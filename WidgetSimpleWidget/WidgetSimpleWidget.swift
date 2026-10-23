import WidgetKit
import SwiftUI
import AppIntents

// The only widget: apps as words on a see-through background; a tap opens the app.
//
// The look (font, size, alignment, colour) and the clock are set in the app and
// shared through the App Group, so every widget on the Home Screen matches.
// The apps stay in Edit Widget: SystemShortcut has no public initializer and no
// public enumeration, so only the system can fill that list (iOS 27 App Intents).

struct DirectLauncherIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Apps"
    static let description = IntentDescription("Pick up to 12 apps. A tap opens the app.")

    @Parameter(title: "App 1") var app1: SystemShortcut?
    @Parameter(title: "App 2") var app2: SystemShortcut?
    @Parameter(title: "App 3") var app3: SystemShortcut?
    @Parameter(title: "App 4") var app4: SystemShortcut?
    @Parameter(title: "App 5") var app5: SystemShortcut?
    @Parameter(title: "App 6") var app6: SystemShortcut?
    @Parameter(title: "App 7") var app7: SystemShortcut?
    @Parameter(title: "App 8") var app8: SystemShortcut?
    @Parameter(title: "App 9") var app9: SystemShortcut?
    @Parameter(title: "App 10") var app10: SystemShortcut?
    @Parameter(title: "App 11") var app11: SystemShortcut?
    @Parameter(title: "App 12") var app12: SystemShortcut?

    init() {}

    /// The picked apps, in order, skipping empty slots.
    var apps: [SystemShortcut] {
        [app1, app2, app3, app4, app5, app6, app7, app8, app9, app10, app11, app12].compactMap { $0 }
    }
}

struct LauncherEntry: TimelineEntry {
    var date: Date
    let look: Look
    let clock: ClockOption
    let apps: [SystemShortcut]
    /// The words shown; sample names in the widget gallery.
    let names: [String]
    /// Matched wallpaper piece (App Store flavour). nil keeps the system background.
    var background: UIImage? = nil
    /// Set while the app is finding the widgets: show this key on pink.
    var findingKey: Int? = nil

    static func sample(look: Look) -> LauncherEntry {
        LauncherEntry(date: .now, look: look, clock: .time, apps: [],
                      names: ["Phone", "Messages", "Camera", "Music"])
    }
}

struct LauncherProvider: AppIntentTimelineProvider {
    typealias Entry = LauncherEntry
    typealias Intent = DirectLauncherIntent

    func placeholder(in context: Context) -> LauncherEntry {
        .sample(look: SharedStore.shared.loadLook())
    }

    func snapshot(for configuration: DirectLauncherIntent, in context: Context) async -> LauncherEntry {
        makeEntry(for: configuration, in: context)
    }

    func timeline(for configuration: DirectLauncherIntent, in context: Context) async -> Timeline<LauncherEntry> {
        // The real on-screen size helps the app cut the right piece of wallpaper.
        if let family = SpotFamily(context.family) {
            SharedStore.shared.recordSize(context.displaySize, for: family)
        }
        let entry = makeEntry(for: configuration, in: context)
        // Without a clock nothing changes on its own: the app and Edit Widget reload it.
        guard entry.clock != .off else { return Timeline(entries: [entry], policy: .never) }
        // One entry per minute; WidgetKit shows each one on time.
        let start = Calendar.current.dateInterval(of: .minute, for: .now)?.start ?? .now
        let entries = (0..<60).map { minute in
            var next = entry
            next.date = start.addingTimeInterval(Double(minute) * 60)
            return next
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func makeEntry(for configuration: DirectLauncherIntent, in context: Context) -> LauncherEntry {
        FontRegistry.registerAllOnce()
        let look = SharedStore.shared.loadLook()
        let apps = configuration.apps
        if apps.isEmpty && context.isPreview {
            // Widget gallery: sample words until apps are picked.
            return .sample(look: look)
        }
        let names = apps.map { String(localized: $0.displayRepresentation.title) }
        let clock = SharedStore.shared.loadClock()
        var entry = LauncherEntry(date: .now, look: look, clock: clock, apps: apps, names: names)
        #if APPSTORE
        // Public-API see-through: draw the piece of wallpaper behind this widget.
        // No match (never set up, wallpaper changed, widget moved) means the system
        // background — never a wrong piece.
        if !context.isPreview, let family = SpotFamily(context.family) {
            let key = SpotKey.make(family: family, clock: clock, apps: names)
            let state = SharedStore.shared.loadSeeThrough()
            if state.finding {
                entry.findingKey = key
            } else {
                entry.background = SharedStore.shared.spotImage(key: key, state: state)
            }
        }
        #endif
        return entry
    }
}

/// Appends a line to the shared log, so the app can show what the widget saw.
enum WidgetLog {
    static func write(_ message: String) {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String,
              !group.isEmpty, !group.contains("$("),
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { return }
        let directory = container.appendingPathComponent("WidgetSimple", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("view.log")
        let line = "\(Date().formatted(date: .omitted, time: .standard)) \(message)\n"
        if let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: file)
        }
    }
}

/// Reports the view chain the widget is hosted in, and blanks what looks like the
/// system's glass or its background layer. Glass drawn by the host in another process
/// can't be reached this way; anything that disappears from here was drawn in-process.
private struct GlassProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let probe = UIView(frame: .zero)
        probe.isUserInteractionEnabled = false
        probe.backgroundColor = .clear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak probe] in
            var chain: [String] = []
            var current = probe?.superview
            var depth = 0
            while let view = current, depth < 14 {
                let name = String(describing: type(of: view))
                let lower = name.lowercased()
                chain.append("\(name)(r=\(Int(view.layer.cornerRadius)))")

                if view is UIVisualEffectView || lower.contains("glass") {
                    view.isHidden = true
                    WidgetLog.write("hid \(name)")
                } else if lower.contains("background") {
                    view.backgroundColor = .clear
                    WidgetLog.write("cleared background of \(name)")
                }

                current = view.superview
                depth += 1
            }
            WidgetLog.write("chain: " + chain.joined(separator: " < "))
        }
        return probe
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

extension SpotFamily {
    /// Bridges WidgetKit's family to the four sizes the wallpaper matching knows.
    init?(_ family: WidgetFamily) {
        switch family {
        case .systemSmall: self = .small
        case .systemMedium: self = .medium
        case .systemLarge: self = .large
        case .systemExtraLargePortrait: self = .max
        default: return nil
        }
    }
}

struct LauncherWidgetView: View {
    let entry: LauncherEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Group {
            if let key = entry.findingKey {
                // The app is looking for the widgets: pink with a code it can read.
                SpotCode(key: key)
                    .containerBackground(for: .widget) { SpotCode.marker }
            } else {
                face
                    .containerBackground(for: .widget) {
                        if let background = entry.background {
                            Image(uiImage: background)
                                .resizable()
                                .scaledToFill()
                        } else {
                            // No match yet: the system background, never a wrong piece.
                            Color.clear
                        }
                    }
            }
        }
        #if !APPSTORE
        .overlay { GlassProbe().frame(width: 0, height: 0) }
        #endif
    }

    /// The words, with one button per app.
    private var face: some View {
        LauncherFace(look: entry.look, clock: entry.clock, date: entry.date, size: size,
                     apps: entry.names, color: color, hint: "Hold here › Edit Widget › pick apps") { index, name in
            if index < entry.apps.count {
                Button(intent: RunSystemShortcutIntent(shortcut: entry.apps[index])) {
                    name
                }
                .buttonStyle(.plain)
            } else {
                name
            }
        }
    }

    /// The chosen colour; white when a Clear or Tinted Home Screen tints the widget.
    private var color: Color {
        renderingMode == .fullColor ? entry.look.color : .white
    }

    private var size: FaceSize {
        switch family {
        case .systemSmall: return .small
        case .systemMedium: return .medium
        default: return .large
        }
    }
}

struct LauncherWidget: Widget {
    // The Direct Launcher's kind, so widgets already on the Home Screen keep their apps.
    static let kind = "WidgetSimpleDirect"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: DirectLauncherIntent.self, provider: LauncherProvider()) { entry in
            LauncherWidgetView(entry: entry)
        }
        .configurationDisplayName("Apps")
        .description("Your apps as words on clear glass, with a clock if you like.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLargePortrait])
        .contentMarginsDisabled()
        // Adding the widget immediately opens Edit Widget, where the apps are picked:
        // iOS only lets the system fill that list.
        .promptsForUserConfiguration()
    }
}

@main
struct WidgetSimpleWidgetBundle: WidgetBundle {
    var body: some Widget {
        LauncherWidget()
    }
}

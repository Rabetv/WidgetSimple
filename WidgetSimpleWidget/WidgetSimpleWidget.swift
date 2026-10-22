import WidgetKit
import SwiftUI
import AppIntents

// The only widget. Apps are picked in Edit Widget, where iOS lists every installed
// app, and a tap opens the app directly (RunSystemShortcutIntent). The look
// (font, size, alignment, color) comes from the app and is the same for every widget.
//
// The background is the piece of wallpaper behind the widget (see SeeThrough.swift),
// so it looks see-through on the normal Home Screen. A Clear or Tinted Home Screen
// replaces it with the system glass.

struct DirectLauncherIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Apps"
    static let description = IntentDescription("Pick apps and a clock. A tap opens the app.")

    @Parameter(title: "Clock", default: .off)
    var clock: ClockOption

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
    /// The piece of wallpaper behind the widget.
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
        // The real on-screen size helps the app find the widget's exact frame.
        if let family = SpotFamily(context.family) {
            SharedStore.shared.recordSize(context.displaySize, for: family)
        }
        let entry = makeEntry(for: configuration, in: context)
        // Without a clock nothing changes on its own: the app and Edit Widget reload it.
        guard entry.clock != .off, entry.findingKey == nil else { return Timeline(entries: [entry], policy: .never) }
        // One entry per minute (one hour with a wallpaper piece, three without);
        // WidgetKit shows each one on time.
        let start = Calendar.current.dateInterval(of: .minute, for: .now)?.start ?? .now
        let entries = (0..<(entry.background == nil ? 180 : 60)).map { minute in
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
        if apps.isEmpty && configuration.clock == .off && context.isPreview {
            // Widget gallery: sample words until apps are picked.
            return .sample(look: look)
        }
        let names = apps.map { String(localized: $0.displayRepresentation.title) }
        var entry = LauncherEntry(date: .now, look: look, clock: configuration.clock, apps: apps, names: names)
        guard !context.isPreview, let family = SpotFamily(context.family) else { return entry }
        let key = SpotKey.make(family: family, clock: configuration.clock, apps: names)
        let state = SharedStore.shared.loadSeeThrough()
        if state.finding {
            entry.findingKey = key
        } else {
            entry.background = SharedStore.shared.spotImage(key: key, state: state)
        }
        return entry
    }
}

extension SpotFamily {
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
        if let key = entry.findingKey {
            // Pink with the widget's key, so the app can find it in a screenshot.
            SpotCode(key: key)
                .containerBackground(for: .widget) { SpotCode.marker }
        } else {
            // The piece of wallpaper is content, not the container background.
            //
            // Since iOS 26 the system removes a widget's container background on a
            // Clear or Tinted Home Screen and draws its own themed glass there instead
            // â€” the grey box. Content is never replaced, so the piece stays the wallpaper.
            //
            // The geometry reader pins the piece to the widget's own size. Without it the
            // image keeps its pixel size (a medium piece is ~1000 pt), the ZStack grows to
            // that, and the widget shows a corner of the piece with the words pushed out
            // of view. `.widgetAccentedRenderingMode` is deliberately not used here: it
            // wraps the image so `resizable()` stops taking effect, which is the same bug.
            GeometryReader { geo in
                ZStack {
                    if let background = entry.background {
                        Image(uiImage: background)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                    face
                }
            }
            // No background of our own, so nothing is left for the system to replace.
            .containerBackground(for: .widget) { Color.clear }
        }
    }

    /// The words, laid out over the wallpaper piece, with one button per app.
    private var face: some View {
        LauncherFace(look: entry.look, clock: entry.clock, date: entry.date, size: size,
                     apps: entry.names, color: color, hint: "Hold here â€º Edit Widget â€º pick apps") { index, name in
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

    /// The chosen color; white when a Clear or Tinted Home Screen tints the widget.
    private var color: Color {
        renderingMode == .fullColor ? entry.look.tone.color : .white
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
    // The Direct Launcher's kind and intent, so widgets already on the Home Screen keep their apps.
    static let kind = "WidgetSimpleDirect"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: DirectLauncherIntent.self, provider: LauncherProvider()) { entry in
            LauncherWidgetView(entry: entry)
        }
        .configurationDisplayName("Apps")
        .description("Your apps as words on clear glass, with a clock if you like.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLargePortrait])
        .contentMarginsDisabled()
        // Keep our (empty) container background instead of letting iOS swap in its
        // glass: "If you mark a background as nonremovable, the system always
        // displays the background container of the widget." Ours draws nothing.
        .containerBackgroundRemovable(false)
    }
}

@main
struct WidgetSimpleWidgetBundle: WidgetBundle {
    var body: some Widget {
        LauncherWidget()
    }
}


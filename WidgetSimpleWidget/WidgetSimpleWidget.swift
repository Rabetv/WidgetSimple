import WidgetKit
import SwiftUI
import AppIntents

// The only widget: apps as words on a see-through background; a tap opens the app.
//
// Without a design, the look (font, size, alignment, colour) and the clock are set in
// the app and shared through the App Group, so every such widget matches. With one of
// the designs saved in the app, the widget draws that design's blocks and the picked
// apps fill its Open App slots in order.
// The apps stay in Edit Widget: SystemShortcut has no public initializer and no
// public enumeration, so only the system can fill that list (iOS 27 App Intents).

/// A saved design, as Edit Widget lists it. "None" keeps the plain Apps widget.
struct DesignEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Design"
    static let defaultQuery = DesignQuery()
    /// The entry that picks no design.
    static let noDesign = DesignEntity(id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
                                   name: String(localized: "None – just the apps"))

    let id: UUID
    let name: String

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    init(_ design: WidgetDesign) {
        self.init(id: design.id, name: design.displayName)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

/// Reads the designs the app saved; nothing is cached, so a new or renamed design shows
/// up the next time Edit Widget opens. There is deliberately no default: a widget
/// without a pick stays the plain Apps widget.
struct DesignQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [DesignEntity] {
        let designs = SharedStore.shared.loadDesigns()
        return identifiers.compactMap { id in
            id == DesignEntity.noDesign.id ? DesignEntity.noDesign : designs.first { $0.id == id }.map(DesignEntity.init)
        }
    }

    func suggestedEntities() async throws -> [DesignEntity] {
        [DesignEntity.noDesign] + SharedStore.shared.loadDesigns().map(DesignEntity.init)
    }
}

struct DirectLauncherIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Apps"
    static let description = IntentDescription("Pick one of your designs, if you like, and up to 12 apps. A tap opens the app.")

    // First in Edit Widget. Added after the apps; widgets placed earlier keep them.
    @Parameter(title: "Design") var design: DesignEntity?
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
    /// The design picked in Edit Widget; nil draws the plain Apps widget.
    var design: WidgetDesign? = nil
    /// The iPhone's charge, read only for a design with a battery block.
    var battery: Double? = nil
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
        await makeEntry(for: configuration, in: context)
    }

    func timeline(for configuration: DirectLauncherIntent, in context: Context) async -> Timeline<LauncherEntry> {
        // The real on-screen size helps the app cut the right piece of wallpaper.
        if let family = SpotFamily(context.family) {
            SharedStore.shared.recordSize(context.displaySize, for: family)
        }
        let entry = await makeEntry(for: configuration, in: context)
        if let design = entry.design, !design.followsMinute {
            // Dates, words and modules change at midnight (a greeting or the battery
            // sooner); the app reloads on every edit.
            return Timeline(entries: [entry], policy: .after(design.nextChange(after: .now)))
        }
        // Without a clock nothing changes on its own: the app and Edit Widget reload it.
        guard entry.design != nil || entry.clock != .off else { return Timeline(entries: [entry], policy: .never) }
        // One entry per minute; WidgetKit shows each one on time.
        let start = Calendar.current.dateInterval(of: .minute, for: .now)?.start ?? .now
        let entries = (0..<60).map { minute in
            var next = entry
            next.date = start.addingTimeInterval(Double(minute) * 60)
            return next
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func makeEntry(for configuration: DirectLauncherIntent, in context: Context) async -> LauncherEntry {
        FontRegistry.registerAllOnce()
        let look = SharedStore.shared.loadLook()
        let design = configuration.design.flatMap { picked in
            SharedStore.shared.loadDesigns().first { $0.id == picked.id }
        }
        let apps = configuration.apps
        if apps.isEmpty && context.isPreview {
            // Widget gallery: sample words until apps are picked.
            var sample = LauncherEntry.sample(look: look)
            sample.design = design
            return sample
        }
        let names = apps.map { String(localized: $0.displayRepresentation.title) }
        #if TESTFLIGHT
        // Tells us whether a blank widget lost its intent or only its contrast.
        WidgetLog.write("entry family=\(context.family) apps=\(apps.count) titles=\(names.map(\.count)) design=\(design != nil)")
        #endif
        let clock = SharedStore.shared.loadClock()
        var entry = LauncherEntry(date: .now, look: look, clock: clock, apps: apps, names: names)
        if let design {
            entry.design = design
            if design.blocks.contains(where: { $0.kind == .battery }) {
                entry.battery = await Self.batteryLevel()
            }
        }
        #if APPSTORE
        // Public-API see-through: draw the piece of wallpaper behind this widget.
        // No match (never set up, wallpaper changed, widget moved) means the system
        // background — never a wrong piece. A design is part of the key, so the same
        // apps in a design never take the plain widget's piece.
        if !context.isPreview, let family = SpotFamily(context.family) {
            let key = design.map { SpotKey.make(family: family, clock: .off, apps: ["design:" + $0.id.uuidString] + names) }
                ?? SpotKey.make(family: family, clock: clock, apps: names)
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

    /// The iPhone's charge, read when the timeline is made; nil when iOS doesn't say.
    @MainActor
    private static func batteryLevel() -> Double? {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        return level < 0 ? nil : Double(level)
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let key = entry.findingKey {
                // The app is looking for the widgets: pink with a code it can read.
                // The container itself must be magenta, or the screenshot finder has
                // no rectangle to measure.
                SpotCode(key: key)
                    .containerBackground(for: .widget) { SpotCode.marker }
            } else {
                face
                    .containerBackground(for: .widget) { widgetBackground }
            }
        }
    }

    /// What sits in the widget container. A matched wallpaper piece wins; otherwise the
    /// background picked in the app. Clear leaves the container to the system, which
    /// draws its own background there.
    @ViewBuilder
    private var widgetBackground: some View {
        if let matched = entry.background {
            Image(uiImage: darkPiece ?? matched)
                .resizable()
                .scaledToFill()
        } else {
            switch entry.look.background {
            case .photo:
                if let photo = SharedStore.shared.loadBackgroundImage() {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else {
                    Color.clear
                }
            case .clear:
                Color.clear
            }
        }
    }

    /// In Dark Mode, the piece cut from the dark wallpaper screenshot; nil keeps the
    /// bright one (no dark screenshot yet, or no dark piece for this widget).
    private var darkPiece: UIImage? {
        guard colorScheme == .dark, let spotFamily = SpotFamily(family) else { return nil }
        let key = SpotKey.make(family: spotFamily, clock: entry.clock, apps: entry.names, design: entry.design?.id)
        return SharedStore.shared.darkSpotImage(key: key, state: SharedStore.shared.loadSeeThrough())
    }

    /// The words, with one button per app: on their own, or in the picked design's
    /// Open App slots.
    private var face: some View {
        Group {
            if let design = entry.design {
                DesignFace(design: design, date: entry.date, size: size, apps: entry.names,
                           color: color(design.look), battery: entry.battery,
                           hint: "Hold here › Edit Widget › pick apps", cell: appCell)
            } else {
                LauncherFace(look: entry.look, clock: entry.clock, date: entry.date, size: size,
                             apps: entry.names, color: color(entry.look), hint: "Hold here › Edit Widget › pick apps",
                             cell: appCell)
            }
        }
        // Accented rendering tints every word white, which is hard to read on a light
        // wallpaper piece, so keep a shadow under the text in every non-full-colour
        // context.
        .shadow(color: renderingMode == .fullColor ? .clear : .black.opacity(0.55),
                radius: 4, x: 0, y: 1)
    }

    /// One word; a button that opens its app once an app is picked for it.
    @ViewBuilder
    private func appCell(_ index: Int, _ name: AppName) -> some View {
        if index < entry.apps.count {
            Button(intent: RunSystemShortcutIntent(shortcut: entry.apps[index])) {
                name
            }
            .buttonStyle(.plain)
        } else {
            name
        }
    }

    /// The chosen colour; white when a Clear or Tinted Home Screen tints the widget.
    private func color(_ look: Look) -> Color {
        renderingMode == .fullColor ? look.color : .white
    }

    private var size: FaceSize {
        switch family {
        case .systemSmall: return .small
        case .systemMedium: return .medium
        case .systemExtraLargePortrait: return .extraLarge
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
        .description("Your apps as words on clear glass, on their own or in one of your designs.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLargePortrait])
        .contentMarginsDisabled()
        // Adding the widget immediately opens Edit Widget, where the apps are picked:
        // iOS only lets the system fill that list.
        .promptsForUserConfiguration()
    }
}

@main
struct WidgetSimpleWidgetBundle: WidgetBundle {
    // One widget. Text, countdowns, world clocks and empty space are blocks of a design.
    var body: some Widget {
        LauncherWidget()
    }
}

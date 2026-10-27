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
        // Every identifier resolves, even one whose design is gone or unreadable right
        // now: dropping it can make iOS discard the widget's whole configuration,
        // apps included. The widget draws the plain Apps face for a missing design.
        return identifiers.map { id in
            if id == DesignEntity.noDesign.id { return DesignEntity.noDesign }
            return designs.first { $0.id == id }.map(DesignEntity.init)
                ?? DesignEntity(id: id, name: String(localized: "Missing design"))
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
    // Where the widget sits on the Home Screen, so it shows the wallpaper behind that
    // spot. WidgetKit doesn't tell a widget its place; top left is the default.
    @Parameter(title: "Position", default: .top) var row: SlotRow
    @Parameter(title: "Side (small widget)", default: .left) var side: SlotSide
    // Per-widget touches on top of the look set in the app.
    @Parameter(title: "Text size", default: .app) var textSize: WordScale
    @Parameter(title: "Text colour", default: .app) var textColour: InkOverride
    @Parameter(title: "Dim the wallpaper", default: .off) var dim: WallpaperDim
    @Parameter(title: "Open apps on tap", default: true) var tappable: Bool
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
    /// The same piece cut from the Dark Mode screenshot; nil reuses `background`.
    var darkBackground: UIImage? = nil
    /// The photo picked in the app, when the look's background is Photo.
    var photo: UIImage? = nil
    /// The wallpaper screenshots are missing: show the setup prompt, not the apps.
    var needsSetup = false
    /// False shows the words without opening anything (no accidental launches).
    var tappable = true
    /// Black over the wallpaper piece, 0…1, so light words stay readable.
    var dim = 0.0

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
        // Still ask again every few hours, so a snapshot made while the App Group or the
        // app list was unavailable doesn't stay on the Home Screen for good.
        guard entry.design != nil || entry.clock != .off else {
            return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(6 * 3600)))
        }
        // One entry per minute; WidgetKit shows each one on time. WidgetKit renders and
        // stores every entry ahead of time, so keep the run short.
        let start = Calendar.current.dateInterval(of: .minute, for: .now)?.start ?? .now
        let entries = (0..<30).map { minute in
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
        // A title iOS can't resolve right now still gets a word, so the slot stays
        // visible and tappable instead of looking like the app was removed.
        let names = apps.enumerated().map { index, app in
            let title = String(localized: app.displayRepresentation.title)
            return title.trimmingCharacters(in: .whitespaces).isEmpty ? String(localized: "App \(index + 1)") : title
        }
        #if TESTFLIGHT
        // Tells us whether a blank widget lost its intent or only its contrast.
        WidgetLog.write("entry family=\(context.family) apps=\(apps.count) titles=\(names.map(\.count)) design=\(design != nil)")
        #endif
        let clock = SharedStore.shared.loadClock()
        var styled = look
        styled.size *= configuration.textSize.factor
        if let tone = configuration.textColour.tone { styled.tone = tone }
        var entry = LauncherEntry(date: .now, look: styled, clock: clock, apps: apps, names: names)
        entry.tappable = configuration.tappable
        entry.dim = configuration.dim.opacity
        if var design {
            if let tone = configuration.textColour.tone {
                design.look.tone = tone
                // Blocks with their own style follow the widget's override too.
                for index in design.blocks.indices where design.blocks[index].look != nil {
                    design.blocks[index].look?.tone = tone
                }
            }
            entry.design = design
            // Music and the vinyl show the Music app's song: read it now, so the widget
            // follows Music even while the app stays closed.
            if design.blocks.contains(where: { $0.kind == .music || $0.kind == .vinyl }) {
                await NowPlayingStore.refreshFromMusic(reload: false)
            }
            if design.blocks.contains(where: { $0.kind == .battery }) {
                entry.battery = await Self.batteryLevel()
            }
        }
        #if APPSTORE
        // Public-API see-through: draw the piece of wallpaper cut for this widget's slot
        // (Position and Side in Edit Widget). No piece yet means the system background.
        if !context.isPreview, let family = SpotFamily(context.family) {
            let state = SharedStore.shared.loadSeeThrough()
            if !state.hasWallpaper || !state.hasDarkWallpaper {
                entry.needsSetup = true
            } else {
                let slot = HomeSlot(family: family, row: configuration.row, side: configuration.side)
                entry.background = SharedStore.shared.spotImage(key: slot.key)
                entry.darkBackground = SharedStore.shared.darkSpotImage(key: slot.key)
            }
        }
        #endif
        if entry.look.background == .photo, !context.isPreview {
            entry.photo = SharedStore.shared.loadBackgroundImage()
        }
        // WidgetKit refuses to store an image larger than the widget itself and then
        // shows the placeholder (grey bars) instead of the apps. Every picture goes in at
        // the widget's size.
        entry.background = entry.background.flatMap { Self.fitted($0, to: context.displaySize) }
        entry.darkBackground = entry.darkBackground.flatMap { Self.fitted($0, to: context.displaySize) }
        entry.photo = entry.photo.flatMap { Self.fitted($0, to: context.displaySize) }
        #if TESTFLIGHT
        WidgetLog.write("entry ok family=\(context.family) size=\(Int(context.displaySize.width))x\(Int(context.displaySize.height)) background=\(entry.background != nil) setup=\(entry.needsSetup)")
        #endif
        return entry
    }

    /// `image` filled into `size` points at 2x, cropped like `.scaledToFill()`: well
    /// under the widget's own pixel area, which is WidgetKit's limit.
    private static func fitted(_ image: UIImage, to size: CGSize) -> UIImage? {
        guard size.width > 0, size.height > 0, image.size.width > 0, image.size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        let fill = max(size.width / image.size.width, size.height / image.size.height)
        let drawn = CGSize(width: image.size.width * fill, height: image.size.height * fill)
        let origin = CGPoint(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: origin, size: drawn))
        }
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

/// What a widget shows until the wallpaper screenshots are in.
private struct SetupPrompt: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 26, weight: .semibold))
            Text("Open WidgetSimple to add your wallpaper")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Text size for one widget, relative to the size set in the app.
enum WordScale: String, AppEnum {
    case smaller, app, larger, largest

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Text size"
    static let caseDisplayRepresentations: [WordScale: DisplayRepresentation] = [
        .smaller: "Smaller", .app: "As in the app", .larger: "Larger", .largest: "Largest",
    ]

    var factor: Double {
        switch self {
        case .smaller: return 0.8
        case .app: return 1
        case .larger: return 1.25
        case .largest: return 1.5
        }
    }
}

/// Text colour for one widget; "As in the app" keeps the shared look.
enum InkOverride: String, AppEnum {
    case app, white, black

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Text colour"
    static let caseDisplayRepresentations: [InkOverride: DisplayRepresentation] = [
        .app: "As in the app", .white: "White", .black: "Black",
    ]

    var tone: TextTone? {
        switch self {
        case .app: return nil
        case .white: return .white
        case .black: return .black
        }
    }
}

/// A dark veil over the wallpaper piece, for words on a bright photo.
enum WallpaperDim: String, AppEnum {
    case off, light, strong

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Dim"
    static let caseDisplayRepresentations: [WallpaperDim: DisplayRepresentation] = [
        .off: "Off", .light: "Light", .strong: "Strong",
    ]

    var opacity: Double {
        switch self {
        case .off: return 0
        case .light: return 0.2
        case .strong: return 0.4
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
            if entry.needsSetup {
                // No buttons, so a tap opens the app at its setup screen.
                SetupPrompt()
                    .containerBackground(for: .widget) { Color.clear }
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
            Image(uiImage: colorScheme == .dark ? entry.darkBackground ?? matched : matched)
                .resizable()
                .scaledToFill()
                .overlay(Color.black.opacity(entry.dim))
        } else {
            switch entry.look.background {
            case .photo:
                if let photo = entry.photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else {
                    Color.clear
                }
            case .clear:
                Color.clear
            }
        }
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
        if entry.tappable, index < entry.apps.count {
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

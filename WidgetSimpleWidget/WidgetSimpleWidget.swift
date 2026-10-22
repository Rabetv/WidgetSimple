import WidgetKit
import SwiftUI
import AppIntents

// The only widget. Apps are picked in Edit Widget, where iOS lists every installed
// app, and a tap opens the app directly (RunSystemShortcutIntent). The look (color,
// font, size) comes from the app and is the same for every widget.

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
        let entry = makeEntry(for: configuration, in: context)
        // Without a clock nothing changes on its own: the app and Edit Widget reload it.
        guard entry.clock != .off else { return Timeline(entries: [entry], policy: .never) }
        // One entry per minute for the next three hours; WidgetKit shows each one on time.
        let start = Calendar.current.dateInterval(of: .minute, for: .now)?.start ?? .now
        let entries = (0..<180).map { minute in
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
        return LauncherEntry(date: .now, look: look, clock: configuration.clock, apps: apps, names: names)
    }
}

struct LauncherWidgetView: View {
    let entry: LauncherEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        LauncherFace(look: entry.look, clock: entry.clock, date: entry.date, size: size,
                     apps: entry.names, hint: "Hold here › Edit Widget › pick apps") { index, name in
            if index < entry.apps.count {
                Button(intent: RunSystemShortcutIntent(shortcut: entry.apps[index])) {
                    name
                }
                .buttonStyle(.plain)
            } else {
                name
            }
        }
        // Exactly the wallpaper color, so the widget blends into the wallpaper.
        .containerBackground(entry.look.theme.background.color, for: .widget)
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
        .description("Your apps as words, with a clock if you like.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLargePortrait])
        .contentMarginsDisabled()
    }
}

@main
struct WidgetSimpleWidgetBundle: WidgetBundle {
    var body: some Widget {
        LauncherWidget()
    }
}

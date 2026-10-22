#if SDK27
import WidgetKit
import SwiftUI
import AppIntents

// iOS 27: the apps are picked in Edit Widget, where iOS lists every installed app,
// and a tap opens the app directly through RunSystemShortcutIntent, without going
// through WidgetSimple. A WidgetSimple layout gives the look (font, colors,
// arrangement, background).

@available(iOS 27.0, *)
struct DirectLauncherIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Direct Launcher"
    static let description = IntentDescription("Pick apps. A tap opens them directly.")

    @Parameter(title: "Look")
    var layout: LayoutEntity?

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

@available(iOS 27.0, *)
struct DirectLauncherEntry: TimelineEntry {
    let launcher: LauncherEntry
    /// The picked app behind each word, by item id.
    let shortcuts: [UUID: SystemShortcut]

    var date: Date { launcher.date }
}

@available(iOS 27.0, *)
struct DirectLauncherProvider: AppIntentTimelineProvider {
    typealias Entry = DirectLauncherEntry
    typealias Intent = DirectLauncherIntent

    func placeholder(in context: Context) -> DirectLauncherEntry {
        DirectLauncherEntry(launcher: .placeholder, shortcuts: [:])
    }

    func snapshot(for configuration: DirectLauncherIntent, in context: Context) async -> DirectLauncherEntry {
        await makeEntry(for: configuration, in: context)
    }

    func timeline(for configuration: DirectLauncherIntent, in context: Context) async -> Timeline<DirectLauncherEntry> {
        let entry = await makeEntry(for: configuration, in: context)
        // Edit Widget and the app both reload the widget, so no periodic refresh is needed.
        return Timeline(entries: [entry], policy: .never)
    }

    private func makeEntry(for configuration: DirectLauncherIntent, in context: Context) async -> DirectLauncherEntry {
        FontRegistry.registerAllOnce()
        let picked = configuration.apps
        if picked.isEmpty && context.isPreview {
            // Widget gallery: show sample words until apps are picked.
            return DirectLauncherEntry(launcher: .placeholder, shortcuts: [:])
        }
        let selectedID = configuration.layout.flatMap { UUID(uuidString: $0.id) }
        var layout = SharedStore.shared.layout(id: selectedID) ?? LauncherLayout.starter()
        var shortcuts: [UUID: SystemShortcut] = [:]
        layout.items = picked.map { shortcut in
            // The picked app's name, styled with the layout's text style.
            let item = LaunchItem(label: String(localized: shortcut.displayRepresentation.title), target: LaunchTarget())
            shortcuts[item.id] = shortcut
            return item
        }
        let launcher = await LauncherEntry.make(layout: layout, isPreview: context.isPreview)
        return DirectLauncherEntry(launcher: launcher, shortcuts: shortcuts)
    }
}

@available(iOS 27.0, *)
struct DirectLauncherView: View {
    let entry: DirectLauncherEntry

    var body: some View {
        WidgetSimpleEntryView(entry: entry.launcher, mode: .wrapped({ item, label in
            guard let shortcut = entry.shortcuts[item.id] else { return label }
            return AnyView(
                Button(intent: RunSystemShortcutIntent(shortcut: shortcut)) {
                    label
                }
                .buttonStyle(.plain)
            )
        }))
    }
}

@available(iOS 27.0, *)
struct DirectLauncherWidget: Widget {
    static let kind = "WidgetSimpleDirect"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: DirectLauncherIntent.self, provider: DirectLauncherProvider()) { entry in
            DirectLauncherView(entry: entry)
        }
        .configurationDisplayName("Direct Launcher")
        .description("Pick apps in Edit Widget. A tap opens them directly.")
        .supportedFamilies(WidgetSizes.families)
        .contentMarginsDisabled()
    }
}
#endif

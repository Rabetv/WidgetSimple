import WidgetKit
import SwiftUI
import AppIntents

struct LauncherEntry: TimelineEntry {
    let date: Date
    let layout: LauncherLayout
    let calibrating: Bool
    let launchMethod: LaunchMethod
    let lightImage: UIImage?
    let darkImage: UIImage?
    /// Full-color label images for the Clear / Tinted Home Screen styles.
    var labelImages: [UUID: UIImage] = [:]

    static var placeholder: LauncherEntry {
        LauncherEntry(date: .now, layout: .starter(), calibrating: false,
                      launchMethod: .auto, lightImage: nil, darkImage: nil)
    }
}

struct Provider: AppIntentTimelineProvider {
    typealias Entry = LauncherEntry
    typealias Intent = SelectLayoutIntent

    func placeholder(in context: Context) -> LauncherEntry {
        .placeholder
    }

    func snapshot(for configuration: SelectLayoutIntent, in context: Context) async -> LauncherEntry {
        await makeEntry(for: configuration, in: context)
    }

    func timeline(for configuration: SelectLayoutIntent, in context: Context) async -> Timeline<LauncherEntry> {
        // Remember the real on-screen size so the app can preview and calibrate precisely.
        if let option = sizeOption(for: context.family) {
            SharedStore.shared.recordWidgetSize(context.displaySize, for: option)
        }
        let entry = await makeEntry(for: configuration, in: context)
        // The app reloads the widget whenever something changes, so no periodic refresh is needed.
        return Timeline(entries: [entry], policy: .never)
    }

    private func sizeOption(for family: WidgetFamily) -> WidgetSizeOption? {
        switch family {
        case .systemMedium: return .medium
        case .systemLarge: return .large
        default: return nil
        }
    }

    private func makeEntry(for configuration: SelectLayoutIntent, in context: Context) async -> LauncherEntry {
        FontRegistry.registerAllOnce()
        let store = SharedStore.shared
        let selectedID = configuration.layout.flatMap { UUID(uuidString: $0.id) }
        guard let layout = store.layout(id: selectedID) else {
            if context.isPreview { return .placeholder }
            var empty = LauncherLayout(name: "")
            empty.background.color = .charcoal
            return LauncherEntry(date: .now, layout: empty, calibrating: false,
                                 launchMethod: .auto, lightImage: nil, darkImage: nil)
        }
        let settings = store.loadSettings()
        let calibrating = settings.calibratingLayoutID == layout.id && !context.isPreview
        var light: UIImage?
        var dark: UIImage?
        if layout.background.mode == .wallpaper {
            if layout.background.hasLightImage { light = store.loadBackground(layoutID: layout.id, dark: false) }
            if layout.background.hasDarkImage { dark = store.loadBackground(layoutID: layout.id, dark: true) }
        }
        var labels: [UUID: UIImage] = [:]
        if layout.keepColorsInClearMode && !calibrating {
            labels = await MainActor.run { LabelRasterizer.render(layout) }
        }
        return LauncherEntry(date: .now, layout: layout, calibrating: calibrating,
                             launchMethod: settings.launchMethod, lightImage: light, darkImage: dark,
                             labelImages: labels)
    }
}

struct WidgetSimpleEntryView: View {
    let entry: LauncherEntry
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Group {
            if entry.calibrating {
                // Solid magenta: the app finds this exact rectangle in a screenshot.
                Color.clear
            } else {
                LauncherCanvas(layout: entry.layout,
                               mode: .widget(entry.launchMethod),
                               labelImages: keepsColors ? entry.labelImages : nil)
            }
        }
        .containerBackground(for: .widget) {
            WidgetBackgroundView(layout: entry.layout,
                                 lightImage: entry.lightImage,
                                 darkImage: entry.darkImage,
                                 calibrating: entry.calibrating)
        }
    }

    /// Clear and Tinted Home Screen styles render widgets in accented mode.
    private var keepsColors: Bool {
        renderingMode == .accented && entry.layout.keepColorsInClearMode && !entry.labelImages.isEmpty
    }
}

struct WidgetSimpleWidget: Widget {
    static let kind = "WidgetSimpleLauncher"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: SelectLayoutIntent.self, provider: Provider()) { entry in
            WidgetSimpleEntryView(entry: entry)
        }
        .configurationDisplayName("Text Launcher")
        .description("Your apps as plain text. Tap a word to open the app.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

@main
struct WidgetSimpleWidgetBundle: WidgetBundle {
    var body: some Widget {
        WidgetSimpleWidget()
    }
}

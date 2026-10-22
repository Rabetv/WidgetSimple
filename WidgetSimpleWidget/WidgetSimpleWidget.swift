import WidgetKit
import SwiftUI
import AppIntents

struct LauncherEntry: TimelineEntry {
    let date: Date
    let layout: LauncherLayout
    let calibrating: Bool
    let lightImage: UIImage?
    let darkImage: UIImage?
    /// Full-color label images for the Clear / Tinted Home Screen styles.
    var labelImages: [UUID: UIImage] = [:]

    static var placeholder: LauncherEntry {
        LauncherEntry(date: .now, layout: .starter(), calibrating: false,
                      lightImage: nil, darkImage: nil)
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
        case .systemSmall: return .small
        case .systemMedium: return .medium
        case .systemLarge: return .large
        default:
            #if SDK27
            if #available(iOS 27.0, *), family == .systemExtraLargePortrait { return .max }
            #endif
            return nil
        }
    }

    private func makeEntry(for configuration: SelectLayoutIntent, in context: Context) async -> LauncherEntry {
        FontRegistry.registerAllOnce()
        let store = SharedStore.shared
        let selectedID = configuration.layout.flatMap { UUID(uuidString: $0.id) }
        guard let layout = store.layout(id: selectedID) else {
            if context.isPreview { return .placeholder }
            var empty = LauncherLayout(name: "")
            empty.background.color = .black
            return LauncherEntry(date: .now, layout: empty, calibrating: false,
                                 lightImage: nil, darkImage: nil)
        }
        return await LauncherEntry.make(layout: layout, isPreview: context.isPreview)
    }
}

extension LauncherEntry {
    /// The entry for `layout`: calibration state, wallpaper copy and full-color labels.
    static func make(layout: LauncherLayout, isPreview: Bool) async -> LauncherEntry {
        let store = SharedStore.shared
        let settings = store.loadSettings()
        let calibrating = settings.calibratingLayoutID == layout.id && !isPreview
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
                             lightImage: light, darkImage: dark,
                             labelImages: labels)
    }
}

struct WidgetSimpleEntryView: View {
    let entry: LauncherEntry
    var mode: CanvasMode = .widget
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        if entry.layout.background.mode == .clear && !entry.calibrating {
            // No background at all: iOS 26+ shows the wallpaper through the widget.
            content.containerBackground(.clear, for: .widget)
        } else {
            content.containerBackground(for: .widget) {
                WidgetBackgroundView(layout: entry.layout,
                                     lightImage: entry.lightImage,
                                     darkImage: entry.darkImage,
                                     calibrating: entry.calibrating)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if entry.calibrating {
                // Solid magenta: the app finds this exact rectangle in a screenshot.
                Color.clear
            } else {
                LauncherCanvas(layout: entry.layout,
                               mode: mode,
                               labelImages: keepsColors ? entry.labelImages : nil)
            }
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
        .supportedFamilies(WidgetSizes.families)
        .contentMarginsDisabled()
    }
}

@main
struct WidgetSimpleWidgetBundle: WidgetBundle {
    var body: some Widget {
        WidgetSimpleWidget()
        ClockWidget()
        #if SDK27
        if #available(iOS 27.0, *) {
            DirectLauncherWidget()
        }
        #endif
    }
}

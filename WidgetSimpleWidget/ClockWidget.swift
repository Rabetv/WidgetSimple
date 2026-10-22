import WidgetKit
import SwiftUI

struct ClockEntry: TimelineEntry {
    let date: Date
    let style: ClockStyle
}

struct ClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: .now, style: ClockStyle())
    }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        FontRegistry.registerAllOnce()
        completion(ClockEntry(date: .now, style: SharedStore.shared.loadClock()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        FontRegistry.registerAllOnce()
        let style = SharedStore.shared.loadClock()
        // One entry per minute for the next three hours; WidgetKit shows each one on time.
        let start = Calendar.current.dateInterval(of: .minute, for: .now)?.start ?? .now
        let entries = (0..<180).map { ClockEntry(date: start.addingTimeInterval(Double($0) * 60), style: style) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct ClockWidgetView: View {
    let entry: ClockEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let face = ClockFace(date: entry.date, style: entry.style, size: size)
            .widgetURL(LaunchRouter.hopURL(for: URL(string: "calshow://")!))
        if entry.style.clear {
            face.containerBackground(.clear, for: .widget)
        } else {
            face.containerBackground(for: .widget) { entry.style.background.color }
        }
    }

    private var size: WidgetSizeOption {
        switch family {
        case .systemSmall: return .small
        case .systemLarge: return .large
        default:
            #if SDK27
            if #available(iOS 27.0, *), family == .systemExtraLargePortrait { return .max }
            #endif
            return .medium
        }
    }
}

struct ClockWidget: Widget {
    static let kind = "WidgetSimpleClock"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ClockProvider()) { entry in
            ClockWidgetView(entry: entry)
        }
        .configurationDisplayName("Clock")
        .description("Day, time, date and week. Tap to open Calendar.")
        .supportedFamilies(WidgetSizes.families)
        .contentMarginsDisabled()
    }
}

/// Widget sizes for both widgets. The iOS 27 Max size (Extra Large portrait) only
/// exists in the iOS 27 SDK; CI sets SDK27 when it builds with Xcode 27.
enum WidgetSizes {
    static var families: [WidgetFamily] {
        var families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
        #if SDK27
        if #available(iOS 27.0, *) { families.append(.systemExtraLargePortrait) }
        #endif
        return families
    }
}

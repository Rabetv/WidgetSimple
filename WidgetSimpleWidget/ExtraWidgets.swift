import WidgetKit
import SwiftUI
import AppIntents

// The lightweight widget types: no permissions, no network, no extra entitlements.
// They share the look from the app (font, size, colour, case, shadow) through the
// same App Group the launcher uses.
//
// Deliberately not here yet: Calendar/Reminders (EventKit), Weather (WeatherKit),
// Photo (Photos + storage), Music (MusicKit), Dashboard (composition), Controls.

// MARK: - Shared drawing

/// Lines of text in the app's look, clipped to the widget.
struct TextStyleBlock: View {
    let lines: [String]
    let look: Look
    let color: Color
    var lineLimitPerLine = 1
    var spacingScale: Double = 0.8

    var body: some View {
        VStack(alignment: look.align.horizontal, spacing: look.size * spacingScale * look.spacing) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(look.font(size: look.size))
                    .lineLimit(lineLimitPerLine)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity,
                           alignment: Alignment(horizontal: look.align.horizontal, vertical: .center))
            }
        }
        .foregroundStyle(color)
        .textCase(look.letterCase.textCase)
        .shadow(color: look.shadow ? Color.black.opacity(0.45) : .clear, radius: 6, x: 0, y: 3)
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: look.alignment)
        .clipped()
    }
}

private func lookColor(_ look: Look, _ mode: WidgetRenderingMode) -> Color {
    mode == .fullColor ? look.color : .white
}

// MARK: - Text & Quote

struct TextWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Text"
    static let description = IntentDescription("Your own words, in the style you picked in the app.")

    @Parameter(title: "Text", default: "One line at a time.")
    var text: String

    init() {}
}

struct TextEntry: TimelineEntry {
    var date: Date
    let look: Look
    let text: String
}

struct TextProvider: AppIntentTimelineProvider {
    typealias Entry = TextEntry
    typealias Intent = TextWidgetIntent

    func placeholder(in context: Context) -> TextEntry {
        TextEntry(date: .now, look: SharedStore.shared.loadLook(), text: "One line at a time.")
    }

    func snapshot(for configuration: TextWidgetIntent, in context: Context) async -> TextEntry {
        TextEntry(date: .now, look: SharedStore.shared.loadLook(), text: configuration.text)
    }

    func timeline(for configuration: TextWidgetIntent, in context: Context) async -> Timeline<TextEntry> {
        Timeline(entries: [TextEntry(date: .now, look: SharedStore.shared.loadLook(), text: configuration.text)],
                 policy: .never)
    }
}

struct TextWidgetView: View {
    let entry: TextEntry
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        TextStyleBlock(lines: [entry.text], look: entry.look, color: lookColor(entry.look, mode), lineLimitPerLine: 4)
            .containerBackground(for: .widget) { Color.clear }
    }
}

struct TextWidget: Widget {
    static let kind = "WidgetSimpleText"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: TextWidgetIntent.self, provider: TextProvider()) { entry in
            TextWidgetView(entry: entry)
        }
        .configurationDisplayName("Text")
        .description("Write something and it appears on the Home Screen in your style.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

// MARK: - Countdown

struct CountdownIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Countdown"
    static let description = IntentDescription("Days until a date.")

    @Parameter(title: "What", default: "Days to go")
    var title: String

    @Parameter(title: "Date")
    var target: Date?

    init() {}
}

struct CountdownEntry: TimelineEntry {
    var date: Date
    let look: Look
    let title: String
    let target: Date?
}

struct CountdownProvider: AppIntentTimelineProvider {
    typealias Entry = CountdownEntry
    typealias Intent = CountdownIntent

    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(date: .now, look: SharedStore.shared.loadLook(), title: "Days to go",
                       target: Calendar.current.date(byAdding: .day, value: 42, to: .now))
    }

    func snapshot(for configuration: CountdownIntent, in context: Context) async -> CountdownEntry {
        CountdownEntry(date: .now, look: SharedStore.shared.loadLook(),
                       title: configuration.title, target: configuration.target)
    }

    func timeline(for configuration: CountdownIntent, in context: Context) async -> Timeline<CountdownEntry> {
        let entry = CountdownEntry(date: .now, look: SharedStore.shared.loadLook(),
                                   title: configuration.title, target: configuration.target)
        // One entry after midnight; the number only changes then.
        let midnight = Calendar.current.nextDate(after: .now,
                                                 matching: DateComponents(hour: 0, minute: 0),
                                                 matchingPolicy: .nextTime) ?? .now.addingTimeInterval(3600)
        return Timeline(entries: [entry], policy: .after(midnight))
    }
}

struct CountdownWidgetView: View {
    let entry: CountdownEntry
    @Environment(\.widgetRenderingMode) private var mode

    private var days: Int? {
        guard let target = entry.target else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.day],
                                       from: calendar.startOfDay(for: entry.date),
                                       to: calendar.startOfDay(for: target)).day
    }

    var body: some View {
        VStack(alignment: entry.look.align.horizontal, spacing: 4) {
            if let days {
                Text("\(days)")
                    .font(entry.look.font(size: entry.look.size * 3, weight: .light))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .widgetAccentable()
            }
            Text(entry.title)
                .font(entry.look.font(size: entry.look.size * 0.8))
                .lineLimit(2)
                .opacity(0.8)
        }
        .foregroundStyle(lookColor(entry.look, mode))
        .textCase(entry.look.letterCase.textCase)
        .shadow(color: entry.look.shadow ? Color.black.opacity(0.45) : .clear, radius: 6, x: 0, y: 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: entry.look.alignment)
        .padding(18)
        .clipped()
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct CountdownWidget: Widget {
    static let kind = "WidgetSimpleCountdown"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: CountdownIntent.self, provider: CountdownProvider()) { entry in
            CountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("Countdown")
        .description("Days until a date, in your font and colour.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

// MARK: - World Clock

struct WorldClockIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "World Clock"
    static let description = IntentDescription("Up to four cities. Leave a slot empty to hide it.")

    @Parameter(title: "City 1", default: "Europe/Berlin") var city1: String?
    @Parameter(title: "City 2", default: "America/New_York") var city2: String?
    @Parameter(title: "City 3", default: "Asia/Tokyo") var city3: String?
    @Parameter(title: "City 4") var city4: String?

    init() {}

    var zones: [String] {
        [city1, city2, city3, city4].compactMap { $0 }.filter { !$0.isEmpty }
    }
}

struct WorldClockEntry: TimelineEntry {
    var date: Date
    let look: Look
    let zones: [String]
}

struct WorldClockProvider: AppIntentTimelineProvider {
    typealias Entry = WorldClockEntry
    typealias Intent = WorldClockIntent

    func placeholder(in context: Context) -> WorldClockEntry {
        WorldClockEntry(date: .now, look: SharedStore.shared.loadLook(),
                        zones: ["Europe/Berlin", "America/New_York", "Asia/Tokyo"])
    }

    func snapshot(for configuration: WorldClockIntent, in context: Context) async -> WorldClockEntry {
        WorldClockEntry(date: .now, look: SharedStore.shared.loadLook(), zones: configuration.zones)
    }

    func timeline(for configuration: WorldClockIntent, in context: Context) async -> Timeline<WorldClockEntry> {
        let entry = WorldClockEntry(date: .now, look: SharedStore.shared.loadLook(), zones: configuration.zones)
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60)))
    }
}

struct WorldClockWidgetView: View {
    let entry: WorldClockEntry
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        VStack(alignment: entry.look.align.horizontal, spacing: entry.look.size * 0.35) {
            ForEach(entry.zones.prefix(4), id: \.self) { identifier in
                if let zone = TimeZone(identifier: identifier) {
                    HStack(spacing: 10) {
                        Text(cityName(identifier))
                            .font(entry.look.font(size: entry.look.size * 0.62))
                            .opacity(0.75)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(zoneTime(entry.date, zone))
                            .font(entry.look.font(size: entry.look.size * 0.78))
                            .lineLimit(1)
                    }
                }
            }
        }
        .foregroundStyle(lookColor(entry.look, mode))
        .textCase(entry.look.letterCase.textCase)
        .shadow(color: entry.look.shadow ? Color.black.opacity(0.45) : .clear, radius: 6, x: 0, y: 3)
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: entry.look.alignment)
        .clipped()
        .containerBackground(for: .widget) { Color.clear }
    }

    /// "Europe/Berlin" → "Berlin".
    private func cityName(_ identifier: String) -> String {
        identifier.split(separator: "/").last.map(String.init)?.replacingOccurrences(of: "_", with: " ")
            ?? identifier
    }

    /// The time in one zone, following the phone's 12/24-hour setting.
    private func zoneTime(_ date: Date, _ zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.locale = .current
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "jmm", options: 0, locale: .current)
        return formatter.string(from: date)
    }
}

struct WorldClockWidget: Widget {
    static let kind = "WidgetSimpleWorldClock"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: WorldClockIntent.self, provider: WorldClockProvider()) { entry in
            WorldClockWidgetView(entry: entry)
        }
        .configurationDisplayName("World Clock")
        .description("Times in up to four cities.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

// MARK: - Spacer

struct SpacerIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Spacer"
    static let description = IntentDescription("An empty widget, to break up the Home Screen.")

    init() {}
}

struct SpacerEntry: TimelineEntry {
    var date: Date
    let look: Look
}

struct SpacerProvider: AppIntentTimelineProvider {
    typealias Entry = SpacerEntry
    typealias Intent = SpacerIntent

    func placeholder(in context: Context) -> SpacerEntry {
        SpacerEntry(date: .now, look: SharedStore.shared.loadLook())
    }

    func snapshot(for configuration: SpacerIntent, in context: Context) async -> SpacerEntry {
        SpacerEntry(date: .now, look: SharedStore.shared.loadLook())
    }

    func timeline(for configuration: SpacerIntent, in context: Context) async -> Timeline<SpacerEntry> {
        Timeline(entries: [SpacerEntry(date: .now, look: SharedStore.shared.loadLook())], policy: .never)
    }
}

struct SpacerWidget: Widget {
    static let kind = "WidgetSimpleSpacer"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: SpacerIntent.self, provider: SpacerProvider()) { _ in
            Color.clear
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Spacer")
        .description("An empty widget.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

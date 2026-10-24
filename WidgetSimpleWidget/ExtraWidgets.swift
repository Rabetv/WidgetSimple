import WidgetKit
import SwiftUI
import AppIntents

// The lightweight widget types: no permissions, no network, no extra entitlements.
// They share the look from the app (font, size, colour, case, shadow) through the
// same App Group the launcher uses, and every one of them is see-through: each has its
// own `WidgetIdentity`, so it gets its own piece of wallpaper after a scan.

// MARK: - Shared drawing

/// The look's colour, case and shadow; white when the Home Screen tints the widget.
struct LookStyle: ViewModifier {
    let look: Look
    @Environment(\.widgetRenderingMode) private var mode

    func body(content: Content) -> some View {
        content
            .foregroundStyle(mode == .fullColor ? look.color : .white)
            .textCase(look.letterCase.textCase)
            .tracking(look.tracking)
            .shadow(color: look.shadow || mode != .fullColor ? Color.black.opacity(0.45) : .clear,
                    radius: 6, x: 0, y: 3)
    }
}

/// The system's content margins, plus the look's inset. Every kind disables WidgetKit's
/// own margins (the wallpaper piece is full-bleed) and puts them back with this.
struct SystemMargins: ViewModifier {
    var extra: Double = 0
    @Environment(\.widgetContentMargins) private var margins

    func body(content: Content) -> some View {
        content
            .padding(margins)
            .padding(CGFloat(extra))
    }
}

extension View {
    func lookStyle(_ look: Look) -> some View { modifier(LookStyle(look: look)) }
    func systemMargins(extra: Double = 0) -> some View { modifier(SystemMargins(extra: extra)) }
}

/// Lines of text in the app's look, inside the margins and clipped to the widget.
struct TextStyleBlock: View {
    let lines: [String]
    let look: Look
    var lineLimitPerLine = 1

    var body: some View {
        VStack(alignment: look.align.horizontal, spacing: look.size * Typography.rowGapRatio * look.spacing) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(look.font(size: look.size, weight: look.weight.font))
                    .lineLimit(lineLimitPerLine)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(look.align.text)
                    .frame(maxWidth: .infinity,
                           alignment: Alignment(horizontal: look.align.horizontal, vertical: .center))
            }
        }
        .lookStyle(look)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: look.alignment)
        .systemMargins(extra: look.inset)
        .clipped()
    }
}

// MARK: - Text & Quote

struct TextWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Text"
    static let description = IntentDescription("Your own words, in the style you picked in the app.")

    @Parameter(title: "Text", default: "One line at a time.")
    var text: String

    @Parameter(title: "See-through ID") var identity: WidgetIdentity?

    init() {}
}

struct TextEntry: TimelineEntry {
    var date: Date
    let look: Look
    let text: String
    var backdrop: Backdrop = .plain
}

struct TextProvider: AppIntentTimelineProvider {
    typealias Entry = TextEntry
    typealias Intent = TextWidgetIntent

    func placeholder(in context: Context) -> TextEntry {
        TextEntry(date: .now, look: SharedStore.shared.loadLook(), text: "One line at a time.")
    }

    func snapshot(for configuration: TextWidgetIntent, in context: Context) async -> TextEntry {
        entry(configuration, context)
    }

    func timeline(for configuration: TextWidgetIntent, in context: Context) async -> Timeline<TextEntry> {
        Timeline(entries: [entry(configuration, context)], policy: .never)
    }

    private func entry(_ configuration: TextWidgetIntent, _ context: Context) -> TextEntry {
        FontRegistry.registerAllOnce()
        var entry = TextEntry(date: .now, look: SharedStore.shared.loadLook(), text: configuration.text)
        entry.backdrop = SeeThrough.backdrop(kind: TextWidget.kind, identity: configuration.identity,
                                             content: [configuration.text], names: [configuration.text],
                                             clock: .off, context: context)
        return entry
    }
}

struct TextWidgetView: View {
    let entry: TextEntry

    var body: some View {
        TextStyleBlock(lines: [entry.text], look: entry.look, lineLimitPerLine: 4)
            .seeThroughBackground(entry.backdrop, look: entry.look)
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

// MARK: - Countdown

struct CountdownIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Countdown"
    static let description = IntentDescription("Days until a date, or since it.")

    @Parameter(title: "Label", default: "Days to go")
    var title: String

    @Parameter(title: "Date")
    var target: Date?

    @Parameter(title: "See-through ID") var identity: WidgetIdentity?

    init() {}
}

struct CountdownEntry: TimelineEntry {
    var date: Date
    let look: Look
    let title: String
    let target: Date?
    var backdrop: Backdrop = .plain
}

struct CountdownProvider: AppIntentTimelineProvider {
    typealias Entry = CountdownEntry
    typealias Intent = CountdownIntent

    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(date: .now, look: SharedStore.shared.loadLook(), title: "Days to go",
                       target: Calendar.current.date(byAdding: .day, value: 42, to: .now))
    }

    func snapshot(for configuration: CountdownIntent, in context: Context) async -> CountdownEntry {
        entry(configuration, context, at: .now)
    }

    func timeline(for configuration: CountdownIntent, in context: Context) async -> Timeline<CountdownEntry> {
        let now = Date.now
        let first = entry(configuration, context, at: now)
        // On the last day the number counts hours, so refresh hourly; otherwise the
        // number only changes at midnight.
        if let target = configuration.target, target > now, target.timeIntervalSince(now) < 86_400 {
            let start = Calendar.current.dateInterval(of: .hour, for: now)?.start ?? now
            let entries = (0...24).map { hour -> CountdownEntry in
                var next = first
                next.date = hour == 0 ? now : start.addingTimeInterval(Double(hour) * 3600)
                return next
            }
            return Timeline(entries: entries, policy: .atEnd)
        }
        let midnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0),
                                                 matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)
        return Timeline(entries: [first], policy: .after(midnight))
    }

    private func entry(_ configuration: CountdownIntent, _ context: Context, at date: Date) -> CountdownEntry {
        FontRegistry.registerAllOnce()
        var entry = CountdownEntry(date: date, look: SharedStore.shared.loadLook(),
                                   title: configuration.title, target: configuration.target)
        let content = [configuration.title, configuration.target.map { "\($0.timeIntervalSince1970)" } ?? ""]
        entry.backdrop = SeeThrough.backdrop(kind: CountdownWidget.kind, identity: configuration.identity,
                                             content: content, names: [configuration.title],
                                             clock: .off, context: context)
        return entry
    }
}

struct CountdownWidgetView: View {
    let entry: CountdownEntry
    @Environment(\.widgetFamily) private var family

    /// The big number and the line under it: days to go, hours on the last day, days since.
    private var reading: (number: String, unit: String)? {
        guard let target = entry.target else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: entry.date),
                                           to: calendar.startOfDay(for: target)).day ?? 0
        if days > 0 {
            return ("\(days)", days == 1 ? String(localized: "day to go") : String(localized: "days to go"))
        }
        if days < 0 {
            return ("\(-days)", days == -1 ? String(localized: "day since") : String(localized: "days since"))
        }
        let hours = Int((target.timeIntervalSince(entry.date) / 3600).rounded(.up))
        if hours > 0 {
            return ("\(hours)", hours == 1 ? String(localized: "hour to go") : String(localized: "hours to go"))
        }
        return ("0", String(localized: "today"))
    }

    var body: some View {
        Group {
            if family == .accessoryCircular {
                VStack(spacing: 0) {
                    Text(reading?.number ?? "–").font(.system(size: 22, weight: .semibold)).minimumScaleFactor(0.5)
                    Text(entry.title).font(.system(size: 9)).lineLimit(1)
                }
            } else {
                VStack(alignment: entry.look.align.horizontal, spacing: Spacing.xxs) {
                    Text(reading?.number ?? "–")
                        .font(entry.look.font(size: entry.look.size * 3, weight: .light))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .widgetAccentable()
                    if let unit = reading?.unit {
                        Text(unit)
                            .font(entry.look.font(size: entry.look.size * 0.7, weight: entry.look.weight.font))
                            .opacity(0.75)
                            .lineLimit(1)
                    }
                    Text(entry.title)
                        .font(entry.look.font(size: entry.look.size * 0.85, weight: entry.look.weight.font))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                .lookStyle(entry.look)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: entry.look.alignment)
                .systemMargins(extra: entry.look.inset)
                .clipped()
            }
        }
        .seeThroughBackground(entry.backdrop, look: entry.look)
    }
}

struct CountdownWidget: Widget {
    static let kind = "WidgetSimpleCountdown"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: CountdownIntent.self, provider: CountdownProvider()) { entry in
            CountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("Countdown")
        .description("Days until a date, or since it, in your font and colour.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
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

    @Parameter(title: "See-through ID") var identity: WidgetIdentity?

    init() {}

    var zones: [String] {
        [city1, city2, city3, city4].compactMap { $0 }.filter { !$0.isEmpty }
    }
}

struct WorldClockEntry: TimelineEntry {
    var date: Date
    let look: Look
    let zones: [String]
    var backdrop: Backdrop = .plain
}

struct WorldClockProvider: AppIntentTimelineProvider {
    typealias Entry = WorldClockEntry
    typealias Intent = WorldClockIntent

    func placeholder(in context: Context) -> WorldClockEntry {
        WorldClockEntry(date: .now, look: SharedStore.shared.loadLook(),
                        zones: ["Europe/Berlin", "America/New_York", "Asia/Tokyo"])
    }

    func snapshot(for configuration: WorldClockIntent, in context: Context) async -> WorldClockEntry {
        entry(configuration, context)
    }

    func timeline(for configuration: WorldClockIntent, in context: Context) async -> Timeline<WorldClockEntry> {
        // A minute timeline like the launcher clock; the times are text, not live views.
        let first = entry(configuration, context)
        let start = Calendar.current.dateInterval(of: .minute, for: .now)?.start ?? .now
        let entries = (0..<60).map { minute -> WorldClockEntry in
            var next = first
            next.date = start.addingTimeInterval(Double(minute) * 60)
            return next
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func entry(_ configuration: WorldClockIntent, _ context: Context) -> WorldClockEntry {
        FontRegistry.registerAllOnce()
        var entry = WorldClockEntry(date: .now, look: SharedStore.shared.loadLook(), zones: configuration.zones)
        entry.backdrop = SeeThrough.backdrop(kind: WorldClockWidget.kind, identity: configuration.identity,
                                             content: configuration.zones, names: configuration.zones.map(cityName),
                                             clock: .off, context: context)
        return entry
    }
}

/// "Europe/Berlin" → "Berlin".
func cityName(_ identifier: String) -> String {
    identifier.split(separator: "/").last.map(String.init)?.replacingOccurrences(of: "_", with: " ")
        ?? identifier
}

struct WorldClockWidgetView: View {
    let entry: WorldClockEntry

    var body: some View {
        VStack(alignment: entry.look.align.horizontal, spacing: entry.look.size * 0.35) {
            ForEach(entry.zones.prefix(4), id: \.self) { identifier in
                if let zone = TimeZone(identifier: identifier) {
                    HStack(spacing: Spacing.xs) {
                        Text(cityName(identifier))
                            .font(entry.look.font(size: entry.look.size * 0.62, weight: entry.look.weight.font))
                            .opacity(0.75)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: Spacing.xxs)
                        Text(zoneTime(entry.date, zone))
                            .font(entry.look.font(size: entry.look.size * 0.78, weight: entry.look.weight.font))
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .lookStyle(entry.look)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: entry.look.alignment)
        .systemMargins(extra: entry.look.inset)
        .clipped()
        .seeThroughBackground(entry.backdrop, look: entry.look)
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

    @Parameter(title: "See-through ID") var identity: WidgetIdentity?

    init() {}
}

struct SpacerEntry: TimelineEntry {
    var date: Date
    let look: Look
    var backdrop: Backdrop = .plain
}

struct SpacerProvider: AppIntentTimelineProvider {
    typealias Entry = SpacerEntry
    typealias Intent = SpacerIntent

    func placeholder(in context: Context) -> SpacerEntry {
        SpacerEntry(date: .now, look: SharedStore.shared.loadLook())
    }

    func snapshot(for configuration: SpacerIntent, in context: Context) async -> SpacerEntry {
        entry(configuration, context)
    }

    func timeline(for configuration: SpacerIntent, in context: Context) async -> Timeline<SpacerEntry> {
        Timeline(entries: [entry(configuration, context)], policy: .never)
    }

    private func entry(_ configuration: SpacerIntent, _ context: Context) -> SpacerEntry {
        var entry = SpacerEntry(date: .now, look: SharedStore.shared.loadLook())
        entry.backdrop = SeeThrough.backdrop(kind: SpacerWidget.kind, identity: configuration.identity,
                                             content: [], names: [], clock: .off, context: context)
        return entry
    }
}

struct SpacerWidget: Widget {
    static let kind = "WidgetSimpleSpacer"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: SpacerIntent.self, provider: SpacerProvider()) { entry in
            Color.clear
                .accessibilityHidden(true)
                .seeThroughBackground(entry.backdrop, look: entry.look)
        }
        .configurationDisplayName("Spacer")
        .description("An empty widget that shows your wallpaper once matched.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

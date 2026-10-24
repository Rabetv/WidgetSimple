import AppIntents
import SwiftUI
import UIKit
import WidgetKit

// The rest of the catalogue: Date & Time, Photo, Greeting, Dashboard, Zen (and Weather,
// compiled only with WEATHER until a data source is chosen). Public API only, no
// network: everything here works offline.

/// One entry per minute for an hour, starting at the current minute.
private func minuteDates(from now: Date = .now) -> [Date] {
    let start = Calendar.current.dateInterval(of: .minute, for: now)?.start ?? now
    return (0..<60).map { start.addingTimeInterval(Double($0) * 60) }
}

// MARK: - Date & Time

enum DateTimeStyle: String, AppEnum {
    case time, timeAndDate, date, calendar

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Style"
    static let caseDisplayRepresentations: [DateTimeStyle: DisplayRepresentation] = [
        .time: "Time",
        .timeAndDate: "Time and date",
        .date: "Date",
        .calendar: "Calendar page",
    ]

    var clock: ClockOption {
        switch self {
        case .time: return .time
        case .timeAndDate: return .timeAndDate
        case .date, .calendar: return .date
        }
    }
}

struct DateTimeIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Date & Time"
    static let description = IntentDescription("The time, the date, or both, in your font.")

    @Parameter(title: "Style", default: .timeAndDate) var style: DateTimeStyle
    /// A second city under the clock, e.g. "Asia/Tokyo". Empty hides it.
    @Parameter(title: "Second city") var secondZone: String?
    @Parameter(title: "See-through ID") var identity: WidgetIdentity?

    init() {}
}

struct DateTimeEntry: TimelineEntry {
    var date: Date
    let look: Look
    let style: DateTimeStyle
    let secondZone: String?
    var backdrop: Backdrop = .plain
}

struct DateTimeProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DateTimeEntry {
        DateTimeEntry(date: .now, look: SharedStore.shared.loadLook(), style: .timeAndDate, secondZone: nil)
    }

    func snapshot(for configuration: DateTimeIntent, in context: Context) async -> DateTimeEntry {
        entry(configuration, context)
    }

    func timeline(for configuration: DateTimeIntent, in context: Context) async -> Timeline<DateTimeEntry> {
        let first = entry(configuration, context)
        let entries = minuteDates().map { date -> DateTimeEntry in
            var next = first
            next.date = date
            return next
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func entry(_ configuration: DateTimeIntent, _ context: Context) -> DateTimeEntry {
        FontRegistry.registerAllOnce()
        let zone = configuration.secondZone.flatMap { $0.isEmpty ? nil : $0 }
        var entry = DateTimeEntry(date: .now, look: SharedStore.shared.loadLook(), style: configuration.style,
                                  secondZone: zone)
        entry.backdrop = SeeThrough.backdrop(kind: DateTimeWidget.kind, identity: configuration.identity,
                                             content: [configuration.style.rawValue, zone ?? ""], names: [],
                                             clock: .off, context: context)
        return entry
    }
}

struct DateTimeWidgetView: View {
    let entry: DateTimeEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        content.seeThroughBackground(entry.backdrop, look: entry.look)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Text(entry.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
        case .accessoryCircular:
            VStack(spacing: 0) {
                Text(entry.date.formatted(.dateTime.weekday(.abbreviated))).font(.system(size: 10, weight: .medium))
                Text(entry.date.formatted(.dateTime.day())).font(.system(size: 24, weight: .semibold))
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.date.formatted(.dateTime.hour().minute())).font(.system(size: 26, weight: .light))
                Text(entry.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.system(size: 13))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            if entry.style == .calendar {
                calendarPage
            } else {
                // The launcher's clock layout: it fits the clock (and the second city as
                // a line under it) to the widget the same way.
                LauncherFace(look: entry.look, clock: entry.style.clock, date: entry.date, size: faceSize,
                             apps: secondCityLine.map { [$0] } ?? [],
                             color: renderingMode == .fullColor ? entry.look.color : .white)
            }
        }
    }

    private var calendarPage: some View {
        VStack(alignment: entry.look.align.horizontal, spacing: 0) {
            Text(entry.date.formatted(.dateTime.weekday(.wide)))
                .font(entry.look.font(size: entry.look.size * 0.8, weight: entry.look.weight.font))
                .opacity(0.8)
            Text(entry.date.formatted(.dateTime.day()))
                .font(entry.look.font(size: entry.look.size * 3.2, weight: .light))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .widgetAccentable()
            Text(entry.date.formatted(.dateTime.month(.wide).year()))
                .font(entry.look.font(size: entry.look.size * 0.8, weight: entry.look.weight.font))
                .opacity(0.8)
        }
        .lineLimit(1)
        .lookStyle(entry.look)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: entry.look.alignment)
        .systemMargins()
        .clipped()
    }

    private var secondCityLine: String? {
        guard let identifier = entry.secondZone, let zone = TimeZone(identifier: identifier) else { return nil }
        var style = Date.FormatStyle.dateTime.hour().minute()
        style.timeZone = zone
        return "\(cityName(identifier)) \(entry.date.formatted(style))"
    }

    private var faceSize: FaceSize {
        switch family {
        case .systemSmall: return .small
        case .systemMedium: return .medium
        default: return .large
        }
    }
}

struct DateTimeWidget: Widget {
    static let kind = "WidgetSimpleDateTime"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: DateTimeIntent.self, provider: DateTimeProvider()) { entry in
            DateTimeWidgetView(entry: entry)
        }
        .configurationDisplayName("Date & Time")
        .description("The time and date in your font, with a second city if you like.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryInline, .accessoryCircular, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

// MARK: - Photo

/// A photo from the library the app keeps in the App Group (stock + the person's own).
struct PhotoEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Photo"
    static let defaultQuery = PhotoQuery()

    let id: String
    let title: String
    let credit: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(credit)")
    }

    init(_ photo: PhotoAsset) {
        id = photo.id
        title = photo.title
        credit = photo.credit ?? ""
    }
}

struct PhotoQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PhotoEntity] {
        let photos = SharedStore.shared.loadPhotos()
        return identifiers.compactMap { id in photos.first { $0.id == id }.map(PhotoEntity.init) }
    }

    func suggestedEntities() async throws -> [PhotoEntity] {
        SharedStore.shared.loadPhotos().map(PhotoEntity.init)
    }

    func defaultResult() async -> PhotoEntity? {
        SharedStore.shared.loadPhotos().first.map(PhotoEntity.init)
    }
}

struct PhotoIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Photo"
    static let description = IntentDescription("A photo from the library in the app.")

    @Parameter(title: "Photo") var photo: PhotoEntity?
    @Parameter(title: "Shuffle every hour", default: false) var shuffle: Bool

    init() {}
}

struct PhotoEntry: TimelineEntry {
    var date: Date
    let photo: PhotoAsset?
    let image: UIImage?
}

struct PhotoProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PhotoEntry {
        PhotoEntry(date: .now, photo: nil, image: nil)
    }

    func snapshot(for configuration: PhotoIntent, in context: Context) async -> PhotoEntry {
        entry(for: pick(configuration, offset: 0), at: .now)
    }

    func timeline(for configuration: PhotoIntent, in context: Context) async -> Timeline<PhotoEntry> {
        guard configuration.shuffle else {
            return Timeline(entries: [entry(for: pick(configuration, offset: 0), at: .now)], policy: .never)
        }
        // Six hours of photos, one an hour; decoding all six now keeps the widget from
        // reading files later, but costs memory, so only the first is decoded up front.
        let start = Calendar.current.dateInterval(of: .hour, for: .now)?.start ?? .now
        let first = entry(for: pick(configuration, offset: 0), at: .now)
        let rest = (1..<6).map { hour in
            entry(for: pick(configuration, offset: hour), at: start.addingTimeInterval(Double(hour) * 3600))
        }
        return Timeline(entries: [first] + rest, policy: .atEnd)
    }

    /// The chosen photo, or with shuffle on, the one `offset` hours on in the library.
    private func pick(_ configuration: PhotoIntent, offset: Int) -> PhotoAsset? {
        let photos = SharedStore.shared.loadPhotos()
        guard !photos.isEmpty else { return nil }
        let chosenIndex = configuration.photo.flatMap { chosen in photos.firstIndex { $0.id == chosen.id } } ?? 0
        guard configuration.shuffle else { return photos[chosenIndex] }
        let hour = Calendar.current.component(.hour, from: .now)
        return photos[(chosenIndex + hour + offset) % photos.count]
    }

    private func entry(for photo: PhotoAsset?, at date: Date) -> PhotoEntry {
        PhotoEntry(date: date, photo: photo, image: photo.flatMap { SharedStore.shared.loadPhotoImage($0) })
    }
}

/// Fills the frame with the image, keeping the focal point as central as the crop
/// allows; the same photo crops differently on a small, medium and large widget.
struct FocalImage: View {
    let image: UIImage
    let focal: CGPoint

    var body: some View {
        GeometryReader { geo in
            let size = image.size
            let scale = max(geo.size.width / max(size.width, 1), geo.size.height / max(size.height, 1))
            let width = size.width * scale, height = size.height * scale
            let x = min(max(geo.size.width / 2 - focal.x * width, geo.size.width - width), 0)
            let y = min(max(geo.size.height / 2 - focal.y * height, geo.size.height - height), 0)
            Image(uiImage: image)
                .resizable()
                .frame(width: width, height: height)
                .offset(x: x, y: y)
        }
        .clipped()
    }
}

struct PhotoWidgetView: View {
    let entry: PhotoEntry

    var body: some View {
        Group {
            if entry.image == nil {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 28, weight: .light))
                    Text("Open WidgetSimple once to load the photos.")
                        .font(.system(size: 13, weight: .medium))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.secondary)
                .systemMargins()
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(Text(entry.photo?.title ?? String(localized: "Photo")))
        .containerBackground(for: .widget) {
            if let image = entry.image, let photo = entry.photo {
                FocalImage(image: image, focal: CGPoint(x: photo.focalX, y: photo.focalY))
            } else {
                Color.clear
            }
        }
    }
}

struct PhotoWidget: Widget {
    static let kind = "WidgetSimplePhoto"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: PhotoIntent.self, provider: PhotoProvider()) { entry in
            PhotoWidgetView(entry: entry)
        }
        .configurationDisplayName("Photo")
        .description("A photo from the library, cropped around what matters.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Greeting

struct GreetingIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Greeting"
    static let description = IntentDescription("Good morning, good evening — with your name if you like.")

    @Parameter(title: "Name") var name: String?
    @Parameter(title: "See-through ID") var identity: WidgetIdentity?

    init() {}
}

struct GreetingEntry: TimelineEntry {
    var date: Date
    let look: Look
    let name: String?
    var backdrop: Backdrop = .plain
}

struct GreetingProvider: AppIntentTimelineProvider {
    /// The hours the greeting changes at.
    static let boundaries = [5, 12, 18, 22]

    func placeholder(in context: Context) -> GreetingEntry {
        GreetingEntry(date: .now, look: SharedStore.shared.loadLook(), name: nil)
    }

    func snapshot(for configuration: GreetingIntent, in context: Context) async -> GreetingEntry {
        entry(configuration, context, at: .now)
    }

    func timeline(for configuration: GreetingIntent, in context: Context) async -> Timeline<GreetingEntry> {
        let now = Date.now
        let calendar = Calendar.current
        let first = entry(configuration, context, at: now)
        // An entry at each of the next four changes, then ask again.
        var dates: [Date] = []
        for dayOffset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) else { continue }
            for hour in Self.boundaries {
                if let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day), date > now {
                    dates.append(date)
                }
            }
        }
        let later = dates.prefix(4).map { date -> GreetingEntry in
            var next = first
            next.date = date
            return next
        }
        return Timeline(entries: [first] + later, policy: .atEnd)
    }

    private func entry(_ configuration: GreetingIntent, _ context: Context, at date: Date) -> GreetingEntry {
        FontRegistry.registerAllOnce()
        let name = configuration.name.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
        var entry = GreetingEntry(date: date, look: SharedStore.shared.loadLook(), name: name)
        entry.backdrop = SeeThrough.backdrop(kind: GreetingWidget.kind, identity: configuration.identity,
                                             content: [name ?? ""], names: [name ?? ""],
                                             clock: .off, context: context)
        return entry
    }
}

struct GreetingWidgetView: View {
    let entry: GreetingEntry

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: entry.date)
        let base: String
        switch hour {
        case 5..<12: base = String(localized: "Good morning")
        case 12..<18: base = String(localized: "Good afternoon")
        case 18..<22: base = String(localized: "Good evening")
        default: base = String(localized: "Good night")
        }
        return entry.name.map { "\(base), \($0)" } ?? base
    }

    var body: some View {
        VStack(alignment: entry.look.align.horizontal, spacing: Spacing.xxs) {
            Text(greeting)
                .font(entry.look.font(size: entry.look.size * 1.3, weight: entry.look.weight.font))
                .lineLimit(3)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(entry.look.align.text)
                .widgetAccentable()
            Text(entry.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(entry.look.font(size: entry.look.size * 0.7, weight: entry.look.weight.font))
                .opacity(0.75)
                .lineLimit(1)
        }
        .lookStyle(entry.look)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: entry.look.alignment)
        .systemMargins()
        .clipped()
        .seeThroughBackground(entry.backdrop, look: entry.look)
    }
}

struct GreetingWidget: Widget {
    static let kind = "WidgetSimpleGreeting"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: GreetingIntent.self, provider: GreetingProvider()) { entry in
            GreetingWidgetView(entry: entry)
        }
        .configurationDisplayName("Greeting")
        .description("Changes with the time of day.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Dashboard (clock, battery, storage)

/// Device readings a widget may show with public API. Uptime is left out on purpose:
/// boot time is a required-reason API with no approved reason for showing it.
struct DeviceReadings {
    /// 0…1, nil when iOS doesn't report it to the extension.
    var battery: Double?
    var charging: Bool
    var freeBytes: Int64?
    var totalBytes: Int64?

    @MainActor
    static func now() -> DeviceReadings {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel
        let state = device.batteryState
        // Disk space: required-reason API, declared in PrivacyInfo (85F4.1, shown to the person).
        let values = try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
        return DeviceReadings(battery: level >= 0 ? Double(level) : nil,
                              charging: state == .charging || state == .full,
                              freeBytes: values?.volumeAvailableCapacityForImportantUsage,
                              totalBytes: values?.volumeTotalCapacity.map { Int64($0) })
    }

    var batteryText: String {
        battery.map { "\(Int(($0 * 100).rounded()))%" } ?? "–"
    }

    var storageText: String {
        guard let freeBytes else { return "–" }
        return ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
    }
}

struct DashboardIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Dashboard"
    static let description = IntentDescription("Clock, battery and free storage.")

    @Parameter(title: "See-through ID") var identity: WidgetIdentity?

    init() {}
}

struct DashboardEntry: TimelineEntry {
    var date: Date
    let look: Look
    let readings: DeviceReadings
    var backdrop: Backdrop = .plain
}

struct DashboardProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DashboardEntry {
        DashboardEntry(date: .now, look: SharedStore.shared.loadLook(),
                       readings: DeviceReadings(battery: 0.8, charging: false, freeBytes: nil, totalBytes: nil))
    }

    func snapshot(for configuration: DashboardIntent, in context: Context) async -> DashboardEntry {
        entry(configuration, context, readings: await MainActor.run { DeviceReadings.now() })
    }

    func timeline(for configuration: DashboardIntent, in context: Context) async -> Timeline<DashboardEntry> {
        // The clock ticks every minute; the readings refresh when the timeline is asked
        // for again after half an hour (a widget can't read the future battery level).
        let first = entry(configuration, context, readings: await MainActor.run { DeviceReadings.now() })
        let entries = minuteDates().prefix(30).map { date -> DashboardEntry in
            var next = first
            next.date = date
            return next
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func entry(_ configuration: DashboardIntent, _ context: Context, readings: DeviceReadings) -> DashboardEntry {
        FontRegistry.registerAllOnce()
        var entry = DashboardEntry(date: .now, look: SharedStore.shared.loadLook(), readings: readings)
        entry.backdrop = SeeThrough.backdrop(kind: DashboardWidget.kind, identity: configuration.identity,
                                             content: [], names: [], clock: .time, context: context)
        return entry
    }
}

struct DashboardWidgetView: View {
    let entry: DashboardEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content.seeThroughBackground(entry.backdrop, look: entry.look)
    }

    @ViewBuilder
    private var content: some View {
        if family == .accessoryCircular {
            Gauge(value: entry.readings.battery ?? 0) {
                Image(systemName: entry.readings.charging ? "bolt.fill" : "battery.100")
            } currentValueLabel: {
                Text(entry.readings.batteryText)
            }
            .gaugeStyle(.accessoryCircular)
        } else {
            VStack(alignment: entry.look.align.horizontal, spacing: Spacing.xs) {
                if family != .systemSmall {
                    Text(entry.date.formatted(.dateTime.hour().minute()))
                        .font(entry.look.font(size: entry.look.size * 2, weight: .light))
                        .monospacedDigit()
                        .widgetAccentable()
                    Text(entry.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(entry.look.font(size: entry.look.size * 0.7, weight: entry.look.weight.font))
                        .opacity(0.75)
                }
                reading(icon: entry.readings.charging ? "battery.100.bolt" : "battery.75",
                        label: String(localized: "Battery"), value: entry.readings.batteryText)
                reading(icon: "internaldrive", label: String(localized: "Free"), value: entry.readings.storageText)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .lookStyle(entry.look)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: entry.look.alignment)
            .systemMargins()
            .clipped()
        }
    }

    private func reading(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: entry.look.size * 0.75))
                .frame(width: entry.look.size * 1.1)
            Text(value)
                .font(entry.look.font(size: entry.look.size * 0.9, weight: entry.look.weight.font))
                .monospacedDigit()
            Text(label)
                .font(entry.look.font(size: entry.look.size * 0.7, weight: entry.look.weight.font))
                .opacity(0.7)
        }
        .accessibilityElement(children: .combine)
    }
}

struct DashboardWidget: Widget {
    static let kind = "WidgetSimpleDashboard"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: DashboardIntent.self, provider: DashboardProvider()) { entry in
            DashboardWidgetView(entry: entry)
        }
        .configurationDisplayName("Dashboard")
        .description("Clock, battery and free storage at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular])
        .contentMarginsDisabled()
    }
}

// MARK: - Zen

struct ZenIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Zen"
    static let description = IntentDescription("A slow breath and a quiet line, every minute.")

    @Parameter(title: "See-through ID") var identity: WidgetIdentity?

    init() {}
}

struct ZenEntry: TimelineEntry {
    var date: Date
    let look: Look
    var step: Int
    var backdrop: Backdrop = .plain
}

struct ZenProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ZenEntry {
        ZenEntry(date: .now, look: SharedStore.shared.loadLook(), step: 0)
    }

    func snapshot(for configuration: ZenIntent, in context: Context) async -> ZenEntry {
        entry(configuration, context)
    }

    /// Widgets can't animate continuously. Each minute is one step: the circle changes
    /// size and the line changes, and a live progress ring fills over the minute.
    func timeline(for configuration: ZenIntent, in context: Context) async -> Timeline<ZenEntry> {
        let first = entry(configuration, context)
        let entries = minuteDates().enumerated().map { index, date -> ZenEntry in
            var next = first
            next.date = date
            next.step = first.step + index
            return next
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func entry(_ configuration: ZenIntent, _ context: Context) -> ZenEntry {
        FontRegistry.registerAllOnce()
        let minute = Calendar.current.component(.minute, from: .now)
        var entry = ZenEntry(date: .now, look: SharedStore.shared.loadLook(), step: minute)
        entry.backdrop = SeeThrough.backdrop(kind: ZenWidget.kind, identity: configuration.identity,
                                             content: [], names: [], clock: .off, context: context)
        return entry
    }
}

struct ZenWidgetView: View {
    let entry: ZenEntry
    @Environment(\.widgetFamily) private var family

    private static let lines: [LocalizedStringResource] = [
        "Breathe in", "Hold", "Breathe out", "Rest",
        "Notice your shoulders", "Unclench your jaw", "One thing at a time", "Look far away",
    ]
    /// Circle sizes for inhale, hold, exhale, rest.
    private static let phases: [CGFloat] = [1, 1, 0.62, 0.62]

    var body: some View {
        // Ring beside the line on a medium widget, above it on a small one.
        let stack = family == .systemSmall
            ? AnyLayout(VStackLayout(spacing: Spacing.xs))
            : AnyLayout(HStackLayout(spacing: Spacing.m))
        stack {
            ZStack {
                Circle()
                    .stroke(lineWidth: 1)
                    .opacity(0.35)
                Circle()
                    .fill(.white.opacity(0.18))
                    .scaleEffect(Self.phases[entry.step % Self.phases.count])
                ProgressView(timerInterval: entry.date...entry.date.addingTimeInterval(60), countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)
                .tint(entry.look.color)
            }
            .frame(width: ringSize, height: ringSize)
            .accessibilityHidden(true)

            Text(Self.lines[entry.step % Self.lines.count])
                .font(entry.look.font(size: entry.look.size, weight: entry.look.weight.font))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(family == .systemSmall ? .center : entry.look.align.text)
                .frame(maxWidth: .infinity,
                       alignment: family == .systemSmall
                           ? .center
                           : Alignment(horizontal: entry.look.align.horizontal, vertical: .center))
        }
        .lookStyle(entry.look)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .systemMargins()
        .clipped()
        .seeThroughBackground(entry.backdrop, look: entry.look)
    }

    private var ringSize: CGFloat {
        family == .systemSmall ? 54 : 84
    }
}

struct ZenWidget: Widget {
    static let kind = "WidgetSimpleZen"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: ZenIntent.self, provider: ZenProvider()) { entry in
            ZenWidgetView(entry: entry)
        }
        .configurationDisplayName("Zen")
        .description("A slow breath and a quiet line, every minute.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

#if WEATHER
// MARK: - Weather (not built until a source is chosen)
//
// WeatherKit needs the capability on both App IDs and the Apple attribution; Open-Meteo
// needs no key but its free tier is non-commercial, so a paid app needs its paid plan.
// Either is a product decision (see CHANGES.md). Until then this kind only exists
// behind WEATHER, with placeholder readings, so nothing fake ships.

struct WeatherReading {
    var temperature: Measurement<UnitTemperature>
    var symbol: String
    var condition: String
}

protocol WeatherSource {
    func current() async -> WeatherReading?
}

struct PlaceholderWeatherSource: WeatherSource {
    func current() async -> WeatherReading? {
        WeatherReading(temperature: Measurement(value: 21, unit: .celsius), symbol: "sun.max", condition: "Clear")
    }
}

struct WeatherIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Weather"
    static let description = IntentDescription("Now, in your font.")

    @Parameter(title: "See-through ID") var identity: WidgetIdentity?

    init() {}
}

struct WeatherEntry: TimelineEntry {
    var date: Date
    let look: Look
    let reading: WeatherReading?
    var backdrop: Backdrop = .plain
}

struct WeatherProvider: AppIntentTimelineProvider {
    let source: WeatherSource = PlaceholderWeatherSource()

    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(date: .now, look: SharedStore.shared.loadLook(), reading: nil)
    }

    func snapshot(for configuration: WeatherIntent, in context: Context) async -> WeatherEntry {
        await entry(configuration, context)
    }

    func timeline(for configuration: WeatherIntent, in context: Context) async -> Timeline<WeatherEntry> {
        Timeline(entries: [await entry(configuration, context)], policy: .after(.now.addingTimeInterval(3600)))
    }

    private func entry(_ configuration: WeatherIntent, _ context: Context) async -> WeatherEntry {
        var entry = WeatherEntry(date: .now, look: SharedStore.shared.loadLook(), reading: await source.current())
        entry.backdrop = SeeThrough.backdrop(kind: WeatherWidget.kind, identity: configuration.identity,
                                             content: [], names: [], clock: .off, context: context)
        return entry
    }
}

struct WeatherWidgetView: View {
    let entry: WeatherEntry

    var body: some View {
        VStack(alignment: entry.look.align.horizontal, spacing: Spacing.xxs) {
            Image(systemName: entry.reading?.symbol ?? "cloud")
                .font(.system(size: entry.look.size * 1.4))
            Text(entry.reading.map { $0.temperature.formatted(.measurement(width: .narrow)) } ?? "–")
                .font(entry.look.font(size: entry.look.size * 2.2, weight: .light))
            Text(entry.reading?.condition ?? "")
                .font(entry.look.font(size: entry.look.size * 0.8, weight: entry.look.weight.font))
                .opacity(0.75)
        }
        .lookStyle(entry.look)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: entry.look.alignment)
        .systemMargins()
        .seeThroughBackground(entry.backdrop, look: entry.look)
    }
}

struct WeatherWidget: Widget {
    static let kind = "WidgetSimpleWeather"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: WeatherIntent.self, provider: WeatherProvider()) { entry in
            WeatherWidgetView(entry: entry)
        }
        .configurationDisplayName("Weather")
        .description("Current temperature and conditions.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
#endif

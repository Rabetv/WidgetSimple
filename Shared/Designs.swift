import SwiftUI
import WidgetKit

// Saved designs: templates built and named in the app, saved in the App Group, and
// picked per widget in Edit Widget (the Apps widget's Design parameter). A design is
// a stack of blocks — Open App slots, clocks, dates, words, modules, empty space — in
// its own look. What sits behind it (clear, photo, matched wallpaper piece) follows
// the shared see-through setting, exactly as for the Apps widget without a design.

/// What one block of a design shows.
enum BlockKind: String, Codable, CaseIterable, Identifiable {
    /// Open App slots: App 1, App 2… in order, filled with the apps picked in Edit Widget.
    case apps
    case text, quote, greeting
    case digitalClock, analogClock, wordClock, worldClock
    case bigDate, weekStrip, monthGrid, progress, daysUntil, moon
    case countdownRing, health, battery, vinyl, calendarIcon
    case spacer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apps: return "Open App"
        case .text: return "Text"
        case .quote: return "Line of the day"
        case .greeting: return "Greeting"
        case .digitalClock: return "Digital clock"
        case .analogClock: return "Analog clock"
        case .wordClock: return "Word clock"
        case .worldClock: return "World clock"
        case .bigDate: return "Big date"
        case .weekStrip: return "Week strip"
        case .monthGrid: return "Month"
        case .progress: return "Progress"
        case .daysUntil: return "Days until"
        case .moon: return "Moon phase"
        case .countdownRing: return "Countdown ring"
        case .health: return "Health chart"
        case .battery: return "Battery"
        case .vinyl: return "Vinyl deck"
        case .calendarIcon: return "Calendar page"
        case .spacer: return "Empty space"
        }
    }

    /// The module drawing a block shows, for the six structural modules.
    var module: ModuleKind? {
        switch self {
        case .analogClock: return .clock
        case .countdownRing: return .countdown
        case .health: return .health
        case .battery: return .battery
        case .vinyl: return .vinyl
        case .calendarIcon: return .calendar
        default: return nil
        }
    }

    /// The groups the editor's block picker shows.
    static let groups: [(title: String, kinds: [BlockKind])] = [
        ("Apps", [.apps]),
        ("Time", [.digitalClock, .analogClock, .wordClock, .worldClock]),
        ("Date", [.bigDate, .weekStrip, .monthGrid, .progress, .daysUntil, .moon]),
        ("Words", [.text, .quote, .greeting]),
        ("Modules", [.countdownRing, .battery, .health, .vinyl, .calendarIcon]),
        ("Space", [.spacer]),
    ]

    fileprivate var defaultWidth: BlockWidth {
        switch self {
        case .analogClock, .countdownRing, .health, .battery, .vinyl, .calendarIcon, .moon: return .half
        default: return .full
        }
    }

    fileprivate var defaultHeight: BlockHeight {
        switch self {
        case .apps, .monthGrid: return .large
        case .text, .quote, .greeting, .weekStrip, .spacer: return .small
        default: return .medium
        }
    }
}

/// A block takes the whole row, or half of it beside another half block.
enum BlockWidth: String, Codable, CaseIterable, Identifiable {
    case full, half
    var id: String { rawValue }
    var title: String { self == .full ? "Full" : "Half" }
}

/// The share of the widget's height a block's row takes, relative to the other rows.
enum BlockHeight: String, Codable, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    var title: String {
        switch self {
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        }
    }
    var weight: CGFloat {
        switch self {
        case .small: return 1
        case .medium: return 2
        case .large: return 3
        }
    }
}

/// How the big date block sets the date.
enum DateStyle: String, Codable, CaseIterable, Identifiable {
    /// "MON 26"
    case compact
    /// Weekday, a big day number, the month.
    case stacked
    /// "Monday" over "26 October 2026".
    case full
    var id: String { rawValue }
    var title: String {
        switch self {
        case .compact: return "Mon 26"
        case .stacked: return "Stacked"
        case .full: return "Full"
        }
    }
}

enum ProgressScope: String, Codable, CaseIterable, Identifiable {
    case year, month, day
    var id: String { rawValue }
    var title: String {
        switch self {
        case .year: return "Year"
        case .month: return "Month"
        case .day: return "Day"
        }
    }
}

enum ProgressStyle: String, Codable, CaseIterable, Identifiable {
    /// "299/365"
    case fraction
    /// "81%"
    case percent
    /// One dot per day (per hour for the day), the passed ones filled.
    case dots
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fraction: return "299/365"
        case .percent: return "81%"
        case .dots: return "Dots"
        }
    }
}

/// Where a block sits in a placed design: fractions 0…1 of the widget, top-left origin.
/// Fractions, not points, so one design fills every iPhone's widget of its size.
struct BlockFrame: Codable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    /// The frame in points, in a widget `area` big.
    func rect(in area: CGSize) -> CGRect {
        CGRect(x: x * area.width, y: y * area.height, width: width * area.width, height: height * area.height)
    }

    /// The frame of `rect` in a widget `area` big.
    init(_ rect: CGRect, in area: CGSize) {
        let w = max(area.width, 1), h = max(area.height, 1)
        self.init(x: rect.minX / w, y: rect.minY / h, width: rect.width / w, height: rect.height / h)
    }

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Kept whole inside the widget: no wider or taller than it, never past an edge.
    var inside: BlockFrame {
        let w = min(max(width, 0.01), 1), h = min(max(height, 0.01), 1)
        return BlockFrame(x: min(max(x, 0), 1 - w), y: min(max(y, 0), 1 - h), width: w, height: h)
    }
}

/// One block of a design and its settings. Only the fields its kind uses matter.
struct DesignBlock: Codable, Hashable, Identifiable {
    static let maxSlots = 12
    static let defaultZones = ["Europe/Berlin", "America/New_York", "Asia/Tokyo"]

    var id: UUID
    var kind: BlockKind
    var width: BlockWidth
    var height: BlockHeight
    /// Open App: how many slots.
    var slots: Int
    /// Text; the greeting's name; the days-until title.
    var text: String
    /// Line of the day: one line per day, in turn.
    var lines: [String]
    /// World clock: up to four time zone identifiers.
    var zones: [String]
    /// Days until: the date counted to (or since, once it has passed).
    var date: Date?
    /// Digital clock: time, time and date, or date.
    var clock: ClockOption
    var dateStyle: DateStyle
    var scope: ProgressScope
    var progressStyle: ProgressStyle
    /// Where the block sits, once the design is placed by hand; nil keeps it in rows.
    var frame: BlockFrame?
    /// This block's own style (font, size, colour, alignment…); nil follows the design's.
    var look: Look?

    init(_ kind: BlockKind) {
        id = UUID()
        self.kind = kind
        width = kind.defaultWidth
        height = kind.defaultHeight
        slots = 4
        text = ""
        lines = []
        zones = Self.defaultZones
        date = nil
        clock = .time
        dateStyle = .stacked
        scope = .year
        progressStyle = .dots
        frame = nil
        look = nil
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, width, height, slots, text, lines, zones, date, clock, dateStyle, scope, progressStyle, frame, look
    }

    /// Tolerant, like `Look`: an unknown value falls back to the default, and only a
    /// kind this build does not know drops the block (see `WidgetDesign`).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var d = DesignBlock(try c.decode(BlockKind.self, forKey: .kind))
        d.id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? d.id
        d.width = (try? c.decodeIfPresent(BlockWidth.self, forKey: .width)) ?? d.width
        d.height = (try? c.decodeIfPresent(BlockHeight.self, forKey: .height)) ?? d.height
        d.slots = min(max((try? c.decodeIfPresent(Int.self, forKey: .slots)) ?? d.slots, 1), Self.maxSlots)
        d.text = (try? c.decodeIfPresent(String.self, forKey: .text)) ?? d.text
        d.lines = (try? c.decodeIfPresent([String].self, forKey: .lines)) ?? d.lines
        d.zones = (try? c.decodeIfPresent([String].self, forKey: .zones)) ?? d.zones
        d.date = try? c.decodeIfPresent(Date.self, forKey: .date)
        d.clock = (try? c.decodeIfPresent(ClockOption.self, forKey: .clock)) ?? d.clock
        d.dateStyle = (try? c.decodeIfPresent(DateStyle.self, forKey: .dateStyle)) ?? d.dateStyle
        d.scope = (try? c.decodeIfPresent(ProgressScope.self, forKey: .scope)) ?? d.scope
        d.progressStyle = (try? c.decodeIfPresent(ProgressStyle.self, forKey: .progressStyle)) ?? d.progressStyle
        d.frame = (try? c.decodeIfPresent(BlockFrame.self, forKey: .frame))?.inside
        d.look = try? c.decodeIfPresent(Look.self, forKey: .look)
        self = d
    }

    /// Whether the block changes from one minute to the next.
    var followsMinute: Bool {
        switch kind {
        case .digitalClock, .analogClock, .wordClock, .worldClock, .countdownRing: return true
        case .progress: return scope == .day
        default: return false
        }
    }
}

/// One saved design: a name, its own look, and its blocks from top to bottom.
struct WidgetDesign: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    /// Font, size, ink, case and shadow of everything the design draws. Its
    /// `background` is not used: the background is the shared one, set once.
    var look: Look
    var blocks: [DesignBlock]
    /// The widget size the design is placed for. A placed design only draws in a widget
    /// of this size; anywhere else it asks to be resized (see `DesignFace`).
    var canvas: FaceSize

    init(id: UUID = UUID(), name: String, look: Look = Look(), blocks: [DesignBlock], canvas: FaceSize = .medium) {
        self.id = id
        self.name = name
        self.look = look
        self.blocks = blocks
        self.canvas = canvas
    }

    enum CodingKeys: String, CodingKey { case id, name, look, blocks, canvas }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        look = (try? c.decodeIfPresent(Look.self, forKey: .look)) ?? Look()
        let lossy = (try? c.decodeIfPresent([Lossy<DesignBlock>].self, forKey: .blocks)) ?? []
        blocks = lossy.compactMap(\.value)
        canvas = (try? c.decodeIfPresent(FaceSize.self, forKey: .canvas)) ?? .medium
    }

    /// Whether the blocks were placed by hand (in the sandbox or a template), rather
    /// than stacked in rows.
    var isPlaced: Bool { blocks.contains { $0.frame != nil } }

    /// The design with every block placed where its row put it, for `canvas`: what the
    /// sandbox starts from the first time it opens a design made of rows.
    func placed() -> WidgetDesign {
        guard !isPlaced else { return self }
        let area = canvas.pointSize
        let rects = DesignFace(design: self, date: .now, size: canvas, color: .white).rowRects(in: area)
        var next = self
        for index in next.blocks.indices {
            if let rect = rects[next.blocks[index].id] {
                next.blocks[index].frame = BlockFrame(rect, in: area).inside
            }
        }
        return next
    }

    /// The name shown in Edit Widget and the app; never empty.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Untitled design") : trimmed
    }

    /// Open App slots in the whole design, at most 12 (the apps Edit Widget offers).
    var slotCount: Int {
        min(blocks.filter { $0.kind == .apps }.reduce(0) { $0 + $1.slots }, DesignBlock.maxSlots)
    }

    /// Whether the widget has to redraw every minute.
    var followsMinute: Bool { blocks.contains(where: \.followsMinute) }

    /// When a design that does not follow the minute next looks different: midnight,
    /// the next greeting, or half an hour for the battery.
    func nextChange(after date: Date) -> Date {
        let calendar = Calendar.current
        var next = calendar.nextDate(after: date, matching: DateComponents(hour: 0, minute: 0),
                                     matchingPolicy: .nextTime) ?? date.addingTimeInterval(3600)
        if blocks.contains(where: { $0.kind == .greeting }) {
            for hour in Greeting.boundaries {
                if let boundary = calendar.nextDate(after: date, matching: DateComponents(hour: hour, minute: 0),
                                                    matchingPolicy: .nextTime) {
                    next = min(next, boundary)
                }
            }
        }
        if blocks.contains(where: { $0.kind == .battery }) {
            next = min(next, date.addingTimeInterval(30 * 60))
        }
        return next
    }

    /// The design a new one starts from: a clock beside the battery, four apps below.
    static func starter(name: String, look: Look) -> WidgetDesign {
        var apps = DesignBlock(.apps)
        apps.slots = 4
        return WidgetDesign(name: name, look: look, blocks: [DesignBlock(.analogClock), DesignBlock(.battery), apps])
    }
}

/// Decodes what it can and keeps going: one unknown block never loses the design.
private struct Lossy<Value: Decodable>: Decodable {
    let value: Value?
    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

/// Saved as its raw value ("small", "medium"…), as a design's canvas.
extension FaceSize: Codable {}


// MARK: - Face

/// What the Apps widget shows with a design picked: the blocks in rows, top to bottom.
/// A full block takes its row; two half blocks in a row share it. Rows split the height
/// by their blocks' S / M / L weight. Shared by the widget and the app's previews, so a
/// preview is exactly what lands on the Home Screen.
struct DesignFace<Cell: View>: View {
    let design: WidgetDesign
    let date: Date
    let size: FaceSize
    /// The picked app names, in Edit Widget's order.
    let apps: [String]
    /// The app's previews: every Open App slot reads "App 1", "App 2"…
    var placeholders = false
    /// The chosen word colour; white on a Clear or Tinted Home Screen.
    let color: Color
    /// The iPhone's charge, 0…1; nil when it is unknown.
    var battery: Double?
    /// Shown in the first Open App block while no app is picked.
    var hint: String = ""
    @ViewBuilder let cell: (Int, AppName) -> Cell

    @Environment(\.widgetRenderingMode) private var renderingMode

    private var look: Look { design.look }
    private var edge: CGFloat { size == .small ? 14 : 18 }
    private var rowGap: CGFloat { size == .small ? 6 : 8 }
    private let columnGap: CGFloat = 10

    var body: some View {
        Group {
            if design.isPlaced && size != design.canvas {
                wrongSize
            } else if design.isPlaced {
                placedBlocks
            } else {
                rowBlocks
            }
        }
        .foregroundStyle(color)
        // Belt and braces, as in `LauncherFace`: nothing may leave the widget.
        .clipped()
    }

    private var rowBlocks: some View {
        // Plain stacks with fixed frames, never offsets: WidgetKit places each app's tap
        // area from the layout, so a word moved only when drawn would not open its app.
        GeometryReader { geo in
            let rows = arrange(in: geo.size)
            VStack(alignment: .leading, spacing: rowGap) {
                ForEach(rows) { row in
                    HStack(spacing: columnGap) {
                        ForEach(row.items) { item in
                            blockView(item)
                                .frame(width: item.size.width, height: item.size.height)
                                .clipped()
                        }
                    }
                    .frame(width: row.width, height: row.height, alignment: row.alignment)
                }
            }
            .padding(edge)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }

    /// Every block where it was placed. `.frame` sizes it and `.position` places it —
    /// both layout, never `.offset` — so an Open App word's tap area is where it is drawn.
    private var placedBlocks: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(place(in: geo.size)) { item in
                    blockView(item)
                        .frame(width: item.size.width, height: item.size.height)
                        .clipped()
                        .position(x: item.rect.midX, y: item.rect.midY)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }

    /// A placed design in a widget of another size: iOS lets anyone resize a widget, so
    /// say which size it was made for instead of squeezing the blocks.
    private var wrongSize: some View {
        Text("This design is \(design.canvas.title) – make the widget \(design.canvas.title)")
            .font(look.font(size: min(look.size, size == .small ? 14 : 17)))
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.6)
            .padding(edge)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shadow(color: look.shadow ? Color.black.opacity(0.45) : .clear, radius: 6, x: 0, y: 3)
    }

    @ViewBuilder
    private func blockView(_ item: Placed) -> some View {
        // A block with its own style draws in it; the others follow the design.
        let blockLook = item.block.look ?? look
        let ink = item.block.look.map { renderingMode == .fullColor ? $0.color : .white } ?? color
        Group {
            if item.block.kind == .apps {
                LauncherFace(look: blockLook, clock: .off, date: date, size: size, apps: slotNames(item),
                             color: ink, hint: item.slotStart == 0 && !placeholders ? hint : "",
                             insets: EdgeInsets(), cell: { index, name in cell(item.slotStart + index, name) })
            } else {
                BlockFace(block: item.block, look: blockLook, date: date, size: size, battery: battery,
                          box: item.size, placeholders: placeholders)
            }
        }
        .foregroundStyle(ink)
    }

    /// The words an Open App block shows: its share of the picked apps, in order.
    private func slotNames(_ item: Placed) -> [String] {
        let end = min(item.slotStart + item.block.slots, DesignBlock.maxSlots)
        guard item.slotStart < end else { return [] }
        return (item.slotStart..<end).compactMap { index in
            if placeholders { return String(localized: "App \(index + 1)") }
            return index < apps.count ? apps[index] : nil
        }
    }

    // MARK: Layout

    struct Placed: Identifiable {
        let block: DesignBlock
        let size: CGSize
        /// The first app index this block shows, for Open App blocks.
        let slotStart: Int
        /// Where the block sits in the widget, for a placed design.
        var rect: CGRect = .zero
        var id: UUID { block.id }
    }

    struct Row: Identifiable {
        let items: [Placed]
        let width: CGFloat
        let height: CGFloat
        /// Where a lone half block sits: where the look aligns the words.
        let alignment: Alignment
        var id: UUID { items[0].id }
    }

    private func arrange(in area: CGSize) -> [Row] {
        // Rows: a full block alone, half blocks in pairs.
        var groups: [[DesignBlock]] = []
        for block in design.blocks {
            if block.width == .half, let last = groups.last, last.count == 1, last[0].width == .half {
                groups[groups.count - 1].append(block)
            } else {
                groups.append([block])
            }
        }
        guard !groups.isEmpty else { return [] }

        let width = max(area.width - edge * 2, 1)
        let weights = groups.map { group in group.map(\.height.weight).max() ?? 1 }
        let total = weights.reduce(0, +)
        let usable = max(area.height - edge * 2 - rowGap * CGFloat(groups.count - 1), 1)
        let half = max((width - columnGap) / 2, 1)
        let alignment = Alignment(horizontal: look.align.horizontal, vertical: .center)

        var rows: [Row] = []
        var slot = 0
        for (index, group) in groups.enumerated() {
            let height = max(usable * weights[index] / total, 1)
            var items: [Placed] = []
            for block in group {
                let size = CGSize(width: block.width == .full ? width : half, height: height)
                items.append(Placed(block: block, size: size, slotStart: slot))
                if block.kind == .apps { slot += block.slots }
            }
            rows.append(Row(items: items, width: width, height: height, alignment: alignment))
        }
        return rows
    }

    /// Where `arrange(in:)` puts each block, in points: the rows' stacks worked out by
    /// hand, so a design of rows can be placed exactly as it looked.
    func rowRects(in area: CGSize) -> [UUID: CGRect] {
        var rects: [UUID: CGRect] = [:]
        var y = edge
        for row in arrange(in: area) {
            let used = row.items.reduce(0) { $0 + $1.size.width } + columnGap * CGFloat(row.items.count - 1)
            var x: CGFloat
            switch row.alignment.horizontal {
            case .center: x = edge + (row.width - used) / 2
            case .trailing: x = edge + row.width - used
            default: x = edge
            }
            for item in row.items {
                rects[item.id] = CGRect(x: x, y: y + (row.height - item.size.height) / 2,
                                        width: item.size.width, height: item.size.height)
                x += item.size.width + columnGap
            }
            y += row.height + rowGap
        }
        return rects
    }

    /// The blocks of a placed design, in points. A block without a frame keeps the
    /// place its row would give it; Open App slots count in block order, as in rows.
    private func place(in area: CGSize) -> [Placed] {
        let fallback = design.blocks.allSatisfy { $0.frame != nil } ? [:] : rowRects(in: area)
        var slot = 0
        return design.blocks.compactMap { block in
            guard let rect = block.frame?.inside.rect(in: area) ?? fallback[block.id] else { return nil }
            let item = Placed(block: block, size: CGSize(width: max(rect.width, 1), height: max(rect.height, 1)),
                              slotStart: slot, rect: rect)
            if block.kind == .apps { slot += block.slots }
            return item
        }
    }
}

extension DesignFace where Cell == AppName {
    /// Names only, no buttons: the app's previews and the widget gallery.
    init(design: WidgetDesign, date: Date, size: FaceSize, apps: [String] = [], placeholders: Bool = false,
         color: Color, battery: Double? = nil) {
        self.init(design: design, date: date, size: size, apps: apps, placeholders: placeholders,
                  color: color, battery: battery) { _, name in name }
    }
}

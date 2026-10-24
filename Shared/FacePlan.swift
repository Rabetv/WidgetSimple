import SwiftUI
import UIKit

// Where everything on a launcher face goes, computed once from the real widget size.
//
// The old face tried candidate layouts with ViewThatFits and let every word shrink on
// its own (minimumScaleFactor), so long names came out smaller than their neighbours,
// columns were ragged and big text clipped. Here the words are measured with the same
// fonts the face draws, one layout is picked, and one scale applies to the whole block.
// The widget and the in-app preview call the same function with the same size, so the
// preview is the widget.

/// The clock's text for one moment.
struct ClockContent: Equatable {
    var big: String
    /// The big line's size as a share of the clock size (a weekday is drawn smaller).
    var bigScale: Double
    var small: String?
    /// Strings the big line will show at other times today; the widest one is measured
    /// so the layout does not jump when the minutes change.
    var bigReferences: [String]

    static func make(date: Date, option: ClockOption, size: FaceSize) -> ClockContent? {
        let time: Date.FormatStyle = .dateTime.hour().minute()
        let dateStyle: Date.FormatStyle = size == .small
            ? .dateTime.weekday(.abbreviated).month(.abbreviated).day()
            : .dateTime.weekday(.wide).month(.wide).day()
        let calendar = Calendar.current
        let references = [10, 22].compactMap { hour in
            calendar.date(bySettingHour: hour, minute: 58, second: 0, of: date)?.formatted(time)
        }
        switch option {
        case .off:
            return nil
        case .time:
            return ClockContent(big: date.formatted(time), bigScale: 1, small: nil, bigReferences: references)
        case .timeAndDate:
            return ClockContent(big: date.formatted(time), bigScale: 1, small: date.formatted(dateStyle),
                                bigReferences: references)
        case .date:
            return ClockContent(big: date.formatted(.dateTime.weekday(.wide)), bigScale: Typography.weekdayRatio,
                                small: date.formatted(.dateTime.month(.wide).day()), bigReferences: [])
        }
    }
}

/// Everything the planner needs; the widget and the preview build it the same way.
struct FacePlanInput {
    var canvas: CGSize
    var insets: EdgeInsets
    var size: FaceSize
    var look: Look
    var layout: LayoutDocument?
    var names: [String]
    var clock: ClockContent?
    var typeFactor: Double = 1
}

struct FacePlan: Equatable {
    struct Name: Equatable {
        var frame: CGRect
        var fontSize: CGFloat
        var weight: NameWeight
        var opacity: Double = 1
        var rotation: Double = 0
        var colorHex: String?
    }

    struct Clock: Equatable {
        var frame: CGRect
        var bigSize: CGFloat
        var smallSize: CGFloat
    }

    var names: [Name] = []
    var clock: Clock?
    var columns = 0
    /// The shared scale the block was drawn at (1 = the size the person picked).
    var scale: Double = 1
    /// The area inside the content margins.
    var content: CGRect = .zero
}

enum FacePlanner {
    static func plan(_ input: FacePlanInput) -> FacePlan {
        if input.layout?.mode == .freeform {
            return freeform(input)
        }
        if input.layout == nil, input.look.arrangement == .free {
            return anchored(input)
        }
        return columns(input)
    }

    // MARK: Columns

    private enum ClockPlacement { case noClock, above, beside }

    private struct Grid {
        var columns: Int
        var columnWidths: [CGFloat]
        var size: CGSize
    }

    /// Clock above or beside a grid of names. Picks the first arrangement, in order of
    /// preference, that fits at full size; if none does, the one that needs the least
    /// shrinking. The clock may shrink a little before the names do.
    private static func columns(_ input: FacePlanInput) -> FacePlan {
        let look = input.look
        let content = contentRect(input)
        let base = CGFloat(look.size * input.typeFactor)
        let metrics = Metrics(input: input, base: base)
        let n = input.names.count
        let layout = input.layout
        let rowGap = base * CGFloat(Typography.rowGapRatio * look.spacing * (layout?.rowSpacing ?? 1))
        let columnGap = base * CGFloat(Typography.columnGapRatio * (layout?.columnSpacing ?? 1))
        let blockGap = base * CGFloat(Typography.blockGapRatio * look.spacing)
        let sideGap = base * CGFloat(Typography.columnGapRatio)
        let clock = input.clock.map { metrics.clock($0, base: base) }

        // A layout picked in Edit Widget decides; otherwise the look's column setting.
        let forced = layout?.columns ?? look.columns
        let columnChoices: [Int] = n == 0 ? [0] : (forced > 0 ? [min(forced, n)] : Array(1...min(4, n)))
        let placements: [ClockPlacement]
        if clock == nil {
            placements = [.noClock]
        } else if n == 0 {
            placements = [.above]
        } else {
            // A medium widget is wide and short: side by side first.
            placements = input.size == .medium ? [.beside, .above] : [.above, .beside]
        }
        let clockScales = clock == nil ? [1.0] : Typography.clockScales

        var best: (scale: CGFloat, placement: ClockPlacement, grid: Grid, clockScale: CGFloat)?
        for placement in placements {
            for count in columnChoices {
                let grid = makeGrid(widths: metrics.nameWidths, lineHeight: metrics.lineHeight,
                                    columns: count, rowGap: rowGap, columnGap: columnGap)
                for clockScale in clockScales.map({ CGFloat($0) }) {
                    let block = blockSize(placement, grid: grid.size, clock: clock?.size, clockScale: clockScale,
                                          blockGap: blockGap, sideGap: sideGap)
                    let fit = scaleToFit(block, in: content.size)
                    if let current = best, fit <= current.scale + 0.001 { continue }
                    best = (fit, placement, grid, clockScale)
                }
            }
        }
        guard let chosen = best else { return FacePlan(content: content) }

        let s = max(chosen.scale, CGFloat(Typography.minimumScale))
        let grid = chosen.grid
        let clockSize = clock.map { CGSize(width: $0.size.width * chosen.clockScale, height: $0.size.height * chosen.clockScale) }
        let block = blockSize(chosen.placement, grid: grid.size, clock: clock?.size, clockScale: chosen.clockScale,
                              blockGap: blockGap, sideGap: sideGap)
        let blockW = block.width * s, blockH = block.height * s
        let h = horizontalFactor(look.align), v = verticalFactor(look.vAlign)
        var originY = content.minY + (content.height - blockH) * v + CGFloat(layout?.verticalOffset ?? 0)
        originY = min(max(originY, 0), max(input.canvas.height - blockH, 0))
        let origin = CGPoint(x: content.minX + (content.width - blockW) * h, y: originY)

        var plan = FacePlan(columns: grid.columns, scale: Double(s), content: content)
        var gridOrigin = origin
        if let clock, let clockSize {
            let clockFrame: CGRect
            switch chosen.placement {
            case .beside:
                clockFrame = CGRect(x: origin.x, y: origin.y, width: clockSize.width * s, height: clockSize.height * s)
                gridOrigin = CGPoint(x: origin.x + (clockSize.width + sideGap) * s, y: origin.y)
            case .above, .noClock:
                clockFrame = CGRect(x: origin.x, y: origin.y, width: blockW, height: clockSize.height * s)
                gridOrigin = CGPoint(x: origin.x + (blockW - grid.size.width * s) * h,
                                     y: origin.y + (clockSize.height + (n > 0 ? blockGap : 0)) * s)
            }
            plan.clock = FacePlan.Clock(frame: clockFrame,
                                        bigSize: clock.bigSize * chosen.clockScale * s,
                                        smallSize: clock.smallSize * chosen.clockScale * s)
        }
        plan.names = placeGrid(grid, origin: gridOrigin, scale: s, lineHeight: metrics.lineHeight,
                               rowGap: rowGap, columnGap: columnGap, base: base, input: input)
        return plan
    }

    /// Row-major grid: rows = ⌈count ÷ columns⌉, the last row padded. Each column is as
    /// wide as its widest name, so columns line up and none is left empty.
    private static func makeGrid(widths: [CGFloat], lineHeight: CGFloat, columns: Int,
                                 rowGap: CGFloat, columnGap: CGFloat) -> Grid {
        guard columns > 0, !widths.isEmpty else { return Grid(columns: 0, columnWidths: [], size: .zero) }
        let rows = (widths.count + columns - 1) / columns
        var columnWidths = [CGFloat](repeating: 0, count: columns)
        for (index, width) in widths.enumerated() {
            columnWidths[index % columns] = max(columnWidths[index % columns], width)
        }
        let width = columnWidths.reduce(0, +) + CGFloat(columns - 1) * columnGap
        let height = CGFloat(rows) * lineHeight + CGFloat(rows - 1) * rowGap
        return Grid(columns: columns, columnWidths: columnWidths, size: CGSize(width: width, height: height))
    }

    private static func placeGrid(_ grid: Grid, origin: CGPoint, scale s: CGFloat, lineHeight: CGFloat,
                                  rowGap: CGFloat, columnGap: CGFloat, base: CGFloat,
                                  input: FacePlanInput) -> [FacePlan.Name] {
        guard grid.columns > 0 else { return [] }
        var xs: [CGFloat] = []
        var x = origin.x
        for width in grid.columnWidths {
            xs.append(x)
            x += (width + columnGap) * s
        }
        return input.names.indices.map { index in
            let row = index / grid.columns, column = index % grid.columns
            let frame = CGRect(x: xs[column], y: origin.y + CGFloat(row) * (lineHeight + rowGap) * s,
                               width: grid.columnWidths[column] * s, height: lineHeight * s)
            return name(index, frame: frame, fontSize: base * s, input: input)
        }
    }

    private static func blockSize(_ placement: ClockPlacement, grid: CGSize, clock: CGSize?, clockScale: CGFloat,
                                  blockGap: CGFloat, sideGap: CGFloat) -> CGSize {
        let c = clock.map { CGSize(width: $0.width * clockScale, height: $0.height * clockScale) } ?? .zero
        switch placement {
        case .noClock:
            return grid
        case .above:
            let gap = grid.height > 0 && c.height > 0 ? blockGap : 0
            return CGSize(width: max(c.width, grid.width), height: c.height + gap + grid.height)
        case .beside:
            return CGSize(width: c.width + sideGap + grid.width, height: max(c.height, grid.height))
        }
    }

    // MARK: Free (layout editor)

    /// Every name at the centre the editor stored, inside the margins. A name that
    /// covers more than 40 % of an earlier one moves by one grid row until it doesn't.
    private static func freeform(_ input: FacePlanInput) -> FacePlan {
        guard let layout = input.layout else { return columns(input) }
        let content = contentRect(input)
        let base = CGFloat(input.look.size * input.typeFactor)
        let metrics = Metrics(input: input, base: base)
        let canvas = input.canvas
        let n = input.names.count
        var plan = FacePlan(columns: 0, scale: 1, content: content)
        var placed: [CGRect] = []

        if let clock = input.clock {
            let item = layout.clockItem ?? LayoutItem(slot: -1, x: 0.5, y: 0.2)
            var m = metrics.clock(clock, base: base * CGFloat(item.scale))
            if m.size.width > content.width {
                m = metrics.clock(clock, base: base * CGFloat(item.scale) * content.width / m.size.width)
            }
            let frame = clamp(CGRect(center: CGPoint(x: CGFloat(item.x) * canvas.width, y: CGFloat(item.y) * canvas.height), size: m.size),
                              into: content)
            plan.clock = FacePlan.Clock(frame: frame, bigSize: m.bigSize, smallSize: m.smallSize)
            placed.append(frame)
        }

        for index in input.names.indices {
            let item = layout.item(for: index)
                ?? LayoutItem(slot: index, x: 0.5, y: (Double(index) + 0.5) / Double(max(n, 1)))
            var fontSize = base * CGFloat(item.scale)
            var size = metrics.nameSize(index, fontSize: fontSize)
            if size.width > content.width {
                fontSize *= content.width / size.width
                size = metrics.nameSize(index, fontSize: fontSize)
            }
            let wanted = clamp(CGRect(center: CGPoint(x: CGFloat(item.x) * canvas.width, y: CGFloat(item.y) * canvas.height), size: size),
                               into: content)
            let frame = nudge(wanted, away: placed, step: canvas.height / CGFloat(LayoutDocument.gridRows), within: content)
            placed.append(frame)
            var entry = name(index, frame: frame, fontSize: fontSize, input: input)
            entry.rotation = item.rotation
            plan.names.append(entry)
        }
        return plan
    }

    // MARK: Anchored (the older Free arrangement: anchors and nudges from the look)

    private static func anchored(_ input: FacePlanInput) -> FacePlan {
        let look = input.look
        let content = contentRect(input)
        let base = CGFloat(look.size * input.typeFactor)
        let metrics = Metrics(input: input, base: base)
        var plan = FacePlan(columns: 0, scale: 1, content: content)
        var placed: [CGRect] = []

        if let clock = input.clock {
            var m = metrics.clock(clock, base: base)
            let fit = scaleToFit(m.size, in: content.size)
            if fit < 1 { m = metrics.clock(clock, base: base * fit) }
            let frame = anchor(m.size, at: look.clockPosition, in: content)
                .offsetBy(dx: look.clockDX, dy: look.clockDY)
            plan.clock = FacePlan.Clock(frame: frame, bigSize: m.bigSize, smallSize: m.smallSize)
            placed.append(frame)
        }

        if look.perWordPlacement {
            for index in input.names.indices {
                var fontSize = base
                var size = metrics.nameSize(index, fontSize: fontSize)
                if size.width > content.width {
                    fontSize *= content.width / size.width
                    size = metrics.nameSize(index, fontSize: fontSize)
                }
                let position = look.wordAnchors["\(index)"] ?? look.appsPosition
                let wanted = anchor(size, at: position, in: content).offsetBy(dx: look.appsDX, dy: look.appsDY)
                // Two words on the same anchor used to sit on top of each other.
                let frame = nudge(wanted, away: placed, step: size.height, within: content)
                placed.append(frame)
                plan.names.append(name(index, frame: frame, fontSize: fontSize, input: input))
            }
            return plan
        }

        let rowGap = base * CGFloat(Typography.rowGapRatio * look.spacing)
        let columnGap = base * CGFloat(Typography.columnGapRatio)
        var best: (scale: CGFloat, grid: Grid)?
        if !input.names.isEmpty {
            let counts = look.columns > 0 ? [min(look.columns, input.names.count)] : Array(1...min(4, input.names.count))
            for count in counts {
                let grid = makeGrid(widths: metrics.nameWidths, lineHeight: metrics.lineHeight,
                                    columns: count, rowGap: rowGap, columnGap: columnGap)
                let fit = scaleToFit(grid.size, in: content.size)
                if let current = best, fit <= current.scale + 0.001 { continue }
                best = (fit, grid)
            }
        }
        if let best {
            let s = max(best.scale, CGFloat(Typography.minimumScale))
            let size = CGSize(width: best.grid.size.width * s, height: best.grid.size.height * s)
            let frame = anchor(size, at: look.appsPosition, in: content).offsetBy(dx: look.appsDX, dy: look.appsDY)
            plan.columns = best.grid.columns
            plan.scale = Double(s)
            plan.names = placeGrid(best.grid, origin: frame.origin, scale: s, lineHeight: metrics.lineHeight,
                                   rowGap: rowGap, columnGap: columnGap, base: base, input: input)
        }
        return plan
    }

    // MARK: Helpers

    private static func name(_ index: Int, frame: CGRect, fontSize: CGFloat, input: FacePlanInput) -> FacePlan.Name {
        let style = input.layout?.style(for: index)
        return FacePlan.Name(frame: frame, fontSize: fontSize,
                             weight: style?.weight ?? input.look.weight,
                             opacity: style?.opacity ?? 1,
                             colorHex: style?.colorHex)
    }

    /// Inside the system margins, plus the look's own inset.
    static func contentRect(_ input: FacePlanInput) -> CGRect {
        let i = input.insets
        let extra = CGFloat(input.look.inset)
        return CGRect(x: i.leading + extra, y: i.top + extra,
                      width: max(input.canvas.width - i.leading - i.trailing - 2 * extra, 1),
                      height: max(input.canvas.height - i.top - i.bottom - 2 * extra, 1))
    }

    private static func scaleToFit(_ size: CGSize, in available: CGSize) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return 1 }
        return min(1, available.width / size.width, available.height / size.height)
    }

    private static func horizontalFactor(_ align: TextAlign) -> CGFloat {
        switch align {
        case .left: return 0
        case .center: return 0.5
        case .right: return 1
        }
    }

    private static func verticalFactor(_ align: TextVAlign) -> CGFloat {
        switch align {
        case .top: return 0
        case .middle: return 0.5
        case .bottom: return 1
        }
    }

    private static func anchorFactors(_ position: WidgetPosition) -> (CGFloat, CGFloat) {
        switch position {
        case .topLeading: return (0, 0)
        case .top: return (0.5, 0)
        case .topTrailing: return (1, 0)
        case .leading: return (0, 0.5)
        case .center: return (0.5, 0.5)
        case .trailing: return (1, 0.5)
        case .bottomLeading: return (0, 1)
        case .bottom: return (0.5, 1)
        case .bottomTrailing: return (1, 1)
        }
    }

    private static func anchor(_ size: CGSize, at position: WidgetPosition, in rect: CGRect) -> CGRect {
        let (h, v) = anchorFactors(position)
        return CGRect(x: rect.minX + (rect.width - size.width) * h,
                      y: rect.minY + (rect.height - size.height) * v,
                      width: size.width, height: size.height)
    }

    static func clamp(_ frame: CGRect, into rect: CGRect) -> CGRect {
        var f = frame
        f.origin.x = min(max(f.minX, rect.minX), max(rect.maxX - f.width, rect.minX))
        f.origin.y = min(max(f.minY, rect.minY), max(rect.maxY - f.height, rect.minY))
        return f
    }

    /// Share of the smaller rectangle that the two have in common.
    static func overlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let common = a.intersection(b)
        guard !common.isNull, !common.isEmpty else { return 0 }
        let smaller = min(a.width * a.height, b.width * b.height)
        return smaller > 0 ? common.width * common.height / smaller : 0
    }

    /// Moves `frame` by whole steps (down, up, two down, two up…) until it covers no
    /// earlier frame by more than 40 %, staying inside `rect`. Keeps it if nothing works.
    private static func nudge(_ frame: CGRect, away others: [CGRect], step: CGFloat, within rect: CGRect) -> CGRect {
        func clear(_ f: CGRect) -> Bool { !others.contains { overlap($0, f) > 0.4 } }
        if clear(frame) || step <= 0 { return frame }
        for k in 1...16 {
            for direction in [CGFloat(1), -1] {
                let moved = frame.offsetBy(dx: 0, dy: direction * CGFloat(k) * step)
                if moved.minY >= rect.minY - 0.5, moved.maxY <= rect.maxY + 0.5, clear(moved) { return moved }
            }
        }
        return frame
    }
}

private extension CGRect {
    init(center: CGPoint, size: CGSize) {
        self.init(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }
}

// MARK: - Measuring

/// Text sizes from the same fonts the face draws (CoreText underneath both).
private struct Metrics {
    let input: FacePlanInput
    let base: CGFloat
    /// Name widths at the base size.
    let nameWidths: [CGFloat]
    /// Tallest name line at the base size.
    let lineHeight: CGFloat

    struct ClockSize {
        var size: CGSize
        var bigSize: CGFloat
        var smallSize: CGFloat
    }

    init(input: FacePlanInput, base: CGFloat) {
        self.input = input
        self.base = base
        var widths: [CGFloat] = []
        var tallest = TextMeasure.font(id: input.look.fontID, size: base, weight: input.look.weight.uiKit).lineHeight
        for index in input.names.indices {
            let weight = input.layout?.style(for: index)?.weight ?? input.look.weight
            let font = TextMeasure.font(id: input.look.fontID, size: base, weight: weight.uiKit)
            widths.append(TextMeasure.width(input.names[index], font: font, look: input.look))
            tallest = max(tallest, font.lineHeight)
        }
        nameWidths = widths
        lineHeight = ceil(tallest)
    }

    func nameSize(_ index: Int, fontSize: CGFloat) -> CGSize {
        let weight = input.layout?.style(for: index)?.weight ?? input.look.weight
        let font = TextMeasure.font(id: input.look.fontID, size: fontSize, weight: weight.uiKit)
        return CGSize(width: TextMeasure.width(input.names[index], font: font, look: input.look),
                      height: ceil(font.lineHeight))
    }

    /// The clock block at word size `base`: big line (light) over the optional date line.
    func clock(_ content: ClockContent, base: CGFloat) -> ClockSize {
        let bigSize = base * CGFloat(Typography.clockRatio(input.size) * content.bigScale)
        let smallSize = base * CGFloat(Typography.dateRatio)
        let bigFont = TextMeasure.font(id: input.look.fontID, size: bigSize, weight: .light)
        let bigWidth = ([content.big] + content.bigReferences)
            .map { TextMeasure.width($0, font: bigFont, look: input.look) }
            .max() ?? 0
        var width = bigWidth
        var height = ceil(bigFont.lineHeight)
        if let small = content.small {
            let smallFont = TextMeasure.font(id: input.look.fontID, size: smallSize, weight: input.look.weight.uiKit)
            width = max(width, TextMeasure.width(small, font: smallFont, look: input.look))
            height += ceil(smallFont.lineHeight)
        }
        return ClockSize(size: CGSize(width: width, height: height), bigSize: bigSize, smallSize: smallSize)
    }
}

enum TextMeasure {
    /// The UIKit twin of `FontCatalog.font(id:size:weight:)`.
    static func font(id: String, size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let s = max(4, size)
        let system = UIFont.systemFont(ofSize: s, weight: weight)
        func design(_ design: UIFontDescriptor.SystemDesign) -> UIFont {
            system.fontDescriptor.withDesign(design).map { UIFont(descriptor: $0, size: s) } ?? system
        }
        switch id {
        case "sys:rounded": return design(.rounded)
        case "sys:serif": return design(.serif)
        case "sys:mono": return design(.monospaced)
        case _ where id.hasPrefix("fam:"):
            let descriptor = UIFontDescriptor(fontAttributes: [
                .family: String(id.dropFirst(4)),
                .traits: [UIFontDescriptor.TraitKey.weight: weight.rawValue],
            ])
            return UIFont(descriptor: descriptor, size: s)
        case _ where id.hasPrefix("ps:"):
            FontRegistry.registerAllOnce()
            return UIFont(name: String(id.dropFirst(3)), size: s) ?? system
        default:
            return system
        }
    }

    /// Width of one line, with the look's case and tracking, rounded up with a hair of slack.
    static func width(_ text: String, font: UIFont, look: Look) -> CGFloat {
        let shown = look.letterCase == .upper ? text.uppercased() : text
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .kern: CGFloat(look.tracking)]
        let width = (shown as NSString).size(withAttributes: attributes).width
        return ceil(width + Typography.measureSlack)
    }
}

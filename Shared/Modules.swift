import SwiftUI

// The structural modules a design is built from, and their line drawings. Shared by the
// app (editor, gallery, assets) and the widget extension (the Design widget), so a module
// looks the same in the app and on the Home Screen.

/// A structural module for designs, presets and the asset ledger.
enum ModuleKind: String, Codable, CaseIterable, Identifiable {
    case clock, countdown, health, battery, vinyl, calendar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clock: return "Clock"
        case .countdown: return "Countdown"
        case .health: return "Health Chart"
        case .battery: return "Battery Bar"
        case .vinyl: return "Vinyl Deck"
        case .calendar: return "Calendar"
        }
    }

    var code: String {
        switch self {
        case .clock: return "CLK-01"
        case .countdown: return "CDN-02"
        case .health: return "HLT-03"
        case .battery: return "BAT-04"
        case .vinyl: return "VNL-05"
        case .calendar: return "CAL-06"
        }
    }

    /// Whether the drawing moves with the clock, so a widget showing it redraws every minute.
    var followsTime: Bool { self == .clock || self == .countdown }

    /// The one reading under the drawing, or nil where there is nothing true to say:
    /// the health chart is a sample line and never reads Health data.
    func reading(at date: Date, battery: Double?) -> String? {
        switch self {
        case .clock: return Clockwork.hoursMinutes(date)
        case .countdown: return String(Clockwork.duration(Clockwork.untilMidnight(date)).prefix(5))
        case .health: return nil
        case .battery: return battery.map { "\(Int(($0 * 100).rounded()))%" } ?? "—"
        case .vinyl: return "33⅓"
        case .calendar: return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

/// Line drawings of the structural modules. One set of paths serves every size: the
/// widget, the editor preview, the preset blueprints and the asset sheets.
enum ModuleDrawing {
    struct Stroke {
        var path: Path
        var width: CGFloat = 1
        var opacity: Double = 1
    }

    /// `seconds` adds the clock's second hand when a date is given; a widget redraws once
    /// a minute, so it leaves the hand off rather than freeze it.
    static func strokes(_ kind: ModuleKind, in rect: CGRect, date: Date? = nil, level: Double = 0.62,
                        seconds: Bool = true) -> [Stroke] {
        switch kind {
        case .clock: return clock(in: square(rect), date: date, seconds: seconds)
        case .countdown: return countdown(in: square(rect), date: date)
        case .health: return health(in: rect)
        case .battery: return battery(in: rect, level: level)
        case .vinyl: return vinyl(in: square(rect))
        case .calendar: return calendar(in: square(rect), date: date)
        }
    }

    /// Strokes in the context's foreground style; `widthScale` thins them for thumbnails.
    static func draw(_ strokes: [Stroke], in context: GraphicsContext, widthScale: CGFloat = 1) {
        for stroke in strokes {
            var layer = context
            layer.opacity = stroke.opacity
            layer.stroke(stroke.path, with: .foreground,
                         style: StrokeStyle(lineWidth: stroke.width * widthScale, lineCap: .round, lineJoin: .round))
        }
    }

    static func square(_ rect: CGRect) -> CGRect {
        let side = min(rect.width, rect.height)
        return CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
    }

    // MARK: Kinds

    private static func clock(in r: CGRect, date: Date?, seconds: Bool) -> [Stroke] {
        let c = CGPoint(x: r.midX, y: r.midY)
        let radius = r.width * 0.46
        var ticks = Path()
        for i in 0..<12 {
            let angle = Double(i) / 12 * 2 * .pi
            ticks.move(to: polarPoint(c, radius * (i % 3 == 0 ? 0.7 : 0.8), angle))
            ticks.addLine(to: polarPoint(c, radius * 0.9, angle))
        }
        let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: date ?? Self.tenTen)
        let minutes = Double(parts.minute ?? 0) + (seconds ? Double(parts.second ?? 0) / 60 : 0)
        let hours = Double((parts.hour ?? 0) % 12) + minutes / 60
        var hourHand = Path()
        hourHand.move(to: c)
        hourHand.addLine(to: polarPoint(c, radius * 0.48, hours / 12 * 2 * .pi))
        var minuteHand = Path()
        minuteHand.move(to: c)
        minuteHand.addLine(to: polarPoint(c, radius * 0.74, minutes / 60 * 2 * .pi))
        var out = [
            Stroke(path: circle(c, radius)),
            Stroke(path: ticks, width: 1, opacity: 0.6),
            Stroke(path: hourHand, width: 2),
            Stroke(path: minuteHand, width: 1.2),
            Stroke(path: circle(c, radius * 0.06)),
        ]
        if seconds, date != nil, let second = parts.second {
            var secondHand = Path()
            secondHand.move(to: c)
            secondHand.addLine(to: polarPoint(c, radius * 0.82, Double(second) / 60 * 2 * .pi))
            out.append(Stroke(path: secondHand, width: 0.6, opacity: 0.55))
        }
        return out
    }

    private static func countdown(in r: CGRect, date: Date?) -> [Stroke] {
        let c = CGPoint(x: r.midX, y: r.midY)
        let radius = r.width * 0.42
        let left = 1 - Clockwork.dayFraction(date ?? Self.tenTen)
        var arc = Path()
        // y grows downward, so `clockwise: false` draws clockwise on screen.
        arc.addArc(center: c, radius: radius, startAngle: .degrees(-90),
                   endAngle: .degrees(-90 + 360 * left), clockwise: false)
        var marker = Path()
        marker.move(to: CGPoint(x: c.x, y: c.y - radius - r.width * 0.06))
        marker.addLine(to: CGPoint(x: c.x, y: c.y - radius + r.width * 0.06))
        var inner = Path()
        for i in 0..<4 {
            let angle = Double(i) / 4 * 2 * .pi
            inner.move(to: polarPoint(c, radius * 0.62, angle))
            inner.addLine(to: polarPoint(c, radius * 0.74, angle))
        }
        return [
            Stroke(path: circle(c, radius), width: 1, opacity: 0.3),
            Stroke(path: arc, width: 2.5),
            Stroke(path: marker, width: 1),
            Stroke(path: inner, width: 1, opacity: 0.5),
        ]
    }

    private static let healthSamples: [CGFloat] = [0.55, 0.48, 0.62, 0.35, 0.72, 0.42, 0.5, 0.18, 0.6, 0.44, 0.38]

    private static func health(in rect: CGRect) -> [Stroke] {
        let area = rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.2)
        var grid = Path()
        for step in 0...2 {
            let y = area.minY + area.height * CGFloat(step) / 2
            grid.move(to: CGPoint(x: area.minX, y: y))
            grid.addLine(to: CGPoint(x: area.maxX, y: y))
        }
        var line = Path()
        var last = CGPoint.zero
        for (index, value) in healthSamples.enumerated() {
            let point = CGPoint(x: area.minX + area.width * CGFloat(index) / CGFloat(healthSamples.count - 1),
                                y: area.minY + area.height * value)
            if index == 0 { line.move(to: point) } else { line.addLine(to: point) }
            last = point
        }
        return [
            Stroke(path: grid, width: 0.6, opacity: 0.3),
            Stroke(path: line, width: 1.4),
            Stroke(path: circle(last, max(rect.width * 0.025, 1.5))),
        ]
    }

    private static func battery(in rect: CGRect, level: Double) -> [Stroke] {
        let width = rect.width * 0.78
        let height = min(rect.height * 0.5, width * 0.42)
        let body = CGRect(x: rect.midX - width / 2 - width * 0.03, y: rect.midY - height / 2, width: width, height: height)
        let nub = CGRect(x: body.maxX + width * 0.015, y: body.midY - height * 0.18, width: width * 0.05, height: height * 0.36)
        let inner = body.insetBy(dx: height * 0.14, dy: height * 0.14)
        let gap = inner.width * 0.04
        let segment = (inner.width - gap * 4) / 5
        let charged = Int((min(max(level, 0), 1) * 5).rounded())
        var cells = Path()
        var hatch = Path()
        for i in 0..<5 {
            let cell = CGRect(x: inner.minX + CGFloat(i) * (segment + gap), y: inner.minY, width: segment, height: inner.height)
            cells.addRoundedRect(in: cell, cornerSize: CGSize(width: 1.5, height: 1.5))
            if i < charged {
                // A charged cell is hatched, never filled.
                for line in 1...3 {
                    let x = cell.minX + cell.width * CGFloat(line) / 4
                    hatch.move(to: CGPoint(x: x, y: cell.minY + 1.5))
                    hatch.addLine(to: CGPoint(x: x, y: cell.maxY - 1.5))
                }
            }
        }
        return [
            Stroke(path: Path(roundedRect: body, cornerRadius: height * 0.22, style: .continuous)),
            Stroke(path: Path(roundedRect: nub, cornerRadius: nub.width * 0.4, style: .continuous)),
            Stroke(path: cells, width: 0.6, opacity: 0.5),
            Stroke(path: hatch, width: 0.8, opacity: 0.9),
        ]
    }

    private static func vinyl(in r: CGRect) -> [Stroke] {
        let c = CGPoint(x: r.midX, y: r.midY)
        let radius = r.width * 0.47
        var grooves = Path()
        var ring = radius * 0.88
        while ring > radius * 0.44 {
            grooves.addPath(circle(c, ring))
            ring -= radius * 0.08
        }
        var sheen = Path()
        sheen.addArc(center: c, radius: radius * 0.7, startAngle: .degrees(200), endAngle: .degrees(235), clockwise: false)
        return [
            Stroke(path: circle(c, radius)),
            Stroke(path: grooves, width: 0.5, opacity: 0.4),
            Stroke(path: sheen, width: 1, opacity: 0.9),
            Stroke(path: circle(c, radius * 0.34)),
            Stroke(path: circle(c, radius * 0.05)),
        ]
    }

    private static func calendar(in r: CGRect, date: Date?) -> [Stroke] {
        let page = r.insetBy(dx: r.width * 0.1, dy: r.width * 0.12)
        let header = page.minY + page.height * 0.26
        var frame = Path(roundedRect: page, cornerRadius: page.width * 0.1, style: .continuous)
        frame.move(to: CGPoint(x: page.minX, y: header))
        frame.addLine(to: CGPoint(x: page.maxX, y: header))
        var rings = Path()
        for x in [page.minX + page.width * 0.28, page.maxX - page.width * 0.28] {
            rings.move(to: CGPoint(x: x, y: page.minY - page.height * 0.07))
            rings.addLine(to: CGPoint(x: x, y: page.minY + page.height * 0.08))
        }
        let grid = CGRect(x: page.minX + page.width * 0.08, y: header + page.height * 0.08,
                          width: page.width * 0.84, height: page.height * 0.58)
        let cellW = grid.width / 7, cellH = grid.height / 4
        let day = Calendar.current.component(.day, from: date ?? Self.tenTen)
        let today = (day - 1) % 28
        var dots = Path()
        var mark = Path()
        for row in 0..<4 {
            for column in 0..<7 {
                let center = CGPoint(x: grid.minX + cellW * (CGFloat(column) + 0.5), y: grid.minY + cellH * (CGFloat(row) + 0.5))
                if row * 7 + column == today {
                    mark.addRoundedRect(in: CGRect(x: center.x - cellW * 0.42, y: center.y - cellH * 0.42,
                                                   width: cellW * 0.84, height: cellH * 0.84),
                                        cornerSize: CGSize(width: 1.5, height: 1.5))
                }
                dots.addPath(circle(center, max(cellW * 0.08, 0.5)))
            }
        }
        return [
            Stroke(path: frame),
            Stroke(path: rings, width: 1.2),
            Stroke(path: dots, width: 0.8, opacity: 0.55),
            Stroke(path: mark, width: 1.2),
        ]
    }

    // MARK: Helpers

    /// 10:10 on 25 October, the catalogue time.
    private static let tenTen: Date = {
        var parts = DateComponents()
        parts.year = 2026; parts.month = 10; parts.day = 25; parts.hour = 10; parts.minute = 10
        return Calendar.current.date(from: parts) ?? .now
    }()

    static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}

/// A point at `radius` from `center`, `angle` radians clockwise from twelve o'clock.
func polarPoint(_ center: CGPoint, _ radius: CGFloat, _ angle: Double) -> CGPoint {
    CGPoint(x: center.x + radius * CGFloat(sin(angle)), y: center.y - radius * CGFloat(cos(angle)))
}

/// A module's line drawing at any size, in the current foreground style.
struct ModuleGlyph: View {
    let kind: ModuleKind
    var date: Date?
    var level: Double = 0.62
    var widthScale: CGFloat = 1
    var seconds = true

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
            ModuleDrawing.draw(ModuleDrawing.strokes(kind, in: rect, date: date, level: level, seconds: seconds),
                               in: context, widthScale: widthScale)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Time

enum Clockwork {
    static var uses12Hour: Bool {
        DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current)?.contains("a") ?? false
    }

    /// Hours and minutes, two digits each, without AM/PM.
    static func hoursMinutes(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    static func meridiem(_ date: Date) -> String {
        let calendar = Calendar.current
        return calendar.component(.hour, from: date) < 12 ? calendar.amSymbol : calendar.pmSymbol
    }

    static func untilMidnight(_ date: Date) -> TimeInterval {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let next = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return next.timeIntervalSince(date)
    }

    /// How much of today has gone, 0…1.
    static func dayFraction(_ date: Date) -> Double {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let next = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return date.timeIntervalSince(start) / next.timeIntervalSince(start)
    }

    /// "03:18:42"
    static func duration(_ interval: TimeInterval) -> String {
        let total = max(Int(interval), 0)
        return String(format: "%02d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
    }

    /// "3:32"
    static func minutesSeconds(_ interval: TimeInterval) -> String {
        let total = max(Int(interval.rounded(.down)), 0)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

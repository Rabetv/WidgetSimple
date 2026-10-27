import SwiftUI
import UIKit

// The configurator's drawing rules, in the app's own theme: the brown and copper folds
// of `AppBackground`, Liquid Glass panels on top, the dark scheme. Lines are the current
// foreground style, so they read white on the glass; the one colour is the amber accent,
// and it marks what is selected.

enum LineArt {
    /// Continuous-curve radii, the corner iOS uses for its own cards and icons.
    static let moduleRadius: CGFloat = 22
    static let innerRadius: CGFloat = 14
    static let keyRadius: CGFloat = 9
    /// The gap inside a nested grid, and the open space between groups.
    static let gutter: CGFloat = 8
    static let breath: CGFloat = 30
    /// Padding inside a module, and the page margin.
    static let inset: CGFloat = 14
    static let margin: CGFloat = 16

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    @MainActor static var systemVersion: String { UIDevice.current.systemVersion }
}

// MARK: - Type

extension Font {
    /// Primary metrics: thick, rounded numerals.
    static func metric(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    /// Sub-labels: a geometric sans, set small. Tracking is added where it is used.
    static func micro(_ size: CGFloat = 9) -> Font {
        .custom("AvenirNext-DemiBold", size: size, relativeTo: .caption2)
    }
}

/// A sub-label: small geometric capitals with open tracking.
struct Micro: View {
    let text: String
    var size: CGFloat
    var tracking: CGFloat
    var tone: HierarchicalShapeStyle

    init(_ text: String, size: CGFloat = 9, tracking: CGFloat = 1.5, tone: HierarchicalShapeStyle = .secondary) {
        self.text = text
        self.size = size
        self.tracking = tracking
        self.tone = tone
    }

    var body: some View {
        Text(text.uppercased())
            .font(.micro(size))
            .tracking(tracking)
            .lineLimit(1)
            .foregroundStyle(tone)
    }
}

/// A typography stamp: a few capitals inside a sticker border one pixel thick.
struct Stamp: View {
    let text: String
    var emphasized: Bool
    @Environment(\.displayScale) private var scale

    init(_ text: String, emphasized: Bool = false) {
        self.text = text
        self.emphasized = emphasized
    }

    var body: some View {
        Text(text.uppercased())
            .font(.custom("AvenirNext-Bold", size: 7.5, relativeTo: .caption2))
            .tracking(1.1)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 4.5)
            .padding(.vertical, 2.5)
            .foregroundStyle(emphasized ? HierarchicalShapeStyle.primary : .secondary)
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(Color.primary.opacity(emphasized ? 0.9 : 0.5),
                                  lineWidth: emphasized ? 1 : 1 / scale)
            }
    }
}

// MARK: - Lines

enum LineWeight {
    /// One physical pixel: sticker borders, grooves, separators.
    case pixel
    /// One point: module outlines, keys, pills.
    case rule
    /// Two points: a selected or targeted outline.
    case bold
}

/// The outline every module is built from: a continuous squircle, never filled.
struct LineBorder: View {
    var radius: CGFloat = LineArt.moduleRadius
    var weight: LineWeight = .rule
    var opacity: Double = 1
    var dash: [CGFloat] = []
    @Environment(\.displayScale) private var scale

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(Color.primary.opacity(opacity), style: StrokeStyle(lineWidth: width, dash: dash))
    }

    private var width: CGFloat {
        switch weight {
        case .pixel: 1 / scale
        case .rule: 1
        case .bold: 2
        }
    }
}

extension View {
    func lineBorder(radius: CGFloat = LineArt.moduleRadius, weight: LineWeight = .rule,
                    opacity: Double = 1, dash: [CGFloat] = []) -> some View {
        overlay { LineBorder(radius: radius, weight: weight, opacity: opacity, dash: dash) }
    }
}

/// A one-pixel rule, used as the explicit separator between rows.
struct Hairline: View {
    var axis: Axis = .horizontal
    var opacity: Double = 0.35
    @Environment(\.displayScale) private var scale

    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(opacity))
            .frame(width: axis == .vertical ? 1 / scale : nil,
                   height: axis == .horizontal ? 1 / scale : nil)
            // A rule only takes the room the labels beside it leave over.
            .layoutPriority(-1)
            .accessibilityHidden(true)
    }
}

struct Corner: OptionSet {
    let rawValue: Int
    static let topLeading = Corner(rawValue: 1)
    static let topTrailing = Corner(rawValue: 2)
    static let bottomLeading = Corner(rawValue: 4)
    static let bottomTrailing = Corner(rawValue: 8)
    static let diagonal: Corner = [.topLeading, .bottomTrailing]
}

/// Registration marks just outside a container's corners, like a print proof.
struct CropMarks: Shape {
    var corners: Corner
    var length: CGFloat = 6
    var gap: CGFloat = 4

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: -gap, dy: -gap)
        var path = Path()
        func mark(_ corner: CGPoint, dx: CGFloat, dy: CGFloat) {
            path.move(to: CGPoint(x: corner.x, y: corner.y + dy * length))
            path.addLine(to: corner)
            path.addLine(to: CGPoint(x: corner.x + dx * length, y: corner.y))
        }
        if corners.contains(.topLeading) { mark(CGPoint(x: r.minX, y: r.minY), dx: 1, dy: 1) }
        if corners.contains(.topTrailing) { mark(CGPoint(x: r.maxX, y: r.minY), dx: -1, dy: 1) }
        if corners.contains(.bottomLeading) { mark(CGPoint(x: r.minX, y: r.maxY), dx: 1, dy: -1) }
        if corners.contains(.bottomTrailing) { mark(CGPoint(x: r.maxX, y: r.maxY), dx: -1, dy: -1) }
        return path
    }
}

// MARK: - Module

/// The basic container: a Liquid Glass panel. A label and a stamp head it, a foot stamp
/// closes it, and optional registration marks sit just outside the corners.
struct ModuleFrame<Content: View>: View {
    var label: String?
    var stamp: String?
    var foot: String?
    var radius: CGFloat
    var inset: CGFloat
    var marks: Corner
    let content: Content
    @Environment(\.displayScale) private var scale

    init(_ label: String? = nil, stamp: String? = nil, foot: String? = nil,
         radius: CGFloat = LineArt.moduleRadius, inset: CGFloat = LineArt.inset,
         marks: Corner = [], @ViewBuilder content: () -> Content) {
        self.label = label
        self.stamp = stamp
        self.foot = foot
        self.radius = radius
        self.inset = inset
        self.marks = marks
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if label != nil || stamp != nil {
                HStack(spacing: 8) {
                    if let label { Micro(label, size: 8.5, tone: .primary) }
                    Spacer(minLength: 8)
                    if let stamp { Stamp(stamp) }
                }
            }
            content
            if let foot {
                HStack {
                    Spacer(minLength: 0)
                    Stamp(foot)
                }
            }
        }
        .padding(inset + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: radius)
        .overlay {
            if !marks.isEmpty {
                CropMarks(corners: marks)
                    .stroke(Color.primary.opacity(0.5), lineWidth: 1 / scale)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// The title at the top of each screen.
struct ScreenHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 40, weight: .heavy, design: .rounded))
            .tracking(-1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A group heading inside a screen: code stamp, title, rule, count.
struct SectionRule: View {
    let code: String
    let title: String
    var count: Int?

    var body: some View {
        HStack(spacing: 10) {
            Stamp(code)
            Text(title)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .layoutPriority(1)
            Hairline()
            if let count { Micro("\(count)", tone: .primary) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Controls

/// A square key with a tiny inner bevel: an outline, and a hairline 2.5 pt inside it
/// that closes in while the key is held.
struct BevelKeyStyle: ButtonStyle {
    var size: CGFloat = 40
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        BevelKey(label: configuration.label, pressed: configuration.isPressed, size: size, selected: selected)
    }
}

extension EnvironmentValues {
    /// Every key and pill at least 44 points: set where small fingers do the work (the
    /// sandbox's sheets).
    @Entry var largeTargets = false
}

private struct BevelKey<Label: View>: View {
    let label: Label
    let pressed: Bool
    let requested: CGFloat
    let selected: Bool
    @Environment(\.displayScale) private var scale
    @Environment(\.isEnabled) private var enabled
    @Environment(\.largeTargets) private var largeTargets

    init(label: Label, pressed: Bool, size: CGFloat, selected: Bool) {
        self.label = label
        self.pressed = pressed
        self.requested = size
        self.selected = selected
    }

    private var size: CGFloat { largeTargets ? max(requested, 44) : requested }

    var body: some View {
        let radius = size * 0.24
        label
            .font(.system(size: size * 0.36, weight: .medium))
            .frame(width: size, height: size)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.85), lineWidth: selected ? 2 : 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: max(radius - 2.5, 1), style: .continuous)
                    .strokeBorder(Color.primary.opacity(pressed ? 0.7 : 0.3), lineWidth: 1 / scale)
                    .padding(pressed ? 3.5 : 2.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .scaleEffect(pressed ? 0.94 : 1)
            .opacity(enabled ? 1 : 0.35)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A capsule button. Selected is filled and ringed in the accent.
struct PillStyle: ButtonStyle {
    var selected = false
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .pillLook(selected: selected, compact: compact)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private struct PillLook: ViewModifier {
    let selected: Bool
    let compact: Bool
    @Environment(\.isEnabled) private var enabled
    @Environment(\.largeTargets) private var largeTargets

    func body(content: Content) -> some View {
        content
            .font(.custom("AvenirNext-Bold", size: largeTargets ? 12 : compact ? 8.5 : 10, relativeTo: .caption))
            .tracking(1.2)
            .textCase(.uppercase)
            .lineLimit(1)
            .padding(.horizontal, largeTargets ? 16 : compact ? 8 : 13)
            .frame(minHeight: largeTargets ? 44 : compact ? 22 : 32)
            .foregroundStyle(selected ? HierarchicalShapeStyle.primary : .secondary)
            .background {
                if selected { Capsule().fill(Color.accentColor.opacity(0.26)) }
            }
            .overlay {
                Capsule().strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.4),
                                       lineWidth: selected ? 1.5 : 1)
            }
            .contentShape(Capsule())
            .opacity(enabled ? 1 : 0.35)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension View {
    /// The capsule look of `PillStyle`, for labels that are not buttons (menus).
    func pillLook(selected: Bool = false, compact: Bool = false) -> some View {
        modifier(PillLook(selected: selected, compact: compact))
    }
}

/// A big capsule key, 56 points tall, filling its share of the row: the sandbox's Add
/// and Save, Delete, and the few other actions a child should find at once.
struct BigKeyStyle: ButtonStyle {
    var prominent = false
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        let tint: Color = destructive ? .red : .accentColor
        return configuration.label
            .font(.system(size: 19, weight: .heavy, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(destructive ? Color.red : Color.primary)
            .glassEffect(prominent || destructive ? Glass.regular.tint(tint.opacity(prominent ? 0.5 : 0.2)) : .regular,
                         in: .capsule)
            .overlay {
                Capsule().strokeBorder(prominent || destructive ? tint : Color.primary.opacity(0.5),
                                       lineWidth: prominent ? 2 : 1)
            }
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// A plain press: the card shrinks a little under the finger.
struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A row of pills that wraps when it runs out of width.
struct PillPicker<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    var compact = false

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                Button(option.title) {
                    withAnimation(.snappy(duration: 0.2)) { selection = option.value }
                }
                .buttonStyle(PillStyle(selected: selection == option.value, compact: compact))
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// An on/off switch drawn as two outlines, with I and O marks like a hardware switch.
struct LineToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                configuration.label
                Spacer(minLength: 8)
                LineSwitch(on: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: configuration.isOn)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

private struct LineSwitch: View {
    let on: Bool
    @Environment(\.displayScale) private var scale

    var body: some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule().strokeBorder(on ? Color.accentColor : Color.primary, lineWidth: 1)
            HStack {
                Rectangle().fill(Color.primary).frame(width: 1, height: 8).opacity(on ? 1 : 0)
                Spacer()
                Circle().strokeBorder(Color.primary.opacity(0.5), lineWidth: 1 / scale)
                    .frame(width: 7, height: 7)
                    .opacity(on ? 0 : 1)
            }
            .padding(.horizontal, 11)
            ZStack {
                Circle().strokeBorder(on ? Color.accentColor : Color.primary, lineWidth: on ? 1.5 : 1)
                if on { Circle().strokeBorder(Color.primary.opacity(0.4), lineWidth: 1 / scale).padding(5) }
            }
            .frame(width: 22, height: 22)
            .padding(3)
        }
        .frame(width: 50, height: 28)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: on)
    }
}

/// A slider drawn as a ruler: ticks for every step, taller every `major` steps, the
/// covered part as a heavier line, and a needle for the thumb.
struct LineRuler: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var major = 5
    var label = ""
    @Environment(\.displayScale) private var scale

    private let edge: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            Canvas { context, size in
                let mid = size.height / 2
                let usable = size.width - edge * 2
                let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                let thumb = edge + usable * CGFloat(fraction)
                let count = Int(((range.upperBound - range.lowerBound) / step).rounded())

                var lit = Path(), dim = Path()
                for i in 0...max(count, 1) {
                    let x = edge + usable * CGFloat(i) / CGFloat(max(count, 1))
                    let tall: CGFloat = i % major == 0 ? 12 : 6
                    if x <= thumb + 0.5 {
                        lit.move(to: CGPoint(x: x, y: mid - tall / 2)); lit.addLine(to: CGPoint(x: x, y: mid + tall / 2))
                    } else {
                        dim.move(to: CGPoint(x: x, y: mid - tall / 2)); dim.addLine(to: CGPoint(x: x, y: mid + tall / 2))
                    }
                }
                var faint = context
                faint.opacity = 0.35
                faint.stroke(dim, with: .foreground, lineWidth: 1 / scale)
                context.stroke(lit, with: .foreground, lineWidth: 1 / scale)

                var covered = Path()
                covered.move(to: CGPoint(x: edge, y: mid))
                covered.addLine(to: CGPoint(x: thumb, y: mid))
                context.stroke(covered, with: .foreground, lineWidth: 2)

                var needle = Path()
                needle.move(to: CGPoint(x: thumb, y: 9))
                needle.addLine(to: CGPoint(x: thumb, y: size.height - 2))
                context.stroke(needle, with: .foreground, lineWidth: 1.5)
                context.stroke(Path(ellipseIn: CGRect(x: thumb - 4, y: 1, width: 8, height: 8)),
                               with: .foreground, lineWidth: 1)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { drag in
                    let fraction = min(max((drag.location.x - edge) / max(width - edge * 2, 1), 0), 1)
                    set(range.lowerBound + Double(fraction) * (range.upperBound - range.lowerBound))
                }
            )
        }
        .frame(height: 36)
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(String(format: step < 1 ? "%.1f" : "%.0f", value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: set(value + step)
            case .decrement: set(value - step)
            @unknown default: break
            }
        }
    }

    private func set(_ raw: Double) {
        let snapped = ((raw - range.lowerBound) / step).rounded() * step + range.lowerBound
        let clamped = min(max(snapped, range.lowerBound), range.upperBound)
        if abs(clamped - value) > step / 1000 { value = clamped }
    }
}

/// Lays children out in rows, wrapping to the next row when the width runs out.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if !row.indices.isEmpty && needed > width {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

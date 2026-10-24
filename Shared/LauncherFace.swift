import SwiftUI
import WidgetKit

/// Widget size, as far as the layout cares.
enum FaceSize: String, CaseIterable, Identifiable {
    case small, medium, large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    /// Width ÷ height of the widget on the Home Screen (393-point screens).
    var aspectRatio: CGFloat {
        let size = FaceMetrics.tableSize(self, screenWidth: 393)
        return size.width / size.height
    }
}

/// What a widget shows: an optional clock and the app names, text only. Shared by the
/// widget and the in-app preview, so the preview is exactly what lands on the Home Screen.
///
/// Where things go is decided by `FacePlanner` from the real size; this view only draws
/// the plan. Three arrangements:
///  * columns — clock above or beside, names in 1–4 balanced columns (the default);
///  * free (layout editor) — every name where the person dragged it;
///  * anchored — the older Free arrangement: 9-point anchors and nudges from the look.
struct LauncherFace<Cell: View>: View {
    let look: Look
    let clock: ClockOption
    let date: Date
    let size: FaceSize
    let apps: [String]
    /// The chosen word colour; white when the Home Screen tints the widget.
    let color: Color
    let layout: LayoutDocument?
    /// nil uses the system's content margins (the widget) or the default (elsewhere).
    let insets: EdgeInsets?
    /// Shown when there is nothing else to show.
    let hint: String
    let cell: (Int, AppName) -> Cell

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.widgetContentMargins) private var systemMargins

    init(look: Look, clock: ClockOption, date: Date, size: FaceSize, apps: [String], color: Color,
         layout: LayoutDocument? = nil, insets: EdgeInsets? = nil, hint: String = "",
         @ViewBuilder cell: @escaping (Int, AppName) -> Cell) {
        self.look = look
        self.clock = clock
        self.date = date
        self.size = size
        self.apps = apps
        self.color = color
        self.layout = layout
        self.insets = insets
        self.hint = hint
        self.cell = cell
    }

    private var isEmpty: Bool { apps.isEmpty && clock == .off }

    var body: some View {
        GeometryReader { geo in
            let plan = FacePlanner.plan(input(canvas: geo.size))
            ZStack(alignment: .topLeading) {
                if let placed = plan.clock, let content = ClockContent.make(date: date, option: clock, size: size) {
                    ClockText(content: content, look: look, bigSize: placed.bigSize, smallSize: placed.smallSize)
                        .frame(width: placed.frame.width, height: placed.frame.height,
                               alignment: Alignment(horizontal: look.align.horizontal, vertical: .top))
                        .offset(x: placed.frame.minX, y: placed.frame.minY)
                }
                ForEach(Array(plan.names.enumerated()), id: \.offset) { index, placed in
                    if index < apps.count {
                        cell(index, AppName(name: apps[index], look: look, placed: placed))
                            .frame(width: placed.frame.width, height: placed.frame.height)
                            .rotationEffect(.degrees(placed.rotation))
                            .opacity(placed.opacity)
                            .offset(x: placed.frame.minX, y: placed.frame.minY)
                    }
                }
                if isEmpty {
                    hintText
                        .frame(width: plan.content.width, height: plan.content.height)
                        .offset(x: plan.content.minX, y: plan.content.minY)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .foregroundStyle(color)
        .textCase(look.letterCase.textCase)
        .shadow(color: look.shadow ? Color.black.opacity(0.45) : .clear, radius: 6, x: 0, y: 3)
        // Belt and braces: the plan keeps everything inside, and nothing may leave the widget.
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
    }

    /// The same input the widget builds, so the preview gets the same plan.
    private func input(canvas: CGSize) -> FacePlanInput {
        FacePlanInput(canvas: canvas,
                      insets: resolvedInsets,
                      size: size,
                      look: look,
                      layout: layout,
                      names: apps,
                      clock: ClockContent.make(date: date, option: clock, size: size),
                      typeFactor: Typography.dynamicFactor(dynamicTypeSize))
    }

    private var resolvedInsets: EdgeInsets {
        if let insets { return insets }
        let m = systemMargins
        if m.top + m.leading + m.bottom + m.trailing > 0 { return m }
        let d = FaceMetrics.defaultMargin
        return EdgeInsets(top: d, leading: d, bottom: d, trailing: d)
    }

    private var accessibilitySummary: Text {
        apps.isEmpty ? Text("Launcher") : Text("Launcher: \(apps.joined(separator: ", "))")
    }

    private var hintText: some View {
        Text(hint)
            .font(.system(size: 14, weight: .medium))
            .multilineTextAlignment(look.align.text)
            .opacity(0.7)
    }
}

extension LauncherFace where Cell == AppName {
    /// Names only, no buttons (in-app preview, widget gallery).
    init(look: Look, clock: ClockOption, date: Date, size: FaceSize, apps: [String], color: Color,
         layout: LayoutDocument? = nil, insets: EdgeInsets? = nil) {
        self.init(look: look, clock: clock, date: date, size: size, apps: apps, color: color,
                  layout: layout, insets: insets) { _, name in name }
    }
}

/// One app, as a word in the chosen font, at the size and weight the plan gave it.
/// Fills the frame it is given, so the whole frame is the tap target.
struct AppName: View {
    let name: String
    let look: Look
    let placed: FacePlan.Name

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        word
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: Alignment(horizontal: look.align.horizontal, vertical: .center))
            .contentShape(Rectangle())
            .accessibilityLabel(Text("\(name), app"))
    }

    /// Keeps the inherited colour unless the layout set one for this name.
    @ViewBuilder
    private var word: some View {
        let text = Text(name)
            .font(look.font(size: Double(placed.fontSize), weight: placed.weight.font))
            .tracking(look.tracking)
            .lineLimit(1)
            // The plan measured the word; this only absorbs sub-point rounding.
            .minimumScaleFactor(0.9)
        if let color = overrideColor {
            text.foregroundStyle(color)
        } else {
            text
        }
    }

    /// A per-name colour from the layout. A tinted Home Screen colours every word itself.
    private var overrideColor: Color? {
        guard renderingMode == .fullColor, let hex = placed.colorHex else { return nil }
        return Color(hex: hex)
    }
}

/// The built-in clock in the chosen font. The big line is the widget's accent, so a
/// Tinted Home Screen colours it. 12 or 24 hours follows the iPhone setting.
struct ClockText: View {
    let content: ClockContent
    let look: Look
    let bigSize: CGFloat
    let smallSize: CGFloat

    var body: some View {
        VStack(alignment: look.align.horizontal, spacing: 0) {
            Text(content.big)
                .font(look.font(size: Double(bigSize), weight: .light))
                .monospacedDigit()
                .widgetAccentable()
            if let small = content.small {
                Text(small)
                    .font(look.font(size: Double(smallSize), weight: look.weight.font))
                    .opacity(0.75)
            }
        }
        .tracking(look.tracking)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
}

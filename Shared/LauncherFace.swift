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

    /// Width ÷ height of the widget on the Home Screen.
    var aspectRatio: CGFloat {
        switch self {
        case .small: return 158.0 / 158.0
        case .medium: return 338.0 / 158.0
        case .large: return 338.0 / 354.0
        }
    }
}

/// What a widget shows: an optional clock and the app names, text only. Shared by the
/// widget and the in-app preview, so the preview is exactly what lands on the Home Screen.
///
/// Two arrangements:
///  * `.stacked` — clock above the apps, and the words flow into more columns as needed;
///  * `.free` — the clock and the apps each sit wherever their position says.
///
/// Nothing is ever drawn outside the widget: the layout degrades (more columns, clock
/// beside the words) until it fits, and the result is clipped as a last resort.
struct LauncherFace<Cell: View>: View {
    let look: Look
    let clock: ClockOption
    let date: Date
    let size: FaceSize
    let apps: [String]
    /// The chosen word color; white on the system glass (Clear / Tinted Home Screen).
    let color: Color
    /// Shown when there is nothing else to show.
    var hint: String = ""
    @ViewBuilder let cell: (Int, AppName) -> Cell

    private var align: HorizontalAlignment { look.align.horizontal }
    private var edgePadding: CGFloat { size == .small ? 16 : 20 }
    private var isEmpty: Bool { apps.isEmpty && clock == .off }

    var body: some View {
        Group {
            switch look.arrangement {
            case .stacked: stacked
            case .free: free
            }
        }
        .foregroundStyle(color)
        .textCase(look.letterCase.textCase)
        .shadow(color: look.shadow ? Color.black.opacity(0.45) : .clear, radius: 6, x: 0, y: 3)
        // Belt and braces: whatever the layout does, no glyph may leave the widget.
        .clipped()
    }

    // MARK: Stacked

    /// Tries the layouts in order of preference and keeps the first one that fits the
    /// widget's height: clock above with growing column counts, then clock beside.
    private var stacked: some View {
        Group {
            if isEmpty {
                hintText
            } else {
                candidateLayouts
            }
        }
        .padding(edgePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: look.alignment)
    }

    @ViewBuilder
    private var candidateLayouts: some View {
        ViewThatFits(in: .vertical) {
            if size == .medium, clock != .off {
                // A medium widget is wide and short: side by side fits best.
                layout(clockBeside: true, columns: 2)
                layout(clockBeside: true, columns: 3)
                layout(clockBeside: true, columns: 4)
                layout(clockBeside: false, columns: 2)
                layout(clockBeside: false, columns: 3)
                layout(clockBeside: false, columns: 1)
            } else {
                layout(clockBeside: false, columns: 1)
                layout(clockBeside: false, columns: 2)
                layout(clockBeside: false, columns: 3)
                layout(clockBeside: false, columns: 4)
                layout(clockBeside: true, columns: 2)
                layout(clockBeside: true, columns: 3)
                layout(clockBeside: true, columns: 4)
            }
        }
    }

    /// One candidate: the clock above or beside the words, in `columns` columns.
    @ViewBuilder
    private func layout(clockBeside: Bool, columns count: Int) -> some View {
        if clockBeside, clock != .off {
            HStack(alignment: .top, spacing: 16) {
                ClockText(date: date, option: clock, look: look, size: size)
                if !apps.isEmpty { appColumns(count) }
            }
        } else {
            VStack(alignment: align, spacing: look.size * 0.8 * look.spacing) {
                if clock != .off {
                    ClockText(date: date, option: clock, look: look, size: size)
                }
                if !apps.isEmpty {
                    appColumns(count)
                }
            }
        }
    }

    // MARK: Free

    private var free: some View {
        ZStack {
            if clock != .off {
                ClockText(date: date, option: clock, look: look, size: size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: look.clockPosition.alignment)
                    .padding(edgePadding)
                    .offset(x: look.clockDX, y: look.clockDY)
            }
            if !apps.isEmpty {
                if look.perWordPlacement {
                    perWordApps
                } else {
                    appList
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: look.appsPosition.alignment)
                        .padding(edgePadding)
                        .offset(x: look.appsDX, y: look.appsDY)
                }
            }
            if isEmpty {
                hintText
            }
        }
    }

    /// Every word on its own anchor, shifted together by the block nudge.
    private var perWordApps: some View {
        ZStack {
            ForEach(apps.indices, id: \.self) { index in
                cell(index, AppName(name: apps[index], look: look, fillWidth: false))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: anchor(for: index).alignment)
                    .padding(edgePadding)
                    .offset(x: look.appsDX, y: look.appsDY)
            }
        }
    }

    private func anchor(for index: Int) -> WidgetPosition {
        look.wordAnchors["\(index)"] ?? look.appsPosition
    }

    // MARK: Apps

    /// Free placement: as many columns as fit, without a clock to compete with.
    private var appList: some View {
        ViewThatFits(in: .vertical) {
            appColumns(1)
            appColumns(2)
            appColumns(3)
            appColumns(4)
        }
    }

    private func appColumns(_ count: Int) -> some View {
        let perColumn = max(1, Int((Double(apps.count) / Double(max(count, 1))).rounded(.up)))
        return HStack(alignment: .top, spacing: 16) {
            ForEach(0..<count, id: \.self) { column in
                let start = min(column * perColumn, apps.count)
                let end = min(start + perColumn, apps.count)
                VStack(alignment: align, spacing: look.size * 0.45 * look.spacing) {
                    ForEach(start..<end, id: \.self) { index in
                        cell(index, AppName(name: apps[index], look: look))
                    }
                }
                .frame(maxWidth: .infinity, alignment: Alignment(horizontal: align, vertical: .top))
            }
        }
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
    init(look: Look, clock: ClockOption, date: Date, size: FaceSize, apps: [String], color: Color) {
        self.init(look: look, clock: clock, date: date, size: size, apps: apps, color: color) { _, name in name }
    }
}

/// One app, as a word in the chosen font.
struct AppName: View {
    let name: String
    let look: Look
    /// False when the word is placed on its own, so it keeps its natural width.
    var fillWidth: Bool = true

    var body: some View {
        Text(name)
            .font(look.font(size: look.size))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: fillWidth ? .infinity : nil,
                   alignment: Alignment(horizontal: look.align.horizontal, vertical: .center))
            .contentShape(Rectangle())
    }
}

/// The built-in clock in the chosen font. The big line is the widget's accent, so a
/// Tinted Home Screen colors it. 12 or 24 hours follows the iPhone setting.
struct ClockText: View {
    let date: Date
    let option: ClockOption
    let look: Look
    let size: FaceSize

    var body: some View {
        VStack(alignment: look.align.horizontal, spacing: 0) {
            switch option {
            case .off:
                EmptyView()
            case .time:
                big(date.formatted(.dateTime.hour().minute()))
            case .timeAndDate:
                big(date.formatted(.dateTime.hour().minute()))
                small(date.formatted(dateFormat))
            case .date:
                big(date.formatted(.dateTime.weekday(.wide)), scale: 0.6)
                small(date.formatted(.dateTime.month(.wide).day()))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .layoutPriority(1)
    }

    private func big(_ text: String, scale: Double = 1) -> some View {
        Text(text)
            .font(look.font(size: bigSize * scale, weight: .light))
            .widgetAccentable()
    }

    private func small(_ text: String) -> some View {
        Text(text)
            .font(look.font(size: look.size * 0.8))
            .opacity(0.75)
    }

    private var bigSize: Double {
        let base = look.size
        switch size {
        case .small: return base * 1.8
        case .medium: return base * 2.2
        case .large: return base * 2.8
        }
    }

    private var dateFormat: Date.FormatStyle {
        size == .small
            ? .dateTime.weekday(.abbreviated).month(.abbreviated).day()
            : .dateTime.weekday(.wide).month(.wide).day()
    }
}

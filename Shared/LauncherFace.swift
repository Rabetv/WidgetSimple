import SwiftUI
import WidgetKit

/// Widget size, as far as the layout cares.
enum FaceSize {
    case small, medium, large
}

/// What a widget shows: an optional clock and the app names, text only. Shared by the
/// widget and the in-app preview, so the preview is exactly what lands on the Home Screen.
///
/// Two arrangements:
///  * `.stacked` — clock above the apps (side by side on a medium widget);
///  * `.free` — the clock and the apps each sit wherever their position says.
/// `cell` wraps each name; the widget turns it into a button that opens the app.
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
    }

    // MARK: Arrangements

    private var stacked: some View {
        content
            .padding(edgePadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: look.alignment)
    }

    private var free: some View {
        ZStack {
            if clock != .off {
                ClockText(date: date, option: clock, look: look, size: size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: look.clockPosition.alignment)
                    .padding(edgePadding)
            }
            if !apps.isEmpty {
                appList
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: look.appsPosition.alignment)
                    .padding(edgePadding)
            }
            if apps.isEmpty && clock == .off {
                Text(hint)
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(look.align.text)
                    .opacity(0.7)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if apps.isEmpty && clock == .off {
            Text(hint)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(look.align.text)
                .opacity(0.7)
        } else if clock != .off && !apps.isEmpty && size == .medium {
            // Medium is wide and short: clock on the left, apps on the right.
            HStack(alignment: .top, spacing: 20) {
                ClockText(date: date, option: clock, look: look, size: size)
                appList
            }
        } else {
            VStack(alignment: align, spacing: look.size * 0.8 * look.spacing) {
                if clock != .off {
                    ClockText(date: date, option: clock, look: look, size: size)
                }
                if !apps.isEmpty {
                    appList
                }
            }
        }
    }

    // MARK: Apps

    /// As many columns as the widget needs to fit every app.
    private var appList: some View {
        ViewThatFits(in: .vertical) {
            columns(1)
            columns(2)
            columns(3)
            columns(4)
        }
    }

    private func columns(_ count: Int) -> some View {
        let perColumn = Int((Double(apps.count) / Double(count)).rounded(.up))
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

    var body: some View {
        Text(name)
            .font(look.font(size: look.size))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: look.align.horizontal, vertical: .center))
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
        .minimumScaleFactor(0.5)
        .fixedSize(horizontal: false, vertical: true)
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

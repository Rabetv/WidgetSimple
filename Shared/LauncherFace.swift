import SwiftUI

/// Widget size, as far as the layout cares.
enum FaceSize {
    case small, medium, large
}

/// What a widget shows: an optional clock and the app names. Shared by the widget
/// and the in-app preview, so the preview is exactly what lands on the Home Screen.
/// `cell` wraps each name; the widget turns it into a button that opens the app.
struct LauncherFace<Cell: View>: View {
    let look: Look
    let clock: ClockOption
    let date: Date
    let size: FaceSize
    let apps: [String]
    /// Shown when there is nothing else to show.
    var hint: String = ""
    @ViewBuilder let cell: (Int, AppName) -> Cell

    var body: some View {
        content
            .foregroundStyle(look.theme.text.color)
            .padding(size == .small ? 16 : 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var content: some View {
        if apps.isEmpty && clock == .off {
            Text(hint)
                .font(.system(size: 14, weight: .medium))
                .opacity(0.6)
        } else if clock != .off && !apps.isEmpty && size == .medium {
            // Medium is wide and short: clock on the left, apps on the right.
            HStack(alignment: .top, spacing: 20) {
                ClockText(date: date, option: clock, look: look, size: size)
                appList
            }
        } else {
            VStack(alignment: .leading, spacing: look.textSize.points * 0.8) {
                if clock != .off {
                    ClockText(date: date, option: clock, look: look, size: size)
                }
                if !apps.isEmpty {
                    appList
                }
            }
        }
    }

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
                VStack(alignment: .leading, spacing: look.textSize.points * 0.45) {
                    ForEach(start..<end, id: \.self) { index in
                        cell(index, AppName(name: apps[index], look: look))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

extension LauncherFace where Cell == AppName {
    /// Names only, no buttons (in-app preview, widget gallery).
    init(look: Look, clock: ClockOption, date: Date, size: FaceSize, apps: [String]) {
        self.init(look: look, clock: clock, date: date, size: size, apps: apps) { _, name in name }
    }
}

/// One app, as a word in the chosen font.
struct AppName: View {
    let name: String
    let look: Look

    var body: some View {
        Text(name)
            .font(look.font(size: look.textSize.points))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }
}

/// The built-in clock: a big time, optionally with the date under it.
struct ClockText: View {
    let date: Date
    let option: ClockOption
    let look: Look
    let size: FaceSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(date.formatted(.dateTime.hour().minute()))
                .font(look.font(size: timeSize, weight: .light))
            if option == .timeAndDate {
                Text(date.formatted(dateFormat))
                    .font(look.font(size: look.textSize.points * 0.8))
                    .opacity(0.75)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var timeSize: Double {
        let base = look.textSize.points
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

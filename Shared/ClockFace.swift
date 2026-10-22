import SwiftUI

/// The clock widget: day, time, date and the current week (month on Large).
/// Shared by the widget and the in-app preview.
struct ClockFace: View {
    let date: Date
    let style: ClockStyle
    let size: WidgetSizeOption

    var body: some View {
        Group {
            switch size {
            case .small: small
            case .medium: medium
            case .large, .max: large
            }
        }
        .foregroundStyle(style.color.color)
        .padding(size == .small ? 16 : 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func face(_ points: Double) -> Font {
        FontCatalog.font(id: style.fontID, size: points, weight: style.weight.weight)
    }

    private var weekday: String { date.formatted(.dateTime.weekday(.wide)) }
    private var time: String { date.formatted(.dateTime.hour().minute()) }
    private var month: String { date.formatted(.dateTime.month(.wide)) }
    private var shortDate: String { date.formatted(.dateTime.month(.abbreviated).day()) }

    private var small: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(weekday).font(face(18))
            Text(time).font(face(32))
            Spacer(minLength: 0)
            Text(shortDate).font(face(14))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(weekday).font(face(28))
                Text(time).font(face(32))
            }
            Spacer(minLength: 8)
            Text(month).font(face(17))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                Text(shortDate).font(face(17)).lineLimit(1)
                Spacer(minLength: 8)
                WeekStrip(date: date, color: style.color.color)
            }
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Text(shortDate).font(face(17)).lineLimit(1).padding(.top, 6)
            Spacer(minLength: 12)
            MonthGrid(date: date, color: style.color.color)
        }
    }
}

/// The days of the current week; today sits on a pill.
struct WeekStrip: View {
    let date: Date
    let color: Color

    var body: some View {
        let cal = Calendar.current
        HStack(spacing: 2) {
            ForEach(Self.week(of: date, calendar: cal), id: \.self) { day in
                let today = cal.isDate(day, inSameDayAs: date)
                VStack(spacing: 6) {
                    Text(Self.letter(for: day, calendar: cal))
                    Text("\(cal.component(.day, from: day))")
                }
                .font(.system(size: 13, weight: today ? .bold : .semibold))
                .monospacedDigit()
                .frame(width: 24)
                .padding(.vertical, 5)
                .background {
                    if today { Capsule().fill(color.opacity(0.22)) }
                }
                .opacity(today ? 1 : (cal.isDateInWeekend(day) ? 0.4 : 0.65))
            }
        }
    }

    static func week(of date: Date, calendar cal: Calendar) -> [Date] {
        guard let start = cal.dateInterval(of: .weekOfYear, for: date)?.start else { return [date] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    static func letter(for day: Date, calendar cal: Calendar) -> String {
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let index = cal.component(.weekday, from: day) - 1
        return symbols.indices.contains(index) ? symbols[index] : ""
    }
}

/// The current month; today sits on a pill.
struct MonthGrid: View {
    let date: Date
    let color: Color

    var body: some View {
        let cal = Calendar.current
        let weeks = Self.weeks(of: date, calendar: cal)
        let symbols = Self.headerSymbols(calendar: cal)
        Grid(horizontalSpacing: 0, verticalSpacing: 4) {
            GridRow {
                ForEach(0..<7, id: \.self) { i in
                    Text(symbols[i])
                        .opacity(0.5)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(weeks.indices, id: \.self) { w in
                GridRow {
                    ForEach(0..<7, id: \.self) { d in
                        if let day = weeks[w][d] {
                            let today = cal.isDate(day, inSameDayAs: date)
                            Text("\(cal.component(.day, from: day))")
                                .fontWeight(today ? .bold : .medium)
                                .frame(width: 30, height: 24)
                                .background {
                                    if today { Capsule().fill(color.opacity(0.22)) }
                                }
                                .opacity(today ? 1 : (cal.isDateInWeekend(day) ? 0.4 : 0.75))
                                .frame(maxWidth: .infinity)
                        } else {
                            Color.clear
                                .frame(height: 24)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .font(.system(size: 14, weight: .medium))
        .monospacedDigit()
    }

    /// Rows of 7 cells; nil before the 1st and after the last day.
    static func weeks(of date: Date, calendar cal: Calendar) -> [[Date?]] {
        guard let month = cal.dateInterval(of: .month, for: date),
              let days = cal.range(of: .day, in: .month, for: date) else { return [] }
        let offset = (cal.component(.weekday, from: month.start) - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: offset)
        for day in 0..<days.count {
            cells.append(cal.date(byAdding: .day, value: day, to: month.start))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    static func headerSymbols(calendar cal: Calendar) -> [String] {
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { symbols[(cal.firstWeekday - 1 + $0) % 7] }
    }
}

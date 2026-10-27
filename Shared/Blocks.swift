import MediaPlayer
import SwiftUI
import WidgetKit

// The blocks of a design, drawn in its look: font, ink (the foreground style), case and
// shadow. Everything is computed on the iPhone from the date and the block's own
// settings — no permissions, no network, no extra entitlements.

/// One block, sized to the box the design gives it. Open App blocks are drawn by
/// `DesignFace` itself, because their words are the widget's buttons.
struct BlockFace: View {
    let block: DesignBlock
    let look: Look
    let date: Date
    let size: FaceSize
    var battery: Double?
    let box: CGSize
    /// The app's previews: empty settings show what goes there.
    var placeholders = false

    private var alignment: Alignment { Alignment(horizontal: look.align.horizontal, vertical: .center) }
    private var textAlignment: TextAlignment { look.align.text }

    var body: some View {
        content
            .frame(width: box.width, height: box.height, alignment: alignment)
            .textCase(look.letterCase.textCase)
            .shadow(color: look.shadow ? Color.black.opacity(0.45) : .clear, radius: 6, x: 0, y: 3)
    }

    @ViewBuilder
    private var content: some View {
        switch block.kind {
        case .apps, .spacer:
            Color.clear
        case .text:
            words(block.text, placeholder: "Your words")
        case .quote:
            words(Quote.line(block.lines, on: date), placeholder: "A line for every day")
        case .greeting:
            fitted(Greeting.phrase(at: date, name: block.text), lines: 2, scale: 1.3)
        case .digitalClock:
            ClockText(date: date, option: block.clock == .off ? .time : block.clock, look: look, size: size)
        case .wordClock:
            fitted(WordClock.phrase(date), lines: 3, scale: 1.6)
        case .worldClock:
            worldClock
        case .bigDate:
            bigDate
        case .weekStrip:
            WeekStrip(date: date, look: look, box: box)
        case .monthGrid:
            MonthGrid(date: date, look: look, box: box)
        case .progress:
            progress
        case .daysUntil:
            daysUntil
        case .moon:
            moon
        case .music:
            MusicBlock(look: look, box: box, placeholders: placeholders)
        case .photo:
            PhotoBlock(block: block, box: box)
        case .analogClock, .countdownRing, .health, .battery, .vinyl, .calendarIcon:
            if let module = block.kind.module {
                ModuleTile(kind: module, date: date, battery: battery, look: look,
                           side: max(min(box.width, box.height), 1))
            }
        }
    }

    // MARK: Words

    /// Plain words in the design's size, as many lines as the box holds.
    @ViewBuilder
    private func words(_ text: String, placeholder: String) -> some View {
        let shown = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if shown.isEmpty {
            if placeholders {
                Text(placeholder).font(look.font(size: look.size)).opacity(0.5)
            }
        } else {
            Text(shown)
                .font(look.font(size: look.size))
                .lineLimit(max(Int(box.height / (look.size * 1.25)), 1))
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(textAlignment)
        }
    }

    /// Words set as large as the box allows, up to `scale` times the design's size: on
    /// one line if they fit, else on two, and so on up to `lines`.
    private func fitted(_ text: String, lines: Int, scale: Double) -> some View {
        // No line limit on the candidates: one whose words wrap too tall is passed over.
        ViewThatFits(in: .vertical) {
            ForEach(1...max(lines, 1), id: \.self) { count in
                Text(text)
                    .font(look.font(size: max(min(look.size * scale, Double(box.height) / (Double(count) * 1.25)), 9)))
                    .multilineTextAlignment(textAlignment)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(text)
                .font(look.font(size: max(Double(box.height) / (Double(lines) * 1.25), 9)))
                .lineLimit(lines)
                .minimumScaleFactor(0.4)
                .multilineTextAlignment(textAlignment)
        }
    }

    // MARK: Time

    private var worldClock: some View {
        let zones = Array(block.zones.compactMap(TimeZone.init(identifier:)).prefix(4))
        let rowSize = min(look.size * 0.8, Double(box.height) / (Double(max(zones.count, 1)) * 1.5))
        return VStack(alignment: look.align.horizontal, spacing: rowSize * 0.3) {
            ForEach(zones, id: \.identifier) { zone in
                HStack(spacing: 8) {
                    Text(WorldTime.city(zone.identifier))
                        .font(look.font(size: rowSize * 0.8))
                        .opacity(0.75)
                    Spacer(minLength: 6)
                    Text(WorldTime.time(date, in: zone))
                        .font(look.font(size: rowSize))
                        .monospacedDigit()
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
        }
    }

    // MARK: Date

    @ViewBuilder
    private var bigDate: some View {
        let h = Double(box.height)
        switch block.dateStyle {
        case .compact:
            Text("\(date.formatted(.dateTime.weekday(.abbreviated))) \(date.formatted(.dateTime.day()))".uppercased())
                .font(look.font(size: min(h * 0.62, look.size * 2.6), weight: .light))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .widgetAccentable()
        case .stacked:
            VStack(alignment: look.align.horizontal, spacing: 0) {
                Text(date.formatted(.dateTime.weekday(.wide)))
                    .font(look.font(size: min(h * 0.17, look.size * 0.9)))
                    .opacity(0.8)
                Text(date.formatted(.dateTime.day()))
                    .font(look.font(size: min(h * 0.52, look.size * 3.4), weight: .light))
                    .monospacedDigit()
                    .widgetAccentable()
                Text(date.formatted(.dateTime.month(.wide)))
                    .font(look.font(size: min(h * 0.17, look.size * 0.9)))
                    .opacity(0.8)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.4)
        case .full:
            VStack(alignment: look.align.horizontal, spacing: 2) {
                Text(date.formatted(.dateTime.weekday(.wide)))
                    .font(look.font(size: min(h * 0.4, look.size * 1.6), weight: .light))
                    .widgetAccentable()
                Text(date.formatted(.dateTime.day().month(.wide).year()))
                    .font(look.font(size: min(h * 0.22, look.size * 0.85)))
                    .opacity(0.8)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.4)
        }
    }

    @ViewBuilder
    private var progress: some View {
        let value = Progress(scope: block.scope, date: date)
        switch block.progressStyle {
        case .dots:
            ProgressDots(passed: value.passed, total: value.total)
                .widgetAccentable()
        case .fraction, .percent:
            let h = Double(box.height)
            VStack(alignment: look.align.horizontal, spacing: 2) {
                Text(block.progressStyle == .percent ? "\(Int((value.fraction * 100).rounded(.down)))%"
                                                     : "\(value.passed)/\(value.total)")
                    .font(look.font(size: min(h * 0.55, look.size * 2.6), weight: .light))
                    .monospacedDigit()
                    .widgetAccentable()
                Text(value.label)
                    .font(look.font(size: min(h * 0.2, look.size * 0.8)))
                    .opacity(0.75)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.4)
        }
    }

    @ViewBuilder
    private var daysUntil: some View {
        if let target = block.date {
            let calendar = Calendar.current
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                               to: calendar.startOfDay(for: target)).day ?? 0
            let title = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let h = Double(box.height)
            VStack(alignment: look.align.horizontal, spacing: 2) {
                Text("\(abs(days))")
                    .font(look.font(size: min(h * 0.55, look.size * 3), weight: .light))
                    .monospacedDigit()
                    .widgetAccentable()
                Text(title.isEmpty ? (days >= 0 ? String(localized: "days to go") : String(localized: "days since")) : title)
                    .font(look.font(size: min(h * 0.2, look.size * 0.8)))
                    .opacity(0.8)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.4)
        } else if placeholders {
            Text("Pick a date").font(look.font(size: look.size * 0.8)).opacity(0.5)
        }
    }

    @ViewBuilder
    private var moon: some View {
        let fraction = MoonPhase.fraction(at: date)
        let wide = box.width > box.height * 1.6
        let side = max(min(wide ? box.height : box.height * 0.68, box.width), 1)
        let layout = wide ? AnyLayout(HStackLayout(spacing: 10)) : AnyLayout(VStackLayout(spacing: 4))
        layout {
            MoonGlyph(fraction: fraction)
                .frame(width: side, height: side)
                .widgetAccentable()
            if box.height >= 40 {
                Text(MoonPhase.name(fraction))
                    .font(look.font(size: min(look.size * 0.75, Double(box.height) * 0.18)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }
}

// MARK: - Modules

/// One module: its line drawing and, where there is room, one reading in the design's
/// font. A widget redraws once a minute, so the clock has no second hand.
struct ModuleTile: View {
    let kind: ModuleKind
    let date: Date
    var battery: Double?
    let look: Look
    let side: CGFloat

    var body: some View {
        let reading = side >= 56 ? kind.reading(at: date, battery: battery) : nil
        VStack(spacing: side * 0.04) {
            ModuleGlyph(kind: kind, date: date, level: battery ?? 0, seconds: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .widgetAccentable()
                .overlay {
                    if kind == .vinyl { VinylLabel() }
                }
            if let reading {
                Text(reading)
                    .font(look.font(size: min(side * 0.17, look.size * 0.9)))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(width: side, height: side)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reading.map { "\(kind.title), \($0)" } ?? kind.title)
    }
}

/// The Photo block: the picture picked in the app, with no frame (edge to edge) or in one
/// of the frames. Before a picture is picked it shows where it will go.
private struct PhotoBlock: View {
    let block: DesignBlock
    let box: CGSize

    private var side: CGFloat { max(min(box.width, box.height), 1) }

    var body: some View {
        Group {
            if let image = SharedStore.shared.loadBlockPhoto(block.id) {
                // Tinted and Clear Home Screens: a toned photo, not a solid silhouette.
                framed(Image(uiImage: image).widgetAccentedRenderingMode(.accentedDesaturated)
                    .resizable().scaledToFill())
            } else {
                empty
            }
        }
        .frame(width: box.width, height: box.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Photo")
    }

    @ViewBuilder
    private func framed(_ picture: some View) -> some View {
        switch block.photoFrame {
        case .none:
            picture
                .frame(width: box.width, height: box.height)
                .clipped()
        case .rounded:
            picture
                .frame(width: box.width, height: box.height)
                .clipShape(RoundedRectangle(cornerRadius: side * 0.14, style: .continuous))
        case .circle:
            picture
                .frame(width: side, height: side)
                .clipShape(Circle())
        case .border:
            let shape = RoundedRectangle(cornerRadius: side * 0.1, style: .continuous)
            picture
                .frame(width: box.width, height: box.height)
                .clipShape(shape)
                .overlay { shape.strokeBorder(Color.white, lineWidth: max(side * 0.035, 2)) }
        case .polaroid:
            // A print: an even white margin, a deeper one below, tilted a little.
            let margin = side * 0.06
            let width = box.width * 0.86
            let height = box.height * 0.86
            picture
                .frame(width: width - 2 * margin, height: height - margin * 4.5)
                .clipped()
                .padding(.top, margin)
                .padding(.horizontal, margin)
                .padding(.bottom, margin * 3.5)
                .background(Color.white)
                .shadow(color: .black.opacity(0.3), radius: side * 0.03, y: side * 0.015)
                .rotationEffect(.degrees(-3))
        }
    }

    private var empty: some View {
        RoundedRectangle(cornerRadius: side * 0.12, style: .continuous)
            .strokeBorder(.foreground.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .overlay {
                VStack(spacing: side * 0.05) {
                    Image(systemName: "photo").font(.system(size: side * 0.22))
                    Text("Pick a photo in the app").font(.system(size: max(side * 0.09, 9), weight: .medium))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                }
                .padding(side * 0.06)
            }
    }
}

/// The Music block: the cover, the song and its artist, and three keys that skip, play
/// and pause in the Music app. It shows what Music played when the widget last redrew:
/// after every key tap, and every few minutes otherwise.
private struct MusicBlock: View {
    let look: Look
    let box: CGSize
    var placeholders = false

    var body: some View {
        let record = placeholders ? nil : NowPlayingStore.load()
        let allowed = placeholders || MPMediaLibrary.authorizationStatus() == .authorized
        let side = max(min(box.height, box.width * 0.42), 1)
        HStack(spacing: side * 0.12) {
            cover(side: side)
            VStack(alignment: .leading, spacing: side * 0.05) {
                Text(allowed ? record?.title ?? (placeholders ? "Song title" : "Nothing playing")
                             : "Allow Music access")
                    .font(look.font(size: min(look.size, Double(side) * 0.22)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(allowed ? record?.artist ?? "Music app" : "Open WidgetSimple")
                    .font(look.font(size: min(look.size * 0.75, Double(side) * 0.16)))
                    .opacity(0.7)
                    .lineLimit(1)
                HStack(spacing: side * 0.18) {
                    key(.previous, symbol: "backward.fill", label: "Previous")
                    key(.playPause, symbol: record?.playing == true ? "pause.fill" : "play.fill",
                        label: record?.playing == true ? "Pause" : "Play")
                    key(.next, symbol: "forward.fill", label: "Next")
                }
                .font(.system(size: min(side * 0.2, 22), weight: .semibold))
                .padding(.top, side * 0.04)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: box.width, height: box.height, alignment: .leading)
    }

    @ViewBuilder
    private func cover(side: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: side * 0.14, style: .continuous)
        if !placeholders, let image = NowPlayingStore.loadCover() {
            Image(uiImage: image)
                .widgetAccentedRenderingMode(.accentedDesaturated)
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .clipShape(shape)
                .accessibilityHidden(true)
        } else {
            shape
                .strokeBorder(.foreground.opacity(0.5), lineWidth: 1)
                .frame(width: side, height: side)
                .overlay { Image(systemName: "music.note").font(.system(size: side * 0.32)) }
                .accessibilityHidden(true)
        }
    }

    private func key(_ action: MusicAction, symbol: String, label: String) -> some View {
        Button(intent: MusicControlIntent(action)) {
            Image(systemName: symbol)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The record's centre label, holding the cover of what is playing (`NowPlayingArt`,
/// empty when nothing is saved): the circle the vinyl drawing rings at 0.34 of its 0.47
/// radius (`ModuleDrawing.vinyl`).
private struct VinylLabel: View {
    var body: some View {
        GeometryReader { geo in
            let side = max(min(geo.size.width, geo.size.height) - 2, 0) * 0.47 * 0.34 * 2
            NowPlayingArt()
                .frame(width: side, height: side)
                .clipShape(Circle())
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Week and month

/// The current week: one initial per day over its number, today ringed.
private struct WeekStrip: View {
    let date: Date
    let look: Look
    let box: CGSize

    var body: some View {
        let calendar = Calendar.current
        let days = Weeks.days(around: date, calendar: calendar)
        let column = box.width / 7
        let numberSize = min(Double(box.height) * 0.36, Double(column) * 0.5, look.size)
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                let today = calendar.isDate(day, inSameDayAs: date)
                VStack(spacing: numberSize * 0.2) {
                    Text(Weeks.initial(of: day, calendar: calendar))
                        .font(look.font(size: numberSize * 0.7))
                        .opacity(0.7)
                    Text("\(calendar.component(.day, from: day))")
                        .font(look.font(size: numberSize))
                        .monospacedDigit()
                        .padding(numberSize * 0.22)
                        .overlay {
                            if today { Circle().stroke(lineWidth: 1.2).widgetAccentable() }
                        }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: column)
            }
        }
    }
}

/// This month as a plain grid: weekday initials, the days, today ringed.
private struct MonthGrid: View {
    let date: Date
    let look: Look
    let box: CGSize

    var body: some View {
        let calendar = Calendar.current
        let cells = Weeks.monthCells(for: date, calendar: calendar)
        let rows = cells.count / 7
        let cellHeight = box.height / CGFloat(rows + 2)
        let size = min(Double(cellHeight) * 0.62, Double(box.width / 7) * 0.48, look.size)
        let today = calendar.component(.day, from: date)
        VStack(alignment: look.align.horizontal, spacing: 0) {
            Text(date.formatted(.dateTime.month(.wide).year()))
                .font(look.font(size: size))
                .frame(height: cellHeight)
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(0..<7, id: \.self) { column in
                        Text(Weeks.initial(of: cells[column] ?? Weeks.weekday(column, near: date, calendar: calendar),
                                           calendar: calendar))
                            .font(look.font(size: size * 0.8))
                            .opacity(0.6)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: cellHeight)
                ForEach(0..<rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<7, id: \.self) { column in
                            let day = cells[row * 7 + column].map { calendar.component(.day, from: $0) }
                            Text(day.map { "\($0)" } ?? "")
                                .font(look.font(size: size))
                                .monospacedDigit()
                                .frame(maxWidth: .infinity)
                                .background {
                                    if day == today {
                                        Circle().stroke(lineWidth: 1.1)
                                            .frame(width: cellHeight * 0.92, height: cellHeight * 0.92)
                                            .widgetAccentable()
                                    }
                                }
                        }
                    }
                    .frame(height: cellHeight)
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}

/// Weeks and months computed from the iPhone's calendar, first weekday included.
enum Weeks {
    static func days(around date: Date, calendar: Calendar) -> [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// Whole weeks covering the month; nil before the first and after the last day.
    static func monthCells(for date: Date, calendar: Calendar) -> [Date?] {
        guard let month = calendar.dateInterval(of: .month, for: date),
              let count = calendar.range(of: .day, in: .month, for: date)?.count else { return [] }
        let lead = (calendar.component(.weekday, from: month.start) - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: lead)
        for offset in 0..<count {
            cells.append(calendar.date(byAdding: .day, value: offset, to: month.start))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    /// The day in the week of `date` that sits in `column`, for the header initials.
    static func weekday(_ column: Int, near date: Date, calendar: Calendar) -> Date {
        days(around: date, calendar: calendar)[min(max(column, 0), 6)]
    }

    static func initial(of day: Date, calendar: Calendar) -> String {
        calendar.veryShortWeekdaySymbols[calendar.component(.weekday, from: day) - 1]
    }
}

// MARK: - Progress

/// How much of the year, month or day has gone: whole days (hours for the day).
struct Progress {
    let passed: Int
    let total: Int
    let fraction: Double
    let label: String

    init(scope: ProgressScope, date: Date) {
        let calendar = Calendar.current
        switch scope {
        case .year:
            total = calendar.range(of: .day, in: .year, for: date)?.count ?? 365
            passed = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
            label = date.formatted(.dateTime.year())
        case .month:
            total = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
            passed = calendar.component(.day, from: date)
            label = date.formatted(.dateTime.month(.wide))
        case .day:
            total = 24
            passed = calendar.component(.hour, from: date)
            label = String(localized: "Today")
        }
        let interval = calendar.dateInterval(of: scope == .year ? .year : scope == .month ? .month : .day, for: date)
        fraction = interval.map { min(max(date.timeIntervalSince($0.start) / $0.duration, 0), 1) }
            ?? Double(passed) / Double(max(total, 1))
    }
}

/// One dot per unit: passed ones filled with the ink, the current one ringed, the rest
/// a faint outline. The grid takes the box's shape.
private struct ProgressDots: View {
    let passed: Int
    let total: Int

    var body: some View {
        Canvas { context, size in
            let count = max(total, 1)
            let columns = max(Int((Double(count) * Double(size.width) / Double(max(size.height, 1))).squareRoot().rounded(.up)), 1)
            let rows = Int((Double(count) / Double(columns)).rounded(.up))
            let cell = min(size.width / CGFloat(columns), size.height / CGFloat(max(rows, 1)))
            let radius = cell * 0.32
            let originX = (size.width - cell * CGFloat(columns)) / 2
            let originY = (size.height - cell * CGFloat(rows)) / 2
            var filled = Path(), current = Path(), rest = Path()
            for index in 0..<count {
                let center = CGPoint(x: originX + cell * (CGFloat(index % columns) + 0.5),
                                     y: originY + cell * (CGFloat(index / columns) + 0.5))
                let dot = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                if index < passed - 1 { filled.addPath(dot) }
                else if index == passed - 1 { current.addPath(dot) }
                else { rest.addPath(dot) }
            }
            context.fill(filled, with: .foreground)
            context.stroke(current, with: .foreground, lineWidth: max(radius * 0.45, 0.8))
            var faint = context
            faint.opacity = 0.4
            faint.stroke(rest, with: .foreground, lineWidth: max(radius * 0.25, 0.5))
        }
        .accessibilityLabel("\(passed) of \(total)")
    }
}

// MARK: - Words for the time

enum WordClock {
    private static let hours = ["twelve", "one", "two", "three", "four", "five", "six",
                                "seven", "eight", "nine", "ten", "eleven"]

    /// "quarter past ten", to the nearest five minutes.
    static func phrase(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        var hour = parts.hour ?? 0
        var minute = Int((Double(parts.minute ?? 0) / 5).rounded()) * 5
        if minute == 60 { minute = 0; hour += 1 }
        let this = hours[hour % 12], next = hours[(hour + 1) % 12]
        switch minute {
        case 0: return "\(this) o'clock"
        case 5: return "five past \(this)"
        case 10: return "ten past \(this)"
        case 15: return "quarter past \(this)"
        case 20: return "twenty past \(this)"
        case 25: return "twenty-five past \(this)"
        case 30: return "half past \(this)"
        case 35: return "twenty-five to \(next)"
        case 40: return "twenty to \(next)"
        case 45: return "quarter to \(next)"
        case 50: return "ten to \(next)"
        default: return "five to \(next)"
        }
    }
}

enum Greeting {
    /// The hours a greeting changes at.
    static let boundaries = [5, 12, 17, 22]

    static func phrase(at date: Date, name: String) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let part: String
        switch hour {
        case 5..<12: part = String(localized: "Good morning")
        case 12..<17: part = String(localized: "Good afternoon")
        case 17..<22: part = String(localized: "Good evening")
        default: part = String(localized: "Good night")
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? part : "\(part), \(trimmed)"
    }
}

enum Quote {
    /// The line for this day; the lines take turns, one a day.
    static func line(_ lines: [String], on date: Date) -> String {
        let usable = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !usable.isEmpty else { return "" }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return usable[day % usable.count]
    }
}

enum WorldTime {
    /// "Europe/Berlin" → "Berlin".
    static func city(_ identifier: String) -> String {
        identifier.split(separator: "/").last.map(String.init)?.replacingOccurrences(of: "_", with: " ") ?? identifier
    }

    /// The time in one zone, following the iPhone's 12/24-hour setting.
    static func time(_ date: Date, in zone: TimeZone) -> String {
        var style = Date.FormatStyle.dateTime.hour().minute()
        style.timeZone = zone
        return date.formatted(style)
    }

    /// Cities the editor offers, by their time zone.
    static let choices = [
        "Pacific/Honolulu", "America/Los_Angeles", "America/Denver", "America/Chicago", "America/New_York",
        "America/Sao_Paulo", "Europe/London", "Europe/Lisbon", "Europe/Paris", "Europe/Berlin", "Europe/Madrid",
        "Europe/Rome", "Europe/Athens", "Europe/Istanbul", "Africa/Cairo", "Africa/Johannesburg", "Asia/Dubai",
        "Asia/Kolkata", "Asia/Bangkok", "Asia/Singapore", "Asia/Hong_Kong", "Asia/Shanghai", "Asia/Seoul",
        "Asia/Tokyo", "Australia/Sydney", "Pacific/Auckland",
    ]
}

// MARK: - Moon

enum MoonPhase {
    private static let synodicMonth = 29.530588853
    /// A new moon: 6 January 2000, 18:14 UTC.
    private static let reference = Date(timeIntervalSince1970: 947_182_440)

    /// Where the moon is in its cycle: 0 new, 0.5 full, back to 1.
    static func fraction(at date: Date) -> Double {
        let days = date.timeIntervalSince(reference) / 86_400
        let age = days.truncatingRemainder(dividingBy: synodicMonth)
        return (age < 0 ? age + synodicMonth : age) / synodicMonth
    }

    static func name(_ fraction: Double) -> String {
        switch fraction {
        case ..<0.034, 0.966...: return String(localized: "New moon")
        case ..<0.216: return String(localized: "Waxing crescent")
        case ..<0.284: return String(localized: "First quarter")
        case ..<0.466: return String(localized: "Waxing gibbous")
        case ..<0.534: return String(localized: "Full moon")
        case ..<0.716: return String(localized: "Waning gibbous")
        case ..<0.784: return String(localized: "Last quarter")
        default: return String(localized: "Waning crescent")
        }
    }
}

/// The moon as line art: its outline, and the lit part filled with the ink.
private struct MoonGlyph: View {
    let fraction: Double

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2 - 1
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            // Waxing, the right side is lit; waning, the left. The terminator is half an
            // ellipse whose width follows the phase.
            let side: CGFloat = fraction < 0.5 ? 1 : -1
            let squeeze = CGFloat(cos(2 * .pi * fraction))
            var lit = Path()
            let steps = 48
            for step in 0...steps {
                let angle = -Double.pi / 2 + Double.pi * Double(step) / Double(steps)
                let point = CGPoint(x: center.x + side * radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
                if step == 0 { lit.move(to: point) } else { lit.addLine(to: point) }
            }
            for step in 0...steps {
                let angle = Double.pi / 2 - Double.pi * Double(step) / Double(steps)
                lit.addLine(to: CGPoint(x: center.x + side * squeeze * radius * CGFloat(cos(angle)),
                                        y: center.y + radius * CGFloat(sin(angle))))
            }
            lit.closeSubpath()
            var fill = context
            fill.opacity = 0.9
            fill.fill(lit, with: .foreground)
            context.stroke(ModuleDrawing.circle(center, radius), with: .foreground, lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

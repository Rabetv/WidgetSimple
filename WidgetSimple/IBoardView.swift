import SwiftUI
import UIKit

/// Screen 01, Home. With no designs yet it is the template catalog. Then it is the
/// iBoard: date and time, every saved design as it really looks — with App 1, App 2…
/// where the apps picked in Edit Widget go — the plain Apps widget, the record deck and
/// a few counters, set as glass modules over the app's wallpaper.
struct IBoardView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var board: BoardStore

    var body: some View {
        if model.designs.isEmpty {
            PresetGalleryView(welcome: true)
        } else {
            hub
        }
    }

    private var hub: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LineArt.breath) {
                ScreenHeader(index: "01", section: "Home", title: "iBoard",
                             stamps: ["Build \(LineArt.version)"])
                DateTimeBlock()
                DesignsModule()
                HomeScreenModule()
                RecordDeck()
                counters
                Micro("End of board · \(model.designs.count) designs · \(blockCount) blocks", size: 7.5, tracking: 2)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, LineArt.margin)
            .padding(.bottom, 36)
        }
        .background(AppBackground())
    }

    private var blockCount: Int { model.designs.reduce(0) { $0 + $1.blocks.count } }
    private var slotCount: Int { model.designs.reduce(0) { $0 + $1.slotCount } }

    /// An asymmetric row: one wide counter, two narrow ones stacked beside it.
    private var counters: some View {
        HStack(alignment: .top, spacing: LineArt.gutter) {
            ModuleFrame("Designs", radius: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(model.designs.count)").font(.metric(44))
                    Micro("Saved · picked in Edit Widget", size: 7.5)
                    DesignMap(designs: model.designs)
                }
            }
            VStack(spacing: LineArt.gutter) {
                ModuleFrame("Blocks", radius: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(blockCount)").font(.metric(28))
                        Micro("In every design", size: 7)
                    }
                }
                ModuleFrame("App slots", radius: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(slotCount)").font(.metric(28))
                        Micro("Open App, in total", size: 7)
                    }
                }
            }
            .frame(width: 132)
        }
    }
}

/// The Apps widget on its own: the shared look and clock, the apps as App 1, App 2…
private struct HomeScreenModule: View {
    @EnvironmentObject private var board: BoardStore

    var body: some View {
        ModuleFrame("On the Home Screen", stamp: "Apps widget", foot: "Real ink") {
            Button { board.editAppsWidget() } label: {
                VStack(alignment: .leading, spacing: 8) {
                    WidgetMockup(design: nil, size: .medium)
                    HStack(spacing: 8) {
                        Micro("No design · every Apps widget", tone: .primary)
                        Hairline()
                        Micro("Edit ›", size: 7.5)
                    }
                }
            }
            .buttonStyle(PressScale())
            .accessibilityHint("Opens its style.")
        }
    }
}

/// Every saved design, as it lands on the Home Screen, at the size it was made for. A
/// tap opens it in the sandbox; holding it offers Rename and Delete.
private struct DesignsModule: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var board: BoardStore
    @State private var renaming: WidgetDesign?
    @State private var deleting: WidgetDesign?
    @State private var deletions = 0

    var body: some View {
        ModuleFrame("Your designs", stamp: "\(model.designs.count) saved", foot: "Hold one to rename or delete") {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(model.designs) { design in
                    Button { board.edit(design) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            WidgetMockup(design: design, size: shownSize(design))
                                .frame(maxWidth: maxWidth(shownSize(design)))
                                .frame(maxWidth: .infinity)
                            HStack(spacing: 8) {
                                Text(design.displayName)
                                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                                    .lineLimit(1)
                                Micro("\(shownSize(design).title) · \(design.blocks.count) blocks · \(design.slotCount) apps", size: 7)
                                Hairline()
                                Micro("Edit ›", size: 7.5)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressScale())
                    .contextMenu {
                        Button("Rename", systemImage: "pencil") { renaming = design }
                        Button("Delete", systemImage: "trash", role: .destructive) { deleting = design }
                    }
                    .accessibilityLabel("\(design.displayName). Opens it in the sandbox.")
                }
                Button {
                    board.tab = .templates
                } label: {
                    Label("New widget", systemImage: "plus")
                }
                .buttonStyle(BigKeyStyle(prominent: true))
            }
        }
        .sheet(item: $renaming) { design in
            NameSheet(title: "Rename", detail: "Edit Widget shows the new name next time it opens.",
                      name: design.name, action: "Rename") { name in
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    model.update(design.id) { $0.name = String(trimmed.prefix(32)) }
                }
                renaming = nil
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Delete “\(deleting?.displayName ?? "")”?", isPresented: presenting($deleting),
                            titleVisibility: .visible, presenting: deleting) { design in
            Button("Delete", role: .destructive) {
                model.deleteDesign(design.id)
                deletions += 1
            }
        } message: { _ in
            Text("Widgets showing it go back to the plain Apps widget.")
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: deletions)
    }

    /// The size a design is drawn at: its canvas once placed; rows fit any size.
    private func shownSize(_ design: WidgetDesign) -> FaceSize {
        design.isPlaced ? design.canvas : .medium
    }

    private func maxWidth(_ size: FaceSize) -> CGFloat {
        switch size {
        case .small: return 170
        case .medium: return .infinity
        case .large: return 300
        case .extraLarge: return 240
        }
    }

    private func presenting<T>(_ item: Binding<T?>) -> Binding<Bool> {
        Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
    }
}

/// One mark per design: doubled when it has Open App slots, dashed when it has none.
private struct DesignMap: View {
    let designs: [WidgetDesign]

    var body: some View {
        let grid = Array(repeating: GridItem(.fixed(22), spacing: 4), count: 3)
        LazyVGrid(columns: grid, alignment: .leading, spacing: 4) {
            ForEach(designs) { design in
                let apps = design.slotCount > 0
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.primary.opacity(apps ? 1 : 0.45),
                                  style: StrokeStyle(lineWidth: 1, dash: apps ? [] : [2, 2]))
                    .overlay {
                        if apps {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.5), lineWidth: 0.5)
                                .padding(3)
                        }
                    }
                    .frame(width: 22, height: 16)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The header block: ultra-bold time, the date, and a thin countdown line to midnight.
private struct DateTimeBlock: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            block(context.date)
        }
    }

    private func block(_ date: Date) -> some View {
        let calendar = Calendar.current
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 0
        return ModuleFrame("Date · Time", stamp: "iOS \(LineArt.systemVersion)", foot: "Min \(minute)/1440",
                           marks: .diagonal) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Clockwork.hoursMinutes(date))
                        .font(.metric(66))
                        .monospacedDigit()
                        .tracking(-2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%02d", calendar.component(.second, from: date)))
                            .font(.metric(20))
                            .monospacedDigit()
                        Micro(Clockwork.uses12Hour ? Clockwork.meridiem(date) : "Sec", size: 7)
                    }
                    Spacer(minLength: 6)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                            .font(.metric(22))
                        Micro(date.formatted(.dateTime.day().month(.abbreviated).year()), size: 8)
                    }
                }
                CountdownLine(fraction: Clockwork.dayFraction(date))
                    .frame(height: 22)
                HStack {
                    Micro("T–\(Clockwork.duration(Clockwork.untilMidnight(date)))", size: 8, tone: .primary)
                    Spacer()
                    Micro("To 00:00 · day \(day)", size: 8)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(date.formatted(date: .complete, time: .shortened))
    }
}

/// The day as a line: hour ticks, what is left drawn heavier, a needle at now.
private struct CountdownLine: View {
    let fraction: Double
    @Environment(\.displayScale) private var scale

    var body: some View {
        Canvas { context, size in
            let mid = size.height * 0.62
            let x = min(max(size.width * CGFloat(fraction), 4), size.width - 4)
            var faint = context
            faint.opacity = 0.35

            var track = Path()
            track.move(to: CGPoint(x: 0, y: mid))
            track.addLine(to: CGPoint(x: size.width, y: mid))
            faint.stroke(track, with: .foreground, lineWidth: 1 / scale)

            var ticks = Path()
            for hour in 0...24 {
                let tx = min(max(size.width * CGFloat(hour) / 24, 0.5), size.width - 0.5)
                let tall: CGFloat = hour % 6 == 0 ? 7 : 3.5
                ticks.move(to: CGPoint(x: tx, y: mid - tall))
                ticks.addLine(to: CGPoint(x: tx, y: mid))
            }
            faint.stroke(ticks, with: .foreground, lineWidth: 1 / scale)

            var left = Path()
            left.move(to: CGPoint(x: x, y: mid))
            left.addLine(to: CGPoint(x: size.width, y: mid))
            context.stroke(left, with: .foreground, lineWidth: 2)

            var needle = Path()
            needle.move(to: CGPoint(x: x, y: 6))
            needle.addLine(to: CGPoint(x: x, y: mid + 5))
            context.stroke(needle, with: .foreground, lineWidth: 1)

            var head = Path()
            head.move(to: CGPoint(x: x - 4, y: 0.5))
            head.addLine(to: CGPoint(x: x + 4, y: 0.5))
            head.addLine(to: CGPoint(x: x, y: 6))
            head.closeSubpath()
            context.stroke(head, with: .foreground, lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

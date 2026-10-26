import SwiftUI

/// Screen 02, the template catalog: a blank widget in every size, then placed designs
/// in families, each card a large line drawing of its layout drawn from its frames, so
/// the choice is made by structure alone. A tap copies the template into the sandbox.
/// The type specimens that restyle every Apps widget close the page.
///
/// With `welcome`, it is Home's first page while there are no designs yet.
struct PresetGalleryView: View {
    var welcome = false
    @EnvironmentObject private var board: BoardStore
    @EnvironmentObject private var model: AppModel
    @State private var filter: Filter = .all
    @State private var pendingType: LookTemplate?

    enum Filter: Hashable {
        case all
        case family(DesignBlueprint.Family)
        case type
    }

    private var filters: [(value: Filter, title: String)] {
        [(.all, "All")] + DesignBlueprint.Family.allCases.map { (.family($0), $0.title) }
            + (welcome ? [] : [(.type, "Type")])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LineArt.breath) {
                header
                PillPicker(options: filters, selection: $filter)
                    .environment(\.largeTargets, true)
                ForEach(DesignBlueprint.Family.allCases) { family in
                    if filter == .all || filter == .family(family) {
                        familySection(family)
                    }
                }
                if !welcome && (filter == .all || filter == .type) {
                    typeSection
                }
                Micro("Drawings carry structure only · no colour", size: 7.5, tracking: 2)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, LineArt.margin)
            .padding(.bottom, 40)
            .animation(.snappy, value: filter)
        }
        .background(AppBackground())
        .confirmationDialog("Use this template?", isPresented: presenting($pendingType), presenting: pendingType) { template in
            Button("Apply to all Apps widgets") {
                model.look = template.look
                model.clock = template.clock
            }
        } message: { _ in
            Text("Your current font, colour and layout are replaced.")
        }
    }

    @ViewBuilder
    private var header: some View {
        if welcome {
            VStack(alignment: .leading, spacing: 10) {
                ScreenHeader(index: "01", section: "Home", title: "Start here",
                             stamps: ["\(DesignBlueprint.all.count) templates"])
                Text("Pick a widget to start from. Then move things with your finger, and save it.")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            ScreenHeader(index: "02", section: "Template catalog", title: "Templates",
                         stamps: ["\(DesignBlueprint.all.count + LookTemplate.all.count) items"])
        }
    }

    private func familySection(_ family: DesignBlueprint.Family) -> some View {
        let blueprints = DesignBlueprint.all.filter { $0.family == family }
        return VStack(alignment: .leading, spacing: 12) {
            SectionRule(code: family.code, title: family.title, count: blueprints.count)
            Text(family.note)
                .font(.footnote)
                .foregroundStyle(.secondary)
            VStack(spacing: LineArt.gutter) {
                ForEach(Self.rows(blueprints), id: \.first?.id) { row in
                    HStack(alignment: .top, spacing: LineArt.gutter) {
                        ForEach(row) { blueprint in
                            TemplateCard(blueprint: blueprint, wide: row.count == 1 && blueprint.canvas == .medium) {
                                board.start(blueprint, model: model)
                            }
                        }
                        if row.count == 1 && row[0].canvas != .medium {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    /// A medium (wide) template takes a row of its own; the others go two by two.
    private static func rows(_ blueprints: [DesignBlueprint]) -> [[DesignBlueprint]] {
        var rows: [[DesignBlueprint]] = []
        var pending: DesignBlueprint?
        for blueprint in blueprints {
            if blueprint.canvas == .medium {
                rows.append([blueprint])
            } else if let first = pending {
                rows.append([first, blueprint])
                pending = nil
            } else {
                pending = blueprint
            }
        }
        if let pending { rows.append([pending]) }
        return rows
    }

    private var typeSection: some View {
        let columns = [GridItem(.flexible(), spacing: LineArt.gutter), GridItem(.flexible(), spacing: LineArt.gutter)]
        return VStack(alignment: .leading, spacing: 12) {
            SectionRule(code: "C-06", title: "Type Specimens", count: LookTemplate.all.count)
            Text("Font, size, case and spacing for every Apps widget at once.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: LineArt.gutter) {
                ForEach(Array(LookTemplate.all.enumerated()), id: \.element.id) { index, template in
                    TypeCard(template: template, code: String(format: "TY-%02d", index + 1)) { pendingType = template }
                }
            }
        }
    }

    private func presenting<T>(_ item: Binding<T?>) -> Binding<Bool> {
        Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
    }
}

/// A template: its layout drawn large on top, code, name and note under a rule.
private struct TemplateCard: View {
    let blueprint: DesignBlueprint
    /// A medium template alone in its row.
    let wide: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                BlueprintDrawing(canvas: blueprint.canvas, blocks: blueprint.blocks)
                    .frame(height: wide ? 150 : 160)
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                Hairline()
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Stamp(blueprint.id)
                        Spacer(minLength: 0)
                        Micro("Use ›", size: 7.5, tone: .primary)
                    }
                    Text(blueprint.name)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Micro(blueprint.note, size: 7, tracking: 1)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(cornerRadius: LineArt.moduleRadius)
            .contentShape(RoundedRectangle(cornerRadius: LineArt.moduleRadius, style: .continuous))
        }
        .buttonStyle(PressScale())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(blueprint.name), \(blueprint.note). Opens it in the sandbox.")
        .accessibilityAddTraits(.isButton)
    }
}

/// A layout as a line drawing: the widget's outline at its real aspect, and every block
/// where its frame puts it, with a sign of what it shows. A blank widget gets a plus.
struct BlueprintDrawing: View {
    let canvas: FaceSize
    let blocks: [DesignBlock]
    @Environment(\.displayScale) private var scale

    var body: some View {
        Canvas { context, size in
            let aspect = canvas.aspectRatio
            let fit = min(size.width, size.height * aspect)
            let widget = CGRect(x: (size.width - fit) / 2, y: (size.height - fit / aspect) / 2,
                                width: fit, height: fit / aspect).insetBy(dx: 0.5, dy: 0.5)
            var faint = context
            faint.opacity = 0.55
            context.stroke(Path(roundedRect: widget, cornerRadius: min(widget.width, widget.height) * 0.14,
                                style: .continuous),
                           with: .foreground, lineWidth: 1.2)
            if blocks.isEmpty {
                let arm = min(widget.width, widget.height) * 0.12
                var plus = Path()
                plus.move(to: CGPoint(x: widget.midX - arm, y: widget.midY))
                plus.addLine(to: CGPoint(x: widget.midX + arm, y: widget.midY))
                plus.move(to: CGPoint(x: widget.midX, y: widget.midY - arm))
                plus.addLine(to: CGPoint(x: widget.midX, y: widget.midY + arm))
                context.stroke(plus, with: .foreground, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                faint.stroke(Path(roundedRect: widget.insetBy(dx: widget.width * 0.08, dy: widget.height * 0.08),
                                  cornerRadius: min(widget.width, widget.height) * 0.08, style: .continuous),
                             with: .foreground, style: StrokeStyle(lineWidth: 1 / scale, dash: [3, 3]))
                return
            }
            for block in blocks {
                guard let frame = block.frame else { continue }
                let rect = frame.rect(in: widget.size).offsetBy(dx: widget.minX, dy: widget.minY).insetBy(dx: 1, dy: 1)
                let outline = Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) * 0.12, style: .continuous)
                if block.kind == .spacer {
                    faint.stroke(outline, with: .foreground, style: StrokeStyle(lineWidth: 1 / scale, dash: [2, 2]))
                } else {
                    faint.stroke(outline, with: .foreground, lineWidth: 1 / scale)
                }
                sign(block, in: rect.insetBy(dx: min(rect.width, rect.height) * 0.12,
                                             dy: min(rect.width, rect.height) * 0.12),
                     context: context)
            }
        }
        .accessibilityHidden(true)
    }

    /// What a block shows, in a few lines.
    private func sign(_ block: DesignBlock, in r: CGRect, context: GraphicsContext) {
        var faint = context
        faint.opacity = 0.6
        let round = StrokeStyle(lineWidth: 1.5, lineCap: .round)
        func line(_ y: CGFloat, _ length: CGFloat) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: r.minX, y: y))
            path.addLine(to: CGPoint(x: r.minX + r.width * length, y: y))
            return path
        }
        func figure(_ text: String, size: CGFloat) {
            context.draw(Text(text).font(.system(size: max(size, 6), weight: .light, design: .rounded)),
                         at: CGPoint(x: r.midX, y: r.midY))
        }

        if let module = block.kind.module {
            ModuleDrawing.draw(ModuleDrawing.strokes(module, in: r), in: context, widthScale: 0.7)
            return
        }
        switch block.kind {
        case .apps:
            let count = max(min(block.slots, DesignBlock.maxSlots), 1)
            let columns = min(max(Int((Double(count) * Double(r.width / max(r.height, 1)) / 3).squareRoot().rounded(.up)), 1), count)
            let rows = Int((Double(count) / Double(columns)).rounded(.up))
            let gap = min(r.width, r.height) * 0.06
            let cellW = (r.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
            let cellH = min((r.height - gap * CGFloat(rows - 1)) / CGFloat(rows), cellW * 0.6)
            for slot in 0..<count {
                let cell = CGRect(x: r.minX + CGFloat(slot % columns) * (cellW + gap),
                                  y: r.minY + CGFloat(slot / columns) * (cellH + gap), width: cellW, height: cellH)
                context.stroke(Path(roundedRect: cell, cornerRadius: min(cellW, cellH) * 0.25, style: .continuous),
                               with: .foreground, lineWidth: 1)
                var word = Path()
                word.move(to: CGPoint(x: cell.minX + cellW * 0.18, y: cell.midY))
                word.addLine(to: CGPoint(x: cell.minX + cellW * 0.66, y: cell.midY))
                faint.stroke(word, with: .foreground, style: round)
            }
        case .digitalClock:
            figure("10:10", size: min(r.height * 0.6, r.width * 0.3))
        case .bigDate:
            figure("26", size: min(r.height * 0.6, r.width * 0.6))
        case .daysUntil:
            figure("30", size: min(r.height * 0.55, r.width * 0.5))
        case .text, .quote, .greeting, .wordClock:
            let count = max(min(Int(r.height / 9), 3), 1)
            for index in 0..<count {
                let y = r.minY + r.height * (CGFloat(index) + 0.5) / CGFloat(count)
                faint.stroke(line(y, [0.9, 0.62, 0.76][index]), with: .foreground, style: round)
            }
        case .worldClock:
            for index in 0..<3 {
                let y = r.minY + r.height * (CGFloat(index) + 0.5) / 3
                faint.stroke(line(y, 0.45), with: .foreground, style: round)
                var time = Path()
                time.move(to: CGPoint(x: r.maxX - r.width * 0.25, y: y))
                time.addLine(to: CGPoint(x: r.maxX, y: y))
                context.stroke(time, with: .foreground, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        case .weekStrip:
            let step = r.width / 7, radius = min(step * 0.3, r.height * 0.3)
            for day in 0..<7 {
                let center = CGPoint(x: r.minX + step * (CGFloat(day) + 0.5), y: r.midY)
                if day == 3 {
                    context.stroke(ModuleDrawing.circle(center, radius), with: .foreground, lineWidth: 1.2)
                } else {
                    faint.fill(ModuleDrawing.circle(center, radius * 0.35), with: .foreground)
                }
            }
        case .monthGrid, .progress:
            let columns = 7, rows = 5
            let cell = min(r.width / CGFloat(columns), r.height / CGFloat(rows))
            var dots = Path()
            for index in 0..<(columns * rows) {
                let center = CGPoint(x: r.midX + cell * (CGFloat(index % columns) - CGFloat(columns - 1) / 2),
                                     y: r.midY + cell * (CGFloat(index / columns) - CGFloat(rows - 1) / 2))
                dots.addPath(ModuleDrawing.circle(center, max(cell * 0.14, 0.6)))
            }
            faint.fill(dots, with: .foreground)
        case .moon:
            let radius = min(r.width, r.height) / 2
            let center = CGPoint(x: r.midX, y: r.midY)
            context.stroke(ModuleDrawing.circle(center, radius), with: .foreground, lineWidth: 1)
            var lit = Path()
            lit.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            lit.closeSubpath()
            faint.fill(lit, with: .foreground)
        default:
            break
        }
    }
}

/// A type template shown as a specimen: the clock and three words in its own font,
/// size ratio, case, alignment and spacing.
private struct TypeCard: View {
    let template: LookTemplate
    let code: String
    let action: () -> Void

    private var look: Look { template.look }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: look.align.horizontal, spacing: 3 * look.spacing) {
                    if template.clock != .off {
                        Text("10:10")
                            .font(look.font(size: look.size * 1.15, weight: .semibold))
                            .monospacedDigit()
                    }
                    ForEach(["Phone", "Messages", "Music"], id: \.self) { name in
                        Text(name)
                            .font(look.font(size: look.size * 0.72))
                            .textCase(look.letterCase.textCase)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, minHeight: 118, alignment: look.alignment)
                .padding(14)
                Hairline()
                VStack(alignment: .leading, spacing: 4) {
                    Stamp(code)
                    Text(template.name)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                    Micro(FontCatalog.displayName(for: look.fontID), size: 7, tracking: 1)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(cornerRadius: LineArt.moduleRadius)
            .contentShape(RoundedRectangle(cornerRadius: LineArt.moduleRadius, style: .continuous))
        }
        .buttonStyle(PressScale())
    }
}

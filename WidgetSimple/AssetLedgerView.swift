import SwiftUI

/// What the asset ledger lists.
enum AssetFamily: String, CaseIterable, Identifiable {
    case block, mechanical, decal, font, stamp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .block: return "Blocks"
        case .mechanical: return "Mechanical"
        case .decal: return "Decals"
        case .font: return "Font Files"
        case .stamp: return "Stamps"
        }
    }

    var code: String {
        switch self {
        case .block: return "BK"
        case .mechanical: return "MC"
        case .decal: return "DC"
        case .font: return "FT"
        case .stamp: return "ST"
        }
    }
}

enum AssetArt {
    enum Decal { case cropMarks, sticker, edgeCut, ruler, marching }

    case module(ModuleKind)
    /// A design block, by its own sign.
    case block(BlockKind)
    case slot
    case token
    case decal(Decal)
    /// A `FontCatalog` id, or "ui:metric" / "ui:micro" for the configurator's own type.
    case font(String)
    case stamp(String)
}

/// One installed component with its layout requirements.
struct AssetItem: Identifiable {
    struct Rule: Identifiable {
        let key: String
        let value: String
        var id: String { key }
        init(_ key: String, _ value: String) {
            self.key = key
            self.value = value
        }
    }

    let id: String
    let name: String
    let family: AssetFamily
    let art: AssetArt
    /// Bounding box in points; nil for type, which scales instead.
    let box: CGSize?
    /// Columns × rows on a four-column Home Screen grid.
    let span: (columns: Int, rows: Int)?
    let version: String
    let rules: [Rule]
    /// The block it is, for the Blocks family: its sheet can start a widget with it.
    var block: BlockKind? = nil

    var boxLabel: String {
        guard let box else { return "12–34 pt" }
        return "\(Int(box.width))×\(Int(box.height))"
    }
}

enum AssetCatalog {
    static func items() -> [AssetItem] {
        blocks + mechanical + decals + fonts() + stamps
    }

    /// Every kind of block a design can hold, at the size a new one starts at.
    private static var blocks: [AssetItem] {
        let groups = Dictionary(BlockKind.groups.flatMap { group in group.kinds.map { ($0, group.title) } },
                                uniquingKeysWith: { first, _ in first })
        return BlockKind.allCases.enumerated().map { offset, kind in
            let box = kind.droppedSize
            return AssetItem(id: String(format: "BK-%02d", offset + 1), name: kind.title, family: .block,
                             art: .block(kind), box: box, span: nil, version: "1.0", rules: [
                                 .init("Group", groups[kind] ?? "—"),
                                 .init("Starts at", "\(Int(box.width)) × \(Int(box.height)) pt, in the middle"),
                                 .init("Place", "Drag anywhere · snaps to the grid"),
                                 .init("Size", "Drag a handle · 3 × 2 cells at least"),
                                 .init("Refresh", kind == .battery ? "About every 30 min"
                                       : DesignBlock(kind).followsMinute ? "Every minute" : "At midnight"),
                             ], block: kind)
        }
    }

    private static let mechanical: [AssetItem] = [
        AssetItem(id: "MC-01", name: "Clock", family: .mechanical, art: .module(.clock),
                  box: CGSize(width: 158, height: 158), span: (2, 2), version: "1.2", rules: [
                      .init("Aspect", "1 : 1, locked"), .init("Minimum", "76 × 76 pt"),
                      .init("Padding", "12 pt"), .init("Refresh", "Every 60 s"), .init("Resize", "Uniform only"),
                  ]),
        AssetItem(id: "MC-02", name: "Countdown", family: .mechanical, art: .module(.countdown),
                  box: CGSize(width: 158, height: 158), span: (2, 2), version: "1.0", rules: [
                      .init("Aspect", "1 : 1, locked"), .init("Target", "00:00 local"),
                      .init("Ring", "2.5 pt arc on 1 pt track"), .init("Refresh", "Every 60 s"),
                  ]),
        AssetItem(id: "MC-03", name: "Health Chart", family: .mechanical, art: .module(.health),
                  box: CGSize(width: 338, height: 158), span: (4, 2), version: "0.9", rules: [
                      .init("Aspect", "2.14 : 1"), .init("Resize", "Horizontal only"),
                      .init("Rules", "3 baselines, 1 px"), .init("Data", "Sample line, nothing read"),
                  ]),
        AssetItem(id: "MC-04", name: "Battery Bar", family: .mechanical, art: .module(.battery),
                  box: CGSize(width: 158, height: 76), span: (2, 1), version: "1.1", rules: [
                      .init("Aspect", "2.08 : 1"), .init("Cells", "5, hatched when charged"),
                      .init("Source", "iPhone battery level"), .init("Resize", "Horizontal only"),
                  ]),
        AssetItem(id: "MC-05", name: "Vinyl Deck", family: .mechanical, art: .module(.vinyl),
                  box: CGSize(width: 338, height: 158), span: (4, 2), version: "2.0", rules: [
                      .init("Platter", "Circle, diameter = height"), .init("Rotation", "200°/s · 33⅓ rpm"),
                      .init("Tonearm", "Pivot 1.13 d, reach 0.75 d"), .init("Cue", "Drag the playback bar"),
                  ]),
        AssetItem(id: "MC-06", name: "Calendar", family: .mechanical, art: .module(.calendar),
                  box: CGSize(width: 158, height: 158), span: (2, 2), version: "1.0", rules: [
                      .init("Grid", "7 × 4 cells"), .init("Today", "Doubled outline"), .init("Refresh", "At midnight"),
                  ]),
        AssetItem(id: "MC-07", name: "Open App Slot", family: .mechanical, art: .slot,
                  box: CGSize(width: 100, height: 88), span: (1, 1), version: "2.0", rules: [
                      .init("Label", "App 1 … App 12, in order"), .init("Filled in", "Edit Widget"),
                      .init("Tap", "Opens the app"), .init("Hit area", "The whole word"),
                  ]),
        AssetItem(id: "MC-08", name: "Design Block", family: .mechanical, art: .token,
                  box: CGSize(width: 338, height: 52), span: (4, 1), version: "1.0", rules: [
                      .init("Place", "Anywhere, by hand"), .init("Snap", "About 14 pt grid"),
                      .init("Kinds", "\(BlockKind.allCases.count)"), .init("Refresh", "Per minute only for clocks"),
                  ]),
    ]

    private static let decals: [AssetItem] = [
        AssetItem(id: "DC-01", name: "Crop Marks", family: .decal, art: .decal(.cropMarks),
                  box: CGSize(width: 6, height: 6), span: nil, version: "1.0", rules: [
                      .init("Stroke", "1 px"), .init("Arm", "6 pt"), .init("Offset", "4 pt outside the corner"),
                  ]),
        AssetItem(id: "DC-02", name: "Sticker Border", family: .decal, art: .decal(.sticker),
                  box: CGSize(width: 44, height: 13), span: nil, version: "1.0", rules: [
                      .init("Stroke", "1 px"), .init("Radius", "3 pt continuous"),
                      .init("Padding", "4.5 × 2.5 pt"), .init("Type", "Avenir Next Bold 7.5"),
                  ]),
        AssetItem(id: "DC-03", name: "Edge Cut Tag", family: .decal, art: .decal(.edgeCut),
                  box: CGSize(width: 80, height: 12), span: nil, version: "1.0", rules: [
                      .init("Cut", "A gap in the 1 pt rule"), .init("Inset", "Corner radius + 4 pt"),
                      .init("Centre", "On the edge line"),
                  ]),
        AssetItem(id: "DC-04", name: "Tick Ruler", family: .decal, art: .decal(.ruler),
                  box: CGSize(width: 300, height: 36), span: nil, version: "1.0", rules: [
                      .init("Major", "Every 5 steps, 12 pt"), .init("Minor", "6 pt"), .init("Stroke", "1 px"),
                  ]),
        AssetItem(id: "DC-05", name: "Marching Border", family: .decal, art: .decal(.marching),
                  box: CGSize(width: 100, height: 88), span: nil, version: "1.0", rules: [
                      .init("Dash", "5 on · 4 off"), .init("Loop", "0.8 s"), .init("Meaning", "A spot to fill"),
                  ]),
    ]

    private static func fonts() -> [AssetItem] {
        var items = [
            AssetItem(id: "FT-01", name: "SF Pro Rounded Heavy", family: .font, art: .font("ui:metric"),
                      box: nil, span: nil, version: "System", rules: [
                          .init("Role", "Primary metrics"), .init("Figures", "Monospaced digits"),
                      ]),
            AssetItem(id: "FT-02", name: "Avenir Next Demi Bold", family: .font, art: .font("ui:micro"),
                      box: nil, span: nil, version: "System", rules: [
                          .init("Role", "Sub-labels"), .init("Size", "6.5–9 pt"), .init("Tracking", "+1.0 to +2.2"),
                      ]),
        ]
        let widgetFonts = FontCatalog.systemFonts.map { ($0, "Built into iOS") }
            + FontCatalog.importedFonts.map { ($0, "Imported .ttf / .otf") }
        for (offset, entry) in widgetFonts.enumerated() {
            items.append(AssetItem(id: String(format: "FT-%02d", offset + 3), name: entry.0.name, family: .font,
                                   art: .font(entry.0.id), box: nil, span: nil, version: "—", rules: [
                                       .init("Role", "Widget words"), .init("Scale", "12–34 pt"),
                                       .init("Source", entry.1),
                                   ]))
        }
        return items
    }

    private static let stamps: [AssetItem] = [
        AssetItem(id: "ST-01", name: "Minute Counter", family: .stamp, art: .stamp("Min 1241"),
                  box: CGSize(width: 52, height: 13), span: nil, version: "1.0", rules: [
                      .init("Updates", "Every second"), .init("Range", "0–1439"),
                  ]),
        AssetItem(id: "ST-02", name: "System Version", family: .stamp, art: .stamp("iOS 27.0"),
                  box: CGSize(width: 48, height: 13), span: nil, version: "1.0", rules: [
                      .init("Source", "Running iOS version"),
                  ]),
        AssetItem(id: "ST-03", name: "Slot Index", family: .stamp, art: .stamp("S-01"),
                  box: CGSize(width: 30, height: 13), span: nil, version: "1.0", rules: [
                      .init("Range", "S-01 – S-06"), .init("Emphasis", "Doubles when unlocked"),
                  ]),
        AssetItem(id: "ST-04", name: "Build Tag", family: .stamp, art: .stamp("Build 1.0"),
                  box: CGSize(width: 52, height: 13), span: nil, version: "1.0", rules: [
                      .init("Source", "App version"),
                  ]),
        AssetItem(id: "ST-05", name: "Side Marker", family: .stamp, art: .stamp("Side A"),
                  box: CGSize(width: 40, height: 13), span: nil, version: "1.0", rules: [
                      .init("Use", "Deck module edge"),
                  ]),
    ]
}

/// Screen 03, Components: a ledger of every block, installed component, decal, font
/// file and stamp, one glass panel per family, with a half-screen sheet that breaks one
/// down. A block's sheet can start a new widget with it.
struct AssetLedgerView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var board: BoardStore
    @State private var filter: AssetFamily?
    @State private var selected: AssetItem?
    /// The block to start a widget with once the sheet has gone.
    @State private var starting: BlockKind?
    @State private var items = AssetCatalog.items()

    private var families: [AssetFamily] {
        filter.map { [$0] } ?? AssetFamily.allCases
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LineArt.breath) {
                ScreenHeader(index: "03", section: "Blocks & assets", title: "Components",
                             stamps: ["\(items.count) installed"])
                PillPicker(options: [(AssetFamily?.none, "All")] + AssetFamily.allCases.map { (Optional($0), $0.title) },
                           selection: $filter)
                    .environment(\.largeTargets, true)
                ForEach(families) { family in
                    ledger(family)
                }
            }
            .padding(.horizontal, LineArt.margin)
            .padding(.bottom, 40)
            .animation(.snappy, value: filter)
        }
        .background(AppBackground())
        .onAppear { items = AssetCatalog.items() }
        .sheet(item: $selected, onDismiss: {
            if let kind = starting {
                starting = nil
                board.start(with: kind, model: model)
            }
        }) { item in
            AssetDetailSheet(item: item) { kind in
                starting = kind
                selected = nil
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
        }
    }

    private func ledger(_ family: AssetFamily) -> some View {
        let rows = items.filter { $0.family == family }
        return VStack(alignment: .leading, spacing: 0) {
            SectionRule(code: family.code, title: family.title, count: rows.count)
                .padding(.bottom, 12)
            HStack(spacing: 12) {
                Micro("No.", size: 7).frame(width: 40, alignment: .leading)
                Micro("Item", size: 7)
                Spacer()
                Micro("Box · pt", size: 7)
            }
            .padding(.bottom, 6)
            Hairline(opacity: 0.6)
            ForEach(rows) { item in
                Button { selected = item } label: { LedgerRow(item: item) }
                    .buttonStyle(.plain)
                Hairline()
            }
        }
        .padding(LineArt.inset + 2)
        .glassPanel(cornerRadius: LineArt.moduleRadius)
    }
}

private struct LedgerRow: View {
    let item: AssetItem

    var body: some View {
        HStack(spacing: 12) {
            Text(item.id)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
            AssetArtView(art: item.art, size: 18)
                .frame(width: 36, height: 36)
                .lineBorder(radius: LineArt.keyRadius, weight: .pixel)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Micro("\(item.family.title) · v\(item.version) · installed", size: 7, tracking: 1)
            }
            Spacer(minLength: 8)
            Text(item.boxLabel)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .light))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name), \(item.family.title), \(item.boxLabel)")
        .accessibilityAddTraits(.isButton)
    }
}

/// An asset's own drawing, at any size.
struct AssetArtView: View {
    let art: AssetArt
    var size: CGFloat = 18

    var body: some View {
        switch art {
        case .module(let kind):
            ModuleGlyph(kind: kind).padding(size * 0.2)
        case .block(let kind):
            BlockIcon(kind: kind, symbolSize: size * 0.85)
        case .slot:
            RoundedRectangle(cornerRadius: size * 0.35, style: .continuous)
                .strokeBorder(Color.primary, lineWidth: 1)
                .overlay(alignment: .bottomLeading) {
                    Capsule().fill(Color.primary.opacity(0.7)).frame(width: size * 0.6, height: 1.5).padding(size * 0.25)
                }
                .padding(size * 0.25)
        case .token:
            Text("Aa")
                .font(.system(size: size * 0.55, weight: .bold, design: .rounded))
                .padding(.horizontal, size * 0.3)
                .padding(.vertical, size * 0.1)
                .overlay { Capsule().strokeBorder(Color.primary, lineWidth: 1) }
        case .decal(let decal):
            DecalDrawing(decal: decal).padding(size * 0.25)
        case .font(let id):
            Text("Ag")
                .font(font(id))
                .lineLimit(1)
                .minimumScaleFactor(0.3)
        case .stamp(let text):
            Stamp(text).scaleEffect(size / 18)
        }
    }

    private func font(_ id: String) -> Font {
        switch id {
        case "ui:metric": return .metric(size)
        case "ui:micro": return .custom("AvenirNext-DemiBold", fixedSize: size)
        default: return FontCatalog.font(id: id, size: size)
        }
    }
}

private struct DecalDrawing: View {
    let decal: AssetArt.Decal
    @Environment(\.displayScale) private var scale

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            var faint = context
            faint.opacity = 0.45
            switch decal {
            case .cropMarks:
                let box = rect.insetBy(dx: size.width * 0.22, dy: size.height * 0.22)
                faint.stroke(Path(roundedRect: box, cornerRadius: box.width * 0.2), with: .foreground,
                             style: StrokeStyle(lineWidth: 1 / scale, dash: [2, 2]))
                context.stroke(CropMarks(corners: .diagonal, length: box.width * 0.3, gap: box.width * 0.14).path(in: box),
                               with: .foreground, lineWidth: 1)
            case .sticker:
                let box = rect.insetBy(dx: 1, dy: size.height * 0.3)
                context.stroke(Path(roundedRect: box, cornerRadius: 3), with: .foreground, lineWidth: 1 / scale)
                var text = Path()
                text.move(to: CGPoint(x: box.minX + box.width * 0.2, y: box.midY))
                text.addLine(to: CGPoint(x: box.maxX - box.width * 0.2, y: box.midY))
                context.stroke(text, with: .foreground, style: StrokeStyle(lineWidth: 1.5, dash: [3, 1.5]))
            case .edgeCut:
                var rule = Path()
                rule.move(to: CGPoint(x: 0, y: rect.midY))
                rule.addLine(to: CGPoint(x: rect.width * 0.25, y: rect.midY))
                rule.move(to: CGPoint(x: rect.width * 0.75, y: rect.midY))
                rule.addLine(to: CGPoint(x: rect.width, y: rect.midY))
                context.stroke(rule, with: .foreground, lineWidth: 1)
                var text = Path()
                text.move(to: CGPoint(x: rect.width * 0.32, y: rect.midY))
                text.addLine(to: CGPoint(x: rect.width * 0.68, y: rect.midY))
                faint.stroke(text, with: .foreground, style: StrokeStyle(lineWidth: 1.5, dash: [2, 1.5]))
            case .ruler:
                var ticks = Path()
                for i in 0...10 {
                    let x = rect.width * CGFloat(i) / 10
                    let tall = i % 5 == 0 ? rect.height * 0.5 : rect.height * 0.25
                    ticks.move(to: CGPoint(x: min(max(x, 0.5), rect.width - 0.5), y: rect.midY - tall / 2))
                    ticks.addLine(to: CGPoint(x: min(max(x, 0.5), rect.width - 0.5), y: rect.midY + tall / 2))
                }
                context.stroke(ticks, with: .foreground, lineWidth: 1 / scale)
            case .marching:
                context.stroke(Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: rect.width * 0.2, style: .continuous),
                               with: .foreground, style: StrokeStyle(lineWidth: 1.25, dash: [3, 2.5]))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Detail

/// The half-screen breakdown: bounding box with dimension lines, the grid span, and
/// the layout requirements as a ledger.
private struct AssetDetailSheet: View {
    let item: AssetItem
    /// Starts a new widget with this block.
    let addBlock: (BlockKind) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Micro("\(item.family.title) · \(item.id)")
                        Text(item.name)
                            .font(.metric(26))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer(minLength: 8)
                    CloseKey { dismiss() }
                }
                if let kind = item.block {
                    Button { addBlock(kind) } label: {
                        Label("Add to a new widget", systemImage: "plus")
                    }
                    .buttonStyle(BigKeyStyle(prominent: true))
                }
                HStack(alignment: .top, spacing: LineArt.gutter) {
                    Group {
                        if case .font(let id) = item.art {
                            TypeDiagram(fontID: id)
                        } else {
                            BoundingBoxDiagram(item: item)
                        }
                    }
                    .frame(height: 170)
                    .frame(maxWidth: .infinity)
                    .lineBorder(radius: LineArt.innerRadius)
                    VStack(spacing: 8) {
                        SpanGrid(span: item.span)
                            .frame(width: 96, height: 96)
                            .lineBorder(radius: LineArt.innerRadius)
                        Micro(item.span.map { "Span \($0.columns)×\($0.rows)" } ?? "Free span", size: 7)
                        Stamp("v\(item.version)")
                    }
                }
                VStack(spacing: 0) {
                    HStack {
                        Micro("Requirement", size: 7)
                        Spacer()
                        Micro("Constraint", size: 7)
                    }
                    .padding(.bottom, 6)
                    Hairline(opacity: 0.6)
                    row("Bounding box", item.box.map { "\(Int($0.width)) × \(Int($0.height)) pt" } ?? "Scales with size")
                    ForEach(item.rules) { rule in
                        row(rule.key, rule.value)
                    }
                }
            }
            .padding(20)
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Micro(key, size: 8)
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 11)
            Hairline()
        }
    }
}

/// The component fitted into a dashed bounding box, with dimension lines, anchor
/// rings at the corners and a crosshair at the centre.
private struct BoundingBoxDiagram: View {
    let item: AssetItem
    @Environment(\.displayScale) private var scale

    var body: some View {
        GeometryReader { geo in
            let area = CGRect(x: 32, y: 16, width: geo.size.width - 48, height: geo.size.height - 50)
            let box = item.box ?? CGSize(width: 1, height: 1)
            let fit = min(area.width / box.width, area.height / box.height)
            let frame = CGRect(x: area.midX - box.width * fit / 2, y: area.midY - box.height * fit / 2,
                               width: box.width * fit, height: box.height * fit)
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in draw(in: context, frame: frame, box: box) }
                AssetArtView(art: item.art, size: min(frame.width, frame.height) * 0.55)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }
        }
        .accessibilityHidden(true)
    }

    private func draw(in context: GraphicsContext, frame: CGRect, box: CGSize) {
        var faint = context
        faint.opacity = 0.5
        faint.stroke(Path(frame), with: .foreground, style: StrokeStyle(lineWidth: 1 / scale, dash: [3, 2]))

        for corner in [CGPoint(x: frame.minX, y: frame.minY), CGPoint(x: frame.maxX, y: frame.minY),
                       CGPoint(x: frame.minX, y: frame.maxY), CGPoint(x: frame.maxX, y: frame.maxY)] {
            context.stroke(ModuleDrawing.circle(corner, 2.5), with: .foreground, lineWidth: 1)
        }

        var cross = Path()
        cross.move(to: CGPoint(x: frame.midX - 6, y: frame.midY))
        cross.addLine(to: CGPoint(x: frame.midX + 6, y: frame.midY))
        cross.move(to: CGPoint(x: frame.midX, y: frame.midY - 6))
        cross.addLine(to: CGPoint(x: frame.midX, y: frame.midY + 6))
        faint.stroke(cross, with: .foreground, lineWidth: 1 / scale)

        // Width, under the box.
        let wy = frame.maxY + 14
        var width = Path()
        width.move(to: CGPoint(x: frame.minX, y: wy))
        width.addLine(to: CGPoint(x: frame.maxX, y: wy))
        for x in [frame.minX, frame.maxX] {
            width.move(to: CGPoint(x: x, y: wy - 4))
            width.addLine(to: CGPoint(x: x, y: wy + 4))
        }
        context.stroke(width, with: .foreground, lineWidth: 1 / scale)
        context.draw(Text("W \(Int(box.width))").font(.micro(7.5)).tracking(1.2),
                     at: CGPoint(x: frame.midX, y: wy + 11))

        // Height, left of the box.
        let hx = frame.minX - 14
        var height = Path()
        height.move(to: CGPoint(x: hx, y: frame.minY))
        height.addLine(to: CGPoint(x: hx, y: frame.maxY))
        for y in [frame.minY, frame.maxY] {
            height.move(to: CGPoint(x: hx - 4, y: y))
            height.addLine(to: CGPoint(x: hx + 4, y: y))
        }
        context.stroke(height, with: .foreground, lineWidth: 1 / scale)
        var turned = context
        turned.translateBy(x: hx - 10, y: frame.midY)
        turned.rotate(by: .degrees(-90))
        turned.draw(Text("H \(Int(box.height))").font(.micro(7.5)).tracking(1.2), at: .zero)
    }
}

/// Type has no fixed box, so its diagram shows the vertical metrics instead.
private struct TypeDiagram: View {
    let fontID: String
    @Environment(\.displayScale) private var scale

    var body: some View {
        GeometryReader { geo in
            let baseline = geo.size.height * 0.68
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    var faint = context
                    faint.opacity = 0.45
                    for (y, label) in [(size.height * 0.24, "Cap"), (size.height * 0.4, "x"), (baseline, "Base")] {
                        var line = Path()
                        line.move(to: CGPoint(x: 12, y: y))
                        line.addLine(to: CGPoint(x: size.width - 12, y: y))
                        faint.stroke(line, with: .foreground, style: StrokeStyle(lineWidth: 1 / scale, dash: [3, 2]))
                        context.draw(Text(label.uppercased()).font(.micro(6.5)).tracking(1.2),
                                     at: CGPoint(x: size.width - 14, y: y - 6), anchor: .trailing)
                    }
                }
                AssetArtView(art: .font(fontID), size: 64)
                    .frame(width: geo.size.width, height: geo.size.height * 0.8)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A four-by-four Home Screen grid with the asset's span doubled.
private struct SpanGrid: View {
    let span: (columns: Int, rows: Int)?

    var body: some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            ForEach(0..<4, id: \.self) { row in
                GridRow {
                    ForEach(0..<4, id: \.self) { column in
                        let inside = span.map { column < $0.columns && row < $0.rows } ?? false
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.primary.opacity(inside ? 1 : 0.3),
                                          style: StrokeStyle(lineWidth: inside ? 1.25 : 0.75, dash: inside ? [] : [2, 2]))
                            .overlay {
                                if inside {
                                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.4), lineWidth: 0.5)
                                        .padding(3)
                                }
                            }
                            .frame(width: 16, height: 16)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

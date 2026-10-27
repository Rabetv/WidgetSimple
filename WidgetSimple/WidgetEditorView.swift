import SwiftUI
import UIKit

/// The plain Apps widget's style: see it live in its real ink, then style it. Opened
/// full-screen from Home; designs are built in the sandbox (`DesignSandbox`) instead.
/// The see-through setup lives in Settings › Wallpaper.
///
/// The Apps widget's style is the shared look, written to the App Group exactly as the
/// widget reads it. Apps are never named here: they are picked in Edit Widget.
struct WidgetEditorScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var previewSize: FaceSize = .medium

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 12) {
                    ScreenHeader(title: "Style")
                    CloseKey { dismiss() }
                }
                LivePreview(design: nil, size: $previewSize)
                TuningPanel(look: $model.look, clock: $model.clock, scope: "Every Apps widget")
            }
            .padding(.horizontal, LineArt.margin)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppBackground())
    }
}

// MARK: - Preview

/// The widget as it lands on the Home Screen, in every size.
private struct LivePreview: View {
    let design: WidgetDesign?
    @Binding var size: FaceSize

    var body: some View {
        ModuleFrame("Live preview", stamp: design == nil ? "Apps widget" : "Design", foot: "Real ink · \(size.title)") {
            VStack(spacing: 14) {
                WidgetMockup(design: design, size: size)
                    .frame(maxWidth: size == .small ? 170 : .infinity)
                    .frame(maxWidth: .infinity)
                PillPicker(options: FaceSize.allCases.map { ($0, $0.title) }, selection: $size)
            }
        }
    }
}

// MARK: - Sandbox

/// The sandbox: the design on an iPhone-shaped canvas, drawn by the real `DesignFace`.
/// Tap a block to pick it and open its options; drag it to move it; drag a handle to
/// resize it. Add and Save sit under the phone, each one big key. Nothing is saved
/// until Save, so leaving keeps the saved design as it was.
struct DesignSandbox: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var board: BoardStore
    @Environment(\.dismiss) private var dismiss
    /// The saved design this copy came from; nil for a new one.
    let saved: UUID?
    let original: WidgetDesign
    @State private var draft: WidgetDesign
    @State private var selected: UUID?
    @State private var sheet: SandboxSheet?
    @State private var confirmingLeave = false
    @State private var deletions = 0

    enum SandboxSheet: String, Identifiable {
        case block, add, save
        var id: String { rawValue }
    }

    init(draft: SandboxDraft) {
        saved = draft.saved
        original = draft.design
        _draft = State(initialValue: draft.design)
    }

    var body: some View {
        VStack(spacing: 14) {
            topBar
            PhoneCanvas(design: $draft, selected: $selected,
                        tapBlock: { id in
                            selected = id
                            sheet = .block
                        },
                        tapEmpty: {
                            selected = nil
                            if sheet == .block { sheet = nil }
                        })
            bottomBar
        }
        .padding(.horizontal, LineArt.margin)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(AppBackground())
        .sheet(item: $sheet) { which in
            sheetView(which)
        }
        .confirmationDialog("Leave without saving?", isPresented: $confirmingLeave, titleVisibility: .visible) {
            Button("Leave without saving", role: .destructive) { dismiss() }
            Button("Keep building", role: .cancel) {}
        } message: {
            Text(saved == nil ? "This new widget is not saved yet." : "Your changes are not saved yet.")
        }
        .sensoryFeedback(.selection, trigger: selected)
        .sensoryFeedback(.impact(weight: .heavy), trigger: deletions)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            CloseKey {
                if draft == original { dismiss() } else { confirmingLeave = true }
            }
            VStack(alignment: .leading, spacing: 3) {
                Micro("Sandbox · \(draft.canvas.title) widget")
                Text(draft.displayName)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 8)
            Stamp(draft.blocks.count == 1 ? "1 block" : "\(draft.blocks.count) blocks")
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button { sheet = .add } label: {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(BigKeyStyle())
            Button { sheet = .save } label: {
                Label("Save", systemImage: "checkmark")
            }
            .buttonStyle(BigKeyStyle(prominent: true))
        }
    }

    @ViewBuilder
    private func sheetView(_ which: SandboxSheet) -> some View {
        switch which {
        case .block:
            if let id = selected, draft.blocks.contains(where: { $0.id == id }) {
                BlockSheet(block: blockBinding(id), look: $draft.look) { delete(id) }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationContentInteraction(.scrolls)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
        case .add:
            BlockPickerSheet { kind in add(kind) }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        case .save:
            NameSheet(title: "Name your widget", detail: saveNote, name: draft.name, action: "Save") { name in
                save(named: name)
            }
            .wallpaperGated()
            .presentationDetents(model.isWallpaperReady ? [.medium] : [.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var saveNote: String {
        "Then on the Home Screen: hold a \(draft.canvas.title) Apps widget › Edit Widget › Design › this name."
    }

    /// The picked block, read and written by its id, so a block deleted meanwhile never
    /// leaves the sheet holding a stale index.
    private func blockBinding(_ id: UUID) -> Binding<DesignBlock> {
        let fallback = draft.blocks.first { $0.id == id } ?? DesignBlock(.spacer)
        return Binding(
            get: { draft.blocks.first { $0.id == id } ?? fallback },
            set: { next in
                if let index = draft.blocks.firstIndex(where: { $0.id == id }) { draft.blocks[index] = next }
            }
        )
    }

    /// A new block lands in the middle, already picked.
    private func add(_ kind: BlockKind) {
        let block = DesignBlock.dropped(kind, on: draft.canvas)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            draft.blocks.append(block)
        }
        selected = block.id
    }

    private func delete(_ id: UUID) {
        sheet = nil
        withAnimation(.snappy) {
            draft.blocks.removeAll { $0.id == id }
        }
        selected = nil
        deletions += 1
    }

    /// Writes the design through `AppModel` (a new one with `addDesign`), so Edit Widget
    /// lists it by this name, and goes Home. The Save sheet sits behind `WallpaperGate`.
    private func save(named name: String) {
        var final = draft
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        final.name = trimmed.isEmpty ? model.nextDesignName : String(trimmed.prefix(32))
        if let saved, model.designs.contains(where: { $0.id == saved }) {
            model.update(saved) { design in
                design.name = final.name
                design.look = final.look
                design.blocks = final.blocks
                design.canvas = final.canvas
            }
        } else {
            let added = model.addDesign(blocks: final.blocks)
            model.update(added.id) { design in
                design.name = final.name
                design.look = final.look
                design.canvas = final.canvas
            }
        }
        sheet = nil
        board.tab = .home
        board.sandbox = nil
    }
}

/// The phone: an iPhone drawn in lines on the brown background, the widget at its real
/// aspect near the top, and the design in it drawn by `DesignFace` with App 1, App 2…
/// Over the drawing sits one touch area per block, placed from the same frames.
private struct PhoneCanvas: View {
    @Binding var design: WidgetDesign
    @Binding var selected: UUID?
    let tapBlock: (UUID) -> Void
    let tapEmpty: () -> Void
    /// The block and frame a drag started from, and where the finger went down.
    @State private var gesture: (id: UUID, start: CGPoint, frame: BlockFrame)?
    @State private var dragging = false
    @State private var snaps = 0

    /// An iPhone in points; the widget sits this far below its top edge.
    private static let phone = CGSize(width: 402, height: 874)
    private static let widgetTop: CGFloat = 72

    var body: some View {
        GeometryReader { geo in
            let real = design.canvas.pointSize
            let scale = max(min(geo.size.width / Self.phone.width,
                                (geo.size.height - 12) / (Self.widgetTop + real.height + 28)), 0.1)
            let phone = CGRect(x: (geo.size.width - Self.phone.width * scale) / 2, y: 0,
                               width: Self.phone.width * scale, height: Self.phone.height * scale)
            let shown = CGSize(width: real.width * scale, height: real.height * scale)
            let widget = CGRect(x: phone.midX - shown.width / 2, y: phone.minY + Self.widgetTop * scale,
                                width: shown.width, height: shown.height)
            ZStack(alignment: .topLeading) {
                PhoneOutline(scale: scale, widget: widget.offsetBy(dx: -phone.minX, dy: -phone.minY))
                    .frame(width: phone.width, height: phone.height)
                    .position(x: phone.midX, y: phone.midY)
                    .allowsHitTesting(false)
                face(real: real, scale: scale)
                    .position(x: widget.midX, y: widget.midY)
                touchLayer(shown: shown)
                    .frame(width: shown.width, height: shown.height)
                    .position(x: widget.midX, y: widget.midY)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .mask {
                // The phone runs off the bottom of the space; fade it out there.
                LinearGradient(stops: [.init(color: .black, location: 0.86), .init(color: .clear, location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .padding(.horizontal, -60)
                    .padding(.top, -60)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: snaps)
    }

    /// The design in its real ink at its real point size, scaled to the phone.
    private func face(real: CGSize, scale: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22 * scale, style: .continuous)
        return TimelineView(.everyMinute) { context in
            DesignFace(design: design, date: context.date, size: design.canvas, placeholders: true,
                       color: design.look.color, battery: AppModel.batteryLevel)
                .frame(width: real.width, height: real.height)
                .scaleEffect(scale, anchor: .topLeading)
        }
        .frame(width: real.width * scale, height: real.height * scale, alignment: .topLeading)
        .background { shape.fill(Color.white.opacity(0.05)) }
        .overlay {
            shape.strokeBorder(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Touch

    private func touchLayer(shown: CGSize) -> some View {
        let grid = design.canvas.grid
        let ordered = design.blocks.filter { $0.id != selected } + design.blocks.filter { $0.id == selected }
        return ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { tapEmpty() }
                .accessibilityHidden(true)
            if dragging {
                GridDots(columns: grid.columns, rows: grid.rows)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            ForEach(ordered) { block in
                let rect = frame(of: block).rect(in: shown)
                let picked = block.id == selected
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(picked ? 0.08 : 0.001))
                    .overlay {
                        if picked {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.accentColor, lineWidth: 4)
                        } else {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        }
                    }
                    .frame(width: max(rect.width, 1), height: max(rect.height, 1))
                    .contentShape(Rectangle())
                    .onTapGesture { tapBlock(block.id) }
                    .gesture(move(block.id, shown: shown))
                    .position(x: rect.midX, y: rect.midY)
                    .accessibilityElement()
                    .accessibilityLabel(block.kind.title)
                    .accessibilityAddTraits(picked ? [.isButton, .isSelected] : .isButton)
                if picked {
                    handles(block.id, rect: rect, shown: shown)
                }
            }
        }
        .coordinateSpace(.named(Self.space))
        .animation(.easeInOut(duration: 0.15), value: dragging)
    }

    private static let space = "widget"

    /// Corner handles always; edge handles where the block is long enough to keep
    /// them apart from the corners. Each is drawn small but takes a 48-point touch.
    @ViewBuilder
    private func handles(_ id: UUID, rect: CGRect, shown: CGSize) -> some View {
        let wide = rect.width >= 96, tall = rect.height >= 96
        ForEach(ResizeHandle.allCases.filter { ($0.dx == 0 ? wide : true) && ($0.dy == 0 ? tall : true) }) { handle in
            Circle()
                .fill(Color.accentColor)
                .overlay { Circle().strokeBorder(Color.white, lineWidth: 2) }
                .frame(width: 18, height: 18)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
                .gesture(resize(id, handle: handle, shown: shown))
                .position(x: rect.minX + rect.width * CGFloat(handle.dx + 1) / 2,
                          y: rect.minY + rect.height * CGFloat(handle.dy + 1) / 2)
                .accessibilityHidden(true)
        }
    }

    private func move(_ id: UUID, shown: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.space))
            .onChanged { value in
                let start = begin(id, at: value.startLocation)
                var next = start
                next.x += Double(value.translation.width / max(shown.width, 1))
                next.y += Double(value.translation.height / max(shown.height, 1))
                setFrame(id, next.inside)
            }
            .onEnded { _ in
                finish(id) { $0.snappedMove(to: design.canvas.grid) }
            }
    }

    private func resize(_ id: UUID, handle: ResizeHandle, shown: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
            .onChanged { value in
                let start = begin(id, at: value.startLocation)
                let dx = Double(value.translation.width / max(shown.width, 1))
                let dy = Double(value.translation.height / max(shown.height, 1))
                setFrame(id, start.resized(handle, by: dx, dy, grid: design.canvas.grid))
            }
            .onEnded { _ in
                finish(id) { $0.snappedEdges(handle, to: design.canvas.grid) }
            }
    }

    /// The frame this drag started from; a new finger-down starts a new drag.
    private func begin(_ id: UUID, at point: CGPoint) -> BlockFrame {
        if let gesture, gesture.id == id, gesture.start == point { return gesture.frame }
        let frame = frame(of: design.blocks.first { $0.id == id })
        gesture = (id, point, frame)
        if selected != id { selected = id }
        dragging = true
        return frame
    }

    /// Lets go: the block springs onto the grid, inside the widget.
    private func finish(_ id: UUID, snap: (BlockFrame) -> BlockFrame) {
        gesture = nil
        dragging = false
        guard let current = design.blocks.first(where: { $0.id == id })?.frame else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.66)) {
            setFrame(id, snap(current).inside)
        }
        snaps += 1
    }

    private func setFrame(_ id: UUID, _ frame: BlockFrame) {
        guard let index = design.blocks.firstIndex(where: { $0.id == id }) else { return }
        design.blocks[index].frame = frame
    }

    private func frame(of block: DesignBlock?) -> BlockFrame {
        block?.frame ?? BlockFrame(x: 0, y: 0, width: 1, height: 1)
    }
}

/// Where a resize handle sits: -1, 0 or 1 across and down.
enum ResizeHandle: Int, CaseIterable, Identifiable {
    case topLeading, top, topTrailing, leading, trailing, bottomLeading, bottom, bottomTrailing

    var id: Int { rawValue }

    var dx: Int {
        switch self {
        case .topLeading, .leading, .bottomLeading: return -1
        case .top, .bottom: return 0
        case .topTrailing, .trailing, .bottomTrailing: return 1
        }
    }

    var dy: Int {
        switch self {
        case .topLeading, .top, .topTrailing: return -1
        case .leading, .trailing: return 0
        case .bottomLeading, .bottom, .bottomTrailing: return 1
        }
    }
}

/// The sandbox grid: about 14 points a cell on the real widget.
struct SnapGrid {
    let columns: Int
    let rows: Int
    /// The smallest block: three cells across, two down.
    var minWidth: Double { 3 / Double(columns) }
    var minHeight: Double { 2 / Double(rows) }

    func x(_ value: Double) -> Double { (value * Double(columns)).rounded() / Double(columns) }
    func y(_ value: Double) -> Double { (value * Double(rows)).rounded() / Double(rows) }
}

extension FaceSize {
    var grid: SnapGrid {
        let points = pointSize
        return SnapGrid(columns: max(Int((points.width / 14).rounded()), 6),
                        rows: max(Int((points.height / 14).rounded()), 6))
    }
}

extension BlockFrame {
    /// Moved onto the nearest grid point, its size kept.
    func snappedMove(to grid: SnapGrid) -> BlockFrame {
        BlockFrame(x: grid.x(x), y: grid.y(y), width: width, height: height)
    }

    /// Dragged by one handle: the opposite edges stay put, never smaller than the grid's
    /// smallest block, never past the widget's edge.
    func resized(_ handle: ResizeHandle, by dx: Double, _ dy: Double, grid: SnapGrid) -> BlockFrame {
        var left = x, top = y, right = x + width, bottom = y + height
        if handle.dx < 0 { left = min(max(left + dx, 0), right - grid.minWidth) }
        if handle.dx > 0 { right = max(min(right + dx, 1), left + grid.minWidth) }
        if handle.dy < 0 { top = min(max(top + dy, 0), bottom - grid.minHeight) }
        if handle.dy > 0 { bottom = max(min(bottom + dy, 1), top + grid.minHeight) }
        return BlockFrame(x: left, y: top, width: right - left, height: bottom - top)
    }

    /// The edges a handle moved, onto the grid.
    func snappedEdges(_ handle: ResizeHandle, to grid: SnapGrid) -> BlockFrame {
        var left = x, top = y, right = x + width, bottom = y + height
        if handle.dx < 0 { left = min(grid.x(left), right - grid.minWidth) }
        if handle.dx > 0 { right = max(grid.x(right), left + grid.minWidth) }
        if handle.dy < 0 { top = min(grid.y(top), bottom - grid.minHeight) }
        if handle.dy > 0 { bottom = max(grid.y(bottom), top + grid.minHeight) }
        return BlockFrame(x: left, y: top, width: right - left, height: bottom - top)
    }
}

extension DesignBlock {
    /// A new block of `kind` in the middle of a widget of `canvas` size, at a size that
    /// suits it, on the grid.
    static func dropped(_ kind: BlockKind, on canvas: FaceSize) -> DesignBlock {
        var block = DesignBlock(kind)
        if kind == .daysUntil {
            block.date = Calendar.current.date(byAdding: .day, value: 30, to: .now)
        }
        let points = canvas.pointSize
        let size = kind.droppedSize
        let width = min(Double(size.width / points.width), 0.9)
        let height = min(Double(size.height / points.height), 0.9)
        let grid = canvas.grid
        let snapped = BlockFrame(x: grid.x(0.5 - width / 2), y: grid.y(0.5 - height / 2),
                                 width: max(grid.x(width), grid.minWidth), height: max(grid.y(height), grid.minHeight))
        block.frame = snapped.inside
        return block
    }
}

extension BlockKind {
    /// The size, in points, a new block of this kind starts at.
    var droppedSize: CGSize {
        switch self {
        case .apps: return CGSize(width: 150, height: 90)
        case .digitalClock: return CGSize(width: 150, height: 60)
        case .analogClock, .countdownRing, .battery, .vinyl, .calendarIcon, .moon: return CGSize(width: 84, height: 84)
        case .health: return CGSize(width: 150, height: 80)
        case .wordClock: return CGSize(width: 170, height: 70)
        case .worldClock: return CGSize(width: 170, height: 84)
        case .bigDate: return CGSize(width: 90, height: 100)
        case .weekStrip: return CGSize(width: 220, height: 50)
        case .monthGrid: return CGSize(width: 150, height: 130)
        case .progress: return CGSize(width: 120, height: 70)
        case .daysUntil: return CGSize(width: 110, height: 70)
        case .text, .quote, .greeting: return CGSize(width: 180, height: 44)
        case .spacer: return CGSize(width: 80, height: 40)
        }
    }

    /// Whether `BlockOptions` has anything to show for this kind.
    var hasOptions: Bool {
        switch self {
        case .apps, .text, .greeting, .quote, .digitalClock, .worldClock, .bigDate, .progress, .daysUntil,
             .battery, .health:
            return true
        default:
            return false
        }
    }
}

/// The phone in lines: its outline, the island, the time, and faint app spots under
/// the widget, so the widget is seen where it will sit.
private struct PhoneOutline: View {
    let scale: CGFloat
    /// The widget's rectangle, in the phone's own coordinates.
    let widget: CGRect
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Canvas { context, size in
            let body = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
            context.stroke(Path(roundedRect: body, cornerRadius: 58 * scale, style: .continuous),
                           with: .foreground, lineWidth: 1.5)
            var faint = context
            faint.opacity = 0.35
            faint.stroke(Path(roundedRect: body.insetBy(dx: 6 * scale, dy: 6 * scale), cornerRadius: 52 * scale,
                              style: .continuous),
                         with: .foreground, lineWidth: 1 / displayScale)
            let island = CGRect(x: size.width / 2 - 62 * scale, y: 12 * scale, width: 124 * scale, height: 36 * scale)
            context.stroke(Path(roundedRect: island, cornerRadius: island.height / 2), with: .foreground, lineWidth: 1)
            context.draw(Text("9:41").font(.system(size: max(15 * scale, 9), weight: .semibold)),
                         at: CGPoint(x: 64 * scale, y: 30 * scale))

            // App spots: four across, below the widget.
            let side = 64 * scale, gap = (size.width - 4 * side) / 5
            var y = widget.maxY + 26 * scale
            while y + side < size.height - 40 * scale {
                for column in 0..<4 {
                    let spot = CGRect(x: gap + CGFloat(column) * (side + gap), y: y, width: side, height: side)
                    faint.stroke(Path(roundedRect: spot, cornerRadius: side * 0.24, style: .continuous),
                                 with: .foreground, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
                y += side + 30 * scale
            }
        }
        .accessibilityHidden(true)
    }
}

/// The grid's points, shown while a block is moved or resized.
private struct GridDots: View {
    let columns: Int
    let rows: Int

    var body: some View {
        Canvas { context, size in
            var dots = Path()
            for column in 0...columns {
                for row in 0...rows {
                    let center = CGPoint(x: size.width * CGFloat(column) / CGFloat(columns),
                                         y: size.height * CGFloat(row) / CGFloat(rows))
                    dots.addPath(ModuleDrawing.circle(center, 1))
                }
            }
            var faint = context
            faint.opacity = 0.45
            faint.fill(dots, with: .foreground)
        }
        .accessibilityHidden(true)
    }
}

/// One block's options: its own settings, the design's style, and Delete at the foot.
private struct BlockSheet: View {
    @Binding var block: DesignBlock
    /// The design's style, which every block without its own follows.
    @Binding var look: Look
    let delete: () -> Void
    @Environment(\.dismiss) private var dismiss
    /// What the style controls change: this block (the default) or the whole design.
    @State private var styleScope: StyleScope = .block

    private enum StyleScope: CaseIterable {
        case block, design

        var title: String {
            switch self {
            case .block: return String(localized: "This block")
            case .design: return String(localized: "Whole design")
            }
        }
    }

    /// This block's own style; the first change copies the design's style into it.
    private var blockLook: Binding<Look> {
        Binding(get: { block.look ?? look }, set: { block.look = $0 })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    BlockIcon(kind: block.kind, symbolSize: 20)
                        .frame(width: 52, height: 52)
                        .lineBorder(radius: LineArt.innerRadius, weight: .pixel)
                    VStack(alignment: .leading, spacing: 3) {
                        Micro("Block")
                        Text(block.kind.title)
                            .font(.metric(26))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer(minLength: 8)
                    CloseKey { dismiss() }
                }
                if block.kind.hasOptions {
                    ModuleFrame("Options", stamp: block.kind.title) {
                        VStack(alignment: .leading, spacing: 14) {
                            BlockOptions(block: $block)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    PillPicker(options: StyleScope.allCases.map { ($0, $0.title) }, selection: $styleScope)
                    if styleScope == .block && block.look != nil {
                        Button("Use the design's style again") { block.look = nil }
                            .buttonStyle(PillStyle())
                    }
                }
                switch styleScope {
                case .block:
                    TuningPanel(look: blockLook, clock: .constant(.off), showsClock: false, scope: "This block only")
                case .design:
                    TuningPanel(look: $look, clock: .constant(.off), showsClock: false,
                                scope: "Every block without its own style")
                }
                Button(role: .destructive, action: delete) {
                    Label("Delete \(block.kind.title)", systemImage: "trash")
                }
                .buttonStyle(BigKeyStyle(destructive: true))
                .padding(.top, 6)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .environment(\.largeTargets, true)
    }
}

/// One big name field, already filled in, and one big key: saving a design or renaming it.
struct NameSheet: View {
    let title: String
    let detail: String
    @State var name: String
    let action: String
    let done: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Micro("Name")
            Text(title).font(.metric(28))
            NameField(text: $name, big: true)
            Button { done(name) } label: {
                Label(action, systemImage: "checkmark")
            }
            .buttonStyle(BigKeyStyle(prominent: true))
            Note(detail)
            Spacer(minLength: 0)
        }
        .padding(24)
    }
}

/// The design's name, in a capsule like the word fields elsewhere.
private struct NameField: View {
    @Binding var text: String
    var big = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "character.cursor.ibeam")
                .font(.system(size: big ? 20 : 13, weight: .light))
                .foregroundStyle(.secondary)
            TextField("Design name", text: $text)
                .font(.system(size: big ? 26 : 16, weight: .semibold, design: .rounded))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focused)
                .onChange(of: text) { _, new in
                    if new.count > 32 { text = String(new.prefix(32)) }
                }
        }
        .padding(.horizontal, big ? 20 : 14)
        .frame(height: big ? 64 : 42)
        .lineBorder(radius: big ? 32 : 21, opacity: focused ? 1 : 0.5)
    }
}

/// A square close key, 48 points.
struct CloseKey: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) { Image(systemName: "xmark") }
            .buttonStyle(BevelKeyStyle(size: 48))
            .accessibilityLabel("Close")
    }
}

// MARK: - Blocks

/// The settings a block's kind has, if any.
private struct BlockOptions: View {
    @Binding var block: DesignBlock

    var body: some View {
        switch block.kind {
        case .apps:
            TuneRow("Open App slots") {
                MetricStepper(value: slots, range: 1...Double(DesignBlock.maxSlots), step: 1) { "\(Int($0))" }
            }
            Note("App 1, App 2… in this order; the apps themselves are picked in Edit Widget.")
        case .text:
            TuneRow("Words") { WordsField(placeholder: "Your words", text: $block.text) }
        case .greeting:
            TuneRow("Name (optional)") { WordsField(placeholder: "Your name", text: $block.text) }
        case .quote:
            TuneRow("Lines · one a day") {
                TextEditor(text: quoteLines)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 90)
                    .padding(8)
                    .lineBorder(radius: LineArt.innerRadius, opacity: 0.5)
            }
            Note("One line per row. Each day shows the next one.")
        case .digitalClock:
            TuneRow("Shows") {
                PillPicker(options: [ClockOption.time, .timeAndDate, .date].map { ($0, $0.title) },
                           selection: $block.clock, compact: true)
            }
        case .worldClock:
            TuneRow("Cities · up to 4") { CityList(zones: $block.zones) }
        case .bigDate:
            TuneRow("Style") {
                PillPicker(options: DateStyle.allCases.map { ($0, $0.title) }, selection: $block.dateStyle, compact: true)
            }
        case .progress:
            TuneRow("Of the") {
                PillPicker(options: ProgressScope.allCases.map { ($0, $0.title) }, selection: $block.scope, compact: true)
            }
            TuneRow("As") {
                PillPicker(options: ProgressStyle.allCases.map { ($0, $0.title) }, selection: $block.progressStyle, compact: true)
            }
        case .daysUntil:
            TuneRow("Date") {
                DatePicker("Date", selection: date, displayedComponents: .date)
                    .labelsHidden()
            }
            TuneRow("Title (optional)") { WordsField(placeholder: "days to go", text: $block.text) }
            Note("Before the date it counts down; after it, the days since.")
        case .battery:
            Note("The charge updates when the widget redraws, about every half hour.")
        case .health:
            Note("A sample line. WidgetSimple never reads Health data.")
        default:
            EmptyView()
        }
    }

    private var slots: Binding<Double> {
        Binding(get: { Double(block.slots) }, set: { block.slots = Int($0) })
    }

    private var quoteLines: Binding<String> {
        Binding(get: { block.lines.joined(separator: "\n") },
                set: { block.lines = $0.components(separatedBy: "\n") })
    }

    private var date: Binding<Date> {
        Binding(get: { block.date ?? .now }, set: { block.date = $0 })
    }
}

/// A short line of words in a capsule.
private struct WordsField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .autocorrectionDisabled()
            .submitLabel(.done)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .lineBorder(radius: 19, opacity: 0.5)
    }
}

/// The world clock's cities: change or remove one, add up to four.
private struct CityList: View {
    @Binding var zones: [String]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(zones.indices, id: \.self) { index in
                Menu {
                    ForEach(WorldTime.choices, id: \.self) { zone in
                        Button(WorldTime.city(zone)) { zones[index] = zone }
                    }
                    Divider()
                    Button("Remove", role: .destructive) { zones.remove(at: index) }
                } label: {
                    Text(WorldTime.city(zones[index])).pillLook(selected: true, compact: true)
                }
            }
            if zones.count < 4 {
                Menu {
                    ForEach(WorldTime.choices.filter { !zones.contains($0) }, id: \.self) { zone in
                        Button(WorldTime.city(zone)) { zones.append(zone) }
                    }
                } label: {
                    Label("City", systemImage: "plus").pillLook(compact: true)
                }
            }
        }
    }
}

/// Every block kind, grouped. A tap adds it at the bottom of the design.
private struct BlockPickerSheet: View {
    let add: (BlockKind) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Micro("Design · blocks")
                        Text("Add a block").font(.metric(26))
                    }
                    Spacer()
                    CloseKey { dismiss() }
                }
                ForEach(BlockKind.groups, id: \.title) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Micro(group.title, tone: .primary)
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(group.kinds) { kind in
                                Button {
                                    add(kind)
                                    dismiss()
                                } label: {
                                    VStack(spacing: 6) {
                                        BlockIcon(kind: kind).frame(width: 30, height: 30)
                                        Text(kind.title)
                                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 6)
                                    .frame(maxWidth: .infinity)
                                    .lineBorder(radius: 14, opacity: 0.4)
                                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(PressScale())
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

/// A block's sign: the module's own drawing, or a symbol.
struct BlockIcon: View {
    let kind: BlockKind
    var symbolSize: CGFloat = 15

    var body: some View {
        if let module = kind.module {
            ModuleGlyph(kind: module).padding(symbolSize * 0.4)
        } else {
            Image(systemName: symbol)
                .font(.system(size: symbolSize, weight: .light))
        }
    }

    private var symbol: String {
        switch kind {
        case .apps: return "square.grid.2x2"
        case .text: return "textformat"
        case .quote: return "quote.opening"
        case .greeting: return "hand.wave"
        case .digitalClock: return "clock"
        case .wordClock: return "textformat.abc"
        case .worldClock: return "globe"
        case .bigDate: return "number"
        case .weekStrip: return "rectangle.split.3x1"
        case .monthGrid: return "calendar"
        case .progress: return "circle.grid.3x3"
        case .daysUntil: return "hourglass"
        case .moon: return "moon"
        default: return "rectangle.dashed"
        }
    }
}

// MARK: - Fine-tuning

private enum TuneTab: String, CaseIterable, Identifiable {
    case position, padding, scale, type, clock

    var id: String { rawValue }

    var title: String {
        switch self {
        case .position: return "Pos"
        case .padding: return "Pad"
        case .scale: return "Scale"
        case .type: return "Type"
        case .clock: return "Clock"
        }
    }
}

private enum NudgeTarget: Hashable { case apps, clock }

/// Precision controls for a look: capsule pills to pick the group, square bevelled keys
/// for anchors and point nudges, rulers for spacing and size. Bound to the Apps widget's
/// shared look or to one design's own.
private struct TuningPanel: View {
    @Binding var look: Look
    @Binding var clock: ClockOption
    /// The Apps widget's own clock; a design has clock blocks instead.
    var showsClock = true
    /// What the controls change, for the panel's foot.
    let scope: String
    @State private var tab: TuneTab = .position
    @State private var target: NudgeTarget = .apps
    @State private var choosingFont = false
    @State private var placingWords = false

    private var free: Bool { look.arrangement == .free }
    private var hasClock: Bool { showsClock && clock != .off }
    private var movesClock: Bool { free && target == .clock && hasClock }
    private var tabs: [TuneTab] { showsClock ? TuneTab.allCases : TuneTab.allCases.filter { $0 != .clock } }

    var body: some View {
        ModuleFrame("Style", stamp: "FT · \(tab.title)", foot: scope, marks: [.topTrailing]) {
            VStack(alignment: .leading, spacing: 18) {
                PillPicker(options: tabs.map { ($0, $0.title) }, selection: $tab)
                Hairline()
                switch tab {
                case .position: positionControls
                case .padding: paddingControls
                case .scale: scaleControls
                case .type: typeControls
                case .clock: clockControls
                }
            }
        }
        .sheet(isPresented: $choosingFont) {
            NavigationStack { FontPickerView(selection: $look.fontID) }
        }
        .sheet(isPresented: $placingWords) {
            WordAnchorsSheet(look: $look)
        }
        .onChange(of: showsClock) { _, shows in
            if !shows && tab == .clock { tab = .position }
        }
    }

    // MARK: Groups

    @ViewBuilder
    private var positionControls: some View {
        TuneRow("Arrangement") {
            PillPicker(options: Arrangement.allCases.map { ($0, $0.title) }, selection: $look.arrangement)
        }
        if free && hasClock {
            TuneRow("Block") {
                PillPicker(options: [(NudgeTarget.apps, "Apps"), (NudgeTarget.clock, "Clock")], selection: $target)
            }
        }
        HStack(alignment: .top, spacing: 22) {
            TuneRow(free ? "Anchor" : "Alignment") { AnchorPad(selection: anchorBinding) }
            TuneRow("Nudge") {
                NudgePad(x: movesClock ? $look.clockDX : $look.appsDX,
                         y: movesClock ? $look.clockDY : $look.appsDY)
                    .disabled(!free)
            }
        }
        if free {
            Toggle(isOn: $look.perWordPlacement) { TuneLabel("Place every word separately") }
                .toggleStyle(LineToggleStyle())
            if look.perWordPlacement {
                Button("Word anchors") { placingWords = true }
                    .buttonStyle(PillStyle(selected: true))
            }
        } else {
            Note("Stacked keeps the clock above the words. Choose Free to anchor and nudge each block by points.")
        }
    }

    @ViewBuilder
    private var paddingControls: some View {
        TuneRow("Line spacing") {
            MetricStepper(value: $look.spacing, range: 0.6...2.0, step: 0.1) { String(format: "%.1f×", $0) }
        }
        LineRuler(value: $look.spacing, range: 0.6...2.0, step: 0.1, major: 2, label: "Line spacing")
        Note("The space between words, as a multiple of the font's own line height.")
    }

    @ViewBuilder
    private var scaleControls: some View {
        TuneRow("Text size") {
            MetricStepper(value: $look.size, range: 12...34, step: 1) { "\(Int($0)) pt" }
        }
        LineRuler(value: $look.size, range: 12...34, step: 1, major: 2, label: "Text size")
    }

    @ViewBuilder
    private var typeControls: some View {
        TuneRow("Font") {
            HStack(spacing: 12) {
                Text(FontCatalog.displayName(for: look.fontID))
                    .font(FontCatalog.font(id: look.fontID, size: 20))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                Button { choosingFont = true } label: {
                    Text("Aa").font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .buttonStyle(BevelKeyStyle(size: 38))
                .accessibilityLabel("Choose a font")
            }
        }
        TuneRow("Letter case") {
            PillPicker(options: [(LetterCase.normal, "As typed"), (LetterCase.upper, "Capitals")],
                       selection: $look.letterCase)
        }
        TuneRow("Text align") {
            PillPicker(options: TextAlign.allCases.map { ($0, $0.title) }, selection: $look.align)
        }
        TuneRow("Ink") {
            PillPicker(options: TextTone.allCases.map { ($0, $0.title) }, selection: $look.tone)
        }
        if look.tone == .custom {
            ColorPicker(selection: customInk, supportsOpacity: false) { TuneLabel("Custom ink") }
        }
        if darkInk {
            Warning("Dark ink disappears on a dark wallpaper. If your widgets show no words, pick White here or turn on Soft shadow.")
        }
        Toggle(isOn: $look.shadow) { TuneLabel("Soft shadow") }
            .toggleStyle(LineToggleStyle())
        Note("The live preview draws the words in the ink the widget uses.")
    }

    @ViewBuilder
    private var clockControls: some View {
        TuneRow("Clock") {
            PillPicker(options: ClockOption.allCases.map { ($0, $0.title) }, selection: $clock)
        }
        Note(free && clock != .off
             ? "Place the clock under Pos › Block › Clock."
             : "The clock uses the launcher font; 12 or 24 hours follows the iPhone setting.")
    }

    // MARK: Bindings

    /// Stacked mode positions the words with align + vertical align; Free mode gives the
    /// apps and the clock their own anchor.
    private var anchorBinding: Binding<WidgetPosition> {
        if !free {
            return Binding(
                get: { WidgetPosition(align: look.align, vAlign: look.vAlign) },
                set: { position in
                    var next = look
                    next.align = position.textAlign
                    next.vAlign = position.textVAlign
                    look = next
                }
            )
        }
        return movesClock ? $look.clockPosition : $look.appsPosition
    }

    private var customInk: Binding<Color> {
        Binding(
            get: { Color(hex: look.customHex) },
            set: { look.customHex = $0.hexValue }
        )
    }

    /// Black, or a custom ink close to it: the words vanish on a dark wallpaper.
    private var darkInk: Bool {
        switch look.tone {
        case .white: return false
        case .black: return true
        case .custom: return Color(hex: look.customHex).luminance < 0.25
        }
    }
}

private struct TuneRow<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Micro(title)
            content
        }
    }
}

private struct TuneLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.system(size: 15, weight: .semibold, design: .rounded))
    }
}

private struct Note: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A note that needs attention, in the accent with a warning mark.
private struct Warning: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.accentColor)
    }
}

/// A big readout with two bevelled keys that repeat while held.
private struct MetricStepper: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        HStack(spacing: 8) {
            Text(format(value))
                .font(.metric(30))
                .monospacedDigit()
                .contentTransition(.numericText(value: value))
                .animation(.snappy, value: value)
            Spacer(minLength: 8)
            Button { set(value - step) } label: { Image(systemName: "minus") }
                .buttonStyle(BevelKeyStyle(size: 36))
                .buttonRepeatBehavior(.enabled)
                .disabled(value - step < range.lowerBound - step / 100)
                .accessibilityLabel("Less")
            Button { set(value + step) } label: { Image(systemName: "plus") }
                .buttonStyle(BevelKeyStyle(size: 36))
                .buttonRepeatBehavior(.enabled)
                .disabled(value + step > range.upperBound + step / 100)
                .accessibilityLabel("More")
        }
    }

    private func set(_ raw: Double) {
        let snapped = ((raw - range.lowerBound) / step).rounded() * step + range.lowerBound
        value = min(max(snapped, range.lowerBound), range.upperBound)
    }
}

/// Nine square keys, one per anchor. The chosen key is doubled and ringed.
private struct AnchorPad: View {
    @Binding var selection: WidgetPosition

    var body: some View {
        Grid(horizontalSpacing: 5, verticalSpacing: 5) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { column in
                        let position = WidgetPosition.allCases[row * 3 + column]
                        let chosen = selection == position
                        Button {
                            withAnimation(.snappy) { selection = position }
                        } label: {
                            ZStack {
                                if chosen {
                                    Circle().strokeBorder(Color.primary, lineWidth: 1).frame(width: 11, height: 11)
                                    Circle().strokeBorder(Color.primary, lineWidth: 1).frame(width: 4, height: 4)
                                } else {
                                    Image(systemName: "plus").font(.system(size: 8, weight: .light)).foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .buttonStyle(BevelKeyStyle(size: 32, selected: chosen))
                        .accessibilityLabel(position.title)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Arrow keys that move a block 2 pt at a time (held, they repeat), and a key to zero.
private struct NudgePad: View {
    @Binding var x: Double
    @Binding var y: Double
    private let step = 2.0
    private let limit = 80.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Grid(horizontalSpacing: 5, verticalSpacing: 5) {
                GridRow {
                    blank
                    key("arrow.up", "Up") { y = clamp(y - step) }
                    blank
                }
                GridRow {
                    key("arrow.left", "Left") { x = clamp(x - step) }
                    Button { x = 0; y = 0 } label: { Text("0").font(.metric(11)) }
                        .buttonStyle(BevelKeyStyle(size: 32))
                        .accessibilityLabel("Reset nudge")
                    key("arrow.right", "Right") { x = clamp(x + step) }
                }
                GridRow {
                    blank
                    key("arrow.down", "Down") { y = clamp(y + step) }
                    blank
                }
            }
            Text("X \(Int(x))  Y \(Int(y))")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var blank: some View { Color.clear.frame(width: 32, height: 32) }

    private func key(_ symbol: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol) }
            .buttonStyle(BevelKeyStyle(size: 32))
            .buttonRepeatBehavior(.enabled)
            .accessibilityLabel(label)
    }

    private func clamp(_ value: Double) -> Double { min(max(value, -limit), limit) }
}

/// Per-word anchors. The app can't see the app names (iOS resolves them in Edit
/// Widget), so the rows are word slots: word 1 is the first app picked.
private struct WordAnchorsSheet: View {
    @Binding var look: Look
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Hairline(opacity: 0.6)
                    ForEach(0..<12, id: \.self) { slot in
                        HStack(spacing: 12) {
                            Stamp(String(format: "A-%02d", slot + 1))
                            Text("App \(slot + 1)")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                            Spacer()
                            Menu {
                                Picker("Anchor", selection: anchor(slot)) {
                                    ForEach(WidgetPosition.allCases) { Text($0.title).tag($0) }
                                }
                            } label: {
                                Text(anchor(slot).wrappedValue.title)
                                    .pillLook(selected: look.wordAnchors["\(slot)"] != nil)
                            }
                        }
                        .padding(.vertical, 12)
                        Hairline()
                    }
                    Note("Slots with no app picked in Edit Widget are ignored.")
                        .padding(.top, 14)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Word anchors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func anchor(_ slot: Int) -> Binding<WidgetPosition> {
        Binding(
            get: { look.wordAnchors["\(slot)"] ?? look.appsPosition },
            set: { look.wordAnchors["\(slot)"] = $0 }
        )
    }
}

// MARK: - Helpers

private extension WidgetPosition {
    init(align: TextAlign, vAlign: TextVAlign) {
        switch (vAlign, align) {
        case (.top, .left): self = .topLeading
        case (.top, .center): self = .top
        case (.top, .right): self = .topTrailing
        case (.middle, .left): self = .leading
        case (.middle, .center): self = .center
        case (.middle, .right): self = .trailing
        case (.bottom, .left): self = .bottomLeading
        case (.bottom, .center): self = .bottom
        case (.bottom, .right): self = .bottomTrailing
        }
    }

    var textAlign: TextAlign {
        switch self {
        case .topLeading, .leading, .bottomLeading: return .left
        case .top, .center, .bottom: return .center
        case .topTrailing, .trailing, .bottomTrailing: return .right
        }
    }

    var textVAlign: TextVAlign {
        switch self {
        case .topLeading, .top, .topTrailing: return .top
        case .leading, .center, .trailing: return .middle
        case .bottomLeading, .bottom, .bottomTrailing: return .bottom
        }
    }
}

private extension Color {
    /// Relative luminance, 0 (black) … 1 (white).
    var luminance: Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return 0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)
    }

    /// "#RRGGBB", matching the decoder in `Models.swift`.
    var hexValue: String {
        let ui = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        ui.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02X%02X%02X",
                      Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }
}

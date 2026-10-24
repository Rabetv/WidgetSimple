import SwiftUI
import UIKit

// The "move the app name with my finger" feature. A widget can't be dragged and Edit
// Widget can't carry a gesture, so names are placed here, on a canvas at the widget's
// real size, saved as a named layout in the App Group, and picked per widget in Edit
// Widget › Layout (LayoutEntity). The canvas draws the same LauncherFace the widget
// draws, from the same plan, so a name lands where it was dropped.

// MARK: - List

struct LayoutListView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editing: LayoutDocument?

    var body: some View {
        List {
            Section {
                Button {
                    var layout = LayoutDocument()
                    layout.name = String(localized: "Layout \(model.layouts.count + 1)")
                    editing = layout
                } label: {
                    Label("New layout", systemImage: "plus")
                }
            } footer: {
                Text("Use a layout on a widget: hold the widget › Edit Widget › Layout. Widgets without one keep the automatic columns.")
            }
            .listRowBackground(GlassRowBackground())

            if !model.layouts.isEmpty {
                Section("Layouts") {
                    ForEach(model.layouts) { layout in
                        Button { editing = layout } label: { row(layout) }
                            .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        let doomed = offsets.map { model.layouts[$0] }
                        for layout in doomed { model.deleteLayout(layout) }
                    }
                }
                .listRowBackground(GlassRowBackground())
            }
        }
        .glassList()
        .navigationTitle("Layouts")
        .sheet(item: $editing) { layout in
            NavigationStack { LayoutEditorView(document: layout) }
                .environmentObject(model)
        }
    }

    private func row(_ layout: LayoutDocument) -> some View {
        HStack(spacing: Spacing.s) {
            Group {
                if let image = UIImage(contentsOfFile: SharedStore.shared.layoutThumbnailURL(id: layout.id).path) {
                    Image(uiImage: image).resizable().scaledToFit()
                } else {
                    RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.1))
                }
            }
            .frame(width: 72, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(layout.name).font(.headline)
                Text("\(FaceSize(layout.family).title) · \(layout.summary)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Editor

struct LayoutEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var document: LayoutDocument
    /// The slot being styled; -1 is the clock.
    @State private var selected: Int?
    /// Where the dragged item's centre was when the finger went down, in canvas points.
    @State private var dragOrigin: CGPoint?
    @State private var snapping = true
    @State private var guides: (vertical: Bool, horizontal: Bool) = (false, false)

    init(document: LayoutDocument) {
        _document = State(initialValue: document)
    }

    private var size: FaceSize { FaceSize(document.family) }
    private var geometry: FaceGeometry { FaceMetrics.geometry(for: size) }
    private var names: [String] { Array(model.sampleNames(for: document.family).prefix(12)) }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $document.name)
                Picker("Size", selection: Binding(get: { size }, set: { document.family = $0.spotFamily })) {
                    ForEach(FaceSize.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Arrangement", selection: modeBinding) {
                    ForEach(LayoutMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(GlassRowBackground())

            Section {
                canvas
                    .listRowInsets(EdgeInsets(top: Spacing.xs, leading: 0, bottom: Spacing.xs, trailing: 0))
                    .listRowBackground(Color.clear)
            } footer: {
                Text(document.mode == .freeform
                     ? "Drag a word to move it; tap to style it. Words snap to a 12 × 8 grid. The names are the apps one of your launchers shows, or samples."
                     : "Columns are filled row by row and balanced. Switch to Free to drag words anywhere.")
            }

            if document.mode == .columns {
                columnControls.listRowBackground(GlassRowBackground())
            } else {
                Section {
                    Toggle("Snap to grid", isOn: $snapping)
                }
                .listRowBackground(GlassRowBackground())
            }

            if let selected {
                styleControls(for: selected).listRowBackground(GlassRowBackground())
            }
        }
        .glassList()
        .navigationTitle(document.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    model.saveLayout(document)
                    dismiss()
                }
            }
        }
    }

    // MARK: Canvas

    private var plan: FacePlan {
        FacePlanner.plan(FacePlanInput(canvas: geometry.size, insets: FaceMetrics.margins(geometry), size: size,
                                       look: model.look, layout: document, names: names,
                                       clock: ClockContent.make(date: .now, option: model.clock, size: size),
                                       typeFactor: Typography.dynamicFactor(dynamicTypeSize)))
    }

    private var canvas: some View {
        let geometry = self.geometry
        let plan = self.plan
        return ScaledCanvas(size: geometry.size, maxScale: 2) { scale in
            ZStack(alignment: .topLeading) {
                PreviewBackdrop(size: size)
                if document.mode == .freeform { grid(geometry.size) }
                LauncherFace(look: model.look, clock: model.clock, date: .now, size: size,
                             apps: names, color: model.look.color, layout: document,
                             insets: FaceMetrics.margins(geometry))
                if document.mode == .freeform {
                    if let clock = plan.clock { handle(slot: -1, frame: clock.frame, scale: scale, canvas: geometry.size) }
                    ForEach(Array(plan.names.enumerated()), id: \.offset) { index, name in
                        handle(slot: index, frame: name.frame, scale: scale, canvas: geometry.size)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(RoundedRectangle(cornerRadius: WidgetPreviewCard.cornerRadius, style: .continuous))
        }
        .padding(.horizontal, Spacing.m)
    }

    private func grid(_ canvas: CGSize) -> some View {
        Canvas { context, size in
            var lines = Path()
            for column in 1..<LayoutDocument.gridColumns {
                let x = size.width * CGFloat(column) / CGFloat(LayoutDocument.gridColumns)
                lines.move(to: CGPoint(x: x, y: 0)); lines.addLine(to: CGPoint(x: x, y: size.height))
            }
            for row in 1..<LayoutDocument.gridRows {
                let y = size.height * CGFloat(row) / CGFloat(LayoutDocument.gridRows)
                lines.move(to: CGPoint(x: 0, y: y)); lines.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(lines, with: .color(.white.opacity(0.12)), lineWidth: 0.5)
            var center = Path()
            if guides.vertical {
                center.move(to: CGPoint(x: size.width / 2, y: 0)); center.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            }
            if guides.horizontal {
                center.move(to: CGPoint(x: 0, y: size.height / 2)); center.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            }
            context.stroke(center, with: .color(.yellow.opacity(0.8)), lineWidth: 1)
        }
        .frame(width: canvas.width, height: canvas.height)
        .allowsHitTesting(false)
    }

    /// An invisible target over a word (or the clock) that moves it.
    private func handle(slot: Int, frame: CGRect, scale: CGFloat, canvas: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .strokeBorder(selected == slot ? Color.yellow : Color.white.opacity(0.25),
                          style: StrokeStyle(lineWidth: 1, dash: selected == slot ? [] : [3, 3]))
            .contentShape(Rectangle())
            .frame(width: max(frame.width, 24), height: max(frame.height, 24))
            .position(x: frame.midX, y: frame.midY)
            .onTapGesture { selected = slot }
            .gesture(
                // Global coordinates: the canvas is drawn scaled, so the finger's travel
                // is divided by the scale to get canvas points.
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { value in
                        selected = slot
                        let origin = dragOrigin ?? CGPoint(x: frame.midX, y: frame.midY)
                        if dragOrigin == nil { dragOrigin = origin }
                        let center = CGPoint(x: origin.x + value.translation.width / scale,
                                             y: origin.y + value.translation.height / scale)
                        move(slot, to: center, canvas: canvas, snap: false)
                    }
                    .onEnded { value in
                        let origin = dragOrigin ?? CGPoint(x: frame.midX, y: frame.midY)
                        let center = CGPoint(x: origin.x + value.translation.width / scale,
                                             y: origin.y + value.translation.height / scale)
                        move(slot, to: center, canvas: canvas, snap: snapping)
                        dragOrigin = nil
                        guides = (false, false)
                    }
            )
    }

    private func move(_ slot: Int, to center: CGPoint, canvas: CGSize, snap: Bool) {
        var x = Double(center.x / max(canvas.width, 1))
        var y = Double(center.y / max(canvas.height, 1))
        if snap {
            x = LayoutDocument.snap(x, steps: LayoutDocument.gridColumns)
            y = LayoutDocument.snap(y, steps: LayoutDocument.gridRows)
        }
        x = min(max(x, 0), 1)
        y = min(max(y, 0), 1)
        guides = (abs(x - 0.5) < 0.01, abs(y - 0.5) < 0.01)
        let existing = slot == -1 ? document.clockItem : document.item(for: slot)
        let item = LayoutItem(slot: slot, x: x, y: y, scale: existing?.scale ?? 1, rotation: existing?.rotation ?? 0)
        if slot == -1 {
            document.clockItem = item
        } else {
            document.setItem(item)
        }
    }

    /// Switching to Free starts every word where the columns had it, so nothing jumps.
    private var modeBinding: Binding<LayoutMode> {
        Binding(
            get: { document.mode },
            set: { mode in
                if mode == .freeform, document.items.isEmpty {
                    let current = plan
                    let canvas = geometry.size
                    for (index, name) in current.names.enumerated() {
                        document.setItem(LayoutItem(slot: index, x: Double(name.frame.midX / canvas.width),
                                                    y: Double(name.frame.midY / canvas.height)))
                    }
                    if let clock = current.clock {
                        document.clockItem = LayoutItem(slot: -1, x: Double(clock.frame.midX / canvas.width),
                                                        y: Double(clock.frame.midY / canvas.height))
                    }
                }
                document.mode = mode
                selected = nil
            }
        )
    }

    // MARK: Controls

    private var columnControls: some View {
        Section("Columns") {
            Picker("Columns", selection: $document.columns) {
                Text("Auto").tag(0)
                ForEach(1...4, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
            slider("Row spacing", value: $document.rowSpacing, in: 0.4...2.5, format: "%.1f×")
            slider("Column spacing", value: $document.columnSpacing, in: 0.4...2.5, format: "%.1f×")
            slider("Move up or down", value: $document.verticalOffset, in: -60...60, format: "%.0f pt")
        }
    }

    @ViewBuilder
    private func styleControls(for slot: Int) -> some View {
        Section(slot == -1 ? String(localized: "Clock") : String(localized: "Word \(slot + 1)")) {
            if document.mode == .freeform {
                slider("Size", value: itemBinding(slot, \.scale, default: 1), in: 0.5...2.5, format: "%.1f×")
                if slot >= 0 {
                    slider("Rotation", value: itemBinding(slot, \.rotation, default: 0), in: -45...45, format: "%.0f°")
                }
            }
            if slot >= 0 {
                Picker("Weight", selection: styleBinding(slot, \.weight)) {
                    Text("Look").tag(NameWeight?.none)
                    ForEach(NameWeight.allCases) { Text($0.title).tag(NameWeight?.some($0)) }
                }
                slider("Opacity", value: Binding(
                    get: { document.style(for: slot)?.opacity ?? 1 },
                    set: { value in
                        var style = document.style(for: slot) ?? NameStyle(slot: slot)
                        style.opacity = value >= 0.999 ? nil : value
                        document.setStyle(style)
                    }), in: 0.2...1, format: "%.0f%%", multiplier: 100)
                ColorPicker("Colour", selection: Binding(
                    get: { document.style(for: slot)?.colorHex.map { Color(hex: $0) } ?? model.look.color },
                    set: { color in
                        var style = document.style(for: slot) ?? NameStyle(slot: slot)
                        style.colorHex = color.hexString
                        document.setStyle(style)
                    }), supportsOpacity: false)
                Button("Use the look's colour and weight") {
                    document.setStyle(NameStyle(slot: slot))
                }
            }
        }
    }

    private func slider(_ title: LocalizedStringKey, value: Binding<Double>, in range: ClosedRange<Double>,
                        format: String, multiplier: Double = 1) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent(title, value: String(format: format, value.wrappedValue * multiplier))
            Slider(value: value, in: range)
        }
    }

    private func itemBinding(_ slot: Int, _ path: WritableKeyPath<LayoutItem, Double>, default value: Double) -> Binding<Double> {
        Binding(
            get: {
                let item = slot == -1 ? document.clockItem : document.item(for: slot)
                return item?[keyPath: path] ?? value
            },
            set: { newValue in
                var item = (slot == -1 ? document.clockItem : document.item(for: slot))
                    ?? LayoutItem(slot: slot, x: 0.5, y: 0.5)
                item[keyPath: path] = newValue
                if slot == -1 { document.clockItem = item } else { document.setItem(item) }
            }
        )
    }

    private func styleBinding(_ slot: Int, _ path: WritableKeyPath<NameStyle, NameWeight?>) -> Binding<NameWeight?> {
        Binding(
            get: { document.style(for: slot)?[keyPath: path] ?? nil },
            set: { newValue in
                var style = document.style(for: slot) ?? NameStyle(slot: slot)
                style[keyPath: path] = newValue
                document.setStyle(style)
            }
        )
    }
}

// MARK: - Thumbnail

/// A small picture of a layout for the list (and for anything else that wants one).
@MainActor
enum LayoutThumbnail {
    static func render(_ layout: LayoutDocument, look: Look, clock: ClockOption) -> Data? {
        let size = FaceSize(layout.family)
        let geometry = FaceMetrics.geometry(for: size)
        let names = ["Phone", "Messages", "Camera", "Music", "Maps", "Notes"]
        let view = LauncherFace(look: look, clock: clock, date: .now, size: size, apps: names,
                                color: look.color, layout: layout, insets: FaceMetrics.margins(geometry))
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color(white: 0.16))
            .clipShape(RoundedRectangle(cornerRadius: WidgetPreviewCard.cornerRadius, style: .continuous))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.uiImage?.pngData()
    }
}

extension Color {
    /// "#RRGGBB", matching the decoder in `Models.swift`.
    var hexString: String {
        let ui = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        ui.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func byte(_ c: CGFloat) -> Int { Int((min(max(c, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }
}

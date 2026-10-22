import SwiftUI
import PhotosUI

struct LayoutEditorView: View {
    @EnvironmentObject private var model: AppModel
    let layoutID: UUID

    @State private var showingPicker = false
    @State private var editingItem: EditingItem?
    @State private var sampleItem: PhotosPickerItem?
    @State private var backdropItem: PhotosPickerItem?

    private struct EditingItem: Identifiable {
        let id: UUID
    }

    private var layout: Binding<LauncherLayout> { model.binding(for: layoutID) }

    var body: some View {
        List {
            Section {
                WidgetPreview(layout: layout.wrappedValue) { item in
                    editingItem = EditingItem(id: item.id)
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                .listRowBackground(Color.clear)
            } footer: {
                Text("Tap a word in the preview to edit it. On the Home Screen, a tap opens the app.")
            }

            Section("Name") {
                TextField("Layout name", text: layout.name)
                Picker("Widget size", selection: layout.size) {
                    ForEach(WidgetSizeOption.allCases) { Text($0.title).tag($0) }
                }
            }

            itemsSection
            Section {
                StyleEditor(style: layout.style)
            } header: {
                Text("Text style (all items)")
            } footer: {
                Text("Individual items can override this in their own settings.")
            }
            arrangementSection
            backgroundSection

            Section("Use it") {
                Text("Home Screen: long-press › Edit › Add Widget › WidgetSimple › Text Launcher (\(layout.wrappedValue.size.title)). Then long-press the widget › Edit Widget › Layout › \(layout.wrappedValue.name).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(layout.wrappedValue.name.isEmpty ? "Layout" : layout.wrappedValue.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .sheet(isPresented: $showingPicker) {
            AppPickerView(mode: .checklist(layoutID: layoutID))
        }
        .sheet(item: $editingItem) { editing in
            NavigationStack {
                ItemEditorView(layoutID: layoutID, itemID: editing.id)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { editingItem = nil }
                        }
                    }
            }
        }
        .onDisappear { model.saveNow() }
    }

    // MARK: Items

    private var itemsSection: some View {
        Section {
            ForEach(layout.wrappedValue.items) { item in
                NavigationLink {
                    ItemEditorView(layoutID: layoutID, itemID: item.id)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label.isEmpty ? "(no text)" : item.label)
                            .font(FontCatalog.font(id: layout.wrappedValue.style(for: item).fontID, size: 17))
                        Text(item.target.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .onDelete { offsets in
                layout.wrappedValue.items.remove(atOffsets: offsets)
            }
            .onMove { source, destination in
                layout.wrappedValue.items.move(fromOffsets: source, toOffset: destination)
            }

            Button {
                showingPicker = true
            } label: {
                Label("Choose apps", systemImage: "checklist")
            }
        } header: {
            Text("Apps (\(layout.wrappedValue.items.count))")
        } footer: {
            Text("Tick the apps from your iPhone that this widget shows. Drag to reorder (Edit), swipe to delete.")
        }
    }

    // MARK: Arrangement

    private var arrangementSection: some View {
        Section("Arrangement") {
            Picker("Style", selection: layout.arrangement) {
                ForEach(ArrangementKind.allCases) { Text($0.title).tag($0) }
            }
            if layout.wrappedValue.arrangement == .grid {
                Stepper("Columns: \(layout.wrappedValue.columns)", value: layout.columns, in: 1...6)
            }
            Picker("Horizontal", selection: layout.alignment) {
                ForEach(HAlignOption.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Vertical", selection: layout.verticalPosition) {
                ForEach(VAlignOption.allCases) { Text($0.title).tag($0) }
            }
            SliderRow(title: "Line spacing", value: layout.rowSpacing, range: 0...40)
            SliderRow(title: "Item spacing", value: layout.columnSpacing, range: 0...60)
            SliderRow(title: "Side margin", value: layout.paddingH, range: 0...60)
            SliderRow(title: "Top/bottom margin", value: layout.paddingV, range: 0...60)
        }
    }

    // MARK: Background

    private var backgroundSection: some View {
        Section {
            NavigationLink {
                BorderlessSetupView(layoutID: layoutID)
            } label: {
                Label("Hide the glass edge", systemImage: "square.dashed")
            }

            Picker("Background", selection: layout.background.mode) {
                ForEach(BackgroundMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            switch layout.wrappedValue.background.mode {
            case .transparent:
                Toggle("Keep my colors in Clear & Tinted style", isOn: layout.keepColorsInClearMode)
                PhotosPicker(selection: $backdropItem, matching: .images) {
                    Label(model.previewBackdrop == nil ? "Show my wallpaper in this preview" : "Change preview wallpaper",
                          systemImage: "photo")
                }
                .onChange(of: backdropItem) { _, newItem in
                    guard let newItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            model.setPreviewBackdrop(image)
                        }
                        backdropItem = nil
                    }
                }
            case .wallpaper:
                NavigationLink {
                    WallpaperMatchView(layoutID: layoutID)
                } label: {
                    HStack {
                        Label("Match my wallpaper", systemImage: "wand.and.stars")
                        Spacer()
                        if layout.wrappedValue.background.isWallpaperReady {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            Text("Not set").foregroundStyle(.secondary)
                        }
                    }
                }
            case .color:
                ColorPicker("Color", selection: Binding(
                    get: { layout.wrappedValue.background.color.color },
                    set: { layout.wrappedValue.background.color = RGBA($0) }
                ), supportsOpacity: false)
                Toggle("Different color in Dark Mode", isOn: Binding(
                    get: { layout.wrappedValue.background.darkColor != nil },
                    set: { layout.wrappedValue.background.darkColor = $0 ? layout.wrappedValue.background.color : nil }
                ))
                if let dark = layout.wrappedValue.background.darkColor {
                    ColorPicker("Dark Mode color", selection: Binding(
                        get: { dark.color },
                        set: { layout.wrappedValue.background.darkColor = RGBA($0) }
                    ), supportsOpacity: false)
                }
                PhotosPicker(selection: $sampleItem, matching: .images) {
                    Label("Pick color from a wallpaper screenshot", systemImage: "eyedropper")
                }
                .onChange(of: sampleItem) { _, newItem in
                    guard let newItem else { return }
                    Task { await sampleColor(from: newItem) }
                }
            }
        } header: {
            Text("Background")
        } footer: {
            Text(backgroundFooter)
        }
    }

    private var backgroundFooter: String {
        switch layout.wrappedValue.background.mode {
        case .transparent:
            return "No background: your wallpaper shows straight through the widget, so it reads as plain text. iOS still draws its thin glass edge on top; “Hide the glass edge” makes it disappear with a matching flat wallpaper. In the Clear and Tinted Home Screen styles iOS turns widget text white; the toggle keeps your fonts and colors there."
        case .wallpaper:
            return "Fallback if Transparent shows a solid box on your iPhone: the widget gets an exact copy of the wallpaper behind it."
        case .color:
            return "A solid color behind the text."
        }
    }

    private func sampleColor(from item: PhotosPickerItem) async {
        defer { sampleItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let color = WallpaperMatcher.averageColor(in: image) else { return }
        layout.wrappedValue.background.color = color
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var format: String = "%.0f"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}

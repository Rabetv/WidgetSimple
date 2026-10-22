import SwiftUI

struct LayoutEditorView: View {
    @EnvironmentObject private var model: AppModel
    let layoutID: UUID

    @State private var showingPicker = false
    @State private var editingItem: EditingItem?

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
            }

            Section {
                TextField("Name", text: layout.name)
                Picker("Size", selection: layout.size) {
                    ForEach(WidgetSizeOption.available) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Add it: hold the Home Screen › Edit › Add Widget › WidgetSimple.")
            }

            itemsSection

            Section("Text") {
                StyleEditor(style: layout.style)
            }

            arrangementSection
            backgroundSection
        }
        .navigationTitle(layout.wrappedValue.name.isEmpty ? "Widget" : layout.wrappedValue.name)
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
            Button {
                showingPicker = true
            } label: {
                Label("Choose apps", systemImage: "checklist")
            }

            ForEach(layout.wrappedValue.items) { item in
                NavigationLink {
                    ItemEditorView(layoutID: layoutID, itemID: item.id)
                } label: {
                    Text(item.label.isEmpty ? "(no text)" : item.label)
                        .font(FontCatalog.font(id: layout.wrappedValue.style(for: item).fontID, size: 17))
                }
            }
            .onDelete { offsets in
                layout.wrappedValue.items.remove(atOffsets: offsets)
            }
            .onMove { source, destination in
                layout.wrappedValue.items.move(fromOffsets: source, toOffset: destination)
            }
        } header: {
            Text("Apps (\(layout.wrappedValue.items.count))")
        } footer: {
            if Features.directLaunch {
                Text("Direct Launcher: pick its apps in Edit Widget. This layout sets the look.")
            }
        }
    }

    // MARK: Arrangement

    private var arrangementSection: some View {
        Section("Layout") {
            Picker("Style", selection: layout.arrangement) {
                ForEach(ArrangementKind.allCases) { Text($0.title).tag($0) }
            }
            if layout.wrappedValue.arrangement == .grid {
                Stepper("Columns: \(layout.wrappedValue.columns)", value: layout.columns, in: 1...6)
            }
            Picker("Align", selection: layout.alignment) {
                ForEach(HAlignOption.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Position", selection: layout.verticalPosition) {
                ForEach(VAlignOption.allCases) { Text($0.title).tag($0) }
            }
            DisclosureGroup("Spacing") {
                SliderRow(title: "Lines", value: layout.rowSpacing, range: 0...40)
                SliderRow(title: "Items", value: layout.columnSpacing, range: 0...60)
                SliderRow(title: "Sides", value: layout.paddingH, range: 0...60)
                SliderRow(title: "Top/bottom", value: layout.paddingV, range: 0...60)
            }
        }
    }

    // MARK: Background

    private var backgroundSection: some View {
        Section("Background") {
            Picker("Background", selection: layout.background.mode) {
                ForEach(BackgroundMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            switch layout.wrappedValue.background.mode {
            case .clear:
                Toggle("Keep colors in Clear & Tinted style", isOn: layout.keepColorsInClearMode)
            case .color:
                ColorSwatches(selection: Binding(
                    get: { layout.wrappedValue.background.color },
                    set: {
                        layout.wrappedValue.background.color = $0
                        layout.wrappedValue.background.darkColor = nil
                    }
                ))
            case .wallpaper:
                NavigationLink {
                    WallpaperMatchView(layoutID: layoutID)
                } label: {
                    HStack {
                        Text("Match my wallpaper")
                        Spacer()
                        if layout.wrappedValue.background.isWallpaperReady {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }
                }
            }

            NavigationLink {
                NoEdgesView()
            } label: {
                Label("Hide the edges", systemImage: "square.dashed")
            }
        }
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

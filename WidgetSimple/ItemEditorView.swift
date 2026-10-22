import SwiftUI

struct ItemEditorView: View {
    @EnvironmentObject private var model: AppModel
    let layoutID: UUID
    let itemID: UUID

    @State private var showingAppPicker = false

    private var layout: Binding<LauncherLayout> { model.binding(for: layoutID) }

    private var item: Binding<LaunchItem> {
        Binding(
            get: {
                layout.wrappedValue.items.first(where: { $0.id == itemID })
                    ?? LaunchItem(label: "", target: LaunchTarget())
            },
            set: { newValue in
                if let index = layout.wrappedValue.items.firstIndex(where: { $0.id == itemID }) {
                    layout.wrappedValue.items[index] = newValue
                }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                ItemLabel(item: item.wrappedValue,
                          style: layout.wrappedValue.style(for: item.wrappedValue),
                          alignment: layout.wrappedValue.alignment)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(previewBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .listRowInsets(EdgeInsets())
            }

            Section("Text on the widget") {
                TextField("Text", text: item.label)
                    .textInputAutocapitalization(.never)
                TextField("SF Symbol (optional, e.g. music.note)", text: item.symbol)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                Picker("Opens", selection: item.target.kind) {
                    // Shortcuts are no longer offered; items that already use one keep working.
                    ForEach(TargetKind.allCases.filter { $0 != .shortcut || item.wrappedValue.target.kind == .shortcut }) {
                        Text($0.title).tag($0)
                    }
                }
                targetFields
                Button {
                    model.test(item.wrappedValue.target.url)
                } label: {
                    Label("Test now", systemImage: "play.circle")
                }
            } header: {
                Text("What it opens")
            } footer: {
                Text(targetFooter)
            }

            Section {
                Toggle("Custom style for this item", isOn: item.useCustomStyle)
                if item.wrappedValue.useCustomStyle {
                    StyleEditor(style: item.style)
                    Button("Copy style from layout") {
                        item.wrappedValue.style = layout.wrappedValue.style
                    }
                }
            } header: {
                Text("Style")
            }

            Section {
                Button("Delete item", role: .destructive) {
                    layout.wrappedValue.items.removeAll { $0.id == itemID }
                }
            }
        }
        .navigationTitle(item.wrappedValue.label.isEmpty ? "Item" : item.wrappedValue.label)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView(mode: .single({ picked in
                var updated = item.wrappedValue
                updated.target = picked.target
                if updated.label.isEmpty { updated.label = picked.label }
                item.wrappedValue = updated
            }))
        }
    }

    private var previewBackground: Color {
        let bg = layout.wrappedValue.background
        return bg.mode == .color ? bg.color.color : Color(white: 0.15)
    }

    @ViewBuilder
    private var targetFields: some View {
        switch item.wrappedValue.target.kind {
        case .app:
            Button {
                showingAppPicker = true
            } label: {
                HStack {
                    Text("App")
                    Spacer()
                    Text(item.wrappedValue.target.catalogID.flatMap { AppCatalog.app(id: $0)?.name } ?? "Choose…")
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
        case .urlScheme:
            TextField("myapp://", text: item.target.value)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        case .website:
            TextField("https://example.com", text: item.target.value)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        case .shortcut:
            TextField("Exact shortcut name", text: item.target.value)
                .autocorrectionDisabled()
        }
    }

    private var targetFooter: String {
        switch item.wrappedValue.target.kind {
        case .app:
            return "Pick from your apps."
        case .urlScheme:
            return "e.g. spotify:// or tel://123"
        case .website:
            return "Opens the site, or its app if installed."
        case .shortcut:
            return "Runs this Shortcut."
        }
    }
}

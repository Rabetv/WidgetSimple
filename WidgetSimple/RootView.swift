import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("didSeeTutorial") private var didSeeTutorial = false
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Widgets") {
                    ForEach(model.layouts) { layout in
                        NavigationLink(value: layout.id) {
                            LayoutRow(layout: layout)
                        }
                        .contextMenu {
                            Button("Duplicate", systemImage: "plus.square.on.square") {
                                model.duplicate(layout)
                            }
                        }
                    }
                    .onDelete(perform: model.deleteLayouts)
                    .onMove(perform: model.moveLayouts)

                    Button {
                        let layout = model.addLayout()
                        path.append(layout.id)
                    } label: {
                        Label("New widget", systemImage: "plus")
                    }
                }

                Section {
                    NavigationLink {
                        ClockEditorView()
                    } label: {
                        Label("Clock widget", systemImage: "clock")
                    }
                    NavigationLink {
                        NoEdgesView()
                    } label: {
                        Label("Hide the edges", systemImage: "square.dashed")
                    }
                    NavigationLink {
                        FontLibraryView()
                    } label: {
                        Label("Fonts", systemImage: "textformat")
                    }
                }

                if model.isCalibrating {
                    Section {
                        Button(role: .destructive) {
                            model.stopCalibration()
                        } label: {
                            Label("Stop magenta widget", systemImage: "xmark.circle")
                        }
                    }
                }

                if !model.store.isAppGroupAvailable {
                    Section {
                        Label("App Group missing: widgets can't load.", systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("WidgetSimple")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        didSeeTutorial = false
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("Tutorial")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .navigationDestination(for: UUID.self) { id in
                LayoutEditorView(layoutID: id)
            }
        }
    }
}

private struct LayoutRow: View {
    let layout: LauncherLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(layout.name.isEmpty ? "Untitled" : layout.name)
                .font(.headline)
            Text(layout.items.map(\.label).joined(separator: " · "))
                .font(FontCatalog.font(id: layout.style.fontID, size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(layout.size.title)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

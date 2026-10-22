import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
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
                        Label("New widget layout", systemImage: "plus")
                    }
                } header: {
                    Text("Your widgets")
                } footer: {
                    Text("Each layout is one widget design. On the Home Screen, long-press a WidgetSimple widget, tap Edit Widget and choose the layout.")
                }

                Section("Set up") {
                    NavigationLink {
                        AddWidgetGuideView()
                    } label: {
                        Label("Add the widget to your Home Screen", systemImage: "square.grid.2x2")
                    }
                    NavigationLink {
                        GlassGuideView()
                    } label: {
                        Label("Transparent widgets & the glass edge", systemImage: "rectangle.dashed")
                    }
                    NavigationLink {
                        LaunchSettingsView()
                    } label: {
                        Label("How apps open", systemImage: "arrow.up.forward.app")
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
                            Label("Stop calibration (widget is magenta)", systemImage: "xmark.circle")
                        }
                    }
                }

                if !model.store.isAppGroupAvailable {
                    Section {
                        Label("App Group not configured. The widget can't see your layouts until signing and the App Group are set up (see README).", systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("WidgetSimple")
            .toolbar {
                EditButton()
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
            HStack(spacing: 6) {
                Text(layout.size.title)
                Text("·")
                Text(layout.background.isWallpaperReady ? "Wallpaper matched" : layout.background.mode.title)
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

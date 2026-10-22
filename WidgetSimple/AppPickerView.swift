import SwiftUI

/// Pick an app from the catalog, or add a website / URL scheme / shortcut.
struct AppPickerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var appsOnly: Bool = false
    let onPick: (LaunchItem) -> Void

    @State private var search = ""
    @State private var custom: CustomEntry?
    @State private var installed: [String: Bool] = [:]

    private struct CustomEntry: Identifiable {
        let kind: TargetKind
        var id: String { kind.rawValue }
    }

    var body: some View {
        NavigationStack {
            List {
                if !appsOnly && search.isEmpty {
                    Section {
                        Button { custom = CustomEntry(kind: .website) } label: {
                            Label("Website or universal link", systemImage: "globe")
                        }
                        Button { custom = CustomEntry(kind: .urlScheme) } label: {
                            Label("Custom URL scheme", systemImage: "link")
                        }
                        Button { custom = CustomEntry(kind: .shortcut) } label: {
                            Label("Any app via Shortcut", systemImage: "square.stack.3d.up")
                        }
                    } footer: {
                        Text("iOS doesn't let apps see everything you have installed. For apps not listed below, use a URL scheme or a Shortcut with the “Open App” action.")
                    }
                }

                let detected = filteredApps.filter { installed[$0.id] == true }
                if !detected.isEmpty {
                    Section("Installed") {
                        ForEach(detected) { app in appRow(app) }
                    }
                }

                ForEach(CatalogApp.Category.allCases, id: \.self) { category in
                    let apps = filteredApps.filter { $0.category == category && installed[$0.id] != true }
                    if !apps.isEmpty {
                        Section(category.rawValue) {
                            ForEach(apps) { app in appRow(app) }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search apps")
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $custom) { entry in
                CustomTargetSheet(kind: entry.kind) { item in
                    onPick(item)
                    custom = nil
                    dismiss()
                }
            }
            .onAppear(perform: detectInstalled)
        }
    }

    private var filteredApps: [CatalogApp] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return AppCatalog.apps }
        return AppCatalog.apps.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private func appRow(_ app: CatalogApp) -> some View {
        Button {
            onPick(LaunchItem.from(app: app))
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).foregroundStyle(.primary)
                    Text(app.url).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                status(for: app)
            }
        }
    }

    @ViewBuilder
    private func status(for app: CatalogApp) -> some View {
        switch installed[app.id] {
        case .some(true):
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .some(false):
            Text("Not installed").font(.caption).foregroundStyle(.secondary)
        case .none:
            if !app.wellKnown {
                Text("Test after adding").font(.caption2).foregroundStyle(.orange)
            }
        }
    }

    private func detectInstalled() {
        var result: [String: Bool] = [:]
        for app in AppCatalog.apps {
            if let value = model.isInstalled(app) { result[app.id] = value }
        }
        installed = result
    }
}

private struct CustomTargetSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let kind: TargetKind
    let onAdd: (LaunchItem) -> Void

    @State private var label = ""
    @State private var value = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Text on the widget") {
                    TextField("e.g. Camera", text: $label)
                }
                Section {
                    TextField(placeholder, text: $value)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(kind == .shortcut ? .default : .URL)
                    Button("Test now") {
                        model.test(LaunchTarget(kind: kind, value: value).url)
                    }
                    .disabled(value.isEmpty)
                } header: {
                    Text(kind.title)
                } footer: {
                    Text(help)
                }
            }
            .navigationTitle("Add \(kind.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let text = label.isEmpty ? value : label
                        onAdd(LaunchItem(label: text, target: LaunchTarget(kind: kind, value: value)))
                    }
                    .disabled(value.isEmpty)
                }
            }
        }
    }

    private var placeholder: String {
        switch kind {
        case .website: return "https://…"
        case .urlScheme: return "myapp://"
        case .shortcut: return "Shortcut name"
        case .app: return ""
        }
    }

    private var help: String {
        switch kind {
        case .website:
            return "Opens directly from the widget. Apps with universal links (YouTube, Instagram, Spotify…) open in the app."
        case .urlScheme:
            return "Many apps publish a URL scheme. Examples: tel://123456, sms://, mailto:you@example.com, spotify://"
        case .shortcut:
            return "1. Open Shortcuts › + › Add Action › “Open App”.\n2. Choose the app (works for every installed app, e.g. Camera, Settings, Calculator).\n3. Rename the shortcut, e.g. “Cam”.\n4. Type that exact name here."
        case .app:
            return ""
        }
    }
}

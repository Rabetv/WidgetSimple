import SwiftUI

/// The apps on your iPhone as a checklist: tick the ones a widget shows.
/// Also picks a single app for an existing item.
///
/// iOS has no public way to list every installed app, so WidgetSimple checks its
/// catalog of well-known apps and lists the ones it finds on this iPhone first.
struct AppPickerView: View {
    enum Mode {
        /// Tick apps on and off for a layout.
        case checklist(layoutID: UUID)
        /// Pick one app, then close.
        case single((LaunchItem) -> Void)
    }

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var search = ""
    @State private var custom: CustomEntry?
    @State private var installed: [String: Bool] = [:]
    @State private var showUndetected = false

    private struct CustomEntry: Identifiable {
        let kind: TargetKind
        var id: String { kind.rawValue }
    }

    private var layoutID: UUID? {
        if case .checklist(let id) = mode { return id }
        return nil
    }

    var body: some View {
        NavigationStack {
            List {
                let apps = filteredApps
                let onPhone = apps.filter { installed[$0.id] == true }
                let builtIn = apps.filter { $0.category == .apple }
                let undetected = apps.filter { $0.category != .apple && installed[$0.id] == nil }

                if !onPhone.isEmpty {
                    Section {
                        ForEach(onPhone) { row($0) }
                    } header: {
                        Text("On this iPhone (\(onPhone.count))")
                    }
                }

                if !builtIn.isEmpty {
                    Section("Built-in apps") {
                        ForEach(builtIn) { row($0) }
                    }
                }

                if !undetected.isEmpty {
                    Section {
                        if showUndetected || !search.isEmpty {
                            ForEach(undetected) { row($0) }
                        } else {
                            Button("Show \(undetected.count) more apps") { showUndetected = true }
                        }
                    } header: {
                        Text("More apps")
                    } footer: {
                        Text("iOS lets an app check only a limited number of other apps, so WidgetSimple can't tell whether these are installed. Tick the ones you have.")
                    }
                }

                if layoutID != nil && search.isEmpty {
                    Section {
                        Button { custom = CustomEntry(kind: .website) } label: {
                            Label("Website or universal link", systemImage: "globe")
                        }
                        Button { custom = CustomEntry(kind: .urlScheme) } label: {
                            Label("App by URL scheme", systemImage: "link")
                        }
                    } header: {
                        Text("Not in the list?")
                    } footer: {
                        Text("Most apps also open through a link, e.g. spotify:// or https://youtube.com.")
                    }
                }
            }
            .searchable(text: $search, prompt: "Search apps")
            .navigationTitle(layoutID == nil ? "Choose App" : "Choose Apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if layoutID == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .sheet(item: $custom) { entry in
                CustomTargetSheet(kind: entry.kind) { item in
                    if let layoutID {
                        model.binding(for: layoutID).wrappedValue.items.append(item)
                    }
                    custom = nil
                }
            }
            .onAppear(perform: detectInstalled)
        }
    }

    private var filteredApps: [CatalogApp] {
        let q = search.trimmingCharacters(in: .whitespaces)
        let apps = q.isEmpty ? AppCatalog.apps : AppCatalog.apps.filter { $0.name.localizedCaseInsensitiveContains(q) }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func row(_ app: CatalogApp) -> some View {
        Button {
            tap(app)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).foregroundStyle(.primary)
                    if installed[app.id] == nil && !app.wellKnown {
                        Text("Test after adding").font(.caption2).foregroundStyle(.orange)
                    }
                }
                Spacer()
                if layoutID != nil {
                    let selected = isSelected(app)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                }
            }
            .contentShape(Rectangle())
        }
    }

    private func isSelected(_ app: CatalogApp) -> Bool {
        guard let layoutID, let layout = model.layout(id: layoutID) else { return false }
        return layout.items.contains { $0.target.catalogID == app.id }
    }

    private func tap(_ app: CatalogApp) {
        switch mode {
        case .single(let onPick):
            onPick(LaunchItem.from(app: app))
            dismiss()
        case .checklist(let layoutID):
            let layout = model.binding(for: layoutID)
            if isSelected(app) {
                layout.wrappedValue.items.removeAll { $0.target.catalogID == app.id }
            } else {
                layout.wrappedValue.items.append(LaunchItem.from(app: app))
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
            return "Runs the Shortcut with exactly this name."
        case .app:
            return ""
        }
    }
}

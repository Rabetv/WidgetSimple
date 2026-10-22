import SwiftUI
import UniformTypeIdentifiers

/// Rows for editing a TextStyle. Used inside a Form/List section.
struct StyleEditor: View {
    @Binding var style: TextStyle

    var body: some View {
        NavigationLink {
            FontPickerView(selection: $style.fontID, previewSize: style.size)
        } label: {
            HStack {
                Text("Font")
                Spacer()
                Text(FontCatalog.displayName(for: style.fontID))
                    .font(FontCatalog.font(id: style.fontID, size: 16))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }

        SliderRow(title: "Size", value: $style.size, range: 8...72)

        Picker("Weight", selection: $style.weight) {
            ForEach(FontWeightOption.allCases) { Text($0.title).tag($0) }
        }

        ColorPicker("Color", selection: Binding(
            get: { style.color.color },
            set: { style.color = RGBA($0) }
        ), supportsOpacity: true)

        DisclosureGroup("More") {
            Toggle("Italic", isOn: $style.italic)
            Toggle("Underline", isOn: $style.underline)

            SliderRow(title: "Letter spacing", value: $style.tracking, range: -3...15, step: 0.5, format: "%.1f")

            Picker("Case", selection: $style.textCase) {
                ForEach(TextCaseOption.allCases) { Text($0.title).tag($0) }
            }

            Toggle("Shadow", isOn: $style.shadow)
            if style.shadow {
                SliderRow(title: "Shadow blur", value: $style.shadowRadius, range: 0...12)
                ColorPicker("Shadow color", selection: Binding(
                    get: { style.shadowColor.color },
                    set: { style.shadowColor = RGBA($0) }
                ), supportsOpacity: true)
            }
        }
    }
}

struct FontPickerView: View {
    @Binding var selection: String
    var previewSize: Double = 20

    @State private var search = ""
    @State private var importing = false
    @State private var imported: [FontChoice] = FontCatalog.importedFonts
    @State private var importError: String?

    var body: some View {
        List {
            Section("System") {
                ForEach(filter(FontCatalog.systemFonts)) { row($0) }
            }
            Section {
                ForEach(filter(imported)) { row($0) }
                Button {
                    importing = true
                } label: {
                    Label("Import font file (.ttf / .otf)", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Your fonts")
            } footer: {
                Text("Import .ttf or .otf files.")
            }
            Section("Built into iOS") {
                ForEach(filter(FontCatalog.familyFonts)) { row($0) }
            }
        }
        .searchable(text: $search)
        .navigationTitle("Font")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [.font, UTType(filenameExtension: "ttf") ?? .font, UTType(filenameExtension: "otf") ?? .font],
                      allowsMultipleSelection: true) { result in
            handleImport(result)
        }
        .alert("Font import failed", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    private func filter(_ fonts: [FontChoice]) -> [FontChoice] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return fonts }
        return fonts.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private func row(_ font: FontChoice) -> some View {
        Button {
            selection = font.id
        } label: {
            HStack {
                Text(font.name)
                    .font(FontCatalog.font(id: font.id, size: min(max(previewSize, 15), 26)))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                if selection == font.id {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let urls):
            var lastAdded: FontChoice?
            for url in urls {
                do {
                    let added = try FontRegistry.importFont(from: url)
                    lastAdded = added.first ?? lastAdded
                } catch {
                    importError = "\(url.lastPathComponent): \(error.localizedDescription)"
                }
            }
            imported = FontCatalog.importedFonts
            if let lastAdded { selection = lastAdded.id }
        }
    }
}

/// Manage imported fonts.
struct FontLibraryView: View {
    @State private var fonts: [FontChoice] = FontCatalog.importedFonts
    @State private var selection = FontCatalog.systemID

    var body: some View {
        List {
            Section {
                NavigationLink("Import or browse fonts") {
                    FontPickerView(selection: $selection)
                }
            } footer: {
                Text("40+ fonts built in. Import your own .ttf or .otf.")
            }
            if !fonts.isEmpty {
                Section("Imported") {
                    ForEach(fonts) { font in
                        Text(font.name).font(FontCatalog.font(id: font.id, size: 20))
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            FontRegistry.removeFont(postScriptName: String(fonts[index].id.dropFirst(3)))
                        }
                        fonts = FontCatalog.importedFonts
                    }
                }
            }
        }
        .navigationTitle("Fonts")
        .onAppear { fonts = FontCatalog.importedFonts }
    }
}

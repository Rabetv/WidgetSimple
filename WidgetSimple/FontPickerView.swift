import SwiftUI
import UniformTypeIdentifiers

/// Every font: the system ones, the 40 built into iOS, and imported .ttf / .otf files.
struct FontPickerView: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

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
                    .onDelete { offsets in
                        let shown = filter(imported)
                        for index in offsets {
                            FontRegistry.removeFont(postScriptName: String(shown[index].id.dropFirst(3)))
                        }
                        imported = FontCatalog.importedFonts
                    }
                Button {
                    importing = true
                } label: {
                    Label("Add a font file (.ttf / .otf)", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Your fonts")
            }
            Section("Built into iOS") {
                ForEach(filter(FontCatalog.familyFonts)) { row($0) }
            }
        }
        .searchable(text: $search)
        .navigationTitle("Fonts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
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
                    .font(FontCatalog.font(id: font.id, size: 20))
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

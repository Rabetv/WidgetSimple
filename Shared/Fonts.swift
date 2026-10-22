import Foundation
import SwiftUI
import CoreText

struct FontChoice: Identifiable, Hashable {
    let id: String
    let name: String
}

/// Fonts the user can pick. IDs:
///  - "sys:<design>"  system font with a design (default, rounded, serif, mono)
///  - "fam:<family>"  a font family that ships with iOS
///  - "ps:<name>"     an imported font, by PostScript name
enum FontCatalog {
    static let systemID = "sys:default"

    static let systemFonts: [FontChoice] = [
        FontChoice(id: "sys:default", name: "SF Pro (System)"),
        FontChoice(id: "sys:rounded", name: "SF Pro Rounded"),
        FontChoice(id: "sys:serif", name: "New York (Serif)"),
        FontChoice(id: "sys:mono", name: "SF Mono"),
    ]

    /// Families preinstalled on every iPhone (iOS 18+).
    static let builtInFamilies: [String] = [
        "Academy Engraved LET", "American Typewriter", "Arial", "Arial Rounded MT Bold",
        "Avenir", "Avenir Next", "Avenir Next Condensed", "Baskerville", "Bodoni 72",
        "Bodoni 72 Smallcaps", "Bradley Hand", "Chalkboard SE", "Chalkduster", "Charter",
        "Cochin", "Copperplate", "Courier New", "Didot", "DIN Alternate", "DIN Condensed",
        "Futura", "Georgia", "Gill Sans", "Helvetica Neue", "Hoefler Text", "Marker Felt",
        "Menlo", "Noteworthy", "Optima", "Palatino", "Papyrus", "Party LET", "Rockwell",
        "Savoye LET", "Snell Roundhand", "Superclarendon", "Times New Roman", "Trebuchet MS",
        "Verdana", "Zapfino",
    ]

    static var familyFonts: [FontChoice] {
        builtInFamilies.map { FontChoice(id: "fam:\($0)", name: $0) }
    }

    static var importedFonts: [FontChoice] {
        SharedStore.shared.loadFontIndex().map { FontChoice(id: "ps:\($0.postScriptName)", name: $0.displayName) }
    }

    static func displayName(for id: String) -> String {
        if let match = systemFonts.first(where: { $0.id == id }) { return match.name }
        if id.hasPrefix("fam:") { return String(id.dropFirst(4)) }
        if id.hasPrefix("ps:") {
            let ps = String(id.dropFirst(3))
            return SharedStore.shared.loadFontIndex().first(where: { $0.postScriptName == ps })?.displayName ?? ps
        }
        return "System"
    }

    /// A few good-looking fonts, offered first in the app.
    static let quickPicks: [FontChoice] = [
        FontChoice(id: "sys:default", name: "Simple"),
        FontChoice(id: "sys:rounded", name: "Round"),
        FontChoice(id: "sys:serif", name: "Book"),
        FontChoice(id: "sys:mono", name: "Typewriter"),
        FontChoice(id: "fam:Futura", name: "Futura"),
        FontChoice(id: "fam:Didot", name: "Didot"),
        FontChoice(id: "fam:Chalkboard SE", name: "Chalk"),
    ]

    static func font(id: String, size: Double, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        let s = CGFloat(max(4, size))
        var font: Font
        switch id {
        case "sys:rounded": font = .system(size: s, weight: weight, design: .rounded)
        case "sys:serif": font = .system(size: s, weight: weight, design: .serif)
        case "sys:mono": font = .system(size: s, weight: weight, design: .monospaced)
        case _ where id.hasPrefix("fam:"):
            font = Font.custom(String(id.dropFirst(4)), fixedSize: s).weight(weight)
        case _ where id.hasPrefix("ps:"):
            FontRegistry.registerAllOnce()
            font = Font.custom(String(id.dropFirst(3)), fixedSize: s).weight(weight)
        default: font = .system(size: s, weight: weight, design: .default)
        }
        if italic { font = font.italic() }
        return font
    }
}

/// Imports .ttf / .otf files into the App Group so both the app and the widget can use them.
enum FontRegistry {
    private static let lock = NSLock()
    private static var registered = Set<String>()

    /// Registers every imported font for the current process (app or widget).
    static func registerAllOnce() {
        let store = SharedStore.shared
        for entry in store.loadFontIndex() {
            register(fileURL: store.fontsURL.appendingPathComponent(entry.fileName))
        }
    }

    @discardableResult
    static func register(fileURL: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if registered.contains(fileURL.lastPathComponent) { return true }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return false }
        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(fileURL as CFURL, .process, &error)
        // "Already registered" also counts as usable.
        registered.insert(fileURL.lastPathComponent)
        return ok || error != nil
    }

    enum ImportError: LocalizedError {
        case unreadable, noFonts
        var errorDescription: String? {
            switch self {
            case .unreadable: return "The file could not be read."
            case .noFonts: return "No usable font was found in this file."
            }
        }
    }

    /// Copies a font file into the shared container, registers it and returns the new font ids.
    static func importFont(from sourceURL: URL) throws -> [FontChoice] {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: sourceURL) else { throw ImportError.unreadable }
        let store = SharedStore.shared
        let ext = sourceURL.pathExtension.isEmpty ? "ttf" : sourceURL.pathExtension
        let fileName = "\(UUID().uuidString).\(ext)"
        let destination = store.fontsURL.appendingPathComponent(fileName)
        try data.write(to: destination, options: .atomic)

        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(destination as CFURL) as? [CTFontDescriptor],
              !descriptors.isEmpty else {
            try? FileManager.default.removeItem(at: destination)
            throw ImportError.noFonts
        }

        register(fileURL: destination)

        var index = store.loadFontIndex()
        var added: [FontChoice] = []
        for descriptor in descriptors {
            guard let ps = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String else { continue }
            let display = (CTFontDescriptorCopyAttribute(descriptor, kCTFontDisplayNameAttribute) as? String) ?? ps
            if index.contains(where: { $0.postScriptName == ps }) { continue }
            index.append(SharedStore.StoredFont(postScriptName: ps, displayName: display, fileName: fileName))
            added.append(FontChoice(id: "ps:\(ps)", name: display))
        }
        store.saveFontIndex(index)
        if added.isEmpty && !index.contains(where: { $0.fileName == fileName }) {
            try? FileManager.default.removeItem(at: destination)
        }
        return added
    }

    static func removeFont(postScriptName: String) {
        let store = SharedStore.shared
        var index = store.loadFontIndex()
        guard let entry = index.first(where: { $0.postScriptName == postScriptName }) else { return }
        index.removeAll { $0.postScriptName == postScriptName }
        store.saveFontIndex(index)
        if !index.contains(where: { $0.fileName == entry.fileName }) {
            try? FileManager.default.removeItem(at: store.fontsURL.appendingPathComponent(entry.fileName))
        }
    }
}

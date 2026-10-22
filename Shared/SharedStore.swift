import Foundation

/// File-based storage in the App Group container, shared by the app and the widget.
final class SharedStore: @unchecked Sendable {
    static let shared = SharedStore()

    let rootURL: URL
    /// False when the App Group entitlement is missing (e.g. signing not set up yet).
    let isAppGroupAvailable: Bool

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    private let decoder = JSONDecoder()

    private init() {
        let id = (Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String) ?? ""
        let fm = FileManager.default
        if !id.isEmpty, !id.contains("$("), let url = fm.containerURL(forSecurityApplicationGroupIdentifier: id) {
            rootURL = url.appendingPathComponent("WidgetSimple", isDirectory: true)
            isAppGroupAvailable = true
        } else {
            let docs = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            rootURL = docs.appendingPathComponent("WidgetSimple", isDirectory: true)
            isAppGroupAvailable = false
        }
        for dir in [rootURL, fontsURL] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: Locations

    var lookURL: URL { rootURL.appendingPathComponent("look.json") }
    var fontsIndexURL: URL { rootURL.appendingPathComponent("fonts.json") }
    var fontsURL: URL { rootURL.appendingPathComponent("Fonts", isDirectory: true) }

    // MARK: Generic JSON

    private func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: Look

    func loadLook() -> Look {
        read(Look.self, from: lookURL) ?? Look()
    }

    func saveLook(_ look: Look) {
        write(look, to: lookURL)
    }

    // MARK: Custom fonts index

    struct StoredFont: Codable, Hashable {
        var postScriptName: String
        var displayName: String
        var fileName: String
    }

    func loadFontIndex() -> [StoredFont] {
        read([StoredFont].self, from: fontsIndexURL) ?? []
    }

    func saveFontIndex(_ fonts: [StoredFont]) {
        write(fonts, to: fontsIndexURL)
    }
}

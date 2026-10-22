import Foundation
import UIKit

/// File-based storage in the App Group container, shared by the app and the widget.
final class SharedStore: @unchecked Sendable {
    static let shared = SharedStore()

    let groupID: String
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
        groupID = id
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
        for dir in [rootURL, backgroundsURL, fontsURL] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: Locations

    var layoutsURL: URL { rootURL.appendingPathComponent("layouts.json") }
    var settingsURL: URL { rootURL.appendingPathComponent("settings.json") }
    var metricsURL: URL { rootURL.appendingPathComponent("widget-metrics.json") }
    var clockURL: URL { rootURL.appendingPathComponent("clock.json") }
    var fontsIndexURL: URL { rootURL.appendingPathComponent("fonts.json") }
    var backgroundsURL: URL { rootURL.appendingPathComponent("Backgrounds", isDirectory: true) }
    var fontsURL: URL { rootURL.appendingPathComponent("Fonts", isDirectory: true) }

    func backgroundURL(for layoutID: UUID, dark: Bool) -> URL {
        backgroundsURL.appendingPathComponent("\(layoutID.uuidString)-\(dark ? "dark" : "light").png")
    }

    // MARK: Generic JSON

    private func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: Layouts

    func loadLayouts() -> [LauncherLayout] {
        read([LauncherLayout].self, from: layoutsURL) ?? []
    }

    func saveLayouts(_ layouts: [LauncherLayout]) {
        write(layouts, to: layoutsURL)
    }

    func layout(id: UUID?) -> LauncherLayout? {
        let all = loadLayouts()
        if let id, let match = all.first(where: { $0.id == id }) { return match }
        return all.first
    }

    // MARK: Settings

    func loadSettings() -> AppSettings {
        read(AppSettings.self, from: settingsURL) ?? AppSettings()
    }

    func saveSettings(_ settings: AppSettings) {
        write(settings, to: settingsURL)
    }

    // MARK: Clock widget

    func loadClock() -> ClockStyle {
        read(ClockStyle.self, from: clockURL) ?? ClockStyle()
    }

    func saveClock(_ clock: ClockStyle) {
        write(clock, to: clockURL)
    }

    // MARK: Widget metrics (written by the widget)

    func loadMetrics() -> WidgetMetrics {
        read(WidgetMetrics.self, from: metricsURL) ?? WidgetMetrics()
    }

    func recordWidgetSize(_ size: CGSize, for option: WidgetSizeOption) {
        guard size.width > 10, size.height > 10 else { return }
        var metrics = loadMetrics()
        let new = PixelSize(width: Double(size.width), height: Double(size.height))
        if metrics.sizes[option.rawValue] != new {
            metrics.sizes[option.rawValue] = new
            write(metrics, to: metricsURL)
        }
    }

    // MARK: Backgrounds

    func saveBackground(_ image: UIImage, layoutID: UUID, dark: Bool) -> Bool {
        guard let data = image.pngData() else { return false }
        do {
            try data.write(to: backgroundURL(for: layoutID, dark: dark), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    func loadBackground(layoutID: UUID, dark: Bool) -> UIImage? {
        let url = backgroundURL(for: layoutID, dark: dark)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func deleteBackground(layoutID: UUID, dark: Bool) {
        try? FileManager.default.removeItem(at: backgroundURL(for: layoutID, dark: dark))
    }

    func deleteBackgrounds(layoutID: UUID) {
        deleteBackground(layoutID: layoutID, dark: false)
        deleteBackground(layoutID: layoutID, dark: true)
    }

    func copyBackgrounds(from source: UUID, to destination: UUID) {
        let fm = FileManager.default
        for dark in [false, true] {
            let src = backgroundURL(for: source, dark: dark)
            let dst = backgroundURL(for: destination, dark: dark)
            if fm.fileExists(atPath: src.path) {
                try? fm.removeItem(at: dst)
                try? fm.copyItem(at: src, to: dst)
            }
        }
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

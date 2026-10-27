import Foundation
import ImageIO
import UIKit

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
        for dir in [rootURL, fontsURL, spotsURL, darkSpotsURL] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: Locations

    var lookURL: URL { rootURL.appendingPathComponent("look.json") }
    var clockURL: URL { rootURL.appendingPathComponent("clock.json") }
    var fontsIndexURL: URL { rootURL.appendingPathComponent("fonts.json") }
    var fontsURL: URL { rootURL.appendingPathComponent("Fonts", isDirectory: true) }

    // MARK: Widget background

    var backgroundImageURL: URL { rootURL.appendingPathComponent("background.png") }

    func saveBackgroundImage(_ data: Data) {
        try? data.write(to: backgroundImageURL, options: .atomic)
    }

    /// The photo, at most 1200 px on its long side. A full-size camera photo decodes to
    /// tens of megabytes, more than a widget extension may use, and the widget then
    /// renders blank.
    func loadBackgroundImage() -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1200,
        ]
        guard let source = CGImageSourceCreateWithURL(backgroundImageURL as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    // MARK: Photo blocks

    var blockPhotosURL: URL { rootURL.appendingPathComponent("BlockPhotos", isDirectory: true) }

    func blockPhotoURL(_ id: UUID) -> URL {
        blockPhotosURL.appendingPathComponent("\(id.uuidString).jpg")
    }

    /// Saves a Photo block's picture at most 420 px on its long side: WidgetKit refuses
    /// an image larger than the widget, and a small widget is about 470 px square.
    @discardableResult
    func saveBlockPhoto(_ data: Data, for id: UUID) -> Bool {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 420,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.85) else { return false }
        try? FileManager.default.createDirectory(at: blockPhotosURL, withIntermediateDirectories: true)
        return (try? jpeg.write(to: blockPhotoURL(id), options: .atomic)) != nil
    }

    func loadBlockPhoto(_ id: UUID) -> UIImage? {
        UIImage(contentsOfFile: blockPhotoURL(id).path)
    }

    // MARK: Wallpaper pieces (one per Home Screen slot, public API only)

    var seeThroughURL: URL { rootURL.appendingPathComponent("see-through.json") }
    var wallpaperURL: URL { rootURL.appendingPathComponent("wallpaper.png") }
    var spotsURL: URL { rootURL.appendingPathComponent("Spots", isDirectory: true) }
    var sizesURL: URL { rootURL.appendingPathComponent("widget-sizes.json") }

    func spotImageURL(key: Int) -> URL { spotsURL.appendingPathComponent("\(key).png") }

    func loadSeeThrough() -> SeeThroughState {
        read(SeeThroughState.self, from: seeThroughURL) ?? SeeThroughState()
    }

    func saveSeeThrough(_ state: SeeThroughState) {
        write(state, to: seeThroughURL)
    }

    func saveWallpaper(_ data: Data) {
        try? data.write(to: wallpaperURL, options: .atomic)
    }

    func loadWallpaper() -> Data? {
        try? Data(contentsOf: wallpaperURL)
    }

    func saveSpotImage(_ png: Data, key: Int) {
        try? png.write(to: spotImageURL(key: key), options: .atomic)
    }

    func removeSpotImages() {
        removeFiles(in: spotsURL)
    }

    /// The wallpaper piece for a slot (`HomeSlot.key`). nil means no piece yet, which
    /// the widget renders as the system background.
    func spotImage(key: Int) -> UIImage? {
        UIImage(contentsOfFile: spotImageURL(key: key).path)
    }

    // The same Home Screen page in Dark Mode: its own screenshot and pieces, cut at the
    // same spots. The widget falls back to the bright piece when there is no dark one.

    var darkWallpaperURL: URL { rootURL.appendingPathComponent("wallpaper-dark.png") }
    var darkSpotsURL: URL { rootURL.appendingPathComponent("SpotsDark", isDirectory: true) }

    func darkSpotImageURL(key: Int) -> URL { darkSpotsURL.appendingPathComponent("\(key).png") }

    func saveDarkWallpaper(_ data: Data) {
        try? data.write(to: darkWallpaperURL, options: .atomic)
    }

    func loadDarkWallpaper() -> Data? {
        try? Data(contentsOf: darkWallpaperURL)
    }

    func saveDarkSpotImage(_ png: Data, key: Int) {
        try? png.write(to: darkSpotImageURL(key: key), options: .atomic)
    }

    func removeDarkSpotImages() {
        removeFiles(in: darkSpotsURL)
    }

    /// The Dark Mode piece for a slot; nil falls back to the bright one.
    func darkSpotImage(key: Int) -> UIImage? {
        UIImage(contentsOfFile: darkSpotImageURL(key: key).path)
    }

    private func removeFiles(in directory: URL) {
        let fm = FileManager.default
        for url in (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [] {
            try? fm.removeItem(at: url)
        }
    }

    /// Real on-screen widget sizes in points, reported by the widget.
    func loadSizes() -> [SpotFamily: CGSize] {
        let raw = read([String: [Double]].self, from: sizesURL) ?? [:]
        var sizes: [SpotFamily: CGSize] = [:]
        for (name, value) in raw where value.count == 2 {
            if let index = Int(name), let family = SpotFamily(rawValue: index) {
                sizes[family] = CGSize(width: value[0], height: value[1])
            }
        }
        return sizes
    }

    func recordSize(_ size: CGSize, for family: SpotFamily) {
        guard size.width > 10, size.height > 10 else { return }
        var raw = read([String: [Double]].self, from: sizesURL) ?? [:]
        let value = [Double(size.width), Double(size.height)]
        guard raw["\(family.rawValue)"] != value else { return }
        raw["\(family.rawValue)"] = value
        write(raw, to: sizesURL)
    }

    /// What the widget's view probe saw; written by the extension, read here.
    var viewLogURL: URL { rootURL.appendingPathComponent("view.log") }

    func loadViewLog() -> String {
        (try? String(contentsOf: viewLogURL, encoding: .utf8)) ?? "Nothing yet. Add the widget, then come back."
    }

    func clearViewLog() {
        try? FileManager.default.removeItem(at: viewLogURL)
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

    // MARK: Look and clock (set in the app, read by the widget)

    func loadLook() -> Look {
        read(Look.self, from: lookURL) ?? Look()
    }

    func saveLook(_ look: Look) {
        write(look, to: lookURL)
    }

    func loadClock() -> ClockOption {
        read(ClockOption.self, from: clockURL) ?? .off
    }

    func saveClock(_ clock: ClockOption) {
        write(clock, to: clockURL)
    }

    // MARK: Designs (built in the app, picked per widget in Edit Widget)

    var designsURL: URL { rootURL.appendingPathComponent("designs.json") }

    func loadDesigns() -> [WidgetDesign] {
        read([WidgetDesign].self, from: designsURL) ?? []
    }

    func saveDesigns(_ designs: [WidgetDesign]) {
        write(designs, to: designsURL)
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

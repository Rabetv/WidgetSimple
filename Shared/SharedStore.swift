import Foundation
import ImageIO
import SwiftUI
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
    /// Guards the in-memory caches that keep the widget from rewriting files it already wrote.
    private let cacheLock = NSLock()
    private var recordedGeometry: [SpotFamily: [Double]] = [:]
    private var recordedWidgets: [UInt32: WidgetRecord] = [:]

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
        for dir in [rootURL, fontsURL, spotsURL, layoutsURL, photosURL] {
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

    func loadBackgroundImage() -> UIImage? {
        UIImage(contentsOfFile: backgroundImageURL.path)
    }

    // MARK: Matched wallpaper (public API only)

    var seeThroughURL: URL { rootURL.appendingPathComponent("see-through.json") }
    var wallpaperURL: URL { rootURL.appendingPathComponent("wallpaper.png") }
    var spotsURL: URL { rootURL.appendingPathComponent("Spots", isDirectory: true) }
    var sizesURL: URL { rootURL.appendingPathComponent("widget-sizes.json") }

    func spotImageURL(key: UInt32, generation: String) -> URL {
        spotsURL.appendingPathComponent(generation, isDirectory: true).appendingPathComponent("\(key).png")
    }

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

    /// Writes a complete set of pieces into a new generation folder and returns its
    /// name. Nothing reads the folder until the state points at it.
    func writeSpotGeneration(_ pieces: [UInt32: Data]) -> String? {
        let generation = UUID().uuidString
        let folder = spotsURL.appendingPathComponent(generation, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for (key, png) in pieces {
                try png.write(to: folder.appendingPathComponent("\(key).png"), options: .atomic)
            }
            return generation
        } catch {
            try? FileManager.default.removeItem(at: folder)
            return nil
        }
    }

    /// Deletes every generation except `keep`, and the flat pieces of builds 35–39.
    /// The previous generation is kept on purpose: a widget that read the old state a
    /// moment ago can still load its piece.
    func pruneSpotGenerations(keeping keep: Set<String>) {
        let fm = FileManager.default
        for url in (try? fm.contentsOfDirectory(at: spotsURL, includingPropertiesForKeys: nil)) ?? [] {
            if keep.contains(url.lastPathComponent) { continue }
            try? fm.removeItem(at: url)
        }
    }

    /// The wallpaper piece for one widget, by its exact key. No match means nil, and
    /// the widget draws no piece: it never borrows another widget's crop (that was how
    /// the wallpaper appeared in widgets that should have been plain).
    func spotImage(key: UInt32, state: SeeThroughState) -> UIImage? {
        guard let generation = state.generation,
              state.spots.contains(where: { $0.key == key }),
              !state.duplicateKeys.contains(key) else { return nil }
        return UIImage(contentsOfFile: spotImageURL(key: key, generation: generation).path)
    }

    /// A piece cut by builds 35–39 (flat in Spots/, 16-bit content key). Exact match only,
    /// and only until this version's first scan replaces them.
    func legacySpotImage(key: Int, state: SeeThroughState) -> UIImage? {
        guard state.generation == nil else { return nil }
        return UIImage(contentsOfFile: spotsURL.appendingPathComponent("\(key).png").path)
    }

    /// Any piece of this size, for the in-app preview only (never for a widget).
    func previewSpotImage(family: SpotFamily) -> UIImage? {
        let state = loadSeeThrough()
        guard let generation = state.generation,
              let spot = state.spots.last(where: { SpotKey.family(of: $0.key) == family }) else { return nil }
        return UIImage(contentsOfFile: spotImageURL(key: spot.key, generation: generation).path)
    }

    // MARK: Widget geometry (reported by the widget, used by the scan and the preview)

    /// Real on-screen widget sizes and content margins in points, as the widget saw them.
    func loadGeometry() -> [SpotFamily: FaceGeometry] {
        let raw = read([String: [Double]].self, from: sizesURL) ?? [:]
        var result: [SpotFamily: FaceGeometry] = [:]
        for (name, value) in raw where value.count >= 2 {
            guard let index = Int(name), let family = SpotFamily(rawValue: index) else { continue }
            var geometry = FaceGeometry(size: CGSize(width: value[0], height: value[1]), margins: nil)
            if value.count >= 6 {
                geometry.margins = EdgeInsets(top: value[2], leading: value[3], bottom: value[4], trailing: value[5])
            }
            result[family] = geometry
        }
        return result
    }

    func loadSizes() -> [SpotFamily: CGSize] {
        loadGeometry().mapValues(\.size)
    }

    /// Called from every timeline request. Writes only when the value changed since
    /// this process last wrote it, so a reload doesn't touch the disk.
    func recordSize(_ size: CGSize, for family: SpotFamily) {
        guard size.width > 10, size.height > 10 else { return }
        updateGeometry(for: family) { value in
            value[0] = Double(size.width)
            value[1] = Double(size.height)
        }
    }

    /// Called from the widget view: the content margins iOS gives this family, so the
    /// in-app preview uses the same insets instead of assuming 16 pt.
    func recordMargins(_ margins: EdgeInsets, for family: SpotFamily) {
        guard margins.top + margins.leading + margins.bottom + margins.trailing > 0 else { return }
        updateGeometry(for: family) { value in
            value[2] = Double(margins.top)
            value[3] = Double(margins.leading)
            value[4] = Double(margins.bottom)
            value[5] = Double(margins.trailing)
        }
    }

    private func updateGeometry(for family: SpotFamily, _ edit: (inout [Double]) -> Void) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        let id = "\(family.rawValue)"
        // The cache answers repeat calls without reading the file (it was read and
        // rewritten on every timeline request before).
        var value = recordedGeometry[family] ?? read([String: [Double]].self, from: sizesURL)?[id] ?? []
        if value.count < 6 { value += [Double](repeating: 0, count: 6 - value.count) }
        let before = value
        edit(&value)
        if value == before, recordedGeometry[family] != nil { return }
        recordedGeometry[family] = value
        var raw = read([String: [Double]].self, from: sizesURL) ?? [:]
        guard raw[id] != value else { return }
        raw[id] = value
        write(raw, to: sizesURL)
    }

    // MARK: Widget registry (what each widget showed last; the app can't read Edit Widget)

    var widgetsURL: URL { rootURL.appendingPathComponent("widgets.json") }

    func loadWidgetRecords() -> [WidgetRecord] {
        let raw = read([String: WidgetRecord].self, from: widgetsURL) ?? [:]
        return raw.values.sorted { $0.seen > $1.seen }
    }

    /// Notes a widget's key, kind, size and names. Rewrites the file only when something
    /// changed, or once a day to keep `seen` meaningful.
    func recordWidget(_ record: WidgetRecord) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = recordedWidgets[record.key], cached.sameContent(as: record),
           record.seen.timeIntervalSince(cached.seen) < 86_400 { return }
        var raw = read([String: WidgetRecord].self, from: widgetsURL) ?? [:]
        let id = "\(record.key)"
        if let old = raw[id], old.sameContent(as: record), record.seen.timeIntervalSince(old.seen) < 86_400 {
            recordedWidgets[record.key] = old
            return
        }
        raw[id] = record
        // Widgets removed from the Home Screen stop reporting; forget them after 60 days.
        raw = raw.filter { record.seen.timeIntervalSince($0.value.seen) < 60 * 86_400 }
        write(raw, to: widgetsURL)
        recordedWidgets[record.key] = record
    }

    // MARK: Layouts (made in the app's layout editor, picked per widget in Edit Widget)

    var layoutsURL: URL { rootURL.appendingPathComponent("Layouts", isDirectory: true) }

    func layoutThumbnailURL(id: String) -> URL { layoutsURL.appendingPathComponent("\(id).png") }

    func loadLayouts() -> [LayoutDocument] {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: layoutsURL, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { read(LayoutDocument.self, from: $0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func loadLayout(id: String) -> LayoutDocument? {
        guard UUID(uuidString: id) != nil else { return nil }
        return read(LayoutDocument.self, from: layoutsURL.appendingPathComponent("\(id).json"))
    }

    func saveLayout(_ layout: LayoutDocument, thumbnail: Data?) {
        write(layout, to: layoutsURL.appendingPathComponent("\(layout.id).json"))
        if let thumbnail {
            try? thumbnail.write(to: layoutThumbnailURL(id: layout.id), options: .atomic)
        }
    }

    func deleteLayout(id: String) {
        guard UUID(uuidString: id) != nil else { return }
        try? FileManager.default.removeItem(at: layoutsURL.appendingPathComponent("\(id).json"))
        try? FileManager.default.removeItem(at: layoutThumbnailURL(id: id))
    }

    // MARK: Photos (stock library copied in by the app, plus the person's own)

    var photosURL: URL { rootURL.appendingPathComponent("Photos", isDirectory: true) }
    var photosIndexURL: URL { rootURL.appendingPathComponent("photos.json") }

    func loadPhotos() -> [PhotoAsset] {
        read([PhotoAsset].self, from: photosIndexURL) ?? []
    }

    func savePhotos(_ photos: [PhotoAsset]) {
        write(photos, to: photosIndexURL)
    }

    func photoURL(_ photo: PhotoAsset) -> URL {
        photosURL.appendingPathComponent(photo.file)
    }

    /// The photo downsampled to at most `maxPixel` on the long edge: a widget has a
    /// tight memory limit, and a large widget needs about 1200 px at 3×.
    func loadPhotoImage(_ photo: PhotoAsset, maxPixel: CGFloat = 1400) -> UIImage? {
        ImageDownsampler.image(at: photoURL(photo), maxPixel: maxPixel)
    }

    // MARK: Diagnostics

    /// What the widget logged; written by the extension, read in TestFlight builds.
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

/// A widget's size and content margins in points.
struct FaceGeometry: Equatable {
    var size: CGSize
    /// nil until the widget has reported them.
    var margins: EdgeInsets?
}

/// One widget as it last rendered: lets the app name widgets it can't otherwise see.
struct WidgetRecord: Codable, Hashable {
    var key: UInt32
    var kind: String
    var family: Int
    var names: [String]
    var seen: Date

    func sameContent(as other: WidgetRecord) -> Bool {
        key == other.key && kind == other.kind && family == other.family && names == other.names
    }
}

/// Decodes an image file at a bounded size (ImageIO thumbnails never decode the full image).
enum ImageDownsampler {
    static func image(at url: URL, maxPixel: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else { return nil }
        let thumbOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions) else { return nil }
        return UIImage(cgImage: image)
    }
}

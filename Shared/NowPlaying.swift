import Foundation
import SwiftUI
import UIKit
import WidgetKit

/// The song the Music app was playing when the app last looked, kept in the App Group for
/// the widget: title and artist in `now-playing.json`, a 300 px cover in `now-playing.png`.
/// The app writes it while it is open (`NowPlayingMonitor`); the widget only reads it.
struct NowPlayingRecord: Codable, Equatable {
    /// Tells songs apart: the library's persistent ID with the title and artist.
    var key: String
    var title: String
    var artist: String
    var savedAt: Date
}

enum NowPlayingStore {
    static var recordURL: URL { SharedStore.shared.rootURL.appendingPathComponent("now-playing.json") }
    static var coverURL: URL { SharedStore.shared.rootURL.appendingPathComponent("now-playing.png") }
    /// The saved cover's side, in pixels.
    static let coverPixels: CGFloat = 300

    static func load() -> NowPlayingRecord? {
        guard let data = try? Data(contentsOf: recordURL) else { return nil }
        return try? JSONDecoder().decode(NowPlayingRecord.self, from: data)
    }

    static func loadCover() -> UIImage? {
        UIImage(contentsOfFile: coverURL.path)
    }

    /// Saves the song for the widget and reloads its timelines. When that song is already
    /// saved, with or without a cover as now, it writes nothing and reloads nothing.
    static func save(key: String, title: String, artist: String, cover: UIImage?) {
        let fm = FileManager.default
        if load()?.key == key, (cover != nil) == fm.fileExists(atPath: coverURL.path) { return }
        if let png = cover.flatMap(squarePNG) {
            try? png.write(to: coverURL, options: .atomic)
        } else {
            try? fm.removeItem(at: coverURL)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let record = NowPlayingRecord(key: key, title: title, artist: artist, savedAt: .now)
        if let data = try? encoder.encode(record) {
            try? data.write(to: recordURL, options: .atomic)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Forgets the song when nothing plays or Music access is off; a no-op when none is saved.
    static func clear() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: recordURL.path) || fm.fileExists(atPath: coverURL.path) else { return }
        try? fm.removeItem(at: recordURL)
        try? fm.removeItem(at: coverURL)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// The cover cropped square from its middle and drawn at `coverPixels`, as PNG.
    private static func squarePNG(_ image: UIImage) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let side = coverPixels
        let fill = max(side / size.width, side / size.height)
        let drawn = CGSize(width: size.width * fill, height: size.height * fill)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        return renderer.pngData { _ in
            image.draw(in: CGRect(x: (side - drawn.width) / 2, y: (side - drawn.height) / 2,
                                  width: drawn.width, height: drawn.height))
        }
    }
}

/// The saved cover as a circle filling its frame, or nothing when no cover is saved. Safe
/// in the widget: it only reads the PNG the app wrote, so it shows the song the Music app
/// was playing when the app was last open.
struct NowPlayingArt: View {
    var body: some View {
        if let cover = NowPlayingStore.loadCover() {
            Image(uiImage: cover)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipShape(Circle())
                .accessibilityHidden(true)
        }
    }
}

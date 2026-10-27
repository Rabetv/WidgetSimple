import AppIntents
import Foundation
import MediaPlayer
import SwiftUI
import UIKit
import WidgetKit

/// The song the Music app is playing, kept in the App Group for the widget: title and
/// artist in `now-playing.json`, a 300 px cover in `now-playing.png`. The app writes it
/// while it is open (`NowPlayingMonitor`); the widget refreshes it on every timeline and
/// after each tap on its music keys (`MusicControlIntent`).
///
/// Only the Music app (Apple Music and the music library) reports its song and takes
/// these commands. Spotify and other players don't tell other apps what they play.
struct NowPlayingRecord: Codable, Equatable {
    /// Tells songs apart: the library's persistent ID with the title and artist.
    var key: String
    var title: String
    var artist: String
    var savedAt: Date
    /// Whether Music was playing when this was read; nil in records from older builds.
    var playing: Bool?
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
    static func save(key: String, title: String, artist: String, cover: UIImage?, playing: Bool? = nil,
                     reload: Bool = true) {
        let fm = FileManager.default
        if let saved = load(), saved.key == key, saved.playing == playing,
           (cover != nil) == fm.fileExists(atPath: coverURL.path) { return }
        if let png = cover.flatMap(squarePNG) {
            try? png.write(to: coverURL, options: .atomic)
        } else {
            try? fm.removeItem(at: coverURL)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let record = NowPlayingRecord(key: key, title: title, artist: artist, savedAt: .now, playing: playing)
        if let data = try? encoder.encode(record) {
            try? data.write(to: recordURL, options: .atomic)
        }
        if reload { WidgetCenter.shared.reloadAllTimelines() }
    }

    /// Reads what the Music app is playing right now and saves it. Needs Media & Apple
    /// Music access, given in the app; without it nothing changes. `reload` is false
    /// inside a widget timeline, which is already being made.
    @MainActor
    static func refreshFromMusic(reload: Bool = true) {
        guard MPMediaLibrary.authorizationStatus() == .authorized else { return }
        let player = MPMusicPlayerController.systemMusicPlayer
        guard let item = player.nowPlayingItem else {
            clear(reload: reload)
            return
        }
        let title = item.title ?? "Untitled"
        let artist = item.artist ?? item.albumArtist ?? "Unknown artist"
        save(key: "\(item.persistentID)|\(title)|\(artist)", title: title, artist: artist,
             cover: item.artwork?.image(at: CGSize(width: coverPixels, height: coverPixels)),
             playing: player.playbackState == .playing, reload: reload)
    }

    /// Forgets the song when nothing plays or Music access is off; a no-op when none is saved.
    static func clear(reload: Bool = true) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: recordURL.path) || fm.fileExists(atPath: coverURL.path) else { return }
        try? fm.removeItem(at: recordURL)
        try? fm.removeItem(at: coverURL)
        if reload { WidgetCenter.shared.reloadAllTimelines() }
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
                .widgetAccentedRenderingMode(.accentedDesaturated)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipShape(Circle())
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Music keys

/// The three keys of the Music block.
enum MusicAction: String, AppEnum {
    case previous, playPause, next

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Music action"
    static let caseDisplayRepresentations: [MusicAction: DisplayRepresentation] = [
        .previous: "Previous", .playPause: "Play or pause", .next: "Next",
    ]
}

/// A key on the Music block: previous, play or pause, next, sent to the Music app. The
/// widget redraws after the tap with the song that is playing then.
struct MusicControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Control Music"
    static let isDiscoverable = false

    @Parameter(title: "Action") var action: MusicAction

    init() {}

    init(_ action: MusicAction) {
        self.action = action
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            let player = MPMusicPlayerController.systemMusicPlayer
            switch action {
            case .previous: player.skipToPreviousItem()
            case .playPause: player.playbackState == .playing ? player.pause() : player.play()
            case .next: player.skipToNextItem()
            }
        }
        // Music needs a moment to switch songs before it reports the new one.
        try? await Task.sleep(for: .milliseconds(400))
        await NowPlayingStore.refreshFromMusic()
        return .result()
    }
}

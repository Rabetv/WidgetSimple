import SwiftUI
import UIKit
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published var look: Look {
        didSet {
            store.saveLook(look)
            scheduleReload()
        }
    }
    @Published var clock: ClockOption {
        didSet {
            store.saveClock(clock)
            scheduleReload()
        }
    }
    /// The matched-wallpaper state: which widget sits where, and the pieces cut for it.
    @Published private(set) var seeThrough: SeeThroughState {
        didSet { store.saveSeeThrough(seeThrough) }
    }
    /// Shown as an alert wherever the editor is on screen.
    @Published var message: String?
    @Published private(set) var working = false
    @Published private(set) var layouts: [LayoutDocument] = []
    @Published private(set) var photos: [PhotoAsset] = []

    let store = SharedStore.shared
    private var reloadTask: Task<Void, Never>?

    init() {
        FontRegistry.registerAllOnce()
        look = store.loadLook()
        clock = store.loadClock()
        seeThrough = store.loadSeeThrough()
        FaceMetrics.screenWidth = Self.screenPointsWide
        layouts = store.loadLayouts()
        photos = StockLibrary.seed(into: store)
        // A launcher without a clock asks never to be reloaded, so an update would leave
        // the old snapshot on the Home Screen until something else touched it.
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Reloads

    /// Coalesces reloads while a slider moves: widgets reload 300 ms after the last change,
    /// not on every tick (WidgetKit budgets reloads).
    func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// For changes the person is waiting to see on the Home Screen (pink on, pink off).
    private func reloadNow() {
        reloadTask?.cancel()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Background

    func setBackground(_ option: WidgetBackground) {
        look.background = option
    }

    func useBackgroundPhoto(_ data: Data) {
        store.saveBackgroundImage(data)
        look.background = .photo
    }

    /// A word colour taken from the wallpaper: its average, pushed far enough toward
    /// white or black to stay readable on it.
    func matchWordColorToWallpaper() {
        guard let data = store.loadWallpaper(), let image = UIImage(data: data)?.cgImage,
              let average = SeeThroughMaker.averageColor(of: image) else {
            message = String(localized: "Add a wallpaper screenshot first (See-through › step 1).")
            return
        }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        average.getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let target: CGFloat = luminance < 0.5 ? 1 : 0
        let mix: CGFloat = luminance < 0.5 ? 0.72 : 0.68
        func blend(_ c: CGFloat) -> Int { Int(((c + (target - c) * mix) * 255).rounded()) }
        look.customHex = String(format: "#%02X%02X%02X", blend(r), blend(g), blend(b))
        look.tone = .custom
    }

    // MARK: Matched wallpaper

    /// Pixel width of a full-screen portrait screenshot on this iPhone.
    private static var screenshotPixelsWide: CGFloat {
        let screen = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen }.first
        guard let native = screen?.nativeBounds else { return 0 }
        return min(native.width, native.height)
    }

    private static var screenPointsWide: CGFloat {
        let screen = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen }.first
        return screen.map { min($0.bounds.width, $0.bounds.height) } ?? 393
    }

    /// Why a screenshot can't be used, or nil when it can.
    private func problem(with image: CGImage) -> String? {
        if image.width > image.height {
            return String(localized: "That screenshot is in landscape. Take it with the iPhone upright.")
        }
        let expected = Self.screenshotPixelsWide
        if expected > 0, abs(CGFloat(image.width) - expected) > 0.5 {
            return String(localized: "That screenshot isn't from this iPhone's screen (\(image.width) px wide, expected \(Int(expected)) px). Take both screenshots on this iPhone.")
        }
        return nil
    }

    /// Step 1: a screenshot of an empty Home Screen page (the wallpaper).
    func useWallpaper(_ data: Data) async {
        guard let image = UIImage(data: data)?.cgImage else {
            message = String(localized: "Couldn't read that screenshot.")
            return
        }
        if let problem = problem(with: image) {
            message = problem
            return
        }
        store.saveWallpaper(data)
        var state = seeThrough
        state.hasWallpaper = true
        guard !state.spots.isEmpty else {
            state.spotsWidth = Double(image.width)
            state.spotsHeight = Double(image.height)
            seeThrough = state
            return
        }
        seeThrough = state
        // The frames came from pink screenshots of one size; a wallpaper of another
        // size can't be cut with them.
        guard Double(image.width) == state.spotsWidth, Double(image.height) == state.spotsHeight else {
            message = String(localized: "This wallpaper screenshot has a different size from the pink one. Match the widgets again.")
            return
        }
        // A new wallpaper re-cuts every known spot; the frames are still right.
        await commit(state)
    }

    /// Step 2: every widget shows a pink code so the app can find it.
    func startFinding() {
        seeThrough.finding = true
        reloadNow()
    }

    func stopFinding() {
        seeThrough.finding = false
        reloadNow()
    }

    /// Forgets every match: all widgets go back to the system background.
    func startOver() {
        var state = seeThrough
        state.spots = []
        state.unreadCount = 0
        state.duplicateKeys = []
        state.finding = false
        state.generation = UUID().uuidString // an empty generation: nothing matches
        seeThrough = state
        store.pruneSpotGenerations(keeping: [])
        reloadNow()
    }

    /// Step 3: one screenshot of each Home Screen page while the widgets are pink.
    func usePinkScreenshots(_ items: [Data]) async {
        let images = items.compactMap { UIImage(data: $0)?.cgImage }
        guard !images.isEmpty else {
            message = String(localized: "Couldn't read that screenshot.")
            return
        }
        for image in images {
            if let problem = problem(with: image) {
                message = problem
                return
            }
            if seeThrough.hasWallpaper, seeThrough.spotsWidth > 0,
               Double(image.width) != seeThrough.spotsWidth || Double(image.height) != seeThrough.spotsHeight {
                message = String(localized: "The pink screenshot and the wallpaper screenshot have different sizes. Take both on this iPhone, held upright, with the same Display Zoom.")
                return
            }
        }

        working = true
        defer { working = false }
        let sizes = store.loadSizes()
        let pixelsPerPoint = CGFloat(images[0].width) / max(Self.screenPointsWide, 1)
        let results = await Task.detached(priority: .userInitiated) {
            images.map { SeeThroughMaker.scan($0, sizes: sizes, pixelsPerPoint: pixelsPerPoint) }
        }.value

        let mismatches = results.flatMap(\.mismatches)
        if let first = mismatches.first {
            // Measured and reported sizes disagree beyond the rim: the scale is wrong
            // (Display Zoom changed, a scaled image). Cutting anyway would leave seams.
            message = String(localized: "A widget measured \(Int(first.found.width))×\(Int(first.found.height)) px but should be \(Int(first.expected.width))×\(Int(first.expected.height)) px. Nothing was changed. Check Display Zoom is the same as when the widget was added, then try again.")
            return
        }

        // Merge every page. The same key on two pages is two widgets with one ID; the
        // same key at the same place twice is the same page picked twice.
        var found: [UInt32: Spot] = [:]
        var duplicates = Set(results.flatMap(\.duplicates))
        for spot in results.flatMap(\.spots) {
            if let earlier = found[spot.key], earlier.rect.insetBy(dx: -4, dy: -4).contains(spot.rect) == false {
                duplicates.insert(spot.key)
            }
            found[spot.key] = spot
        }
        for key in duplicates { found[key] = nil }
        let unread = results.reduce(0) { $0 + $1.unread.count }

        guard !found.isEmpty || unread > 0 || !duplicates.isEmpty else {
            message = String(localized: "No pink widgets in that screenshot. Take it on the Home Screen while the widgets are pink.")
            return
        }

        // Widgets matched earlier on pages not in this scan keep their spot, but only
        // identity keys: a content key from an older build may belong to nobody now.
        var state = seeThrough
        let kept = state.spots.filter { SpotKey.isIdentity($0.key) && found[$0.key] == nil && !duplicates.contains($0.key) }
        state.spots = kept + found.values.sorted { ($0.y, $0.x) < ($1.y, $1.x) }
        state.spotsWidth = Double(images[0].width)
        state.spotsHeight = Double(images[0].height)
        state.pixelsPerPoint = Double(pixelsPerPoint)
        state.unreadCount = unread
        state.duplicateKeys = Array(duplicates)
        state.finding = false
        await commit(state)

        if unread > 0 {
            message = String(localized: "Found \(unread) widget(s) but couldn't read their ID. Rescan with nothing covering the pink squares.")
        } else if !duplicates.isEmpty {
            message = String(localized: "\(duplicates.count) pair(s) of widgets share an ID and were left plain. In Edit Widget, set See-through ID to a new one on one of them, then rescan.")
        }
    }

    /// Cuts every piece into a new folder, then points the state at it in one write.
    /// A widget reading in between sees the complete old set or the complete new one.
    private func commit(_ newState: SeeThroughState) async {
        var state = newState
        guard state.hasWallpaper, let data = store.loadWallpaper(),
              let wallpaper = UIImage(data: data)?.cgImage else {
            // No wallpaper yet: remember the frames, cut once it arrives.
            seeThrough = state
            reloadNow()
            if !state.spots.isEmpty {
                message = String(localized: "Widgets found. Now add the wallpaper screenshot (step 1) to finish.")
            }
            return
        }
        guard Double(wallpaper.width) == state.spotsWidth, Double(wallpaper.height) == state.spotsHeight else {
            message = String(localized: "The two screenshots have different sizes. Take both on this iPhone, held upright.")
            return
        }
        working = true
        defer { working = false }
        let store = self.store
        let spots = state.spots
        let generation = await Task.detached(priority: .userInitiated) { () -> String? in
            var pieces: [UInt32: Data] = [:]
            for spot in spots {
                if let png = SeeThroughMaker.crop(wallpaper, to: spot.rect) {
                    pieces[spot.key] = png
                }
            }
            return store.writeSpotGeneration(pieces)
        }.value
        guard let generation else {
            message = String(localized: "Couldn't save the wallpaper pieces. Free some storage and try again.")
            return
        }
        let previous = seeThrough.generation
        state.generation = generation
        seeThrough = state
        store.pruneSpotGenerations(keeping: Set([generation, previous].compactMap { $0 }))
        reloadNow()
    }

    // MARK: Layouts

    func saveLayout(_ layout: LayoutDocument) {
        let thumbnail = LayoutThumbnail.render(layout, look: look, clock: clock)
        store.saveLayout(layout, thumbnail: thumbnail)
        layouts = store.loadLayouts()
        scheduleReload()
    }

    func deleteLayout(_ layout: LayoutDocument) {
        store.deleteLayout(id: layout.id)
        layouts = store.loadLayouts()
        scheduleReload()
    }

    /// Names to preview a layout with: the apps a widget last showed, else samples.
    func sampleNames(for family: SpotFamily) -> [String] {
        let records = store.loadWidgetRecords()
        let launcher = records.first { $0.kind == "WidgetSimpleDirect" && $0.family == family.rawValue && !$0.names.isEmpty }
            ?? records.first { $0.kind == "WidgetSimpleDirect" && !$0.names.isEmpty }
        return launcher?.names ?? ["Phone", "Messages", "Camera", "Music", "Maps", "Notes"]
    }

    // MARK: Photos

    func importPhoto(_ data: Data) {
        guard let photo = StockLibrary.importPhoto(data, into: store) else {
            message = String(localized: "Couldn't read that photo.")
            return
        }
        photos.append(photo)
        store.savePhotos(photos)
        scheduleReload()
    }

    func deletePhoto(_ photo: PhotoAsset) {
        guard !photo.isStock else { return }
        try? FileManager.default.removeItem(at: store.photoURL(photo))
        photos.removeAll { $0.id == photo.id }
        store.savePhotos(photos)
        scheduleReload()
    }
}

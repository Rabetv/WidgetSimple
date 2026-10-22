import SwiftUI
import UIKit
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published var look: Look {
        didSet {
            store.saveLook(look)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    @Published private(set) var seeThrough: SeeThroughState {
        didSet {
            store.saveSeeThrough(seeThrough)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    @Published var message: String?
    @Published private(set) var working = false

    let store = SharedStore.shared

    init() {
        FontRegistry.registerAllOnce()
        look = store.loadLook()
        seeThrough = store.loadSeeThrough()
    }

    // MARK: See-through

    /// Step 1: the screenshot of an empty Home Screen page.
    func useWallpaper(_ data: Data) async {
        guard UIImage(data: data)?.cgImage != nil else {
            message = "Couldn't read that screenshot."
            return
        }
        store.saveWallpaper(data)
        seeThrough.hasWallpaper = true
        seeThrough.wallpaperName = nil
        await makePieces()
    }

    /// Step 1, the other way: a wallpaper that ships with the app. The user sets it as
    /// their iPhone wallpaper, so no empty Home Screen screenshot is needed.
    func useCatalogWallpaper(_ wallpaper: CatalogWallpaper) async {
        // Match the pink screenshot's pixels when there is one, so its pieces line up.
        let screen = seeThrough.spotsWidth > 1 && seeThrough.spotsHeight > 1
            ? CGSize(width: seeThrough.spotsWidth, height: seeThrough.spotsHeight)
            : Self.screenPixelSize
        guard let image = wallpaper.wallpaper(fitting: screen), let data = image.pngData() else {
            message = "Couldn't read the \(wallpaper.name) wallpaper."
            return
        }
        store.saveWallpaper(data)
        seeThrough.hasWallpaper = true
        seeThrough.wallpaperName = wallpaper.id
        await makePieces()
    }

    /// Step 2: every widget turns pink and shows its code.
    func startFinding() {
        seeThrough.finding = true
    }

    func stopFinding() {
        seeThrough.finding = false
    }

    /// Step 2: the screenshot of the Home Screen with the pink widgets.
    func usePinkScreenshot(_ data: Data) async {
        guard let image = UIImage(data: data)?.cgImage else {
            message = "Couldn't read that screenshot."
            return
        }
        working = true
        defer { working = false }
        let sizes = store.loadSizes()
        let pointsWide = Self.screenPointsWide
        let spots = await Task.detached(priority: .userInitiated) {
            SeeThroughMaker.findSpots(in: image, sizes: sizes, pointsWide: pointsWide)
        }.value
        guard !spots.isEmpty else {
            message = "No pink widgets in that screenshot. Take it on the Home Screen while the widgets are pink."
            return
        }
        var state = seeThrough
        state.spots = spots
        state.spotsWidth = Double(image.width)
        state.spotsHeight = Double(image.height)
        state.finding = false
        seeThrough = state
        await makePieces()
    }

    /// Cuts the piece of wallpaper behind every widget found, and measures how dark it
    /// is so the words can switch between white and black on their own.
    private func makePieces() async {
        let state = seeThrough
        guard state.hasWallpaper, !state.spots.isEmpty,
              let data = store.loadWallpaper(), let stored = UIImage(data: data)?.cgImage else { return }
        // A bundled wallpaper is already screen sized; a screenshot from another iPhone
        // (or an older one) is not, so bring the wallpaper to the spots' pixels.
        guard let wallpaper = SeeThroughMaker.scaled(stored, to: CGSize(width: state.spotsWidth,
                                                                       height: state.spotsHeight)) else {
            message = "Couldn't read that wallpaper. Pick it again."
            return
        }
        working = true
        defer { working = false }
        let store = self.store
        let spots = state.spots
        let pieces = await Task.detached(priority: .userInitiated) { () -> [Spot] in
            store.removeSpotImages()
            var result: [Spot] = []
            for spot in spots {
                guard let png = SeeThroughMaker.crop(wallpaper, to: spot.rect) else { continue }
                store.saveSpotImage(png, key: spot.key)
                var piece = spot
                piece.isDark = SeeThroughMaker.isDark(wallpaper, in: spot.rect)
                result.append(piece)
            }
            return result
        }.value
        seeThrough.spots = pieces
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static var screenPointsWide: CGFloat {
        let screen = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen }
            .first
        return screen?.bounds.width ?? 393
    }

    /// The screen in pixels, the size a Home Screen screenshot has on this iPhone.
    private static var screenPixelSize: CGSize {
        let screen = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen }
            .first
        let points = screen?.bounds.size ?? CGSize(width: 393, height: 852)
        let scale = screen?.scale ?? 3
        return CGSize(width: (points.width * scale).rounded(), height: (points.height * scale).rounded())
    }
}

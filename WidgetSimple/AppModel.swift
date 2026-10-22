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
    /// The piece of wallpaper behind a medium widget, so the preview in the app shows
    /// the real thing instead of a sample gradient once step 2 is done.
    @Published private(set) var previewPiece: UIImage?

    let store = SharedStore.shared

    init() {
        FontRegistry.registerAllOnce()
        let state = store.loadSeeThrough()
        look = store.loadLook()
        seeThrough = state
        previewPiece = Self.previewPiece(for: state, in: store)
    }

    private static func previewPiece(for state: SeeThroughState, in store: SharedStore) -> UIImage? {
        let spot = state.spots.first { SpotKey.family(of: $0.key) == .medium } ?? state.spots.first
        guard let spot else { return nil }
        return UIImage(contentsOfFile: store.spotImageURL(key: spot.key).path)
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

    /// Cuts the piece of wallpaper behind every widget found.
    private func makePieces() async {
        let state = seeThrough
        guard state.hasWallpaper, !state.spots.isEmpty,
              let data = store.loadWallpaper(), let wallpaper = UIImage(data: data)?.cgImage else { return }
        guard Double(wallpaper.width) == state.spotsWidth, Double(wallpaper.height) == state.spotsHeight else {
            message = "The two screenshots have different sizes. Take both on this iPhone, held upright."
            return
        }
        working = true
        defer { working = false }
        let store = self.store
        await Task.detached(priority: .userInitiated) {
            store.removeSpotImages()
            for spot in state.spots {
                if let png = SeeThroughMaker.crop(wallpaper, to: spot.rect) {
                    store.saveSpotImage(png, key: spot.key)
                }
            }
        }.value
        previewPiece = Self.previewPiece(for: seeThrough, in: store)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static var screenPointsWide: CGFloat {
        let screen = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen }
            .first
        return screen?.bounds.width ?? 393
    }
}

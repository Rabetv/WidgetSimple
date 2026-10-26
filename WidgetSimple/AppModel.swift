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
    @Published var clock: ClockOption {
        didSet {
            store.saveClock(clock)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    /// The matched-wallpaper state: which widget sits where, and the pieces cut for it.
    /// Used by the App Store flavour only; the AltStore build removes the container
    /// instead and never needs a wallpaper.
    @Published private(set) var seeThrough: SeeThroughState {
        didSet {
            store.saveSeeThrough(seeThrough)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    /// The saved designs, in the order the app lists them. Edit Widget offers the same
    /// list as the Apps widget's Design.
    @Published var designs: [WidgetDesign] {
        didSet {
            guard designs != oldValue else { return }
            store.saveDesigns(designs)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    @Published var message: String?
    @Published private(set) var working = false

    let store = SharedStore.shared

    init() {
        FontRegistry.registerAllOnce()
        look = store.loadLook()
        clock = store.loadClock()
        seeThrough = store.loadSeeThrough()
        designs = store.loadDesigns()
        // A launcher without a clock asks never to be reloaded, so an update would leave
        // the old snapshot on the Home Screen until something else touched it.
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Designs

    /// A new design in the current look, named after its place in the list. Without
    /// blocks it starts with a clock, the battery and four Open App slots.
    @discardableResult
    func addDesign(blocks: [DesignBlock]? = nil) -> WidgetDesign {
        let taken = Set(designs.map(\.name))
        var number = designs.count + 1
        while taken.contains("Design \(number)") { number += 1 }
        var design = WidgetDesign.starter(name: "Design \(number)", look: look)
        if let blocks { design.blocks = blocks }
        designs.append(design)
        return design
    }

    /// Changes one design in place; nothing happens if it was deleted meanwhile.
    func update(_ id: UUID, _ change: (inout WidgetDesign) -> Void) {
        guard let index = designs.firstIndex(where: { $0.id == id }) else { return }
        change(&designs[index])
    }

    func deleteDesign(_ id: UUID) {
        designs.removeAll { $0.id == id }
    }

    // MARK: Background

    func setBackground(_ option: WidgetBackground) {
        look.background = option
    }

    func useBackgroundPhoto(_ data: Data) {
        store.saveBackgroundImage(data)
        look.background = .photo
    }

    // MARK: Matched wallpaper

    /// True once every widget looks right in both appearances: the bright and the dark
    /// wallpaper and the matched widgets — or the widgets show the user's photo instead.
    var isWallpaperReady: Bool {
        look.background == .photo || seeThrough.isComplete
    }

    /// Step 1: a screenshot of an empty Home Screen page (the wallpaper), in Light Mode.
    func useWallpaper(_ data: Data) async {
        guard UIImage(data: data)?.cgImage != nil else {
            message = "Couldn't read that screenshot."
            return
        }
        guard data != store.loadDarkWallpaper() else {
            message = "That's the Dark Mode screenshot. Switch the iPhone to Light Mode, take a new screenshot of the empty page, and pick that one."
            return
        }
        store.saveWallpaper(data)
        seeThrough.hasWallpaper = true
        await makePieces()
    }

    /// Step 1, again in Dark Mode: the same empty page, which iOS darkens or swaps.
    func useDarkWallpaper(_ data: Data) async {
        guard UIImage(data: data)?.cgImage != nil else {
            message = "Couldn't read that screenshot."
            return
        }
        guard data != store.loadWallpaper() else {
            message = "That's the Light Mode screenshot again. Switch the iPhone to Dark Mode, take a new screenshot of the empty page, and pick that one."
            return
        }
        store.saveDarkWallpaper(data)
        seeThrough.hasDarkWallpaper = true
        await makePieces()
    }

    /// Step 2: every widget shows a pink code so the app can find it.
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

    /// Cuts the wallpaper pieces behind every widget found, from the bright and the dark
    /// screenshot at the same spots. A widget without a piece simply keeps the system
    /// background, and one without a dark piece keeps its bright one in Dark Mode, so
    /// this can never make things worse.
    private func makePieces() async {
        let state = seeThrough
        guard !state.spots.isEmpty else { return }
        func fits(_ image: CGImage) -> Bool {
            Double(image.width) == state.spotsWidth && Double(image.height) == state.spotsHeight
        }
        var bright = state.hasWallpaper ? store.loadWallpaper().flatMap { UIImage(data: $0)?.cgImage } : nil
        var dark = state.hasDarkWallpaper ? store.loadDarkWallpaper().flatMap { UIImage(data: $0)?.cgImage } : nil
        if let image = bright, !fits(image) {
            bright = nil
            message = "The Light Mode screenshot and the pink one have different sizes. Take both on this iPhone, held upright."
        }
        var staleDark = false
        if let image = dark, !fits(image) {
            dark = nil
            staleDark = true
            message = "The Dark Mode screenshot and the pink one have different sizes. Take both on this iPhone, held upright."
        }
        guard bright != nil || dark != nil || staleDark else { return }
        working = true
        defer { working = false }
        let store = self.store
        await Task.detached(priority: .userInitiated) { [bright, dark, staleDark] in
            if let bright {
                store.removeSpotImages()
                for spot in state.spots {
                    if let png = SeeThroughMaker.crop(bright, to: spot.rect) {
                        store.saveSpotImage(png, key: spot.key)
                    }
                }
            }
            // Old dark pieces may sit where widgets no longer are: drop them, so Dark
            // Mode falls back to the bright piece instead of showing a wrong one.
            if dark != nil || staleDark { store.removeDarkSpotImages() }
            if let dark {
                for spot in state.spots {
                    if let png = SeeThroughMaker.crop(dark, to: spot.rect) {
                        store.saveDarkSpotImage(png, key: spot.key)
                    }
                }
            }
        }.value
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// The iPhone's charge, 0…1, for the battery module's previews; nil when unknown.
    static var batteryLevel: Double? {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        return level < 0 ? nil : Double(level)
    }

    private static var screenPointsWide: CGFloat {
        let screen = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen }
            .first
        return screen?.bounds.width ?? 393
    }
}

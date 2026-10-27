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
    /// The wallpaper state: which screenshots are in, the nudge, and what the pieces
    /// for every Home Screen slot were cut for.
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

    /// Cuts the pieces again when something they depend on changed since the last cut,
    /// such as a widget reporting its real size for the first time. Called on launch and
    /// whenever the app comes to the front.
    func refreshPiecesIfNeeded() async {
        guard seeThrough.hasWallpaper || seeThrough.hasDarkWallpaper else { return }
        guard seeThrough.cutSignature != cutSignature() else { return }
        await makePieces()
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

    // MARK: Wallpaper pieces

    /// True once every widget looks right in both appearances: the bright and the dark
    /// wallpaper screenshot are in — or the widgets show the user's photo instead.
    var isWallpaperReady: Bool {
        look.background == .photo || seeThrough.isComplete
    }

    /// True once both wallpaper screenshots (Light and Dark Mode) are in. Until then the
    /// App Store build keeps the app on the setup screen and every widget shows a
    /// setup prompt instead of its apps.
    var hasWallpaperShots: Bool {
        seeThrough.hasWallpaper && seeThrough.hasDarkWallpaper
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

    /// Moves every piece by `points` (down when positive) for an iPhone whose Home
    /// Screen grid sits a little differently from the table, and cuts them again.
    func nudgeWallpaper(by points: Double) async {
        seeThrough.offsetY = (seeThrough.offsetY + points).clamped(to: -40...40)
        await makePieces()
    }

    func resetWallpaperNudge() async {
        seeThrough.offsetY = 0
        await makePieces()
    }

    /// The real widget sizes, the nudge and the screenshots the pieces depend on.
    private func cutSignature() -> String {
        let sizes = store.loadSizes()
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { "\($0.key.rawValue):\(Int($0.value.width))x\(Int($0.value.height))" }
            .joined(separator: ",")
        let shots = [store.wallpaperURL, store.darkWallpaperURL].map { url in
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            return date.map { "\(Int($0.timeIntervalSince1970))" } ?? "-"
        }
        return "\(sizes)|\(seeThrough.offsetY)|\(shots.joined(separator: ","))|\(Self.screenPointsWide)"
    }

    /// Cuts a piece for every Home Screen slot from the bright and the dark screenshot.
    /// A widget picks its slot in Edit Widget; one without a dark piece keeps its bright
    /// one in Dark Mode.
    private func makePieces() async {
        let state = seeThrough
        let bright = state.hasWallpaper ? store.loadWallpaper().flatMap { UIImage(data: $0)?.cgImage } : nil
        var dark = state.hasDarkWallpaper ? store.loadDarkWallpaper().flatMap { UIImage(data: $0)?.cgImage } : nil
        if let bright, let image = dark, image.width != bright.width || image.height != bright.height {
            dark = nil
            message = "The Light and Dark Mode screenshots have different sizes. Take both on this iPhone, held upright."
        }
        guard let reference = bright ?? dark else { return }
        working = true
        defer { working = false }
        let store = self.store
        let signature = cutSignature()
        let grid = HomeGrid.make(width: CGFloat(reference.width), height: CGFloat(reference.height),
                                 scale: CGFloat(reference.width) / Self.screenPointsWide,
                                 sizes: store.loadSizes(), offsetY: state.offsetY)
        await Task.detached(priority: .userInitiated) { [bright, dark] in
            store.removeSpotImages()
            store.removeDarkSpotImages()
            for slot in HomeSlot.all {
                let rect = grid.rect(for: slot)
                if let bright, let png = SeeThroughMaker.crop(bright, to: rect) {
                    store.saveSpotImage(png, key: slot.key)
                }
                if let dark, let png = SeeThroughMaker.crop(dark, to: rect) {
                    store.saveDarkSpotImage(png, key: slot.key)
                }
            }
        }.value
        seeThrough.cutSignature = signature
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

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

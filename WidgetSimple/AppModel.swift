import SwiftUI
import UIKit
import Photos
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published var look: Look {
        didSet {
            store.saveLook(look)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    /// The color whose wallpaper was last saved to Photos.
    @Published private(set) var savedWallpaper: Theme? {
        didSet { UserDefaults.standard.set(savedWallpaper?.rawValue, forKey: "savedWallpaper") }
    }
    @Published var message: String?

    let store = SharedStore.shared

    init() {
        FontRegistry.registerAllOnce()
        look = store.loadLook()
        savedWallpaper = UserDefaults.standard.string(forKey: "savedWallpaper").flatMap(Theme.init(rawValue:))
    }

    /// Saves a wallpaper of exactly the widget color to Photos.
    func saveWallpaper() async {
        guard let data = Self.wallpaper(look.theme.background).pngData() else { return }
        let access = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard access == .authorized || access == .limited else {
            message = "WidgetSimple may not save to Photos. Allow it in Settings › WidgetSimple › Photos."
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
            savedWallpaper = look.theme
        } catch {
            message = "Couldn't save the wallpaper: \(error.localizedDescription)"
        }
    }

    /// A flat image exactly the size of the screen.
    private static func wallpaper(_ color: RGBA) -> UIImage {
        let screen = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen }
            .first
        let format = UIGraphicsImageRendererFormat()
        format.scale = screen?.scale ?? 3
        format.opaque = true
        format.preferredRange = .standard
        let size = screen?.bounds.size ?? CGSize(width: 393, height: 852)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.uiColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

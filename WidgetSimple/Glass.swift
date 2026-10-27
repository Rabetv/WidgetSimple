import SwiftUI
import UIKit

/// What the app draws behind its own screens, picked in Settings › App Wallpaper.
enum AppWallpaper: String, CaseIterable, Identifiable {
    /// The app's own brown artwork.
    case standard
    /// The Home Screen wallpaper from the setup screenshots (the Dark Mode one, since the
    /// app is always dark), so the app looks like the Home Screen its widgets sit on.
    case homeScreen

    static let storageKey = "appWallpaper"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return String(localized: "WidgetSimple")
        case .homeScreen: return String(localized: "My Home Screen")
        }
    }
}

/// The app's wallpaper behind every screen.
struct AppBackground: View {
    @AppStorage(AppWallpaper.storageKey) private var wallpaper = AppWallpaper.standard

    var body: some View {
        Group {
            if wallpaper == .homeScreen, let image = HomeScreenWallpaper.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    // Dimmed so the glass panels and white text stay readable.
                    .overlay(Color.black.opacity(0.35))
            } else {
                Image("AppBackground")
                    .resizable()
                    .scaledToFill()
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// The setup screenshot, decoded once and again only when the file changes.
enum HomeScreenWallpaper {
    @MainActor private static var cached: (date: Date, image: UIImage)?

    @MainActor static var image: UIImage? {
        let store = SharedStore.shared
        let url = store.loadDarkWallpaper() != nil ? store.darkWallpaperURL : store.wallpaperURL
        guard let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else {
            return nil
        }
        if let cached, cached.date == date { return cached.image }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        cached = (date, image)
        return image
    }
}

extension View {
    /// A Liquid Glass panel in a rounded rectangle, optionally tinted.
    func glassPanel(cornerRadius: CGFloat = 24, tint: Color? = nil) -> some View {
        glassEffect(tint.map { Glass.regular.tint($0) } ?? .regular,
                    in: .rect(cornerRadius: cornerRadius, style: .continuous))
    }
}

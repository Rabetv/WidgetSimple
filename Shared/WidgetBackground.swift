import SwiftUI
import UIKit

/// The widget background: a solid color (matching a flat wallpaper) or a cropped
/// copy of the wallpaper behind the widget.
struct WidgetBackgroundView: View {
    let layout: LauncherLayout
    let lightImage: UIImage?
    let darkImage: UIImage?
    var calibrating: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if calibrating {
            CalibrationMarker.color
        } else {
            switch layout.background.mode {
            case .wallpaper:
                if let image = currentImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    solidColor
                }
            case .color:
                solidColor
            }
        }
    }

    private var currentImage: UIImage? {
        if colorScheme == .dark { return darkImage ?? lightImage }
        return lightImage
    }

    private var solidColor: Color {
        if colorScheme == .dark, let dark = layout.background.darkColor { return dark.color }
        return layout.background.color.color
    }
}

/// Approximate widget sizes (points) for previews before the real size is known.
enum WidgetSizing {
    static func estimatedSize(for option: WidgetSizeOption, screenWidth: CGFloat) -> CGSize {
        let width = (screenWidth * 0.8465).rounded()
        let height = (width * 0.467).rounded()
        switch option {
        case .small: return CGSize(width: height, height: height)
        case .medium: return CGSize(width: width, height: height)
        case .large: return CGSize(width: width, height: (width * 1.05).rounded())
        }
    }

    static let cornerRadius: CGFloat = 24
}

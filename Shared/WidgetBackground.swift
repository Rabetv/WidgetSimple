import SwiftUI
import UIKit

/// The widget background: either the cropped wallpaper (so the widget blends into the
/// Home Screen and the iOS glass outline has nothing to contrast with) or a solid color.
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
            fill.overlay { edgeBand }
        }
    }

    @ViewBuilder
    private var fill: some View {
        switch layout.background.mode {
        case .transparent:
            // Nothing behind the text: iOS 26+ shows the wallpaper through the widget.
            Color.clear
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

    /// iOS draws its glass outline on top of the widget, so it can't be painted over.
    /// A soft darker (or lighter) band underneath can cancel it out; tuned by eye on the device.
    @ViewBuilder
    private var edgeBand: some View {
        let bg = layout.background
        if bg.edgeCorrection, bg.edgeTone != 0 {
            let width = CGFloat(max(1, bg.edgeWidth))
            ContainerRelativeShape()
                .strokeBorder(bg.edgeTone < 0 ? Color.black : Color.white, lineWidth: width)
                .blur(radius: width / 2)
                .opacity(min(abs(bg.edgeTone), 100) / 100)
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
        switch option {
        case .medium: return CGSize(width: width, height: (width * 0.467).rounded())
        case .large: return CGSize(width: width, height: (width * 1.05).rounded())
        }
    }

    static let cornerRadius: CGFloat = 24
}

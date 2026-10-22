import SwiftUI
import UIKit

/// In the Clear and Tinted Home Screen styles (accented rendering) iOS recolors all
/// widget text to white and ignores custom colors. Images marked
/// `.widgetAccentedRenderingMode(.fullColor)` are the documented exception, so the
/// widget can draw each label as a full-color image there and keep its look.
enum LabelRasterizer {
    @MainActor
    static func render(_ layout: LauncherLayout, scale: CGFloat = 3) -> [UUID: UIImage] {
        var images: [UUID: UIImage] = [:]
        for item in layout.items {
            let label = ItemLabel(item: item, style: layout.style(for: item), alignment: layout.alignment)
            let renderer = ImageRenderer(content: label)
            renderer.scale = scale
            renderer.isOpaque = false
            if let image = renderer.uiImage {
                images[item.id] = image
            }
        }
        return images
    }
}

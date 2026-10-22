import UIKit
import ImageIO

/// Builds Home Screen wallpapers for edge-free widgets.
///
/// The glass edge iOS draws on every widget only shows where the wallpaper behind
/// it has detail. A wallpaper that is one flat color where the widgets sit hides it,
/// so a photo can stay on the rest of the screen.
enum WallpaperComposer {
    enum PlainArea: String, CaseIterable, Identifiable {
        case top, bottom
        var id: String { rawValue }
        var title: String {
            switch self {
            case .top: return "Top"
            case .bottom: return "Bottom"
            }
        }
    }

    /// A flat image exactly the size of the screen.
    @MainActor
    static func plain(_ color: RGBA) -> UIImage {
        render { context, size in
            solid(color).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// The photo on part of the screen, fading into flat `color` where the widgets go.
    /// - Parameter fraction: share of the screen height that is plain (0...1).
    @MainActor
    static func photo(_ photo: UIImage, color: RGBA, area: PlainArea, fraction: CGFloat) -> UIImage {
        render { context, size in
            let cg = context.cgContext
            solid(color).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let plainHeight = (size.height * min(max(fraction, 0), 0.9)).rounded()
            let photoRect: CGRect
            switch area {
            case .top: photoRect = CGRect(x: 0, y: plainHeight, width: size.width, height: size.height - plainHeight)
            case .bottom: photoRect = CGRect(x: 0, y: 0, width: size.width, height: size.height - plainHeight)
            }

            // Photo, aspect-filled into its part of the screen.
            cg.saveGState()
            cg.clip(to: photoRect)
            let scale = max(photoRect.width / max(photo.size.width, 1), photoRect.height / max(photo.size.height, 1))
            let drawSize = CGSize(width: photo.size.width * scale, height: photo.size.height * scale)
            photo.draw(in: CGRect(x: photoRect.midX - drawSize.width / 2,
                                  y: photoRect.midY - drawSize.height / 2,
                                  width: drawSize.width, height: drawSize.height))
            cg.restoreGState()

            // Soft fade from the plain color into the photo.
            let fade = (size.height * 0.15).rounded()
            let colors = [solid(color).cgColor, solid(color).withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1]) else { return }
            let start: CGPoint
            let end: CGPoint
            switch area {
            case .top:
                start = CGPoint(x: 0, y: photoRect.minY)
                end = CGPoint(x: 0, y: photoRect.minY + fade)
            case .bottom:
                start = CGPoint(x: 0, y: photoRect.maxY)
                end = CGPoint(x: 0, y: photoRect.maxY - fade)
            }
            cg.saveGState()
            cg.clip(to: photoRect)
            cg.drawLinearGradient(gradient, start: start, end: end, options: [])
            cg.restoreGState()
        }
    }

    /// Loads a photo scaled down to what a wallpaper needs, with its orientation applied.
    /// Full-size iPhone photos (up to 48 MP) would use far too much memory.
    @MainActor
    static func loadPhoto(_ data: Data) -> UIImage? {
        let maxPixels = max(ScreenInfo.bounds.width, ScreenInfo.bounds.height) * ScreenInfo.scale * 1.5
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    private static func solid(_ color: RGBA) -> UIColor {
        RGBA(r: color.r, g: color.g, b: color.b).uiColor
    }

    @MainActor
    private static func render(_ draw: (UIGraphicsImageRendererContext, CGSize) -> Void) -> UIImage {
        let size = ScreenInfo.bounds.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = ScreenInfo.scale
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            draw(context, size)
        }
    }
}

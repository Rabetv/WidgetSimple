import UIKit
import ImageIO

// Wallpapers that ship with the app.
//
// The see-through widget apps don't store a wallpaper as one screenshot: they store the
// Home Screen's widget area as one canvas, cut into two overlapping halves, and take
// every widget's piece out of it. The files here keep that layout — `<id>.slice.top.jpg`
// and `<id>.slice.bottom.jpg` — because the halves are the only clean pixels we have of
// the wallpaper: the full screen previews in the app bundle carry the app's own buttons
// and the dock.
//
// The half heights and the overlap are the ones measured in the original assets:
// `top` is 1047 × 1062, `bottom` is 1047 × 1095 and sits 544 px down, so the canvas is
// 1047 × 1639. Keep those numbers if you replace the images with other crops.

struct CatalogWallpaper: Identifiable, Hashable {
    /// File name prefix: `<id>.slice.top.jpg`.
    let id: String
    let name: String

    /// Where `bottom` starts in the canvas. The halves overlap by 518 px.
    static let bottomOffset: CGFloat = 544

    static func fileURL(_ id: String, part: String) -> URL? {
        let name = "\(id).slice.\(part)"
        // A folder reference keeps the images in `Wallpapers/`; a plain group flattens them.
        return Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "Wallpapers")
            ?? Bundle.main.url(forResource: name, withExtension: "jpg")
    }

    static func image(_ id: String, part: String) -> UIImage? {
        fileURL(id, part: part).flatMap { UIImage(contentsOfFile: $0.path) }
    }

    /// The whole widget area: `top` at the top, `bottom` over its lower part.
    var canvas: UIImage? {
        guard let top = Self.image(id, part: "top"),
              let bottom = Self.image(id, part: "bottom") else { return nil }
        let size = CGSize(width: max(top.size.width, bottom.size.width),
                          height: Self.bottomOffset + bottom.size.height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            top.draw(in: CGRect(origin: .zero, size: top.size))
            bottom.draw(in: CGRect(x: 0, y: Self.bottomOffset,
                                   width: bottom.size.width, height: bottom.size.height))
        }
    }

    /// The canvas as a full-screen wallpaper, scaled to fill the screen.
    /// The user sets this one in Settings; the app keeps exactly these pixels, so the
    /// piece the widget shows is the same piece that is behind it.
    func wallpaper(fitting screen: CGSize) -> UIImage? {
        guard let canvas, canvas.size.width > 1, canvas.size.height > 1,
              screen.width > 1, screen.height > 1 else { return nil }
        let scale = max(screen.width / canvas.size.width, screen.height / canvas.size.height)
        let drawn = CGSize(width: canvas.size.width * scale, height: canvas.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: screen, format: format).image { _ in
            canvas.draw(in: CGRect(x: (screen.width - drawn.width) / 2,
                                   y: (screen.height - drawn.height) / 2,
                                   width: drawn.width, height: drawn.height))
        }
    }

    /// A small preview for the picker, decoded without loading the whole slice.
    static func thumbnail(_ id: String, maxPixel: CGFloat) -> UIImage? {
        guard let url = fileURL(id, part: "top"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}

enum WallpaperCatalog {
    /// The wallpapers the reference app ships, under the names it gives them.
    static let all: [CatalogWallpaper] = [
        CatalogWallpaper(id: "default", name: "Hintergrund"),
        CatalogWallpaper(id: "background", name: "Background"),
        CatalogWallpaper(id: "background-2", name: "Background 2"),
        CatalogWallpaper(id: "background-3", name: "Background 3"),
        CatalogWallpaper(id: "emily", name: "Emily"),
    ]

    static func wallpaper(id: String?) -> CatalogWallpaper? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }
}

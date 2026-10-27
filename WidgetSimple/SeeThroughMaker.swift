import UIKit

/// Cuts the pieces of wallpaper behind each Home Screen slot out of a screenshot (see
/// SeeThrough.swift).
enum SeeThroughMaker {

    /// The part of `wallpaper` inside `rect` (pixels) as PNG; nil when it is off-screen
    /// or too small to be a widget.
    static func crop(_ wallpaper: CGImage, to rect: CGRect) -> Data? {
        let bounds = CGRect(x: 0, y: 0, width: wallpaper.width, height: wallpaper.height)
        let r = rect.integral.intersection(bounds)
        guard !r.isNull, r.width > 10, r.height > 10, let piece = wallpaper.cropping(to: r) else { return nil }
        return UIImage(cgImage: piece).pngData()
    }
}

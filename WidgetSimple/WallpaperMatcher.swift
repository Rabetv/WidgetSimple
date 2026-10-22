import UIKit

/// Image helpers for the "match my wallpaper" workaround.
enum WallpaperMatcher {

    /// Redraws an image so its pixels are upright (orientation .up, scale 1).
    static func normalized(_ image: UIImage) -> UIImage {
        guard let cg = image.cgImage else { return image }
        if image.imageOrientation == .up { return UIImage(cgImage: cg, scale: 1, orientation: .up) }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }

    static func pixelSize(_ image: UIImage) -> CGSize {
        guard let cg = image.cgImage else { return image.size }
        return CGSize(width: cg.width, height: cg.height)
    }

    // MARK: Bitmap access

    private struct Bitmap {
        let width: Int
        let height: Int
        let bytes: [UInt8]

        init?(_ image: UIImage) {
            guard let cg = image.cgImage else { return nil }
            let w = cg.width
            let h = cg.height
            guard w > 0, h > 0 else { return nil }
            var buffer = [UInt8](repeating: 0, count: w * h * 4)
            let ok: Bool = buffer.withUnsafeMutableBytes { raw in
                guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h,
                                          bitsPerComponent: 8, bytesPerRow: w * 4,
                                          space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
                return true
            }
            guard ok else { return nil }
            width = w
            height = h
            bytes = buffer
        }

        @inline(__always)
        func rgb(_ x: Int, _ y: Int) -> (Int, Int, Int) {
            let i = (y * width + x) * 4
            return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
        }
    }

    @inline(__always)
    private static func isMarker(_ r: Int, _ g: Int, _ b: Int) -> Bool {
        r > 165 && b > 165 && g < 125 && abs(r - b) < 90
    }

    // MARK: Find the magenta calibration widget

    /// Returns the rectangle (in pixels) covered by the magenta calibration widget.
    static func findMarker(in image: UIImage) -> CGRect? {
        guard let bmp = Bitmap(image) else { return nil }
        let w = bmp.width, h = bmp.height
        var rowCounts = [Int](repeating: 0, count: h)
        var colCounts = [Int](repeating: 0, count: w)
        var total = 0
        for y in 0..<h {
            for x in 0..<w {
                let (r, g, b) = bmp.rgb(x, y)
                if isMarker(r, g, b) {
                    rowCounts[y] += 1
                    colCounts[x] += 1
                    total += 1
                }
            }
        }
        // A widget is at least ~100 x 100 pixels.
        guard total > 10_000 else { return nil }
        guard let rows = longestBand(rowCounts), let cols = longestBand(colCounts) else { return nil }
        let rect = CGRect(x: cols.lowerBound, y: rows.lowerBound,
                          width: cols.count, height: rows.count)
        guard rect.width > 100, rect.height > 100 else { return nil }
        return rect
    }

    /// Longest run of indices whose count is at least half of the maximum.
    private static func longestBand(_ counts: [Int]) -> Range<Int>? {
        guard let peak = counts.max(), peak > 0 else { return nil }
        let threshold = max(1, peak / 2)
        var best: Range<Int>?
        var start: Int?
        for (i, c) in counts.enumerated() {
            if c >= threshold {
                if start == nil { start = i }
            } else if let s = start {
                if best == nil || (i - s) > best!.count { best = s..<i }
                start = nil
            }
        }
        if let s = start, best == nil || (counts.count - s) > best!.count {
            best = s..<counts.count
        }
        return best
    }

    /// Uses the widget's measured size (if it fits) around the detected center.
    /// The glass edge can eat a few pixels of the magenta area, the measured size can't.
    static func refine(_ detected: CGRect, measuredPoints: CGSize?, pixelsPerPoint: CGFloat) -> CGRect {
        guard let measured = measuredPoints, measured.width > 0 else { return detected.integral }
        let expected = CGSize(width: (measured.width * pixelsPerPoint).rounded(),
                              height: (measured.height * pixelsPerPoint).rounded())
        let dw = abs(expected.width - detected.width) / expected.width
        let dh = abs(expected.height - detected.height) / expected.height
        guard dw < 0.06, dh < 0.06 else { return detected.integral }
        let center = CGPoint(x: detected.midX, y: detected.midY)
        return CGRect(x: (center.x - expected.width / 2).rounded(),
                      y: (center.y - expected.height / 2).rounded(),
                      width: expected.width, height: expected.height)
    }

    // MARK: Crop & sample

    static func crop(_ image: UIImage, to rect: CGRect) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: cg.width, height: cg.height)
        let r = rect.integral.intersection(bounds)
        guard !r.isNull, r.width > 10, r.height > 10, let cropped = cg.cropping(to: r) else { return nil }
        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }

    /// Average color of the middle of an image (for single-color wallpapers).
    static func averageColor(in image: UIImage) -> RGBA? {
        let upright = normalized(image)
        let size = pixelSize(upright)
        let region = CGRect(x: size.width * 0.4, y: size.height * 0.4,
                            width: size.width * 0.2, height: size.height * 0.2)
        guard let cropped = crop(upright, to: region), let bmp = Bitmap(cropped) else { return nil }
        var r = 0, g = 0, b = 0, n = 0
        for y in stride(from: 0, to: bmp.height, by: 2) {
            for x in stride(from: 0, to: bmp.width, by: 2) {
                let px = bmp.rgb(x, y)
                r += px.0; g += px.1; b += px.2; n += 1
            }
        }
        guard n > 0 else { return nil }
        return RGBA(r: Double(r) / Double(n) / 255, g: Double(g) / Double(n) / 255, b: Double(b) / Double(n) / 255)
    }

    /// The most common color in an image. In a Home Screen screenshot with a flat
    /// wallpaper that is the wallpaper as iOS actually shows it (icons cover far less).
    static func dominantColor(in image: UIImage) -> RGBA? {
        guard let bmp = Bitmap(normalized(image)) else { return nil }
        struct Bucket { var n = 0, r = 0, g = 0, b = 0 }
        var buckets: [Int: Bucket] = [:]
        for y in stride(from: 0, to: bmp.height, by: 3) {
            for x in stride(from: 0, to: bmp.width, by: 3) {
                let (r, g, b) = bmp.rgb(x, y)
                let key = (r >> 3) << 10 | (g >> 3) << 5 | (b >> 3)
                var bucket = buckets[key] ?? Bucket()
                bucket.n += 1; bucket.r += r; bucket.g += g; bucket.b += b
                buckets[key] = bucket
            }
        }
        guard let best = buckets.values.max(by: { $0.n < $1.n }), best.n > 0 else { return nil }
        let n = Double(best.n) * 255
        return RGBA(r: Double(best.r) / n, g: Double(best.g) / n, b: Double(best.b) / n)
    }
}

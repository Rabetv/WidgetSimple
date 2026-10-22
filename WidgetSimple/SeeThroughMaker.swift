import UIKit

/// Finds the pink widgets in a Home Screen screenshot and cuts the matching pieces
/// out of the wallpaper screenshot (see SeeThrough.swift).
enum SeeThroughMaker {

    /// Every pink widget in `image` whose key could be read.
    /// - Parameters:
    ///   - sizes: real widget sizes in points, reported by the widget.
    ///   - pointsWide: screen width in points, to turn those sizes into pixels.
    static func findSpots(in image: CGImage, sizes: [SpotFamily: CGSize], pointsWide: CGFloat) -> [Spot] {
        guard let bmp = Bitmap(image) else { return [] }
        let pixelsPerPoint = CGFloat(bmp.width) / max(pointsWide, 1)

        // Mark pink on a coarse grid, then group touching cells into widgets.
        let step = 4
        let gw = bmp.width / step
        let gh = bmp.height / step
        var pink = [Bool](repeating: false, count: gw * gh)
        for gy in 0..<gh {
            for gx in 0..<gw {
                pink[gy * gw + gx] = bmp.isMarker(gx * step + step / 2, gy * step + step / 2)
            }
        }

        var seen = [Bool](repeating: false, count: gw * gh)
        var spots: [Spot] = []
        for start in pink.indices where pink[start] && !seen[start] {
            var queue = [start]
            seen[start] = true
            var head = 0
            var minX = gw, minY = gh, maxX = 0, maxY = 0
            func visit(_ cell: Int) {
                if pink[cell] && !seen[cell] {
                    seen[cell] = true
                    queue.append(cell)
                }
            }
            while head < queue.count {
                let cell = queue[head]
                head += 1
                let x = cell % gw, y = cell / gw
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
                if x > 0 { visit(cell - 1) }
                if x < gw - 1 { visit(cell + 1) }
                if y > 0 { visit(cell - gw) }
                if y < gh - 1 { visit(cell + gw) }
            }
            // A widget is far bigger than 300 cells (about 70 × 70 pixels of pink).
            guard queue.count >= 300 else { continue }

            // The exact frame: walk outward from inside the pink to each edge, on a few
            // lines between the corners and the code, and take the middle result.
            // Walking from inside stops at the widget's edge even on a pink wallpaper.
            let ax = CGFloat(minX * step), ay = CGFloat(minY * step)
            let aw = CGFloat((maxX - minX + 1) * step), ah = CGFloat((maxY - minY + 1) * step)
            let lines: [CGFloat] = [0.3, 0.4, 0.5, 0.6, 0.7]
            guard let left = median(lines.map { bmp.walk(from: Int(ax + aw * 0.1), Int(ay + ah * $0), dx: -1, dy: 0) }),
                  let right = median(lines.map { bmp.walk(from: Int(ax + aw * 0.9), Int(ay + ah * $0), dx: 1, dy: 0) }),
                  let top = median(lines.map { bmp.walk(from: Int(ax + aw * $0), Int(ay + ah * 0.1), dx: 0, dy: -1) }),
                  let bottom = median(lines.map { bmp.walk(from: Int(ax + aw * $0), Int(ay + ah * 0.9), dx: 0, dy: 1) }),
                  right > left, bottom > top else { continue }
            var rect = CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
            guard let key = readKey(bmp, in: rect) else { continue }

            // The glass edge iOS draws can hide a few pixels of pink; the size the
            // widget reported can't, so use it around the found center when it fits.
            if let family = SpotKey.family(of: key), let points = sizes[family] {
                rect = snap(rect, to: CGSize(width: points.width * pixelsPerPoint, height: points.height * pixelsPerPoint))
            }
            spots.append(Spot(key: key, rect: rect))
        }
        return spots
    }

    /// The wallpaper piece for one widget, as PNG.
    static func crop(_ wallpaper: CGImage, to rect: CGRect) -> Data? {
        let bounds = CGRect(x: 0, y: 0, width: wallpaper.width, height: wallpaper.height)
        let r = rect.integral.intersection(bounds)
        guard !r.isNull, r.width > 10, r.height > 10, let piece = wallpaper.cropping(to: r) else { return nil }
        return UIImage(cgImage: piece).pngData()
    }

    // MARK: Helpers

    /// Reads the 4 × 4 squares SpotCode draws in the middle of the widget.
    private static func readKey(_ bmp: Bitmap, in rect: CGRect) -> Int? {
        let side = min(rect.width, rect.height) * SpotCode.sideRatio
        let cell = side / 4
        let originX = rect.midX - side / 2
        let originY = rect.midY - side / 2
        var key = 0
        for index in 0..<16 {
            let cx = Int(originX + (CGFloat(index % 4) + 0.5) * cell)
            let cy = Int(originY + (CGFloat(index / 4) + 0.5) * cell)
            var sum = 0, count = 0
            for dy in -2...2 {
                for dx in -2...2 {
                    let x = cx + dx, y = cy + dy
                    if bmp.isMarker(x, y) { return nil }
                    let (r, g, b) = bmp.rgb(x, y)
                    sum += (r + g + b) / 3
                    count += 1
                }
            }
            let brightness = sum / max(count, 1)
            if brightness < 90 {
                key |= 1 << (15 - index)
            } else if brightness < 165 {
                return nil // Neither black nor white: not a code square.
            }
        }
        return key
    }

    private static func median(_ values: [Int?]) -> Int? {
        let found = values.compactMap { $0 }.sorted()
        return found.isEmpty ? nil : found[found.count / 2]
    }

    private static func snap(_ found: CGRect, to expected: CGSize) -> CGRect {
        guard expected.width > 0, expected.height > 0,
              abs(expected.width - found.width) / expected.width < 0.08,
              abs(expected.height - found.height) / expected.height < 0.08 else { return found.integral }
        return CGRect(x: (found.midX - expected.width / 2).rounded(),
                      y: (found.midY - expected.height / 2).rounded(),
                      width: expected.width.rounded(),
                      height: expected.height.rounded())
    }

    /// RGBA pixels in sRGB.
    private struct Bitmap {
        let width: Int
        let height: Int
        let bytes: [UInt8]

        init?(_ image: CGImage) {
            let w = image.width, h = image.height
            guard w > 0, h > 0 else { return nil }
            var buffer = [UInt8](repeating: 0, count: w * h * 4)
            let ok: Bool = buffer.withUnsafeMutableBytes { raw in
                guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h,
                                          bitsPerComponent: 8, bytesPerRow: w * 4,
                                          space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
                return true
            }
            guard ok else { return nil }
            width = w
            height = h
            bytes = buffer
        }

        /// The pixel at (x, y), top-left origin; edges are clamped.
        func rgb(_ x: Int, _ y: Int) -> (Int, Int, Int) {
            let cx = min(max(x, 0), width - 1), cy = min(max(y, 0), height - 1)
            let i = (cy * width + cx) * 4
            return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
        }

        /// Pure pink (SpotCode.marker); photos almost never have it.
        func isMarker(_ x: Int, _ y: Int) -> Bool {
            let (r, g, b) = rgb(x, y)
            return r > 215 && b > 215 && g < 60
        }

        /// From a pink pixel, steps in (dx, dy) while the next pixel is pink too.
        /// Returns the last pink x (horizontal walk) or y (vertical walk).
        func walk(from x: Int, _ y: Int, dx: Int, dy: Int) -> Int? {
            guard isMarker(x, y) else { return nil }
            var x = x, y = y
            while x + dx >= 0, x + dx < width, y + dy >= 0, y + dy < height, isMarker(x + dx, y + dy) {
                x += dx
                y += dy
            }
            return dx != 0 ? x : y
        }
    }
}

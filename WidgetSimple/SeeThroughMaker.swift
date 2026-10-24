import UIKit

/// Finds the pink widgets in a Home Screen screenshot and cuts the matching pieces
/// out of the wallpaper screenshot (see SeeThrough.swift).
enum SeeThroughMaker {

    struct SizeMismatch: Hashable {
        var family: SpotFamily
        var found: CGSize
        var expected: CGSize
    }

    struct ScanResult {
        /// Widgets found and read, with their final frames in screenshot pixels.
        var spots: [Spot] = []
        /// Pink widgets whose code couldn't be read (shadow, tint, partly covered).
        var unread: [CGRect] = []
        /// Keys seen on more than one widget in this screenshot.
        var duplicates: Set<UInt32> = []
        /// Widgets whose measured size is more than 2 % off the size they reported.
        var mismatches: [SizeMismatch] = []
    }

    /// The largest disagreement between a widget's measured and reported size that is
    /// still treated as the glass rim eating into the pink, not a different scale.
    static let sizeTolerance: CGFloat = 0.02

    /// Every pink widget in `image`.
    /// - Parameters:
    ///   - sizes: real widget sizes in points, reported by each widget family.
    ///   - pixelsPerPoint: screenshot pixels per screen point (screenshot width ÷ screen
    ///     width in points; not UIScreen.scale, which ignores Display Zoom).
    static func scan(_ image: CGImage, sizes: [SpotFamily: CGSize], pixelsPerPoint: CGFloat) -> ScanResult {
        var result = ScanResult()
        guard let bmp = Bitmap(image) else { return result }

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
        var keyCounts: [UInt32: Int] = [:]
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

            // The pink's extent: walk outward from inside the pink to each edge, on a few
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
            let found = CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)

            // Found a widget but couldn't read its ID: keep it so the app can say so,
            // instead of silently dropping it (it used to fall back to a borrowed piece).
            guard let key = readKey(bmp, in: found) else {
                result.unread.append(found.integral)
                continue
            }
            keyCounts[key, default: 0] += 1

            guard let family = SpotKey.family(of: key), let points = sizes[family] else {
                // The family never reported its size: the pink is the best we have.
                result.spots.append(Spot(key: key, rect: found.integral))
                continue
            }
            // The size the widget reported is the authority; the pink only gives the
            // centre. The glass rim hides a pixel or two of pink on each side, evenly,
            // so the centre is exact while the pink's size is not.
            let expected = CGSize(width: points.width * pixelsPerPoint, height: points.height * pixelsPerPoint)
            let dw = abs(found.width - expected.width) / max(expected.width, 1)
            let dh = abs(found.height - expected.height) / max(expected.height, 1)
            guard dw <= sizeTolerance, dh <= sizeTolerance else {
                result.mismatches.append(SizeMismatch(family: family, found: found.size, expected: expected))
                continue
            }
            let rect = CGRect(x: (found.midX - expected.width / 2).rounded(),
                              y: (found.midY - expected.height / 2).rounded(),
                              width: expected.width.rounded(),
                              height: expected.height.rounded())
            result.spots.append(Spot(key: key, rect: rect))
        }

        // Two widgets drawing the same key can't be told apart: neither gets a piece.
        result.duplicates = Set(keyCounts.filter { $0.value > 1 }.keys)
        result.spots.removeAll { result.duplicates.contains($0.key) }
        return result
    }

    /// The wallpaper piece for one widget, as PNG.
    static func crop(_ wallpaper: CGImage, to rect: CGRect) -> Data? {
        let bounds = CGRect(x: 0, y: 0, width: wallpaper.width, height: wallpaper.height)
        let r = rect.integral.intersection(bounds)
        guard !r.isNull, r.width > 10, r.height > 10, let piece = wallpaper.cropping(to: r) else { return nil }
        return UIImage(cgImage: piece).pngData()
    }

    /// The wallpaper's average colour, for the "match wallpaper" word colour.
    static func averageColor(of image: CGImage) -> UIColor? {
        guard let bmp = Bitmap(image, maxSide: 64) else { return nil }
        var r = 0, g = 0, b = 0
        for y in 0..<bmp.height {
            for x in 0..<bmp.width {
                let p = bmp.rgb(x, y)
                r += p.0; g += p.1; b += p.2
            }
        }
        let n = CGFloat(max(bmp.width * bmp.height, 1)) * 255
        return UIColor(red: CGFloat(r) / n, green: CGFloat(g) / n, blue: CGFloat(b) / n, alpha: 1)
    }

    // MARK: Helpers

    /// Reads the 6 × 6 squares SpotCode draws in the middle of the widget.
    ///
    /// The code square is located from the pixels themselves (the non-pink block in the
    /// middle), not from an assumed widget size. Each square is the median of nine
    /// samples spread over its inner half, with wide black/white bands (0.35 / 0.65), so
    /// a shadowed or glass-tinted square still reads. The CRC rejects anything misread.
    private static func readKey(_ bmp: Bitmap, in rect: CGRect) -> UInt32? {
        let region = rect.insetBy(dx: rect.width * 0.12, dy: rect.height * 0.12)
        let x0 = max(Int(region.minX), 0), x1 = min(Int(region.maxX), bmp.width - 1)
        let y0 = max(Int(region.minY), 0), y1 = min(Int(region.maxY), bmp.height - 1)
        guard x1 - x0 > 24, y1 - y0 > 24 else { return nil }

        var columns = [Int](repeating: 0, count: x1 - x0 + 1)
        var rows = [Int](repeating: 0, count: y1 - y0 + 1)
        for y in y0...y1 {
            for x in x0...x1 where !bmp.isMarker(x, y) {
                columns[x - x0] += 1
                rows[y - y0] += 1
            }
        }
        // Rows and columns through the code are mostly not pink; a stray highlight isn't.
        let columnFloor = max((columns.max() ?? 0) * 3 / 10, 1)
        let rowFloor = max((rows.max() ?? 0) * 3 / 10, 1)
        guard let left = columns.firstIndex(where: { $0 >= columnFloor }),
              let right = columns.lastIndex(where: { $0 >= columnFloor }),
              let top = rows.firstIndex(where: { $0 >= rowFloor }),
              let bottom = rows.lastIndex(where: { $0 >= rowFloor }) else { return nil }
        let box = CGRect(x: x0 + left, y: y0 + top, width: right - left + 1, height: bottom - top + 1)
        guard box.width > 18, box.height > 18,
              abs(box.width - box.height) / max(box.width, box.height) < 0.12 else { return nil }

        let side = SpotKey.codeSide
        let cellW = box.width / CGFloat(side), cellH = box.height / CGFloat(side)
        let offsets: [CGFloat] = [-0.25, 0, 0.25]
        var bits: [Bool] = []
        for index in 0..<SpotKey.codeBits {
            let cx = box.minX + (CGFloat(index % side) + 0.5) * cellW
            let cy = box.minY + (CGFloat(index / side) + 0.5) * cellH
            var samples: [Double] = []
            for dy in offsets {
                for dx in offsets {
                    let x = Int(cx + dx * cellW), y = Int(cy + dy * cellH)
                    if bmp.isMarker(x, y) { continue } // pink would read as dark
                    samples.append(bmp.luminance(x, y))
                }
            }
            guard samples.count >= 5 else { return nil }
            let middle = samples.sorted()[samples.count / 2]
            if middle < 0.35 {
                bits.append(true)
            } else if middle > 0.65 {
                bits.append(false)
            } else {
                return nil // neither black nor white
            }
        }
        return SpotKey.decode(bits)
    }

    private static func median(_ values: [Int?]) -> Int? {
        let found = values.compactMap { $0 }.sorted()
        return found.isEmpty ? nil : found[found.count / 2]
    }

    /// RGBA pixels in sRGB.
    private struct Bitmap {
        let width: Int
        let height: Int
        let bytes: [UInt8]

        /// - Parameter maxSide: draws the image smaller when set (for averages).
        init?(_ image: CGImage, maxSide: Int? = nil) {
            var w = image.width, h = image.height
            guard w > 0, h > 0 else { return nil }
            if let maxSide, max(w, h) > maxSide {
                let scale = Double(maxSide) / Double(max(w, h))
                w = max(Int(Double(w) * scale), 1)
                h = max(Int(Double(h) * scale), 1)
            }
            var buffer = [UInt8](repeating: 0, count: w * h * 4)
            let ok: Bool = buffer.withUnsafeMutableBytes { raw in
                guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h,
                                          bitsPerComponent: 8, bytesPerRow: w * 4,
                                          space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                ctx.interpolationQuality = .medium
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

        /// Relative luminance, 0…1.
        func luminance(_ x: Int, _ y: Int) -> Double {
            let (r, g, b) = rgb(x, y)
            return (0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)) / 255
        }

        /// The marker pink (SpotCode.marker), allowing for the ~10 % white veil the
        /// system glass lays over the container; photos almost never have it.
        func isMarker(_ x: Int, _ y: Int) -> Bool {
            let (r, g, b) = rgb(x, y)
            return r > 200 && b > 200 && g < 90 && abs(r - b) < 45
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

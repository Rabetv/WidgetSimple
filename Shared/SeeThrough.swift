import SwiftUI

// See-through widgets on the normal Home Screen: each widget shows the piece of
// wallpaper behind it, cut from a screenshot of an empty Home Screen page.
//
// To learn where each widget sits, every widget turns pink for a moment and shows
// its key as 4 × 4 black and white squares. One screenshot of the Home Screen then
// gives the app each widget's exact frame and which widget it is.

enum SpotFamily: Int, Codable, CaseIterable {
    case small, medium, large, max
}

/// Which widget a background belongs to: its size (2 bits) and a 14-bit hash of what
/// it shows. Two widgets of the same size with the same clock and apps share a key.
enum SpotKey {
    static func make(family: SpotFamily, clock: ClockOption, apps: [String]) -> Int {
        // FNV-1a: stable across launches, unlike Hasher.
        var hash: UInt32 = 2_166_136_261
        for byte in "\(clock.rawValue)|\(apps.joined(separator: "\u{1F}"))".utf8 {
            hash = (hash ^ UInt32(byte)) &* 16_777_619
        }
        let short = Int((hash >> 16) ^ (hash & 0xFFFF)) & 0x3FFF
        return family.rawValue << 14 | short
    }

    /// The Apps widget's key, the same one the timeline provider makes: with a design,
    /// the design is part of the key (and the clock is not), so the same apps in a design
    /// never take the plain widget's piece.
    static func make(family: SpotFamily, clock: ClockOption, apps: [String], design: UUID?) -> Int {
        design.map { make(family: family, clock: .off, apps: ["design:" + $0.uuidString] + apps) }
            ?? make(family: family, clock: clock, apps: apps)
    }

    static func family(of key: Int) -> SpotFamily? {
        SpotFamily(rawValue: (key >> 14) & 0x3)
    }
}

/// Where one widget sits, in screenshot pixels.
struct Spot: Codable, Hashable {
    var key: Int
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(key: Int, rect: CGRect) {
        self.key = key
        x = Double(rect.minX)
        y = Double(rect.minY)
        width = Double(rect.width)
        height = Double(rect.height)
    }

    var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

struct SeeThroughState: Codable, Hashable {
    /// While true every widget turns pink and shows its key.
    var finding = false
    var spots: [Spot] = []
    /// Pixel size of the pink screenshot the spots come from.
    var spotsWidth: Double = 0
    var spotsHeight: Double = 0
    /// The bright (Light Mode) wallpaper screenshot.
    var hasWallpaper = false
    /// The same Home Screen page in Dark Mode. The spots serve both: widgets don't move
    /// when the appearance changes.
    var hasDarkWallpaper = false

    /// Both wallpapers and at least one matched widget: every widget found has a piece
    /// for Light and for Dark Mode.
    var isComplete: Bool { hasWallpaper && hasDarkWallpaper && !spots.isEmpty }

    init() {}

    enum CodingKeys: String, CodingKey { case finding, spots, spotsWidth, spotsHeight, hasWallpaper, hasDarkWallpaper }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        finding = try c.decodeIfPresent(Bool.self, forKey: .finding) ?? false
        spots = try c.decodeIfPresent([Spot].self, forKey: .spots) ?? []
        spotsWidth = try c.decodeIfPresent(Double.self, forKey: .spotsWidth) ?? 0
        spotsHeight = try c.decodeIfPresent(Double.self, forKey: .spotsHeight) ?? 0
        hasWallpaper = try c.decodeIfPresent(Bool.self, forKey: .hasWallpaper) ?? false
        hasDarkWallpaper = try c.decodeIfPresent(Bool.self, forKey: .hasDarkWallpaper) ?? false
    }
}

/// What a widget shows while the app looks for it: its key as 16 squares on pink
/// (the pink is the widget's container background).
struct SpotCode: View {
    let key: Int

    static let marker = Color(red: 1, green: 0, blue: 1)
    /// Side of the code square, as a share of the widget's shorter side.
    static let sideRatio: CGFloat = 0.6

    var body: some View {
        GeometryReader { geo in
            let cell = min(geo.size.width, geo.size.height) * Self.sideRatio / 4
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { column in
                            Rectangle()
                                .fill(Self.bit(key, row * 4 + column) ? Color.black : Color.white)
                                .frame(width: cell, height: cell)
                        }
                    }
                }
            }
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    /// Bit `index` (0 = top left, row by row) of `key`.
    static func bit(_ key: Int, _ index: Int) -> Bool {
        (key >> (15 - index)) & 1 == 1
    }
}

// MARK: - Positions for Edit Widget

extension SeeThroughState {
    /// A matched spot with a stable id and a name a person can pick in Edit Widget.
    struct NamedSpot: Hashable {
        let id: String
        let key: Int
        let name: String
    }

    /// The matched spots top to bottom, left to right, named by size and place:
    /// "Small · top left", "Medium · middle". Two spots with the same name get a number.
    var namedSpots: [NamedSpot] {
        guard spotsWidth > 0, spotsHeight > 0 else { return [] }
        let ordered = spots.sorted { ($0.y, $0.x) < ($1.y, $1.x) }
        var seen: [String: Int] = [:]
        return ordered.map { spot in
            var name = "\(Self.sizeName(of: spot.key)) · \(placeName(of: spot))"
            seen[name, default: 0] += 1
            if let count = seen[name], count > 1 { name += " \(count)" }
            return NamedSpot(id: Self.id(of: spot), key: spot.key, name: name)
        }
    }

    func spot(withID id: String) -> Spot? {
        spots.first { Self.id(of: $0) == id }
    }

    static func id(of spot: Spot) -> String {
        "\(spot.key)@\(Int(spot.x)),\(Int(spot.y))"
    }

    private static func sizeName(of key: Int) -> String {
        switch SpotKey.family(of: key) {
        case .small: return String(localized: "Small")
        case .medium: return String(localized: "Medium")
        case .large: return String(localized: "Large")
        case .max, .none: return String(localized: "Extra large")
        }
    }

    /// Thirds of the screen: top/middle/bottom and left/centre/right.
    private func placeName(of spot: Spot) -> String {
        let column = (spot.x + spot.width / 2) / spotsWidth
        let row = (spot.y + spot.height / 2) / spotsHeight
        let vertical = row < 1 / 3 ? String(localized: "top") : row > 2 / 3 ? String(localized: "bottom") : String(localized: "middle")
        if column < 1 / 3 { return "\(vertical) \(String(localized: "left"))" }
        if column > 2 / 3 { return "\(vertical) \(String(localized: "right"))" }
        return vertical
    }
}

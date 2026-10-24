import SwiftUI

// See-through widgets on the normal Home Screen: each widget shows the piece of
// wallpaper behind it, cut from a screenshot of an empty Home Screen page. Public API
// only — the system container is still there; it just has the right pixels inside.
//
// To learn where each widget sits, every widget turns pink for a moment and shows
// its key as 6 × 6 black and white squares. One screenshot per Home Screen page then
// gives the app each widget's exact frame and which widget it is.

enum SpotFamily: Int, Codable, CaseIterable {
    case small, medium, large, max
}

/// Which widget a background belongs to.
///
/// Layout of the 32 bits: family (2) · origin (1) · hash (29).
///  * origin 1 — the hash of the widget's own identity (`WidgetIdentity`, a UUID the
///    system stores in each widget's configuration). Two widgets showing the same apps
///    still get different keys.
///  * origin 0 — the hash of what the widget shows. Only widgets configured before
///    identities existed use it; it is the migration path, not the normal case.
///
/// The code drawn on pink adds a 4-bit CRC, so a misread square is rejected instead of
/// silently turning into somebody else's key.
enum SpotKey {
    static func make(family: SpotFamily, identity: String) -> UInt32 {
        UInt32(family.rawValue) << 30 | 1 << 29 | (fnv1a(identity) & 0x1FFF_FFFF)
    }

    /// Content key for widgets without an identity (migration only).
    static func content(family: SpotFamily, kind: String, clock: ClockOption, apps: [String]) -> UInt32 {
        let text = "\(kind)|\(clock.rawValue)|\(apps.joined(separator: "\u{1F}"))"
        return UInt32(family.rawValue) << 30 | (fnv1a(text) & 0x1FFF_FFFF)
    }

    /// The 16-bit key builds 35–39 used (content hash, no identity). Read once to keep
    /// existing pieces on screen until the first rescan; never written.
    static func legacy16(family: SpotFamily, clock: ClockOption, apps: [String]) -> Int {
        let hash = fnv1a("\(clock.rawValue)|\(apps.joined(separator: "\u{1F}"))")
        let short = Int((hash >> 16) ^ (hash & 0xFFFF)) & 0x3FFF
        return family.rawValue << 14 | short
    }

    static func family(of key: UInt32) -> SpotFamily? {
        SpotFamily(rawValue: Int(key >> 30))
    }

    /// True for keys made from a widget identity (they survive edits and rescans).
    static func isIdentity(_ key: UInt32) -> Bool {
        key & (1 << 29) != 0
    }

    // MARK: Code

    static let codeSide = 6
    static let codeBits = codeSide * codeSide

    /// The 36 squares for `key`, top left first, row by row: 32 key bits, then the CRC.
    static func codeBits(for key: UInt32) -> [Bool] {
        let check = crc4(key)
        return (0..<codeBits).map { index in
            index < 32 ? (key >> UInt32(31 - index)) & 1 == 1 : (check >> UInt8(35 - index)) & 1 == 1
        }
    }

    /// The key in 36 read squares, or nil when the CRC does not match.
    static func decode(_ bits: [Bool]) -> UInt32? {
        guard bits.count == codeBits else { return nil }
        var key: UInt32 = 0
        for index in 0..<32 where bits[index] { key |= 1 << UInt32(31 - index) }
        var check: UInt8 = 0
        for index in 32..<36 where bits[index] { check |= 1 << UInt8(35 - index) }
        return check == crc4(key) ? key : nil
    }

    /// CRC-4 (x⁴ + x + 1) of the 32 key bits, xored with a constant so an all-white or
    /// all-black square never decodes.
    static func crc4(_ value: UInt32) -> UInt8 {
        var crc: UInt8 = 0
        for shift in stride(from: 31, through: 0, by: -1) {
            let bit = UInt8((value >> UInt32(shift)) & 1)
            let top = (crc >> 3) & 1
            crc = (crc << 1) & 0xF
            if top ^ bit == 1 { crc ^= 0x3 }
        }
        return crc ^ 0x9
    }

    /// FNV-1a: stable across launches and processes, unlike Hasher.
    private static func fnv1a(_ text: String) -> UInt32 {
        var hash: UInt32 = 2_166_136_261
        for byte in text.utf8 {
            hash = (hash ^ UInt32(byte)) &* 16_777_619
        }
        return hash
    }
}

/// Where one widget sits, in screenshot pixels.
struct Spot: Codable, Hashable {
    var key: UInt32
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(key: UInt32, rect: CGRect) {
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
    /// Pixel size of the screenshots the spots come from (wallpaper and pink must match).
    var spotsWidth: Double = 0
    var spotsHeight: Double = 0
    /// Points per pixel the spots were measured with, for the record and for support.
    var pixelsPerPoint: Double = 0
    var hasWallpaper = false
    /// The folder under Spots/ holding the current pieces. Switching it is the atomic
    /// swap: a widget reads either the old set or the new one, never a half-written mix.
    /// nil until the first scan made by this version (old pieces live in Spots/ itself).
    var generation: String?
    /// Pink widgets the last scan found but could not read (shadowed or tinted code).
    var unreadCount = 0
    /// Keys the last scan saw on more than one widget; those widgets got no piece.
    var duplicateKeys: [UInt32] = []

    init() {}

    enum CodingKeys: String, CodingKey {
        case finding, spots, spotsWidth, spotsHeight, pixelsPerPoint, hasWallpaper
        case generation, unreadCount, duplicateKeys
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        finding = try c.decodeIfPresent(Bool.self, forKey: .finding) ?? false
        spots = (try? c.decodeIfPresent([Spot].self, forKey: .spots)) ?? []
        spotsWidth = try c.decodeIfPresent(Double.self, forKey: .spotsWidth) ?? 0
        spotsHeight = try c.decodeIfPresent(Double.self, forKey: .spotsHeight) ?? 0
        pixelsPerPoint = try c.decodeIfPresent(Double.self, forKey: .pixelsPerPoint) ?? 0
        hasWallpaper = try c.decodeIfPresent(Bool.self, forKey: .hasWallpaper) ?? false
        generation = try c.decodeIfPresent(String.self, forKey: .generation)
        unreadCount = try c.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0
        duplicateKeys = try c.decodeIfPresent([UInt32].self, forKey: .duplicateKeys) ?? []
        // Builds 35–39 had no generation and keyed spots with a 16-bit content hash of
        // another format. Their rects can't be trusted as keys of this one, so they are
        // dropped; the old pieces stay readable by exact legacy key until the first scan.
        if generation == nil { spots = [] }
    }
}

/// What a widget shows while the app looks for it: its key as 36 squares on pink
/// (the pink is the widget's container background).
struct SpotCode: View {
    let key: UInt32

    static let marker = Color(red: 1, green: 0, blue: 1)
    /// Side of the code square, as a share of the widget's shorter side.
    static let sideRatio: CGFloat = 0.6

    var body: some View {
        GeometryReader { geo in
            let side = SpotKey.codeSide
            let cell = (min(geo.size.width, geo.size.height) * Self.sideRatio / CGFloat(side)).rounded(.down)
            let bits = SpotKey.codeBits(for: key)
            VStack(spacing: 0) {
                ForEach(0..<side, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<side, id: \.self) { column in
                            Rectangle()
                                .fill(bits[row * side + column] ? Color.black : Color.white)
                                .frame(width: cell, height: cell)
                        }
                    }
                }
            }
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .accessibilityLabel("Matching code")
    }
}

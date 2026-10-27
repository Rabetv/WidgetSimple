import AppIntents
import CoreGraphics

// See-through widgets on the normal Home Screen: each widget shows the piece of
// wallpaper behind it, cut from two screenshots of an empty Home Screen page (Light and
// Dark Mode). That is all the person does.
//
// WidgetKit never tells a widget where it sits, so the app cuts a piece for every slot
// of the iPhone's widget grid, and each widget picks its slot in Edit Widget (Position,
// and Side for small widgets). Top left is the default.
//
// The grid comes from the screenshot itself: the Home Screen grid is centred, so the
// left edge is (width − medium width) / 2, and a large widget spans two small rows, so
// the row gap is large height − 2 × small height. Widget sizes are the real ones the
// widget reports once it has been on the Home Screen, or a per-iPhone table until then.
// Only the grid's top edge needs the table outright; `offsetY` nudges it where a model
// differs.

enum SpotFamily: Int, Codable, CaseIterable {
    case small, medium, large, max
}

/// The row a widget sits in. A large widget spans two rows, so it is either at the top
/// or starts in the middle row.
enum SlotRow: Int, Codable, CaseIterable, AppEnum {
    case top, middle, bottom

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Position"
    static let caseDisplayRepresentations: [SlotRow: DisplayRepresentation] = [
        .top: "Top", .middle: "Middle", .bottom: "Bottom",
    ]
}

/// The half of the row a small widget sits in.
enum SlotSide: Int, Codable, CaseIterable, AppEnum {
    case left, right

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Side"
    static let caseDisplayRepresentations: [SlotSide: DisplayRepresentation] = [
        .left: "Left", .right: "Right",
    ]
}

/// One place a widget can sit. Only places that exist: a medium, large or extra-large
/// widget fills the row's width, a large one can't start in the bottom row, and an
/// extra-large one fills the page.
struct HomeSlot: Hashable {
    let family: SpotFamily
    let row: SlotRow
    let side: SlotSide

    init(family: SpotFamily, row: SlotRow, side: SlotSide) {
        self.family = family
        switch family {
        case .small:
            self.row = row
            self.side = side
        case .medium:
            self.row = row
            self.side = .left
        case .large:
            self.row = row == .top ? .top : .middle
            self.side = .left
        case .max:
            self.row = .top
            self.side = .left
        }
    }

    /// File name of this slot's piece.
    var key: Int { family.rawValue << 4 | row.rawValue << 1 | side.rawValue }

    static let all: [HomeSlot] = {
        var slots: [HomeSlot] = []
        for family in SpotFamily.allCases {
            for row in SlotRow.allCases {
                for side in SlotSide.allCases {
                    let slot = HomeSlot(family: family, row: row, side: side)
                    if !slots.contains(slot) { slots.append(slot) }
                }
            }
        }
        return slots
    }()
}

/// The widget grid of one iPhone's Home Screen, in screenshot pixels.
struct HomeGrid: Equatable {
    var small: CGSize
    var medium: CGSize
    var large: CGSize
    var max: CGSize
    var left: CGFloat
    var top: CGFloat
    var rowGap: CGFloat

    /// Where `slot` sits in the screenshot.
    func rect(for slot: HomeSlot) -> CGRect {
        let size: CGSize
        switch slot.family {
        case .small: size = small
        case .medium: size = medium
        case .large: size = large
        case .max: size = max
        }
        let x = slot.side == .right ? left + medium.width - small.width : left
        let y = top + CGFloat(slot.row.rawValue) * (small.height + rowGap)
        return CGRect(x: x, y: y, width: size.width, height: size.height).integral
    }

    /// Home Screen layouts on iOS 27, keyed by screenshot height in pixels: small widget
    /// side, medium width, large height, top edge of the grid. Sizes are replaced by the
    /// widget's real ones once known; the top edge is the part only this table gives.
    ///
    /// Source: the community-measured iOS 18 tables (Scriptable "invisible widget"
    /// scripts), moved down 4 pt for iOS 27. That shift is measured on a 17 Pro (2622,
    /// 261 px on iOS 18, 273 px on iOS 27), and it matches the iOS 18 values reported for
    /// the 12 mini and XS against the older tables. Settings › Wallpaper's nudge covers
    /// a model that still sits differently, and Home Screens with large icons.
    private static let table: [Int: (small: CGFloat, medium: CGFloat, large: CGFloat, top: CGFloat)] = [
        2868: (510, 1092, 1146, 288),   // 16 Pro Max, 17 Pro Max
        2796: (510, 1092, 1146, 264),   // 14 Pro Max, 15 Plus, 15 Pro Max, 16 Plus
        2778: (510, 1092, 1146, 228),   // 12 Pro Max, 13 Pro Max, 14 Plus
        2736: (498, 1062, 1122, 279),   // Air (estimated between 2622 and 2868)
        2688: (507, 1080, 1137, 210),   // 11 Pro Max
        2622: (486, 1032, 1098, 273),   // 16 Pro, 17, 17 Pro (measured on iOS 27)
        2556: (474, 1017, 1062, 252),   // 14 Pro, 15, 15 Pro, 16
        2532: (474, 1014, 1062, 213),   // 12, 12 Pro, 13, 13 Pro, 14, 16e
        2436: (465, 987, 1035, 195),    // 11 Pro (12 mini and 13 mini: see `miniTop`)
        1792: (338, 720, 758, 148),     // 11
        1334: (296, 642, 648, 68),      // SE (2nd and 3rd generation)
    ]

    /// Raised whenever `table` changes, so pieces cut with older values are cut again.
    static let tableVersion = 2

    /// The 12 mini and 13 mini render at 1125 × 2436 like the 11 Pro, with the grid lower.
    private static let miniTop: CGFloat = 213

    /// The grid for a screenshot `width` × `height` pixels taken at `scale` pixels per
    /// point. `sizes` are the real widget sizes in points the widget reported;
    /// `offsetY` (points) moves the whole grid down, or up when negative. `isMini` tells
    /// a 12 mini or 13 mini from an 11 Pro, which share the screenshot size.
    static func make(width: CGFloat, height: CGFloat, scale: CGFloat,
                     sizes: [SpotFamily: CGSize], offsetY: CGFloat, isMini: Bool = false) -> HomeGrid {
        var known = table[Int(height.rounded())]
        if isMini, Int(height.rounded()) == 2436 { known?.top = miniTop }
        func reported(_ family: SpotFamily) -> CGSize? {
            sizes[family].map { CGSize(width: $0.width * scale, height: $0.height * scale) }
        }
        // Without a table entry: proportions shared by every iPhone in the table.
        let smallSide = known?.small ?? (width * 0.402).rounded()
        let small = reported(.small) ?? CGSize(width: smallSide, height: smallSide)
        let mediumWidth = known?.medium ?? (width * 0.856).rounded()
        let medium = reported(.medium) ?? CGSize(width: mediumWidth, height: small.height)
        let largeHeight = known?.large ?? (small.height * 2.24).rounded()
        let large = reported(.large) ?? CGSize(width: medium.width, height: largeHeight)
        let rowGap = Swift.max(0, large.height - 2 * small.height)
        let max = reported(.max) ?? CGSize(width: medium.width, height: 3 * small.height + 2 * rowGap)
        let top = (known?.top ?? (height * 0.1).rounded()) + offsetY * scale
        return HomeGrid(small: small, medium: medium, large: large, max: max,
                        left: ((width - medium.width) / 2).rounded(), top: top.rounded(), rowGap: rowGap)
    }
}

struct SeeThroughState: Codable, Hashable {
    /// The bright (Light Mode) wallpaper screenshot.
    var hasWallpaper = false
    /// The same Home Screen page in Dark Mode. Both are cut at the same slots: widgets
    /// don't move when the appearance changes.
    var hasDarkWallpaper = false
    /// Moves every piece down (or up when negative), in points, for an iPhone whose grid
    /// sits a little differently from the table.
    var offsetY: Double = 0
    /// What the pieces were last cut for. When it changes (new screenshot, new real
    /// widget sizes, a nudge) the app cuts them again.
    var cutSignature = ""

    /// Both screenshots are in: every slot has a piece for Light and Dark Mode.
    var isComplete: Bool { hasWallpaper && hasDarkWallpaper }

    init() {}

    enum CodingKeys: String, CodingKey { case hasWallpaper, hasDarkWallpaper, offsetY, cutSignature }

    // Builds that matched widgets with a pink screenshot stored more; those fields are
    // simply ignored.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hasWallpaper = try c.decodeIfPresent(Bool.self, forKey: .hasWallpaper) ?? false
        hasDarkWallpaper = try c.decodeIfPresent(Bool.self, forKey: .hasDarkWallpaper) ?? false
        offsetY = try c.decodeIfPresent(Double.self, forKey: .offsetY) ?? 0
        cutSignature = try c.decodeIfPresent(String.self, forKey: .cutSignature) ?? ""
    }
}

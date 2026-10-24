import SwiftUI
import UIKit

/// The spacing scale. Every gap in the faces is one of these, or a share of the type
/// size from `Typography` — never a one-off constant.
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

/// The type scale for widget faces, as ratios of the word size the person picked.
/// Gaps scale with the type, so a layout that has to shrink shrinks evenly.
enum Typography {
    /// Word size range offered in the app (points).
    static let nameRange: ClosedRange<Double> = 12...34

    /// The clock's big line. Smaller on a small widget, where it used to crowd out the apps.
    static func clockRatio(_ size: FaceSize) -> Double {
        switch size {
        case .small: return 1.5
        case .medium: return 1.9
        case .large: return 2.4
        }
    }

    /// The date line under the clock.
    static let dateRatio = 0.75
    /// A weekday shown in place of the time (the "date" clock).
    static let weekdayRatio = 0.62
    /// Between rows of names, times the look's spacing.
    static let rowGapRatio = 0.45
    /// Between columns of names.
    static let columnGapRatio = 0.9
    /// Between the clock and the names, times the look's spacing.
    static let blockGapRatio = 0.6
    /// The clock may shrink to these before the names shrink at all.
    static let clockScales: [Double] = [1, 0.85, 0.72, 0.6]
    /// Below this the layout stops shrinking and clips instead. 0.4 is the lowest the
    /// acceptance matrix needs (12 names, 26 pt, clock, small widget) — see CHANGES.md.
    static let minimumScale = 0.4
    /// Measuring is exact to the point; this keeps a hair of room for rounding.
    static let measureSlack: CGFloat = 1.5

    /// How much larger or smaller the person's text-size setting makes the words.
    /// The fit then shrinks the block again if it no longer fits, so a large setting
    /// can never clip.
    static func dynamicFactor(_ size: DynamicTypeSize) -> Double {
        switch size {
        case .xSmall: return 0.88
        case .small: return 0.92
        case .medium: return 0.96
        case .large: return 1
        case .xLarge: return 1.06
        case .xxLarge: return 1.12
        case .xxxLarge: return 1.18
        default: return 1.24 // accessibility sizes, capped: a widget is a fixed box
        }
    }
}

extension FaceSize {
    init(_ family: SpotFamily) {
        switch family {
        case .small: self = .small
        case .medium: self = .medium
        case .large, .max: self = .large
        }
    }

    var spotFamily: SpotFamily {
        switch self {
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        }
    }
}

/// Real widget sizes, so the in-app preview is drawn at the same point size as the
/// widget (then scaled to fit the card) instead of being re-laid out at another size.
enum FaceMetrics {
    /// What the widget reported for this family, else Apple's table for this screen.
    static func geometry(for size: FaceSize) -> FaceGeometry {
        let reported = SharedStore.shared.loadGeometry()[size.spotFamily]
        let fallback = tableSize(size, screenWidth: screenWidth)
        return FaceGeometry(size: reported?.size ?? fallback, margins: reported?.margins)
    }

    /// The system's content margin when the widget hasn't reported its own yet.
    static let defaultMargin: CGFloat = Spacing.m

    static func margins(_ geometry: FaceGeometry) -> EdgeInsets {
        geometry.margins ?? EdgeInsets(top: defaultMargin, leading: defaultMargin,
                                       bottom: defaultMargin, trailing: defaultMargin)
    }

    /// Portrait screen width in points. The app sets it at launch (UIApplication is off
    /// limits in the widget extension, which never needs the table anyway).
    static var screenWidth: CGFloat = 393

    /// Apple's published widget sizes in points, by portrait screen width. The 402 and
    /// 440 rows are interpolated; the widget's own report replaces them on first run.
    static func tableSize(_ size: FaceSize, screenWidth: CGFloat) -> CGSize {
        let rows: [(width: CGFloat, small: CGFloat, mediumWidth: CGFloat, largeHeight: CGFloat)] = [
            (440, 172, 368, 386),
            (430, 170, 364, 382),
            (428, 170, 364, 382),
            (414, 169, 360, 379),
            (402, 164, 350, 368),
            (393, 158, 338, 354),
            (390, 158, 338, 354),
            (375, 155, 329, 345),
            (360, 155, 329, 345),
            (320, 141, 292, 311),
        ]
        let row = rows.first { screenWidth >= $0.width - 0.5 } ?? rows[rows.count - 1]
        switch size {
        case .small: return CGSize(width: row.small, height: row.small)
        case .medium: return CGSize(width: row.mediumWidth, height: row.small)
        case .large: return CGSize(width: row.mediumWidth, height: row.largeHeight)
        }
    }
}

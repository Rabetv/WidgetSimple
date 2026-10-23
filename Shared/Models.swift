import Foundation
import SwiftUI
import AppIntents

// MARK: - Look

enum TextAlign: String, Codable, CaseIterable, Identifiable {
    case left, center, right
    var id: String { rawValue }

    var title: String {
        switch self {
        case .left: return "Left"
        case .center: return "Center"
        case .right: return "Right"
        }
    }

    var horizontal: HorizontalAlignment {
        switch self {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }

    var text: TextAlignment {
        switch self {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
}

/// Where the block of words sits on the widget.
enum TextVAlign: String, Codable, CaseIterable, Identifiable {
    case top, middle, bottom
    var id: String { rawValue }

    var title: String {
        switch self {
        case .top: return "Top"
        case .middle: return "Middle"
        case .bottom: return "Bottom"
        }
    }

    var vertical: VerticalAlignment {
        switch self {
        case .top: return .top
        case .middle: return .center
        case .bottom: return .bottom
        }
    }
}

enum LetterCase: String, Codable, CaseIterable, Identifiable {
    case normal, upper
    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: return "Aa"
        case .upper: return "AA"
        }
    }

    var textCase: Text.Case? {
        switch self {
        case .normal: return nil
        case .upper: return .uppercase
        }
    }
}

enum TextTone: String, Codable, CaseIterable, Identifiable {
    case white, black, custom
    var id: String { rawValue }

    var title: String {
        switch self {
        case .white: return "White"
        case .black: return "Black"
        case .custom: return "Custom"
        }
    }

    /// The colour for this tone; `.custom` uses `customHex`.
    func color(customHex: String = "#FFFFFF") -> Color {
        switch self {
        case .white: return .white
        case .black: return .black
        case .custom: return Color(hex: customHex)
        }
    }
}

/// How every widget looks. Set in the app and shared with the widget through the App
/// Group, so every widget on the Home Screen keeps the same look.
struct Look: Codable, Hashable {
    var tone: TextTone = .white
    var customHex: String = "#FFFFFF"
    var fontID: String = FontCatalog.systemID
    /// Word size in points. Replaces the old small/medium/big steps.
    var size: Double = 21
    var align: TextAlign = .left
    var vAlign: TextVAlign = .top
    var letterCase: LetterCase = .normal
    /// Soft shadow behind the words, for bright wallpapers.
    var shadow: Bool = false
    /// Line spacing multiplier: 0.6 tight … 2.0 airy.
    var spacing: Double = 1.0

    init() {}

    enum CodingKeys: String, CodingKey {
        case tone, customHex, fontID, size, align, vAlign, letterCase, shadow, spacing
    }

    /// The key an old look stored the size under; decode only, never encoded.
    private enum LegacyKeys: String, CodingKey { case textSize }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Look()
        tone = (try? c.decodeIfPresent(TextTone.self, forKey: .tone)) ?? d.tone
        customHex = try c.decodeIfPresent(String.self, forKey: .customHex) ?? d.customHex
        fontID = try c.decodeIfPresent(String.self, forKey: .fontID) ?? d.fontID
        align = (try? c.decodeIfPresent(TextAlign.self, forKey: .align)) ?? d.align
        vAlign = (try? c.decodeIfPresent(TextVAlign.self, forKey: .vAlign)) ?? d.vAlign
        letterCase = (try? c.decodeIfPresent(LetterCase.self, forKey: .letterCase)) ?? d.letterCase
        shadow = try c.decodeIfPresent(Bool.self, forKey: .shadow) ?? d.shadow
        spacing = try c.decodeIfPresent(Double.self, forKey: .spacing) ?? d.spacing

        if let legacy = try? decoder.container(keyedBy: LegacyKeys.self).decodeIfPresent(TextSize.self, forKey: .textSize) {
            size = legacy.points // old small/medium/big values
        } else {
            size = try c.decodeIfPresent(Double.self, forKey: .size) ?? d.size
        }
        size = min(max(size, 10), 44)
    }

    var color: Color { tone.color(customHex: customHex) }

    func font(size: Double, weight: Font.Weight = .regular) -> Font {
        FontCatalog.font(id: fontID, size: size, weight: weight)
    }

    /// The block alignment, both axes.
    var alignment: Alignment { Alignment(horizontal: align.horizontal, vertical: vAlign.vertical) }
}

/// Kept only to migrate old stored looks; new looks store a plain point size.
enum TextSize: String, Codable {
    case small, medium, big
    var points: Double {
        switch self {
        case .small: return 17
        case .medium: return 21
        case .big: return 26
        }
    }
}

// MARK: - Clock

/// The clock a widget shows above (or beside) its apps. Picked in the app.
enum ClockOption: String, Codable, CaseIterable, AppEnum {
    case off, time, timeAndDate, date

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Clock"
    static let caseDisplayRepresentations: [ClockOption: DisplayRepresentation] = [
        .off: "No clock",
        .time: "Time",
        .timeAndDate: "Time and date",
        .date: "Date",
    ]

    var title: String {
        String(localized: Self.caseDisplayRepresentations[self]?.title
               ?? LocalizedStringResource(stringLiteral: rawValue))
    }
}

// MARK: - Colour

extension Color {
    /// "#RRGGBB" or "#RRGGBBAA"; falls back to white.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        switch cleaned.count {
        case 8:
            self.init(.sRGB,
                      red: Double((value >> 24) & 0xFF) / 255,
                      green: Double((value >> 16) & 0xFF) / 255,
                      blue: Double((value >> 8) & 0xFF) / 255,
                      opacity: Double(value & 0xFF) / 255)
        case 6:
            self.init(.sRGB,
                      red: Double((value >> 16) & 0xFF) / 255,
                      green: Double((value >> 8) & 0xFF) / 255,
                      blue: Double(value & 0xFF) / 255)
        default:
            self = .white
        }
    }
}

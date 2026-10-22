import Foundation
import SwiftUI
import UIKit
import AppIntents

// MARK: - Color

/// A Codable sRGB color.
struct RGBA: Codable, Hashable {
    var r: Double
    var g: Double
    var b: Double

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
    var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
}

// MARK: - Theme

/// The one color of the whole Home Screen: the wallpaper and every widget share it.
///
/// Widgets are filled with exactly the wallpaper color, so they can't be told apart
/// from it. iOS also draws a glass edge on every widget; with a plain wallpaper and
/// the settings below it disappears (iOS 27).
enum Theme: String, Codable, CaseIterable, Identifiable {
    case black, gray, white
    var id: String { rawValue }

    var title: String {
        switch self {
        case .black: return "Black"
        case .gray: return "Gray"
        case .white: return "White"
        }
    }

    var background: RGBA {
        switch self {
        case .black: return RGBA(r: 0, g: 0, b: 0)
        case .gray: return RGBA(r: 0.45, g: 0.45, b: 0.47)
        case .white: return RGBA(r: 1, g: 1, b: 1)
        }
    }

    var text: RGBA {
        self == .white ? RGBA(r: 0, g: 0, b: 0) : RGBA(r: 1, g: 1, b: 1)
    }

    // iPhone settings that hide the glass edge for this color.
    var darkMode: Bool { self != .white }
    var increaseContrast: Bool { self == .black }
    var showBorders: Bool { self == .white }
}

// MARK: - Look

enum TextSize: String, Codable, CaseIterable, Identifiable {
    case small, medium, big
    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .big: return "Big"
        }
    }

    var points: Double {
        switch self {
        case .small: return 17
        case .medium: return 21
        case .big: return 26
        }
    }
}

/// How every widget looks. Set in the app; the apps and the clock are picked per widget.
struct Look: Codable, Hashable {
    var theme: Theme = .black
    var fontID: String = FontCatalog.systemID
    var textSize: TextSize = .medium

    init() {}

    enum CodingKeys: String, CodingKey { case theme, fontID, textSize }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Look()
        theme = (try? c.decodeIfPresent(Theme.self, forKey: .theme)) ?? d.theme
        fontID = try c.decodeIfPresent(String.self, forKey: .fontID) ?? d.fontID
        textSize = (try? c.decodeIfPresent(TextSize.self, forKey: .textSize)) ?? d.textSize
    }

    func font(size: Double, weight: Font.Weight = .regular) -> Font {
        FontCatalog.font(id: fontID, size: size, weight: weight)
    }
}

// MARK: - Clock

/// The clock a widget shows above (or beside) its apps. Picked in Edit Widget.
enum ClockOption: String, CaseIterable, AppEnum {
    case off, time, timeAndDate

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Clock"
    static let caseDisplayRepresentations: [ClockOption: DisplayRepresentation] = [
        .off: "No clock",
        .time: "Time",
        .timeAndDate: "Time and date",
    ]
}

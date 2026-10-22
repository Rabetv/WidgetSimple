import Foundation
import SwiftUI
import AppIntents

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

/// The widget's own see-through background, drawn on the normal Home Screen.
enum BackgroundStyle: String, Codable, CaseIterable, Identifiable {
    /// iOS 26 Liquid Glass, clear variant: the wallpaper shows through, with a glossy edge.
    case glass
    /// Liquid Glass, regular variant: a little more blur.
    case frosted
    /// No glass, just a nearly invisible fill.
    case clear
    var id: String { rawValue }

    var title: String {
        switch self {
        case .glass: return "Glass"
        case .frosted: return "Frosted"
        case .clear: return "Clear"
        }
    }
}

enum TextTone: String, Codable, CaseIterable, Identifiable {
    case white, black
    var id: String { rawValue }

    var title: String {
        switch self {
        case .white: return "White"
        case .black: return "Black"
        }
    }

    var color: Color { self == .white ? .white : .black }
}

/// How every widget looks. Set in the app; the apps and the clock are picked per widget.
struct Look: Codable, Hashable {
    var background: BackgroundStyle = .glass
    var tone: TextTone = .white
    var fontID: String = FontCatalog.systemID
    var textSize: TextSize = .medium
    var align: TextAlign = .left

    init() {}

    enum CodingKeys: String, CodingKey { case background, tone, fontID, textSize, align }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Look()
        background = (try? c.decodeIfPresent(BackgroundStyle.self, forKey: .background)) ?? d.background
        tone = (try? c.decodeIfPresent(TextTone.self, forKey: .tone)) ?? d.tone
        fontID = try c.decodeIfPresent(String.self, forKey: .fontID) ?? d.fontID
        textSize = (try? c.decodeIfPresent(TextSize.self, forKey: .textSize)) ?? d.textSize
        align = (try? c.decodeIfPresent(TextAlign.self, forKey: .align)) ?? d.align
    }

    func font(size: Double, weight: Font.Weight = .regular) -> Font {
        FontCatalog.font(id: fontID, size: size, weight: weight)
    }
}

// MARK: - Clock

/// The clock a widget shows above (or beside) its apps. Picked in Edit Widget.
enum ClockOption: String, CaseIterable, AppEnum {
    case off, time, timeAndDate, date

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Clock"
    static let caseDisplayRepresentations: [ClockOption: DisplayRepresentation] = [
        .off: "No clock",
        .time: "Time",
        .timeAndDate: "Time and date",
        .date: "Date",
    ]
}

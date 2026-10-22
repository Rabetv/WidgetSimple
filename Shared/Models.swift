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

/// How every widget looks. Set in the app; the apps and the clock are picked per widget.
/// The background is always the system's: clear glass on a Clear or Tinted Home Screen.
struct Look: Codable, Hashable {
    var fontID: String = FontCatalog.systemID
    var textSize: TextSize = .medium
    var align: TextAlign = .left

    init() {}

    enum CodingKeys: String, CodingKey { case fontID, textSize, align }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Look()
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

import Foundation
import SwiftUI
import UIKit

/// A named arrangement made in the app's layout editor and picked per widget in Edit
/// Widget (`LayoutEntity`). Stored as `Layouts/<id>.json` in the App Group.
///
/// App names are only known to the widget (iOS resolves them in Edit Widget), so
/// everything here is keyed by slot: slot 0 is the first app picked.
struct LayoutDocument: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var name: String = "Layout"
    /// The widget size the editor drew this on; positions are shares of that canvas.
    var family: SpotFamily = .medium
    var mode: LayoutMode = .columns
    /// 0 picks the column count automatically; 1…4 forces it.
    var columns: Int = 0
    /// Multipliers on the look's spacing.
    var rowSpacing: Double = 1
    var columnSpacing: Double = 1
    /// Moves the whole block up (negative) or down, in points.
    var verticalOffset: Double = 0
    /// Free placement: one entry per slot that was moved.
    var items: [LayoutItem] = []
    /// Free placement of the clock, if it was moved.
    var clockItem: LayoutItem?
    /// Per-name weight, opacity and colour.
    var styles: [NameStyle] = []

    init() {}

    enum CodingKeys: String, CodingKey {
        case id, name, family, mode, columns, rowSpacing, columnSpacing, verticalOffset, items, clockItem, styles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = LayoutDocument()
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? d.id
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? d.name
        family = (try? c.decodeIfPresent(SpotFamily.self, forKey: .family)) ?? d.family
        mode = (try? c.decodeIfPresent(LayoutMode.self, forKey: .mode)) ?? d.mode
        columns = min(max(try c.decodeIfPresent(Int.self, forKey: .columns) ?? 0, 0), 4)
        rowSpacing = try c.decodeIfPresent(Double.self, forKey: .rowSpacing) ?? d.rowSpacing
        columnSpacing = try c.decodeIfPresent(Double.self, forKey: .columnSpacing) ?? d.columnSpacing
        verticalOffset = try c.decodeIfPresent(Double.self, forKey: .verticalOffset) ?? d.verticalOffset
        items = (try? c.decodeIfPresent([LayoutItem].self, forKey: .items)) ?? []
        clockItem = try? c.decodeIfPresent(LayoutItem.self, forKey: .clockItem)
        styles = (try? c.decodeIfPresent([NameStyle].self, forKey: .styles)) ?? []
    }

    func item(for slot: Int) -> LayoutItem? { items.first { $0.slot == slot } }
    func style(for slot: Int) -> NameStyle? { styles.first { $0.slot == slot } }

    mutating func setItem(_ item: LayoutItem) {
        items.removeAll { $0.slot == item.slot }
        items.append(item)
    }

    mutating func setStyle(_ style: NameStyle) {
        styles.removeAll { $0.slot == style.slot }
        if !style.isEmpty { styles.append(style) }
    }

    /// One line for pickers: "Free · 4 names" or "2 columns".
    var summary: String {
        switch mode {
        case .freeform:
            return String(localized: "Free · \(items.count) placed")
        case .columns:
            return columns == 0 ? String(localized: "Columns · automatic") : String(localized: "\(columns) columns")
        }
    }

    /// The editor's grid: names snap to these lines.
    static let gridColumns = 12
    static let gridRows = 8

    static func snap(_ value: Double, steps: Int) -> Double {
        (value * Double(steps)).rounded() / Double(steps)
    }
}

enum LayoutMode: String, Codable, CaseIterable, Identifiable {
    case columns, freeform
    var id: String { rawValue }

    var title: String {
        switch self {
        case .columns: return String(localized: "Columns")
        case .freeform: return String(localized: "Free")
        }
    }
}

/// Where one name (or the clock) sits: its centre as a share of the widget, 0…1.
struct LayoutItem: Codable, Hashable {
    var slot: Int
    var x: Double
    var y: Double
    var scale: Double = 1
    /// Degrees.
    var rotation: Double = 0

    init(slot: Int, x: Double, y: Double, scale: Double = 1, rotation: Double = 0) {
        self.slot = slot
        self.x = x
        self.y = y
        self.scale = scale
        self.rotation = rotation
    }

    enum CodingKeys: String, CodingKey { case slot, x, y, scale, rotation }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slot = try c.decode(Int.self, forKey: .slot)
        x = min(max(try c.decode(Double.self, forKey: .x), 0), 1)
        y = min(max(try c.decode(Double.self, forKey: .y), 0), 1)
        scale = min(max(try c.decodeIfPresent(Double.self, forKey: .scale) ?? 1, 0.4), 3)
        rotation = try c.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
    }
}

/// Overrides for one name; nil fields follow the look.
struct NameStyle: Codable, Hashable {
    var slot: Int
    var weight: NameWeight?
    var opacity: Double?
    var colorHex: String?

    var isEmpty: Bool { weight == nil && opacity == nil && colorHex == nil }
}

enum NameWeight: String, Codable, CaseIterable, Identifiable {
    case light, regular, medium, semibold, bold
    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return String(localized: "Light")
        case .regular: return String(localized: "Regular")
        case .medium: return String(localized: "Medium")
        case .semibold: return String(localized: "Semibold")
        case .bold: return String(localized: "Bold")
        }
    }

    var font: Font.Weight {
        switch self {
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }

    var uiKit: UIFont.Weight {
        switch self {
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

/// A picture for the Photo widget: from the bundled stock library (copied into the
/// App Group by the app) or imported by the person.
struct PhotoAsset: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    /// File name inside `Photos/`.
    var file: String
    var credit: String?
    var licence: String?
    var source: String?
    /// The point that must stay in view when the photo is cropped, as shares 0…1.
    var focalX: Double = 0.5
    var focalY: Double = 0.5
    var isStock: Bool = false
}

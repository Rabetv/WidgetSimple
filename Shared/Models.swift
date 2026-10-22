import Foundation
import SwiftUI
import UIKit

// MARK: - Color

/// A Codable sRGB color.
struct RGBA: Codable, Hashable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    init(_ color: Color) {
        self.init(UIColor(color))
    }

    init(_ uiColor: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if !uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            var white: CGFloat = 0
            uiColor.getWhite(&white, alpha: &a)
            r = white; g = white; b = white
        }
        func clamp(_ v: CGFloat) -> Double { Double(min(max(v, 0), 1)) }
        self.init(r: clamp(r), g: clamp(g), b: clamp(b), a: clamp(a))
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
    var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: a) }
    /// Perceived brightness, 0 (black) to 1 (white).
    var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }

    static let white = RGBA(r: 1, g: 1, b: 1)
    static let black = RGBA(r: 0, g: 0, b: 0)
    static let shadow = RGBA(r: 0, g: 0, b: 0, a: 0.55)
    static let charcoal = RGBA(r: 0.11, g: 0.11, b: 0.12)
}

/// A rectangle in screenshot pixels.
struct PixelRect: Codable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }

    init(_ rect: CGRect) {
        self.init(x: Double(rect.origin.x), y: Double(rect.origin.y),
                  width: Double(rect.size.width), height: Double(rect.size.height))
    }
}

struct PixelSize: Codable, Hashable {
    var width: Double
    var height: Double
    var cgSize: CGSize { CGSize(width: width, height: height) }
}

// MARK: - Text style

enum FontWeightOption: String, Codable, CaseIterable, Identifiable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black
    var id: String { rawValue }

    var title: String {
        switch self {
        case .ultraLight: return "Ultra Light"
        case .thin: return "Thin"
        case .light: return "Light"
        case .regular: return "Regular"
        case .medium: return "Medium"
        case .semibold: return "Semibold"
        case .bold: return "Bold"
        case .heavy: return "Heavy"
        case .black: return "Black"
        }
    }

    var weight: Font.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
}

enum TextCaseOption: String, Codable, CaseIterable, Identifiable {
    case asTyped, uppercase, lowercase
    var id: String { rawValue }
    var title: String {
        switch self {
        case .asTyped: return "As typed"
        case .uppercase: return "UPPERCASE"
        case .lowercase: return "lowercase"
        }
    }
    func apply(_ s: String) -> String {
        switch self {
        case .asTyped: return s
        case .uppercase: return s.uppercased()
        case .lowercase: return s.lowercased()
        }
    }
}

struct TextStyle: Codable, Hashable {
    var fontID: String = FontCatalog.systemID
    var size: Double = 20
    var weight: FontWeightOption = .regular
    var italic: Bool = false
    var underline: Bool = false
    var color: RGBA = .white
    var tracking: Double = 0
    var textCase: TextCaseOption = .asTyped
    var shadow: Bool = false
    var shadowRadius: Double = 3
    var shadowColor: RGBA = .shadow

    init() {}

    enum CodingKeys: String, CodingKey {
        case fontID, size, weight, italic, underline, color, tracking, textCase, shadow, shadowRadius, shadowColor
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = TextStyle()
        fontID = try c.decodeIfPresent(String.self, forKey: .fontID) ?? d.fontID
        size = try c.decodeIfPresent(Double.self, forKey: .size) ?? d.size
        weight = (try? c.decodeIfPresent(FontWeightOption.self, forKey: .weight)) ?? d.weight
        italic = try c.decodeIfPresent(Bool.self, forKey: .italic) ?? d.italic
        underline = try c.decodeIfPresent(Bool.self, forKey: .underline) ?? d.underline
        color = try c.decodeIfPresent(RGBA.self, forKey: .color) ?? d.color
        tracking = try c.decodeIfPresent(Double.self, forKey: .tracking) ?? d.tracking
        textCase = (try? c.decodeIfPresent(TextCaseOption.self, forKey: .textCase)) ?? d.textCase
        shadow = try c.decodeIfPresent(Bool.self, forKey: .shadow) ?? d.shadow
        shadowRadius = try c.decodeIfPresent(Double.self, forKey: .shadowRadius) ?? d.shadowRadius
        shadowColor = try c.decodeIfPresent(RGBA.self, forKey: .shadowColor) ?? d.shadowColor
    }
}

// MARK: - Launch targets

enum TargetKind: String, Codable, CaseIterable, Identifiable {
    case app, urlScheme, website, shortcut
    var id: String { rawValue }
    var title: String {
        switch self {
        case .app: return "App"
        case .urlScheme: return "URL scheme"
        case .website: return "Website"
        case .shortcut: return "Shortcut"
        }
    }
}

struct LaunchTarget: Codable, Hashable {
    var kind: TargetKind = .app
    /// Catalog id when `kind == .app`.
    var catalogID: String? = nil
    /// URL string for app / urlScheme / website, shortcut name for shortcut.
    var value: String = ""

    init(kind: TargetKind = .app, catalogID: String? = nil, value: String = "") {
        self.kind = kind
        self.catalogID = catalogID
        self.value = value
    }

    /// The URL that actually gets opened.
    var url: URL? {
        var v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // Catalog apps use the catalog's current link, so fixed links reach existing widgets.
        if kind == .app, let id = catalogID, let app = AppCatalog.app(id: id) { v = app.url }
        guard !v.isEmpty else { return nil }
        switch kind {
        case .app, .urlScheme:
            if v.contains(":") { return URL(string: v) }
            return URL(string: v + "://")
        case .website:
            let lower = v.lowercased()
            if lower.hasPrefix("http://") || lower.hasPrefix("https://") { return URL(string: v) }
            return URL(string: "https://" + v)
        case .shortcut:
            var comps = URLComponents()
            comps.scheme = "shortcuts"
            comps.host = "run-shortcut"
            comps.queryItems = [URLQueryItem(name: "name", value: v)]
            return comps.url
        }
    }

    var summary: String {
        switch kind {
        case .app:
            if let id = catalogID, let app = AppCatalog.app(id: id) { return app.name }
            return value
        case .urlScheme: return value
        case .website: return value
        case .shortcut: return "Shortcut: \(value)"
        }
    }
}

struct LaunchItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var label: String
    var target: LaunchTarget
    /// When false the layout's default text style is used.
    var useCustomStyle: Bool = false
    var style: TextStyle = TextStyle()
    /// Optional SF Symbol name. Empty means text only.
    var symbol: String = ""

    init(label: String, target: LaunchTarget, useCustomStyle: Bool = false, style: TextStyle = TextStyle(), symbol: String = "") {
        self.label = label
        self.target = target
        self.useCustomStyle = useCustomStyle
        self.style = style
        self.symbol = symbol
    }

    enum CodingKeys: String, CodingKey { case id, label, target, useCustomStyle, style, symbol }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        target = try c.decodeIfPresent(LaunchTarget.self, forKey: .target) ?? LaunchTarget()
        useCustomStyle = try c.decodeIfPresent(Bool.self, forKey: .useCustomStyle) ?? false
        style = try c.decodeIfPresent(TextStyle.self, forKey: .style) ?? TextStyle()
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? ""
    }

    static func from(app: CatalogApp) -> LaunchItem {
        LaunchItem(label: app.name, target: LaunchTarget(kind: .app, catalogID: app.id, value: app.url))
    }
}

// MARK: - Layout

enum ArrangementKind: String, Codable, CaseIterable, Identifiable {
    case grid, flow
    var id: String { rawValue }
    var title: String {
        switch self {
        case .grid: return "Grid / list"
        case .flow: return "Flowing text"
        }
    }
}

enum HAlignOption: String, Codable, CaseIterable, Identifiable {
    case leading, center, trailing
    var id: String { rawValue }
    var title: String {
        switch self {
        case .leading: return "Left"
        case .center: return "Center"
        case .trailing: return "Right"
        }
    }
    var horizontal: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
    var textAlignment: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

enum VAlignOption: String, Codable, CaseIterable, Identifiable {
    case top, center, bottom, spread
    var id: String { rawValue }
    var title: String {
        switch self {
        case .top: return "Top"
        case .center: return "Middle"
        case .bottom: return "Bottom"
        case .spread: return "Spread out"
        }
    }
}

enum WidgetSizeOption: String, Codable, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

enum BackgroundMode: String, Codable, CaseIterable, Identifiable {
    case color
    /// A pixel copy of the wallpaper behind the widget.
    case wallpaper
    var id: String { rawValue }
    var title: String {
        switch self {
        case .color: return "Color"
        case .wallpaper: return "Wallpaper"
        }
    }
}

struct BackgroundSettings: Codable, Hashable {
    var mode: BackgroundMode = .color
    var color: RGBA = .black
    /// Optional separate color for Dark Mode (solid color mode).
    var darkColor: RGBA? = nil
    /// Where the widget sits in the screenshot (pixels).
    var cropRect: PixelRect? = nil
    var screenshotSize: PixelSize? = nil
    var hasLightImage: Bool = false
    var hasDarkImage: Bool = false
    var imageVersion: Int = 0

    init() {}

    enum CodingKeys: String, CodingKey {
        case mode, color, darkColor, cropRect, screenshotSize, hasLightImage, hasDarkImage, imageVersion
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawMode = try? c.decodeIfPresent(String.self, forKey: .mode)
        color = try c.decodeIfPresent(RGBA.self, forKey: .color) ?? .black
        if rawMode == "transparent" {
            // Older builds offered "Transparent", but iOS draws its own gray box behind
            // a clear widget. Those layouts become black.
            mode = .color
            color = .black
        } else {
            mode = rawMode.flatMap { BackgroundMode(rawValue: $0) } ?? .color
        }
        darkColor = try c.decodeIfPresent(RGBA.self, forKey: .darkColor)
        cropRect = try c.decodeIfPresent(PixelRect.self, forKey: .cropRect)
        screenshotSize = try c.decodeIfPresent(PixelSize.self, forKey: .screenshotSize)
        hasLightImage = try c.decodeIfPresent(Bool.self, forKey: .hasLightImage) ?? false
        hasDarkImage = try c.decodeIfPresent(Bool.self, forKey: .hasDarkImage) ?? false
        imageVersion = try c.decodeIfPresent(Int.self, forKey: .imageVersion) ?? 0
    }

    var isWallpaperReady: Bool { mode == .wallpaper && hasLightImage }
}

struct LauncherLayout: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var items: [LaunchItem] = []
    var arrangement: ArrangementKind = .grid
    var columns: Int = 2
    var alignment: HAlignOption = .leading
    var verticalPosition: VAlignOption = .center
    var rowSpacing: Double = 8
    var columnSpacing: Double = 14
    var paddingH: Double = 20
    var paddingV: Double = 16
    var style: TextStyle = TextStyle()
    var background: BackgroundSettings = BackgroundSettings()
    var size: WidgetSizeOption = .medium
    /// In the Clear / Tinted Home Screen styles iOS turns widget text white.
    /// When true, labels are drawn as full-color images there so fonts and colors stay.
    var keepColorsInClearMode: Bool = true

    init(name: String, items: [LaunchItem] = []) {
        self.name = name
        self.items = items
    }

    enum CodingKeys: String, CodingKey {
        case id, name, items, arrangement, columns, alignment, verticalPosition
        case rowSpacing, columnSpacing, paddingH, paddingV, style, background, size
        case keepColorsInClearMode
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = LauncherLayout(name: "")
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Widget"
        items = try c.decodeIfPresent([LaunchItem].self, forKey: .items) ?? []
        arrangement = (try? c.decodeIfPresent(ArrangementKind.self, forKey: .arrangement)) ?? d.arrangement
        columns = try c.decodeIfPresent(Int.self, forKey: .columns) ?? d.columns
        alignment = (try? c.decodeIfPresent(HAlignOption.self, forKey: .alignment)) ?? d.alignment
        verticalPosition = (try? c.decodeIfPresent(VAlignOption.self, forKey: .verticalPosition)) ?? d.verticalPosition
        rowSpacing = try c.decodeIfPresent(Double.self, forKey: .rowSpacing) ?? d.rowSpacing
        columnSpacing = try c.decodeIfPresent(Double.self, forKey: .columnSpacing) ?? d.columnSpacing
        paddingH = try c.decodeIfPresent(Double.self, forKey: .paddingH) ?? d.paddingH
        paddingV = try c.decodeIfPresent(Double.self, forKey: .paddingV) ?? d.paddingV
        style = try c.decodeIfPresent(TextStyle.self, forKey: .style) ?? d.style
        background = try c.decodeIfPresent(BackgroundSettings.self, forKey: .background) ?? d.background
        size = (try? c.decodeIfPresent(WidgetSizeOption.self, forKey: .size)) ?? d.size
        keepColorsInClearMode = try c.decodeIfPresent(Bool.self, forKey: .keepColorsInClearMode) ?? d.keepColorsInClearMode
    }

    func style(for item: LaunchItem) -> TextStyle {
        item.useCustomStyle ? item.style : style
    }

    static func starter(named name: String = "Home") -> LauncherLayout {
        let ids = ["phone", "messages", "mail", "safari", "music", "maps"]
        let items = ids.compactMap { AppCatalog.app(id: $0) }.map { LaunchItem.from(app: $0) }
        var layout = LauncherLayout(name: name, items: items)
        layout.style.size = 21
        layout.style.weight = .medium
        return layout
    }
}

// MARK: - Settings shared with the widget

struct AppSettings: Codable, Hashable {
    /// While set, widgets showing this layout turn solid magenta so the app
    /// can find their exact position in a screenshot.
    var calibratingLayoutID: UUID? = nil

    init() {}

    enum CodingKeys: String, CodingKey { case calibratingLayoutID }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        calibratingLayoutID = try c.decodeIfPresent(UUID.self, forKey: .calibratingLayoutID)
    }
}

/// Look of the clock widget.
struct ClockStyle: Codable, Hashable {
    var fontID: String = "sys:mono"
    var weight: FontWeightOption = .regular
    var color: RGBA = .white
    var background: RGBA = .black

    init() {}

    enum CodingKeys: String, CodingKey { case fontID, weight, color, background }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ClockStyle()
        fontID = try c.decodeIfPresent(String.self, forKey: .fontID) ?? d.fontID
        weight = (try? c.decodeIfPresent(FontWeightOption.self, forKey: .weight)) ?? d.weight
        color = try c.decodeIfPresent(RGBA.self, forKey: .color) ?? d.color
        background = try c.decodeIfPresent(RGBA.self, forKey: .background) ?? d.background
    }
}

/// Written by the widget extension: the real on-screen size of each widget family, in points.
struct WidgetMetrics: Codable, Hashable {
    var sizes: [String: PixelSize] = [:]

    func size(for option: WidgetSizeOption) -> CGSize? {
        sizes[option.rawValue]?.cgSize
    }
}

/// The color the widget shows while calibrating.
enum CalibrationMarker {
    static let rgba = RGBA(r: 1, g: 0, b: 1)
    static var color: Color { rgba.color }
}

import SwiftUI

/// Where a widget lives. Matches the four tabs of the New Widget sheet.
enum WidgetSurface: String, CaseIterable, Identifiable {
    case home, lock, standby, controls

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return String(localized: "Home")
        case .lock: return String(localized: "Lock")
        case .standby: return String(localized: "StandBy")
        case .controls: return String(localized: "Controls")
        }
    }
}

/// One entry in the New Widget catalogue.
struct WidgetType: Identifiable {
    let id: String
    let glyph: String
    let name: String
    let detail: String
    let surfaces: [WidgetSurface]
    let pro: Bool
    /// False while the widget is only designed, not built: dimmed and not tappable.
    let available: Bool

    static let all: [WidgetType] = [
        WidgetType(id: "launcher", glyph: "Aa", name: "Launcher",
                   detail: "Apps as words. Tap a word, open the app.",
                   surfaces: [.home, .lock, .standby], pro: false, available: true),
        WidgetType(id: "clock", glyph: "◷", name: "Clock",
                   detail: "14 styles, digital and analog, 12 or 24 h.",
                   surfaces: [.home, .lock, .standby], pro: false, available: false),
        WidgetType(id: "wordclock", glyph: "ten", name: "Word Clock",
                   detail: "The time in words: quarter past ten.",
                   surfaces: [.home, .lock, .standby], pro: false, available: false),
        WidgetType(id: "worldclock", glyph: "TZ", name: "World Clock",
                   detail: "Up to four cities, by name.",
                   surfaces: [.home, .lock, .standby], pro: true, available: true),
        WidgetType(id: "photo", glyph: "▣", name: "Photo",
                   detail: "Shuffle an album, pin one, add stickers.",
                   surfaces: [.home, .standby], pro: true, available: false),
        WidgetType(id: "countdown", glyph: "12", name: "Countdown",
                   detail: "Days until, or since, any date.",
                   surfaces: [.home, .lock, .standby], pro: false, available: true),
        WidgetType(id: "calendar", glyph: "31", name: "Calendar",
                   detail: "Up next, or the whole month.",
                   surfaces: [.home, .lock, .standby], pro: true, available: false),
        WidgetType(id: "reminders", glyph: "✓", name: "Reminders",
                   detail: "Tick them off on the widget.",
                   surfaces: [.home, .lock], pro: true, available: false),
        WidgetType(id: "weather", glyph: "21°", name: "Weather",
                   detail: "Now, hourly, and the week ahead.",
                   surfaces: [.home, .lock, .standby], pro: true, available: false),
        WidgetType(id: "text", glyph: "“", name: "Text & Quote",
                   detail: "Your words, or a daily quote.",
                   surfaces: [.home, .lock], pro: false, available: true),
        WidgetType(id: "greeting", glyph: "Hi", name: "Greeting",
                   detail: "Changes with the time of day.",
                   surfaces: [.home, .standby], pro: false, available: false),
        WidgetType(id: "music", glyph: "♪", name: "Music",
                   detail: "Apple Music playlists, one tap to play.",
                   surfaces: [.home, .standby], pro: true, available: false),
        WidgetType(id: "battery", glyph: "▮", name: "Battery",
                   detail: "Your iPhone’s charge at a glance.",
                   surfaces: [.home, .lock], pro: true, available: false),
        WidgetType(id: "dashboard", glyph: "⊞", name: "Dashboard",
                   detail: "Clock, weather, events, battery.",
                   surfaces: [.home, .standby], pro: true, available: false),
        WidgetType(id: "spacer", glyph: "⬚", name: "Spacer",
                   detail: "An invisible blank, any size, no label.",
                   surfaces: [.home], pro: false, available: true),
        WidgetType(id: "appcontrol", glyph: "◉", name: "App Control",
                   detail: "Open any app from Control Center.",
                   surfaces: [.controls], pro: false, available: false),
        WidgetType(id: "shortcutcontrol", glyph: "⟳", name: "Shortcut Control",
                   detail: "Run a shortcut with one tap.",
                   surfaces: [.controls, .lock], pro: true, available: false)
    ]

    static func on(_ surface: WidgetSurface) -> [WidgetType] {
        all.filter { $0.surfaces.contains(surface) }
    }

    /// The name the system gallery shows for this widget.
    var galleryName: String? {
        switch id {
        case "launcher": return "Apps"
        case "text": return "Text"
        case "countdown": return "Countdown"
        case "worldclock": return "World Clock"
        case "spacer": return "Spacer"
        default: return nil
        }
    }
}

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
        WidgetType(id: "clock", glyph: "◷", name: "Date & Time",
                   detail: "Time, date or a calendar page, with a second city.",
                   surfaces: [.home, .lock, .standby], pro: false, available: true),
        WidgetType(id: "wordclock", glyph: "ten", name: "Word Clock",
                   detail: "The time in words: quarter past ten.",
                   surfaces: [.home, .lock, .standby], pro: false, available: false),
        WidgetType(id: "worldclock", glyph: "TZ", name: "World Clock",
                   detail: "Up to four cities, by name.",
                   surfaces: [.home, .lock, .standby], pro: true, available: true),
        WidgetType(id: "photo", glyph: "▣", name: "Photo",
                   detail: "A photo from the library, or shuffle every hour.",
                   surfaces: [.home, .standby], pro: true, available: true),
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
                   surfaces: [.home, .standby], pro: false, available: true),
        WidgetType(id: "zen", glyph: "◯", name: "Zen",
                   detail: "A slow breath and a quiet line, every minute.",
                   surfaces: [.home, .standby], pro: false, available: true),
        // Not built: a widget can't read what another app is playing. The Launcher
        // already opens Music with one tap if it is picked there.
        WidgetType(id: "music", glyph: "♪", name: "Music",
                   detail: "Apple Music playlists, one tap to play.",
                   surfaces: [.home, .standby], pro: true, available: false),
        WidgetType(id: "battery", glyph: "▮", name: "Battery",
                   detail: "Your iPhone’s charge at a glance.",
                   surfaces: [.home, .lock], pro: true, available: true),
        WidgetType(id: "dashboard", glyph: "⊞", name: "Dashboard",
                   detail: "Clock, battery and free storage.",
                   surfaces: [.home, .standby], pro: true, available: true),
        WidgetType(id: "spacer", glyph: "⬚", name: "Spacer",
                   detail: "A blank that shows your wallpaper once matched.",
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
        case "clock": return "Date & Time"
        case "photo": return "Photo"
        case "greeting": return "Greeting"
        case "zen": return "Zen"
        case "battery", "dashboard": return "Dashboard"
        case "text": return "Text"
        case "countdown": return "Countdown"
        case "worldclock": return "World Clock"
        case "spacer": return "Spacer"
        default: return nil
        }
    }
}

import Foundation

/// A known app and the URL that opens it.
///
/// iOS does not let apps list what is installed, so WidgetSimple ships a
/// catalog of well-known URL schemes and checks which of them are on the
/// iPhone. Anything missing can be added as a custom URL scheme or a website.
struct CatalogApp: Identifiable, Hashable {
    let id: String
    let name: String
    let url: String
    let category: Category
    /// True when the scheme is widely documented. Others: use "Test".
    let wellKnown: Bool

    enum Category: String, CaseIterable {
        case apple = "Apple"
        case social = "Social & Messaging"
        case media = "Music & Video"
        case google = "Google"
        case microsoft = "Microsoft"
        case productivity = "Productivity"
        case travel = "Travel & Maps"
        case shopping = "Shopping & Money"
        case browsers = "Browsers"
        case other = "Other"
    }

    init(_ id: String, _ name: String, _ url: String, _ category: Category, wellKnown: Bool = true) {
        self.id = id
        self.name = name
        self.url = url
        self.category = category
        self.wellKnown = wellKnown
    }

    /// The bare scheme, e.g. "spotify".
    var scheme: String {
        if let r = url.range(of: ":") { return String(url[..<r.lowerBound]) }
        return url
    }

    var openURL: URL? { URL(string: url) }
}

enum AppCatalog {
    static let apps: [CatalogApp] = [
        // Apple
        CatalogApp("phone", "Phone", "mobilephone://", .apple, wellKnown: false),
        // sms:, imessage:// and messages:// open a new message on iOS 26; ichat:// opens the app.
        CatalogApp("messages", "Messages", "ichat://", .apple),
        CatalogApp("mail", "Mail", "message://", .apple),
        CatalogApp("safari", "Safari", "x-web-search://", .apple),
        CatalogApp("music", "Music", "music://", .apple),
        CatalogApp("maps", "Maps", "maps://", .apple),
        CatalogApp("photos", "Photos", "photos-redirect://", .apple),
        CatalogApp("calendar", "Calendar", "calshow://", .apple),
        CatalogApp("notes", "Notes", "mobilenotes://", .apple),
        CatalogApp("reminders", "Reminders", "x-apple-reminderkit://", .apple),
        CatalogApp("weather", "Weather", "weather://", .apple),
        CatalogApp("appstore", "App Store", "itms-apps://", .apple),
        CatalogApp("podcasts", "Podcasts", "podcasts://", .apple),
        CatalogApp("shortcuts", "Shortcuts", "shortcuts://", .apple),
        CatalogApp("files", "Files", "shareddocuments://", .apple),
        CatalogApp("health", "Health", "x-apple-health://", .apple),
        CatalogApp("books", "Books", "ibooks://", .apple),
        CatalogApp("tv", "TV", "videos://", .apple),
        CatalogApp("findmy", "Find My", "findmy://", .apple),
        CatalogApp("wallet", "Wallet", "shoebox://", .apple),
        CatalogApp("stocks", "Stocks", "stocks://", .apple),
        CatalogApp("news", "News", "applenews://", .apple),
        CatalogApp("voicememos", "Voice Memos", "voicememos://", .apple),
        CatalogApp("watch", "Watch", "itms-watchs://", .apple),
        CatalogApp("facetime", "FaceTime", "facetime://", .apple, wellKnown: false),
        CatalogApp("clock", "Clock (Alarms)", "clock-alarm://", .apple, wellKnown: false),
        CatalogApp("home", "Home", "com.apple.home://", .apple, wellKnown: false),
        CatalogApp("fitness", "Fitness", "fitnessapp://", .apple, wellKnown: false),
        CatalogApp("translate", "Translate", "translate://", .apple, wellKnown: false),
        CatalogApp("freeform", "Freeform", "freeform://", .apple, wellKnown: false),

        // Social & messaging
        CatalogApp("whatsapp", "WhatsApp", "whatsapp://", .social),
        CatalogApp("instagram", "Instagram", "instagram://", .social),
        CatalogApp("facebook", "Facebook", "fb://", .social),
        CatalogApp("messenger", "Messenger", "fb-messenger://", .social),
        CatalogApp("x", "X", "twitter://", .social),
        CatalogApp("threads", "Threads", "barcelona://", .social),
        CatalogApp("telegram", "Telegram", "tg://", .social),
        CatalogApp("signal", "Signal", "sgnl://", .social),
        CatalogApp("snapchat", "Snapchat", "snapchat://", .social),
        CatalogApp("tiktok", "TikTok", "snssdk1233://", .social),
        CatalogApp("reddit", "Reddit", "reddit://", .social),
        CatalogApp("pinterest", "Pinterest", "pinterest://", .social),
        CatalogApp("linkedin", "LinkedIn", "linkedin://", .social),
        CatalogApp("discord", "Discord", "discord://", .social),
        CatalogApp("viber", "Viber", "viber://", .social),
        CatalogApp("line", "LINE", "line://", .social),
        CatalogApp("wechat", "WeChat", "weixin://", .social),
        CatalogApp("bluesky", "Bluesky", "https://bsky.app", .social),

        // Music & video
        CatalogApp("youtube", "YouTube", "youtube://", .media),
        CatalogApp("youtubemusic", "YouTube Music", "youtubemusic://", .media),
        CatalogApp("spotify", "Spotify", "spotify://", .media),
        CatalogApp("netflix", "Netflix", "nflx://", .media),
        CatalogApp("primevideo", "Prime Video", "aiv://", .media),
        CatalogApp("disneyplus", "Disney+", "disneyplus://", .media),
        CatalogApp("twitch", "Twitch", "twitch://", .media),
        CatalogApp("shazam", "Shazam", "shazam://", .media),
        CatalogApp("soundcloud", "SoundCloud", "soundcloud://", .media),
        CatalogApp("overcast", "Overcast", "overcast://", .media),

        // Google
        CatalogApp("google", "Google", "google://", .google),
        CatalogApp("gmail", "Gmail", "googlegmail://", .google),
        CatalogApp("googlemaps", "Google Maps", "comgooglemaps://", .google),
        CatalogApp("chrome", "Chrome", "googlechrome://", .google),
        CatalogApp("googledrive", "Google Drive", "googledrive://", .google),
        CatalogApp("googlephotos", "Google Photos", "googlephotos://", .google),
        CatalogApp("googlecalendar", "Google Calendar", "googlecalendar://", .google),

        // Microsoft
        CatalogApp("outlook", "Outlook", "ms-outlook://", .microsoft),
        CatalogApp("teams", "Teams", "msteams://", .microsoft),
        CatalogApp("word", "Word", "ms-word://", .microsoft),
        CatalogApp("excel", "Excel", "ms-excel://", .microsoft),
        CatalogApp("powerpoint", "PowerPoint", "ms-powerpoint://", .microsoft),

        // Productivity
        CatalogApp("slack", "Slack", "slack://", .productivity),
        CatalogApp("zoom", "Zoom", "zoomus://", .productivity),
        CatalogApp("notion", "Notion", "notion://", .productivity),
        CatalogApp("trello", "Trello", "trello://", .productivity),
        CatalogApp("things", "Things", "things:///", .productivity),
        CatalogApp("todoist", "Todoist", "todoist://", .productivity),
        CatalogApp("obsidian", "Obsidian", "obsidian://", .productivity),
        CatalogApp("bear", "Bear", "bear://", .productivity),
        CatalogApp("drafts", "Drafts", "drafts://", .productivity),
        CatalogApp("onepassword", "1Password", "onepassword://", .productivity),
        CatalogApp("chatgpt", "ChatGPT", "chatgpt://", .productivity, wellKnown: false),
        CatalogApp("claude", "Claude", "claude://", .productivity, wellKnown: false),

        // Travel & maps
        CatalogApp("waze", "Waze", "waze://", .travel),
        CatalogApp("uber", "Uber", "uber://", .travel),
        CatalogApp("lyft", "Lyft", "lyft://", .travel),
        CatalogApp("airbnb", "Airbnb", "airbnb://", .travel),
        CatalogApp("booking", "Booking.com", "booking://", .travel),
        CatalogApp("strava", "Strava", "strava://", .travel),
        CatalogApp("bolt", "Bolt", "bolt://", .travel, wellKnown: false),
        CatalogApp("wolt", "Wolt", "https://wolt.com/discovery", .travel),

        // Shopping & money
        CatalogApp("amazon", "Amazon", "com.amazon.mobile.shopping://", .shopping),
        CatalogApp("paypal", "PayPal", "paypal://", .shopping, wellKnown: false),
        CatalogApp("revolut", "Revolut", "revolut://", .shopping, wellKnown: false),

        // Browsers
        CatalogApp("firefox", "Firefox", "firefox://", .browsers),
        CatalogApp("brave", "Brave", "brave://", .browsers),
        CatalogApp("duckduckgo", "DuckDuckGo", "ddgQuickLink://", .browsers),

        // Other
        CatalogApp("duolingo", "Duolingo", "duolingo://", .other, wellKnown: false),
    ]

    private static let byID: [String: CatalogApp] = {
        var dict: [String: CatalogApp] = [:]
        for app in apps { dict[app.id] = app }
        return dict
    }()

    static func app(id: String) -> CatalogApp? { byID[id] }
}

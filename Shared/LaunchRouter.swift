import Foundation

/// Decides how a widget tap reaches the target app.
///
/// * Direct: the widget runs `OpenTargetIntent`, which hands the URL to the
///   system (`OpenURLIntent`). Works reliably for web links / universal links.
///   For custom app schemes this depends on the iOS version, so it is opt-in.
/// * Via WidgetSimple: the widget opens `widgetsimple://open?u=…`, the app
///   immediately forwards the URL and gets out of the way. Works for every app.
enum LaunchRouter {
    static let scheme = "widgetsimple"

    static func hopURL(for target: URL) -> URL {
        let encoded = Data(target.absoluteString.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return URL(string: "\(scheme)://open?u=\(encoded)") ?? URL(string: "\(scheme)://")!
    }

    /// Returns the forwarded target if `url` is a hop URL.
    static func target(fromHop url: URL) -> URL? {
        guard url.scheme?.lowercased() == scheme, url.host == "open",
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = comps.queryItems?.first(where: { $0.name == "u" })?.value else { return nil }
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64),
              let string = String(data: data, encoding: .utf8) else { return nil }
        return URL(string: string)
    }

    static func isWeb(_ url: URL) -> Bool {
        let s = url.scheme?.lowercased() ?? ""
        return s == "http" || s == "https"
    }

    static func usesDirect(_ url: URL, method: LaunchMethod) -> Bool {
        switch method {
        case .auto: return isWeb(url)
        case .direct: return true
        case .viaApp: return false
        }
    }
}

import Foundation

/// How a widget tap reaches the target app.
///
/// iOS sends every widget tap to the widget's own app; a widget can't open another
/// app by itself. So the widget opens `widgetsimple://open?u=…` and WidgetSimple
/// forwards the URL immediately on a black screen.
enum LaunchRouter {
    static let scheme = "widgetsimple"

    static func hopURL(for target: URL) -> URL {
        if target.scheme?.lowercased() == scheme { return target }
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
}

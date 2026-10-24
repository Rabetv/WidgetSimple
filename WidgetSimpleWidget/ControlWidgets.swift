import AppIntents
import SwiftUI
import WidgetKit

// Control Center (and the Lock Screen's control slots): run one of the person's
// shortcuts with a tap — MD's "Control Widget" slot, WIDGETS-SPEC's Shortcut Control.
//
// An "open any app" control isn't possible with public API: the App Intents metadata
// processor rejects SystemShortcut in anything but a WidgetConfigurationIntent (CI run
// 40082067043: "can only be used in an AppIntent conforming to
// WidgetConfigurationIntent"). A shortcut can open an app, so this covers that need.

struct RunShortcutControlIntent: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Run Shortcut"
    static let description = IntentDescription("Runs one of your shortcuts by its name.")

    @Parameter(title: "Shortcut name", default: "")
    var shortcut: String

    init() {}

    func perform() async throws -> some IntentResult {
        .result()
    }

    var trimmedName: String {
        shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// shortcuts://run-shortcut?name=… ; without a name it opens the Shortcuts app.
    var url: URL {
        var components = URLComponents()
        components.scheme = "shortcuts"
        if !trimmedName.isEmpty {
            components.host = "run-shortcut"
            components.queryItems = [URLQueryItem(name: "name", value: trimmedName)]
        }
        return components.url ?? URL(fileURLWithPath: "/")
    }

    var label: String {
        trimmedName.isEmpty ? String(localized: "Choose a shortcut") : trimmedName
    }
}

struct RunShortcutControl: ControlWidget {
    static let kind = "WidgetSimpleRunShortcutControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: Self.kind, intent: RunShortcutControlIntent.self) { configuration in
            ControlWidgetButton(action: OpenURLIntent(configuration.url)) {
                Label(configuration.label, systemImage: "square.2.layers.3d")
            }
        }
        .displayName("Run Shortcut")
        .description("Run one of your shortcuts from Control Center.")
        .promptsForUserConfiguration()
    }
}

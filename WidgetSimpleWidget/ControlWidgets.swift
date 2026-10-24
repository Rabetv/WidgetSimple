import AppIntents
import SwiftUI
import WidgetKit

// Control Center (and the Lock Screen's control slots): open any app with one tap, the
// launcher's job in a control. The app is picked in the control's own settings; a tap
// hands over to the system's RunSystemShortcutIntent, the same public intent the
// launcher's words use. SystemShortcut can only be filled by the system's picker.

struct OpenAppControlIntent: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Open App"
    static let description = IntentDescription("Opens the app you pick.")

    @Parameter(title: "App") var app: SystemShortcut?

    init() {}

    func perform() async throws -> some IntentResult & OpensIntent {
        guard let app else { throw OpenAppControlError.noApp }
        return .result(opensIntent: RunSystemShortcutIntent(shortcut: app))
    }

    /// The picked app's name, or what to do when none is picked yet.
    var label: String {
        app.map { String(localized: $0.displayRepresentation.title) } ?? String(localized: "Choose an app")
    }
}

enum OpenAppControlError: Error, CustomLocalizedStringResourceConvertible {
    case noApp

    var localizedStringResource: LocalizedStringResource {
        "Pick an app in the control's settings first."
    }
}

struct OpenAppControl: ControlWidget {
    static let kind = "WidgetSimpleOpenAppControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: Self.kind, intent: OpenAppControlIntent.self) { configuration in
            ControlWidgetButton(action: configuration) {
                Label(configuration.label, systemImage: "arrow.up.forward.app")
            }
        }
        .displayName("Open App")
        .description("Open any app from Control Center.")
        .promptsForUserConfiguration()
    }
}

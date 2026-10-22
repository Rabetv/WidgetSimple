import AppIntents
import Foundation
import WidgetKit

// MARK: - Widget configuration ("Edit Widget" > Layout)

struct LayoutEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Widget Layout"
    static let defaultQuery = LayoutQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(_ layout: LauncherLayout) {
        self.init(id: layout.id.uuidString, name: layout.name.isEmpty ? "Untitled" : layout.name)
    }
}

struct LayoutQuery: EntityQuery {
    init() {}

    func entities(for identifiers: [LayoutEntity.ID]) async throws -> [LayoutEntity] {
        let layouts = SharedStore.shared.loadLayouts()
        return identifiers.compactMap { id in
            layouts.first(where: { $0.id.uuidString == id }).map(LayoutEntity.init)
        }
    }

    func suggestedEntities() async throws -> [LayoutEntity] {
        SharedStore.shared.loadLayouts().map(LayoutEntity.init)
    }

    func defaultResult() async -> LayoutEntity? {
        SharedStore.shared.loadLayouts().first.map(LayoutEntity.init)
    }
}

struct SelectLayoutIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Layout"
    static let description = IntentDescription("Pick which WidgetSimple layout this widget shows.")

    @Parameter(title: "Layout")
    var layout: LayoutEntity?

    init() {}
}

// MARK: - Direct launch from a widget tap

struct OpenTargetIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Launcher Item"
    static let isDiscoverable: Bool = false
    static let openAppWhenRun: Bool = false

    @Parameter(title: "URL")
    var url: URL

    init() {}

    init(url: URL) {
        self.url = url
    }

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(url))
    }
}

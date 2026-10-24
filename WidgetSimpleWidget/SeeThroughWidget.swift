import AppIntents
import SwiftUI
import WidgetKit

// The see-through plumbing every widget kind shares: who a widget is (so its piece of
// wallpaper is its own), what to draw behind it, and the layouts made in the app.

// MARK: - Identity

/// A widget's own identity, stored by the system in that widget's configuration.
///
/// Before this, a widget was keyed by what it showed, so two widgets of one size with
/// the same apps shared a key and drew the same crop; moving one moved both pieces.
/// A new widget gets a fresh UUID from `defaultResult()` when it is added. Picking
/// "New ID" in Edit Widget gives it another one (the fix if two ever collide).
struct WidgetIdentity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "See-through ID"
    static let defaultQuery = WidgetIdentityQuery()

    let id: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Widget \(String(id.prefix(4)).uppercased())")
    }
}

struct WidgetIdentityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetIdentity] {
        identifiers.filter { !$0.isEmpty }.map { WidgetIdentity(id: $0) }
    }

    func suggestedEntities() async throws -> [WidgetIdentity] {
        [WidgetIdentity(id: UUID().uuidString)]
    }

    func defaultResult() async -> WidgetIdentity? {
        WidgetIdentity(id: UUID().uuidString)
    }
}

// MARK: - Layouts

/// A layout from the app's layout editor, picked per widget in Edit Widget.
struct LayoutEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Layout"
    static let defaultQuery = LayoutQuery()

    let id: String
    let name: String
    let detail: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(detail)")
    }

    init(_ layout: LayoutDocument) {
        id = layout.id
        name = layout.name
        detail = layout.summary
    }
}

struct LayoutQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [LayoutEntity] {
        identifiers.compactMap { SharedStore.shared.loadLayout(id: $0).map(LayoutEntity.init) }
    }

    func suggestedEntities() async throws -> [LayoutEntity] {
        SharedStore.shared.loadLayouts().map(LayoutEntity.init)
    }
}

// MARK: - Backdrop

/// What a widget draws in its container.
enum Backdrop {
    /// The app is matching widgets: pink with this key.
    case finding(UInt32)
    /// This widget's own piece of wallpaper.
    case piece(UIImage)
    /// No piece: the look's photo if it has one, else the system background.
    case plain
}

enum SeeThrough {
    /// Resolves the backdrop for one widget and notes its size and names for the app.
    /// - Parameters:
    ///   - identity: the widget's `WidgetIdentity`, nil for widgets added before it existed.
    ///   - content: what the widget shows, used only to key widgets without an identity.
    static func backdrop(kind: String, identity: WidgetIdentity?, content: [String], names: [String],
                         clock: ClockOption, context: TimelineProviderContext) -> Backdrop {
        guard !context.isPreview, let family = SpotFamily(context.family) else { return .plain }
        let store = SharedStore.shared
        // The real on-screen size lets the app cut exactly the right piece.
        store.recordSize(context.displaySize, for: family)

        let key: UInt32
        if let id = identity?.id {
            key = SpotKey.make(family: family, identity: id)
        } else {
            key = SpotKey.content(family: family, kind: kind, clock: clock, apps: content)
        }
        store.recordWidget(WidgetRecord(key: key, kind: kind, family: family.rawValue, names: names, seen: .now))

        let state = store.loadSeeThrough()
        if state.finding { return .finding(key) }
        if let piece = store.spotImage(key: key, state: state) { return .piece(piece) }
        // Launchers matched by builds 35–39 keep their piece until the first new scan.
        if identity == nil, kind == LauncherWidget.kind,
           let piece = store.legacySpotImage(key: SpotKey.legacy16(family: family, clock: clock, apps: content),
                                             state: state) {
            return .piece(piece)
        }
        // No match: plain. Never a piece borrowed from another widget of the same size.
        return .plain
    }
}

extension SpotFamily {
    /// Bridges WidgetKit's family to the four sizes the wallpaper matching knows.
    init?(_ family: WidgetFamily) {
        switch family {
        case .systemSmall: self = .small
        case .systemMedium: self = .medium
        case .systemLarge: self = .large
        case .systemExtraLargePortrait: self = .max
        default: return nil
        }
    }
}

extension View {
    /// The widget's container: the matching code, its wallpaper piece, the look's photo,
    /// or the system background — in that order.
    func seeThroughBackground(_ backdrop: Backdrop, look: Look) -> some View {
        modifier(SeeThroughContainer(backdrop: backdrop, look: look))
    }

    /// Records the content margins iOS gives this widget, so the app's preview matches.
    func reportsContentMargins() -> some View {
        modifier(MarginReporter())
    }
}

private struct SeeThroughContainer: ViewModifier {
    let backdrop: Backdrop
    let look: Look

    @ViewBuilder
    func body(content: Content) -> some View {
        switch backdrop {
        case .finding(let key):
            // The container itself must be magenta, or the screenshot finder has no
            // rectangle to measure.
            SpotCode(key: key)
                .containerBackground(for: .widget) { SpotCode.marker }
        case .piece(let image):
            content.containerBackground(for: .widget) { fill(piece: image) }
        case .plain:
            content.containerBackground(for: .widget) { fill(piece: nil) }
        }
    }

    /// A photo the person explicitly chose wins over the matched piece.
    @ViewBuilder
    private func fill(piece: UIImage?) -> some View {
        if look.background == .photo, let photo = SharedStore.shared.loadBackgroundImage() {
            Image(uiImage: photo).resizable().scaledToFill()
        } else if let piece {
            Image(uiImage: piece).resizable().scaledToFill()
        } else {
            Color.clear
        }
    }
}

/// Widget views have no lifecycle callbacks a snapshot is guaranteed to run, so the
/// margins are recorded while the body is evaluated; the store skips repeat writes.
private struct MarginReporter: ViewModifier {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetContentMargins) private var margins

    func body(content: Content) -> some View {
        if let spot = SpotFamily(family) {
            SharedStore.shared.recordMargins(margins, for: spot)
        }
        return content
    }
}

import SwiftUI

/// The four screens, so one screen can send you to another.
enum AppTab: Hashable {
    case home, templates, components, settings
}

/// A design open in the sandbox: a working copy, saved only when Save is pressed.
struct SandboxDraft: Identifiable {
    let id = UUID()
    var design: WidgetDesign
    /// The saved design this copy came from; nil for a new one.
    let saved: UUID?
}

/// The configurator's own state: which screen is open and what the sandbox works on.
/// It stays in the app; nothing here reaches the widgets.
@MainActor
final class BoardStore: ObservableObject {
    /// The screen on show.
    @Published var tab: AppTab = .home
    /// The design open in the full-screen sandbox, if any.
    @Published var sandbox: SandboxDraft?
    /// The plain Apps widget's style screen, full-screen.
    @Published var stylingApps = false

    /// Opens a saved design in the sandbox. A design of rows is placed first, exactly
    /// where its rows put each block, for the widget size it was made for.
    func edit(_ design: WidgetDesign) {
        sandbox = SandboxDraft(design: design.placed(), saved: design.id)
    }

    /// Opens the plain Apps widget's style screen.
    func editAppsWidget() {
        stylingApps = true
    }

    /// Copies a blueprint, with new ids, into the sandbox. A new design opens behind
    /// `WallpaperGate` (see `MainTabs`).
    func start(_ blueprint: DesignBlueprint, model: AppModel) {
        let name = blueprint.blocks.isEmpty ? model.nextDesignName : blueprint.name
        sandbox = SandboxDraft(design: blueprint.design(name: name, look: model.look), saved: nil)
    }

    /// A new blank widget with one block in the middle, already in the sandbox.
    func start(with kind: BlockKind, model: AppModel) {
        var design = DesignBlueprint.blank(.medium).design(name: model.nextDesignName, look: model.look)
        design.blocks.append(DesignBlock.dropped(kind, on: design.canvas))
        sandbox = SandboxDraft(design: design, saved: nil)
    }
}

extension AppModel {
    /// "Design 1", "Design 2"…: the first name no saved design uses, as `addDesign` names.
    var nextDesignName: String {
        let taken = Set(designs.map(\.name))
        var number = designs.count + 1
        while taken.contains("Design \(number)") { number += 1 }
        return "Design \(number)"
    }
}

extension ModuleKind {
    /// The design block that shows this module.
    var block: BlockKind {
        switch self {
        case .clock: return .analogClock
        case .countdown: return .countdownRing
        case .health: return .health
        case .battery: return .battery
        case .vinyl: return .vinyl
        case .calendar: return .calendarIcon
        }
    }
}

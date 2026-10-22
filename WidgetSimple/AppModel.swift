import SwiftUI
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published var look: Look {
        didSet {
            store.saveLook(look)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    let store = SharedStore.shared

    init() {
        FontRegistry.registerAllOnce()
        look = store.loadLook()
    }
}

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
    @Published var clock: ClockOption {
        didSet {
            store.saveClock(clock)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    @Published var message: String?

    let store = SharedStore.shared

    init() {
        FontRegistry.registerAllOnce()
        look = store.loadLook()
        clock = store.loadClock()
    }
}

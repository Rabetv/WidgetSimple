import SwiftUI

@main
struct WidgetSimpleApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
        // Follows the Music app's song only while the app is in front. It asks nothing:
        // without Music access it keeps the deck's sample side.
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active: NowPlayingMonitor.shared.resume()
            case .background: NowPlayingMonitor.shared.pause()
            default: break
            }
        }
    }
}

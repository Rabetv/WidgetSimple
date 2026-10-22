import SwiftUI

@main
struct WidgetSimpleApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environmentObject(model)
                .onOpenURL { url in
                    model.handleIncoming(url)
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .background:
                        // We were only forwarding a widget tap; show the normal UI next time.
                        model.isForwarding = false
                    case .active:
                        model.refreshMetrics()
                    default:
                        break
                    }
                }
        }
    }
}

/// Shows a plain black screen while forwarding a widget tap, so the hop through
/// WidgetSimple is as invisible as possible. Normal launches fade the UI in.
struct AppShell: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("didSeeTutorial") private var didSeeTutorial = false
    @State private var revealed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if !model.isForwarding {
                RootView()
                    .opacity(revealed ? 1 : 0)
            }
        }
        .task {
            // Give a widget tap a moment to arrive before showing the UI.
            try? await Task.sleep(nanoseconds: 120_000_000)
            withAnimation(.easeOut(duration: 0.15)) { revealed = true }
        }
        .fullScreenCover(isPresented: Binding(
            get: { revealed && !didSeeTutorial && !model.isForwarding },
            set: { if !$0 { didSeeTutorial = true } }
        )) {
            TutorialView { didSeeTutorial = true }
        }
        .alert("Couldn't open", isPresented: Binding(
            get: { model.launchError != nil },
            set: { if !$0 { model.launchError = nil } }
        )) {
            Button("OK", role: .cancel) { model.launchError = nil }
        } message: {
            Text(model.launchError ?? "")
        }
    }
}

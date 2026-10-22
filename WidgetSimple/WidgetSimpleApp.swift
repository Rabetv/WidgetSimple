import SwiftUI

@main
struct WidgetSimpleApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .alert("Oops", isPresented: Binding(
                    get: { model.message != nil },
                    set: { if !$0 { model.message = nil } }
                )) {
                    Button("OK", role: .cancel) { model.message = nil }
                } message: {
                    Text(model.message ?? "")
                }
        }
    }
}

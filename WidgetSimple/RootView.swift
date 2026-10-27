import SwiftUI

/// The app: a one-time tutorial, the paywall until the subscription is active, the
/// wallpaper screenshots (App Store build), then the four configurator screens — Home,
/// Templates, Components, Settings — with the sandbox opening full-screen over them.
struct RootView: View {
    @StateObject private var license = LicenseStore()
    @StateObject private var board = BoardStore()
    @EnvironmentObject private var model: AppModel
    /// True while the required setup is on screen, so its last tick is seen before
    /// Continue moves on.
    @State private var settingUp = false
    @AppStorage("onboarded") private var onboarded = false
    @Environment(\.scenePhase) private var scenePhase

    #if targetEnvironment(simulator)
    /// "-screenshot [-screen home|templates|components|settings|style]" in a simulator build.
    static var screenshotScreen: String? {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-screenshot") else { return nil }
        if let index = args.firstIndex(of: "-screen"), args.indices.contains(index + 1) {
            return args[index + 1]
        }
        return "home"
    }

    @ViewBuilder
    private func screenshotView(_ screen: String) -> some View {
        Group {
            switch screen {
            case "home", "iboard": IBoardView()
            case "gallery", "templates": PresetGalleryView()
            case "assets", "components": AssetLedgerView()
            case "settings": SystemSettingsView(license: license)
            default: WidgetEditorScreen()
            }
        }
        .preferredColorScheme(.dark)
    }
    #endif
    var body: some View {
        Group {
            #if targetEnvironment(simulator)
            if let screen = Self.screenshotScreen {
                screenshotView(screen)
            } else {
                normalFlow
            }
            #else
            normalFlow
            #endif
        }
        .environmentObject(board)
        #if APPSTORE
        // A subscription can lapse or be refunded while the app sits in the background.
        // Widgets placed meanwhile have reported their real sizes: cut the wallpaper
        // pieces to them.
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                Task {
                    await license.refresh()
                    await model.refreshPiecesIfNeeded()
                }
            }
        }
        #endif
    }

    // Every screen is dark glass over the app's own wallpaper, in both system appearances.
    @ViewBuilder
    private var normalFlow: some View {
        if !onboarded {
            OnboardingView { onboarded = true }
                .preferredColorScheme(.dark)
        } else {
            switch license.status {
            case .checking:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppBackground())
                    .task { await license.refresh() }
                    .preferredColorScheme(.dark)
            case .unlicensed:
                PaywallView(license: license)
                    .preferredColorScheme(.dark)
            case .licensed:
                #if APPSTORE
                if model.hasWallpaperShots && !settingUp {
                    MainTabs(license: license)
                        .preferredColorScheme(.dark)
                } else {
                    WallpaperSetupView(required: true) { settingUp = false }
                        .onAppear { settingUp = true }
                        .preferredColorScheme(.dark)
                }
                #else
                MainTabs(license: license)
                    .preferredColorScheme(.dark)
                #endif
            }
        }
    }
}

private struct MainTabs: View {
    @ObservedObject var license: LicenseStore
    @EnvironmentObject private var board: BoardStore
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView(selection: $board.tab) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                IBoardView()
            }
            Tab("Templates", systemImage: "rectangle.3.group", value: AppTab.templates) {
                PresetGalleryView()
            }
            Tab("Components", systemImage: "square.stack.3d.up", value: AppTab.components) {
                AssetLedgerView()
            }
            Tab("Settings", systemImage: "slider.horizontal.3", value: AppTab.settings) {
                SystemSettingsView(license: license)
            }
        }
        .fullScreenCover(item: $board.sandbox) { draft in
            // Using a template (a new design) waits for the wallpaper setup first.
            Group {
                if draft.saved == nil {
                    DesignSandbox(draft: draft).wallpaperGated()
                } else {
                    DesignSandbox(draft: draft)
                }
            }
            .environmentObject(model)
                .environmentObject(board)
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $board.stylingApps) {
            WidgetEditorScreen()
                .environmentObject(model)
                .environmentObject(board)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Preview

/// The widget as it will look on the Home Screen: just the words, in the real ink.
struct WidgetPreviewCard: View {
    let look: Look
    let clock: ClockOption
    let size: FaceSize
    var apps = ["Phone", "Messages", "Music"]

    var body: some View {
        TimelineView(.everyMinute) { context in
            LauncherFace(look: look, clock: clock, date: context.date, size: size,
                         apps: apps, color: look.color)
        }
        .aspectRatio(size.aspectRatio, contentMode: .fit)
        .padding(18)
        // The widget as iOS 27 draws it: words on the system's Liquid Glass.
        .glassEffect(.regular, in: .rect(cornerRadius: 34, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: look)
        .frame(maxWidth: .infinity)
    }
}

/// A widget as it lands on the Home Screen, for the app's own pages: its real point
/// size scaled to fit, in the real ink on the iOS 27 widget glass. With a design, its
/// Open App slots read App 1, App 2… — the apps themselves are picked in Edit Widget.
struct WidgetMockup: View {
    /// nil shows the Apps widget without a design, in the shared look and clock.
    let design: WidgetDesign?
    let size: FaceSize
    @EnvironmentObject private var model: AppModel

    private var real: CGSize { size.pointSize }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size == .small ? 24 : 28, style: .continuous)
        GeometryReader { geo in
            TimelineView(.everyMinute) { context in
                face(at: context.date)
                    .frame(width: real.width, height: real.height)
                    .scaleEffect(geo.size.width / real.width, anchor: .topLeading)
            }
        }
        .aspectRatio(real.width / real.height, contentMode: .fit)
        .clipShape(shape)
        // The system widget container: Liquid Glass with its rim, not the app's artwork.
        .glassEffect(.regular, in: shape)
        .animation(.easeInOut(duration: 0.2), value: design)
        .animation(.easeInOut(duration: 0.2), value: model.look)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(design.map { "Preview of \($0.displayName)" } ?? "Preview of the Apps widget")
    }

    @ViewBuilder
    private func face(at date: Date) -> some View {
        if let design {
            DesignFace(design: design, date: date, size: size, placeholders: true,
                       color: design.look.color, battery: AppModel.batteryLevel)
        } else {
            LauncherFace(look: model.look, clock: model.clock, date: date, size: size,
                         apps: (1...3).map { String(localized: "App \($0)") }, color: model.look.color)
        }
    }
}

#if TESTFLIGHT
/// TestFlight only: what the widget extension wrote into the App Group. Without a Mac
/// or Console this is the only way to see an extension that cannot reach the shared
/// container.
struct DiagnosticsView: View {
    @State private var view = ""

    private var groupID: String {
        (Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String) ?? "(missing)"
    }

    var body: some View {
        List {
            Section("App Group") {
                LabeledContent("ID", value: groupID)
                LabeledContent("Available", value: SharedStore.shared.isAppGroupAvailable ? "yes" : "no")
                LabeledContent("Path", value: SharedStore.shared.rootURL.path)
            }
            Section("Current look") {
                LabeledContent("Background", value: SharedStore.shared.loadLook().background.title)
            }
            Section("view.log (widget extension)") {
                Text(view.isEmpty
                     ? "Empty. The extension has not run, or it cannot see the App Group."
                     : view)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("Diagnostics")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reload") { load() }
            }
        }
        .task { load() }
    }

    private func load() {
        view = SharedStore.shared.loadViewLog()
    }
}
#endif

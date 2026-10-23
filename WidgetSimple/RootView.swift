import PhotosUI
import StoreKit
import SwiftUI
import UIKit

/// The app: a one-time tutorial, the paywall until the subscription is active, then
/// three tabs over the app background — widgets, templates, settings.
struct RootView: View {
    @StateObject private var license = LicenseStore()
    @AppStorage("onboarded") private var onboarded = false
    @Environment(\.scenePhase) private var scenePhase

    #if targetEnvironment(simulator)
    /// "-screenshot [-screen editor|templates|settings]" in a simulator build.
    static var screenshotScreen: String? {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-screenshot") else { return nil }
        if let index = args.firstIndex(of: "-screen"), args.indices.contains(index + 1) {
            return args[index + 1]
        }
        return "editor"
    }

    @ViewBuilder
    private func screenshotView(_ screen: String) -> some View {
        switch screen {
        case "templates": NavigationStack { TemplatesView() }
        case "settings": NavigationStack { AccountView(license: license) }
        default: NavigationStack { EditorView() }
        }
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
        // The design is dark glass over a dark wallpaper in both system appearances.
        .preferredColorScheme(.dark)
        #if APPSTORE
        // A subscription can lapse or be refunded while the app sits in the background.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await license.refresh() } }
        }
        #endif
    }

    @ViewBuilder
    private var normalFlow: some View {
        if !onboarded {
            OnboardingView { onboarded = true }
        } else {
            switch license.status {
            case .checking:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppBackground())
                    .task { await license.refresh() }
            case .unlicensed:
                PaywallView(license: license)
            case .licensed:
                MainTabs(license: license)
            }
        }
    }
}

private struct MainTabs: View {
    @ObservedObject var license: LicenseStore

    var body: some View {
        TabView {
            Tab("Widgets", systemImage: "square.grid.2x2") {
                HomeView()
            }
            Tab("Templates", systemImage: "rectangle.grid.1x2") {
                TemplatesView()
            }
            Tab("Settings", systemImage: "gearshape") {
                NavigationStack { AccountView(license: license) }
            }
        }
    }
}

/// Every control that styles the launcher widget, with a live preview. All launcher
/// widgets on the Home Screen follow this one look.
struct EditorView: View {
    @EnvironmentObject private var model: AppModel
    @State private var previewSize: FaceSize = .medium
    @State private var pickingWallpaper = false
    @State private var pickingPink = false
    @State private var wallpaperItem: PhotosPickerItem?
    @State private var pinkItem: PhotosPickerItem?

    var body: some View {
        Form {
            previewSection
            #if APPSTORE
            seeThroughSection.listRowBackground(GlassRowBackground())
            #endif
            appsSection.listRowBackground(GlassRowBackground())
            clockSection.listRowBackground(GlassRowBackground())
            styleSection.listRowBackground(GlassRowBackground())
        }
        .glassList()
        .navigationTitle("Launcher")
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: $pickingWallpaper, selection: $wallpaperItem, matching: .screenshots)
        .photosPicker(isPresented: $pickingPink, selection: $pinkItem, matching: .screenshots)
        .onChange(of: wallpaperItem) { _, item in
            guard let item else { return }
            wallpaperItem = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                await model.useWallpaper(data)
            }
        }
        .onChange(of: pinkItem) { _, item in
            guard let item else { return }
            pinkItem = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                await model.usePinkScreenshot(data)
            }
        }
    }

    #if APPSTORE
    /// Matched wallpaper: two screenshots, once. Public API only, and a widget without
    /// a match keeps the system background instead of showing a wrong piece.
    private var seeThroughSection: some View {
        Section {
            Button {
                pickingWallpaper = true
            } label: {
                Label(model.seeThrough.hasWallpaper ? "New wallpaper screenshot" : "Pick a wallpaper screenshot",
                      systemImage: "photo")
            }

            if model.seeThrough.finding {
                Button {
                    pickingPink = true
                } label: {
                    Label("Pick the pink screenshot", systemImage: "camera.viewfinder")
                }
                Button("Cancel", role: .cancel) { model.stopFinding() }
            } else {
                Button {
                    model.startFinding()
                } label: {
                    Label("Match my widgets", systemImage: "viewfinder")
                }
            }

            if model.working {
                ProgressView()
            } else if !model.seeThrough.spots.isEmpty {
                Label("\(model.seeThrough.spots.count) widget\(model.seeThrough.spots.count == 1 ? "" : "s") matched",
                      systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        } header: {
            Text("See-through")
        } footer: {
            Text("Two screenshots, once. Redo it only if you change the wallpaper or move a widget — a widget with no match keeps the system background.")
        }
    }
    #endif

    // MARK: Sections

    private var previewSection: some View {
        Section {
            Picker("Size", selection: $previewSize) {
                ForEach(FaceSize.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            WidgetPreviewCard(look: model.look, clock: model.clock, size: previewSize)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        } header: {
            Text("Preview")
        } footer: {
            #if APPSTORE
            Text("Your words on the widget background iOS draws. Add the widget once from the Home Screen and style it here.")
            #else
            Text("The widget is see-through — the wallpaper shows behind the words. Add it once from the Home Screen and style it here.")
            #endif
        }
    }

    private var appsSection: some View {
        Section {
            Label("Hold the widget › Edit Widget to pick the apps.", systemImage: "hand.tap")
            Label("A tap on a word opens that app directly.", systemImage: "arrow.up.forward.app")
            Label("Every widget can open a different set.", systemImage: "square.grid.2x2")
        } header: {
            Text("Apps")
        } footer: {
            Text("iOS only lets the system fill the app list, so it lives in Edit Widget.")
        }
    }

    private var clockSection: some View {
        Section("Clock") {
            Picker("Clock", selection: $model.clock) {
                ForEach(ClockOption.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var styleSection: some View {
        Section {
            NavigationLink {
                FontPickerView(selection: $model.look.fontID)
            } label: {
                LabeledContent("Font", value: FontCatalog.displayName(for: model.look.fontID))
            }

            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Size", value: "\(Int(model.look.size)) pt")
                Slider(value: $model.look.size, in: 12...34, step: 1)
            }

            Picker("Alignment", selection: $model.look.align) {
                ForEach(TextAlign.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("Position", selection: $model.look.vAlign) {
                ForEach(TextVAlign.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("Arrangement", selection: $model.look.arrangement) {
                ForEach(Arrangement.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            if model.look.arrangement == .free {
                Picker("Clock position", selection: $model.look.clockPosition) {
                    ForEach(WidgetPosition.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)

                nudge("Clock nudge", x: $model.look.clockDX, y: $model.look.clockDY)

                Picker("Apps position", selection: $model.look.appsPosition) {
                    ForEach(WidgetPosition.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)

                Toggle("Place every word separately", isOn: $model.look.perWordPlacement)

                if model.look.perWordPlacement {
                    NavigationLink("Word placement") {
                        WordPlacementView(look: $model.look)
                    }
                }

                nudge("Apps nudge", x: $model.look.appsDX, y: $model.look.appsDY)
            }

            Picker("Letter case", selection: $model.look.letterCase) {
                ForEach(LetterCase.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("Color", selection: $model.look.tone) {
                ForEach(TextTone.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            if model.look.tone == .custom {
                ColorPicker("Custom color", selection: customColorBinding, supportsOpacity: false)
            }

            Toggle("Shadow", isOn: $model.look.shadow)

            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Spacing", value: String(format: "%.1f×", model.look.spacing))
                Slider(value: $model.look.spacing, in: 0.6...2.0, step: 0.1)
            }
        } header: {
            Text("Style")
        }
    }

    /// Two sliders that move a block by points on top of its anchor.
    private func nudge(_ title: String, x: Binding<Double>, y: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent(title, value: "\(Int(x.wrappedValue)), \(Int(y.wrappedValue)) pt")
            HStack(spacing: 12) {
                Image(systemName: "arrow.left.and.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: x, in: -80...80, step: 1)
            }
            HStack(spacing: 12) {
                Image(systemName: "arrow.up.and.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: y, in: -80...80, step: 1)
            }
        }
    }

    /// The custom colour, kept as a hex string in the look.
    private var customColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: model.look.customHex) },
            set: { model.look.customHex = $0.toHex() }
        )
    }
}

// MARK: - Word placement

/// Per-word anchors. The app can't see the app names (iOS resolves them in Edit
/// Widget), so the rows are word slots: slot 1 is the first app picked.
private struct WordPlacementView: View {
    @Binding var look: Look

    var body: some View {
        List {
            Section {
                ForEach(0..<12, id: \.self) { slot in
                    Picker("Word \(slot + 1)", selection: anchorBinding(slot)) {
                        ForEach(WidgetPosition.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
            } footer: {
                Text("Words you haven't picked in Edit Widget are ignored.")
            }
        }
        .navigationTitle("Word placement")
    }

    private func anchorBinding(_ slot: Int) -> Binding<WidgetPosition> {
        Binding(
            get: { look.wordAnchors["\(slot)"] ?? look.appsPosition },
            set: { look.wordAnchors["\(slot)"] = $0 }
        )
    }
}

// MARK: - Account

/// Licence controls: manage the subscription or forget the key on this iPhone.
private struct AccountView: View {
    @ObservedObject var license: LicenseStore
    @Environment(\.openURL) private var openURL
    @State private var viewLog = ""
    @State private var managing = false
    @AppStorage("onboarded") private var onboarded = true

    var body: some View {
        List {
            #if APPSTORE
            Section("Subscription") {
                Button("Manage subscription") { managing = true }
                Button("Restore Purchases") { Task { await license.restore() } }
                    .disabled(license.busy)
                // No StoreKit products in a simulator; keep the screenshot clean.
                if let message = license.message,
                   !ProcessInfo.processInfo.arguments.contains("-screenshot") {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                }
                Link("Terms of Use", destination: StoreConfig.termsURL)
                Link("Support", destination: StoreConfig.supportURL)
                Link("Privacy Policy", destination: StoreConfig.privacyURL)
            }
            .listRowBackground(GlassRowBackground())
            #else
            Section("Subscription") {
                Button("Manage subscription") { openURL(license.manageSubscription()) }
                Button("Sign out on this iPhone", role: .destructive) { license.signOut() }
            }
            .listRowBackground(GlassRowBackground())
            #endif
            Section {
                Button("Show the tutorial again") { onboarded = false }
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
            } header: {
                Text("About")
            } footer: {
                #if APPSTORE
                Text("Widgets keep working when the subscription ends; the subscription unlocks the editor.")
                #else
                Text("Widgets stay see-through when the app is locked; the subscription unlocks the editor.")
                #endif
            }
            .listRowBackground(GlassRowBackground())
        }
        .glassList()
        .navigationTitle("Settings")
        #if APPSTORE
        .manageSubscriptionsSheet(isPresented: $managing)
        #else
        .task { viewLog = SharedStore.shared.loadViewLog() }
        #endif
    }
}

// MARK: - Preview

/// The widget as it will look on the Home Screen: just the words.
struct WidgetPreviewCard: View {
    let look: Look
    let clock: ClockOption
    let size: FaceSize
    /// True for template thumbnails: a neutral panel instead of the app wallpaper, so
    /// six cards do not all show the same picture.
    var plainBackdrop = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            LauncherFace(look: look, clock: clock, date: context.date, size: size,
                         apps: ["Phone", "Messages", "Music"], color: look.color)
        }
        .aspectRatio(size.aspectRatio, contentMode: .fit)
        .padding(18)
        .background {
            if plainBackdrop {
                LinearGradient(colors: [look.color.opacity(0.30), Color.black.opacity(0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                Image("AppBackground").resizable().scaledToFill()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: look)
        .frame(maxWidth: .infinity)
    }
}

private extension Color {
    /// "#RRGGBB", matching the decoder in `Models.swift`.
    func toHex() -> String {
        let ui = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        ui.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02X%02X%02X",
                      Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }
}

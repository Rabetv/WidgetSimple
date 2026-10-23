import StoreKit
import SwiftUI
import UIKit

/// The app: the paywall until a licence is validated, then one screen with a live
/// preview and every control that styles the widget.
struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var license = LicenseStore()
    @State private var previewSize: FaceSize = .medium
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch license.status {
            case .checking:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground).ignoresSafeArea())
                    .task { await license.refresh() }
            case .unlicensed:
                PaywallView(license: license)
            case .licensed:
                editor
            }
        }
        #if APPSTORE
        // A subscription can lapse or be refunded while the app sits in the background.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await license.refresh() } }
        }
        #endif
    }

    private var editor: some View {
        NavigationStack {
            Form {
                previewSection
                appsSection
                clockSection
                styleSection
            }
            .navigationTitle("WidgetSimple")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AccountView(license: license)
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Account")
                }
            }
        }
    }

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
            Text("The widget is see-through — the wallpaper shows behind the words. Add it once from the Home Screen and style it here.")
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

    var body: some View {
        List {
            #if APPSTORE
            Section("Subscription") {
                Button("Manage subscription") { managing = true }
                Button("Restore Purchases") { Task { await license.restore() } }
                    .disabled(license.busy)
                if let message = license.message {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                }
                Link("Terms of Use", destination: StoreConfig.termsURL)
                Link("Privacy Policy", destination: StoreConfig.privacyURL)
            }
            #else
            Section("Subscription") {
                Button("Manage subscription") { openURL(license.manageSubscription()) }
                Button("Sign out on this iPhone", role: .destructive) { license.signOut() }
            }
            // The view-hierarchy probe exists for the transparency research; the App
            // Store build has nothing to investigate there.
            Section {
                DisclosureGroup("Widget view log") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewLog)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack {
                            Button("Refresh") { viewLog = SharedStore.shared.loadViewLog() }
                            Button("Clear", role: .destructive) {
                                SharedStore.shared.clearViewLog()
                                viewLog = ""
                            }
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                    .padding(.top, 6)
                }
            } header: {
                Text("Diagnostics")
            } footer: {
                Text("What the widget's view hierarchy looked like. Used to find out which layer draws the glass border.")
            }
            #endif
            Section {
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
        }
        .navigationTitle("Account")
        #if APPSTORE
        .manageSubscriptionsSheet(isPresented: $managing)
        #else
        .task { viewLog = SharedStore.shared.loadViewLog() }
        #endif
    }
}

// MARK: - Preview

/// The widget as it will look on the Home Screen: just the words.
private struct WidgetPreviewCard: View {
    let look: Look
    let clock: ClockOption
    let size: FaceSize

    var body: some View {
        TimelineView(.everyMinute) { context in
            LauncherFace(look: look, clock: clock, date: context.date, size: size,
                         apps: ["Phone", "Messages", "Music"], color: look.color)
        }
        .aspectRatio(size.aspectRatio, contentMode: .fit)
        .padding(18)
        .background(LinearGradient.sampleWallpaper)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: look)
        .frame(maxWidth: .infinity)
    }
}

private extension LinearGradient {
    /// Stands in for a wallpaper in the app's preview.
    static let sampleWallpaper = LinearGradient(
        colors: [Color(red: 0.98, green: 0.55, blue: 0.45), Color(red: 0.45, green: 0.35, blue: 0.85)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
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

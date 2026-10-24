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
    @EnvironmentObject private var model: AppModel

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
        // Every error the model reports surfaces here, whichever screen caused it
        // (the message used to be set and never shown).
        .alert("WidgetSimple", isPresented: Binding(
            get: { model.message != nil },
            set: { if !$0 { model.message = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.message ?? "")
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
    @State private var pinkItems: [PhotosPickerItem] = []
    @State private var pickingBackground = false
    @State private var backgroundItem: PhotosPickerItem?
    @State private var confirmingStartOver = false

    var body: some View {
        Form {
            previewSection
            seeThroughSection.listRowBackground(GlassRowBackground())
            backgroundSection.listRowBackground(GlassRowBackground())
            appsSection.listRowBackground(GlassRowBackground())
            clockSection.listRowBackground(GlassRowBackground())
            typographySection.listRowBackground(GlassRowBackground())
            colourSection.listRowBackground(GlassRowBackground())
            layoutSection.listRowBackground(GlassRowBackground())
        }
        .glassList()
        .navigationTitle("Launcher")
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: $pickingWallpaper, selection: $wallpaperItem, matching: .screenshots)
        .photosPicker(isPresented: $pickingPink, selection: $pinkItems, maxSelectionCount: 12,
                      selectionBehavior: .ordered, matching: .screenshots)
        .photosPicker(isPresented: $pickingBackground, selection: $backgroundItem, matching: .images)
        .onChange(of: backgroundItem) { _, item in
            guard let item else { return }
            backgroundItem = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                model.useBackgroundPhoto(data)
            }
        }
        .onChange(of: wallpaperItem) { _, item in
            guard let item else { return }
            wallpaperItem = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                await model.useWallpaper(data)
            }
        }
        .onChange(of: pinkItems) { _, items in
            guard !items.isEmpty else { return }
            pinkItems = []
            Task {
                var screenshots: [Data] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) { screenshots.append(data) }
                }
                await model.usePinkScreenshots(screenshots)
            }
        }
        .confirmationDialog("Forget every match?", isPresented: $confirmingStartOver, titleVisibility: .visible) {
            Button("Start over", role: .destructive) { model.startOver() }
        } message: {
            Text("Every widget goes back to the system background until you match again.")
        }
    }

    // MARK: Preview

    private var previewSection: some View {
        Section {
            Picker("Size", selection: $previewSize) {
                ForEach(FaceSize.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            WidgetPreviewCard(look: model.look, clock: model.clock, size: previewSize,
                              apps: model.sampleNames(for: previewSize.spotFamily))
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        } header: {
            Text("Preview")
        } footer: {
            Text("Drawn at your widget's real size over its piece of your wallpaper. iOS still draws its own thin glass edge around every widget; nothing an app may do removes it.")
        }
    }

    // MARK: See-through

    /// Matched wallpaper: two kinds of screenshot. Public API only, and a widget without
    /// a match keeps the system background instead of showing a wrong piece.
    private var seeThroughSection: some View {
        Section {
            Button {
                pickingWallpaper = true
            } label: {
                stepLabel(1, model.seeThrough.hasWallpaper
                          ? String(localized: "New wallpaper screenshot")
                          : String(localized: "Pick a screenshot of an empty Home Screen page"),
                          done: model.seeThrough.hasWallpaper)
            }

            if model.seeThrough.finding {
                Label("Your widgets are pink now. On the Home Screen, take a screenshot of every page that has widgets.",
                      systemImage: "camera.viewfinder")
                    .font(.footnote)
                Button {
                    pickingPink = true
                } label: {
                    stepLabel(3, String(localized: "Pick the pink screenshots"), done: false)
                }
                Button("Cancel", role: .cancel) { model.stopFinding() }
            } else {
                Button {
                    model.startFinding()
                } label: {
                    stepLabel(2, String(localized: "Match my widgets (turns them pink)"), done: !model.seeThrough.spots.isEmpty)
                }
            }

            if model.working {
                ProgressView()
            } else {
                status
            }

            if !model.seeThrough.spots.isEmpty {
                NavigationLink {
                    SeeThroughMapView()
                } label: {
                    Label("Where each widget was matched", systemImage: "rectangle.dashed")
                }
                Button("Start over", role: .destructive) { confirmingStartOver = true }
            }
        } header: {
            Text("See-through")
        } footer: {
            Text("Take every screenshot on this iPhone, held upright, with the same Display Zoom: the app cuts each widget's piece from the wallpaper screenshot at the exact place it found the widget, so the sizes must match. Match again after moving a widget or changing the wallpaper; until then a moved widget's piece drifts. A widget with no match keeps the system background.")
        }
    }

    @ViewBuilder
    private var status: some View {
        let state = model.seeThrough
        if !state.spots.isEmpty {
            Label("\(state.spots.count) widget(s) matched", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        if state.unreadCount > 0 {
            Label("\(state.unreadCount) widget(s) found but their ID couldn't be read — match again.",
                  systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        if !state.duplicateKeys.isEmpty {
            Label("\(state.duplicateKeys.count) ID(s) shared by two widgets. Set a new See-through ID in Edit Widget on one of them.",
                  systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    private func stepLabel(_ number: Int, _ text: String, done: Bool) -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: done ? "checkmark.circle.fill" : "\(number).circle")
                .foregroundStyle(done ? Color.green : Color.accentColor)
            Text(text)
        }
    }

    // MARK: Background

    /// Clear or your own photo. Everything here is part of the subscription; nothing
    /// inside the app is sold separately.
    private var backgroundSection: some View {
        Section {
            Picker("Background", selection: Binding(
                get: { model.look.background },
                set: { model.setBackground($0) }
            )) {
                ForEach(WidgetBackground.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            if model.look.background == .photo {
                Button {
                    pickingBackground = true
                } label: {
                    Label("Choose a photo", systemImage: "photo")
                }
            }
        } header: {
            Text("Background")
        } footer: {
            Text("Clear shows each widget's matched piece of your wallpaper. Photo draws your own picture instead.")
        }
    }

    // MARK: Apps and clock

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

    // MARK: Typography

    private var typographySection: some View {
        Section("Typography") {
            NavigationLink {
                FontPickerView(selection: $model.look.fontID)
            } label: {
                LabeledContent("Font", value: FontCatalog.displayName(for: model.look.fontID))
            }

            Picker("Weight", selection: $model.look.weight) {
                ForEach(NameWeight.allCases) { Text($0.title).tag($0) }
            }

            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Size", value: "\(Int(model.look.size)) pt")
                Slider(value: $model.look.size, in: Typography.nameRange, step: 1)
            }

            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Letter spacing", value: String(format: "%.1f pt", model.look.tracking))
                Slider(value: $model.look.tracking, in: -1...6, step: 0.5)
            }

            Picker("Letter case", selection: $model.look.letterCase) {
                ForEach(LetterCase.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: Colour

    private var colourSection: some View {
        Section {
            Picker("Color", selection: $model.look.tone) {
                ForEach(TextTone.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            if model.look.tone == .custom {
                ColorPicker("Custom color", selection: customColorBinding, supportsOpacity: false)
            }

            Button {
                model.matchWordColorToWallpaper()
            } label: {
                Label("Match my wallpaper", systemImage: "eyedropper")
            }

            Toggle("Shadow", isOn: $model.look.shadow)
        } header: {
            Text("Colour")
        } footer: {
            Text("Match my wallpaper picks a tint from your wallpaper screenshot that stays readable on it. Per-word colours live in Layouts.")
        }
    }

    // MARK: Layout

    private var layoutSection: some View {
        Section {
            Picker("Alignment", selection: $model.look.align) {
                ForEach(TextAlign.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("Position", selection: $model.look.vAlign) {
                ForEach(TextVAlign.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Spacing", value: String(format: "%.1f×", model.look.spacing))
                Slider(value: $model.look.spacing, in: 0.6...2.0, step: 0.1)
            }

            Picker("Columns", selection: $model.look.columns) {
                Text("Auto").tag(0)
                ForEach(1...4, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Inset from the edges", value: String(format: "%+.0f pt", model.look.inset))
                Slider(value: $model.look.inset, in: -8...24, step: 1)
            }

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

            NavigationLink {
                LayoutListView()
            } label: {
                Label("Layouts — drag words anywhere", systemImage: "hand.draw")
            }
            NavigationLink {
                PreviewHarnessView()
            } label: {
                Label("Check every size", systemImage: "square.grid.3x3")
            }
        } header: {
            Text("Layout")
        } footer: {
            Text("A layout made in Layouts can be picked per widget in Edit Widget › Layout; it replaces these settings for that widget.")
        }
    }

    /// Two sliders that move a block by points on top of its anchor.
    private func nudge(_ title: LocalizedStringKey, x: Binding<Double>, y: Binding<Double>) -> some View {
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
            set: { model.look.customHex = $0.hexString }
        )
    }
}

// MARK: - See-through map

/// The wallpaper screenshot with every matched widget outlined: where each piece was
/// cut. If a widget has moved since, its outline no longer sits under it — that is the
/// seam people see, and why matching again fixes it.
struct SeeThroughMapView: View {
    @EnvironmentObject private var model: AppModel
    @State private var wallpaper: UIImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("Each outline is where a widget was when you matched. Its piece of wallpaper is cut from exactly there, so a widget moved later shows a piece that no longer lines up with what's around it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                map
            }
            .padding(Spacing.m)
        }
        .background(AppBackground())
        .navigationTitle("Matches")
        .task { wallpaper = SharedStore.shared.loadWallpaper().flatMap(UIImage.init(data:)) }
    }

    private var map: some View {
        let state = model.seeThrough
        let width = max(state.spotsWidth, 1), height = max(state.spotsHeight, 1)
        return GeometryReader { geo in
            let scale = geo.size.width / CGFloat(width)
            ZStack(alignment: .topLeading) {
                if let wallpaper {
                    Image(uiImage: wallpaper).resizable().scaledToFit()
                } else {
                    Color.black.opacity(0.4)
                }
                ForEach(state.spots, id: \.key) { spot in
                    RoundedRectangle(cornerRadius: 22 * scale * CGFloat(state.pixelsPerPoint), style: .continuous)
                        .strokeBorder(Color.yellow, lineWidth: 2)
                        .frame(width: CGFloat(spot.width) * scale, height: CGFloat(spot.height) * scale)
                        .offset(x: CGFloat(spot.x) * scale, y: CGFloat(spot.y) * scale)
                }
            }
        }
        .aspectRatio(CGFloat(width / height), contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                Text("Words you haven't picked in Edit Widget are ignored. Words on the same anchor are stacked instead of drawn on top of each other.")
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

// MARK: - Photos

/// The Photo widget's library: the bundled stock photos and the person's own.
struct PhotoLibraryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var picking = false
    @State private var item: PhotosPickerItem?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: Spacing.xs)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("Pick one per widget: hold the Photo widget › Edit Widget › Photo.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: Spacing.xs) {
                    ForEach(model.photos) { photo in
                        thumbnail(photo)
                    }
                }
                NavigationLink {
                    CreditsView()
                } label: {
                    Label("Photo credits and licence", systemImage: "doc.text")
                }
            }
            .padding(Spacing.m)
        }
        .background(AppBackground())
        .navigationTitle("Photos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { picking = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add a photo")
            }
        }
        .photosPicker(isPresented: $picking, selection: $item, matching: .images)
        .onChange(of: item) { _, newItem in
            guard let newItem else { return }
            item = nil
            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                model.importPhoto(data)
            }
        }
    }

    private func thumbnail(_ photo: PhotoAsset) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image = SharedStore.shared.loadPhotoImage(photo, maxPixel: 300) {
                    FocalFill(image: image, focal: CGPoint(x: photo.focalX, y: photo.focalY))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                Text(photo.title)
                    .font(.caption2.weight(.semibold))
                    .padding(Spacing.xxs)
                    .shadow(radius: 2)
            }
            .contextMenu {
                if !photo.isStock {
                    Button("Delete", role: .destructive) { model.deletePhoto(photo) }
                }
            }
            .accessibilityLabel(photo.title)
    }
}

/// The app-side twin of the widget's focal crop, for thumbnails.
private struct FocalFill: View {
    let image: UIImage
    let focal: CGPoint

    var body: some View {
        GeometryReader { geo in
            let size = image.size
            let scale = max(geo.size.width / max(size.width, 1), geo.size.height / max(size.height, 1))
            let width = size.width * scale, height = size.height * scale
            Image(uiImage: image)
                .resizable()
                .frame(width: width, height: height)
                .offset(x: min(max(geo.size.width / 2 - focal.x * width, geo.size.width - width), 0),
                        y: min(max(geo.size.height / 2 - focal.y * height, geo.size.height - height), 0))
        }
    }
}

/// The stock photos' sources and the CC0 legal code, verbatim (Stock/CREDITS.md).
struct CreditsView: View {
    @State private var text = ""

    var body: some View {
        ScrollView {
            Text(text)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.m)
        }
        .background(AppBackground())
        .navigationTitle("Photo credits")
        .task { text = StockLibrary.credits() }
    }
}

// MARK: - Account

/// Licence controls: manage the subscription or forget the key on this iPhone.
private struct AccountView: View {
    @ObservedObject var license: LicenseStore
    @Environment(\.openURL) private var openURL
    @State private var managing = false
    @AppStorage("onboarded") private var onboarded = true

    var body: some View {
        List {
            #if APPSTORE
            Section("Subscription") {
                Button("Manage subscription") { managing = true }
                Button("Restore Purchases") { Task { await license.restore() } }
                    .disabled(license.busy)
                #if TESTFLIGHT
                if license.testUnlocked {
                    Button("Re-lock (test the paywall)", role: .destructive) {
                        license.relockForTesting()
                    }
                }
                #endif
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
                NavigationLink("Photos for the Photo widget") { PhotoLibraryView() }
                NavigationLink("Photo credits") { CreditsView() }
            }
            .listRowBackground(GlassRowBackground())
            Section {
                Button("Show the tutorial again") { onboarded = false }
                #if TESTFLIGHT
                NavigationLink("Widget diagnostics") { DiagnosticsView() }
                #endif
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
            } header: {
                Text("About")
            } footer: {
                Text("Widgets keep working when the subscription ends; the subscription unlocks the editor.")
            }
            .listRowBackground(GlassRowBackground())
        }
        .glassList()
        .navigationTitle("Settings")
        #if APPSTORE
        .manageSubscriptionsSheet(isPresented: $managing)
        #endif
    }
}

#if TESTFLIGHT
/// TestFlight only: what the widget extension wrote into the App Group. Without a Mac
/// or Console this is the only way to see an extension that cannot reach the shared
/// container, or which widgets the scan knows about.
private struct DiagnosticsView: View {
    @State private var view = ""
    @State private var records: [WidgetRecord] = []
    @State private var geometry: [SpotFamily: FaceGeometry] = [:]

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
            Section("See-through") {
                let state = SharedStore.shared.loadSeeThrough()
                LabeledContent("Generation", value: state.generation ?? "none")
                LabeledContent("Spots", value: "\(state.spots.count)")
                LabeledContent("Pixels per point", value: String(format: "%.3f", state.pixelsPerPoint))
                ForEach(SpotFamily.allCases, id: \.self) { family in
                    if let g = geometry[family] {
                        LabeledContent(String(describing: family), value: "\(Int(g.size.width))×\(Int(g.size.height)) pt, margin \(Int(g.margins?.leading ?? 0))")
                    }
                }
            }
            Section("Widgets seen") {
                ForEach(records, id: \.key) { record in
                    Text("\(record.kind) · \(record.family) · \(String(record.key, radix: 16)) · \(record.names.joined(separator: ", "))")
                        .font(.caption.monospaced())
                }
            }
            Section("view.log") {
                Text(view.isEmpty ? "Nothing yet." : view)
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
        records = SharedStore.shared.loadWidgetRecords()
        geometry = SharedStore.shared.loadGeometry()
    }
}
#endif

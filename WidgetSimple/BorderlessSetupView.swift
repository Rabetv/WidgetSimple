import SwiftUI
import PhotosUI
import Photos

/// Flat colors that make a good borderless setup.
enum BorderlessTheme: String, CaseIterable, Identifiable {
    case white, gray, black, custom
    var id: String { rawValue }

    var title: String {
        switch self {
        case .white: return "White"
        case .gray: return "Gray"
        case .black: return "Black"
        case .custom: return "Custom"
        }
    }

    var color: RGBA? {
        switch self {
        case .white: return .white
        case .gray: return RGBA(r: 0.45, g: 0.45, b: 0.47)
        case .black: return .black
        case .custom: return nil
        }
    }
}

/// Hides the glass edge iOS 26+ draws around every widget.
///
/// The edge is drawn by iOS on top of the widget, so no widget can paint over it.
/// What it shows is the wallpaper behind it, bent and highlighted. On one flat
/// color, with the widget filled in exactly that color, there is nothing to bend
/// and nothing to contrast with, so the edge disappears.
struct BorderlessSetupView: View {
    @EnvironmentObject private var model: AppModel
    let layoutID: UUID

    @State private var theme: BorderlessTheme = .black
    @State private var customColor: RGBA = .charcoal
    @State private var screenshotItem: PhotosPickerItem?
    @State private var saving = false
    @State private var saveStatus: String?
    @State private var matchStatus: String?

    private var layout: Binding<LauncherLayout> { model.binding(for: layoutID) }
    private var color: RGBA { theme.color ?? customColor }

    private var isApplied: Bool {
        let bg = layout.wrappedValue.background
        return bg.mode == .color && bg.darkColor == nil && bg.color == color
    }

    private var layoutName: String {
        layout.wrappedValue.name.isEmpty ? "this layout" : layout.wrappedValue.name
    }

    var body: some View {
        List {
            Section {
                Text("iOS draws the glass edge on top of every widget and no app can switch it off. What the edge shows is the wallpaper behind it. On one flat color, with the widget filled in exactly that color, the glass has nothing to bend or light up, so the edge disappears and only your words are left.")
                    .font(.subheadline)
            }
            colorSection
            wallpaperSection
            widgetSection
            settingsSection
            fineTuneSection
            edgeSection
        }
        .navigationTitle("Hide the glass edge")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadCurrent)
        .onChange(of: screenshotItem) { _, item in
            guard let item else { return }
            Task { await matchScreenshot(item) }
        }
    }

    // MARK: Sections

    private var colorSection: some View {
        Section {
            Picker("Color", selection: $theme) {
                ForEach(BorderlessTheme.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            if theme == .custom {
                ColorPicker("Custom color", selection: Binding(
                    get: { customColor.color },
                    set: { customColor = RGBA($0) }
                ), supportsOpacity: false)
            }
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.color)
                .frame(height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                )
        } header: {
            Text("1. Pick a color")
        } footer: {
            Text("Wallpaper and widget get exactly this color. If a faint edge still shows with one color, try another: iOS lights the glass differently on white, gray and black.")
        }
    }

    private var wallpaperSection: some View {
        Section {
            Button {
                Task { await saveWallpaper() }
            } label: {
                Label("Save wallpaper to Photos", systemImage: "square.and.arrow.down")
            }
            .disabled(saving)
            if let saveStatus {
                Text(saveStatus).font(.footnote).foregroundStyle(.secondary)
            }
            GuideStep(number: 1, text: "Settings › Wallpaper › Add New Wallpaper › Photos › pick the saved image. Don't zoom in.")
            GuideStep(number: 2, text: "In the ⋯ menu turn off Perspective Zoom, tap Add, then Set as Wallpaper Pair.")
            GuideStep(number: 3, text: "The Home Screen must show the plain image: if iOS offers Blur or Legibility Blur there, turn it off.")
        } header: {
            Text("2. Make it your wallpaper")
        } footer: {
            Text("A flat image exactly the size of your screen.")
        }
    }

    private var widgetSection: some View {
        Section {
            Button {
                apply(color)
            } label: {
                HStack {
                    Label("Fill “\(layoutName)” with this color", systemImage: "paintbrush")
                    Spacer()
                    if isApplied {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
            }
        } header: {
            Text("3. Fill the widget")
        } footer: {
            Text("Sets this layout's background to the same color. Text switches to black or white if it would be hard to read.")
        }
    }

    private var settingsSection: some View {
        Section {
            GuideStep(number: 1, text: "Home Screen: long-press › Edit › Customize › Default. Clear, Tinted and Dark restyle every widget.")
            GuideStep(number: 2, text: "Settings › Display & Brightness › \(color.luminance >= 0.5 ? "Light" : "Dark"). The other mode can dim or tint the wallpaper, which breaks the match.")
            GuideStep(number: 3, text: "Settings › Accessibility › Motion › Reduce Motion on. The wallpaper stops shifting, so it stays lined up with the widget.")
            GuideStep(number: 4, text: "Settings › Accessibility › Display & Text Size: Reduce Transparency off. If a faint line stays, flip Increase Contrast; depending on the iOS version and color one of the two settings hides it.")
        } header: {
            Text("4. iPhone settings")
        }
    }

    private var fineTuneSection: some View {
        Section {
            PhotosPicker(selection: $screenshotItem, matching: .screenshots) {
                Label("Match from a Home Screen screenshot", systemImage: "camera.viewfinder")
            }
            if let matchStatus {
                Text(matchStatus).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("5. Fine-tune")
        } footer: {
            Text("If the widget still looks like a slightly different shade: take a screenshot of the Home Screen (side button + volume up) and pick it here. WidgetSimple copies the exact color iOS shows and fills the widget with it.")
        }
    }

    private var edgeSection: some View {
        Section {
            Toggle("Edge correction", isOn: layout.background.edgeCorrection)
            if layout.wrappedValue.background.edgeCorrection {
                SliderRow(title: "Width (points)", value: layout.background.edgeWidth, range: 1...12)
                SliderRow(title: "Darker ← 0 → Lighter", value: layout.background.edgeTone, range: -60...60)
            }
        } header: {
            Text("Still see a line?")
        } footer: {
            Text("Draws a soft band just inside the widget's edge, under the glass. A darker band cancels a light rim. Change it a little, look at the Home Screen, repeat. Experimental: how well it works depends on the iOS version.")
        }
    }

    // MARK: Actions

    private func loadCurrent() {
        let bg = layout.wrappedValue.background
        guard bg.mode == .color else { return }
        if let match = BorderlessTheme.allCases.first(where: { $0.color == bg.color }) {
            theme = match
        } else {
            theme = .custom
            customColor = bg.color
        }
    }

    private func apply(_ color: RGBA) {
        var updated = layout.wrappedValue
        updated.background.mode = .color
        updated.background.color = color
        updated.background.darkColor = nil
        if abs(updated.style.color.luminance - color.luminance) < 0.35 {
            updated.style.color = color.luminance >= 0.5 ? .black : .white
        }
        layout.wrappedValue = updated
    }

    private func saveWallpaper() async {
        saving = true
        defer { saving = false }
        guard let data = wallpaperImage(color).pngData() else { return }
        let access = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard access == .authorized || access == .limited else {
            saveStatus = "WidgetSimple isn't allowed to add photos. Allow it in Settings › Privacy & Security › Photos."
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
            saveStatus = "Saved to Photos. Now set it as your wallpaper."
        } catch {
            saveStatus = "Couldn't save: \(error.localizedDescription)"
        }
    }

    /// A flat sRGB image exactly the size of the screen.
    private func wallpaperImage(_ color: RGBA) -> UIImage {
        let size = ScreenInfo.bounds.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = ScreenInfo.scale
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            RGBA(r: color.r, g: color.g, b: color.b).uiColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func matchScreenshot(_ item: PhotosPickerItem) async {
        defer { screenshotItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let found = WallpaperMatcher.dominantColor(in: image) else {
            matchStatus = "Couldn't read that screenshot."
            return
        }
        theme = .custom
        customColor = found
        apply(found)
        matchStatus = "The widget now uses the wallpaper color exactly as iOS shows it."
    }
}

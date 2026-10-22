import SwiftUI
import PhotosUI

/// The workaround for the iOS 26/27 glass widget border:
/// give the widget a background that is a pixel-exact copy of the wallpaper
/// behind it, so the system's glass outline sits on identical pixels and the
/// widget reads as plain text on the Home Screen.
struct WallpaperMatchView: View {
    @EnvironmentObject private var model: AppModel
    let layoutID: UUID

    @State private var lightPick: PhotosPickerItem?
    @State private var darkPick: PhotosPickerItem?
    @State private var markerPick: PhotosPickerItem?

    @State private var lightShot: UIImage?
    @State private var darkShot: UIImage?
    @State private var markerShot: UIImage?
    @State private var rect: CGRect?
    @State private var working = false
    @State private var message: String?
    @State private var success = false

    private var layout: Binding<LauncherLayout> { model.binding(for: layoutID) }
    private var isCalibratingThis: Bool { model.settings.calibratingLayoutID == layoutID }

    var body: some View {
        List {
            checklistSection
            wallpaperSection
            positionSection
            applySection
            if layout.wrappedValue.background.hasLightImage {
                Section {
                    Button("Remove matched background", role: .destructive) {
                        model.store.deleteBackgrounds(layoutID: layoutID)
                        layout.wrappedValue.background.hasLightImage = false
                        layout.wrappedValue.background.hasDarkImage = false
                        layout.wrappedValue.background.imageVersion += 1
                    }
                }
            }
        }
        .navigationTitle("Match wallpaper")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if rect == nil, let saved = layout.wrappedValue.background.cropRect { rect = saved.cgRect }
        }
        .onChange(of: lightPick) { _, item in load(item) { lightShot = $0 } }
        .onChange(of: darkPick) { _, item in load(item) { darkShot = $0 } }
        .onChange(of: markerPick) { _, item in
            load(item) { image in
                markerShot = image
                detect(in: image)
            }
        }
        .overlay {
            if working {
                ProgressView().controlSize(.large)
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .alert("Wallpaper match", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    // MARK: Sections

    private var checklistSection: some View {
        Section {
            ChecklistRow(text: "Home Screen style = Default. Long-press the Home Screen › Edit › Customize › Default (Light, Dark or Automatic). “Clear” and “Tinted” always replace widget backgrounds with glass.")
            ChecklistRow(text: "Wallpaper Blur off: long-press › Edit › Edit Wallpaper › Blur.")
            ChecklistRow(text: "Settings › Accessibility › Motion › Reduce Motion ON (stops the wallpaper from shifting).")
            ChecklistRow(text: "Settings › Accessibility › Display & Text Size: Reduce Transparency and Increase Contrast OFF.")
            ChecklistRow(text: "Optional: Edit › Customize › large icon size hides ALL labels under apps and widgets.")
        } header: {
            Text("Before you start")
        } footer: {
            Text("iOS 26 and 27 draw a thin glass outline around every widget, and no app can switch it off. When the widget background is an exact copy of the wallpaper, the outline has nothing to contrast with and practically disappears.")
        }
    }

    private var wallpaperSection: some View {
        Section {
            PhotosPicker(selection: $lightPick, matching: .images) {
                ShotRow(title: "Wallpaper screenshot", image: lightShot, done: lightShot != nil || layout.wrappedValue.background.hasLightImage)
            }
            PhotosPicker(selection: $darkPick, matching: .images) {
                ShotRow(title: "Dark Mode screenshot (optional)", image: darkShot, done: darkShot != nil || layout.wrappedValue.background.hasDarkImage)
            }
        } header: {
            Text("Step 1 · Your wallpaper")
        } footer: {
            Text("Long-press the Home Screen until the icons wiggle, swipe to an empty page (drag one app to a new page if you have none), then press Side button + Volume Up. If you use Dark Mode at night, take a second screenshot in Dark Mode.")
        }
    }

    private var positionSection: some View {
        Section {
            if isCalibratingThis {
                Label("Your “\(layout.wrappedValue.name)” widget is now solid magenta.", systemImage: "checkmark.circle")
                    .foregroundStyle(.pink)
                Button("Stop (turn it back)") { model.stopCalibration() }
            } else {
                Button {
                    model.startCalibration(for: layoutID)
                } label: {
                    Label("Turn my widget magenta", systemImage: "paintbrush.pointed")
                }
            }

            PhotosPicker(selection: $markerPick, matching: .images) {
                ShotRow(title: "Screenshot with the magenta widget", image: markerShot, done: rect != nil)
            }

            if let rect {
                PositionPreview(image: markerShot ?? lightShot, rect: rect)
                    .frame(height: 260)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                Nudger(rect: Binding(get: { self.rect ?? rect }, set: { self.rect = $0 }))
            }
        } header: {
            Text("Step 2 · Where the widget sits")
        } footer: {
            Text("Put the widget where you want it first (this layout must be selected in Edit Widget). Tap “Turn my widget magenta”, go to the Home Screen, take a screenshot, come back and pick it. Only needed again if you move the widget.")
        }
    }

    private var applySection: some View {
        Section {
            Button {
                apply()
            } label: {
                Label(success ? "Background created" : "Create background", systemImage: success ? "checkmark.seal.fill" : "wand.and.stars")
            }
            .disabled(rect == nil || (lightShot == nil && darkShot == nil))
        } header: {
            Text("Step 3 · Apply")
        } footer: {
            Text("The widget updates within a second. If it looks a few pixels off, nudge the frame above and apply again.")
        }
    }

    // MARK: Actions

    private func load(_ item: PhotosPickerItem?, then handler: @escaping (UIImage) -> Void) {
        guard let item else { return }
        working = true
        Task {
            defer { working = false }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                message = "That image couldn't be loaded."
                return
            }
            handler(WallpaperMatcher.normalized(image))
        }
    }

    private func detect(in image: UIImage) {
        working = true
        let measured = model.metrics.size(for: layout.wrappedValue.size)
        let pixelsPerPoint = WallpaperMatcher.pixelSize(image).width / max(ScreenInfo.width, 1)
        Task {
            let found = await Task.detached(priority: .userInitiated) {
                WallpaperMatcher.findMarker(in: image)
            }.value
            working = false
            guard let found else {
                message = "No magenta widget found in that screenshot. Make sure you tapped “Turn my widget magenta”, the widget shows this layout, and the screenshot was taken afterwards."
                return
            }
            rect = WallpaperMatcher.refine(found, measuredPoints: measured, pixelsPerPoint: pixelsPerPoint)
            success = false
        }
    }

    private func apply() {
        guard let rect else { return }
        var background = layout.wrappedValue.background
        let referenceSize = (markerShot ?? lightShot ?? darkShot).map(WallpaperMatcher.pixelSize)

        for (shot, dark) in [(lightShot, false), (darkShot, true)] {
            guard let shot else { continue }
            if let referenceSize, WallpaperMatcher.pixelSize(shot) != referenceSize {
                message = "The screenshots have different sizes. Take all of them on this iPhone without zooming."
                return
            }
            guard let cropped = WallpaperMatcher.crop(shot, to: rect),
                  model.store.saveBackground(cropped, layoutID: layoutID, dark: dark) else {
                message = "Couldn't create the background image."
                return
            }
            if dark { background.hasDarkImage = true } else { background.hasLightImage = true }
        }
        if !background.hasLightImage, background.hasDarkImage, let darkShot,
           let cropped = WallpaperMatcher.crop(darkShot, to: rect),
           model.store.saveBackground(cropped, layoutID: layoutID, dark: false) {
            background.hasLightImage = true
        }
        background.mode = .wallpaper
        background.cropRect = PixelRect(rect)
        if let referenceSize {
            background.screenshotSize = PixelSize(width: Double(referenceSize.width), height: Double(referenceSize.height))
        }
        background.imageVersion += 1
        layout.wrappedValue.background = background
        model.stopCalibration()
        model.saveNow()
        success = true
    }
}

// MARK: - Small views

private struct ChecklistRow: View {
    let text: String
    var body: some View {
        Label {
            Text(text).font(.footnote)
        } icon: {
            Image(systemName: "checkmark.square").foregroundStyle(.secondary)
        }
    }
}

private struct ShotRow: View {
    let title: String
    let image: UIImage?
    let done: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "photo.on.rectangle")
                    .frame(width: 36, height: 60)
                    .foregroundStyle(.secondary)
            }
            Text(title).foregroundStyle(.primary)
            Spacer()
            if done {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
    }
}

/// Shows the screenshot with the detected widget frame drawn on top.
private struct PositionPreview: View {
    let image: UIImage?
    let rect: CGRect

    var body: some View {
        GeometryReader { geo in
            if let image {
                let size = WallpaperMatcher.pixelSize(image)
                // Zoom so the widget area fills most of the preview.
                let zoom = min(geo.size.width / max(rect.width * 1.4, 1), geo.size.height / max(rect.height * 2.2, 1))
                let center = CGPoint(x: rect.midX * zoom, y: rect.midY * zoom)
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: size.width * zoom, height: size.height * zoom)
                    Rectangle()
                        .strokeBorder(Color.green, lineWidth: 2)
                        .frame(width: rect.width * zoom, height: rect.height * zoom)
                        .offset(x: rect.minX * zoom, y: rect.minY * zoom)
                }
                .offset(x: geo.size.width / 2 - center.x, y: geo.size.height / 2 - center.y)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .clipped()
            } else {
                Text("Frame: \(Int(rect.minX)), \(Int(rect.minY)) · \(Int(rect.width)) × \(Int(rect.height)) px")
                    .font(.footnote.monospacedDigit())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// Fine-tune the detected frame pixel by pixel.
private struct Nudger: View {
    @Binding var rect: CGRect

    var body: some View {
        VStack(spacing: 10) {
            Text("x \(Int(rect.minX))  y \(Int(rect.minY))  ·  \(Int(rect.width)) × \(Int(rect.height)) px")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                nudge("arrow.left") { rect.origin.x -= 1 }
                nudge("arrow.up") { rect.origin.y -= 1 }
                nudge("arrow.down") { rect.origin.y += 1 }
                nudge("arrow.right") { rect.origin.x += 1 }
            }
            HStack(spacing: 16) {
                Button("Narrower") { rect = rect.insetBy(dx: 1, dy: 0) }
                Button("Wider") { rect = rect.insetBy(dx: -1, dy: 0) }
                Button("Shorter") { rect = rect.insetBy(dx: 0, dy: 1) }
                Button("Taller") { rect = rect.insetBy(dx: 0, dy: -1) }
            }
            .font(.footnote)
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }

    private func nudge(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: 28, height: 22)
        }
    }
}

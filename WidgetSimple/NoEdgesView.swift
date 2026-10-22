import SwiftUI
import PhotosUI
import Photos

/// A flat wallpaper color plus the iPhone settings that hide the widget glass edges.
///
/// iOS draws the edge on top of every widget. On iOS 27 it disappears when the
/// wallpaper is one flat color, the widgets are clear (or exactly that color), and
/// these settings are set (Dark: Increase Contrast on, Show Borders off; Gray: both
/// off; White: Show Borders on). On iOS 26 a faint outline always stays.
enum EdgeTheme: String, CaseIterable, Identifiable {
    case black, gray, white
    var id: String { rawValue }

    var title: String {
        switch self {
        case .black: return "Black"
        case .gray: return "Gray"
        case .white: return "White"
        }
    }

    var color: RGBA {
        switch self {
        case .black: return .black
        case .gray: return RGBA(r: 0.45, g: 0.45, b: 0.47)
        case .white: return .white
        }
    }

    var darkMode: Bool { self != .white }
    var increaseContrast: Bool { self == .black }
    var showBorders: Bool { self == .white }
}

struct NoEdgesView: View {
    @EnvironmentObject private var model: AppModel

    @State private var theme: EdgeTheme = .black
    @State private var screenshotItem: PhotosPickerItem?
    @State private var saved = false
    @State private var saving = false
    @State private var message: String?

    private var isIOS27: Bool { ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 }

    var body: some View {
        List {
            Section {
                Picker("Color", selection: $theme) {
                    ForEach(EdgeTheme.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Only works with a plain wallpaper.")
            }

            Section {
                Button {
                    Task { await saveWallpaper() }
                } label: {
                    StepRow(number: 1, title: "Save wallpaper", detail: "Then set it: Settings › Wallpaper. Blur off.", done: saved)
                }
                .disabled(saving)

                Button {
                    model.applyClear(on: theme.color)
                } label: {
                    StepRow(number: 2, title: "Make all widgets clear", detail: nil, done: model.allClear)
                }

                StepRow(number: 3, title: "Home Screen", detail: "Hold › Edit › Customize › Default, large icons.", done: false)
                StepRow(number: 4, title: "iPhone settings", detail: nil, done: false)
                SettingRow(name: "Display & Brightness", value: theme.darkMode ? "Dark" : "Light")
                if isIOS27 {
                    SettingRow(name: "Increase Contrast", value: theme.increaseContrast ? "On" : "Off")
                    SettingRow(name: "Show Borders", value: theme.showBorders ? "On" : "Off")
                    SettingRow(name: "Reduce Transparency", value: "Off")
                } else {
                    SettingRow(name: "Reduce Motion", value: "On")
                    SettingRow(name: "Increase Contrast", value: "Off")
                    SettingRow(name: "Reduce Transparency", value: "Off")
                }
            } footer: {
                Text("Contrast, Borders, Transparency: Settings › Accessibility › Display & Text Size.")
            }

            Section {
                Button {
                    model.applyBackground(theme.color)
                } label: {
                    HStack {
                        Text("Use solid \(theme.title.lowercased()) instead")
                        Spacer()
                        if model.usesBackground(theme.color) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }
                }
                PhotosPicker(selection: $screenshotItem, matching: .screenshots) {
                    Label("Match the color from a screenshot", systemImage: "camera.viewfinder")
                }
                if let message {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                }
            } header: {
                Text("Gray box instead of clear?")
            }

            if !isIOS27 {
                Section {
                    Text("iOS 26 always keeps a faint edge. iOS 27 can hide it fully.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Hide the edges")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !model.clock.clear, let match = EdgeTheme.allCases.first(where: { $0.color == model.clock.background }) {
                theme = match
            }
        }
        .onChange(of: theme) { _, _ in saved = false }
        .onChange(of: screenshotItem) { _, item in
            guard let item else { return }
            Task { await matchScreenshot(item) }
        }
    }

    // MARK: Actions

    private func saveWallpaper() async {
        saving = true
        defer { saving = false }
        guard let data = wallpaperImage(theme.color).pngData() else { return }
        let access = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard access == .authorized || access == .limited else {
            message = "Allow Photos in Settings › WidgetSimple."
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
            saved = true
        } catch {
            message = "Couldn't save: \(error.localizedDescription)"
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
            message = "Couldn't read that screenshot."
            return
        }
        model.applyBackground(found)
        message = "Done: widgets now use the exact wallpaper color."
    }
}

private struct StepRow: View {
    let number: Int
    let title: String
    let detail: String?
    let done: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.bold().monospacedDigit())
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor.opacity(0.2)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.primary)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if done {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
    }
}

private struct SettingRow: View {
    let name: String
    let value: String

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(value == "Off" ? Color.secondary : Color.accentColor)
        }
        .padding(.leading, 36)
    }
}

/// Black, gray and white (the No-edges colors) plus a custom color.
struct ColorSwatches: View {
    @Binding var selection: RGBA

    var body: some View {
        HStack(spacing: 14) {
            ForEach(EdgeTheme.allCases) { theme in
                Button {
                    selection = theme.color
                } label: {
                    Circle()
                        .fill(theme.color.color)
                        .frame(width: 34, height: 34)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1))
                        .overlay {
                            if selection == theme.color {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(theme.color.luminance >= 0.5 ? Color.black : Color.white)
                            }
                        }
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(theme.title)
            }
            Spacer()
            ColorPicker("Custom color", selection: Binding(
                get: { selection.color },
                set: { selection = RGBA($0) }
            ), supportsOpacity: false)
            .labelsHidden()
        }
    }
}

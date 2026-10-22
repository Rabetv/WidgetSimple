import SwiftUI
import UIKit

/// The whole app: five steps on one screen.
struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingFonts = false
    @State private var saving = false

    private var theme: Theme { model.look.theme }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("WidgetSimple")
                    .font(.largeTitle.bold())
                    .padding(.top, 8)

                WidgetPreviewCard(look: model.look)

                Step(number: 1, title: "Pick a color") {
                    colorPicker
                }
                Step(number: 2, title: "Pick letters") {
                    fontPicker
                    Picker("Size", selection: $model.look.textSize) {
                        ForEach(TextSize.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Step(number: 3, title: "Save the wallpaper", done: model.savedWallpaper == theme) {
                    wallpaper
                }
                Step(number: 4, title: "Change iPhone settings") {
                    settings
                }
                Step(number: 5, title: "Add the widget") {
                    Hint(symbol: "hand.tap", text: "Hold the Home Screen › Edit › Add Widget › the WidgetSimple icon.")
                    Hint(symbol: "checklist", text: "Hold the widget › Edit Widget. Pick your apps and a clock.")
                }

                if !model.store.isAppGroupAvailable {
                    Label("App Group missing: widgets can't load.", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .sheet(isPresented: $showingFonts) {
            NavigationStack {
                FontPickerView(selection: $model.look.fontID)
            }
        }
    }

    // MARK: 1. Color

    private var colorPicker: some View {
        HStack(spacing: 0) {
            ForEach(Theme.allCases) { option in
                let selected = option == theme
                Button {
                    model.look.theme = option
                } label: {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(option.background.color)
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
                            .overlay {
                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(.title2.bold())
                                        .foregroundStyle(option.text.color)
                                }
                            }
                            .frame(width: 68, height: 68)
                            .padding(4)
                            .overlay(Circle().strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 3))
                        Text(option.title)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    // MARK: 2. Letters

    private var fontPicker: some View {
        let isQuickPick = FontCatalog.quickPicks.contains { $0.id == model.look.fontID }
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(FontCatalog.quickPicks) { font in
                FontChip(fontID: font.id, name: font.name, selected: font.id == model.look.fontID) {
                    model.look.fontID = font.id
                }
            }
            FontChip(fontID: isQuickPick ? FontCatalog.systemID : model.look.fontID,
                     name: "More", sample: isQuickPick ? "···" : "Aa", selected: !isQuickPick) {
                showingFonts = true
            }
        }
    }

    // MARK: 3. Wallpaper

    @ViewBuilder
    private var wallpaper: some View {
        Text("A plain \(theme.title.lowercased()) picture. The widgets melt into it.")
            .foregroundStyle(.secondary)
        Button {
            Task {
                saving = true
                await model.saveWallpaper()
                saving = false
            }
        } label: {
            Label(model.savedWallpaper == theme ? "Saved to Photos" : "Save wallpaper",
                  systemImage: model.savedWallpaper == theme ? "checkmark" : "square.and.arrow.down")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .disabled(saving)
        Hint(symbol: "photo", text: "In Photos: Share › Use as Wallpaper › Add › Set as Wallpaper Pair. Blur off.")
        if let photos = URL(string: "photos-redirect://") {
            Button("Open Photos") { UIApplication.shared.open(photos) }
                .font(.headline)
        }
    }

    // MARK: 4. Settings

    @ViewBuilder
    private var settings: some View {
        SettingRow(name: "Appearance", value: theme.darkMode ? "Dark" : "Light",
                   path: "Settings › Display & Brightness")
        SettingRow(name: "Increase Contrast", value: theme.increaseContrast ? "On" : "Off",
                   path: "Settings › Accessibility › Display & Text Size")
        SettingRow(name: "Show Borders", value: theme.showBorders ? "On" : "Off",
                   path: "Settings › Accessibility › Display & Text Size")
        SettingRow(name: "Reduce Transparency", value: "Off",
                   path: "Settings › Accessibility › Display & Text Size")
        SettingRow(name: "Home Screen", value: "Default",
                   path: "Hold the Home Screen › Edit › Customize › Default, large icons")
    }
}

// MARK: - Pieces

/// The widget as it will look: same color, font and size as on the Home Screen.
private struct WidgetPreviewCard: View {
    let look: Look

    var body: some View {
        TimelineView(.everyMinute) { context in
            LauncherFace(look: look, clock: .timeAndDate, date: context.date, size: .medium,
                         apps: ["Phone", "Messages", "Music"])
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(338.0 / 158.0, contentMode: .fit)
        .background(look.theme.background.color)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: look)
    }
}

private struct Step<Content: View>: View {
    let number: Int
    let title: String
    var done = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(done ? Color.green : Color.accentColor)
                    if done {
                        Image(systemName: "checkmark").font(.headline.bold())
                    } else {
                        Text("\(number)").font(.headline.bold())
                    }
                }
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                Text(title)
                    .font(.title2.bold())
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct FontChip: View {
    let fontID: String
    let name: String
    var sample = "Aa"
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(sample)
                    .font(FontCatalog.font(id: fontID, size: 26))
                    .lineLimit(1)
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct SettingRow: View {
    let name: String
    let value: String
    let path: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.headline)
                Text(path).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(value == "Off" ? Color.primary : Color.white)
                .background(value == "Off" ? Color(.tertiarySystemFill) : Color.accentColor, in: Capsule())
        }
    }
}

private struct Hint: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol).foregroundStyle(.tint)
        }
        .font(.callout)
    }
}

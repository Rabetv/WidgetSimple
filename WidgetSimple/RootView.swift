import SwiftUI
import UIKit

/// The whole app: three steps on one screen.
struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingFonts = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("WidgetSimple")
                    .font(.largeTitle.bold())
                    .padding(.top, 8)

                WidgetPreviewCard(look: model.look)

                Step(number: 1, title: "Add the widget") {
                    Hint(symbol: "hand.tap", text: "Hold the Home Screen › Edit › Add Widget › the WidgetSimple icon.")
                    Hint(symbol: "checklist", text: "Hold the widget › Edit Widget. Pick your apps and a clock.")
                }
                Step(number: 2, title: "Pick a background") {
                    backgroundPicker
                }
                Step(number: 3, title: "Pick letters") {
                    fontPicker
                    Picker("Size", selection: $model.look.textSize) {
                        ForEach(TextSize.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Align", selection: $model.look.align) {
                        ForEach(TextAlign.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Color", selection: $model.look.tone) {
                        ForEach(TextTone.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
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

    private var backgroundPicker: some View {
        HStack(spacing: 12) {
            ForEach(BackgroundStyle.allCases) { style in
                let selected = style == model.look.background
                Button {
                    model.look.background = style
                } label: {
                    VStack(spacing: 8) {
                        WidgetBackdrop(style: style, shape: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                Text("Aa")
                                    .font(model.look.font(size: 22))
                                    .foregroundStyle(model.look.tone.color)
                            }
                            .frame(height: 64)
                            .padding(10)
                            .background(LinearGradient.sampleWallpaper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 3)
                            )
                        Text(style.title)
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
}

// MARK: - Pieces

/// The widget as it will look on the Home Screen, over a sample wallpaper.
private struct WidgetPreviewCard: View {
    let look: Look

    var body: some View {
        TimelineView(.everyMinute) { context in
            LauncherFace(look: look, clock: .timeAndDate, date: context.date, size: .medium,
                         apps: ["Phone", "Messages", "Music"], color: look.tone.color)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(338.0 / 158.0, contentMode: .fit)
        .background {
            WidgetBackdrop(style: look.background, shape: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .padding(18)
        .background(LinearGradient.sampleWallpaper, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: look)
    }
}

private extension LinearGradient {
    /// Stands in for the wallpaper in the app.
    static let sampleWallpaper = LinearGradient(
        colors: [Color(red: 0.98, green: 0.55, blue: 0.45), Color(red: 0.45, green: 0.35, blue: 0.85)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

private struct Step<Content: View>: View {
    let number: Int
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text("\(number)")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor, in: Circle())
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

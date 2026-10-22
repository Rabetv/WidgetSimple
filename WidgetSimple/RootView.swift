import SwiftUI
import UIKit
import PhotosUI

/// The whole app: three steps on one screen.
struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingFonts = false
    @State private var pickingWallpaper = false
    @State private var wallpaperItem: PhotosPickerItem?
    @State private var pickingPink = false
    @State private var pinkItem: PhotosPickerItem?

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
                Step(number: 2, title: "Make it see-through") {
                    seeThroughSteps
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
        .onChange(of: scenePhase) { _, phase in
            // Back from taking the pink screenshot: offer it right away.
            if phase == .active && model.seeThrough.finding && !pickingWallpaper {
                pickingPink = true
            }
        }
    }

    // MARK: See-through

    @ViewBuilder
    private var seeThroughSteps: some View {
        let state = model.seeThrough
        SubStep(letter: "A", done: state.hasWallpaper,
                text: "Set a wallpaper that ships with the app, or pick a screenshot of your own.")
        catalogPicker
        Button {
            pickingWallpaper = true
        } label: {
            Label(state.hasWallpaper ? "Pick a new wallpaper screenshot" : "Pick that screenshot", systemImage: "photo")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)

        SubStep(letter: "B", done: !state.spots.isEmpty && !state.finding,
                text: "Tap Find my widgets. They turn pink. Take a screenshot of the Home Screen, then come back.")
        if state.finding {
            Button {
                pickingPink = true
            } label: {
                Label("Pick the pink screenshot", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button("Stop", role: .cancel) { model.stopFinding() }
                .frame(maxWidth: .infinity)
        } else {
            Button {
                model.startFinding()
            } label: {
                Label("Find my widgets", systemImage: "viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }

        if model.working {
            ProgressView().frame(maxWidth: .infinity)
        } else if state.hasWallpaper && !state.spots.isEmpty && !state.finding {
            Label(state.spots.count == 1 ? "1 widget is see-through." : "\(state.spots.count) widgets are see-through.",
                  systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.headline)
        }
        Text("New wallpaper, or moved a widget? Do A and B again. With Home Screen › Customize › Clear, iOS makes widgets see-through by itself.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    /// The wallpapers that ship with the app, the way the see-through widget apps offer
    /// them: pick one, set it in Settings, and the app already has the pixels.
    private var catalogPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wallpapers that come with it")
                .font(.subheadline.bold())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(WallpaperCatalog.all) { wallpaper in
                        Button {
                            Task { await model.useCatalogWallpaper(wallpaper) }
                        } label: {
                            VStack(spacing: 6) {
                                WallpaperThumbnail(wallpaper: wallpaper)
                                Text(wallpaper.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .frame(width: 78)
                            .padding(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(model.seeThrough.wallpaperName == wallpaper.id
                                                  ? Color.accentColor : .clear, lineWidth: 3)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            Text("Set it as your iPhone wallpaper once. The pink screenshot below is still needed: iOS doesn't tell a widget which slot of the Home Screen it sits in, so the app finds it there.")
                .font(.footnote)
                .foregroundStyle(.secondary)
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

/// The widget as it will look on the Home Screen: just the words on the wallpaper.
private struct WidgetPreviewCard: View {
    let look: Look

    var body: some View {
        TimelineView(.everyMinute) { context in
            LauncherFace(look: look, clock: .timeAndDate, date: context.date, size: .medium,
                         apps: ["Phone", "Messages", "Music"], color: look.tone.color)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(338.0 / 158.0, contentMode: .fit)
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

/// One bundled wallpaper, decoded small: the slices are 1047 px wide and there are five.
private struct WallpaperThumbnail: View {
    let wallpaper: CatalogWallpaper
    @State private var image: UIImage?

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.tertiarySystemFill))
            .frame(width: 78, height: 150)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .task(id: wallpaper.id) {
                let id = wallpaper.id
                image = await Task.detached(priority: .userInitiated) {
                    CatalogWallpaper.thumbnail(id, maxPixel: 240)
                }.value
            }
    }
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

private struct SubStep: View {
    let letter: String
    let done: Bool
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Group {
                if done {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    Text(letter).font(.subheadline.bold()).foregroundStyle(.tint)
                }
            }
            .frame(width: 22)
            Text(text).font(.callout)
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

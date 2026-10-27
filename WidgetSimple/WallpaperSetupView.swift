import PhotosUI
import SwiftUI
import UIKit
import WidgetKit

/// The see-through setup, once, in two steps: the empty Home Screen page in Light Mode,
/// then the same page in Dark Mode. The app cuts the wallpaper for every widget slot from
/// those; each widget picks its slot in Edit Widget. Or a photo of the user's own behind
/// every widget instead.
struct WallpaperSetupView: View {
    /// The first-run step after the paywall: the two wallpaper screenshots, which every
    /// widget needs before it shows its apps. No photo alternative and no fine-tuning.
    let required: Bool
    /// Called by Continue once setup is complete; nil closes the screen instead.
    let onDone: (() -> Void)?

    init(required: Bool = false, onDone: (() -> Void)? = nil) {
        self.required = required
        self.onDone = onDone
    }

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented
    @Environment(\.scenePhase) private var scenePhase
    @State private var pickingShot = false
    @State private var pickingPhoto = false
    @State private var target = Shot.bright
    @State private var shotItem: PhotosPickerItem?
    @State private var photoItem: PhotosPickerItem?
    /// The iPhone's own appearance; the app itself is always dark.
    @State private var systemDark = false
    /// WidgetSimple widgets on the Home Screen; nil until iOS answers.
    @State private var placed: Int?

    private enum Shot { case bright, dark }

    private var state: SeeThroughState { model.seeThrough }
    private var canContinue: Bool {
        if required { return model.hasWallpaperShots }
        return model.isWallpaperReady && (onDone != nil || isPresented)
    }
    private var usesPhoto: Bool { model.look.background == .photo }
    /// The first step still to do, which is drawn as the current one.
    private var current: Int? {
        if !state.hasWallpaper { return 1 }
        if !state.hasDarkWallpaper { return 2 }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                Text(required
                     ? "Before you add a widget, the app needs two screenshots of your wallpaper: one in Light Mode, one in Dark Mode. Your widgets show the piece of wallpaper behind them, so they blend into the Home Screen."
                     : "Your widgets are see-through: each one shows the piece of wallpaper behind it. The app cuts those pieces from two screenshots of an empty Home Screen page, taken once.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                brightStep
                darkStep
                positionNote
                notice
                if canContinue {
                    Button(action: finish) {
                        Label("Continue", systemImage: "arrow.right")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.accentColor)
                }
                if !required {
                    if state.isComplete { lineUp }
                    photoAlternative
                }
            }
            .padding(.horizontal, LineArt.margin)
            .padding(.bottom, 40)
        }
        .background(AppBackground())
        .animation(.snappy(duration: 0.25), value: state)
        .animation(.snappy(duration: 0.25), value: model.look.background)
        .sensoryFeedback(.success, trigger: model.isWallpaperReady) { _, ready in ready }
        .photosPicker(isPresented: $pickingShot, selection: $shotItem, matching: .screenshots)
        .photosPicker(isPresented: $pickingPhoto, selection: $photoItem, matching: .images)
        .onChange(of: shotItem) { _, item in
            guard let item else { return }
            shotItem = nil
            let shot = target
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    model.message = "Couldn't load that screenshot."
                    return
                }
                switch shot {
                case .bright: await model.useWallpaper(data)
                case .dark: await model.useDarkWallpaper(data)
                }
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    model.message = "Couldn't load that photo."
                    return
                }
                model.useBackgroundPhoto(data)
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            systemDark = Self.systemIsDark
            placed = try? await WidgetCenter.shared.currentConfigurations().count
        }
    }

    // MARK: Parts

    private var header: some View {
        HStack(alignment: .top) {
            ScreenHeader(title: "Wallpaper")
            if isPresented {
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(BevelKeyStyle(size: 36))
                    .accessibilityLabel("Close")
                    .padding(.top, 8)
                    .padding(.leading, 8)
            }
        }
    }

    private var brightStep: some View {
        SetupStep(number: 1, title: "Light Mode wallpaper", done: state.hasWallpaper, current: current == 1) {
            Instructions(lines: [
                "Switch your iPhone to Light Mode: open Control Center and turn Dark Mode off, or go to Settings › Display & Brightness › Light.",
                "Go to an empty Home Screen page — swipe left past your last page of apps — and take a screenshot: press the side button and volume up together.",
                "Come back here and pick that screenshot.",
            ])
            if systemDark && !state.hasWallpaper {
                Hint("Your iPhone is in Dark Mode right now.")
            }
        } action: {
            Button(state.hasWallpaper ? "Replace" : "Pick the Light Mode screenshot") { pick(.bright) }
                .buttonStyle(PillStyle(selected: current == 1))
        }
    }

    private var darkStep: some View {
        SetupStep(number: 2, title: "Dark Mode wallpaper", done: state.hasDarkWallpaper, current: current == 2) {
            Instructions(lines: [
                "Switch your iPhone to Dark Mode: open Control Center and turn Dark Mode on, or go to Settings › Display & Brightness › Dark.",
                "Take a screenshot of the same empty page. iOS darkens the wallpaper (or shows its dark version), so the widgets need their own dark pieces.",
                "Come back here and pick that screenshot.",
            ])
            if !systemDark && !state.hasDarkWallpaper {
                Hint("Your iPhone is in Light Mode right now.")
            }
        } action: {
            Button(state.hasDarkWallpaper ? "Replace" : "Pick the Dark Mode screenshot") { pick(.dark) }
                .buttonStyle(PillStyle(selected: current == 2))
        }
    }

    /// How a widget finds its piece: WidgetKit doesn't say where a widget sits, so the
    /// person tells it once in Edit Widget (top left is the default).
    private var positionNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Hint("Each widget shows the wallpaper of its own spot. Not at the top left? Touch and hold the widget › Edit Widget › Position (and Side for a small widget).")
            if placed == 0 && state.isComplete {
                Hint("Next: add a widget. Touch and hold the Home Screen, tap Edit › Add Widget, and choose WidgetSimple.")
            }
            if model.working {
                HStack(spacing: 10) {
                    ProgressView()
                    Micro("Cutting wallpaper pieces")
                }
            }
        }
    }

    /// Only for an iPhone whose Home Screen grid sits a little differently from the one
    /// the app knows: moves the wallpaper inside every widget up or down.
    private var lineUp: some View {
        ModuleFrame("Fine-tune", stamp: state.offsetY == 0 ? nil : "\(Int(state.offsetY)) pt") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Wallpaper slightly off?")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                Text("If the wallpaper inside your widgets sits a little too high or too low, move it here. It applies to every widget.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    // Cutting lower moves the picture inside the widget up.
                    Button("Move up") { Task { await model.nudgeWallpaper(by: 1) } }
                        .buttonStyle(PillStyle())
                    Button("Move down") { Task { await model.nudgeWallpaper(by: -1) } }
                        .buttonStyle(PillStyle())
                    if state.offsetY != 0 {
                        Button("Reset") { Task { await model.resetWallpaperNudge() } }
                            .buttonStyle(PillStyle())
                    }
                }
                .disabled(model.working)
            }
        }
    }

    @ViewBuilder
    private var notice: some View {
        if let message = model.message {
            HStack(alignment: .top, spacing: 10) {
                Stamp("Notice", emphasized: true)
                Text(message)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button { model.message = nil } label: { Image(systemName: "xmark") }
                    .buttonStyle(BevelKeyStyle(size: 28))
                    .accessibilityLabel("Dismiss")
            }
            .padding(LineArt.inset)
            .glassPanel(cornerRadius: LineArt.innerRadius)
        }
    }

    private var photoAlternative: some View {
        ModuleFrame("Or", stamp: usesPhoto ? "In use" : nil) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Use a photo instead")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                Text(usesPhoto
                     ? "Every widget shows your photo instead of the wallpaper. Switch back to see-through any time; the screenshots above stay saved."
                     : "Rather skip the screenshots? Every widget can show a photo of your own instead of the wallpaper behind it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button(usesPhoto ? "Choose another photo" : "Choose a photo") { pickingPhoto = true }
                        .buttonStyle(PillStyle(selected: usesPhoto))
                    if usesPhoto {
                        Button("Back to see-through") { model.setBackground(.clear) }
                            .buttonStyle(PillStyle())
                    }
                }
            }
        }
    }

    // MARK: Actions

    private func pick(_ shot: Shot) {
        model.message = nil
        target = shot
        pickingShot = true
    }

    private func finish() {
        if let onDone { onDone() } else { dismiss() }
    }

    /// The iPhone's appearance setting. The app forces dark glass on its own windows, so
    /// read it from the screen, which the app's override doesn't touch.
    private static var systemIsDark: Bool {
        let screen = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen }.first
        return screen?.traitCollection.userInterfaceStyle == .dark
    }
}

/// One big step: a number that turns into a tick, a title, plain instructions, and its
/// buttons. The current step is tinted and outlined.
private struct SetupStep<Content: View, Action: View>: View {
    let number: Int
    let title: String
    let done: Bool
    let current: Bool
    let content: Content
    let action: Action

    init(number: Int, title: String, done: Bool, current: Bool,
         @ViewBuilder content: () -> Content, @ViewBuilder action: () -> Action) {
        self.number = number
        self.title = title
        self.done = done
        self.current = current
        self.content = content()
        self.action = action()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundStyle(.black)
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(Color.accentColor))
                    } else {
                        Text("\(number)")
                            .font(.metric(24))
                            .monospacedDigit()
                            .frame(width: 46, height: 46)
                            .overlay { Circle().strokeBorder(Color.primary.opacity(current ? 0.9 : 0.4), lineWidth: current ? 2 : 1) }
                    }
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Micro("Step \(number)")
                    Text(title)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Stamp(done ? "Done" : current ? "Next" : "To do", emphasized: done || current)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Step \(number), \(title), \(done ? "done" : "not done yet")")
            Hairline()
            content
            action
        }
        .padding(LineArt.inset + 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: LineArt.moduleRadius, tint: current ? Color.accentColor.opacity(0.18) : nil)
        .lineBorder(radius: LineArt.moduleRadius, weight: current ? .bold : .pixel,
                    opacity: current ? 0.8 : 0.3)
        .opacity(done || current ? 1 : 0.8)
    }
}

/// Numbered how-to lines in plain language.
private struct Instructions: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(lines.indices, id: \.self) { index in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1).")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Text(lines[index])
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// A short remark under the instructions, such as the iPhone's current appearance.
private struct Hint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Label {
            Text(text)
                .font(.footnote.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle")
        }
        .foregroundStyle(Color.accentColor)
    }
}

// MARK: - Gate

/// Shows `WallpaperSetupView` until the widgets can look right: bright and dark
/// wallpaper screenshots, or a photo background. Then shows `content`.
/// Setup finished here waits for its Continue button, so the last tick is seen.
/// The AltStore build removes the widget container instead and never gates.
///
///     WallpaperGate { TemplatePicker() }
///     SaveStep().wallpaperGated()
struct WallpaperGate<Content: View>: View {
    @EnvironmentObject private var model: AppModel
    /// True while the setup screen is showing here, until Continue.
    @State private var settingUp = false
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        #if APPSTORE
        if model.isWallpaperReady && !settingUp {
            content
        } else {
            WallpaperSetupView { settingUp = false }
                .onAppear { settingUp = true }
        }
        #else
        content
        #endif
    }
}

extension View {
    /// Wraps this view in `WallpaperGate`: the wallpaper setup comes first until it's done.
    func wallpaperGated() -> some View {
        WallpaperGate { self }
    }
}

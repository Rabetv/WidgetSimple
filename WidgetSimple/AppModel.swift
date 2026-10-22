import SwiftUI
import UIKit
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published var layouts: [LauncherLayout] {
        didSet { scheduleSave() }
    }
    @Published var settings: AppSettings {
        didSet {
            store.saveSettings(settings)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    @Published private(set) var metrics: WidgetMetrics
    /// True while the app is only forwarding a widget tap to another app.
    @Published var isForwarding = false
    @Published var launchError: String?
    @Published var clock: ClockStyle {
        didSet {
            store.saveClock(clock)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    let store = SharedStore.shared
    private var saveTask: Task<Void, Never>?

    init() {
        FontRegistry.registerAllOnce()
        var loaded = store.loadLayouts()
        if loaded.isEmpty {
            loaded = [LauncherLayout.starter()]
            store.saveLayouts(loaded)
        }
        layouts = loaded
        settings = store.loadSettings()
        metrics = store.loadMetrics()
        clock = store.loadClock()
    }

    // MARK: No edges

    /// Gives every widget (launchers and clock) a flat background in `color`, and
    /// switches text to black or white where it would be hard to read.
    func applyBackground(_ color: RGBA) {
        let readable: RGBA = color.luminance >= 0.5 ? .black : .white
        layouts = layouts.map { layout in
            var updated = layout
            updated.background.mode = .color
            updated.background.color = color
            updated.background.darkColor = nil
            if abs(updated.style.color.luminance - color.luminance) < 0.35 {
                updated.style.color = readable
            }
            return updated
        }
        var newClock = clock
        newClock.clear = false
        newClock.background = color
        if abs(newClock.color.luminance - color.luminance) < 0.35 {
            newClock.color = readable
        }
        clock = newClock
    }

    /// True when every widget already uses `color` as its background.
    func usesBackground(_ color: RGBA) -> Bool {
        !clock.clear && clock.background == color && layouts.allSatisfy {
            $0.background.mode == .color && $0.background.darkColor == nil && $0.background.color == color
        }
    }

    /// Makes every widget clear, with text readable on a `wallpaper` colored wallpaper.
    func applyClear(on wallpaper: RGBA) {
        let readable: RGBA = wallpaper.luminance >= 0.5 ? .black : .white
        layouts = layouts.map { layout in
            var updated = layout
            updated.background.mode = .clear
            if abs(updated.style.color.luminance - wallpaper.luminance) < 0.35 {
                updated.style.color = readable
            }
            return updated
        }
        var newClock = clock
        newClock.clear = true
        if abs(newClock.color.luminance - wallpaper.luminance) < 0.35 {
            newClock.color = readable
        }
        clock = newClock
    }

    /// True when every widget is clear.
    var allClear: Bool {
        clock.clear && layouts.allSatisfy { $0.background.mode == .clear }
    }

    // MARK: Persistence

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, let self else { return }
            self.saveNow()
        }
    }

    func saveNow() {
        store.saveLayouts(layouts)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func refreshMetrics() {
        metrics = store.loadMetrics()
    }

    // MARK: Layouts

    func binding(for id: UUID) -> Binding<LauncherLayout> {
        Binding(
            get: { [weak self] in
                self?.layouts.first(where: { $0.id == id }) ?? LauncherLayout(name: "")
            },
            set: { [weak self] newValue in
                guard let self, let index = self.layouts.firstIndex(where: { $0.id == id }) else { return }
                self.layouts[index] = newValue
            }
        )
    }

    func layout(id: UUID) -> LauncherLayout? {
        layouts.first(where: { $0.id == id })
    }

    @discardableResult
    func addLayout() -> LauncherLayout {
        var layout = LauncherLayout.starter(named: "Widget \(layouts.count + 1)")
        if let first = layouts.first {
            // New layouts start with the look of the first one.
            layout.style = first.style
        }
        layouts.append(layout)
        return layout
    }

    func duplicate(_ layout: LauncherLayout) {
        var copy = layout
        copy.id = UUID()
        copy.name = layout.name + " copy"
        store.copyBackgrounds(from: layout.id, to: copy.id)
        layouts.append(copy)
    }

    func deleteLayouts(at offsets: IndexSet) {
        for index in offsets {
            store.deleteBackgrounds(layoutID: layouts[index].id)
        }
        layouts.remove(atOffsets: offsets)
        if layouts.isEmpty { layouts = [LauncherLayout.starter()] }
    }

    func moveLayouts(from source: IndexSet, to destination: Int) {
        layouts.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: Calibration

    func startCalibration(for layoutID: UUID) {
        settings.calibratingLayoutID = layoutID
    }

    func stopCalibration() {
        if settings.calibratingLayoutID != nil {
            settings.calibratingLayoutID = nil
        }
    }

    var isCalibrating: Bool { settings.calibratingLayoutID != nil }

    // MARK: Launching

    /// Handles `widgetsimple://open?u=…` from a widget tap: forward to the target app right away.
    func handleIncoming(_ url: URL) {
        guard let target = LaunchRouter.target(fromHop: url) else { return }
        isForwarding = true
        UIApplication.shared.open(target, options: [:]) { [weak self] success in
            Task { @MainActor in
                guard let self else { return }
                if !success {
                    self.isForwarding = false
                    self.launchError = "Couldn't open \(target.absoluteString). The app may not be installed, or the link is wrong."
                }
            }
        }
    }

    /// Used by "Test" buttons inside the app.
    func test(_ url: URL?) {
        guard let url else {
            launchError = "This item has no valid link yet."
            return
        }
        UIApplication.shared.open(url, options: [:]) { [weak self] success in
            Task { @MainActor in
                if !success {
                    self?.launchError = "iOS couldn't open \(url.absoluteString). The app is probably not installed or uses a different link."
                }
            }
        }
    }

    /// The schemes iOS actually checks. Apps built with the iOS 27 SDK get only the first
    /// 25 LSApplicationQueriesSchemes entries (50 before). Entry 26 is our own scheme:
    /// it always resolves, so a "no" means the list was cut at 25.
    private lazy var checkableSchemes: Set<String> = {
        let declared = (Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String]) ?? []
        let probe = URL(string: "\(LaunchRouter.scheme)://")
        let limit = probe.map { UIApplication.shared.canOpenURL($0) } == true ? 50 : 25
        return Set(declared.prefix(limit).map { $0.lowercased() })
    }()

    /// nil when iOS doesn't let WidgetSimple check this app.
    func isInstalled(_ app: CatalogApp) -> Bool? {
        guard let url = app.openURL, app.category != .apple else { return nil }
        guard checkableSchemes.contains(app.scheme.lowercased()) else { return nil }
        return UIApplication.shared.canOpenURL(url)
    }
}

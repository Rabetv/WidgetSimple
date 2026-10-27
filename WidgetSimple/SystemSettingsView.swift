import StoreKit
import SwiftUI
import UIKit
import WidgetKit

/// Screen 05: refresh, syncing and permissions as plain rows between one-pixel rules,
/// then the subscription, and the privacy notes in small spaced capitals at the foot.
struct SystemSettingsView: View {
    @ObservedObject var license: LicenseStore
    @EnvironmentObject private var model: AppModel
    @Environment(\.openURL) private var openURL
    @AppStorage("onboarded") private var onboarded = true
    @AppStorage(AppWallpaper.storageKey) private var appWallpaper = AppWallpaper.standard
    @State private var managing = false
    @State private var lastSync: Date?
    @State private var settingUpWallpaper = false
    #if TESTFLIGHT
    @State private var showingDiagnostics = false
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LineArt.breath) {
                ScreenHeader(title: "Settings")
                appearanceSection
                syncSection
                permissionsSection
                subscriptionSection
                aboutSection
                privacyNotes
            }
            .padding(.horizontal, LineArt.margin)
            .padding(.bottom, 40)
        }
        .background(AppBackground())
        #if APPSTORE
        .manageSubscriptionsSheet(isPresented: $managing)
        .sheet(isPresented: $settingUpWallpaper) {
            WallpaperSetupView()
                .preferredColorScheme(.dark)
        }
        #endif
        #if TESTFLIGHT
        .sheet(isPresented: $showingDiagnostics) {
            NavigationStack { DiagnosticsView() }
        }
        #endif
    }

    // MARK: Sections

    private var appearanceSection: some View {
        SettingsSection(code: "S-00", title: "Appearance") {
            SettingRow(title: "App Wallpaper",
                       detail: model.seeThrough.hasWallpaper || model.seeThrough.hasDarkWallpaper
                           ? "What WidgetSimple shows behind its own screens."
                           : "Add your wallpaper screenshots to use your Home Screen here.") {
                Picker("App Wallpaper", selection: $appWallpaper) {
                    ForEach(AppWallpaper.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
    }

    private var syncSection: some View {
        SettingsSection(code: "S-01", title: "Refresh & sync") {
            #if APPSTORE
            Button { settingUpWallpaper = true } label: {
                SettingRow(title: "Wallpaper", detail: wallpaperDetail) {
                    HStack(spacing: 10) {
                        Stamp(wallpaperStatus, emphasized: model.isWallpaperReady)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .regular))
                            .frame(width: 34, height: 34)
                            .lineBorder(radius: LineArt.keyRadius)
                    }
                }
            }
            .buttonStyle(.plain)
            #endif
            SettingRow(title: "Background Refresh Time",
                       detail: model.clock == .off
                           ? "Without a clock the widget redraws only when you change something here."
                           : "With a clock, the widget queues one redraw a minute; iOS sets the final budget.") {
                Stamp(model.clock == .off ? "On change" : "Every min", emphasized: true)
            }
            SettingRow(title: "Widget Syncing",
                       detail: "Style, clock, designs and see-through pieces reach every widget through the shared App Group.") {
                Stamp(SharedStore.shared.isAppGroupAvailable ? "Linked" : "No group",
                      emphasized: SharedStore.shared.isAppGroupAvailable)
            }
            SettingRow(title: "Sync now",
                       detail: lastSync.map { "Last pushed at \($0.formatted(date: .omitted, time: .standard))." }
                           ?? "Asks iOS to redraw every widget from the current settings.") {
                Button {
                    WidgetCenter.shared.reloadAllTimelines()
                    lastSync = .now
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(BevelKeyStyle(size: 38))
                .accessibilityLabel("Sync widgets now")
            }
        }
        .sensoryFeedback(.success, trigger: lastSync)
    }

    private var permissionsSection: some View {
        SettingsSection(code: "S-02", title: "Permissions") {
            SettingRow(title: "System Health Permissions",
                       detail: "Health modules draw a sample line. WidgetSimple never asks for or reads Health data.") {
                Stamp("None asked")
            }
            SettingRow(title: "Screenshots & Photos",
                       detail: "You pick one image at a time in the system picker; the app never sees the rest of your library.") {
                Stamp("Per pick")
            }
            actionRow("iOS Settings", detail: "Open WidgetSimple's page in the Settings app.", symbol: "arrow.up.right") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        }
    }

    private var subscriptionSection: some View {
        SettingsSection(code: "S-03", title: "Subscription") {
            #if APPSTORE
            actionRow("Manage subscription", symbol: "creditcard") { managing = true }
            actionRow("Restore Purchases", symbol: "arrow.clockwise") {
                Task { await license.restore() }
            }
            .disabled(license.busy)
            #if TESTFLIGHT
            if license.testUnlocked {
                actionRow("Re-lock (test the paywall)", symbol: "lock") { license.relockForTesting() }
            }
            #endif
            // No StoreKit products in a simulator; keep the screenshot clean.
            if let message = license.message,
               !ProcessInfo.processInfo.arguments.contains("-screenshot") {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            }
            actionRow("Terms of Use", symbol: "arrow.up.right") { openURL(StoreConfig.termsURL) }
            actionRow("Support", symbol: "arrow.up.right") { openURL(StoreConfig.supportURL) }
            actionRow("Privacy Policy", symbol: "arrow.up.right") { openURL(StoreConfig.privacyURL) }
            #else
            actionRow("Manage subscription", symbol: "arrow.up.right") { openURL(license.manageSubscription()) }
            actionRow("Sign out on this iPhone", symbol: "rectangle.portrait.and.arrow.right") { license.signOut() }
            #endif
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSection(code: "S-04", title: "About") {
                actionRow("Show the tutorial again", symbol: "play.rectangle") { onboarded = false }
                #if TESTFLIGHT
                actionRow("Widget diagnostics", symbol: "stethoscope") { showingDiagnostics = true }
                #endif
                SettingRow(title: "Version") {
                    Text(LineArt.version).font(.metric(15)).monospacedDigit()
                }
            }
            #if APPSTORE
            Text("Widgets keep working when the subscription ends; the subscription unlocks the editor.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            #else
            Text("Widgets stay see-through when the app is locked; the subscription unlocks the editor.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            #endif
        }
    }

    private var privacyNotes: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Stamp("P")
                Micro("Data privacy", tone: .primary)
                Hairline()
            }
            ForEach(Self.notes, id: \.self) { note in
                Text(note.uppercased())
                    .font(.custom("AvenirNext-Medium", size: 7.5, relativeTo: .caption2))
                    .tracking(2.2)
                    .lineSpacing(3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private static var notes: [String] {
        var notes = ["P-01 · No account, no analytics, no ads, no tracking."]
        #if APPSTORE
        notes.append("P-02 · Settings, fonts and screenshots stay on this iPhone, in the app and its App Group.")
        notes.append("P-03 · Wallpaper pieces are cut on this iPhone and never uploaded.")
        notes.append("P-04 · Purchases run through the App Store; no payment details reach us.")
        #else
        notes.append("P-02 · Settings and fonts stay on this iPhone, in the app and its App Group.")
        notes.append("P-04 · The licence key is checked with the store that sold it.")
        #endif
        notes.append("P-05 · Deleting the app removes everything it stored.")
        return notes
    }

    private var wallpaperStatus: String {
        let state = model.seeThrough
        if model.look.background == .photo { return "Photo" }
        if state.finding { return "Matching" }
        if state.isComplete { return "Ready" }
        let done = [state.hasWallpaper, state.hasDarkWallpaper, !state.spots.isEmpty].filter { $0 }.count
        return "\(done) of 3"
    }

    private var wallpaperDetail: String {
        let state = model.seeThrough
        if model.look.background == .photo {
            return "Your widgets show your own photo. Open to change it or go back to see-through."
        }
        if state.isComplete {
            let count = state.spots.count
            return "Light and dark screenshots, \(count) \(count == 1 ? "widget" : "widgets") matched. Redo it after you change the wallpaper or move a widget."
        }
        return "Finish the screenshots so your widgets show the wallpaper behind them in Light and Dark Mode."
    }

    private func actionRow(_ title: String, detail: String? = nil, symbol: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SettingRow(title: title, detail: detail) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .regular))
                    .frame(width: 34, height: 34)
                    .lineBorder(radius: LineArt.keyRadius)
            }
        }
        .buttonStyle(.plain)
    }
}

/// A titled glass panel of rows with an explicit one-pixel rule between every option.
private struct SettingsSection<Content: View>: View {
    let code: String
    let title: String
    let content: Content

    init(code: String, title: String, @ViewBuilder content: () -> Content) {
        self.code = code
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Stamp(code)
                Micro(title, tone: .primary)
            }
            .padding(.bottom, 10)
            .accessibilityAddTraits(.isHeader)
            Hairline(opacity: 0.7)
            ForEach(subviews: content) { row in
                row
                Hairline(opacity: 0.5)
            }
        }
        .padding(LineArt.inset + 2)
        .glassPanel(cornerRadius: LineArt.moduleRadius)
    }
}

private struct SettingRow<Trailing: View>: View {
    let title: String
    var detail: String?
    let trailing: Trailing

    init(title: String, detail: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.detail = detail
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .semibold, design: .rounded))
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

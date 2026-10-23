import StoreKit
import SwiftUI

/// Shown until the subscription is active. Sideloaded builds cannot use App Store
/// purchases, so there the subscription is bought on the web and the receipt key is
/// entered here (or restored on a new device); App Store builds buy it with StoreKit.
struct PaywallView: View {
    @ObservedObject var license: LicenseStore
    @State private var key = ""
    @Environment(\.openURL) private var openURL
    #if APPSTORE
    @Environment(\.purchase) private var purchase
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    header
                    benefits
                    buyButton
                    #if TESTFLIGHT && APPSTORE
                    testFlightUnlock
                    #endif
                    restore
                    footer
                }
                .padding(22)
            }
            .background(AppBackground())
            .navigationBarTitleDisplayMode(.inline)
            #if APPSTORE
            .task { if license.product == nil { await license.loadProduct() } }
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("WidgetSimple").font(.headline)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image("AppIconImage")
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 20, y: 12)
                .accessibilityHidden(true)
            #if APPSTORE
            Text("Your apps as words.")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            if !license.priceLine.isEmpty {
                Text("One subscription, every widget. \(license.priceLine).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            #else
            Text("Your apps as words, see-through.")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text("One subscription, every widget. \(LicenseConfig.priceLine).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            #endif
        }
        .padding(.top, 20)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Up to 12 apps per widget, tap to open", systemImage: "hand.tap")
            #if APPSTORE
            Label("Words over your wallpaper, on the system glass", systemImage: "square.dashed")
            #else
            Label("Truly transparent — no glass, no frames", systemImage: "square.dashed")
            #endif
            Label("Fonts, colours, placement, clock", systemImage: "slider.horizontal.3")
            Label("Updates and new features included", systemImage: "arrow.triangle.2.circlepath")
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassPanel(cornerRadius: 26)
    }

    private var buyButton: some View {
        VStack(spacing: 10) {
            #if APPSTORE
            // App Store builds sell through StoreKit (3.1.1); the external checkout and
            // its "enter your key" flow are only for the AltStore distribution.
            Button {
                Task { await license.purchase(with: purchase) }
            } label: {
                Group {
                    if license.busy {
                        ProgressView()
                    } else if license.product == nil {
                        license.message == nil ? Text("Loading…") : Text("Try Again")
                    } else if license.trialLine != nil {
                        Text("Start Free Trial")
                    } else {
                        Text("Subscribe — \(license.priceLine)")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(license.busy || (license.product == nil && license.message == nil))

            // 3.1.2: title, length and price of the subscription, how it renews, and what
            // the trial turns into. The amount billed stays the most prominent price.
            if let trialLine = license.trialLine {
                Text("\(trialLine), then \(license.priceLine)")
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("WidgetSimple Pro, 1 year. When the free trial ends, the price above is charged to your Apple Account and the subscription renews each year until cancelled. Cancel any time in Settings › Apple Account › Subscriptions, at least 24 hours before the trial or the current year ends.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("WidgetSimple Pro, 1 year. Renews automatically each year until cancelled. Cancel any time in Settings › Apple Account › Subscriptions, at least 24 hours before the renewal date.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let message = license.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            #else
            Button {
                openURL(LicenseConfig.checkoutURL)
            } label: {
                Text("Subscribe — \(LicenseConfig.priceLine)")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)

            Text("After paying you get a licence key by email. Enter it below.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            #endif
        }
    }

    #if TESTFLIGHT && APPSTORE
    /// TestFlight only: the subscription cannot be bought before App Review approves
    /// it, so testers need a way in. Deliberately visible, and compiled out of the
    /// build submitted to review.
    private var testFlightUnlock: some View {
        VStack(spacing: 8) {
            Button("Unlock without purchase") {
                license.unlockForTesting()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            Text("TestFlight test build. This button is not in the App Store version.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassPanel(cornerRadius: 22)
    }
    #endif

    #if APPSTORE
    private var restore: some View {
        HStack(spacing: 20) {
            Button("Restore Purchases") {
                Task { await license.restore() }
            }
            .disabled(license.busy)
            Link("Terms of Use", destination: StoreConfig.termsURL)
            Link("Privacy Policy", destination: StoreConfig.privacyURL)
        }
        .font(.footnote)
    }
    #else
    private var restore: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Already subscribed?")
                .font(.subheadline.weight(.semibold))
            HStack {
                TextField("Licence key", text: $key)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                Button("Activate") {
                    Task { await license.activate(key: key) }
                }
                .buttonStyle(.bordered)
                .disabled(license.busy || key.isEmpty)
            }
            if let message = license.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            Button("Manage subscription") {
                openURL(license.manageSubscription())
            }
            .font(.footnote)
        }
        .padding(18)
        .glassPanel(cornerRadius: 26)
    }
    #endif

    private var footer: some View {
        VStack(spacing: 6) {
            #if !APPSTORE
            Text("The licence is checked online and works offline for a week.")
            #endif
            Text("Widgets keep working even if the app is locked.")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
}

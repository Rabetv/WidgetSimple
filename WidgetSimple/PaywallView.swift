import StoreKit
import SwiftUI

#if APPSTORE

/// Shown until the subscription is active: Apple's own subscription screen for
/// WidgetSimple Pro. StoreKit draws the price, the trial, the renewal terms and the
/// purchase sheet, so the wording always matches App Store Connect.
struct PaywallView: View {
    @ObservedObject var license: LicenseStore

    var body: some View {
        SubscriptionStoreView(productIDs: [StoreConfig.productID]) {
            marketing
        }
        .storeButton(.visible, for: .restorePurchases)
        .subscriptionStorePolicyDestination(url: StoreConfig.termsURL, for: .termsOfService)
        .subscriptionStorePolicyDestination(url: StoreConfig.privacyURL, for: .privacyPolicy)
        .subscriptionStoreControlStyle(.prominentPicker)
        .containerBackground(for: .subscriptionStore) { AppBackground() }
        // Purchases, restores and Ask to Buy approvals all end in the entitlement check.
        .onInAppPurchaseCompletion { _, _ in await license.refresh() }
        .task { await license.refresh() }
    }

    private var marketing: some View {
        VStack(spacing: 18) {
            Image("AppIconImage")
                .resizable()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
                .accessibilityHidden(true)
            Text("Your apps as words.")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 12) {
                Label("Up to 12 apps per widget, tap to open", systemImage: "hand.tap")
                Label("Matched to your wallpaper", systemImage: "photo.on.rectangle")
                Label("Fonts, colours, placement, clock", systemImage: "slider.horizontal.3")
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassPanel(cornerRadius: 24)
            #if TESTFLIGHT
            testFlightUnlock
            #endif
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
    }

    #if TESTFLIGHT
    /// TestFlight only: the subscription cannot be bought before App Review approves
    /// it, so testers need a way in. Deliberately visible, and compiled out of the
    /// build submitted to review.
    private var testFlightUnlock: some View {
        VStack(spacing: 6) {
            Button("Unlock without purchase") {
                license.unlockForTesting()
            }
            .buttonStyle(.bordered)
            Text("TestFlight test build. This button is not in the App Store version.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    #endif
}

#else

/// Shown until the subscription is active. Sideloaded builds cannot use App Store
/// purchases, so the subscription is bought on the web and the receipt key is entered
/// here (or restored on a new device).
struct PaywallView: View {
    @ObservedObject var license: LicenseStore
    @State private var key = ""
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    header
                    benefits
                    buyButton
                    restore
                    footer
                }
                .padding(22)
            }
            .background(AppBackground())
            .navigationBarTitleDisplayMode(.inline)
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
            Text("Your apps as words.")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text("One subscription, every widget. \(LicenseConfig.priceLine).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Up to 12 apps per widget, tap to open", systemImage: "hand.tap")
            Label("Matched to your wallpaper", systemImage: "photo.on.rectangle")
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
        }
    }

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

    private var footer: some View {
        VStack(spacing: 6) {
            Text("The licence is checked online and works offline for a week.")
            Text("Widgets keep working even if the app is locked.")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
}

#endif

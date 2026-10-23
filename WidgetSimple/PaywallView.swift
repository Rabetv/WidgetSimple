import SwiftUI

/// Shown until a licence key is validated. Sideloaded builds cannot use App Store
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
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
            Image(systemName: "textformat")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tint)
            Text("Your apps as words, see-through.")
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
            Label("Truly transparent — no glass, no frames", systemImage: "square.dashed")
            Label("Fonts, colours, placement, clock", systemImage: "slider.horizontal.3")
            Label("Updates and new features included", systemImage: "arrow.triangle.2.circlepath")
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var buyButton: some View {
        VStack(spacing: 10) {
            #if APPSTORE
            // App Store builds must sell through StoreKit (3.1.1); the external checkout
            // and its "enter your key" flow are only for the AltStore distribution.
            Text("Purchases are handled by the App Store.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            #else
            Button {
                openURL(LicenseConfig.checkoutURL)
            } label: {
                Text("Subscribe — \(LicenseConfig.priceLine)")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("After paying you get a licence key by email. Enter it below.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            #endif
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
            #if !APPSTORE
            Button("Manage subscription") {
                openURL(license.manageSubscription())
            }
            .font(.footnote)
            #endif
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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

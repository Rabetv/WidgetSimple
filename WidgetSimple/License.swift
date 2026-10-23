import Foundation
import Security
import StoreKit
import SwiftUI
import UIKit

#if !APPSTORE
// AltStore build: sold on the web, unlocked with a licence key. App Store builds use
// the StoreKit store below instead (guideline 3.1.1), so none of this ships there.

/// Where the licence is bought. Fill these in once the store exists; everything else
/// in the app already works with them.
enum LicenseConfig {
    /// The checkout link for the €1/year licence (Lemon Squeezy, Paddle, Gumroad…).
    static let checkoutURL = URL(string: "https://YOURSTORE.lemonsqueezy.com/buy/000000")!
    /// Where a licence can be managed or cancelled.
    static let manageURL = URL(string: "https://YOURSTORE.lemonsqueezy.com/billing")!
    /// Optional Lemon Squeezy product id; 0 accepts a key from any product.
    static let productID = 0
    /// Shown on the paywall.
    static let priceLine = "€1 per year"
}

/// Validates the licence key against the store's licence API and keeps it in the
/// Keychain. The check runs online; a validated key is trusted for a week offline.
@MainActor
final class LicenseStore: ObservableObject {
    enum Status: Equatable { case checking, unlicensed, licensed }

    @Published private(set) var status: Status = .checking
    @Published private(set) var message: String?
    @Published private(set) var busy = false

    private let keychain = Keychain()
    private let session = URLSession(configuration: .ephemeral)

    private static let keyItem = "license.key"
    private static let instanceItem = "license.instance"
    private static let lastCheckItem = "license.lastCheck"
    /// How long a validated key is accepted without reaching the store.
    private static let offlineGrace: TimeInterval = 7 * 24 * 3600

    init() {}

    /// Called on launch and when the app comes back to the foreground.
    func refresh() async {
        guard let key = keychain.string(for: Self.keyItem) else {
            status = .unlicensed
            return
        }
        if let last = keychain.string(for: Self.lastCheckItem).flatMap(Double.init),
           Date().timeIntervalSince1970 - last < Self.offlineGrace {
            status = .licensed
            return
        }
        busy = true
        defer { busy = false }
        if await validate(key: key) {
            keychain.set("\(Date().timeIntervalSince1970)", for: Self.lastCheckItem)
            status = .licensed
        } else {
            message = "The licence could not be checked. Connect to the internet and try again."
            status = .unlicensed
        }
    }

    /// Enters a key the person received after paying.
    func activate(key rawKey: String) async {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            message = "Enter the licence key from your receipt."
            return
        }
        busy = true
        defer { busy = false }
        message = nil
        guard let response = await post("activate", fields: ["license_key": key,
                                                             "instance_name": deviceName]) else {
            message = "Could not reach the licence server."
            return
        }
        let activated = (response["activated"] as? Bool) ?? false
        guard activated else {
            message = (response["error"] as? String) ?? "That key was not accepted."
            return
        }
        keychain.set(key, for: Self.keyItem)
        if let instance = (response["instance"] as? [String: Any])?["id"] as? String {
            keychain.set(instance, for: Self.instanceItem)
        }
        keychain.set("\(Date().timeIntervalSince1970)", for: Self.lastCheckItem)
        status = .licensed
    }

    /// Forgets the key on this device (the subscription itself keeps running).
    func signOut() {
        keychain.remove(Self.keyItem)
        keychain.remove(Self.instanceItem)
        keychain.remove(Self.lastCheckItem)
        status = .unlicensed
    }

    func manageSubscription() -> URL { LicenseConfig.manageURL }

    // MARK: Store

    private func validate(key: String) async -> Bool {
        var fields = ["license_key": key]
        if let instance = keychain.string(for: Self.instanceItem) {
            fields["instance_id"] = instance
        }
        guard let response = await post("validate", fields: fields) else { return false }
        if let valid = response["valid"] as? Bool, valid { return true }
        // A key that is valid but has no instance on this device: activate it.
        return false
    }

    private func post(_ endpoint: String, fields: [String: String]) async -> [String: Any]? {
        guard let url = URL(string: "https://api.lemonsqueezy.com/v1/licenses/\(endpoint)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = fields
            .map { "\($0.key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        guard let (data, _) = try? await session.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json
    }

    private var deviceName: String {
        UIDevice.current.name.isEmpty ? "iPhone" : UIDevice.current.name
    }
}

#else

/// The App Store subscription. The product is created in App Store Connect as an
/// auto-renewable subscription; its price comes from the store, never from here.
enum StoreConfig {
    static let productID = "com.rabetv.widgetsimple.pro.yearly"
    /// Required on the paywall for auto-renewable subscriptions (3.1.2).
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// Hosted from the public Rabetv/widgetsimple-site repository (GitHub Pages).
    static let privacyURL = URL(string: "https://rabetv.github.io/widgetsimple-site/privacy.html")!
    static let supportURL = URL(string: "https://rabetv.github.io/widgetsimple-site/")!
}

/// Unlocks the editor while the yearly subscription is active. StoreKit 2 keeps the
/// signed transactions on the device, so the check also works offline.
@MainActor
final class LicenseStore: ObservableObject {
    enum Status: Equatable { case checking, unlicensed, licensed }

    @Published private(set) var status: Status = .checking
    @Published private(set) var message: String?
    @Published private(set) var busy = false
    @Published private(set) var product: Product?
    /// The free trial set up in App Store Connect, when this Apple Account can still
    /// get it (one introductory offer per subscription group and person).
    @Published private(set) var trial: Product.SubscriptionOffer?

    private var updates: Task<Void, Never>?

    init() {
        // Renewals, refunds, Ask to Buy approvals and purchases made on another device
        // arrive here while the app runs.
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self.refreshEntitlement()
            }
        }
    }

    /// "€1 per year", in the person's storefront currency once the product has loaded.
    var priceLine: String {
        guard let product else { return "" }
        return String(localized: "\(product.displayPrice) per year")
    }

    /// "3 months free", or nil when there is no trial for this person.
    var trialLine: String? {
        guard let trial else { return nil }
        let count = trial.period.value * trial.periodCount
        switch trial.period.unit {
        case .day: return count == 1 ? String(localized: "1 day free") : String(localized: "\(count) days free")
        case .week: return count == 1 ? String(localized: "1 week free") : String(localized: "\(count) weeks free")
        case .month: return count == 1 ? String(localized: "1 month free") : String(localized: "\(count) months free")
        case .year: return count == 1 ? String(localized: "1 year free") : String(localized: "\(count) years free")
        @unknown default: return String(localized: "Free trial")
        }
    }

    /// Called on launch and when the app comes back to the foreground.
    func refresh() async {
        await refreshEntitlement()
        if product == nil { await loadProduct() }
    }

    func loadProduct() async {
        message = nil
        do {
            product = try await Product.products(for: [StoreConfig.productID]).first
            if product == nil { message = String(localized: "The subscription is not available right now.") }
            if let subscription = product?.subscription,
               let offer = subscription.introductoryOffer, offer.paymentMode == .freeTrial,
               await subscription.isEligibleForIntroOffer {
                trial = offer
            } else {
                trial = nil
            }
        } catch {
            message = String(localized: "Could not reach the App Store. Check your connection and try again.")
        }
    }

    /// Buys the subscription through the system sheet (`@Environment(\.purchase)`).
    func purchase(with purchase: PurchaseAction) async {
        guard let product else {
            await loadProduct()
            return
        }
        busy = true
        defer { busy = false }
        message = nil
        do {
            switch try await purchase(product) {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshEntitlement()
            case .success(.unverified):
                message = String(localized: "The App Store could not verify this purchase.")
            case .pending:
                message = String(localized: "The purchase is waiting for approval.")
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = String(localized: "The purchase did not go through. Try again.")
        }
    }

    /// Restore Purchases: syncs with the App Store, which may ask the person to sign in.
    func restore() async {
        busy = true
        defer { busy = false }
        message = nil
        do {
            try await AppStore.sync()
        } catch {
            message = String(localized: "Could not reach the App Store. Check your connection and try again.")
            return
        }
        await refreshEntitlement()
        if status != .licensed {
            message = String(localized: "No active subscription was found for this Apple Account.")
        }
    }

    /// Fallback for the manage link; the app shows `manageSubscriptionsSheet` instead.
    func manageSubscription() -> URL { URL(string: "https://apps.apple.com/account/subscriptions")! }

    private func refreshEntitlement() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == StoreConfig.productID,
                  transaction.revocationDate == nil else { continue }
            if let expiry = transaction.expirationDate, expiry < Date() { continue }
            active = true
        }
        status = active ? .licensed : .unlicensed
    }
}

#endif

/// The few Keychain calls this app needs.
final class Keychain {
    private let service = "com.rabetv.widgetsimple.license"

    func set(_ value: String, for account: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func string(for account: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func remove(_ account: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
    }
}

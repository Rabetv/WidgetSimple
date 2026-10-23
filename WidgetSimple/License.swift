import Foundation
import Security
import UIKit

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

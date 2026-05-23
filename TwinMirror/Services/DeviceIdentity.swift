import Foundation
import Security

/// Per-install device identifier persisted in the Keychain so it survives app
/// updates. Used as `X-Device-Id` for the history endpoints. We deliberately
/// scope this to the device (not the iCloud account) for v1; account-level
/// sync is a future feature.
final class DeviceIdentity: @unchecked Sendable {
    static let shared = DeviceIdentity()

    private let service = "app.twinmirror.ios"
    private let account = "device-id"
    private let lock = NSLock()
    private var cached: String?

    private init() {}

    var deviceID: String {
        lock.lock(); defer { lock.unlock() }
        if let cached { return cached }
        if let existing = readFromKeychain() {
            cached = existing
            return existing
        }
        let fresh = UUID().uuidString.lowercased()
        writeToKeychain(fresh)
        cached = fresh
        return fresh
    }

    // MARK: - Keychain

    private func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = withUnsafeMutablePointer(to: &item) { SecItemCopyMatching(query as CFDictionary, $0) }
        guard status == errSecSuccess, let data = item as? Data, let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }

    private func writeToKeychain(_ value: String) {
        let data = Data(value.utf8)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemDelete(attributes as CFDictionary)
        SecItemAdd(attributes as CFDictionary, nil)
    }
}

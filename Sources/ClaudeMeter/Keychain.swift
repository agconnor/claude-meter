import Foundation
import Security
import ClaudeMeterCore

/// Reads and writes the OAuth credential blob that Claude Code stores in the login
/// keychain under the generic-password service "Claude Code-credentials".
enum Keychain {
    static let service = "Claude Code-credentials"

    static func readRaw() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func readCredentials() -> Credentials? {
        readRaw().flatMap(UsageParser.parseCredentials)
    }

    /// Rewrites only the token fields, preserving the rest of the blob so the item
    /// stays compatible with Claude Code itself.
    @discardableResult
    static func updateTokens(accessToken: String, refreshToken: String, expiresAt: Double) -> Bool {
        guard let raw = readRaw(),
              let updated = UsageParser.updatedCredentialBlob(
                raw, accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt),
              let data = updated.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        let attrs: [String: Any] = [kSecValueData as String: data]
        return SecItemUpdate(query as CFDictionary, attrs as CFDictionary) == errSecSuccess
    }
}

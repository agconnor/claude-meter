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
}

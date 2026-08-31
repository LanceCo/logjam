import Foundation
import Security

final class KeychainStore: @unchecked Sendable {
    static let shared = KeychainStore()

    private let service = "com.lanceconzett.Logjam"
    private let tokenAccount = "discogsPersonalAccessToken"
    private let usernameAccount = "discogsUsername"

    private init() {}

    func saveDiscogsToken(_ token: String) throws {
        try save(token, account: tokenAccount)
    }

    func readDiscogsToken() throws -> String? {
        try read(account: tokenAccount)
    }

    func saveDiscogsUsername(_ username: String) throws {
        try save(username, account: usernameAccount)
    }

    func readDiscogsUsername() throws -> String? {
        try read(account: usernameAccount)
    }

    private func save(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandled(status: status) }
    }

    private func read(account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.unhandled(status: status)
        }
        return String(data: data, encoding: .utf8)
    }
}

enum KeychainError: Error {
    case unhandled(status: OSStatus)
}

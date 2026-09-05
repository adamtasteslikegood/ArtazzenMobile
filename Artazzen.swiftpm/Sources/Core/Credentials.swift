import Foundation

#if canImport(Security)
    import Security
#endif

package struct Connection: Equatable, Sendable {
    package let baseURL: URL
    package let username: String
    package let password: String

    package init(server: String, username: String, password: String) throws {
        guard
            var parts = URLComponents(
                string: server.trimmingCharacters(in: .whitespacesAndNewlines)),
            let host = parts.host, !host.isEmpty,
            parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
            parts.scheme == "https"
                || (parts.scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host)),
            !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw CredentialError.invalidConnection }
        parts.host = host.lowercased()
        if parts.scheme == "https" && parts.port == 443 { parts.port = nil }
        while parts.path.hasSuffix("/") { parts.path.removeLast() }
        guard let url = parts.url else { throw CredentialError.invalidConnection }
        baseURL = url
        self.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        self.password = password
    }

    package var credentialKey: String { baseURL.absoluteString + "|" + username }
}

package protocol CredentialStore {
    func read(key: String) throws -> String?
    func write(_ password: String, key: String) throws
}

package enum CredentialError: LocalizedError {
    case invalidConnection, storageFailed
    package var errorDescription: String? {
        switch self {
        case .invalidConnection:
            return "Enter a valid HTTPS Server URL, admin username, and password in Settings."
        case .storageFailed:
            return "Could not access Keychain. Unlock the device and try again."
        }
    }
}

package struct KeychainCredentialStore: CredentialStore {
    package init() {}
    #if canImport(Security)
        private func query(_ key: String) -> [String: Any] {
            [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "com.artazzen.mobile.admin",
                kSecAttrAccount as String: key,
            ]
        }

        package func read(key: String) throws -> String? {
            var attributes = query(key)
            attributes[kSecReturnData as String] = true
            attributes[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: CFTypeRef?
            let status = SecItemCopyMatching(attributes as CFDictionary, &result)
            if status == errSecItemNotFound { return nil }
            guard status == errSecSuccess, let data = result as? Data,
                let password = String(data: data, encoding: .utf8)
            else { throw CredentialError.storageFailed }
            return password
        }

        package func write(_ password: String, key: String) throws {
            let attributes = query(key)
            let values: [String: Any] = [kSecValueData as String: Data(password.utf8)]
            let status = SecItemUpdate(attributes as CFDictionary, values as CFDictionary)
            if status == errSecSuccess { return }
            guard status == errSecItemNotFound else { throw CredentialError.storageFailed }
            var item = attributes.merging(values) { _, new in new }
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
                throw CredentialError.storageFailed
            }
        }
    #else
        package func read(key: String) throws -> String? { throw CredentialError.storageFailed }
        package func write(_ password: String, key: String) throws {
            throw CredentialError.storageFailed
        }
    #endif
}

import Foundation
import Security

public enum KeychainCredentialError: LocalizedError {
    case operationFailed(Int32)
    case invalidCredentialEncoding

    public var errorDescription: String? {
        switch self {
        case .operationFailed(let status):
            return "Could not access the macOS Keychain (status \(status))."
        case .invalidCredentialEncoding:
            return "The saved API key is not valid UTF-8."
        }
    }
}

public struct KeychainCredentialStore {
    private let service = "ColdTwin.ExternalModelCredential"

    public init() {}

    public func save(_ credential: String, for identifier: String) throws {
        guard let data = credential.data(using: .utf8) else {
            throw KeychainCredentialError.invalidCredentialEncoding
        }
        let query = itemQuery(for: identifier)
        let attributes = [kSecValueData as String: data] as CFDictionary
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let status = SecItemAdd(addQuery as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw KeychainCredentialError.operationFailed(status)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainCredentialError.operationFailed(updateStatus)
        }
    }

    public func load(for identifier: String) throws -> String? {
        var query = itemQuery(for: identifier)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainCredentialError.operationFailed(status)
        }
        guard let data = result as? Data,
              let credential = String(data: data, encoding: .utf8) else {
            throw KeychainCredentialError.invalidCredentialEncoding
        }
        return credential
    }

    public func delete(for identifier: String) throws {
        let status = SecItemDelete(itemQuery(for: identifier) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainCredentialError.operationFailed(status)
        }
    }

    private func itemQuery(for identifier: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: identifier
        ]
    }
}

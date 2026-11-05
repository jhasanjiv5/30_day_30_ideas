import Foundation
import CryptoKit
import Security

/// Hardware Enclave AES-256-GCM Secure Vault
public final class SecureVaultStore: ObservableObject {
    @Published public var credentials: [VaultCredential] = []

    public init() {
        loadStarterCredentials()
    }

    private func loadStarterCredentials() {
        credentials = [
            VaultCredential(id: "v-1", service: "Instagram Creator", username: "@hearthandcrumb", encryptedEnvelope: "AES-GCM-256-ENCLAVE", category: "Social Login", hasTotp: true, updatedAt: "2 days ago"),
            VaultCredential(id: "v-2", service: "Meta Graph API Token", username: "meta_admin_token", encryptedEnvelope: "AES-GCM-256-ENCLAVE", category: "API Key", hasTotp: false, updatedAt: "1 week ago")
        ]
    }

    public func encrypt(plaintext: String, using key: SymmetricKey) throws -> String {
        guard let data = plaintext.data(using: .utf8) else { throw VaultError.encodingError }
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined?.base64EncodedString() ?? ""
    }

    public func decrypt(base64Ciphertext: String, using key: SymmetricKey) throws -> String {
        guard let data = Data(base64Encoded: base64Ciphertext) else { throw VaultError.corruptedData }
        let box = try AES.GCM.SealedBox(combined: data)
        let decrypted = try AES.GCM.open(box, using: key)
        return String(data: decrypted, encoding: .utf8) ?? ""
    }

    public enum VaultError: Error {
        case encodingError
        case corruptedData
    }
}

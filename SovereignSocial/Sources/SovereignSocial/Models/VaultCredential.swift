import Foundation

public struct VaultCredential: Codable, Identifiable {
    public var id: String
    public var service: String
    public var username: String
    public var encryptedEnvelope: String
    public var category: String
    public var hasTotp: Bool
    public var updatedAt: String
}

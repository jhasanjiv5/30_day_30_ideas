import Foundation

public struct PrivacyReceipt: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let sessionStartedAt: Date
    public let sessionEndedAt: Date
    public let locationDurationSeconds: TimeInterval
    public let coordinatesStoredCount: Int
    public let personalItemsReferencedCount: Int
    public let anonymousTileLookupsCount: Int
    public let queriedTileIDs: [String]

    public init(
        id: UUID = UUID(),
        sessionStartedAt: Date,
        sessionEndedAt: Date,
        locationDurationSeconds: TimeInterval,
        coordinatesStoredCount: Int = 0,
        personalItemsReferencedCount: Int,
        anonymousTileLookupsCount: Int,
        queriedTileIDs: [String]
    ) {
        self.id = id
        self.sessionStartedAt = sessionStartedAt
        self.sessionEndedAt = sessionEndedAt
        self.locationDurationSeconds = locationDurationSeconds
        self.coordinatesStoredCount = coordinatesStoredCount
        self.personalItemsReferencedCount = personalItemsReferencedCount
        self.anonymousTileLookupsCount = anonymousTileLookupsCount
        self.queriedTileIDs = queriedTileIDs
    }
}

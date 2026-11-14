import Foundation

public struct ColdTwinInventorySnapshot: Codable, Sendable {
    public var sites: [Site]
    public var assets: [Asset]
    public var readings: [TemperatureReading]
    public var events: [RecordedEvent]
    public var resourceContext: ResourceContext
    public var selectedAssetID: String?

    public init(
        sites: [Site],
        assets: [Asset],
        readings: [TemperatureReading],
        events: [RecordedEvent],
        resourceContext: ResourceContext,
        selectedAssetID: String?
    ) {
        self.sites = sites
        self.assets = assets
        self.readings = readings
        self.events = events
        self.resourceContext = resourceContext
        self.selectedAssetID = selectedAssetID
    }
}

public struct LocalColdTwinInventoryStore {
    private let defaults: UserDefaults
    private let storageKey: String

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = "ColdTwin.localInventory"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    public func load() throws -> ColdTwinInventorySnapshot? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try JSONDecoder().decode(ColdTwinInventorySnapshot.self, from: data)
    }

    public func save(_ snapshot: ColdTwinInventorySnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        defaults.set(data, forKey: storageKey)
    }
}

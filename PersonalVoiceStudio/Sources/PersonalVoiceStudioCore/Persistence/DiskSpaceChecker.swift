import Foundation

public protocol DiskSpaceChecking: Sendable {
    func availableBytes(at url: URL) throws -> Int64
    func ensureSufficientSpace(at url: URL, requiredBytes: Int64) throws
}

public struct DiskSpaceChecker: DiskSpaceChecking, Sendable {
    public typealias CapacityProvider = @Sendable (URL) throws -> Int64

    private let capacityProvider: CapacityProvider

    public init(capacityProvider: CapacityProvider? = nil) {
        if let capacityProvider {
            self.capacityProvider = capacityProvider
        } else {
            self.capacityProvider = { url in
                let probeURL = FileManager.default.fileExists(atPath: url.path)
                    ? url
                    : url.deletingLastPathComponent()
                let values = try probeURL.resourceValues(forKeys: [
                    .volumeAvailableCapacityForImportantUsageKey,
                    .volumeAvailableCapacityKey
                ])
                if let important = values.volumeAvailableCapacityForImportantUsage {
                    return important
                }
                if let basic = values.volumeAvailableCapacity {
                    return Int64(basic)
                }
                throw StudioError.persistenceFailed(reason: "Unable to query free disk space.")
            }
        }
    }

    public func availableBytes(at url: URL) throws -> Int64 {
        try capacityProvider(url)
    }

    public func ensureSufficientSpace(at url: URL, requiredBytes: Int64) throws {
        let available = try availableBytes(at: url)
        if available < requiredBytes {
            let requiredMB = max(1, Int((requiredBytes + 1_048_575) / 1_048_576))
            let availableMB = max(0, Int(available / 1_048_576))
            throw StudioError.insufficientDiskSpace(requiredMB: requiredMB, availableMB: availableMB)
        }
    }
}

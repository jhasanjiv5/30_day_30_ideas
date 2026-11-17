import Foundation

public protocol DiskSpaceChecking: Sendable {
    func availableBytes(at directoryURL: URL) throws -> Int64
    func ensureSufficientSpace(at directoryURL: URL, requiredBytes: Int64) throws
}

public struct DiskSpaceChecker: DiskSpaceChecking {
    private let availableBytesProvider: @Sendable (URL) throws -> Int64

    public init() {
        self.availableBytesProvider = { url in
            let fileManager = FileManager.default
            var probe = url
            while !fileManager.fileExists(atPath: probe.path) && probe.pathComponents.count > 1 {
                probe = probe.deletingLastPathComponent()
            }
            let values = try probe.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
            if let important = values.volumeAvailableCapacityForImportantUsage {
                return important
            }
            if let standard = values.volumeAvailableCapacity {
                return Int64(standard)
            }
            throw VideoStudioError.storageFailure(reason: "Unable to query available disk space.")
        }
    }

    public init(availableBytesProvider: @escaping @Sendable (URL) throws -> Int64) {
        self.availableBytesProvider = availableBytesProvider
    }

    public func availableBytes(at directoryURL: URL) throws -> Int64 {
        try availableBytesProvider(directoryURL)
    }

    public func ensureSufficientSpace(at directoryURL: URL, requiredBytes: Int64) throws {
        let free = try availableBytes(at: directoryURL)
        if free < requiredBytes {
            let requiredMB = max(1, requiredBytes / (1024 * 1024))
            let availableMB = max(0, free / (1024 * 1024))
            throw VideoStudioError.insufficientDiskSpace(requiredMB: requiredMB, availableMB: availableMB)
        }
    }
}

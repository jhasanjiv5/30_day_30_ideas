import Foundation
import CloudKit
import SaathiCore

@MainActor
final class EpisodeStorageService {
    private let localDirectoryName = "SaathiEpisodes"

    private var localEpisodesURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(localDirectoryName, isDirectory: true)
    }

    func saveLocally(_ episode: MemoryEpisode) throws -> URL {
        let safeEpisode = enforceZeroCoordinates(episode)
        try FileManager.default.createDirectory(at: localEpisodesURL, withIntermediateDirectories: true)
        let fileURL = localEpisodesURL.appendingPathComponent("\(safeEpisode.id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(safeEpisode)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    enum StorageError: LocalizedError {
        case iCloudNotConfigured
        var errorDescription: String? {
            "iCloud isn't set up in this build. Add the iCloud capability in Xcode, or keep the episode on this iPhone."
        }
    }

    /// Container from Info.plist `SaathiICloudContainer`. CloudKit raises an exception (a crash,
    /// not a thrown error) if the app uses a container it isn't entitled to, so without the key
    /// we refuse instead of touching CloudKit.
    private var iCloudContainerIdentifier: String? {
        Bundle.main.object(forInfoDictionaryKey: "SaathiICloudContainer") as? String
    }

    func saveToICloud(_ episode: MemoryEpisode) async throws {
        guard let containerID = iCloudContainerIdentifier, !containerID.isEmpty else {
            throw StorageError.iCloudNotConfigured
        }
        let safeEpisode = enforceZeroCoordinates(episode)
        let container = CKContainer(identifier: containerID)
        let database = container.privateCloudDatabase
        let record = CKRecord(recordType: "MemoryEpisode")
        record["title"] = safeEpisode.title as CKRecordValue
        record["createdAt"] = safeEpisode.createdAt as CKRecordValue
        record["languageCode"] = safeEpisode.languageCode as CKRecordValue
        record["script"] = safeEpisode.script as CKRecordValue
        record["photoLocalIdentifiers"] = safeEpisode.linkedPhotoLocalIdentifiers as CKRecordValue
        _ = try await database.save(record)
    }

    private func enforceZeroCoordinates(_ episode: MemoryEpisode) -> MemoryEpisode {
        MemoryEpisode(
            id: episode.id,
            title: episode.title,
            createdAt: episode.createdAt,
            languageCode: episode.languageCode,
            secondaryLanguageCode: episode.secondaryLanguageCode,
            script: EpisodeBuilder.sanitizeCoordinates(from: episode.script),
            secondaryScript: episode.secondaryScript.map { EpisodeBuilder.sanitizeCoordinates(from: $0) },
            stops: episode.stops,
            personalMomentDescriptions: episode.personalMomentDescriptions.map { EpisodeBuilder.sanitizeCoordinates(from: $0) },
            linkedPhotoLocalIdentifiers: episode.linkedPhotoLocalIdentifiers,
            closingReflection: EpisodeBuilder.sanitizeCoordinates(from: episode.closingReflection),
            estimatedDurationSeconds: episode.estimatedDurationSeconds,
            walkSummary: episode.walkSummary // previously dropped on save
        )
    }
}

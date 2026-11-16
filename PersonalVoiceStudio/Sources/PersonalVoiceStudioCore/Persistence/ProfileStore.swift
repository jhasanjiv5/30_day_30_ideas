import Foundation
import os

public struct StorageUsageSummary: Equatable, Sendable {
    public let totalBytes: Int64
    public let recordingsBytes: Int64
    public let correctionsBytes: Int64
    public let generatedBytes: Int64
    public let modelBytes: Int64

    public init(
        totalBytes: Int64,
        recordingsBytes: Int64,
        correctionsBytes: Int64,
        generatedBytes: Int64,
        modelBytes: Int64
    ) {
        self.totalBytes = totalBytes
        self.recordingsBytes = recordingsBytes
        self.correctionsBytes = correctionsBytes
        self.generatedBytes = generatedBytes
        self.modelBytes = modelBytes
    }
}

public final class ProfileStore: @unchecked Sendable {
    public let paths: LocalStoragePaths
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: "com.local.PersonalVoiceStudio", category: "Persistence")

    public init(paths: LocalStoragePaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func loadProfile() throws -> VoiceProfile? {
        guard fileManager.fileExists(atPath: paths.profileFileURL.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: paths.profileFileURL)
            let profile = try decoder.decode(VoiceProfile.self, from: data)
            logger.debug("Loaded local voice profile record.")
            return profile
        } catch {
            logger.error("Failed to decode local profile file.")
            throw StudioError.persistenceFailed(reason: error.localizedDescription)
        }
    }

    public func saveProfile(_ profile: VoiceProfile) throws {
        do {
            try paths.ensureDirectoriesExist(fileManager: fileManager)
            var updated = profile
            updated.updatedAt = Date()
            let data = try encoder.encode(updated)
            try data.write(to: paths.profileFileURL, options: [.atomic])
            logger.debug("Saved local voice profile record.")
        } catch let studioError as StudioError {
            throw studioError
        } catch {
            logger.error("Failed to persist local voice profile.")
            throw StudioError.persistenceFailed(reason: error.localizedDescription)
        }
    }

    public func deletePromptRecordingFile(named fileName: String) throws {
        let url = paths.promptRecordingURL(fileName: fileName)
        try removeItemIfPresent(at: url)
    }

    public func deleteCorrectionAudioFile(named fileName: String) throws {
        let url = paths.correctionAudioURL(fileName: fileName)
        try removeItemIfPresent(at: url)
    }

    public func deleteGeneratedAudioFile(named fileName: String) throws {
        let url = paths.generatedAudioURL(fileName: fileName)
        try removeItemIfPresent(at: url)
    }

    public func clearAllGeneratedAudioFiles() throws {
        try clearDirectoryContents(paths.generatedAudioDirectory)
    }

    public func clearAllPromptRecordings() throws {
        try clearDirectoryContents(paths.promptRecordingsDirectory)
    }

    public func clearImportedModelFiles() throws {
        try clearDirectoryContents(paths.importedModelDirectory)
    }

    public func deleteCompleteProfileAndData(includeImportedModel: Bool = false) throws {
        try clearDirectoryContents(paths.promptRecordingsDirectory)
        try clearDirectoryContents(paths.correctionsDirectory)
        try clearDirectoryContents(paths.generatedAudioDirectory)
        if includeImportedModel {
            try clearDirectoryContents(paths.importedModelDirectory)
        }
        try removeItemIfPresent(at: paths.profileFileURL)
        logger.info("Deleted local voice profile and recordings.")
    }

    public func computeStorageUsage() -> StorageUsageSummary {
        let rec = directorySize(paths.promptRecordingsDirectory)
        let cor = directorySize(paths.correctionsDirectory)
        let gen = directorySize(paths.generatedAudioDirectory)
        let mod = directorySize(paths.importedModelDirectory)
        return StorageUsageSummary(
            totalBytes: rec + cor + gen + mod,
            recordingsBytes: rec,
            correctionsBytes: cor,
            generatedBytes: gen,
            modelBytes: mod
        )
    }

    private func removeItemIfPresent(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw StudioError.persistenceFailed(reason: error.localizedDescription)
        }
    }

    private func clearDirectoryContents(_ directory: URL) throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        do {
            let items = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for item in items {
                try fileManager.removeItem(at: item)
            }
        } catch {
            throw StudioError.persistenceFailed(reason: error.localizedDescription)
        }
    }

    private func directorySize(_ directory: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var sum: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
               values.isRegularFile == true,
               let size = values.fileSize {
                sum += Int64(size)
            }
        }
        return sum
    }
}

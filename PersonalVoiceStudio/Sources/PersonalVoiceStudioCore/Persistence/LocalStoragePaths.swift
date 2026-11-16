import Foundation

public struct LocalStoragePaths: Equatable, Sendable {
    public let rootDirectory: URL
    public let profileFileURL: URL
    public let promptRecordingsDirectory: URL
    public let correctionsDirectory: URL
    public let generatedAudioDirectory: URL
    public let importedModelDirectory: URL

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
        self.profileFileURL = rootDirectory.appendingPathComponent("profile.json", isDirectory: false)
        self.promptRecordingsDirectory = rootDirectory.appendingPathComponent("recordings", isDirectory: true)
        self.correctionsDirectory = rootDirectory.appendingPathComponent("corrections", isDirectory: true)
        self.generatedAudioDirectory = rootDirectory.appendingPathComponent("generated", isDirectory: true)
        self.importedModelDirectory = rootDirectory.appendingPathComponent("models/active", isDirectory: true)
    }

    public static func defaultAppSupportPaths(fileManager: FileManager = .default) -> LocalStoragePaths {
        let baseSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let root = baseSupport.appendingPathComponent("PersonalVoiceStudio", isDirectory: true)
        return LocalStoragePaths(rootDirectory: root)
    }

    public func ensureDirectoriesExist(fileManager: FileManager = .default) throws {
        let directories = [
            rootDirectory,
            promptRecordingsDirectory,
            correctionsDirectory,
            generatedAudioDirectory,
            importedModelDirectory
        ]
        for dir in directories {
            if !fileManager.fileExists(atPath: dir.path) {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    public func promptRecordingURL(fileName: String) -> URL {
        promptRecordingsDirectory.appendingPathComponent(fileName, isDirectory: false)
    }

    public func correctionAudioURL(fileName: String) -> URL {
        correctionsDirectory.appendingPathComponent(fileName, isDirectory: false)
    }

    public func generatedAudioURL(fileName: String) -> URL {
        generatedAudioDirectory.appendingPathComponent(fileName, isDirectory: false)
    }
}

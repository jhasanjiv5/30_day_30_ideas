import Foundation

public struct LocalStoragePaths: Equatable, Sendable {
    public let rootDirectory: URL
    public let projectsDirectory: URL
    public let importedVideoModelDirectory: URL

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
        self.projectsDirectory = rootDirectory.appendingPathComponent("projects", isDirectory: true)
        self.importedVideoModelDirectory = rootDirectory.appendingPathComponent("models/scene-generation/active", isDirectory: true)
    }

    public static func defaultAppSupportPaths(fileManager: FileManager = .default) -> LocalStoragePaths {
        let baseSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let root = baseSupport.appendingPathComponent("PersonalVideoStudio", isDirectory: true)
        return LocalStoragePaths(rootDirectory: root)
    }

    public func ensureRootDirectoriesExist(fileManager: FileManager = .default) throws {
        for dir in [rootDirectory, projectsDirectory, importedVideoModelDirectory] {
            if !fileManager.fileExists(atPath: dir.path) {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    public func projectDirectory(for projectID: UUID) -> URL {
        projectsDirectory.appendingPathComponent(projectID.uuidString, isDirectory: true)
    }

    public func projectFileURL(for projectID: UUID) -> URL {
        projectDirectory(for: projectID).appendingPathComponent("project.json", isDirectory: false)
    }

    public func projectMediaDirectory(for projectID: UUID) -> URL {
        projectDirectory(for: projectID).appendingPathComponent("media", isDirectory: true)
    }

    public func projectAudioDirectory(for projectID: UUID) -> URL {
        projectDirectory(for: projectID).appendingPathComponent("audio", isDirectory: true)
    }

    public func projectGeneratedDirectory(for projectID: UUID) -> URL {
        projectDirectory(for: projectID).appendingPathComponent("generated", isDirectory: true)
    }

    public func projectRendersDirectory(for projectID: UUID) -> URL {
        projectDirectory(for: projectID).appendingPathComponent("renders", isDirectory: true)
    }

    public func ensureProjectDirectoriesExist(for projectID: UUID, fileManager: FileManager = .default) throws {
        try ensureRootDirectoriesExist(fileManager: fileManager)
        let dirs = [
            projectDirectory(for: projectID),
            projectMediaDirectory(for: projectID),
            projectAudioDirectory(for: projectID),
            projectGeneratedDirectory(for: projectID),
            projectRendersDirectory(for: projectID)
        ]
        for dir in dirs {
            if !fileManager.fileExists(atPath: dir.path) {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    public func mediaFileURL(projectID: UUID, fileName: String) -> URL {
        projectMediaDirectory(for: projectID).appendingPathComponent(fileName, isDirectory: false)
    }

    public func audioFileURL(projectID: UUID, fileName: String) -> URL {
        projectAudioDirectory(for: projectID).appendingPathComponent(fileName, isDirectory: false)
    }

    public func generatedClipURL(projectID: UUID, fileName: String) -> URL {
        projectGeneratedDirectory(for: projectID).appendingPathComponent(fileName, isDirectory: false)
    }

    public func renderFileURL(projectID: UUID, fileName: String) -> URL {
        projectRendersDirectory(for: projectID).appendingPathComponent(fileName, isDirectory: false)
    }
}

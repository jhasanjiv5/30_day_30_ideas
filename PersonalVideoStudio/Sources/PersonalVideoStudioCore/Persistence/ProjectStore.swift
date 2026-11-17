import Foundation

public final class ProjectStore: @unchecked Sendable {
    private let paths: LocalStoragePaths
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

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

    public func listProjects() throws -> [VideoProject] {
        try paths.ensureRootDirectoriesExist(fileManager: fileManager)
        let contents = try fileManager.contentsOfDirectory(
            at: paths.projectsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var projects: [VideoProject] = []
        for entry in contents {
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            let projectFile = entry.appendingPathComponent("project.json", isDirectory: false)
            guard fileManager.fileExists(atPath: projectFile.path) else { continue }
            let data = try Data(contentsOf: projectFile)
            let project = try decoder.decode(VideoProject.self, from: data)
            projects.append(project)
        }

        return projects.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func createProject(title: String) throws -> VideoProject {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw VideoStudioError.invalidProject(reason: "Please provide a project name.")
        }
        let project = VideoProject(title: trimmed)
        try saveProject(project)
        return project
    }

    public func loadProject(id: UUID) throws -> VideoProject {
        let projectFile = paths.projectFileURL(for: id)
        guard fileManager.fileExists(atPath: projectFile.path) else {
            throw VideoStudioError.projectNotFound(id: id)
        }
        do {
            let data = try Data(contentsOf: projectFile)
            return try decoder.decode(VideoProject.self, from: data)
        } catch {
            throw VideoStudioError.storageFailure(reason: "Failed to read project file: \(error.localizedDescription)")
        }
    }

    public func saveProject(_ project: VideoProject) throws {
        var updated = project
        updated.updatedAt = Date()
        try paths.ensureProjectDirectoriesExist(for: updated.id, fileManager: fileManager)
        let projectFile = paths.projectFileURL(for: updated.id)
        do {
            let data = try encoder.encode(updated)
            try data.write(to: projectFile, options: [.atomic])
        } catch {
            throw VideoStudioError.storageFailure(reason: "Failed to save project locally: \(error.localizedDescription)")
        }
    }

    public func renameProject(id: UUID, newTitle: String) throws -> VideoProject {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw VideoStudioError.invalidProject(reason: "Project name cannot be empty.")
        }
        var project = try loadProject(id: id)
        project.title = trimmed
        try saveProject(project)
        return project
    }

    public func deleteProject(id: UUID) throws {
        let projectDir = paths.projectDirectory(for: id)
        if fileManager.fileExists(atPath: projectDir.path) {
            try fileManager.removeItem(at: projectDir)
        }
    }

    public func deleteRender(projectID: UUID, renderID: UUID) throws -> VideoProject {
        var project = try loadProject(id: projectID)
        if let index = project.renders.firstIndex(where: { $0.id == renderID }) {
            let record = project.renders[index]
            let renderURL = paths.renderFileURL(projectID: projectID, fileName: record.fileName)
            if fileManager.fileExists(atPath: renderURL.path) {
                try fileManager.removeItem(at: renderURL)
            }
            project.renders.remove(at: index)
            try saveProject(project)
        }
        return project
    }

    public func clearAllRenders(projectID: UUID) throws -> VideoProject {
        var project = try loadProject(id: projectID)
        let rendersDir = paths.projectRendersDirectory(for: projectID)
        if fileManager.fileExists(atPath: rendersDir.path) {
            try fileManager.removeItem(at: rendersDir)
        }
        try fileManager.createDirectory(at: rendersDir, withIntermediateDirectories: true)
        project.renders.removeAll()
        try saveProject(project)
        return project
    }

    public func deleteImportedVideoModel() throws {
        let modelDir = paths.importedVideoModelDirectory
        if fileManager.fileExists(atPath: modelDir.path) {
            try fileManager.removeItem(at: modelDir)
        }
        try fileManager.createDirectory(at: modelDir, withIntermediateDirectories: true)
    }

    public func directorySizeBytes(at directoryURL: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true,
                  let size = values.fileSize else {
                continue
            }
            total += Int64(size)
        }
        return total
    }
}

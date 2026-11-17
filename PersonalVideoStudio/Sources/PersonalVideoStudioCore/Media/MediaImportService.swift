import Foundation

public struct ImportedVisualMedia: Equatable, Sendable {
    public let fileName: String
    public let mediaKind: SceneMediaKind

    public init(fileName: String, mediaKind: SceneMediaKind) {
        self.fileName = fileName
        self.mediaKind = mediaKind
    }
}

public final class MediaImportService: @unchecked Sendable {
    public static let supportedImageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "tiff", "webp"]
    public static let supportedVideoExtensions: Set<String> = ["mp4", "mov", "m4v"]
    public static let supportedAudioExtensions: Set<String> = ["wav", "m4a", "mp3", "aac", "aiff", "caf"]

    private let paths: LocalStoragePaths
    private let fileManager: FileManager
    private let diskChecker: DiskSpaceChecking
    private let audioInspector: AudioAssetInspecting

    public init(
        paths: LocalStoragePaths,
        fileManager: FileManager = .default,
        diskChecker: DiskSpaceChecking = DiskSpaceChecker(),
        audioInspector: AudioAssetInspecting = AudioAssetInspector()
    ) {
        self.paths = paths
        self.fileManager = fileManager
        self.diskChecker = diskChecker
        self.audioInspector = audioInspector
    }

    public func importVisualMedia(from sourceURL: URL, into projectID: UUID) throws -> ImportedVisualMedia {
        try SecurityScopedBookmarkManager.withSecurityScopedAccess(to: sourceURL) { url in
            let ext = url.pathExtension.lowercased()
            let kind: SceneMediaKind
            if Self.supportedImageExtensions.contains(ext) {
                kind = .image
            } else if Self.supportedVideoExtensions.contains(ext) {
                kind = .video
            } else {
                throw VideoStudioError.mediaImportFailed(
                    reason: "Unsupported visual format '.\(ext)'. Use PNG, JPEG, HEIC, MP4, or MOV."
                )
            }

            try paths.ensureProjectDirectoriesExist(for: projectID, fileManager: fileManager)
            let fileSize = try regularFileSize(at: url)
            try diskChecker.ensureSufficientSpace(
                at: paths.projectMediaDirectory(for: projectID),
                requiredBytes: fileSize + 20_971_520
            )

            let safeFileName = "\(UUID().uuidString.prefix(8))-\(sanitizedFileName(url.lastPathComponent))"
            let destinationURL = paths.mediaFileURL(projectID: projectID, fileName: safeFileName)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: url, to: destinationURL)
            return ImportedVisualMedia(fileName: safeFileName, mediaKind: kind)
        }
    }

    public func importAudioTrack(
        from sourceURL: URL,
        role: AudioTrackRole,
        into projectID: UUID
    ) async throws -> AudioTrackItem {
        try await SecurityScopedBookmarkManager.withAsyncSecurityScopedAccess(to: sourceURL) { url in
            let ext = url.pathExtension.lowercased()
            guard Self.supportedAudioExtensions.contains(ext) else {
                throw VideoStudioError.mediaImportFailed(
                    reason: "Unsupported audio format '.\(ext)'. Import .wav (including PersonalVoiceStudio exports), .m4a, .mp3, or .aac."
                )
            }

            let metadata = try await audioInspector.inspectAudio(at: url)
            try paths.ensureProjectDirectoriesExist(for: projectID, fileManager: fileManager)
            let fileSize = try regularFileSize(at: url)
            try diskChecker.ensureSufficientSpace(
                at: paths.projectAudioDirectory(for: projectID),
                requiredBytes: fileSize + 20_971_520
            )

            let safeFileName = "\(UUID().uuidString.prefix(8))-\(sanitizedFileName(url.lastPathComponent))"
            let destinationURL = paths.audioFileURL(projectID: projectID, fileName: safeFileName)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: url, to: destinationURL)

            let baseTitle = url.deletingPathExtension().lastPathComponent
            return AudioTrackItem(
                role: role,
                displayName: baseTitle.isEmpty ? role.displayName : baseTitle,
                fileName: safeFileName,
                sourceFormat: metadata.formatExtension.uppercased(),
                sourceDurationSeconds: metadata.durationSeconds,
                sampleRate: metadata.sampleRate
            )
        }
    }

    private func regularFileSize(at url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else {
            throw VideoStudioError.mediaImportFailed(reason: "Selected item is not a readable regular file.")
        }
        return Int64(values.fileSize ?? 0)
    }

    private func sanitizedFileName(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let cleaned = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let result = String(cleaned)
        return result.isEmpty ? "asset.dat" : result
    }
}

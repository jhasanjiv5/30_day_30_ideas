import Foundation

public struct OfflineVideoModelValidator: Sendable {
    private let fileManager: FileManager
    private let diskChecker: DiskSpaceChecking

    public init(
        fileManager: FileManager = .default,
        diskChecker: DiskSpaceChecking = DiskSpaceChecker()
    ) {
        self.fileManager = fileManager
        self.diskChecker = diskChecker
    }

    public func validate(directoryURL: URL) throws -> ValidatedVideoModelBundle {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw VideoStudioError.invalidModelDirectory(
                reason: "The selected path does not exist or is not a folder."
            )
        }

        let topLevelContents: [URL]
        do {
            topLevelContents = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw VideoStudioError.invalidModelDirectory(reason: error.localizedDescription)
        }

        let topNames = Set(topLevelContents.map(\.lastPathComponent))
        let metadataCandidates = ["model_manifest.json", "config.json"]
        guard let manifestName = metadataCandidates.first(where: { topNames.contains($0) }) else {
            throw VideoStudioError.invalidModelDirectory(
                reason: "Missing model_manifest.json or config.json in the selected local video model folder."
            )
        }

        let manifestURL = directoryURL.appendingPathComponent(manifestName)
        let parsed = try parseModelMetadata(from: manifestURL)
        let regularFiles = try collectRegularFiles(in: directoryURL)

        var weightPaths: [String] = []
        var detectedFormat = parsed.runtimeFormat

        for item in topLevelContents where item.pathExtension.lowercased() == "mlmodelc" || item.pathExtension.lowercased() == "mlpackage" {
            weightPaths.append(item.lastPathComponent)
            detectedFormat = item.pathExtension.lowercased()
        }

        let regularWeightFiles = regularFiles.filter { url in
            let ext = url.pathExtension.lowercased()
            return ext == "safetensors" || ext == "gguf" || ext == "onnx" || ext == "bin" || ext == "mil"
        }

        for url in regularWeightFiles {
            weightPaths.append(relativePath(of: url, to: directoryURL))
        }

        let uniqueWeights = Array(Set(weightPaths)).sorted()
        guard !uniqueWeights.isEmpty else {
            throw VideoStudioError.invalidModelDirectory(
                reason: "No local model weight files found (expected .safetensors, .gguf, .mlmodelc, .mlpackage, or .onnx)."
            )
        }

        let metadataFiles = regularFiles
            .filter { ["model_manifest.json", "config.json", "LICENSE", "NOTICE"].contains($0.lastPathComponent) }
            .map { relativePath(of: $0, to: directoryURL) }
            .sorted()

        var totalBytes: Int64 = 0
        for file in regularFiles {
            if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalBytes += Int64(size)
            }
        }

        return ValidatedVideoModelBundle(
            directoryPath: directoryURL.path,
            modelArchitecture: parsed.architecture,
            runtimeFormat: detectedFormat,
            capabilities: parsed.capabilities,
            weightFiles: uniqueWeights,
            metadataFiles: metadataFiles,
            totalSizeBytes: totalBytes
        )
    }

    public func importModelDirectory(from sourceURL: URL, into destinationDirectory: URL) throws -> ValidatedVideoModelBundle {
        try SecurityScopedBookmarkManager.withSecurityScopedAccess(to: sourceURL) { securedURL in
            let validatedSource = try validate(directoryURL: securedURL)
            let requiredBytes = validatedSource.totalSizeBytes + 524_288_000 // +500 MB safety headroom
            try diskChecker.ensureSufficientSpace(
                at: destinationDirectory.deletingLastPathComponent(),
                requiredBytes: requiredBytes
            )

            if fileManager.fileExists(atPath: destinationDirectory.path) {
                try fileManager.removeItem(at: destinationDirectory)
            }
            try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

            let items = try fileManager.contentsOfDirectory(
                at: securedURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            for item in items {
                let target = destinationDirectory.appendingPathComponent(item.lastPathComponent)
                try fileManager.copyItem(at: item, to: target)
            }

            return try validate(directoryURL: destinationDirectory)
        }
    }

    private func collectRegularFiles(in directoryURL: URL) throws -> [URL] {
        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )

        var files: [URL] = []
        for item in contents {
            let values = try item.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true {
                throw VideoStudioError.invalidModelDirectory(
                    reason: "Symbolic links are not allowed inside imported model folders (\(item.lastPathComponent))."
                )
            } else if values.isRegularFile == true {
                files.append(item)
            } else if values.isDirectory == true {
                files.append(contentsOf: try collectRegularFiles(in: item))
            }
        }
        return files
    }

    private func relativePath(of fileURL: URL, to directoryURL: URL) -> String {
        let dirPath = directoryURL.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        return String(filePath.dropFirst(dirPath.count).drop(while: { $0 == "/" }))
    }

    private func parseModelMetadata(
        from manifestURL: URL
    ) throws -> (architecture: String, runtimeFormat: String, capabilities: VideoModelCapabilities) {
        let data: Data
        do {
            data = try Data(contentsOf: manifestURL)
        } catch {
            throw VideoStudioError.invalidModelDirectory(
                reason: "Unable to read \(manifestURL.lastPathComponent): \(error.localizedDescription)"
            )
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw VideoStudioError.invalidModelDirectory(
                reason: "\(manifestURL.lastPathComponent) is not valid JSON."
            )
        }

        let architecture = (json["model_type"] as? String)
            ?? (json["architecture"] as? String)
            ?? "custom-i2v-lipsync"
        let runtimeFormat = (json["runtime"] as? String) ?? "mlx-or-coreml"

        let supportsI2V = (json["supports_image_to_video"] as? Bool) ?? true
        let supportsBehaviorPrompt = (json["supports_behavior_text_prompt"] as? Bool) ?? true
        let supportsBodyMotion = (json["supports_hand_and_body_motion"] as? Bool) ?? true
        let supportsLipSync = (json["supports_lip_sync"] as? Bool) ?? false
        let supportsAudio = (json["supports_audio_conditioning"] as? Bool) ?? supportsLipSync
        let minRAM = (json["min_unified_memory_gb"] as? Int) ?? 16
        let maxDuration = (json["max_clip_duration_seconds"] as? Double) ?? 8.0

        let capabilities = VideoModelCapabilities(
            supportsImageToVideo: supportsI2V,
            supportsBehaviorTextPrompt: supportsBehaviorPrompt,
            supportsBodyAndHandMotion: supportsBodyMotion,
            supportsPortraitLipSync: supportsLipSync,
            supportsAudioConditioning: supportsAudio,
            minimumUnifiedMemoryGB: minRAM,
            maxClipDurationSeconds: maxDuration,
            supportedAudioSampleRates: [16_000, 24_000, 44_100]
        )
        return (architecture, runtimeFormat, capabilities)
    }
}

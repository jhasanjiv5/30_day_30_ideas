import Foundation

public struct OfflineLocalModelValidator: Sendable {
    private let fileManager: FileManager
    private let diskChecker: DiskSpaceChecking

    public init(
        fileManager: FileManager = .default,
        diskChecker: DiskSpaceChecking = DiskSpaceChecker()
    ) {
        self.fileManager = fileManager
        self.diskChecker = diskChecker
    }

    public func validate(directoryURL: URL) throws -> ValidatedModelBundle {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw StudioError.invalidModelDirectory(reason: "The selected path does not exist or is not a folder.")
        }

        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw StudioError.invalidModelDirectory(reason: error.localizedDescription)
        }

        let fileNames = Set(contents.map { $0.lastPathComponent })

        guard fileNames.contains("config.json") else {
            throw StudioError.invalidModelDirectory(
                reason: "Missing config.json. Select an unpacked local MLX model folder (for example Qwen3-TTS-12Hz-0.6B-Base-8bit)."
            )
        }

        let configURL = directoryURL.appendingPathComponent("config.json")
        let modelType = try parseModelType(from: configURL)
        let regularFiles = try collectRegularFiles(in: directoryURL)

        let recognizedTokenizerCandidates = [
            "tokenizer.json",
            "tokenizer_config.json",
            "vocab.json",
            "merges.txt",
            "spm.model"
        ]
        let tokenizerFiles = regularFiles.filter {
            recognizedTokenizerCandidates.contains($0.lastPathComponent)
        }
        guard !tokenizerFiles.isEmpty else {
            throw StudioError.invalidModelDirectory(
                reason: "Missing tokenizer files (expected tokenizer.json, tokenizer_config.json, or vocab.json)."
            )
        }

        let weightExtensions: Set<String> = ["safetensors", "npz", "mlmodelc"]
        let weightURLs = regularFiles.filter { url in
            weightExtensions.contains(url.pathExtension.lowercased())
        }
        guard !weightURLs.isEmpty else {
            throw StudioError.invalidModelDirectory(
                reason: "No local weight files found (expected .safetensors weights in the selected folder)."
            )
        }

        if modelType.lowercased() == "qwen3_tts" {
            let speechTokenizerDirectory = directoryURL.appendingPathComponent("speech_tokenizer", isDirectory: true)
            let speechTokenizerFiles = regularFiles.filter {
                $0.deletingLastPathComponent().standardizedFileURL == speechTokenizerDirectory.standardizedFileURL
            }
            guard speechTokenizerFiles.contains(where: { $0.lastPathComponent == "config.json" }) else {
                throw StudioError.invalidModelDirectory(
                    reason: "Missing speech_tokenizer/config.json. Import the complete MLX Qwen3-TTS model folder."
                )
            }
            guard speechTokenizerFiles.contains(where: { $0.pathExtension.lowercased() == "safetensors" }) else {
                throw StudioError.invalidModelDirectory(
                    reason: "Missing speech_tokenizer weight files. Import the complete MLX Qwen3-TTS model folder."
                )
            }
        }

        var totalBytes: Int64 = 0
        for file in regularFiles {
            do {
                if let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalBytes += Int64(size)
                }
            } catch {
                throw StudioError.invalidModelDirectory(reason: error.localizedDescription)
            }
        }

        return ValidatedModelBundle(
            directoryPath: directoryURL.path,
            modelType: modelType,
            weightFiles: weightURLs.map { relativePath(of: $0, to: directoryURL) }.sorted(),
            tokenizerFiles: tokenizerFiles.map { relativePath(of: $0, to: directoryURL) }.sorted(),
            totalSizeBytes: totalBytes
        )
    }

    public func importModelDirectory(from sourceURL: URL, into destinationDirectory: URL) throws -> ValidatedModelBundle {
        let validatedSource = try validate(directoryURL: sourceURL)

        // Require source size + 200 MB headroom before copying into Application Support.
        let requiredBytes = validatedSource.totalSizeBytes + 209_715_200
        try diskChecker.ensureSufficientSpace(
            at: destinationDirectory.deletingLastPathComponent(),
            requiredBytes: requiredBytes
        )

        if fileManager.fileExists(atPath: destinationDirectory.path) {
            try fileManager.removeItem(at: destinationDirectory)
        }
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let items = try fileManager.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        for item in items {
            let target = destinationDirectory.appendingPathComponent(item.lastPathComponent)
            try fileManager.copyItem(at: item, to: target)
        }

        return try validate(directoryURL: destinationDirectory)
    }

    private func collectRegularFiles(in directoryURL: URL) throws -> [URL] {
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw StudioError.invalidModelDirectory(reason: error.localizedDescription)
        }

        var files: [URL] = []
        for item in contents {
            let values: URLResourceValues
            do {
                values = try item.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey])
            } catch {
                throw StudioError.invalidModelDirectory(reason: error.localizedDescription)
            }

            if values.isSymbolicLink == true {
                throw StudioError.invalidModelDirectory(
                    reason: "Symbolic links are not supported in model folders: \(item.lastPathComponent)."
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
        let directoryPath = directoryURL.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        return String(filePath.dropFirst(directoryPath.count).drop(while: { $0 == "/" }))
    }

    private func parseModelType(from configURL: URL) throws -> String {
        let data: Data
        do {
            data = try Data(contentsOf: configURL)
        } catch {
            throw StudioError.invalidModelDirectory(reason: "Unable to read config.json: \(error.localizedDescription)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StudioError.invalidModelDirectory(reason: "config.json is not valid JSON.")
        }

        if let modelType = json["model_type"] as? String, !modelType.isEmpty {
            return modelType
        }
        if let architectures = json["architectures"] as? [String], let first = architectures.first, !first.isEmpty {
            return first
        }
        return "local-mlx-tts"
    }
}

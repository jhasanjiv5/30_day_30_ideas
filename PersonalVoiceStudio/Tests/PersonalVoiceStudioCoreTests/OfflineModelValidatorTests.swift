import XCTest
@testable import PersonalVoiceStudioCore

final class OfflineModelValidatorTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("pvs-model-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testMissingConfigFailsValidation() throws {
        let validator = OfflineLocalModelValidator()
        XCTAssertThrowsError(try validator.validate(directoryURL: tempRoot)) { error in
            guard case StudioError.invalidModelDirectory = error else {
                return XCTFail("Expected invalidModelDirectory error")
            }
        }
    }

    func testQwenModelWithoutSpeechTokenizerFailsValidation() throws {
        let sourceDir = tempRoot.appendingPathComponent("incomplete-source", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try Data(#"{"model_type": "qwen3_tts"}"#.utf8)
            .write(to: sourceDir.appendingPathComponent("config.json"))
        try Data("{}".utf8)
            .write(to: sourceDir.appendingPathComponent("vocab.json"))
        try Data("weights".utf8)
            .write(to: sourceDir.appendingPathComponent("model.safetensors"))

        XCTAssertThrowsError(try OfflineLocalModelValidator().validate(directoryURL: sourceDir)) { error in
            guard case StudioError.invalidModelDirectory(let reason) = error else {
                return XCTFail("Expected invalidModelDirectory error")
            }
            XCTAssertTrue(reason.contains("speech_tokenizer"))
        }
    }

    func testValidLocalModelBundleImportsOffline() throws {
        let sourceDir = tempRoot.appendingPathComponent("source", isDirectory: true)
        let destDir = tempRoot.appendingPathComponent("imported", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        try Data(#"{"model_type": "qwen3_tts"}"#.utf8)
            .write(to: sourceDir.appendingPathComponent("config.json"))
        try Data("{}".utf8)
            .write(to: sourceDir.appendingPathComponent("vocab.json"))
        try Data("weights".utf8)
            .write(to: sourceDir.appendingPathComponent("model.safetensors"))
        let speechTokenizerDir = sourceDir.appendingPathComponent("speech_tokenizer", isDirectory: true)
        try FileManager.default.createDirectory(at: speechTokenizerDir, withIntermediateDirectories: true)
        try Data("tokenizer weights".utf8)
            .write(to: speechTokenizerDir.appendingPathComponent("model.safetensors"))
        try Data(#"{"sample_rate": 24000}"#.utf8)
            .write(to: speechTokenizerDir.appendingPathComponent("config.json"))

        let validator = OfflineLocalModelValidator(diskChecker: DiskSpaceChecker { _ in 1_000_000_000 })
        let bundle = try validator.importModelDirectory(from: sourceDir, into: destDir)

        XCTAssertEqual(bundle.modelType, "qwen3_tts")
        XCTAssertEqual(bundle.weightFiles, ["model.safetensors", "speech_tokenizer/model.safetensors"])
        XCTAssertEqual(bundle.tokenizerFiles, ["vocab.json"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: destDir.appendingPathComponent("model.safetensors").path))
        XCTAssertEqual(
            try Data(contentsOf: destDir.appendingPathComponent("speech_tokenizer/model.safetensors")),
            Data("tokenizer weights".utf8)
        )
    }
}

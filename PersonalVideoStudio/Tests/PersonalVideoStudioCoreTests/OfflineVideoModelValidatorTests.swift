import XCTest
@testable import PersonalVideoStudioCore

final class OfflineVideoModelValidatorTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("pvid-model-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testMissingManifestFailsValidation() {
        let validator = OfflineVideoModelValidator()
        XCTAssertThrowsError(try validator.validate(directoryURL: tempRoot)) { error in
            guard case VideoStudioError.invalidModelDirectory = error else {
                return XCTFail("Expected invalidModelDirectory error")
            }
        }
    }

    func testSymbolicLinkInsideModelFolderIsRejected() throws {
        let sourceDir = tempRoot.appendingPathComponent("symlink-model", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try Data(#"{"model_type": "wan2.1_i2v"}"#.utf8)
            .write(to: sourceDir.appendingPathComponent("model_manifest.json"))
        let targetFile = tempRoot.appendingPathComponent("external.safetensors")
        try Data("weights".utf8).write(to: targetFile)
        try FileManager.default.createSymbolicLink(
            at: sourceDir.appendingPathComponent("linked.safetensors"),
            withDestinationURL: targetFile
        )

        XCTAssertThrowsError(try OfflineVideoModelValidator().validate(directoryURL: sourceDir)) { error in
            guard case VideoStudioError.invalidModelDirectory(let reason) = error else {
                return XCTFail("Expected invalidModelDirectory error")
            }
            XCTAssertTrue(reason.contains("Symbolic links"))
        }
    }

    func testValidVisualTextAndLipSyncModelImportsAndCapabilitiesParse() throws {
        let sourceDir = tempRoot.appendingPathComponent("wan-echomimic", isDirectory: true)
        let destDir = tempRoot.appendingPathComponent("active", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let manifest = """
        {
          "model_type": "wan2.1_i2v_echomimic",
          "runtime": "mlx",
          "supports_image_to_video": true,
          "supports_behavior_text_prompt": true,
          "supports_hand_and_body_motion": true,
          "supports_lip_sync": true,
          "supports_audio_conditioning": true,
          "min_unified_memory_gb": 16,
          "max_clip_duration_seconds": 8.0
        }
        """
        try Data(manifest.utf8).write(to: sourceDir.appendingPathComponent("model_manifest.json"))
        try Data("Apache-2.0".utf8).write(to: sourceDir.appendingPathComponent("LICENSE"))
        try Data("weights".utf8).write(to: sourceDir.appendingPathComponent("model.safetensors"))

        let validator = OfflineVideoModelValidator(diskChecker: DiskSpaceChecker { _ in 4_000_000_000 })
        let bundle = try validator.importModelDirectory(from: sourceDir, into: destDir)

        XCTAssertEqual(bundle.modelArchitecture, "wan2.1_i2v_echomimic")
        XCTAssertTrue(bundle.capabilities.supportsImageToVideo)
        XCTAssertTrue(bundle.capabilities.supportsBehaviorTextPrompt)
        XCTAssertTrue(bundle.capabilities.supportsBodyAndHandMotion)
        XCTAssertTrue(bundle.capabilities.supportsPortraitLipSync)
        XCTAssertEqual(bundle.capabilities.minimumUnifiedMemoryGB, 16)

        let unlinkedEngine = LocalSceneGenerationEngine(
            isAppleSilicon: true,
            physicalMemoryGB: 32,
            isRuntimeLinked: false
        )
        XCTAssertFalse(unlinkedEngine.currentReadiness(modelDirectory: destDir).isReadyForInference)
        XCTAssertEqual(unlinkedEngine.currentCapabilities(modelDirectory: destDir), .unavailable)

        let lowMemoryEngine = LocalSceneGenerationEngine(
            isAppleSilicon: true,
            physicalMemoryGB: 8,
            isRuntimeLinked: true
        )
        if case .insufficientMemory = lowMemoryEngine.currentReadiness(modelDirectory: destDir) {
            // Expected insufficient unified memory state
        } else {
            XCTFail("Expected insufficientMemory readiness state on 8 GB Mac")
        }
    }
}

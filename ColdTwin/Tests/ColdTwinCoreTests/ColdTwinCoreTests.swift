import XCTest
@testable import ColdTwinCore

final class ColdTwinCoreTests: XCTestCase {
    func testDoorEventIsPreparedAsEvidenceForModelAssessment() {
        let engine = DiagnosisEngine()
        let asset = Asset(id: "cooler-07", siteId: "site-1", name: "Cooler 7", assetType: .cooler)
        let now = Date()
        let iso = ISO8601DateFormatter()
        let readings = [
            TemperatureReading(assetId: "cooler-07", originalValue: 3.0, originalUnit: .celsius, originalTimestamp: iso.string(from: now.addingTimeInterval(-3600)), timestamp: now.addingTimeInterval(-3600)),
            TemperatureReading(assetId: "cooler-07", originalValue: 6.8, originalUnit: .celsius, originalTimestamp: iso.string(from: now.addingTimeInterval(-1800)), timestamp: now.addingTimeInterval(-1800)),
            TemperatureReading(assetId: "cooler-07", originalValue: 7.4, originalUnit: .celsius, originalTimestamp: iso.string(from: now.addingTimeInterval(-300)), timestamp: now.addingTimeInterval(-300))
        ]
        let events = [
            RecordedEvent(assetId: "cooler-07", originalTimestamp: iso.string(from: now.addingTimeInterval(-2400)), timestamp: now.addingTimeInterval(-2400), category: .doorOpen, note: "Door propped open")
        ]

        let analysis = engine.prepare(
            asset: asset,
            readings: readings,
            events: events,
            context: ResourceContext(availableMinutes: 15, availableSkills: [.basicInspection], availableTools: [.flashlight, .gasketCard]),
            now: now
        )
        XCTAssertTrue(analysis.observations.contains { $0.eventIds.contains(events[0].id) })
        XCTAssertEqual(analysis.options.count, 5)
    }

    func testModelAssessmentsCanBeOverriddenByLocalUserMemory() throws {
        let asset = Asset(id: "cooler-07", siteId: "site-1", name: "Cooler 7", assetType: .cooler)
        let draft = DiagnosisEngine().prepare(
            asset: asset,
            readings: [],
            events: [],
            context: ResourceContext()
        )
        let assessments = draft.options.map {
            ModelHypothesisAssessment(
                candidateID: $0.id,
                status: .needsMoreEvidence,
                explanation: "The available evidence is insufficient.",
                supportingObservationIDs: [],
                missingInformation: ["More evidence is needed."]
            )
        }
        let memory = InferenceMemory(
            assessmentOverrides: ["cooler-07::option-door-seal": .possible]
        )

        let analysis = try OnDeviceDiagnosisEngine().applying(
            assessments,
            to: draft,
            context: ResourceContext(),
            memory: memory
        )

        XCTAssertEqual(
            analysis.options.first { $0.id == "option-door-seal" }?.status,
            "possible"
        )
    }

    func testModelAssessmentWithUnknownObservationIsSafelyDowngraded() throws {
        let asset = Asset(id: "cooler-07", siteId: "site-1", name: "Cooler 7", assetType: .cooler)
        let draft = DiagnosisEngine().prepare(
            asset: asset,
            readings: [],
            events: [],
            context: ResourceContext()
        )
        let assessments = draft.options.map {
            ModelHypothesisAssessment(
                candidateID: $0.id,
                status: .possible,
                explanation: "A provisional assessment.",
                supportingObservationIDs: ["invented-observation"],
                missingInformation: []
            )
        }

        let analysis = try OnDeviceDiagnosisEngine().applying(
            assessments,
            to: draft,
            context: ResourceContext()
        )
        let affectedOption = try XCTUnwrap(analysis.options.first { $0.id == "option-door-seal" })
        XCTAssertEqual(affectedOption.status, "not_enough_evidence")
        XCTAssertTrue(affectedOption.supportingObservationIds.isEmpty)
        XCTAssertTrue(affectedOption.plainLanguageExplanation.contains("not present in the recorded evidence"))
    }

    func testPossibleModelAssessmentRequiresSupportingEvidence() {
        let asset = Asset(id: "cooler-07", siteId: "site-1", name: "Cooler 7", assetType: .cooler)
        let draft = DiagnosisEngine().prepare(
            asset: asset,
            readings: [],
            events: [],
            context: ResourceContext()
        )
        let assessments = draft.options.map {
            ModelHypothesisAssessment(
                candidateID: $0.id,
                status: .possible,
                explanation: "A provisional assessment.",
                supportingObservationIDs: [],
                missingInformation: []
            )
        }

        XCTAssertThrowsError(
            try OnDeviceDiagnosisEngine().applying(assessments, to: draft, context: ResourceContext())
        )
    }

    func testInferenceMemoryPersistsRulesOverridesAndFeedbackLocally() throws {
        let suiteName = "ColdTwinCoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated test preferences.")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LocalInferenceMemoryStore(defaults: defaults)
        let memory = InferenceMemory(
            customRules: ["Treat repeated readings as stronger evidence."],
            assessmentOverrides: ["cooler-07::option-door-seal": .possible],
            feedback: [
                InferenceFeedback(
                    assetID: "cooler-07",
                    hypothesisID: "option-door-seal",
                    assessment: .possible
                )
            ]
        )

        try store.save(memory)

        XCTAssertEqual(try store.load(), memory)
    }

    func testInventoryPersistsSitesAssetsReadingsEventsAndContext() throws {
        let suiteName = "ColdTwinCoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated test preferences.")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let site = Site(id: "site-1", name: "North Shop", location: "Back room")
        let asset = Asset(id: "cooler-1", siteId: site.id, name: "Cooler 1", assetType: .cooler)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let reading = TemperatureReading(
            assetId: asset.id,
            originalValue: 4.2,
            originalUnit: .celsius,
            originalTimestamp: ISO8601DateFormatter().string(from: timestamp),
            timestamp: timestamp,
            sourceLabel: "Manual"
        )
        let event = RecordedEvent(
            assetId: asset.id,
            originalTimestamp: reading.originalTimestamp,
            timestamp: timestamp,
            category: .doorOpen,
            note: "Door left open"
        )
        let context = ResourceContext(
            availableMinutes: 30,
            availableSkills: [.basicInspection],
            availableTools: [.flashlight, .gasketCard]
        )
        let snapshot = ColdTwinInventorySnapshot(
            sites: [site],
            assets: [asset],
            readings: [reading],
            events: [event],
            resourceContext: context,
            selectedAssetID: asset.id
        )
        let store = LocalColdTwinInventoryStore(defaults: defaults, storageKey: "test.inventory")

        try store.save(snapshot)
        let restored = try XCTUnwrap(store.load())

        XCTAssertEqual(restored.sites, [site])
        XCTAssertEqual(restored.assets, [asset])
        XCTAssertEqual(restored.readings, [reading])
        XCTAssertEqual(restored.events, [event])
        XCTAssertEqual(restored.resourceContext, context)
        XCTAssertEqual(restored.selectedAssetID, asset.id)
    }

    func testOlderInferenceMemoryDecodesWithoutExternalModelFields() throws {
        let legacyData = Data(
            #"{"customRules":["Prefer repeated readings"],"assessmentOverrides":{},"feedback":[]}"#.utf8
        )

        let memory = try JSONDecoder().decode(InferenceMemory.self, from: legacyData)

        XCTAssertEqual(memory.customRules, ["Prefer repeated readings"])
        XCTAssertTrue(memory.externalModels.isEmpty)
        XCTAssertNil(memory.selectedExternalModelID)
    }

    func testExternalModelEndpointRequiresHTTPSExceptForLoopback() throws {
        XCTAssertEqual(
            try OpenAICompatibleDiagnosisEngine.validateBaseURL("https://api.example.test/v1").host,
            "api.example.test"
        )
        XCTAssertNoThrow(try OpenAICompatibleDiagnosisEngine.validateBaseURL("http://localhost:11434/v1"))
        XCTAssertThrowsError(try OpenAICompatibleDiagnosisEngine.validateBaseURL("http://api.example.test/v1"))
        XCTAssertThrowsError(try OpenAICompatibleDiagnosisEngine.validateBaseURL("https://user:pass@example.test/v1"))
    }

    func testExternalOpenAICompatibleResponseIsValidatedAndApplied() async throws {
        let responseContent = """
        {"assessments":[
          {"candidateID":"option-door-seal","status":"possible","explanation":"A door event aligns with the elevated reading.","supportingObservationIDs":["obs-1"],"missingInformation":[]},
          {"candidateID":"option-loading-ambient","status":"needsMoreEvidence","explanation":"No loading event was logged.","supportingObservationIDs":[],"missingInformation":["Confirm recent stock delivery."]},
          {"candidateID":"option-defrost-cycle","status":"needsMoreEvidence","explanation":"No defrost event was logged.","supportingObservationIDs":[],"missingInformation":["Compare with the defrost schedule."]},
          {"candidateID":"option-sensor-quality","status":"needsMoreEvidence","explanation":"There are too few readings to assess sensor quality.","supportingObservationIDs":[],"missingInformation":["Collect more readings."]},
          {"candidateID":"option-system-escalation","status":"needsMoreEvidence","explanation":"The evidence does not establish a mechanical issue.","supportingObservationIDs":[],"missingInformation":["Verify conditions with a qualified technician."]}
        ]}
        """
        let completionData = try JSONSerialization.data(withJSONObject: [
            "choices": [["message": ["content": responseContent]]]
        ])
        StubHTTPURLProtocol.responseData = completionData
        StubHTTPURLProtocol.responseStatus = 200
        StubHTTPURLProtocol.capturedRequest = nil
        StubHTTPURLProtocol.capturedBody = nil
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubHTTPURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let asset = Asset(id: "cooler-07", siteId: "site-1", name: "Cooler 7", assetType: .cooler)
        let now = Date()
        let reading = TemperatureReading(
            assetId: asset.id,
            originalValue: 4.0,
            originalUnit: .celsius,
            originalTimestamp: ISO8601DateFormatter().string(from: now),
            timestamp: now
        )
        let event = RecordedEvent(
            assetId: asset.id,
            originalTimestamp: ISO8601DateFormatter().string(from: now),
            timestamp: now,
            category: .doorOpen,
            note: "Door left open"
        )
        let engine = OpenAICompatibleDiagnosisEngine(session: session)
        let result = try await engine.analyze(
            asset: asset,
            readings: [reading],
            events: [event],
            context: ResourceContext(),
            profile: ExternalModelProfile(
                name: "Test provider",
                baseURL: "https://api.example.test/v1",
                modelID: "test-model"
            ),
            apiKey: "test-secret"
        )

        let request = try XCTUnwrap(StubHTTPURLProtocol.capturedRequest)
        let body = try XCTUnwrap(StubHTTPURLProtocol.capturedBody)
        let bodyText = String(decoding: body, as: UTF8.self)
        XCTAssertEqual(request.url?.path, "/v1/chat/completions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-secret")
        XCTAssertFalse(bodyText.contains("test-secret"))
        XCTAssertTrue(bodyText.contains("Door left open"))
        XCTAssertEqual(result.options.first { $0.id == "option-door-seal" }?.status, "possible")
    }

    func testCSVImporterValidatesAndDetectsDuplicates() {
        let importer = CSVImporter()
        let asset = Asset(id: "cooler-07", siteId: "site-1", name: "Cooler 7", assetType: .cooler)
        let csv = """
        timestamp,asset_id,temperature,unit,event
        2026-11-14T08:00:00Z,cooler-07,3.5,C,"door open, staff nearby"
        2026-11-14T08:00:00Z,cooler-07,3.5,C,duplicate row
        bad-date,cooler-07,4.0,C,invalid
        """
        let rows = importer.parse(csvText: csv, assets: [asset], existingReadings: [])
        XCTAssertEqual(rows.count, 3)
        XCTAssertTrue(rows[0].isValid)
        XCTAssertEqual(rows[0].event?.note, "door open, staff nearby")
        XCTAssertTrue(rows[1].isDuplicate)
        XCTAssertFalse(rows[2].isValid)
    }

    private final class StubHTTPURLProtocol: URLProtocol {
        static var responseData = Data()
        static var responseStatus = 200
        static var capturedRequest: URLRequest?
        static var capturedBody: Data?

        override class func canInit(with request: URLRequest) -> Bool {
            true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            Self.capturedRequest = request
            Self.capturedBody = request.httpBody ?? Self.readBodyStream(request.httpBodyStream)
            guard let response = HTTPURLResponse(
                url: request.url!,
                statusCode: Self.responseStatus,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Self.responseData)
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}

        private static func readBodyStream(_ stream: InputStream?) -> Data? {
            guard let stream else { return nil }
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            return data
        }
    }

    func testJSONExportSchemaVersion() throws {
        let exporter = ExportService()
        let engine = DiagnosisEngine()
        let asset = Asset(id: "cooler-07", siteId: "site-1", name: "Cooler 7", assetType: .cooler)
        let analysis = engine.prepare(asset: asset, readings: [], events: [], context: ResourceContext())
        let data = try exporter.encodeJSON(asset: asset, siteName: "Test Site", analysis: analysis, context: ResourceContext(), events: [])
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\"schema_version\" : \"1.0\""))
    }
}

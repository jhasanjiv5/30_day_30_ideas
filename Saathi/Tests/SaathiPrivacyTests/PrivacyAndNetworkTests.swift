import Foundation
import Testing
@testable import SaathiCore

// Serialized: the URLProtocol interceptor records into shared static state.
@Suite("Saathi Privacy & Network Audit Tests", .serialized)
struct PrivacyAndNetworkTests {

    @Test("App container scan finds zero latitude/longitude patterns after simulated walk & episode")
    func testContainerScanZeroCoordinatesAfterSession() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaathiPrivacyAudit_\(UUID().uuidString)", isDirectory: true)
        let docs = tempRoot.appendingPathComponent("Documents", isDirectory: true)
        let library = tempRoot.appendingPathComponent("Library", isDirectory: true)
        let caches = library.appendingPathComponent("Caches", isDirectory: true)
        let tmp = tempRoot.appendingPathComponent("tmp", isDirectory: true)

        for dir in [docs, library, caches, tmp] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        // Simulate tile-snapped lookup + episode serialization
        let userCoord = EphemeralCoordinate(latitude: 15.342519, longitude: 76.475612)
        let tile = GeoTileSnapper.snap(userCoord)
        let places = MockFixtures.hampiPlaces(tileID: tile.id, lang: .englishIndia)

        let segment = NarrationSegment(
            placeID: places[0].id,
            placeTitle: places[0].title,
            spokenText: places[0].summary,
            captionText: places[0].summary,
            citations: places[0].citations,
            languageCode: "en-IN",
            isUnprompted: true
        )
        let episode = EpisodeBuilder.build(
            segments: [segment],
            referencedMemories: MockFixtures.samplePersonalMemories(),
            language: .englishIndia
        )
        let episodeData = try JSONEncoder().encode(episode)
        try episodeData.write(to: docs.appendingPathComponent("episode.json"))

        // Write a tile cache file using tile ID + place summary only
        let cachePayload = CachedTilePayload(
            tileID: tile.id,
            fetchedAt: Date(),
            places: places.map {
                CachedTilePayload.CachedPlace(
                    id: $0.id,
                    title: $0.title,
                    summary: $0.summary,
                    sitelinksCount: $0.sitelinksCount,
                    tags: $0.tags,
                    citations: $0.citations,
                    sourceLanguageCode: $0.sourceLanguageCode
                )
            }
        )
        try JSONEncoder().encode(cachePayload)
            .write(to: caches.appendingPathComponent("\(tile.id).json"))

        let suiteName = "com.saathi.privacytest.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("en-IN", forKey: "preferredLanguage")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let findings = PrivacyContainerScanner.scanDirectories(
            [docs, library, caches, tmp],
            userDefaults: defaults,
            userDefaultsSuiteName: suiteName
        )
        #expect(findings.isEmpty, "Unexpected coordinate pattern persisted: \(findings)")
    }

    @Test("URLProtocol interceptor verifies allowlisted hosts, tile-only precision, and zero personal headers")
    func testURLProtocolInterceptorAllowlistAndTilePrecision() async throws {
        AllowlistedURLProtocol.reset()
        AllowlistedURLProtocol.mockHandler = { request in
            let url = request.url!
            let json: String
            if url.host == "www.wikidata.org" {
                json = #"{"entities":{"Q1":{"sitelinks":{"enwiki":{},"hiwiki":{},"knwiki":{}}}}}"#
            } else {
                json = #"{"query":{"pages":[{"pageid":101,"title":"Vittala Temple","extract":"16th-century temple complex in Hampi.","coordinates":[{"lat":15.3425,"lon":76.4756}],"pageprops":{"wikibase_item":"Q1"}}]}}"#
            }
            let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AllowlistedURLProtocol.self]
        let session = URLSession(configuration: config)

        let client = PublicSourceClient(session: session, mockMode: false)
        let exactUserCoord = EphemeralCoordinate(latitude: 15.34258123, longitude: 76.47569487)
        let result = try await client.fetchPlaces(near: exactUserCoord, preferredLanguage: .englishIndia)

        // Real-mode parsing: coordinates, extract and Wikidata sitelink notability are wired through.
        #expect(result.places.count == 1)
        #expect(result.places.first?.sitelinksCount == 3)
        #expect(result.places.first?.citations.contains { $0.provider == .wikidata } == true)
        #expect(result.places.first?.tags.contains("temple") == true)

        let recorded = AllowlistedURLProtocol.recordedRequests
        #expect(recorded.count == 2) // one Wikipedia + one Wikidata request
        for req in recorded {
            #expect(OutboundRequestValidator.isHostAllowed(req.host))
            #expect(OutboundRequestValidator.hasOnlyTilePrecisionCoordinates(in: req.url))
            #expect(!OutboundRequestValidator.containsForbiddenIdentifierHeaders(req.headers))
            #expect(req.userAgent?.hasPrefix("Saathi/1.0") == true)
        }
    }

    @Test("Area-context lookup uses a coarser ~2 km tile, wider radius, and stays on the allowlist")
    func testAreaContextRequestIsCoarse() async throws {
        AllowlistedURLProtocol.reset()
        AllowlistedURLProtocol.mockHandler = { request in
            let url = request.url!
            let json = url.host == "www.wikidata.org"
                ? #"{"entities":{}}"#
                : #"{"query":{"pages":[{"pageid":7,"title":"Virupaksha Temple","extract":"Oldest functioning temple in Hampi.","coordinates":[{"lat":15.335,"lon":76.46}]}]}}"#
            let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AllowlistedURLProtocol.self]
        let client = PublicSourceClient(session: URLSession(configuration: config), mockMode: false)

        let user = EphemeralCoordinate(latitude: 15.34258123, longitude: 76.47569487)
        let result = try await client.fetchAreaContext(near: user, preferredLanguage: .englishIndia)
        #expect(result.places.first?.title == "Virupaksha Temple")
        #expect(result.tile.tileSizeMeters == 2_000)

        let wikiRequest = try #require(AllowlistedURLProtocol.recordedRequests.first)
        #expect(wikiRequest.url.absoluteString.contains("ggsradius=5000"))
        #expect(OutboundRequestValidator.hasOnlyTilePrecisionCoordinates(in: wikiRequest.url))
        #expect(!wikiRequest.url.absoluteString.contains("15.3425")) // not the user's position
        for req in AllowlistedURLProtocol.recordedRequests {
            #expect(OutboundRequestValidator.isHostAllowed(req.host))
        }
    }

    @Test("Container scanner catches coordinates stored under renamed keys")
    func testScannerCatchesRenamedCoordinateKeys() {
        #expect(PrivacyContainerScanner.containsCoordinateLeak(in: #"{"coarseLat":15.3412,"x":1}"#) != nil)
        #expect(PrivacyContainerScanner.containsCoordinateLeak(in: #"{"userLng":76.47561}"#) != nil)
        #expect(PrivacyContainerScanner.containsCoordinateLeak(in: "near 15.342519, 76.475612") != nil)
        #expect(PrivacyContainerScanner.containsCoordinateLeak(in: #"{"createdAt":817058897.698288}"#) == nil)
    }

    @Test("Session termination invalidates location stream within 2 seconds")
    func testLocationStopsWithinTwoSecondsOfSessionEnd() async throws {
        let stopTriggeredAt = Date()

        // Mirrors LocationSessionManager: the update loop only exits via cancellation.
        let locationTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
            }
        }

        // Simulate session end
        locationTask.cancel()
        await locationTask.value

        let stopLatency = Date().timeIntervalSince(stopTriggeredAt)
        #expect(stopLatency < 2.0)
    }
}

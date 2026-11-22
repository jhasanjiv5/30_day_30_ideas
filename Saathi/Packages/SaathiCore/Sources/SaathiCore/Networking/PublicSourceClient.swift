import Foundation

/// Shape of a tile cache entry. Saathi keeps the tile cache in memory only for the current
/// session (wiped at session end), so nothing about visited tiles persists on disk.
/// The type stays public so privacy tests can assert what a serialized entry would contain:
/// tile ID + public place content, never coordinates.
public struct CachedTilePayload: Sendable, Codable, Equatable {
    public struct CachedPlace: Sendable, Codable, Equatable {
        public let id: String
        public let title: String
        public let summary: String
        public let sitelinksCount: Int
        public let tags: [String]
        public let citations: [FactCitation]
        public let sourceLanguageCode: String

        public init(
            id: String,
            title: String,
            summary: String,
            sitelinksCount: Int,
            tags: [String],
            citations: [FactCitation],
            sourceLanguageCode: String
        ) {
            self.id = id
            self.title = title
            self.summary = summary
            self.sitelinksCount = sitelinksCount
            self.tags = tags
            self.citations = citations
            self.sourceLanguageCode = sourceLanguageCode
        }
    }

    public let tileID: String
    public let fetchedAt: Date
    public let places: [CachedPlace]

    public init(tileID: String, fetchedAt: Date, places: [CachedPlace]) {
        self.tileID = tileID
        self.fetchedAt = fetchedAt
        self.places = places
    }
}

public actor PublicSourceClient {
    private let session: URLSession
    private let userAgent: String
    private let mockMode: Bool
    /// Session-scoped, memory-only tile cache. Cleared by `resetSession()`.
    private var memoryTileCache: [String: [PlaceCandidate]] = [:]
    private var queriedTileIDs: [String] = []

    public init(
        session: URLSession = .shared,
        userAgent: String = "Saathi/1.0 (Privacy-First Historic Audio Guide)",
        mockMode: Bool = false
    ) {
        self.session = session
        self.userAgent = userAgent
        self.mockMode = mockMode
    }

    public func lookupCountAndTiles() -> (count: Int, tileIDs: [String]) {
        (queriedTileIDs.count, queriedTileIDs)
    }

    /// Wipes the in-memory tile cache and lookup log. Call at session start and end so
    /// a privacy receipt only counts its own session and no tile history outlives it.
    public func resetSession() {
        memoryTileCache.removeAll()
        queriedTileIDs.removeAll()
    }

    public func fetchPlaces(
        near coordinate: EphemeralCoordinate,
        preferredLanguage: SaathiLanguage,
        tileSizeMeters: Double = GeoTileSnapper.defaultTileSizeMeters
    ) async throws -> (tile: GeoTile, places: [PlaceCandidate]) {
        // Snap exact coordinate to ~250m tile centre BEFORE any cache or network lookup.
        let tile = GeoTileSnapper.snap(coordinate, tileSizeMeters: tileSizeMeters)
        let cacheKey = "\(tile.id)_\(preferredLanguage.baseLanguageCode)"

        if let cached = memoryTileCache[cacheKey] {
            return (tile, cached)
        }

        queriedTileIDs.append(tile.id)

        if mockMode {
            let mocked = MockFixtures.places(forTile: tile, language: preferredLanguage)
            memoryTileCache[cacheKey] = mocked
            return (tile, mocked)
        }

        // Prefer the article in the user's language; fall back to English when that
        // Wikipedia has no geotagged articles for this tile (common for smaller Indic wikis).
        var places = try await fetchWikipediaPlaces(tile: tile, languageCode: preferredLanguage.baseLanguageCode)
        if places.isEmpty && preferredLanguage.baseLanguageCode != "en" {
            places = try await fetchWikipediaPlaces(tile: tile, languageCode: "en")
        }

        memoryTileCache[cacheKey] = places
        return (tile, places)
    }

    /// Wider "around you" context for the quiet stretches between landmarks: notable places
    /// within a few kilometres (the neighbourhood, a fort on the hill, the river ghat).
    /// Uses a coarser ~2 km tile, so it reveals even less than the landmark lookup.
    public func fetchAreaContext(
        near coordinate: EphemeralCoordinate,
        preferredLanguage: SaathiLanguage,
        radiusMeters: Int = 5_000,
        tileSizeMeters: Double = 2_000
    ) async throws -> (tile: GeoTile, places: [PlaceCandidate]) {
        let tile = GeoTileSnapper.snap(coordinate, tileSizeMeters: tileSizeMeters)
        let cacheKey = "area_\(tile.id)_\(preferredLanguage.baseLanguageCode)"
        if let cached = memoryTileCache[cacheKey] {
            return (tile, cached)
        }
        queriedTileIDs.append(tile.id)

        if mockMode {
            let mocked = MockFixtures.areaPlaces(forTile: tile, language: preferredLanguage)
            memoryTileCache[cacheKey] = mocked
            return (tile, mocked)
        }

        let clampedRadius = min(10_000, max(1_000, radiusMeters)) // Wikipedia geosearch max is 10 km
        var places = try await fetchWikipediaPlaces(
            tile: tile,
            languageCode: preferredLanguage.baseLanguageCode,
            radiusMeters: clampedRadius,
            limit: 20
        )
        if places.isEmpty && preferredLanguage.baseLanguageCode != "en" {
            places = try await fetchWikipediaPlaces(tile: tile, languageCode: "en", radiusMeters: clampedRadius, limit: 20)
        }
        memoryTileCache[cacheKey] = places
        return (tile, places)
    }

    /// One Wikipedia request (geosearch generator + coordinates + intro extract + Wikidata ID),
    /// then one Wikidata request for sitelink counts, which drive the ranker's notability score.
    private func fetchWikipediaPlaces(
        tile: GeoTile,
        languageCode: String,
        radiusMeters: Int = 400,
        limit: Int = 10
    ) async throws -> [PlaceCandidate] {
        // Outbound query uses strictly the tile centre (never raw user GPS).
        let host = "\(languageCode).wikipedia.org"
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/w/api.php"
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "generator", value: "geosearch"),
            URLQueryItem(name: "ggscoord", value: String(format: "%.4f|%.4f", tile.centerLatitude, tile.centerLongitude)),
            URLQueryItem(name: "ggsradius", value: String(radiusMeters)),
            URLQueryItem(name: "ggslimit", value: String(limit)),
            URLQueryItem(name: "prop", value: "coordinates|extracts|pageprops"),
            URLQueryItem(name: "exintro", value: "1"),
            URLQueryItem(name: "explaintext", value: "1"),
            URLQueryItem(name: "exsentences", value: "5"),
            URLQueryItem(name: "exlimit", value: String(min(limit, 20))), // API cap for intro extracts
            URLQueryItem(name: "ppprop", value: "wikibase_item"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "formatversion", value: "2")
        ]
        guard let url = components.url else { return [] }

        let data = try await get(url)
        let pages = (try? JSONDecoder().decode(WikipediaGeneratorResponse.self, from: data))?.query?.pages ?? []

        let wikidataIDs = pages.compactMap { $0.pageprops?.wikibaseItem }
        let sitelinks = (try? await fetchSitelinkCounts(ids: wikidataIDs)) ?? [:]

        return pages.compactMap { page -> PlaceCandidate? in
            guard let coord = page.coordinates?.first else { return nil }
            let extract = (page.extract?.isEmpty == false) ? page.extract! : "Historic landmark: \(page.title)."
            var citations = [
                FactCitation(
                    provider: .wikipedia,
                    title: page.title,
                    urlString: "https://\(host)/wiki/\(page.title.replacingOccurrences(of: " ", with: "_"))",
                    languageCode: languageCode
                )
            ]
            let qid = page.pageprops?.wikibaseItem
            if let qid {
                citations.append(
                    FactCitation(
                        provider: .wikidata,
                        title: qid,
                        urlString: "https://www.wikidata.org/wiki/\(qid)",
                        languageCode: "mul"
                    )
                )
            }
            return PlaceCandidate(
                id: "wiki_\(languageCode)_\(page.pageid)",
                title: page.title,
                summary: extract,
                coordinate: EphemeralCoordinate(latitude: coord.lat, longitude: coord.lon),
                sitelinksCount: qid.flatMap { sitelinks[$0] } ?? 1,
                tags: Self.inferTags(title: page.title, extract: extract),
                citations: citations,
                tileID: tile.id,
                sourceLanguageCode: languageCode
            )
        }
    }

    private func fetchSitelinkCounts(ids: [String]) async throws -> [String: Int] {
        guard !ids.isEmpty else { return [:] }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.wikidata.org"
        components.path = "/w/api.php"
        components.queryItems = [
            URLQueryItem(name: "action", value: "wbgetentities"),
            URLQueryItem(name: "ids", value: ids.prefix(50).joined(separator: "|")),
            URLQueryItem(name: "props", value: "sitelinks"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components.url else { return [:] }
        let data = try await get(url)
        let decoded = try JSONDecoder().decode(WikidataEntitiesResponse.self, from: data)
        return decoded.entities.mapValues { $0.sitelinks?.count ?? 0 }
    }

    private func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: request)
        return data
    }

    /// Lightweight topic tags so the session interest profile ("more architecture") has
    /// something to learn from. Keyword-based on purpose: transparent and offline.
    static func inferTags(title: String, extract: String) -> [String] {
        let text = (title + " " + extract).lowercased()
        let vocabulary: [(tag: String, keywords: [String])] = [
            ("temple", ["temple", "mandir", "shrine", "gopuram"]),
            ("architecture", ["architecture", "carved", "pillar", "dome", "arch", "facade", "built"]),
            ("fort", ["fort", "citadel", "rampart", "palace"]),
            ("religion", ["mosque", "church", "cathedral", "basilica", "dargah", "gurdwara"]),
            ("market", ["market", "bazaar", "chowk", "street"]),
            ("ruins", ["ruins", "ruin", "archaeolog", "excavat"]),
            ("history", ["century", "dynasty", "empire", "ruler", "king", "emperor"])
        ]
        let tags = vocabulary.filter { entry in entry.keywords.contains { text.contains($0) } }.map(\.tag)
        return tags.isEmpty ? ["heritage"] : tags
    }
}

private struct WikipediaGeneratorResponse: Decodable {
    struct Query: Decodable {
        let pages: [Page]
    }
    struct Page: Decodable {
        struct Coordinate: Decodable {
            let lat: Double
            let lon: Double
        }
        struct PageProps: Decodable {
            let wikibaseItem: String?
            enum CodingKeys: String, CodingKey { case wikibaseItem = "wikibase_item" }
        }
        let pageid: Int
        let title: String
        let extract: String?
        let coordinates: [Coordinate]?
        let pageprops: PageProps?
    }
    let query: Query?
}

private struct WikidataEntitiesResponse: Decodable {
    struct Entity: Decodable {
        let sitelinks: [String: Sitelink]?
    }
    struct Sitelink: Decodable {}
    let entities: [String: Entity]
}

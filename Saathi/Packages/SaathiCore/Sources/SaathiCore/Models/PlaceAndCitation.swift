import Foundation

/// In-memory only coordinate pair. Intentionally does NOT conform to `Codable`
/// so it cannot be accidentally serialized to disk, UserDefaults, or iCloud.
public struct EphemeralCoordinate: Sendable, Equatable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Great-circle distance in meters using Haversine formula.
    public func distanceMeters(to other: EphemeralCoordinate) -> Double {
        let earthRadius = 6_371_000.0
        let dLat = (other.latitude - latitude) * .pi / 180.0
        let dLon = (other.longitude - longitude) * .pi / 180.0
        let lat1 = latitude * .pi / 180.0
        let lat2 = other.latitude * .pi / 180.0

        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }

    /// Bearing in degrees [0, 360) from this coordinate to another.
    public func bearingDegrees(to other: EphemeralCoordinate) -> Double {
        let lat1 = latitude * .pi / 180.0
        let lat2 = other.latitude * .pi / 180.0
        let dLon = (other.longitude - longitude) * .pi / 180.0
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radians = atan2(y, x)
        let degrees = radians * 180.0 / .pi
        return (degrees + 360.0).truncatingRemainder(dividingBy: 360.0)
    }
}

/// Coarse ~250m grid tile identifier and centre used for ALL outbound public API queries.
public struct GeoTile: Sendable, Hashable, Codable {
    public let latIndex: Int
    public let lonIndex: Int
    public let centerLatitude: Double
    public let centerLongitude: Double
    public let tileSizeMeters: Double

    public var id: String {
        "tile_\(latIndex)_\(lonIndex)_\(Int(tileSizeMeters))m"
    }

    public var boundingBox: (south: Double, west: Double, north: Double, east: Double) {
        let latStep = GeoTileSnapper.latitudeStepDegrees(tileSizeMeters: tileSizeMeters)
        let lonStep = GeoTileSnapper.longitudeStepDegrees(
            atLatitude: centerLatitude,
            tileSizeMeters: tileSizeMeters
        )
        return (
            south: centerLatitude - latStep / 2.0,
            west: centerLongitude - lonStep / 2.0,
            north: centerLatitude + latStep / 2.0,
            east: centerLongitude + lonStep / 2.0
        )
    }
}

/// Snaps precise in-memory coordinates onto a deterministic ~250m coarse grid.
public enum GeoTileSnapper {
    public static let defaultTileSizeMeters: Double = 250.0
    private static let metersPerDegreeLatitude: Double = 111_320.0

    public static func latitudeStepDegrees(tileSizeMeters: Double = defaultTileSizeMeters) -> Double {
        tileSizeMeters / metersPerDegreeLatitude
    }

    public static func longitudeStepDegrees(
        atLatitude latitude: Double,
        tileSizeMeters: Double = defaultTileSizeMeters
    ) -> Double {
        let cosLat = max(0.1, abs(cos(latitude * .pi / 180.0)))
        return tileSizeMeters / (metersPerDegreeLatitude * cosLat)
    }

    public static func snap(
        _ coordinate: EphemeralCoordinate,
        tileSizeMeters: Double = defaultTileSizeMeters
    ) -> GeoTile {
        let latStep = latitudeStepDegrees(tileSizeMeters: tileSizeMeters)
        let latIndex = Int(floor(coordinate.latitude / latStep))
        let centerLat = (Double(latIndex) + 0.5) * latStep

        let lonStep = longitudeStepDegrees(atLatitude: centerLat, tileSizeMeters: tileSizeMeters)
        let lonIndex = Int(floor(coordinate.longitude / lonStep))
        let centerLon = (Double(lonIndex) + 0.5) * lonStep

        // Round outbound tile centres to 4 decimal places (~11m of tile centre; never raw GPS)
        let roundedLat = (centerLat * 10_000).rounded() / 10_000
        let roundedLon = (centerLon * 10_000).rounded() / 10_000

        return GeoTile(
            latIndex: latIndex,
            lonIndex: lonIndex,
            centerLatitude: roundedLat,
            centerLongitude: roundedLon,
            tileSizeMeters: tileSizeMeters
        )
    }
}

public enum SourceProvider: String, Sendable, Codable, CaseIterable {
    case wikipedia = "Wikipedia"
    case wikidata = "Wikidata"
    case openStreetMap = "OpenStreetMap"
    case curatedRSS = "Curated Notice"
    case personalMemory = "On-Device Memory"

    public var licenceNotice: String {
        switch self {
        case .wikipedia:
            return "Text from Wikipedia (CC BY-SA 4.0)"
        case .wikidata:
            return "Structured metadata from Wikidata (CC0 1.0)"
        case .openStreetMap:
            return "Map & POI data © OpenStreetMap contributors (ODbL 1.0)"
        case .curatedRSS:
            return "Public heritage RSS feed"
        case .personalMemory:
            return "On-device opted-in personal context"
        }
    }
}

public struct FactCitation: Sendable, Codable, Hashable, Identifiable {
    public let id: UUID
    public let provider: SourceProvider
    public let title: String
    public let urlString: String?
    public let languageCode: String
    public let licence: String

    public init(
        id: UUID = UUID(),
        provider: SourceProvider,
        title: String,
        urlString: String?,
        languageCode: String,
        licence: String? = nil
    ) {
        self.id = id
        self.provider = provider
        self.title = title
        self.urlString = urlString
        self.languageCode = languageCode
        self.licence = licence ?? provider.licenceNotice
    }
}

/// Public heritage POI fetched for a tile. Coordinates are kept strictly transient in memory
/// when computing on-device distance/bearing and excluded from `Codable` persistence in episodes.
public struct PlaceCandidate: Sendable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let summary: String
    public let coordinate: EphemeralCoordinate
    public let sitelinksCount: Int
    public let tags: [String]
    public let citations: [FactCitation]
    public let tileID: String
    public let sourceLanguageCode: String

    public init(
        id: String,
        title: String,
        summary: String,
        coordinate: EphemeralCoordinate,
        sitelinksCount: Int,
        tags: [String],
        citations: [FactCitation],
        tileID: String,
        sourceLanguageCode: String
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.coordinate = coordinate
        self.sitelinksCount = sitelinksCount
        self.tags = tags
        self.citations = citations
        self.tileID = tileID
        self.sourceLanguageCode = sourceLanguageCode
    }
}

public struct PersonalMemoryItem: Sendable, Identifiable, Hashable {
    public enum Kind: String, Sendable, Codable {
        case photo
        case calendarEvent
        case journalingSuggestion
    }

    public let id: String
    public let kind: Kind
    public let title: String
    public let detail: String
    public let date: Date
    public let photoLocalIdentifier: String?
    public let approximateCoordinate: EphemeralCoordinate?

    public init(
        id: String,
        kind: Kind,
        title: String,
        detail: String,
        date: Date,
        photoLocalIdentifier: String? = nil,
        approximateCoordinate: EphemeralCoordinate? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.date = date
        self.photoLocalIdentifier = photoLocalIdentifier
        self.approximateCoordinate = approximateCoordinate
    }

    public static func == (lhs: PersonalMemoryItem, rhs: PersonalMemoryItem) -> Bool {
        lhs.id == rhs.id && lhs.kind == rhs.kind && lhs.title == rhs.title
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(kind)
    }
}

public struct CuratedNotice: Sendable, Codable, Identifiable, Equatable {
    public let id: String
    public let headline: String
    public let summary: String
    public let citation: FactCitation

    public init(id: String, headline: String, summary: String, citation: FactCitation) {
        self.id = id
        self.headline = headline
        self.summary = summary
        self.citation = citation
    }
}

public struct NarrationSegment: Sendable, Identifiable, Codable, Equatable {
    public let id: UUID
    public let placeID: String
    public let placeTitle: String
    public let spokenText: String
    public let captionText: String
    public let followUpPrompt: String?
    public let citations: [FactCitation]
    public let referencedMemoryIDs: [String]
    public let languageCode: String
    public let timestamp: Date
    public let isUnprompted: Bool

    public init(
        id: UUID = UUID(),
        placeID: String,
        placeTitle: String,
        spokenText: String,
        captionText: String,
        followUpPrompt: String? = nil,
        citations: [FactCitation],
        referencedMemoryIDs: [String] = [],
        languageCode: String,
        timestamp: Date = Date(),
        isUnprompted: Bool
    ) {
        self.id = id
        self.placeID = placeID
        self.placeTitle = placeTitle
        self.spokenText = spokenText
        self.captionText = captionText
        self.followUpPrompt = followUpPrompt
        self.citations = citations
        self.referencedMemoryIDs = referencedMemoryIDs
        self.languageCode = languageCode
        self.timestamp = timestamp
        self.isUnprompted = isUnprompted
    }
}

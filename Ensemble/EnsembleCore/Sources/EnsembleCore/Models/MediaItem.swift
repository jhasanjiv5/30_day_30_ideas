import Foundation

public enum StreamingAppID: String, Codable, Sendable, CaseIterable, Hashable, Identifiable {
    case ensemble = "ensemble"
    case appleTV = "apple-tv"
    case netflix = "netflix"
    case disneyPlus = "disney-plus"
    case primeVideo = "prime-video"
    case max = "max"
    case hulu = "hulu"
    case youtube = "youtube"
    case plex = "plex"
    case infuse = "infuse"
    case jellyfin = "jellyfin"
    case vimeo = "vimeo"
    case mubi = "mubi"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .ensemble: return "Ensemble"
        case .appleTV: return "Apple TV"
        case .netflix: return "Netflix"
        case .disneyPlus: return "Disney+"
        case .primeVideo: return "Prime Video"
        case .max: return "Max"
        case .hulu: return "Hulu"
        case .youtube: return "YouTube"
        case .plex: return "Plex"
        case .infuse: return "Infuse"
        case .jellyfin: return "Jellyfin"
        case .vimeo: return "Vimeo"
        case .mubi: return "MUBI"
        }
    }

    /// URL scheme declared in EnsembleTV/Info.plist under LSApplicationQueriesSchemes.
    public var urlScheme: String? {
        switch self {
        case .ensemble: return nil
        case .appleTV: return "videos"
        case .netflix: return "nflx"
        case .disneyPlus: return "disneyplus"
        case .primeVideo: return "aiv"
        case .max: return "max"
        case .hulu: return "hulu"
        case .youtube: return "youtube"
        case .plex: return "plex"
        case .infuse: return "infuse"
        case .jellyfin: return "jellyfin"
        case .vimeo: return "vimeo"
        case .mubi: return "mubi"
        }
    }

    public var accentHex: String {
        switch self {
        case .ensemble: return "#2563EB"
        case .appleTV: return "#1E293B"
        case .netflix: return "#DC2626"
        case .disneyPlus: return "#0284C7"
        case .primeVideo: return "#0EA5E9"
        case .max: return "#1D4ED8"
        case .hulu: return "#16A34A"
        case .youtube: return "#EF4444"
        case .plex: return "#D97706"
        case .infuse: return "#EA580C"
        case .jellyfin: return "#4F46E5"
        case .vimeo: return "#0891B2"
        case .mubi: return "#1E293B"
        }
    }
}

public struct MediaProviderLink: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let appID: StreamingAppID
    public let deepLinkURL: String
    public let universalLinkURL: String?

    public var id: String { "\(appID.rawValue)-\(deepLinkURL)" }

    public init(appID: StreamingAppID, deepLinkURL: String, universalLinkURL: String? = nil) {
        self.appID = appID
        self.deepLinkURL = deepLinkURL
        self.universalLinkURL = universalLinkURL
    }
}

public struct InstalledAppStatus: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let appID: StreamingAppID
    public let displayName: String
    public let urlScheme: String?
    public let isInstalled: Bool

    public var id: StreamingAppID { appID }

    public init(appID: StreamingAppID, displayName: String, urlScheme: String?, isInstalled: Bool) {
        self.appID = appID
        self.displayName = displayName
        self.urlScheme = urlScheme
        self.isInstalled = isInstalled
    }
}

public enum AgeRating: String, Codable, Sendable, CaseIterable, Comparable {
    case g = "G"
    case pg = "PG"
    case pg13 = "PG-13"
    case r = "R"

    public var severity: Int {
        switch self {
        case .g: return 0
        case .pg: return 1
        case .pg13: return 2
        case .r: return 3
        }
    }

    public static func < (lhs: AgeRating, rhs: AgeRating) -> Bool {
        lhs.severity < rhs.severity
    }

    /// Returns true if this content rating is appropriate for a participant with `isChild`.
    /// When a child is present, only G and PG are allowed.
    public static func maxAllowed(for participants: [RoomParticipant]) -> AgeRating {
        if participants.contains(where: { $0.isChild }) {
            return .pg
        }
        if participants.contains(where: { $0.isTeen }) {
            return .pg13
        }
        return .r
    }
}

public struct LicenseCredit: Codable, Sendable, Equatable, Hashable {
    public let holder: String
    public let licenseName: String
    public let licenseURL: String
    public let attribution: String

    public init(holder: String, licenseName: String, licenseURL: String, attribution: String) {
        self.holder = holder
        self.licenseName = licenseName
        self.licenseURL = licenseURL
        self.attribution = attribution
    }
}

public struct MediaItem: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let synopsis: String
    public let year: Int
    public let genres: [String]
    public let moodTags: [String]
    public let runtimeMinutes: Int
    public let ageRating: AgeRating
    public let streamURL: String?
    public let subtitleResource: String?
    public let posterKey: String
    public let license: LicenseCredit?
    public let providers: [MediaProviderLink]

    public var isPlayableInApp: Bool {
        streamURL != nil
    }

    public var isPlayable: Bool {
        streamURL != nil || !providers.isEmpty
    }

    public func preferredProvider(installedApps: Set<StreamingAppID>) -> MediaProviderLink? {
        if let installedMatch = providers.first(where: { installedApps.contains($0.appID) }) {
            return installedMatch
        }
        return providers.first
    }

    public init(
        id: String,
        title: String,
        synopsis: String,
        year: Int,
        genres: [String],
        moodTags: [String],
        runtimeMinutes: Int,
        ageRating: AgeRating,
        streamURL: String? = nil,
        subtitleResource: String? = nil,
        posterKey: String,
        license: LicenseCredit? = nil,
        providers: [MediaProviderLink] = []
    ) {
        self.id = id
        self.title = title
        self.synopsis = synopsis
        self.year = year
        self.genres = genres
        self.moodTags = moodTags
        self.runtimeMinutes = runtimeMinutes
        self.ageRating = ageRating
        self.streamURL = streamURL
        self.subtitleResource = subtitleResource
        self.posterKey = posterKey
        self.license = license
        self.providers = providers
    }
}

public enum CatalogueLoader {
    public static func loadBundledCatalogue() throws -> [MediaItem] {
        guard let url = Bundle.module.url(forResource: "catalogue", withExtension: "json") else {
            throw NSError(domain: "EnsembleCore", code: 101, userInfo: [
                NSLocalizedDescriptionKey: "Missing catalogue.json in EnsembleCore bundle."
            ])
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([MediaItem].self, from: data)
    }
}

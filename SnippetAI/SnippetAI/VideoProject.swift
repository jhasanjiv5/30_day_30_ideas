import AVFoundation
import Foundation

enum ColorFilter: String, CaseIterable, Identifiable, Codable {
    case clean
    case warm
    case monochrome

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clean: "Clean"
        case .warm: "Warm"
        case .monochrome: "Mono"
        }
    }
}

enum SocialPlatform: String, CaseIterable, Identifiable {
    case tiktok
    case instagram
    case youtube

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tiktok: "TikTok"
        case .instagram: "Instagram"
        case .youtube: "YouTube"
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .tiktok, .instagram: 9.0 / 16.0
        case .youtube: 16.0 / 9.0
        }
    }
}

struct VideoSegment: Identifiable, Codable, Equatable {
    var id = UUID()
    var startTime: Double
    var endTime: Double
    var caption: String
    var reason: String
    var isMuted = false

    var duration: Double { max(0, endTime - startTime) }

    var dictionaryRepresentation: [String: Any] {
        [
            "id": id.uuidString,
            "startTime": startTime,
            "endTime": endTime,
            "caption": caption,
            "reason": reason,
            "isMuted": isMuted
        ]
    }
}

struct VideoProject: Identifiable {
    var id: String
    var title: String
    var segments: [VideoSegment]
    var filter: ColorFilter
}

struct VideoSegmentDecision {
    var timeRange: CMTimeRange
    var keep: Bool
    var reason: String
    var caption: String
}

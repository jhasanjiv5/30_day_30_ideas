import Foundation

public struct ScheduledPost: Codable, Identifiable {
    public var id: String
    public var platform: String
    public var hook: String
    public var caption: String
    public var hashtags: [String]
    public var scheduledDate: String
    public var scheduledTime: String
    public var status: PostStatus
    public var privacyScore: Int
    public var pillar: String

    public enum PostStatus: String, Codable {
        case draft
        case scheduled
        case published
    }
}

import Foundation

public struct BusinessProfile: Codable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var name: String
    public var industry: String
    public var niche: String
    public var targetAudience: String
    public var usp: String
    public var brandVoice: String
    public var isHomeBased: Bool
    public var platforms: [String]

    public static let sample = BusinessProfile(
        name: "Hearth & Crumb Bakery",
        industry: "Food & Beverage",
        niche: "Artisanal Sourdough & Natural Pastries",
        targetAudience: "Local food lovers, health-conscious families",
        usp: "Slow-fermented wild yeast sourdough baked fresh every morning with organic heritage grains",
        brandVoice: "Friendly & Warm",
        isHomeBased: true,
        platforms: ["Instagram", "TikTok", "Pinterest"]
    )
}

import Foundation

public final class PostSchedulerStore: ObservableObject {
    @Published public var posts: [ScheduledPost] = []

    public init() {
        posts = [
            ScheduledPost(
                id: "p-1",
                platform: "Instagram",
                hook: "Why we ferment our sourdough for 36 hours.",
                caption: "Great bread takes patience. Blistering crust comes from natural wild yeast breakdown.",
                hashtags: ["#SourdoughBaker", "#RealBread", "#ArtisanBakery"],
                scheduledDate: "Tomorrow",
                scheduledTime: "10:15 AM",
                status: .scheduled,
                privacyScore: 100,
                pillar: "Behind The Scenes"
            )
        ]
    }
}

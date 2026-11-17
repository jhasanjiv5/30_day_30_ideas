import Foundation

public struct SceneTimelineSlice: Equatable, Sendable {
    public let scene: StoryboardScene
    public let startTimeSeconds: Double
    public let endTimeSeconds: Double

    public var durationSeconds: Double {
        endTimeSeconds - startTimeSeconds
    }
}

public enum CompositionPreviewBuilder {
    public static func timelineSlices(for project: VideoProject) -> [SceneTimelineSlice] {
        var cursor = 0.0
        return project.scenes.map { scene in
            let duration = max(0.5, scene.durationSeconds)
            let slice = SceneTimelineSlice(
                scene: scene,
                startTimeSeconds: cursor,
                endTimeSeconds: cursor + duration
            )
            cursor += duration
            return slice
        }
    }

    public static func activeScene(at timeSeconds: Double, in project: VideoProject) -> (slice: SceneTimelineSlice, localProgress: Double)? {
        let slices = timelineSlices(for: project)
        guard !slices.isEmpty else { return nil }
        let clamped = max(0, min(timeSeconds, project.totalDurationSeconds))
        guard let slice = slices.last(where: { clamped >= $0.startTimeSeconds && clamped <= $0.endTimeSeconds }) ?? slices.last else {
            return nil
        }
        let elapsed = max(0, clamped - slice.startTimeSeconds)
        let progress = min(1.0, elapsed / max(0.5, slice.durationSeconds))
        return (slice, progress)
    }
}

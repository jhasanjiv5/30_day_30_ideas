import Foundation

public struct VideoRenderProgress: Equatable, Sendable {
    public let fractionCompleted: Double
    public let statusMessage: String

    public init(fractionCompleted: Double, statusMessage: String) {
        self.fractionCompleted = min(max(fractionCompleted, 0), 1)
        self.statusMessage = statusMessage
    }
}

public protocol VideoRenderingEngine: Sendable {
    func render(
        project: VideoProject,
        storagePaths: LocalStoragePaths,
        outputURL: URL,
        progress: @escaping @Sendable (VideoRenderProgress) -> Void
    ) async throws -> RenderedVideoRecord
}

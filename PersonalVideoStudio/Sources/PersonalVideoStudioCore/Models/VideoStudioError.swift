import Foundation

public enum VideoStudioError: LocalizedError, Equatable, Sendable {
    case projectNotFound(id: UUID)
    case invalidProject(reason: String)
    case invalidScene(reason: String)
    case invalidAudioTrack(reason: String)
    case invalidExportConfiguration(reason: String)
    case mediaImportFailed(reason: String)
    case mediaFileMissing(fileName: String)
    case insufficientDiskSpace(requiredMB: Int64, availableMB: Int64)
    case invalidModelDirectory(reason: String)
    case aiGenerationUnavailable(reason: String)
    case exportCancelled
    case exportFailed(reason: String)
    case storageFailure(reason: String)

    public var errorDescription: String? {
        switch self {
        case .projectNotFound(let id):
            return "Could not find local video project (\(id.uuidString))."
        case .invalidProject(let reason),
             .invalidScene(let reason),
             .invalidAudioTrack(let reason),
             .invalidExportConfiguration(let reason):
            return reason
        case .mediaImportFailed(let reason):
            return "Media import failed: \(reason)"
        case .mediaFileMissing(let fileName):
            return "Referenced local media file '\(fileName)' could not be found in project storage."
        case .insufficientDiskSpace(let requiredMB, let availableMB):
            return "Not enough free disk space. Need about \(requiredMB) MB, only \(availableMB) MB available."
        case .invalidModelDirectory(let reason):
            return reason
        case .aiGenerationUnavailable(let reason):
            return reason
        case .exportCancelled:
            return "Video export was cancelled."
        case .exportFailed(let reason):
            return "Video export failed: \(reason)"
        case .storageFailure(let reason):
            return "Local storage error: \(reason)"
        }
    }
}

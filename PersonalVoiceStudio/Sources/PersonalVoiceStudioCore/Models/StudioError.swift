import Foundation

public enum StudioError: LocalizedError, Equatable, Sendable {
    case consentRequired
    case microphonePermissionDenied
    case microphonePermissionRestricted
    case recordingAlreadyInProgress
    case recordingFailedToStart(reason: String)
    case recordingInterrupted(reason: String)
    case audioFileCorruptedOrMissing
    case playbackFailed(reason: String)
    case insufficientDiskSpace(requiredMB: Int, availableMB: Int)
    case invalidModelDirectory(reason: String)
    case modelUnavailable(reason: String)
    case synthesisFailed(reason: String)
    case emptyInputText
    case missingReferenceRecording
    case exportFailed(reason: String)
    case persistenceFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .consentRequired:
            return "Confirm that you are recording your own voice before starting setup."
        case .microphonePermissionDenied:
            return "Microphone access was denied. Open System Settings > Privacy & Security > Microphone to allow Personal Voice Studio."
        case .microphonePermissionRestricted:
            return "Microphone access is restricted by system policy on this Mac."
        case .recordingAlreadyInProgress:
            return "A recording is already in progress. Stop the current recording first."
        case .recordingFailedToStart(let reason):
            return "Could not start microphone recording: \(reason)"
        case .recordingInterrupted(let reason):
            return "Recording was interrupted (\(reason)). Check your audio input device and try again."
        case .audioFileCorruptedOrMissing:
            return "The recorded audio file could not be read or is missing."
        case .playbackFailed(let reason):
            return "Could not play audio clip: \(reason)"
        case .insufficientDiskSpace(let requiredMB, let availableMB):
            return "Not enough free disk space. At least \(requiredMB) MB is needed, but only \(availableMB) MB is available."
        case .invalidModelDirectory(let reason):
            return "The selected model folder cannot be used: \(reason)"
        case .modelUnavailable(let reason):
            return reason
        case .synthesisFailed(let reason):
            return "On-device speech generation failed: \(reason)"
        case .emptyInputText:
            return "Enter or paste some text before generating audio."
        case .missingReferenceRecording:
            return "Record at least one clear voice prompt in Voice Setup before generating speech."
        case .exportFailed(let reason):
            return "Could not export audio: \(reason)"
        case .persistenceFailed(let reason):
            return "Could not update local profile storage: \(reason)"
        }
    }
}

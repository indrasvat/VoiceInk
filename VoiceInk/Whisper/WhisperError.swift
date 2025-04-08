import Foundation

enum WhisperStateError: Error, Identifiable {
    case modelLoadFailed
    case transcriptionFailed
    case recordingFailed
    case accessibilityPermissionDenied
    case modelDownloadFailed
    case modelDeletionFailed
    case unzipFailed
    case unknownError
    
    var id: String { UUID().uuidString }
}

extension WhisperStateError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .modelLoadFailed:
            return "Failed to load the transcription model."
        case .transcriptionFailed:
            return "Failed to transcribe the audio."
        case .recordingFailed:
            return "Failed to start or stop recording."
        case .accessibilityPermissionDenied:
            return "Accessibility permission is required for automatic pasting."
        case .modelDownloadFailed:
            return "Failed to download the model."
        case .modelDeletionFailed:
            return "Failed to delete the model."
        case .unzipFailed:
            return "Failed to unzip the downloaded Core ML model."
        case .unknownError:
            return "An unknown error occurred."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .modelLoadFailed:
            return "Try selecting a different model or redownloading the current model."
        case .transcriptionFailed:
            return "Check your audio input and try again. If the problem persists, try a different model."
        case .recordingFailed:
            return "Check your microphone permissions and try again."
        case .accessibilityPermissionDenied:
            return "Go to System Preferences > Security & Privacy > Privacy > Accessibility and allow VoiceInk."
        case .modelDownloadFailed:
            return "Check your internet connection and try again. If the problem persists, try a different model."
        case .modelDeletionFailed:
            return "Restart the application and try again. If the problem persists, you may need to manually delete the model file."
        case .unzipFailed:
            return "The downloaded Core ML model archive might be corrupted. Try deleting the model and downloading it again. Check available disk space."
        case .unknownError:
            return "Please restart the application. If the problem persists, contact support."
        }
    }
} 
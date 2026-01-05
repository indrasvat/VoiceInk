import Foundation
import Speech
import AVFoundation
import os
import Combine

/// Protocol for receiving streaming transcription updates
protocol StreamingTranscriptionDelegate: AnyObject {
    func streamingTranscription(didReceivePartialResult text: String)
    func streamingTranscription(didReceiveFinalResult text: String)
    func streamingTranscription(didFailWithError error: Error)
}

/// Generic protocol for any streaming transcription service
/// Implemented by Apple (SFSpeechRecognizer) and Parakeet streaming services
@MainActor
protocol GenericStreamingTranscriptionService: AnyObject {
    /// Whether streaming is currently active
    var isStreaming: Bool { get }

    /// Delegate for receiving transcription updates
    var delegate: StreamingTranscriptionDelegate? { get set }

    /// Start streaming transcription
    /// - Parameter locale: Language code for recognition (e.g., "en", "en-US")
    /// NOTE: This is async to ensure streaming infrastructure is fully ready before returning
    func startStreaming(locale: String) async throws

    /// Append audio buffer to the streaming recognizer
    /// - Parameter buffer: Audio buffer from the recorder
    /// NOTE: Called from background audio queue - implementations must handle actor isolation
    nonisolated func appendAudioBuffer(_ buffer: AVAudioPCMBuffer)

    /// Stop streaming and return final result
    /// - Returns: The final transcribed text
    @discardableResult
    func stopStreaming() async -> String

    /// Request authorization for this streaming service
    /// - Returns: True if authorized, false otherwise
    func requestAuthorization() async -> Bool
}

/// Service for real-time streaming transcription using Apple's SFSpeechRecognizer
@MainActor
class AppleStreamingTranscriptionService: ObservableObject, GenericStreamingTranscriptionService {

    // MARK: - Published Properties

    @Published private(set) var partialResult: String = ""
    @Published private(set) var isStreaming: Bool = false
    @Published private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published private(set) var isOnDeviceAvailable: Bool = false

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "StreamingTranscriptionService")

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var finalResult: String = ""
    private var currentLocale: Locale = Locale(identifier: "en-US")

    weak var delegate: StreamingTranscriptionDelegate?

    // MARK: - Initialization

    init() {
        updateAuthorizationStatus()
    }

    // MARK: - Authorization

    /// Request speech recognition authorization (Apple-specific return type)
    func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    self.logger.info("Speech recognition authorization: \(String(describing: status))")
                    continuation.resume(returning: status)
                }
            }
        }
    }

    /// Request authorization (protocol conformance)
    func requestAuthorization() async -> Bool {
        let status = await requestSpeechAuthorization()
        return status == .authorized
    }

    /// Update the current authorization status
    func updateAuthorizationStatus() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    // MARK: - Streaming Control

    /// Start streaming transcription with the specified locale
    /// - Parameter locale: The locale to use for recognition (e.g., "en-US", "hi-IN")
    func startStreaming(locale: String = "en-US") async throws {
        guard authorizationStatus == .authorized else {
            logger.error("Speech recognition not authorized")
            throw StreamingTranscriptionError.notAuthorized
        }

        // Stop any existing session (sync cleanup)
        cleanupSession()

        // Map VoiceInk language code to Apple locale identifier
        let appleLocale = mapToAppleLocale(languageCode: locale)
        currentLocale = Locale(identifier: appleLocale)

        // Create speech recognizer for the locale
        guard let recognizer = SFSpeechRecognizer(locale: currentLocale) else {
            logger.error("Could not create speech recognizer for locale: \(appleLocale)")
            throw StreamingTranscriptionError.recognizerUnavailable
        }

        guard recognizer.isAvailable else {
            logger.error("Speech recognizer not available for locale: \(appleLocale)")
            throw StreamingTranscriptionError.recognizerUnavailable
        }

        speechRecognizer = recognizer
        isOnDeviceAvailable = recognizer.supportsOnDeviceRecognition

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        // Prefer on-device recognition for privacy and speed
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
            logger.info("Using on-device recognition for locale: \(appleLocale)")
        } else {
            logger.info("Using server-based recognition for locale: \(appleLocale)")
        }

        recognitionRequest = request

        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result: result, error: error)
            }
        }

        partialResult = ""
        finalResult = ""
        isStreaming = true

        logger.info("Started streaming transcription for locale: \(appleLocale)")
    }

    /// Append an audio buffer to the streaming recognizer
    /// - Parameter buffer: The audio buffer to append
    /// NOTE: This is called from a background audio processing queue, so we must
    /// properly hop to MainActor before accessing actor-isolated state
    nonisolated func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard self.isStreaming, let request = self.recognitionRequest else { return }
            request.append(buffer)
        }
    }

    /// Stop streaming and return the final transcription result
    /// - Returns: The final transcribed text
    @discardableResult
    func stopStreaming() async -> String {
        guard isStreaming else { return finalResult }

        cleanupSession()

        // Return the best result we have
        let result = finalResult.isEmpty ? partialResult : finalResult
        logger.info("Stopped streaming, final result: \(result.prefix(100))...")

        return result
    }

    /// Internal cleanup method used by both startStreaming and stopStreaming
    private func cleanupSession() {
        // End audio input
        recognitionRequest?.endAudio()

        // Cancel the task (this will trigger a final result or cancellation)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        speechRecognizer = nil

        isStreaming = false
    }

    // MARK: - Private Methods

    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result = result {
            let text = result.bestTranscription.formattedString

            if result.isFinal {
                finalResult = text
                partialResult = text
                delegate?.streamingTranscription(didReceiveFinalResult: text)
                logger.debug("Final result: \(text.prefix(100))...")
            } else {
                partialResult = text
                delegate?.streamingTranscription(didReceivePartialResult: text)
            }
        }

        if let error = error as NSError? {
            // Ignore cancellation errors (code 216 in kAFAssistantErrorDomain)
            if error.domain == "kAFAssistantErrorDomain" && error.code == 216 {
                return
            }
            // Ignore error 1110 (no speech detected)
            if error.domain == "kAFAssistantErrorDomain" && error.code == 1110 {
                logger.debug("No speech detected")
                return
            }

            logger.error("Recognition error: \(error.localizedDescription)")
            delegate?.streamingTranscription(didFailWithError: error)
        }
    }

    /// Map VoiceInk language codes to Apple locale identifiers
    private func mapToAppleLocale(languageCode: String) -> String {
        // If already a full locale (e.g., "en-US"), use as-is
        if languageCode.contains("-") {
            return languageCode
        }

        // Map simple language codes to Apple locales
        let localeMap: [String: String] = [
            "en": "en-US",
            "hi": "hi-IN",
            "es": "es-ES",
            "fr": "fr-FR",
            "de": "de-DE",
            "it": "it-IT",
            "ja": "ja-JP",
            "ko": "ko-KR",
            "pt": "pt-BR",
            "ru": "ru-RU",
            "zh": "zh-CN",
            "ar": "ar-SA",
            "nl": "nl-NL",
            "pl": "pl-PL",
            "sv": "sv-SE",
            "tr": "tr-TR",
            "th": "th-TH",
            "vi": "vi-VN",
            "uk": "uk-UA",
            "cs": "cs-CZ",
            "da": "da-DK",
            "fi": "fi-FI",
            "el": "el-GR",
            "he": "he-IL",
            "hu": "hu-HU",
            "id": "id-ID",
            "ms": "ms-MY",
            "nb": "nb-NO",
            "ro": "ro-RO",
            "sk": "sk-SK",
            "yue": "yue-CN",
            "ca": "ca-ES",
            "hr": "hr-HR",
            "auto": "en-US"  // Default to English for auto-detect
        ]

        return localeMap[languageCode] ?? "en-US"
    }
}

// MARK: - Error Types

enum StreamingTranscriptionError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case audioEngineError(Error)
    case recognitionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition is not authorized. Please enable it in System Settings > Privacy & Security > Speech Recognition."
        case .recognizerUnavailable:
            return "Speech recognizer is not available for the selected language."
        case .audioEngineError(let error):
            return "Audio engine error: \(error.localizedDescription)"
        case .recognitionFailed(let error):
            return "Recognition failed: \(error.localizedDescription)"
        }
    }
}

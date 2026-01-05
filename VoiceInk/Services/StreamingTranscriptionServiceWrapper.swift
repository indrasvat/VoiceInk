import Foundation
import AVFoundation
import os

/// Wrapper to provide TranscriptionService protocol conformance for StreamingTranscriptionService
/// This allows the streaming service to be used with the existing transcription architecture
/// when falling back to file-based transcription (e.g., for audio file imports)
class StreamingTranscriptionServiceWrapper: TranscriptionService {

    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "StreamingTranscriptionServiceWrapper")

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        guard model.provider == .streaming else {
            throw StreamingTranscriptionError.recognizerUnavailable
        }

        logger.notice("Streaming model selected for file-based transcription - using SFSpeechRecognizer")

        // For file-based transcription, use SFSpeechURLRecognitionRequest
        let recognizer = await MainActor.run {
            let selectedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "en"
            let locale = mapToAppleLocale(languageCode: selectedLanguage)
            return SFSpeechRecognizer(locale: Locale(identifier: locale))
        }

        guard let speechRecognizer = recognizer, speechRecognizer.isAvailable else {
            logger.error("Speech recognizer not available for file transcription")
            throw StreamingTranscriptionError.recognizerUnavailable
        }

        // Use URL-based recognition for file transcription
        let request = SFSpeechURLRecognitionRequest(url: audioURL)

        // Prefer on-device recognition
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            speechRecognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    self.logger.error("File transcription error: \(error.localizedDescription)")
                    continuation.resume(throwing: StreamingTranscriptionError.recognitionFailed(error))
                    return
                }

                if let result = result, result.isFinal {
                    let text = result.bestTranscription.formattedString
                    self.logger.notice("File transcription completed: \(text.prefix(100))...")
                    continuation.resume(returning: text)
                }
            }
        }
    }

    /// Map VoiceInk language codes to Apple locale identifiers
    private func mapToAppleLocale(languageCode: String) -> String {
        if languageCode.contains("-") {
            return languageCode
        }

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
            "auto": "en-US"
        ]

        return localeMap[languageCode] ?? "en-US"
    }
}

import Speech

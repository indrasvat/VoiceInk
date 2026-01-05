import Foundation
import AVFoundation
import os

// MARK: - Streaming Transcription Extension
extension WhisperState: StreamingTranscriptionDelegate {

    /// Check if the current model should use streaming transcription
    /// Returns true if the model is streaming-only, or if it supports both and user has streaming enabled
    var isCurrentModelStreaming: Bool {
        guard let model = currentTranscriptionModel else { return false }
        switch model.streamingCapability {
        case .streamingOnly:
            return true
        case .batchAndStreaming:
            // Default to true (streaming) for fastest experience
            let key = "StreamingMode_\(model.name)"
            if UserDefaults.standard.object(forKey: key) == nil {
                return true  // Default: streaming enabled
            }
            return UserDefaults.standard.bool(forKey: key)
        case .batchOnly:
            return false
        }
    }

    /// The appropriate streaming service for the current model
    var currentStreamingService: (any GenericStreamingTranscriptionService)? {
        guard let model = currentTranscriptionModel else { return nil }
        switch model.provider {
        case .streaming:
            return serviceRegistry.appleStreamingService
        case .parakeet:
            return serviceRegistry.parakeetStreamingService
        default:
            return nil
        }
    }

    /// The Apple streaming transcription service from the registry (for backward compatibility)
    var streamingService: AppleStreamingTranscriptionService {
        serviceRegistry.appleStreamingService
    }

    // MARK: - Streaming Lifecycle

    /// Set up streaming if the current model requires it
    func setupStreamingIfNeeded() async -> Bool {
        guard isCurrentModelStreaming else { return true }
        guard let service = currentStreamingService else { return true }

        // Check authorization status
        let isAuthorized = await service.requestAuthorization()

        guard isAuthorized else {
            logger.error("Streaming transcription not authorized")
            await MainActor.run {
                NotificationManager.shared.showNotification(
                    title: "Speech Recognition Not Authorized",
                    type: .error
                )
            }
            return false
        }

        // Pre-load Parakeet streaming if needed for faster startup
        if let parakeetService = service as? ParakeetStreamingTranscriptionService,
           let model = currentTranscriptionModel as? ParakeetModel {
            do {
                parakeetService.setVersion(model.name.lowercased().contains("v2") ? .v2 : .v3)
                try await parakeetService.prepareForStreaming()
            } catch {
                logger.error("Failed to prepare Parakeet streaming: \(error.localizedDescription)")
            }
        }

        return true
    }

    /// Start streaming transcription alongside recording
    /// NOTE: This is async to ensure the streaming service is fully ready before recording starts
    func startStreamingRecognition() async {
        guard isCurrentModelStreaming else { return }
        guard let service = currentStreamingService else { return }

        // Get the selected language
        let selectedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "en"

        do {
            // Set up delegate for callbacks
            service.delegate = self

            // CRITICAL: Set callback FIRST before starting streaming
            // This ensures no audio buffers are dropped during initialization
            recorder.onAudioBufferForStreaming = { [weak service] buffer in
                service?.appendAudioBuffer(buffer)
            }

            // Start the streaming service - AWAIT to ensure manager is ready
            // This is the critical fix: we must wait for the manager to exist
            // before audio recording starts, otherwise buffers are dropped
            try await service.startStreaming(locale: selectedLanguage)

            logger.info("Started streaming recognition for language: \(selectedLanguage)")
        } catch {
            // Clear callback on error
            recorder.onAudioBufferForStreaming = nil
            logger.error("Failed to start streaming recognition: \(error.localizedDescription)")
            NotificationManager.shared.showNotification(
                title: "Streaming Failed: \(error.localizedDescription)",
                type: .error
            )
        }
    }

    /// Stop streaming and return the final result
    func stopStreamingRecognition() async -> String {
        guard isCurrentModelStreaming else { return "" }
        guard let service = currentStreamingService else { return "" }

        // Stop streaming and get final result FIRST (wait for all audio to be processed)
        let result = await service.stopStreaming()

        // THEN disconnect audio callback (after finalization completes)
        recorder.onAudioBufferForStreaming = nil

        logger.info("Stopped streaming recognition, result: \(result.prefix(100))...")

        return result
    }

    // MARK: - Streaming Result Processing

    /// Process streaming transcription result (bypasses batch transcription)
    func processStreamingResult(_ text: String, on transcription: Transcription) async {
        await MainActor.run {
            recordingState = .transcribing
        }

        // Play stop sound
        Task {
            let isSystemMuteEnabled = UserDefaults.standard.bool(forKey: "isSystemMuteEnabled")
            if isSystemMuteEnabled {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            await MainActor.run {
                SoundManager.shared.playStopSound()
            }
        }

        logger.notice("🔄 Processing streaming result...")

        var processedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var finalPastedText: String = processedText

        // Apply text formatting if enabled
        if UserDefaults.standard.object(forKey: "IsTextFormattingEnabled") as? Bool ?? true {
            processedText = WhisperTextFormatter.format(processedText)
            logger.notice("📝 Formatted streaming result: \(processedText, privacy: .public)")
        }

        // Apply word replacements
        processedText = WordReplacementService.shared.applyReplacements(to: processedText, using: modelContext)
        logger.notice("📝 WordReplacement: \(processedText, privacy: .public)")
        finalPastedText = processedText

        // Get power mode info
        let powerModeManager = PowerModeManager.shared
        let activePowerModeConfig = powerModeManager.currentActiveConfiguration
        let powerModeName = (activePowerModeConfig?.isEnabled == true) ? activePowerModeConfig?.name : nil
        let powerModeEmoji = (activePowerModeConfig?.isEnabled == true) ? activePowerModeConfig?.emoji : nil

        // Update transcription
        transcription.text = processedText
        transcription.transcriptionModelName = currentTranscriptionModel?.displayName
        transcription.transcriptionDuration = 0  // Streaming is instant
        transcription.powerModeName = powerModeName
        transcription.powerModeEmoji = powerModeEmoji

        // Handle AI enhancement if enabled
        if let enhancementService = enhancementService,
           enhancementService.isEnhancementEnabled,
           enhancementService.isConfigured {

            if shouldCancelRecording {
                await cleanupModelResources()
                return
            }

            await MainActor.run { recordingState = .enhancing }

            do {
                let (enhancedText, enhancementDuration, promptName) = try await enhancementService.enhance(processedText)
                logger.notice("📝 AI enhancement: \(enhancedText, privacy: .public)")
                transcription.enhancedText = enhancedText
                transcription.aiEnhancementModelName = enhancementService.getAIService()?.currentModel
                transcription.promptName = promptName
                transcription.enhancementDuration = enhancementDuration
                transcription.aiRequestSystemMessage = enhancementService.lastSystemMessageSent
                transcription.aiRequestUserMessage = enhancementService.lastUserMessageSent
                finalPastedText = enhancedText
            } catch {
                transcription.enhancedText = "Enhancement failed: \(error)"
                logger.error("AI enhancement failed: \(error.localizedDescription)")
            }
        }

        transcription.transcriptionStatus = TranscriptionStatus.completed.rawValue
        try? modelContext.save()

        NotificationCenter.default.post(name: .transcriptionCompleted, object: transcription)

        // Paste the result
        if var textToPaste = Optional(finalPastedText) {
            if case .trialExpired = licenseViewModel.licenseState {
                textToPaste = """
                    Your trial has expired. Upgrade to VoiceInk Pro at tryvoiceink.com/buy
                    \n\(textToPaste)
                    """
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                CursorPaster.pasteAtCursor(textToPaste + " ")

                let powerMode = PowerModeManager.shared
                if let activeConfig = powerMode.currentActiveConfiguration, activeConfig.isAutoSendEnabled {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        CursorPaster.pressEnter()
                    }
                }
            }
        }

        await dismissMiniRecorder()
        shouldCancelRecording = false
    }

    // MARK: - StreamingTranscriptionDelegate

    nonisolated func streamingTranscription(didReceivePartialResult text: String) {
        Task { @MainActor in
            // Update UI with partial result if needed
            // This could be displayed in the mini recorder
            logger.debug("Streaming partial: \(text.prefix(50))...")
        }
    }

    nonisolated func streamingTranscription(didReceiveFinalResult text: String) {
        Task { @MainActor in
            logger.info("Streaming final: \(text.prefix(100))...")
        }
    }

    nonisolated func streamingTranscription(didFailWithError error: Error) {
        Task { @MainActor in
            logger.error("Streaming error: \(error.localizedDescription)")
            NotificationManager.shared.showNotification(
                title: "Streaming Error",
                type: .error
            )
        }
    }
}

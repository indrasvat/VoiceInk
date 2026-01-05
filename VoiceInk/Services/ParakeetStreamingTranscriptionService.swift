import Foundation
import AVFoundation
import FluidAudio
import os

/// Service for real-time streaming transcription using Parakeet via FluidAudio
/// Achieves near-instant transcription by processing audio chunks as they arrive
///
/// CRITICAL ARCHITECTURE NOTE:
/// Audio buffers arrive from a background audio processing queue (~85ms intervals at 48kHz/4096 samples).
/// We MUST NOT hop through MainActor for every buffer - that adds variable latency (1-50ms)
/// which breaks FluidAudio's LocalAgreement algorithm timing.
///
/// Instead, we use thread-safe references to call the StreamingAsrManager actor DIRECTLY.
/// The actor handles its own serialization internally.
@MainActor
class ParakeetStreamingTranscriptionService: ObservableObject, GenericStreamingTranscriptionService {

    // MARK: - Published Properties

    @Published private(set) var partialResult: String = ""
    @Published private(set) var isStreaming: Bool = false

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "ParakeetStreamingTranscriptionService")

    private var streamingManager: StreamingAsrManager?
    private var transcriptionTask: Task<Void, Never>?
    private var confirmedText: String = ""
    private var volatileText: String = ""

    weak var delegate: StreamingTranscriptionDelegate?

    // MARK: - Thread-Safe State for Direct Audio Buffer Access
    //
    // These properties allow appendAudioBuffer() to bypass MainActor entirely.
    // This eliminates the variable latency that was breaking LocalAgreement timing.
    //
    // The lock protects both _activeManager and _isStreamingActive as a unit.
    // When streaming starts: set manager first, then flag
    // When streaming stops: clear flag first, then manager

    nonisolated(unsafe) private let bufferAccessLock = NSLock()
    nonisolated(unsafe) private var _activeManager: StreamingAsrManager?
    nonisolated(unsafe) private var _isStreamingActive: Bool = false

    // MARK: - Streaming Configuration

    /// Streaming config using FluidAudio's recommended settings
    /// The .streaming preset uses LocalAgreement-2 validation with proper context windows:
    /// - 1.5s chunks for balanced latency/accuracy
    /// - 5.0s minimum context for reliable token confirmation
    /// - 0.80 confirmation threshold for quality output
    ///
    /// Note: Earlier aggressive configs (0.5s chunks, 2.0s context) caused:
    /// - Dropped words (insufficient context for LocalAgreement)
    /// - Hallucinated/gibberish text (premature confirmation)
    /// - Duplicated output (confirmation failures)

    // MARK: - Version Management

    private var currentVersion: AsrModelVersion = .v3

    /// Set the Parakeet model version to use for streaming
    func setVersion(_ version: AsrModelVersion) {
        currentVersion = version
    }

    // MARK: - Authorization

    /// Parakeet doesn't require special authorization (uses local model)
    func requestAuthorization() async -> Bool {
        // Check if Parakeet models are available
        let cacheDir = AsrModels.defaultCacheDirectory(for: currentVersion)
        let modelsExist = AsrModels.modelsExist(at: cacheDir, version: currentVersion)

        if !modelsExist {
            logger.warning("Parakeet models not found for streaming - version \(self.currentVersion == .v2 ? "v2" : "v3")")
            return false
        }

        return true
    }

    // MARK: - Model Preloading

    /// Pre-load the streaming manager and models for faster startup
    /// NOTE: This does NOT start the manager - that happens in startStreaming()
    /// This avoids the double-start bug where prepareForStreaming() started the manager,
    /// then startStreaming() started it again, corrupting internal state.
    func prepareForStreaming() async throws {
        guard streamingManager == nil else { return }

        logger.info("Pre-loading Parakeet streaming manager...")

        // Use FluidAudio's .streaming preset for balanced latency and accuracy
        // Just create manager and pre-load models - don't start yet
        let manager = StreamingAsrManager(config: .streaming)

        // Pre-load models into cache (this is the slow part)
        _ = try await AsrModels.loadFromCache(configuration: nil, version: currentVersion)

        self.streamingManager = manager
        logger.info("Parakeet streaming manager pre-loaded (not started)")
    }

    // MARK: - Streaming Control

    /// Start streaming transcription
    /// - Parameter locale: Language code (currently Parakeet only supports English)
    /// NOTE: This method is async to ensure the streaming manager is fully ready before returning.
    /// This prevents the race condition where audio buffers arrive before the manager exists.
    func startStreaming(locale: String = "en") async throws {
        guard !isStreaming else {
            logger.warning("Streaming already active")
            return
        }

        // Reset state
        confirmedText = ""
        volatileText = ""
        partialResult = ""

        logger.info("Starting Parakeet streaming...")

        // CRITICAL: Start manager FIRST, before setting isStreaming
        // This ensures the manager is ready when audio buffers start arriving
        do {
            if let existingManager = streamingManager {
                // Manager exists (either pre-loaded or kept warm after reset) - start/restart it
                logger.info("Starting existing manager...")
                let models = try await AsrModels.loadFromCache(configuration: nil, version: currentVersion)
                try await existingManager.start(models: models, source: .microphone)
                logger.info("Existing manager started")
            } else {
                // Create new streaming manager (first time or after error)
                logger.info("Creating streaming manager...")

                let manager = StreamingAsrManager(config: .streaming)

                // Load models
                let models = try await AsrModels.loadFromCache(configuration: nil, version: currentVersion)
                try await manager.start(models: models, source: .microphone)

                self.streamingManager = manager
                logger.info("Streaming manager created and ready")
            }

            guard let manager = streamingManager else {
                logger.error("Failed to create streaming manager")
                throw StreamingError.managerCreationFailed
            }

            // Listen for transcription updates (fire-and-forget is OK here)
            transcriptionTask = Task { [weak self] in
                for await update in await manager.transcriptionUpdates {
                    guard let self = self else { break }
                    await self.handleTranscriptionUpdate(update)
                }
            }

            // CRITICAL: Set thread-safe references for direct buffer access
            // This allows appendAudioBuffer() to bypass MainActor entirely
            // Order matters: set manager first, then flag (reverse order when stopping)
            bufferAccessLock.lock()
            _activeManager = manager
            _isStreamingActive = true
            bufferAccessLock.unlock()

            // Only set streaming flag AFTER manager is fully ready
            isStreaming = true
            logger.info("Parakeet streaming started successfully")

        } catch {
            logger.error("Failed to start Parakeet streaming: \(error.localizedDescription)")

            // Clear thread-safe references on error
            bufferAccessLock.lock()
            _isStreamingActive = false
            _activeManager = nil
            bufferAccessLock.unlock()

            isStreaming = false
            delegate?.streamingTranscription(didFailWithError: error)
            throw error
        }
    }

    /// Internal error for streaming failures
    private enum StreamingError: Error {
        case managerCreationFailed
    }

    /// Append audio buffer to the streaming recognizer
    /// - Parameter buffer: Audio buffer from the recorder
    ///
    /// CRITICAL: This method is called from a background audio processing queue (~200 times/sec).
    /// We MUST NOT hop to MainActor - that adds 1-50ms variable latency per buffer which
    /// breaks FluidAudio's LocalAgreement timing algorithm.
    ///
    /// Instead, we use thread-safe references (_isStreamingActive, _activeManager) to
    /// call the StreamingAsrManager actor directly. The actor handles its own serialization.
    nonisolated func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Get thread-safe references atomically
        bufferAccessLock.lock()
        let isActive = _isStreamingActive
        let manager = _activeManager
        bufferAccessLock.unlock()

        // Fast path: drop buffer if not streaming
        guard isActive, let manager = manager else {
            // Don't log here - this is expected when stopping
            return
        }

        // Call the actor directly WITHOUT MainActor hop
        // StreamingAsrManager is already an actor - it handles its own serialization
        Task {
            await manager.streamAudio(buffer)
        }
    }

    /// Stop streaming and return final result
    /// - Returns: The final transcribed text
    @discardableResult
    func stopStreaming() async -> String {
        guard isStreaming else {
            return confirmedText + volatileText
        }

        // CRITICAL: Clear thread-safe references FIRST to stop buffer processing
        // Order matters: clear flag first (stops accepting buffers), then clear manager
        bufferAccessLock.lock()
        _isStreamingActive = false
        _activeManager = nil
        bufferAccessLock.unlock()

        isStreaming = false

        // Cancel transcription task
        transcriptionTask?.cancel()
        transcriptionTask = nil

        // Finalize streaming and get the final transcription
        // This is critical - we MUST wait for finish() to get the transcribed text
        guard let manager = streamingManager else {
            let result = confirmedText + volatileText
            logger.info("Stopped Parakeet streaming (no manager), result: \(result.prefix(100))...")
            return result
        }

        var finalResult = ""
        do {
            let finalText = try await manager.finish()
            logger.info("Parakeet finish() returned: \(finalText.prefix(100))...")

            if !finalText.isEmpty {
                confirmedText = finalText
                partialResult = finalText
                finalResult = finalText
                delegate?.streamingTranscription(didReceiveFinalResult: finalText)
            } else {
                // If finish() returns empty, use accumulated text
                finalResult = confirmedText + volatileText
            }

            // Reset manager for next session (keeps models loaded for instant startup)
            // This avoids ~100ms reload latency on next recording
            try await manager.reset()
            logger.info("Manager reset and kept warm for next session")
        } catch {
            logger.error("Error finalizing streaming: \(error.localizedDescription)")
            finalResult = confirmedText + volatileText
            // If reset fails, release manager to ensure clean state
            await manager.cancel()
            streamingManager = nil
            logger.warning("Manager released due to reset error")
        }

        logger.info("Stopped Parakeet streaming, result: \(finalResult.prefix(100))...")

        return finalResult
    }

    private func finalizeStreaming() async {
        guard let manager = streamingManager else { return }

        do {
            let finalText = try await manager.finish()

            if !finalText.isEmpty {
                await MainActor.run {
                    self.confirmedText = finalText
                    self.partialResult = finalText
                    self.delegate?.streamingTranscription(didReceiveFinalResult: finalText)
                }
            }

            // Reset manager for next session
            try await manager.reset()
        } catch {
            logger.error("Error finalizing streaming: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    private func handleTranscriptionUpdate(_ update: StreamingTranscriptionUpdate) async {
        // Track confirmed vs volatile (hypothesis) text
        if update.isConfirmed {
            confirmedText += update.text
            volatileText = ""
        } else {
            volatileText = update.text
        }

        // Combined result for UI
        let combined = confirmedText + volatileText
        partialResult = combined

        // Notify delegate
        if !combined.isEmpty {
            delegate?.streamingTranscription(didReceivePartialResult: combined)
        }

        logger.debug("Streaming update - text: \(update.text.prefix(30)), confirmed: \(update.isConfirmed)")
    }

    // MARK: - Cleanup

    func cleanup() {
        // Clear thread-safe references first
        bufferAccessLock.lock()
        _isStreamingActive = false
        _activeManager = nil
        bufferAccessLock.unlock()

        transcriptionTask?.cancel()
        transcriptionTask = nil

        Task {
            if let manager = streamingManager {
                await manager.cancel()
            }
            streamingManager = nil
        }

        isStreaming = false
        confirmedText = ""
        volatileText = ""
        partialResult = ""
    }
}

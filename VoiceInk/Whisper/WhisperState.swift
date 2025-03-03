import Foundation
import SwiftUI
import AVFoundation
import SwiftData
import AppKit
import KeyboardShortcuts
import os

@MainActor
class WhisperState: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isModelLoaded = false
    @Published var messageLog = ""
    @Published var canTranscribe = false
    @Published var isRecording = false
    @Published var currentModel: WhisperModel?
    @Published var isModelLoading = false
    @Published var availableModels: [WhisperModel] = []
    @Published var predefinedModels: [PredefinedModel] = PredefinedModels.models
    @Published var clipboardMessage = ""
    @Published var miniRecorderError: String?
    @Published var isProcessing = false
    @Published var shouldCancelRecording = false
    @Published var isTranscribing = false
    @Published var isAutoCopyEnabled: Bool = UserDefaults.standard.object(forKey: "IsAutoCopyEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isAutoCopyEnabled, forKey: "IsAutoCopyEnabled")
        }
    }
    @Published var recorderType: String = UserDefaults.standard.string(forKey: "RecorderType") ?? "mini" {
        didSet {
            UserDefaults.standard.set(recorderType, forKey: "RecorderType")
        }
    }
    
    private var whisperContext: WhisperContext?
    private let recorder = Recorder()
    private var recordedFile: URL? = nil
    let whisperPrompt = WhisperPrompt()
    
    let modelContext: ModelContext
    
    private var modelUrl: URL? {
        let possibleURLs = [
            Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin", subdirectory: "Models"),
            Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin"),
            Bundle.main.bundleURL.appendingPathComponent("Models/ggml-base.en.bin")
        ]
        
        for url in possibleURLs {
            if let url = url, FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }
    
    private enum LoadError: Error {
        case couldNotLocateModel
    }
    
    private let modelsDirectory: URL
    private let recordingsDirectory: URL
    private var transcriptionStartTime: Date?
    private var enhancementService: AIEnhancementService?
    private let licenseViewModel: LicenseViewModel
    private var notchWindowManager: NotchWindowManager?
    private var miniWindowManager: MiniWindowManager?
    var audioEngine: AudioEngine
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "WhisperState")
    
    init(modelContext: ModelContext, enhancementService: AIEnhancementService? = nil) {
        self.modelContext = modelContext
        self.modelsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("WhisperModels")
        self.recordingsDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.prakashjoshipax.VoiceInk")
            .appendingPathComponent("Recordings")
        self.audioEngine = AudioEngine()
        self.enhancementService = enhancementService
        self.licenseViewModel = LicenseViewModel()
        
        super.init()
        
        setupNotifications()
        createModelsDirectoryIfNeeded()
        createRecordingsDirectoryIfNeeded()
        loadAvailableModels()
        
        if let savedModelName = UserDefaults.standard.string(forKey: "CurrentModel"),
           let savedModel = availableModels.first(where: { $0.name == savedModelName }) {
            currentModel = savedModel
        }
    }
    
    private func createModelsDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            messageLog += "Error creating models directory: \(error.localizedDescription)\n"
        }
    }
    
    private func createRecordingsDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            messageLog += "Error creating recordings directory: \(error.localizedDescription)\n"
        }
    }
    
    private func loadAvailableModels() {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil)
            availableModels = fileURLs.compactMap { url in
                guard url.pathExtension == "bin" else { return nil }
                return WhisperModel(name: url.deletingPathExtension().lastPathComponent, url: url)
            }
        } catch {
            messageLog += "Error loading available models: \(error.localizedDescription)\n"
        }
    }
    
    private func loadModel(_ model: WhisperModel) async throws {
        guard whisperContext == nil else { return }
        
        isModelLoading = true
        defer { isModelLoading = false }
        
        do {
            whisperContext = try await WhisperContext.createContext(path: model.url.path)
            isModelLoaded = true
            currentModel = model
        } catch {
            throw WhisperStateError.modelLoadFailed
        }
    }
    
    func setDefaultModel(_ model: WhisperModel) async {
        do {
            currentModel = model
            UserDefaults.standard.set(model.name, forKey: "CurrentModel")
            canTranscribe = true
        } catch {
            currentError = error as? WhisperStateError ?? .unknownError
            canTranscribe = false
        }
    }

    func toggleRecord() async {
        if isRecording {
            await recorder.stopRecording()
            isRecording = false
            isVisualizerActive = false
            audioEngine.stopAudioEngine()
            if let recordedFile {
                let duration = Date().timeIntervalSince(transcriptionStartTime ?? Date())
                await transcribeAudio(recordedFile, duration: duration)
            }
        } else {
            requestRecordPermission { [self] granted in
                if granted {
                    Task {
                        do {
                            let file = try FileManager.default.url(for: .documentDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil,
                                create: true)
                                .appending(path: "output.wav")
                            
                            if !self.audioEngine.isRunning {
                                self.audioEngine.startAudioEngine()
                            }
                            
                            try await self.recorder.startRecording(toOutputFile: file, delegate: self)
                            
                            self.isRecording = true
                            self.isVisualizerActive = true
                            self.recordedFile = file
                            self.transcriptionStartTime = Date()
                            
                            await ActiveWindowService.shared.applyConfigurationForCurrentApp()
                            
                            if let currentModel = self.currentModel, self.whisperContext == nil {
                                do {
                                    try await self.loadModel(currentModel)
                                } catch {
                                    await MainActor.run {
                                        self.messageLog += "Error preloading model: \(error.localizedDescription)\n"
                                    }
                                }
                            }
                        } catch {
                            self.messageLog += "\(error.localizedDescription)\n"
                            self.isRecording = false
                            self.isVisualizerActive = false
                            self.audioEngine.stopAudioEngine()
                        }
                    }
                } else {
                    self.messageLog += "Recording permission denied\n"
                }
            }
        }
    }
    
    private func requestRecordPermission(response: @escaping (Bool) -> Void) {
#if os(macOS)
        response(true)
#else
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            response(granted)
        }
#endif
    }
    
    // MARK: AVAudioRecorderDelegate
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error {
            Task {
                await handleRecError(error)
            }
        }
    }
    
    private func handleRecError(_ error: Error) {
        messageLog += "\(error.localizedDescription)\n"
        isRecording = false
    }
    
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task {
            await onDidFinishRecording(success: flag)
        }
    }
    
    private func onDidFinishRecording(success: Bool) {
        isRecording = false
    }
    
    @Published var downloadProgress: [String: Double] = [:]

    func downloadModel(_ model: PredefinedModel) async {
        guard let url = URL(string: model.downloadURL) else { return }

        do {
            let (data, response) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, URLResponse), Error>) in
                let task = URLSession.shared.dataTask(with: url) { data, response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode),
                          let data = data else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                        return
                    }
                    continuation.resume(returning: (data, httpResponse))
                }
                
                task.resume()
                
                let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                    DispatchQueue.main.async {
                        self.downloadProgress[model.name] = progress.fractionCompleted
                    }
                }
                
                Task {
                    await withTaskCancellationHandler {
                        observation.invalidate()
                    } operation: {
                        await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in }
                    }
                }
            }

            let destinationURL = modelsDirectory.appendingPathComponent(model.filename)
            try data.write(to: destinationURL)

            availableModels.append(WhisperModel(name: model.name, url: destinationURL))
            self.downloadProgress.removeValue(forKey: model.name)
        } catch {
            currentError = .modelDownloadFailed
            self.downloadProgress.removeValue(forKey: model.name)
        }
    }

    private func transcribeAudio(_ url: URL, duration: TimeInterval) async {
        if shouldCancelRecording { return }

        guard let currentModel = currentModel else {
            messageLog += "Cannot transcribe: No model selected.\n"
            currentError = .modelLoadFailed
            return
        }

        guard let whisperContext = whisperContext else {
            messageLog += "Cannot transcribe: Model not loaded.\n"
            currentError = .modelLoadFailed
            return
        }

        do {
            isProcessing = true
            isTranscribing = true
            canTranscribe = false

            let permanentURL = try saveRecordingPermanently(url)
            let permanentURLString = permanentURL.absoluteString

            if shouldCancelRecording {
                await cleanupResources()
                return
            }

            messageLog += "Reading wave samples...\n"
            let data = try readAudioSamples(url)
            
            if shouldCancelRecording {
                await cleanupResources()
                return
            }
            
            messageLog += "Transcribing data using \(currentModel.name) model...\n"
            messageLog += "Setting prompt: \(whisperPrompt.transcriptionPrompt)\n"
            await whisperContext.setPrompt(whisperPrompt.transcriptionPrompt)
            
            if shouldCancelRecording {
                await cleanupResources()
                return
            }
            
            await whisperContext.fullTranscribe(samples: data)
            
            if shouldCancelRecording {
                await cleanupResources()
                return
            }
            
            var text = await whisperContext.getTranscription()
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let enhancementService = enhancementService,
               enhancementService.isEnhancementEnabled,
               enhancementService.isConfigured {
                do {
                    if shouldCancelRecording {
                        await cleanupResources()
                        return
                    }
                    
                    messageLog += "Enhancing transcription with AI...\n"
                    let enhancedText = try await enhancementService.enhance(text)
                    messageLog += "Enhancement completed.\n"
                    
                    let newTranscription = Transcription(
                        text: text,
                        duration: duration,
                        enhancedText: enhancedText,
                        audioFileURL: permanentURLString
                    )
                    modelContext.insert(newTranscription)
                    try? modelContext.save()
                    
                    text = enhancedText
                } catch {
                    messageLog += "Enhancement failed: \(error.localizedDescription). Using original transcription.\n"
                    let newTranscription = Transcription(
                        text: text,
                        duration: duration,
                        audioFileURL: permanentURLString
                    )
                    modelContext.insert(newTranscription)
                    try? modelContext.save()
                }
            } else {
                let newTranscription = Transcription(
                    text: text,
                    duration: duration,
                    audioFileURL: permanentURLString
                )
                modelContext.insert(newTranscription)
                try? modelContext.save()
            }
            
            if case .trialExpired = licenseViewModel.licenseState {
                text = """
                    Your trial has expired. Upgrade to VoiceInk Pro at tryvoiceink.com/buy
                    
                    \(text)
                    """
            }
            
            messageLog += "Done: \(text)\n"
            
            SoundManager.shared.playStopSound()
            
            if AXIsProcessTrusted() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    CursorPaster.pasteAtCursor(text)
                }
            } else {
                messageLog += "Accessibility permissions not granted. Transcription not pasted automatically.\n"
            }
            
            if isAutoCopyEnabled {
                let success = ClipboardManager.copyToClipboard(text)
                if success {
                    clipboardMessage = "Transcription copied to clipboard"
                } else {
                    clipboardMessage = "Failed to copy to clipboard"
                    messageLog += "Failed to copy transcription to clipboard\n"
                }
            }
            
            await cleanupResources()
            await dismissMiniRecorder()
            
        } catch {
            messageLog += "\(error.localizedDescription)\n"
            currentError = .transcriptionFailed
            
            await cleanupResources()
            await dismissMiniRecorder()
        }
    }

    private func readAudioSamples(_ url: URL) throws -> [Float] {
        return try decodeWaveFile(url)
    }

    private func decodeWaveFile(_ url: URL) throws -> [Float] {
        let data = try Data(contentsOf: url)
        let floats = stride(from: 44, to: data.count, by: 2).map {
            return data[$0..<$0 + 2].withUnsafeBytes {
                let short = Int16(littleEndian: $0.load(as: Int16.self))
                return max(-1.0, min(Float(short) / 32767.0, 1.0))
            }
        }
        return floats
    }

    func deleteModel(_ model: WhisperModel) async {
        do {
            try FileManager.default.removeItem(at: model.url)
            availableModels.removeAll { $0.id == model.id }
            if currentModel?.id == model.id {
                currentModel = nil
                canTranscribe = false
            }
        } catch {
            print("Error deleting model: \(error.localizedDescription)")
            messageLog += "Error deleting model: \(error.localizedDescription)\n"
            currentError = .modelDeletionFailed
        }
    }

    @Published var isVisualizerActive = false
    
    @Published var isMiniRecorderVisible = false {
        didSet {
            if isMiniRecorderVisible {
                showRecorderPanel()
            } else {
                hideRecorderPanel()
            }
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleToggleMiniRecorder), name: .toggleMiniRecorder, object: nil)
    }
    
    @objc public func handleToggleMiniRecorder() {
        if isMiniRecorderVisible {
            // If the recorder is visible, toggle recording
            Task {
                await toggleRecord()
            }
        } else {
            // Serialize audio operations to prevent deadlocks
            Task {
                do {
                    // First start the audio engine
                    await MainActor.run {
                        audioEngine.startAudioEngine()
                    }
                    
                    // Small delay to ensure audio system is ready
                    try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    
                    // Now play the sound
                    SoundManager.shared.playStartSound()
                    
                    // Show UI
                    await MainActor.run {
                        showRecorderPanel()
                        isMiniRecorderVisible = true
                    }
                    
                    // Finally start recording
                    await toggleRecord()
                } catch {
                    logger.error("Error during recorder initialization: \(error)")
                }
            }
        }
    }

    private func showRecorderPanel() {
        logger.info("Showing recorder panel, type: \(self.recorderType)")
        if recorderType == "notch" {
            if notchWindowManager == nil {
                notchWindowManager = NotchWindowManager(whisperState: self, audioEngine: audioEngine)
                logger.info("Created new notch window manager")
            }
            notchWindowManager?.show()
        } else {
            if miniWindowManager == nil {
                miniWindowManager = MiniWindowManager(whisperState: self, audioEngine: audioEngine)
                logger.info("Created new mini window manager")
            }
            miniWindowManager?.show()
        }
        // Audio engine is now started separately in handleToggleMiniRecorder
        // SoundManager.shared.playStartSound() - Moved to handleToggleMiniRecorder
        logger.info("Recorder panel shown successfully")
    }

    private func hideRecorderPanel() {
        audioEngine.stopAudioEngine()
        
        if isRecording {
            Task {
                await toggleRecord()
            }
        }
    }

    func toggleMiniRecorder() async {
        if isMiniRecorderVisible {
            await dismissMiniRecorder()
        } else {
            // Start a parallel task for both UI and recording
            Task {
                // Play start sound first
                SoundManager.shared.playStartSound()
                
                // Start audio engine immediately - this can happen in parallel
                audioEngine.startAudioEngine()
                
                // Show UI (this is quick now that we removed animations)
                await MainActor.run {
                    showRecorderPanel() // Modified version that doesn't start audio engine
                    isMiniRecorderVisible = true
                }
                
                // Start recording
                await toggleRecord()
            }
        }
    }

    private func cleanupResources() async {
        audioEngine.stopAudioEngine()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        if !isRecording && !isProcessing {
            await whisperContext?.releaseResources()
            whisperContext = nil
            isModelLoaded = false
        }
    }

    func dismissMiniRecorder() async {
        shouldCancelRecording = true
        if isRecording {
            await recorder.stopRecording()
        }
        
        if recorderType == "notch" {
            notchWindowManager?.hide()
        } else {
            miniWindowManager?.hide()
        }
        
        await MainActor.run {
            isRecording = false
            isVisualizerActive = false
            isProcessing = false
            isTranscribing = false
            canTranscribe = true
            isMiniRecorderVisible = false
            shouldCancelRecording = false
        }
        
        try? await Task.sleep(nanoseconds: 150_000_000)
        await cleanupResources()
    }

    func cancelRecording() async {
        shouldCancelRecording = true
        SoundManager.shared.playEscSound()
        if isRecording {
            await recorder.stopRecording()
        }
        await dismissMiniRecorder()
    }

    @Published var currentError: WhisperStateError?

    func unloadModel() {
        Task {
            await whisperContext?.releaseResources()
            whisperContext = nil
            isModelLoaded = false
            
            audioEngine.stopAudioEngine()
            if let recordedFile = recordedFile {
                try? FileManager.default.removeItem(at: recordedFile)
                self.recordedFile = nil
            }
        }
    }

    private func clearDownloadedModels() async {
        for model in availableModels {
            do {
                try FileManager.default.removeItem(at: model.url)
            } catch {
                messageLog += "Error deleting model: \(error.localizedDescription)\n"
            }
        }
        availableModels.removeAll()
    }

    func getEnhancementService() -> AIEnhancementService? {
        return enhancementService
    }

    private func saveRecordingPermanently(_ tempURL: URL) throws -> URL {
        let fileName = "\(UUID().uuidString).wav"
        let permanentURL = recordingsDirectory.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: tempURL, to: permanentURL)
        return permanentURL
    }
}

struct WhisperModel: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    var downloadURL: String {
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(filename)"
    }
    var filename: String {
        "\(name).bin"
    }
}

private class TaskDelegate: NSObject, URLSessionTaskDelegate {
    private let continuation: CheckedContinuation<Void, Never>
    
    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        continuation.resume()
    }
}

extension Notification.Name {
    static let toggleMiniRecorder = Notification.Name("toggleMiniRecorder")
}


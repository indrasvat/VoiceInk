import Foundation

// Enum to describe streaming capability of a model
enum StreamingCapability: String, Codable {
    case batchOnly         // Model only supports batch transcription (Whisper, most cloud)
    case streamingOnly     // Model only supports streaming (Apple Live)
    case batchAndStreaming // Model supports both modes (Parakeet with streaming branch)
}

// Enum to differentiate between model providers
enum ModelProvider: String, Codable, Hashable, CaseIterable {
    case local = "Local"
    case parakeet = "Parakeet"
    case groq = "Groq"
    case elevenLabs = "ElevenLabs"
    case deepgram = "Deepgram"
    case mistral = "Mistral"
    case gemini = "Gemini"
    case soniox = "Soniox"
    case custom = "Custom"
    case nativeApple = "Native Apple"
    case streaming = "Streaming"
}

// A unified protocol for any transcription model
protocol TranscriptionModel: Identifiable, Hashable {
    var id: UUID { get }
    var name: String { get }
    var displayName: String { get }
    var description: String { get }
    var provider: ModelProvider { get }

    // Language capabilities
    var isMultilingualModel: Bool { get }
    var supportedLanguages: [String: String] { get }

    // Streaming capability - determines if model can stream or only batch
    var streamingCapability: StreamingCapability { get }
}

extension TranscriptionModel {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var language: String {
        isMultilingualModel ? "Multilingual" : "English-only"
    }

    // Default: most models only support batch transcription
    var streamingCapability: StreamingCapability {
        .batchOnly
    }
}

// A new struct for Apple's native models
struct NativeAppleModel: TranscriptionModel {
    let id = UUID()
    let name: String
    let displayName: String
    let description: String
    let provider: ModelProvider = .nativeApple
    let isMultilingualModel: Bool
    let supportedLanguages: [String: String]
}

// A new struct for streaming transcription using Apple's SFSpeechRecognizer
struct StreamingModel: TranscriptionModel {
    let id = UUID()
    let name: String
    let displayName: String
    let description: String
    let provider: ModelProvider = .streaming
    let isMultilingualModel: Bool
    let supportedLanguages: [String: String]

    // Apple Live streaming is streaming-only
    var streamingCapability: StreamingCapability { .streamingOnly }
}

// A new struct for Parakeet models
struct ParakeetModel: TranscriptionModel {
    let id = UUID()
    let name: String
    let displayName: String
    let description: String
    let provider: ModelProvider = .parakeet
    let size: String
    let speed: Double
    let accuracy: Double
    let ramUsage: Double
    var isMultilingualModel: Bool {
        supportedLanguages.count > 1
    }
    let supportedLanguages: [String: String]

    // Parakeet supports both batch and streaming (via FluidAudio streammsss branch)
    var streamingCapability: StreamingCapability { .batchAndStreaming }
}

// A new struct for cloud models
struct CloudModel: TranscriptionModel {
    let id: UUID
    let name: String
    let displayName: String
    let description: String
    let provider: ModelProvider
    let speed: Double
    let accuracy: Double
    let isMultilingualModel: Bool
    let supportedLanguages: [String: String]

    init(id: UUID = UUID(), name: String, displayName: String, description: String, provider: ModelProvider, speed: Double, accuracy: Double, isMultilingual: Bool, supportedLanguages: [String: String]) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.description = description
        self.provider = provider
        self.speed = speed
        self.accuracy = accuracy
        self.isMultilingualModel = isMultilingual
        self.supportedLanguages = supportedLanguages
    }
}

// A new struct for custom cloud models
struct CustomCloudModel: TranscriptionModel, Codable {
    let id: UUID
    let name: String
    let displayName: String
    let description: String
    let provider: ModelProvider = .custom
    let apiEndpoint: String
    let apiKey: String
    let modelName: String
    let isMultilingualModel: Bool
    let supportedLanguages: [String: String]

    init(id: UUID = UUID(), name: String, displayName: String, description: String, apiEndpoint: String, apiKey: String, modelName: String, isMultilingual: Bool = true, supportedLanguages: [String: String]? = nil) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.description = description
        self.apiEndpoint = apiEndpoint
        self.apiKey = apiKey
        self.modelName = modelName
        self.isMultilingualModel = isMultilingual
        self.supportedLanguages = supportedLanguages ?? PredefinedModels.getLanguageDictionary(isMultilingual: isMultilingual)
    }
} 

struct LocalModel: TranscriptionModel {
    let id = UUID()
    let name: String
    let displayName: String
    let size: String
    let supportedLanguages: [String: String]
    let description: String
    let speed: Double
    let accuracy: Double
    let ramUsage: Double
    let provider: ModelProvider = .local

    var downloadURL: String {
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(filename)"
    }

    var filename: String {
        "\(name).bin"
    }

    var isMultilingualModel: Bool {
        supportedLanguages.count > 1
    }
} 

// User-imported local models 
struct ImportedLocalModel: TranscriptionModel {
    let id = UUID()
    let name: String
    let displayName: String
    let description: String
    let provider: ModelProvider = .local
    let isMultilingualModel: Bool
    let supportedLanguages: [String: String]

    init(fileBaseName: String) {
        self.name = fileBaseName
        self.displayName = fileBaseName
        self.description = "Imported local model"
        self.isMultilingualModel = true
        self.supportedLanguages = PredefinedModels.getLanguageDictionary(isMultilingual: true, provider: .local)
    }
}
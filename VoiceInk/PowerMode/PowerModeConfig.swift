import Foundation

struct PowerModeConfig: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var emoji: String
    var appConfigs: [AppConfig]?
    var urlConfigs: [URLConfig]?
    var isAIEnhancementEnabled: Bool
    var selectedPrompt: String? // UUID string of the selected prompt
    var selectedWhisperModel: String? // Name of the selected Whisper model
    var selectedLanguage: String? // Language code (e.g., "en", "fr")
    var useScreenCapture: Bool
    var selectedAIProvider: String? // AI provider name (e.g., "OpenAI", "Gemini")
    var selectedAIModel: String? // AI model name (e.g., "gpt-4", "gemini-1.5-pro")
    
    init(id: UUID = UUID(), name: String, emoji: String, appConfigs: [AppConfig]? = nil, 
         urlConfigs: [URLConfig]? = nil, isAIEnhancementEnabled: Bool, selectedPrompt: String? = nil,
         selectedWhisperModel: String? = nil, selectedLanguage: String? = nil, useScreenCapture: Bool = false,
         selectedAIProvider: String? = nil, selectedAIModel: String? = nil) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.appConfigs = appConfigs
        self.urlConfigs = urlConfigs
        self.isAIEnhancementEnabled = isAIEnhancementEnabled
        self.selectedPrompt = selectedPrompt
        self.useScreenCapture = useScreenCapture
        self.selectedAIProvider = selectedAIProvider ?? UserDefaults.standard.string(forKey: "selectedAIProvider")
        self.selectedAIModel = selectedAIModel
        
        // Use provided values or get from UserDefaults if nil
        self.selectedWhisperModel = selectedWhisperModel ?? UserDefaults.standard.string(forKey: "CurrentModel")
        self.selectedLanguage = selectedLanguage ?? UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "en"
    }
    
    static func == (lhs: PowerModeConfig, rhs: PowerModeConfig) -> Bool {
        lhs.id == rhs.id
    }
}

// App configuration
struct AppConfig: Codable, Identifiable, Equatable {
    let id: UUID
    var bundleIdentifier: String
    var appName: String
    
    init(id: UUID = UUID(), bundleIdentifier: String, appName: String) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
    }
    
    static func == (lhs: AppConfig, rhs: AppConfig) -> Bool {
        lhs.id == rhs.id
    }
}

// Simple URL configuration
struct URLConfig: Codable, Identifiable, Equatable {
    let id: UUID
    var url: String // Simple URL like "google.com"
    
    init(id: UUID = UUID(), url: String) {
        self.id = id
        self.url = url
    }
    
    static func == (lhs: URLConfig, rhs: URLConfig) -> Bool {
        lhs.id == rhs.id
    }
}

class PowerModeManager: ObservableObject {
    static let shared = PowerModeManager()
    @Published var configurations: [PowerModeConfig] = []
    @Published var defaultConfig: PowerModeConfig
    @Published var isPowerModeEnabled: Bool
    
    private let configKey = "powerModeConfigurationsV2"
    private let defaultConfigKey = "defaultPowerModeConfigV2"
    private let powerModeEnabledKey = "isPowerModeEnabled"
    
    private init() {
        // Load power mode enabled state or default to false if not set
        if UserDefaults.standard.object(forKey: powerModeEnabledKey) != nil {
            self.isPowerModeEnabled = UserDefaults.standard.bool(forKey: powerModeEnabledKey)
        } else {
            self.isPowerModeEnabled = false
            UserDefaults.standard.set(false, forKey: powerModeEnabledKey)
        }
        
        // Initialize default config with default values
        if let data = UserDefaults.standard.data(forKey: defaultConfigKey),
           let config = try? JSONDecoder().decode(PowerModeConfig.self, from: data) {
            defaultConfig = config
        } else {
            // Get default values from UserDefaults if available
            let defaultModelName = UserDefaults.standard.string(forKey: "CurrentModel")
            let defaultLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "en"
            
            defaultConfig = PowerModeConfig(
                id: UUID(),
                name: "Default Configuration",
                emoji: "⚙️",
                isAIEnhancementEnabled: false,
                selectedPrompt: nil,
                selectedWhisperModel: defaultModelName,
                selectedLanguage: defaultLanguage
            )
            saveDefaultConfig()
        }
        loadConfigurations()
    }
    
    private func loadConfigurations() {
        if let data = UserDefaults.standard.data(forKey: configKey),
           let configs = try? JSONDecoder().decode([PowerModeConfig].self, from: data) {
            configurations = configs
        }
    }
    
    func saveConfigurations() {
        if let data = try? JSONEncoder().encode(configurations) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }
    
    private func saveDefaultConfig() {
        if let data = try? JSONEncoder().encode(defaultConfig) {
            UserDefaults.standard.set(data, forKey: defaultConfigKey)
        }
    }
    
    func addConfiguration(_ config: PowerModeConfig) {
        if !configurations.contains(where: { $0.id == config.id }) {
            configurations.append(config)
            saveConfigurations()
        }
    }
    
    func removeConfiguration(with id: UUID) {
        configurations.removeAll { $0.id == id }
        saveConfigurations()
    }
    
    func getConfiguration(with id: UUID) -> PowerModeConfig? {
        return configurations.first { $0.id == id }
    }
    
    func updateConfiguration(_ config: PowerModeConfig) {
        if config.id == defaultConfig.id {
            defaultConfig = config
            saveDefaultConfig()
        } else if let index = configurations.firstIndex(where: { $0.id == config.id }) {
            configurations[index] = config
            saveConfigurations()
        }
    }
    
    // Get configuration for a specific URL
    func getConfigurationForURL(_ url: String) -> PowerModeConfig? {
        let cleanedURL = cleanURL(url)
        
        for config in configurations {
            if let urlConfigs = config.urlConfigs {
                for urlConfig in urlConfigs {
                    let configURL = cleanURL(urlConfig.url)
                    
                    if cleanedURL.contains(configURL) {
                        return config
                    }
                }
            }
        }
        return nil
    }
    
    // Get configuration for an application bundle ID
    func getConfigurationForApp(_ bundleId: String) -> PowerModeConfig? {
        for config in configurations {
            if let appConfigs = config.appConfigs {
                if appConfigs.contains(where: { $0.bundleIdentifier == bundleId }) {
                    return config
                }
            }
        }
        return nil
    }
    
    // Add app configuration
    func addAppConfig(_ appConfig: AppConfig, to config: PowerModeConfig) {
        if var updatedConfig = configurations.first(where: { $0.id == config.id }) {
            var configs = updatedConfig.appConfigs ?? []
            configs.append(appConfig)
            updatedConfig.appConfigs = configs
            updateConfiguration(updatedConfig)
        }
    }
    
    // Remove app configuration
    func removeAppConfig(_ appConfig: AppConfig, from config: PowerModeConfig) {
        if var updatedConfig = configurations.first(where: { $0.id == config.id }) {
            updatedConfig.appConfigs?.removeAll(where: { $0.id == appConfig.id })
            updateConfiguration(updatedConfig)
        }
    }
    
    // Add URL configuration
    func addURLConfig(_ urlConfig: URLConfig, to config: PowerModeConfig) {
        if var updatedConfig = configurations.first(where: { $0.id == config.id }) {
            var configs = updatedConfig.urlConfigs ?? []
            configs.append(urlConfig)
            updatedConfig.urlConfigs = configs
            updateConfiguration(updatedConfig)
        }
    }
    
    // Remove URL configuration
    func removeURLConfig(_ urlConfig: URLConfig, from config: PowerModeConfig) {
        if var updatedConfig = configurations.first(where: { $0.id == config.id }) {
            updatedConfig.urlConfigs?.removeAll(where: { $0.id == urlConfig.id })
            updateConfiguration(updatedConfig)
        }
    }
    
    // Clean URL for comparison
    func cleanURL(_ url: String) -> String {
        return url.lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Save power mode enabled state
    func savePowerModeEnabled() {
        UserDefaults.standard.set(isPowerModeEnabled, forKey: powerModeEnabledKey)
    }
} 
import Foundation

@MainActor
class WhisperPrompt: ObservableObject {
    @Published var transcriptionPrompt: String = UserDefaults.standard.string(forKey: "TranscriptionPrompt") ?? ""
    
    private var dictionaryWords: [String] = []
    private let saveKey = "CustomDictionaryItems"
    
    private let basePrompt = """
    Hey, How are you doing? Are you good? It's nice to meet after so long.
    
    """
    
    init() {
        loadDictionaryItems()
        updateTranscriptionPrompt()
    }
    
    private func loadDictionaryItems() {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return }
        
        if let savedItems = try? JSONDecoder().decode([DictionaryItem].self, from: data) {
            let enabledWords = savedItems.filter { $0.isEnabled }.map { $0.word }
            dictionaryWords = enabledWords
            updateTranscriptionPrompt()
        }
    }
    
    func updateDictionaryWords(_ words: [String]) {
        dictionaryWords = words
        updateTranscriptionPrompt()
    }
    
    private func updateTranscriptionPrompt() {
        var prompt = basePrompt
        var allWords = ["VoiceInk"]
        allWords.append(contentsOf: dictionaryWords)
        
        if !allWords.isEmpty {
            prompt += "\nImportant words: " + allWords.joined(separator: ", ")
        }
        
        transcriptionPrompt = prompt
        UserDefaults.standard.set(prompt, forKey: "TranscriptionPrompt")
    }
    
    func saveDictionaryItems(_ items: [DictionaryItem]) async {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
            let enabledWords = items.filter { $0.isEnabled }.map { $0.word }
            dictionaryWords = enabledWords
            updateTranscriptionPrompt()
        }
    }
} 
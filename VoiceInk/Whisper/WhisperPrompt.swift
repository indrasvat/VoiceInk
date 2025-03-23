import Foundation

@MainActor
class WhisperPrompt: ObservableObject {
    @Published var transcriptionPrompt: String = UserDefaults.standard.string(forKey: "TranscriptionPrompt") ?? ""
    
    private var dictionaryWords: [String] = []
    private let saveKey = "CustomDictionaryItems"
    
    // Language-specific base prompts
    private let languagePrompts: [String: String] = [
        // English
        "en": "Hey, How are you doing? Are you good? It's nice to meet after so long.",
        
        // Asian Languages
        "hi": "नमस्ते, कैसे हैं आप? सब ठीक है? इतने समय बाद मिलकर बहुत अच्छा लगा।",
        "bn": "নমস্কার, কেমন আছেন? সব ঠিক আছে? এত দিন পর দেখা হয়ে খুব ভালো লাগছে।",
        "ja": "こんにちは、お元気ですか？調子はいかがですか？久しぶりにお会いできて嬉しいです。",
        "ko": "안녕하세요, 잘 지내시나요? 괜찮으신가요? 오랜만에 만나서 반갑습니다.",
        "zh": "你好，最近好吗？你还好吗？好久不见了，很高兴见到你。",
        "th": "สวัสดีครับ/ค่ะ สบายดีไหม? เป็นอย่างไรบ้าง? ดีใจที่ได้เจอกันหลังจากนานมาก",
        "vi": "Xin chào, bạn khỏe không? Dạo này bạn thế nào? Rất vui được gặp lại bạn sau thời gian dài.",
        
        // European Languages
        "es": "¡Hola! ¿Cómo estás? ¿Todo bien? ¡Qué gusto verte después de tanto tiempo!",
        "fr": "Bonjour! Comment allez-vous? Vous vous portez bien? C'est un plaisir de vous revoir après si longtemps!",
        "de": "Hallo! Wie geht es dir? Alles in Ordnung? Schön, dich nach so langer Zeit wiederzusehen!",
        "it": "Ciao! Come stai? Tutto bene? È bello rivederti dopo tanto tempo!",
        "pt": "Olá! Como você está? Tudo bem? É muito bom te ver depois de tanto tempo!",
        "ru": "Здравствуйте! Как у вас дела? Всё хорошо? Приятно встретиться после долгого времени!",
        "pl": "Cześć! Jak się masz? Wszystko w porządku? Miło cię widzieć po tak długim czasie!",
        "nl": "Hallo! Hoe gaat het met je? Alles goed? Fijn om je na zo'n lange tijd weer te zien!",
        "tr": "Merhaba! Nasılsın? İyi misin? Uzun zaman sonra görüşmek çok güzel!",
        
        // Middle Eastern Languages
        "ar": "مرحباً! كيف حالك؟ هل أنت بخير؟ من الجميل أن نلتقي بعد كل هذا الوقت!",
        "fa": "سلام! حال شما چطور است؟ خوب هستید؟ خیلی خوشحالم که بعد از مدت‌ها می‌بینمتان!",
        "he": "!שלום! מה שלומך? הכל בסדר? כל כך נעים לראות אותך אחרי זמן רב",
        
        // South Asian Languages
        "ta": "வணக்கம், எப்படி இருக்கிறீர்கள்? நலமா? நீண்ட நாட்களுக்குப் பிறகு சந்திப்பது மகிழ்ச்சியாக இருக்கிறது.",
        "te": "నమస్కారం, ఎలా ఉన్నారు? బాగున్నారా? ఇంత కాలం తర్వాత కలుసుకోవడం చాలా సంతోషంగా ఉంది.",
        "ml": "നമസ്കാരം, സുഖമാണോ? എല്ലാം ശരിയാണോ? ഇത്രയും കാലത്തിനു ശേഷം കാണുന്നതിൽ സന്തോഷം.",
        "kn": "ನಮಸ್ಕಾರ, ಹೇಗಿದ್ದೀರಾ? ಎಲ್ಲಾ ಚೆನ್ನಾಗಿದೆಯಾ? ಇಷ್ಟು ದಿನಗಳ ನಂತರ ನಿಮ್ಮನ್ನು ನೋಡಿ ತುಂಬಾ ಸಂತೋಷವಾಗಿದೆ.",
        "ur": "السلام علیکم! کیسے ہیں آپ؟ سب ٹھیک ہے؟ اتنے عرصے بعد آپ سے مل کر بہت خوشی ہوئی۔",
        
        // Default prompt for unsupported languages
        "default": "Hello. How are you? Nice to meet you after so long."
    ]
    
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
        // Get the currently selected language from UserDefaults
        let selectedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "en"
        
        // Get the appropriate base prompt for the selected language
        let basePrompt = languagePrompts[selectedLanguage] ?? languagePrompts["default"]!
        
        var prompt = basePrompt
        var allWords = ["VoiceInk"]
        allWords.append(contentsOf: dictionaryWords)
        
        if !allWords.isEmpty {
            // Keep Important words section in English for all languages
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
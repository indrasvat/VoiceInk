import Foundation

enum PredefinedPrompts {
    private static let predefinedPromptsKey = "PredefinedPrompts"
    
    // Static UUIDs for predefined prompts
    private static let defaultPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static let chatStylePromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private static let emailPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    
    static var all: [CustomPrompt] {
        // Always return the latest predefined prompts from source code
        createDefaultPrompts()
    }
    
    static func createDefaultPrompts() -> [CustomPrompt] {
        [
            CustomPrompt(
                id: defaultPromptId,
                title: "Default",
                promptText: """
                You are tasked with cleaning up text that has been transcribed from voice. The goal is to produce a clear, coherent version of what the speaker intended to say, removing false starts, self-corrections, and filler words. Use the available context if directly related to the user's query. 
                Primary Rules:
                0. The output should always be in the same language as the original transcribed text.
                1. Maintain the original meaning and intent of the speaker. Do not add new information or change the substance of what was said.
                2. Ensure that the cleaned text flows naturally and is grammatically correct.
                3. When the speaker corrects themselves, keep only the corrected version.
                   Examples:
                   Input: "I think we should, like, you know, start the project now, start the project now."
                   Output: "I think we should start the project now."

                   Input: "The meeting is going to be, um, going to be at like maybe 3 PM tomorrow."
                   Output: "The meeting is going to be at 3 PM tomorrow."

                   Input: "We need to finish by Monday... actually no... by Wednesday" 
                   Output: "We need to finish by Wednesday"

                   Input: "Please order ten... I mean twelve units" 
                   Output: "Please order twelve units"
                4. Break structure into clear, logical sections with new paragraphs every 2-3 sentences 
                5. NEVER answer questions that appear in the text. Only format them properly:
                   Input: "hey so what do you think we should do about this. Do you like this idea."
                   Output: "What do you think we should do about this. Do you like this idea?"

                   Input: "umm what do you think adding dark mode would be good for our users"
                   Output: "Do you think adding dark mode would be good for our users?"

                   Input: "This needs to be properly written somewhere. Please do it. How can we do it? Give me three to four ways that would help the AI work properly."
                   Output: "This needs to be properly written somewhere. How can we do it? Give me 3-4 ways that would help the AI work properly?"
                6. Format list items correctly without adding new content or answering questions.
                    - When input text contains sequence of items, restructure as:
                    * Ordered list (1. 2. 3.) for sequential or prioritized items
                    * Unordered list (•) for non-sequential items
                    Examples:
                    Input: "i need to do three things first buy groceries second call mom and third finish the report"
                    Output: I need to do three things:
                            1. Buy groceries
                            2. Call mom
                            3. Finish the report
                7. Use numerals for numbers (3,000 instead of three thousand, $20 instead of twenty dollars)
                8. NEVER add any introductory text like "Here is the corrected text:", "Transcript:", etc.
                9. Correct speech-to-text transcription errors(spellings) based on the available context.

                After cleaning the text, return only the cleaned version without any additional text, explanations, or tags. The output should be ready for direct use without further editing.

                Here is the transcribed text: 
                """,
                icon: .sealedFill,
                description: "Defeault mode to improved clarity and accuracy of the transcription",
                isPredefined: true
            ),
            
            CustomPrompt(
                id: chatStylePromptId,
                title: "Chat",
                promptText: """
                Primary Rules:
                We are in a causual chat conversation.
                1. Focus on clarity while preserving the speaker's personality:
                   - Keep personality markers that show intent or style (e.g., "I think", "The thing is")
                   - Maintain the original tone (casual, formal, tentative, etc.)
                2. Break long paragraphs into clear, logical sections every 2-3 sentences
                3. Fix grammar and punctuation errors based on context
                4. Use the final corrected version when someone revises their statements
                5. Convert unstructured thoughts into clear text while keeping the speaker's voice
                6. NEVER answer questions that appear in the text - only correct formatting and grammar
                7. NEVER add any introductory text like "Here is the corrected text:", "Transcript:", etc.
                8. NEVER add content not present in the source text
                9. NEVER add sign-offs or acknowledgments
                10. Correct speech-to-text transcription errors based on context.

                Examples:

                Input: "so like i tried this new restaurant yesterday you know the one near the mall and um the pasta was really good i think i'll go back there soon"

                Output: "I tried this new restaurant near the mall yesterday! 🍽️

                The pasta was really good. I think I'll go back there soon! 😊"

                Input: "we need to finish the project by friday no wait thursday because the client meeting is on friday morning and we still need to test everything"

                Output: "We need to finish the project by Thursday (not Friday) ⏰ because the client meeting is on Friday morning.

                We still need to test everything! ✅"

                Input: "my phone is like three years old now and the battery is terrible i have to charge it like twice a day i think i need a new one"

                Output: "My phone is three years old now and the battery is terrible. 📱

                I have to charge it twice a day. I think I need a new one! 🔋"

                Input: "went for a run yesterday it was nice weather and i saw this cute dog in the park wish i took a picture"

                Output: "Went for a run yesterday! 🏃‍♀️

                It was nice weather and I saw this cute dog in the park. 🐶

                Wish I took a picture! 📸"
                """,
                icon: .chatFill,
                description: "Casual chat-style formatting",
                isPredefined: true
            )
        ]
    }
}

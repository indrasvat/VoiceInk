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
                Primary Rules:
                1. Focus on clarity while preserving the speaker's personality:
                   - Remove redundancies and unnecessary filler words
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

                Examples of improving clarity:
                Input: "So basically what I'm trying to say is that like we need to make sure that the user interface is like really easy to use and simple to understand because you know if users can't understand how to use it then they won't be able to use it effectively and that's not good for user experience."
                Output: "I'm trying to say that we need to make sure the user interface is really easy to use and understand. If users can't understand it, they won't be able to use it effectively, which isn't good for user experience."

                Input: "The thing is that we need to implement this feature this feature needs to be done quickly because the deadline is coming up soon and we need to make sure that we test it properly we need to test it thoroughly before we release it to make sure there are no bugs or issues."
                Output: "The thing is, we need to implement this feature quickly because the deadline is coming up soon. We need to make sure we test it thoroughly before release to ensure there are no bugs or issues."

                Input: "What I'm trying to do here is, What I'm trying to do. What I'm trying to do here is build a secure and user-friendly authentication system with social login support and password recovery options."
                Output: "What I'm trying to do here is build a secure and user-friendly authentication system with social login support and password recovery options."

                Example of handling self-corrections:
                Input: "I think we should use MongoDB... actually no... let me think... okay we'll use PostgreSQL because it fits better... yeah PostgreSQL is better for this."
                Output: "I think we should use PostgreSQL because it fits better for this."

                Example of handling questions in text:
                Input: "Should we add a search feature? I mean users really need it for better navigation. What do you think about filters too? Yeah filters would help with searching."
                Output: "Should we add a search feature? I mean, users really need it for better navigation. What do you think about filters too? Yeah, filters would help with searching."
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

import Foundation

struct WhisperTextFormatter {
    static func format(_ text: String) -> String {
        var formattedText = text
        
        // First, replace commas with periods before new line/paragraph commands
        let commaPatterns = [
            // Replace comma before new paragraph
            (pattern: ",\\s*new\\s+paragraph", replacement: ". new paragraph"),
            // Replace comma before new line
            (pattern: ",\\s*new\\s+line", replacement: ". new line")
        ]
        
        for (pattern, replacement) in commaPatterns {
            formattedText = formattedText.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Handle single-word variants
        let singleWordPatterns = [
            (pattern: "\\b(newline)\\b", replacement: "new line"),
            (pattern: "\\b(newparagraph)\\b", replacement: "new paragraph")
        ]
        
        for (pattern, replacement) in singleWordPatterns {
            formattedText = formattedText.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Then handle the new line/paragraph commands with any combination of spaces and punctuation
        let patterns = [
            // Handle "new paragraph" with any combination of spaces and punctuation
            (pattern: "\\s*new\\s+paragraph\\s*[,.!?]?\\s*", replacement: "\n\n"),
            // Handle "new line" with any combination of spaces and punctuation
            (pattern: "\\s*new\\s+line\\s*[,.!?]?\\s*", replacement: "\n")
        ]
        
        for (pattern, replacement) in patterns {
            formattedText = formattedText.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Clean up any multiple consecutive newlines (more than 2)
        formattedText = formattedText.replacingOccurrences(
            of: "\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )
        
        return formattedText
    }
} 
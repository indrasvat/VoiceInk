import SwiftUI

/// A reusable grid component for selecting prompts with a plus button to add new ones
struct PromptSelectionGrid: View {
    @EnvironmentObject private var enhancementService: AIEnhancementService
    
    let selectedPromptId: UUID?
    let onPromptTap: (CustomPrompt) -> Void
    let onPromptEdit: (CustomPrompt) -> Void
    let onPromptDelete: (CustomPrompt) -> Void
    let onAddNew: () -> Void
    let assistantTriggerWord: String?
    
    init(
        selectedPromptId: UUID?,
        onPromptTap: @escaping (CustomPrompt) -> Void,
        onPromptEdit: @escaping (CustomPrompt) -> Void = { _ in },
        onPromptDelete: @escaping (CustomPrompt) -> Void = { _ in },
        onAddNew: @escaping () -> Void,
        assistantTriggerWord: String? = nil
    ) {
        self.selectedPromptId = selectedPromptId
        self.onPromptTap = onPromptTap
        self.onPromptEdit = onPromptEdit
        self.onPromptDelete = onPromptDelete
        self.onAddNew = onAddNew
        self.assistantTriggerWord = assistantTriggerWord
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if enhancementService.allPrompts.isEmpty {
                Text("No prompts available")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                let columns = [
                    GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 36)
                ]
                
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(enhancementService.allPrompts) { prompt in
                        prompt.promptIcon(
                            isSelected: selectedPromptId == prompt.id,
                            onTap: { 
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    onPromptTap(prompt)
                                }
                            },
                            onEdit: onPromptEdit,
                            onDelete: onPromptDelete,
                            assistantTriggerWord: assistantTriggerWord
                        )
                    }
                    
                    // Plus icon using the same styling as prompt icons
                    CustomPrompt.addNewButton {
                        onAddNew()
                    }
                    .help("Add new prompt")
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
        }
    }
}


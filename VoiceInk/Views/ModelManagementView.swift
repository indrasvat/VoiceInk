import SwiftUI
import SwiftData

struct ModelManagementView: View {
    @ObservedObject var whisperState: WhisperState
    @State private var modelToDelete: WhisperModel?
    @State private var customModelToDelete: CustomCloudModel?
    @State private var customModelToEdit: CustomCloudModel?
    @StateObject private var aiService = AIService()
    @StateObject private var customModelManager = CustomModelManager.shared
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @Environment(\.modelContext) private var modelContext
    @StateObject private var whisperPrompt = WhisperPrompt()

    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                defaultModelSection
                languageSelectionSection
                availableModelsSection
            }
            .padding(40)
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(NSColor.controlBackgroundColor))
        .alert(item: $modelToDelete) { model in
            Alert(
                title: Text("Delete Model"),
                message: Text("Are you sure you want to delete the model '\(model.name)'?"),
                primaryButton: .destructive(Text("Delete")) {
                    Task {
                        await whisperState.deleteModel(model)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .alert(item: $customModelToDelete) { model in
            Alert(
                title: Text("Delete Custom Model"),
                message: Text("Are you sure you want to delete the custom model '\(model.displayName)'?"),
                primaryButton: .destructive(Text("Delete")) {
                    customModelManager.removeCustomModel(withId: model.id)
                    // Update whisperState to refresh the UI
                    whisperState.refreshAllAvailableModels()
                },
                secondaryButton: .cancel()
            )
        }

    }
    
    private var defaultModelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default Model")
                .font(.headline)
                .foregroundColor(.secondary)
            Text(whisperState.currentTranscriptionModel?.displayName ?? "No model selected")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.windowBackgroundColor).opacity(0.4))
        .cornerRadius(10)
    }
    
    private var languageSelectionSection: some View {
        LanguageSelectionView(whisperState: whisperState, displayMode: .full, whisperPrompt: whisperPrompt)
    }
    
    private var availableModelsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Available Models")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("(\(whisperState.allAvailableModels.count))")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(whisperState.allAvailableModels, id: \.id) { model in
                    ModelCardRowView(
                        model: model,
                        isDownloaded: whisperState.availableModels.contains { $0.name == model.name },
                        isCurrent: whisperState.currentTranscriptionModel?.name == model.name,
                        downloadProgress: whisperState.downloadProgress,
                        modelURL: whisperState.availableModels.first { $0.name == model.name }?.url,
                        deleteAction: {
                            if model.provider == .custom, let customModel = model as? CustomCloudModel {
                                customModelToDelete = customModel
                            } else if let downloadedModel = whisperState.availableModels.first(where: { $0.name == model.name }) {
                                modelToDelete = downloadedModel
                            }
                        },
                        setDefaultAction: {
                            Task {
                                await whisperState.setDefaultTranscriptionModel(model)
                            }
                        },
                        downloadAction: {
                            if let localModel = model as? LocalModel {
                                Task {
                                    await whisperState.downloadModel(localModel)
                                }
                            }
                        },
                        editAction: model.provider == .custom ? { customModel in
                            customModelToEdit = customModel
                        } : nil
                    )
                }
                
                // Add Custom Model Card at the bottom
                AddCustomModelCardView(
                    customModelManager: customModelManager,
                    editingModel: customModelToEdit
                ) {
                    // Refresh the models when a new custom model is added
                    whisperState.refreshAllAvailableModels()
                    customModelToEdit = nil // Clear editing state
                }
            }
        }
        .padding()
    }
}

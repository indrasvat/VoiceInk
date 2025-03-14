import SwiftUI
import SwiftData

struct ModelManagementView: View {
    @ObservedObject var whisperState: WhisperState
    @State private var modelToDelete: WhisperModel?
    @StateObject private var aiService = AIService()
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @Environment(\.modelContext) private var modelContext
    
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
    }
    
    private var defaultModelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default Model")
                .font(.headline)
                .foregroundColor(.secondary)
            Text(whisperState.currentModel.flatMap { model in
                PredefinedModels.models.first { $0.name == model.name }?.displayName
            } ?? "No model selected")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.windowBackgroundColor).opacity(0.4))
        .cornerRadius(10)
    }
    
    private var languageSelectionSection: some View {
        LanguageSelectionView(whisperState: whisperState, displayMode: .full)
    }
    
    private var availableModelsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Available Models")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("(\(whisperState.predefinedModels.count))")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                Spacer()
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)], spacing: 16) {
                ForEach(whisperState.predefinedModels) { model in
                    modelCard(for: model)
                }
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor).opacity(0.4))
        .cornerRadius(10)
    }
    
    private func modelCard(for model: PredefinedModel) -> some View {
        let isDownloaded = whisperState.availableModels.contains { $0.name == model.name }
        let isCurrent = whisperState.currentModel?.name == model.name
        
        return VStack(alignment: .leading, spacing: 12) {
            // Model name and details
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.headline)
                    Text("\(model.size) • \(model.language)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                modelStatusBadge(isDownloaded: isDownloaded, isCurrent: isCurrent)
            }
            
            // Description
            Text(model.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            // Performance indicators
            HStack(spacing: 16) {
                performanceIndicator(label: "Speed", value: model.speed)
                performanceIndicator(label: "Accuracy", value: model.accuracy)
                ramUsageLabel(gb: model.ramUsage)
            }
            
            // Action buttons
            HStack {
                modelActionButton(isDownloaded: isDownloaded, isCurrent: isCurrent, model: model)
                
                if isDownloaded {
                    Menu {
                        Button(action: {
                            if let downloadedModel = whisperState.availableModels.first(where: { $0.name == model.name }) {
                                modelToDelete = downloadedModel
                            }
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button(action: {
                            if let downloadedModel = whisperState.availableModels.first(where: { $0.name == model.name }) {
                                NSWorkspace.shared.selectFile(downloadedModel.url.path, inFileViewerRootedAtPath: "")
                            }
                        }) {
                            Label("Show in Finder", systemImage: "folder")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.secondary)
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                    .frame(width: 30, height: 30)
                }
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor).opacity(0.9))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCurrent ? Color.accentColor : Color.gray.opacity(0.2), lineWidth: isCurrent ? 2 : 1)
        )
    }

    private func modelStatusBadge(isDownloaded: Bool, isCurrent: Bool) -> some View {
        Group {
            if isCurrent {
                Text("Default")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            } else if isDownloaded {
                Text("Downloaded")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }

    private func performanceIndicator(label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                ForEach(0..<5) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < Int(value * 5) ? performanceColor(value: value) : Color.secondary.opacity(0.2))
                        .frame(width: 16, height: 8)
                }
            }
            
            Text(String(format: "%.1f", value * 10))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func performanceColor(value: Double) -> Color {
        switch value {
        case 0.8...: return .green
        case 0.6..<0.8: return .yellow
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }
    
    private func modelActionButton(isDownloaded: Bool, isCurrent: Bool, model: PredefinedModel) -> some View {
        Group {
            if isCurrent {
                Text("Default Model")
                    .foregroundColor(.white)
            } else if isDownloaded {
                Button("Set as Default") {
                    if let downloadedModel = whisperState.availableModels.first(where: { $0.name == model.name }) {
                        Task {
                            await whisperState.setDefaultModel(downloadedModel)
                        }
                    }
                }
                .foregroundColor(.white)
            } else if whisperState.downloadProgress[model.name] != nil {
                VStack {
                    ProgressView(value: whisperState.downloadProgress[model.name] ?? 0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .animation(.linear, value: whisperState.downloadProgress[model.name])
                    Text("\(Int((whisperState.downloadProgress[model.name] ?? 0) * 100))%")
                        .font(.caption)
                        .animation(.none)
                }
            } else {
                Button("Download Model") {
                    Task {
                        await whisperState.downloadModel(model)
                    }
                }
                .foregroundColor(.white)
            }
        }
        .buttonStyle(GradientButtonStyle(isDownloaded: isDownloaded, isCurrent: isCurrent))
        .frame(maxWidth: .infinity)
    }

    private func ramUsageLabel(gb: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("RAM")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(formatRAMSize(gb))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primary)
        }
    }

    private func formatRAMSize(_ gb: Double) -> String {
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        } else {
            return String(format: "%d MB", Int(gb * 1024))
        }
    }
}

struct GradientButtonStyle: ButtonStyle {
    let isDownloaded: Bool
    let isCurrent: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(
                Group {
                    if isCurrent {
                        LinearGradient(gradient: Gradient(colors: [Color.green, Color.green.opacity(0.7)]), startPoint: .top, endPoint: .bottom)
                    } else if isDownloaded {
                        LinearGradient(gradient: Gradient(colors: [Color.purple, Color.purple.opacity(0.7)]), startPoint: .top, endPoint: .bottom)
                    } else {
                        LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]), startPoint: .top, endPoint: .bottom)
                    }
                }
            )
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

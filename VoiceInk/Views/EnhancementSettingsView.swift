import SwiftUI

struct EnhancementSettingsView: View {
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @State private var isEditingPrompt = false
    @State private var isSettingsExpanded = true
    @State private var selectedPromptForEdit: CustomPrompt?
    @State private var isEditingTriggerWord = false
    @State private var tempTriggerWord = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Main Settings Sections
                VStack(spacing: 24) {
                    // Enable/Disable Toggle Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Enable Enhancement")
                                        .font(.headline)
                                    
                                    InfoTip(
                                        title: "AI Enhancement",
                                        message: "AI enhancement lets you pass the transcribed audio through LLMS to post-process using different prompts suitable for different use cases like e-mails, summary, writing, etc.",
                                        learnMoreURL: "https://www.youtube.com/@tryvoiceink/videos"
                                    )
                                }
                                
                                Text("Turn on AI-powered enhancement features")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $enhancementService.isEnhancementEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .labelsHidden()
                                .scaleEffect(1.2)
                        }
                        
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Clipboard Context", isOn: $enhancementService.useClipboardContext)
                                    .toggleStyle(.switch)
                                    .disabled(!enhancementService.isEnhancementEnabled)
                                Text("Use text from clipboard to understand the context")
                                    .font(.caption)
                                    .foregroundColor(enhancementService.isEnhancementEnabled ? .secondary : .secondary.opacity(0.5))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Context Awareness", isOn: $enhancementService.useScreenCaptureContext)
                                    .toggleStyle(.switch)
                                    .disabled(!enhancementService.isEnhancementEnabled)
                                Text("Learn what is on the screen to understand the context")
                                    .font(.caption)
                                    .foregroundColor(enhancementService.isEnhancementEnabled ? .secondary : .secondary.opacity(0.5))
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.windowBackgroundColor).opacity(0.4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                    )
                    
                    // 1. AI Provider Integration Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("AI Provider Integration")
                            .font(.headline)
                        
                        APIKeyManagementView()
                            .background(Color(.windowBackgroundColor).opacity(0.4))
                            .cornerRadius(10)
                    }
                    .padding()
                    .background(Color(.windowBackgroundColor).opacity(0.4))
                    .cornerRadius(10)
                    
                    // 3. Enhancement Modes & Assistant Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Enhancement Prompt")
                            .font(.headline)
                        
                        // Prompts Section
                        VStack(alignment: .leading, spacing: 12) {
                            PromptSelectionGrid(
                                selectedPromptId: enhancementService.selectedPromptId,
                                onPromptTap: { prompt in
                                    enhancementService.setActivePrompt(prompt)
                                },
                                onPromptEdit: { prompt in
                                    selectedPromptForEdit = prompt
                                },
                                onPromptDelete: { prompt in
                                    enhancementService.deletePrompt(prompt)
                                },
                                onAddNew: {
                                    isEditingPrompt = true
                                },
                                assistantTriggerWord: enhancementService.assistantTriggerWord
                            )
                        }
                        
                        Divider()
                        
                        // Assistant Mode Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Assistant Prompt")
                                    .font(.subheadline)
                                Image(systemName: "sparkles")
                                    .foregroundColor(.accentColor)
                            }
                            
                            Text("Configure how to trigger the AI assistant mode")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Current Trigger:")
                                        .font(.subheadline)
                                    Text("\"\(enhancementService.assistantTriggerWord)\"")
                                        .font(.system(.subheadline, design: .monospaced))
                                        .foregroundColor(.accentColor)
                                }
                                
                                if isEditingTriggerWord {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            TextField("New trigger word", text: $tempTriggerWord)
                                                .textFieldStyle(.roundedBorder)
                                                .frame(maxWidth: 200)
                                            
                                            Button("Save") {
                                                enhancementService.assistantTriggerWord = tempTriggerWord
                                                isEditingTriggerWord = false
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .disabled(tempTriggerWord.isEmpty)
                                            
                                            Button("Cancel") {
                                                isEditingTriggerWord = false
                                                tempTriggerWord = enhancementService.assistantTriggerWord
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                        
                                        Text("Default: \"hey\"")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Button("Change Trigger Word") {
                                        tempTriggerWord = enhancementService.assistantTriggerWord
                                        isEditingTriggerWord = true
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            
                            Text("Start with \"\(enhancementService.assistantTriggerWord), \" to use AI assistant mode")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Instead of enhancing the text, VoiceInk will respond like a conversational AI assistant")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.windowBackgroundColor).opacity(0.4))
                    .cornerRadius(10)
                }
            }
            .padding(24)
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $isEditingPrompt) {
            PromptEditorView(mode: .add)
        }
        .sheet(item: $selectedPromptForEdit) { prompt in
            PromptEditorView(mode: .edit(prompt))
        }
    }
}

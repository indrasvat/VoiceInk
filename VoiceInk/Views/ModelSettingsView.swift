import SwiftUI

struct ModelSettingsView: View {
    @ObservedObject var whisperPrompt: WhisperPrompt
    @AppStorage("SelectedLanguage") private var selectedLanguage: String = "en"
    @AppStorage("IsTextFormattingEnabled") private var isTextFormattingEnabled = true
    @AppStorage("IsVADEnabled") private var isVADEnabled = true
    @AppStorage("AppendTrailingSpace") private var appendTrailingSpace = true
    @AppStorage("PrewarmModelOnWake") private var prewarmModelOnWake = true

    // VAD timing configuration (lower values = faster response, higher = better noise filtering)
    @AppStorage("VADMinSpeechDurationMs") private var vadMinSpeechDurationMs: Int = 50
    @AppStorage("VADMinSilenceDurationMs") private var vadMinSilenceDurationMs: Int = 80
    @AppStorage("VADSpeechPadMs") private var vadSpeechPadMs: Int = 100

    @State private var customPrompt: String = ""
    @State private var isEditing: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Output Format")
                    .font(.headline)
                
                InfoTip(
                    title: "Output Format Guide",
                    message: "Unlike GPT, Voice Models(whisper) follows the style of your prompt rather than instructions. Use examples of your desired output format instead of commands.",
                    learnMoreURL: "https://cookbook.openai.com/examples/whisper_prompting_guide#comparison-with-gpt-prompting"
                )
                
                Spacer()
                
                Button(action: {
                    if isEditing {
                        // Save changes
                        whisperPrompt.setCustomPrompt(customPrompt, for: selectedLanguage)
                        isEditing = false
                    } else {
                        // Enter edit mode
                        customPrompt = whisperPrompt.getLanguagePrompt(for: selectedLanguage)
                        isEditing = true
                    }
                }) {
                    Text(isEditing ? "Save" : "Edit")
                        .font(.caption)
                }
            }
            
            if isEditing {
                TextEditor(text: $customPrompt)
                    .font(.system(size: 12))
                    .padding(8)
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                
            } else {
                Text(whisperPrompt.getLanguagePrompt(for: selectedLanguage))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.windowBackgroundColor).opacity(0.4))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            }

            Divider().padding(.vertical, 4)

            HStack {
                Toggle(isOn: $appendTrailingSpace) {
                    Text("Add space after paste")
                }
                .toggleStyle(.switch)
                
                InfoTip(
                    title: "Trailing Space",
                    message: "Automatically add a space after pasted text. Useful for space-delimited languages."
                )
            }

            HStack {
                Toggle(isOn: $isTextFormattingEnabled) {
                    Text("Automatic text formatting")
                }
                .toggleStyle(.switch)
                
                InfoTip(
                    title: "Automatic Text Formatting",
                    message: "Apply intelligent text formatting to break large block of text into paragraphs."
                )
            }

            HStack {
                Toggle(isOn: $isVADEnabled) {
                    Text("Voice Activity Detection (VAD)")
                }
                .toggleStyle(.switch)

                InfoTip(
                    title: "Voice Activity Detection",
                    message: "Detect speech segments and filter out silence to improve accuracy of local models."
                )
            }

            // VAD timing sliders (only shown when VAD is enabled)
            if isVADEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    // Min speech duration slider
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Min speech duration")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(vadMinSpeechDurationMs) ms")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: Binding(
                                get: { Double(vadMinSpeechDurationMs) },
                                set: { vadMinSpeechDurationMs = Int($0) }
                            ),
                            in: 10...500,
                            step: 10
                        )
                    }

                    // Min silence duration slider
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Min silence duration")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(vadMinSilenceDurationMs) ms")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: Binding(
                                get: { Double(vadMinSilenceDurationMs) },
                                set: { vadMinSilenceDurationMs = Int($0) }
                            ),
                            in: 20...500,
                            step: 10
                        )
                    }

                    // Speech padding slider
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Speech padding")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(vadSpeechPadMs) ms")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: Binding(
                                get: { Double(vadSpeechPadMs) },
                                set: { vadSpeechPadMs = Int($0) }
                            ),
                            in: 10...300,
                            step: 10
                        )
                    }

                    Text("Lower values = faster response for short utterances. Higher values = better noise filtering.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 16)
            }

            HStack {
                Toggle(isOn: $prewarmModelOnWake) {
                    Text("Prewarm model (Experimental)")
                }
                .toggleStyle(.switch)

                InfoTip(
                    title: "Prewarm Model (Experimental)",
                    message: "Turn this on if transcriptions with local models are taking longer than expected. Runs silent background transcription on app launch and wake to trigger optimization."
                )
            }

        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        // Reset the editor when language changes
        .onChange(of: selectedLanguage) { oldValue, newValue in
            if isEditing {
                customPrompt = whisperPrompt.getLanguagePrompt(for: selectedLanguage)
            }
        }
    }
} 

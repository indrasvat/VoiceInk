import SwiftUI
import LaunchAtLogin

struct MenuBarView: View {
    @EnvironmentObject var whisperState: WhisperState
    @EnvironmentObject var hotkeyManager: HotkeyManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    @EnvironmentObject var updaterViewModel: UpdaterViewModel
    @EnvironmentObject var enhancementService: AIEnhancementService
    @EnvironmentObject var aiService: AIService
    @State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled
    
    var body: some View {
        VStack {
            Button("Toggle Mini Recorder") {
                Task {
                    await whisperState.toggleMiniRecorder()
                }
            }
            
            Toggle("AI Enhancement", isOn: $enhancementService.isEnhancementEnabled)
            
            Menu {
                ForEach(aiService.connectedProviders, id: \.self) { provider in
                    Button {
                        aiService.selectedProvider = provider
                    } label: {
                        HStack {
                            Text(provider.rawValue)
                            if aiService.selectedProvider == provider {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                if aiService.connectedProviders.isEmpty {
                    Text("No providers connected")
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                Button("Manage AI Providers") {
                    menuBarManager.openMainWindowAndNavigate(to: "Enhancement")
                }
            } label: {
                HStack {
                    Text("AI Provider: \(aiService.selectedProvider.rawValue)")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }
            
            Menu {
                ForEach(whisperState.availableModels) { model in
                    Button {
                        Task {
                            await whisperState.setDefaultModel(model)
                        }
                    } label: {
                        HStack {
                            Text(PredefinedModels.models.first { $0.name == model.name }?.displayName ?? model.name)
                            if whisperState.currentModel?.name == model.name {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                if whisperState.availableModels.isEmpty {
                    Text("No models downloaded")
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                Button("Manage Models") {
                    menuBarManager.openMainWindowAndNavigate(to: "AI Models")
                }
            } label: {
                HStack {
                    Text("Model: \(PredefinedModels.models.first { $0.name == whisperState.currentModel?.name }?.displayName ?? "None")")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }
            
            Toggle("Use Clipboard Context", isOn: $enhancementService.useClipboardContext)
                .disabled(!enhancementService.isEnhancementEnabled)
            
            Toggle("Use Screen Context", isOn: $enhancementService.useScreenCaptureContext)
                .disabled(!enhancementService.isEnhancementEnabled)
            
            Menu("Additional") {
                Toggle("Auto-copy to Clipboard", isOn: $whisperState.isAutoCopyEnabled)
                
                Toggle("Sound Feedback", isOn: .init(
                    get: { SoundManager.shared.isEnabled },
                    set: { SoundManager.shared.isEnabled = $0 }
                ))
                
                Toggle("Pause Media During Recording", isOn: .init(
                    get: { MediaController.shared.isMediaPauseEnabled },
                    set: { MediaController.shared.isMediaPauseEnabled = $0 }
                ))
            }
            
            Divider()
            
            Button("History") {
                menuBarManager.openMainWindowAndNavigate(to: "History")
            }
            
            Button("Settings") {
                menuBarManager.openMainWindowAndNavigate(to: "Settings")
            }
            
            Button(menuBarManager.isMenuBarOnly ? "Show Dock Icon" : "Hide Dock Icon") {
                menuBarManager.toggleMenuBarOnly()
            }
            
            Toggle("Launch at Login", isOn: $launchAtLoginEnabled)
                .onChange(of: launchAtLoginEnabled) { newValue in
                    LaunchAtLogin.isEnabled = newValue
                }
            
            Divider()
            
            Button("Check for Updates") {
                updaterViewModel.checkForUpdates()
            }
            .disabled(!updaterViewModel.canCheckForUpdates)
            
            Button("About VoiceInk") {
                NSApplication.shared.orderFrontStandardAboutPanel(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            
            Button("Help and Support") {
                openMailForSupport()
            }
            
            Divider()
            
            Button("Quit VoiceInk") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    private func openMailForSupport() {
        let subject = "VoiceInk Help & Support"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailtoURL = URL(string: "mailto:prakashjoshipax@gmail.com?subject=\(encodedSubject)")!
        NSWorkspace.shared.open(mailtoURL)
    }
}

import Foundation
import KeyboardShortcuts
import Carbon
import AppKit

extension KeyboardShortcuts.Name {
    static let toggleMiniRecorder = Self("toggleMiniRecorder")
    static let escapeRecorder = Self("escapeRecorder")
    static let toggleEnhancement = Self("toggleEnhancement")
    // Prompt selection shortcuts
    static let selectPrompt1 = Self("selectPrompt1")
    static let selectPrompt2 = Self("selectPrompt2")
    static let selectPrompt3 = Self("selectPrompt3")
    static let selectPrompt4 = Self("selectPrompt4")
    static let selectPrompt5 = Self("selectPrompt5")
    static let selectPrompt6 = Self("selectPrompt6")
    static let selectPrompt7 = Self("selectPrompt7")
    static let selectPrompt8 = Self("selectPrompt8")
    static let selectPrompt9 = Self("selectPrompt9")
}

// State machine enum for recorder state
enum RecorderState {
    case idle                // Not recording, recorder not visible
    case recording           // Actively recording with key held down
    case lockedRecording     // Recording in locked mode (after double press)
}

@MainActor
class HotkeyManager: ObservableObject {
    @Published var isListening = false
    @Published var isShortcutConfigured = false
    @Published var isPushToTalkEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isPushToTalkEnabled, forKey: "isPushToTalkEnabled")
            resetKeyStates()
            setupKeyMonitor()
        }
    }
    @Published var pushToTalkKey: PushToTalkKey {
        didSet {
            UserDefaults.standard.set(pushToTalkKey.rawValue, forKey: "pushToTalkKey")
            resetKeyStates()
        }
    }
    
    private var whisperState: WhisperState
    private var currentKeyState = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var visibilityTask: Task<Void, Never>?
    
    // State machine properties
    private var recorderState: RecorderState = .idle
    private var lastKeyPressTime: Date?
    private var keyPressStartTime: Date?  // Track when key was pressed for duration calculation
    private let doublePressThreshold = 0.3  // 300ms for double-press detection
    private let briefPressThreshold = 1.0 // 1000ms threshold for brief press
    
    enum PushToTalkKey: String, CaseIterable {
        case rightOption = "rightOption"
        case fn = "fn"
        case rightCommand = "rightCommand"
        case rightShift = "rightShift"
        
        var displayName: String {
            switch self {
            case .rightOption: return "Right Option (⌥)"
            case .fn: return "Fn"
            case .rightCommand: return "Right Command (⌘)"
            case .rightShift: return "Right Shift (⇧)"
            }
        }
        
        var keyCode: CGKeyCode {
            switch self {
            case .rightOption: return 0x3D
            case .fn: return 0x3F
            case .rightCommand: return 0x36
            case .rightShift: return 0x3C
            }
        }
        
        var flags: CGEventFlags {
            switch self {
            case .rightOption: return .maskAlternate
            case .fn: return .maskSecondaryFn
            case .rightCommand: return .maskCommand
            case .rightShift: return .maskShift
            }
        }
    }
    
    init(whisperState: WhisperState) {
        self.isPushToTalkEnabled = UserDefaults.standard.bool(forKey: "isPushToTalkEnabled")
        self.pushToTalkKey = PushToTalkKey(rawValue: UserDefaults.standard.string(forKey: "pushToTalkKey") ?? "") ?? .rightCommand
        self.whisperState = whisperState
        
        updateShortcutStatus()
        setupEnhancementShortcut()
        setupVisibilityObserver()
    }
    
    private func resetKeyStates() {
        currentKeyState = false
        lastKeyPressTime = nil
        recorderState = .idle
    }
    
    private func setupVisibilityObserver() {
        visibilityTask = Task { @MainActor in
            for await isVisible in whisperState.$isMiniRecorderVisible.values {
                if isVisible {
                    setupEscapeShortcut()
                    KeyboardShortcuts.setShortcut(.init(.e, modifiers: .command), for: .toggleEnhancement)
                    setupPromptShortcuts()
                } else {
                    removeEscapeShortcut()
                    removeEnhancementShortcut()
                    removePromptShortcuts()
                    // Ensure state is reset when recorder is dismissed externally
                    if recorderState != .idle {
                        recorderState = .idle
                    }
                }
            }
        }
    }
    
    private func setupKeyMonitor() {
        removeKeyMonitor()
        
        guard isPushToTalkEnabled else { return }
        guard AXIsProcessTrusted() else { return }
        
        let eventMask = (1 << CGEventType.flagsChanged.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon!).takeUnretainedValue()
                
                if type == .flagsChanged {
                    Task { @MainActor in
                        await manager.handleKeyEvent(event)
                    }
                }
                
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }
        
        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let runLoopSource = self.runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
    
    private func removeKeyMonitor() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let runLoopSource = self.runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            }
            self.eventTap = nil
            self.runLoopSource = nil
        }
    }
    
    private func handleKeyEvent(_ event: CGEvent) async {
        let flags = event.flags
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        
        let isKeyPressed = flags.contains(pushToTalkKey.flags)
        let isTargetKey = pushToTalkKey == .fn ? true : keycode == pushToTalkKey.keyCode
        
        guard isTargetKey else { return }
        guard isKeyPressed != currentKeyState else { return }
        
        currentKeyState = isKeyPressed
        
        if isKeyPressed {
            await handleKeyPress()
        } else {
            await handleKeyRelease()
        }
    }
    
    private func handleKeyPress() async {
        let now = Date()
        keyPressStartTime = now  // Track when the key was pressed
        
        switch recorderState {
        case .idle:
            // Start recording
            recorderState = .recording
            if !whisperState.isMiniRecorderVisible {
                await whisperState.handleToggleMiniRecorder()
            }
            
        case .recording:
            // This shouldn't happen in normal flow
            break
            
        case .lockedRecording:
            // If in locked recording, pressing the key again should stop recording
            recorderState = .idle
            await whisperState.handleToggleMiniRecorder()
        }
        
        // Check for double press
        if let lastPress = lastKeyPressTime, 
           now.timeIntervalSince(lastPress) < doublePressThreshold {
            // Double press detected, transition to locked recording
            recorderState = .lockedRecording
        }
        
        lastKeyPressTime = now
    }
    
    private func handleKeyRelease() async {
        let now = Date()
        
        switch recorderState {
        case .idle:
            // This shouldn't happen in normal flow
            break
            
        case .recording:
            // Check if this was a brief press
            if let startTime = keyPressStartTime, 
               now.timeIntervalSince(startTime) < briefPressThreshold {
                // Brief press - dismiss without transcribing
                recorderState = .idle
                await whisperState.dismissMiniRecorder()
            } else {
                // Normal release - stop recording and transcribe
                recorderState = .idle
                await whisperState.handleToggleMiniRecorder()
            }
            
        case .lockedRecording:
            // When in locked recording, key release does nothing
            // Stay in locked recording state
            break
        }
        
        keyPressStartTime = nil  // Reset press start time
    }
    
    private func setupEscapeShortcut() {
        KeyboardShortcuts.setShortcut(.init(.escape), for: .escapeRecorder)
        KeyboardShortcuts.onKeyDown(for: .escapeRecorder) { [weak self] in
            Task { @MainActor in
                guard let self = self,
                      await self.whisperState.isMiniRecorderVisible else { return }
                
                // Reset state machine when using Escape key
                self.recorderState = .idle
                
                SoundManager.shared.playEscSound()
                await self.whisperState.dismissMiniRecorder()
            }
        }
    }
    
    private func removeEscapeShortcut() {
        KeyboardShortcuts.setShortcut(nil, for: .escapeRecorder)
    }
    
    private func setupEnhancementShortcut() {
        KeyboardShortcuts.onKeyDown(for: .toggleEnhancement) { [weak self] in
            Task { @MainActor in
                guard let self = self,
                      await self.whisperState.isMiniRecorderVisible,
                      let enhancementService = await self.whisperState.getEnhancementService() else { return }
                enhancementService.isEnhancementEnabled.toggle()
            }
        }
    }
    private func setupPromptShortcuts() {
        // Set up Command+1 through Command+9 shortcuts with proper key definitions
        KeyboardShortcuts.setShortcut(.init(.one, modifiers: .command), for: .selectPrompt1)
        KeyboardShortcuts.setShortcut(.init(.two, modifiers: .command), for: .selectPrompt2)
        KeyboardShortcuts.setShortcut(.init(.three, modifiers: .command), for: .selectPrompt3)
        KeyboardShortcuts.setShortcut(.init(.four, modifiers: .command), for: .selectPrompt4)
        KeyboardShortcuts.setShortcut(.init(.five, modifiers: .command), for: .selectPrompt5)
        KeyboardShortcuts.setShortcut(.init(.six, modifiers: .command), for: .selectPrompt6)
        KeyboardShortcuts.setShortcut(.init(.seven, modifiers: .command), for: .selectPrompt7)
        KeyboardShortcuts.setShortcut(.init(.eight, modifiers: .command), for: .selectPrompt8)
        KeyboardShortcuts.setShortcut(.init(.nine, modifiers: .command), for: .selectPrompt9)
        
        // Setup handlers for each shortcut
        setupPromptHandler(for: .selectPrompt1, index: 0)
        setupPromptHandler(for: .selectPrompt2, index: 1)
        setupPromptHandler(for: .selectPrompt3, index: 2)
        setupPromptHandler(for: .selectPrompt4, index: 3)
        setupPromptHandler(for: .selectPrompt5, index: 4)
        setupPromptHandler(for: .selectPrompt6, index: 5)
        setupPromptHandler(for: .selectPrompt7, index: 6)
        setupPromptHandler(for: .selectPrompt8, index: 7)
        setupPromptHandler(for: .selectPrompt9, index: 8)
    }
    
    private func setupPromptHandler(for shortcutName: KeyboardShortcuts.Name, index: Int) {
        KeyboardShortcuts.onKeyDown(for: shortcutName) { [weak self] in
            Task { @MainActor in
                guard let self = self,
                      await self.whisperState.isMiniRecorderVisible,
                      let enhancementService = await self.whisperState.getEnhancementService() else { return }
                
                let prompts = enhancementService.allPrompts
                if index < prompts.count {
                    // Enable AI enhancement if it's not already enabled
                    if !enhancementService.isEnhancementEnabled {
                        enhancementService.isEnhancementEnabled = true
                    }
                    // Switch to the selected prompt
                    enhancementService.setActivePrompt(prompts[index])
                }
            }
        }
    }
    
    private func removePromptShortcuts() {
        // Remove Command+1 through Command+9 shortcuts
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt1)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt2)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt3)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt4)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt5)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt6)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt7)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt8)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt9)
    }
    
    private func removeEnhancementShortcut() {
        KeyboardShortcuts.setShortcut(nil, for: .toggleEnhancement)
    }
    
    func updateShortcutStatus() {
        isShortcutConfigured = KeyboardShortcuts.getShortcut(for: .toggleMiniRecorder) != nil
        if isShortcutConfigured {
            setupShortcutHandler()
            setupKeyMonitor()
        } else {
            removeKeyMonitor()
        }
    }
    
    private func setupShortcutHandler() {
        KeyboardShortcuts.onKeyUp(for: .toggleMiniRecorder) { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                
                // Update state when using the main shortcut
                if self.recorderState == .idle {
                    self.recorderState = .recording
                } else {
                    self.recorderState = .idle
                }
                
                await self.whisperState.handleToggleMiniRecorder()
            }
        }
    }
    
    deinit {
        visibilityTask?.cancel()
        Task { @MainActor in
            removeKeyMonitor()
            removeEscapeShortcut()
            removeEnhancementShortcut()
        }
    }
}

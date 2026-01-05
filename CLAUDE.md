# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Complete build (first-time setup - builds whisper.cpp framework and VoiceInk)
make all

# Development workflow (build and run)
make dev

# Build commands
make build            # Build debug (alias for build-debug)
make build-debug      # Build Debug configuration (unsigned, dev icon, license bypassed)
make build-release    # Build Release configuration (unsigned, production icon)
make install          # Build release and install to ~/Applications
make install-local    # Build debug and install to ~/Applications (dev icon, no license)

# Utility commands
make check            # Verify prerequisites (git, xcodebuild, swift)
make whisper          # Clone and build whisper.cpp XCFramework
make run              # Launch the built app
make open             # Open project in Xcode
make list             # List available Xcode schemes
make clean            # Remove whisper dependencies
make clean-derived    # Remove Xcode DerivedData for this project
make help             # Show all available targets
```

The Makefile manages the whisper.cpp dependency in `~/VoiceInk-Dependencies/` and handles framework linking automatically.

## Local Development Setup

Debug and Release builds have different configurations:

| Aspect | Debug | Release |
|--------|-------|---------|
| App Icon | `AppIcon-Dev` (purple + DEV ribbon) | `AppIcon` (original) |
| License Check | Bypassed via `LOCAL_BUILD` flag | Full license validation |
| Code Signing | Unsigned (local use only) | Unsigned (local use only) |

**Compile-time flag**: Debug builds define `LOCAL_BUILD` which conditionally bypasses license checks in `LicenseViewModel.swift`.

**Typical workflow**:
```bash
make dev              # Build debug and run (dev icon, no license check)
make install          # Build release to ~/Applications (production icon)
```

## Architecture Overview

VoiceInk is a native macOS voice-to-text application built with SwiftUI and SwiftData.

### Core Components

**Entry Point & App Structure** (`VoiceInk.swift`):
- `VoiceInkApp` is the `@main` entry point using SwiftUI App lifecycle
- Initializes SwiftData `ModelContainer` with two stores: transcriptions (`default.store`) and dictionary (`dictionary.store`)
- Creates and wires together all major services as `@StateObject` instances
- Handles onboarding flow and menu bar integration via `MenuBarExtra`

**State Management**:
- `WhisperState` - Central state machine for recording/transcription workflow. Manages `RecordingState` (idle, recording, transcribing, enhancing, busy) and coordinates between audio recording, model loading, and transcription services
- `HotkeyManager` - Global keyboard shortcut handling using KeyboardShortcuts library. Supports modifier keys (Fn, Option), middle-click, and custom shortcuts
- `PowerModeManager` - Singleton managing context-aware configurations that auto-apply settings based on active app or URL

### Transcription Pipeline

**Model Types** (`Models/TranscriptionModel.swift`):
- `TranscriptionModel` protocol unifies all model types
- `ModelProvider` enum: `local`, `parakeet`, `groq`, `elevenLabs`, `deepgram`, `mistral`, `gemini`, `soniox`, `custom`, `nativeApple`
- Concrete types: `LocalModel` (Whisper.cpp), `ParakeetModel`, `CloudModel`, `CustomCloudModel`, `NativeAppleModel`, `ImportedLocalModel`

**Transcription Services** (`Services/`):
- `TranscriptionService` protocol defines the interface for all transcription backends
- `TranscriptionServiceRegistry` - Factory for obtaining appropriate service based on model provider
- Local: `LocalTranscriptionService`, `ParakeetTranscriptionService`, `NativeAppleTranscriptionService`
- Cloud: Individual services in `Services/CloudTranscription/` (Groq, Deepgram, ElevenLabs, etc.)

**Whisper Integration** (`Whisper/`):
- `WhisperState` extensions handle model management, downloading, and loading
- `LibWhisper.swift` - Swift wrapper for whisper.cpp C API
- `WhisperPrompt` - Manages vocabulary/prompt context for improved accuracy

### AI Enhancement

**Services** (`Services/AIEnhancement/`):
- `AIService` - Manages AI provider connections (OpenAI, Anthropic, Gemini, Ollama, etc.)
- `AIEnhancementService` - Post-transcription text enhancement using LLMs
- Supports screen capture context via `ScreenCaptureService` for context-aware enhancements

### Power Mode System

**Location**: `PowerMode/`

Context-aware configuration system that auto-applies settings based on active application or browser URL:
- `PowerModeConfig` - Configuration struct with app/URL triggers, AI settings, prompt selection
- `PowerModeManager` - Singleton managing all configurations, loads from `UserDefaults.standard`
- `ActiveWindowService` - Monitors frontmost app and browser URLs
- `PowerModeShortcutManager` - Per-configuration keyboard shortcuts

#### Creating Power Modes Programmatically

Power Mode configurations are stored in `UserDefaults.standard` as JSON-encoded `Data` (not String) under the key `powerModeConfigurationsV2`.

**Critical requirements:**
1. **UUIDs must be valid format**: 8-4-4-4-12 hex characters (e.g., `A1B2C3D4-E5F6-7890-ABCD-EF1234567890`)
2. **Store as Data type**: Use `data(using: .utf8)` on JSON string, then `UserDefaults.set(data, forKey:)`
3. **Write directly to plist**: From CLI, write to `~/Library/Preferences/com.prakashjoshipax.VoiceInk.plist`
4. **Clear cache after writing**: Run `killall cfprefsd` to flush preferences daemon cache
5. **Preserve existing modes**: Always read existing configurations first and append new modes to the array. Writing a new array will **overwrite and delete** all existing Power Modes!

**PowerModeConfig JSON schema:**
```json
{
  "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",  // Valid UUID format required!
  "name": "Mode Name",
  "emoji": "💻",
  "appConfigs": [
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "bundleIdentifier": "com.example.App",
      "appName": "App Name"
    }
  ],
  "urlConfigs": [
    {
      "id": "22222222-2222-2222-2222-222222222222",
      "url": "example.com"
    }
  ],
  "isAIEnhancementEnabled": true,
  "selectedPrompt": null,
  "selectedTranscriptionModelName": null,
  "selectedLanguage": "en",
  "useScreenCapture": true,
  "selectedAIProvider": null,
  "selectedAIModel": null,
  "isAutoSendEnabled": false,
  "isEnabled": true,
  "isDefault": false,
  "hotkeyShortcut": null
}
```

**Example Swift script to add a Power Mode (preserving existing):**
```swift
import Foundation

let plistPath = NSString(string: "~/Library/Preferences/com.prakashjoshipax.VoiceInk.plist").expandingTildeInPath

// 1. Read existing plist and configurations
guard let plistData = FileManager.default.contents(atPath: plistPath),
      var plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
    print("❌ Could not read plist"); exit(1)
}

// 2. Decode existing Power Modes
var existingConfigs: [[String: Any]] = []
if let configData = plist["powerModeConfigurationsV2"] as? Data,
   let configs = try? JSONSerialization.jsonObject(with: configData) as? [[String: Any]] {
    existingConfigs = configs
}

// 3. Create new Power Mode
let newConfig: [String: Any?] = [
    "id": "FA57D1C7-0000-0000-0000-000000000001",
    "name": "Fast Dictation",
    "emoji": "⚡",
    "appConfigs": [["id": "AAAA0000-0000-0000-0000-000000000001", "bundleIdentifier": "dev.warp.Warp-Stable", "appName": "Warp"]],
    "urlConfigs": [],
    "isAIEnhancementEnabled": false,
    "selectedPrompt": nil,
    "selectedTranscriptionModelName": nil,
    "selectedLanguage": "en",
    "useScreenCapture": false,
    "selectedAIProvider": nil,
    "selectedAIModel": nil,
    "isAutoSendEnabled": false,
    "isEnabled": true,
    "isDefault": false,
    "hotkeyShortcut": nil
]

// 4. Append new config (avoid duplicates by ID)
let newId = newConfig["id"] as? String
if !existingConfigs.contains(where: { $0["id"] as? String == newId }) {
    existingConfigs.append(newConfig.compactMapValues { $0 })
}

// 5. Encode and write back
if let jsonData = try? JSONSerialization.data(withJSONObject: existingConfigs),
   let jsonString = String(data: jsonData, encoding: .utf8),
   let outputData = jsonString.data(using: .utf8) {
    plist["powerModeConfigurationsV2"] = outputData
    if let output = try? PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0) {
        try? output.write(to: URL(fileURLWithPath: plistPath))
        print("✅ Added Power Mode (total: \(existingConfigs.count))")
    }
}
// Then run: killall cfprefsd && restart VoiceInk
```

**Finding app bundle identifiers:**
```bash
# Search for app
mdfind "kMDItemDisplayName == 'AppName'" -onlyin /Applications

# Get bundle ID
defaults read /Applications/AppName.app/Contents/Info.plist CFBundleIdentifier
```

### Data Persistence

**SwiftData Models** (`Models/`):
- `Transcription` - Saved transcription records
- `VocabularyWord` - Custom vocabulary for improved recognition
- `WordReplacement` - Text replacement rules post-transcription

### UI Layer

**Views Structure**:
- `ContentView` - Main navigation container
- `Views/Recorder/` - Mini recorder and notch recorder UIs
- `Views/Settings/` - Settings panels
- `Views/History/` - Transcription history browser
- `WindowManager` - Manages main window, mini recorder panels

### Key Dependencies

- **whisper.cpp** - Local speech recognition (built via `make whisper`)
- **FluidAudio** - Parakeet model implementation
- **Sparkle** - Auto-updates
- **KeyboardShortcuts** - Global hotkey handling
- **SwiftData** - Persistence layer

## Requirements

- macOS 14.0+
- Xcode (latest recommended)
- Swift (latest recommended)

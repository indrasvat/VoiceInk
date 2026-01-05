import SwiftUI
import AppKit
import Speech

// MARK: - Streaming Model Card View
struct StreamingModelCardView: View {
    let model: StreamingModel
    let isCurrent: Bool
    var setDefaultAction: () -> Void

    @StateObject private var authStatus = SpeechAuthorizationStatus()

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Main Content
            VStack(alignment: .leading, spacing: 6) {
                headerSection
                metadataSection
                descriptionSection

                if authStatus.status != .authorized {
                    permissionSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Action Controls
            actionSection
        }
        .padding(16)
        .background(CardBackground(isSelected: isCurrent, useAccentGradientWhenSelected: isCurrent))
        .onAppear {
            authStatus.update()
        }
    }

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(model.displayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.labelColor))

            statusBadge

            Spacer()
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            if isCurrent {
                Text("Default")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundColor(.white)
            }

            Text("Instant")
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.green.opacity(0.2)))
                .foregroundColor(Color.green)
        }
    }

    private var metadataSection: some View {
        HStack(spacing: 12) {
            // Apple Speech
            Label("Apple Speech", systemImage: "apple.logo")
                .font(.system(size: 11))
                .foregroundColor(Color(.secondaryLabelColor))
                .lineLimit(1)

            // Language
            Label(model.language, systemImage: "globe")
                .font(.system(size: 11))
                .foregroundColor(Color(.secondaryLabelColor))
                .lineLimit(1)

            // On-Device indicator
            if authStatus.supportsOnDevice {
                Label("On-Device", systemImage: "checkmark.shield")
                    .font(.system(size: 11))
                    .foregroundColor(Color(.secondaryLabelColor))
                    .lineLimit(1)
            }

            // Real-time
            Label("Real-time", systemImage: "waveform")
                .font(.system(size: 11))
                .foregroundColor(Color(.secondaryLabelColor))
                .lineLimit(1)
        }
        .lineLimit(1)
    }

    private var descriptionSection: some View {
        Text(model.description)
            .font(.system(size: 11))
            .foregroundColor(Color(.secondaryLabelColor))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }

    private var permissionSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 11))

            Text(permissionMessage)
                .font(.system(size: 11))
                .foregroundColor(.orange)

            if authStatus.status == .notDetermined {
                Button("Grant Permission") {
                    requestPermission()
                }
                .font(.system(size: 11))
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else if authStatus.status == .denied {
                Button("Open Settings") {
                    openPrivacySettings()
                }
                .font(.system(size: 11))
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.top, 4)
    }

    private var permissionMessage: String {
        switch authStatus.status {
        case .notDetermined:
            return "Speech recognition permission required"
        case .denied:
            return "Speech recognition permission denied"
        case .restricted:
            return "Speech recognition is restricted on this device"
        case .authorized:
            return ""
        @unknown default:
            return "Unknown permission status"
        }
    }

    private var actionSection: some View {
        HStack(spacing: 8) {
            if isCurrent {
                Text("Default Model")
                    .font(.system(size: 12))
                    .foregroundColor(Color(.secondaryLabelColor))
            } else {
                Button(action: setDefaultAction) {
                    Text("Set as Default")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(authStatus.status != .authorized)
            }
        }
    }

    private func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                authStatus.update()
            }
        }
    }

    private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Speech Authorization Status Helper
private class SpeechAuthorizationStatus: ObservableObject {
    @Published var status: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var supportsOnDevice: Bool = false

    func update() {
        status = SFSpeechRecognizer.authorizationStatus()

        if let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) {
            supportsOnDevice = recognizer.supportsOnDeviceRecognition
        }
    }
}

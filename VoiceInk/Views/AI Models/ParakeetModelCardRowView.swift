import SwiftUI
import Combine
import AppKit

struct ParakeetModelCardRowView: View {
    let model: ParakeetModel
    @ObservedObject var whisperState: WhisperState
    @State private var isStreamingEnabled: Bool = true

    var isCurrent: Bool {
        whisperState.currentTranscriptionModel?.name == model.name
    }

    private var streamingModeKey: String {
        "StreamingMode_\(model.name)"
    }

    var isDownloaded: Bool {
        whisperState.isParakeetModelDownloaded(model)
    }

    var isDownloading: Bool {
        whisperState.isParakeetModelDownloading(model)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                headerSection
                metadataSection
                if isDownloaded {
                    streamingToggleSection
                }
                descriptionSection
                progressSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            actionSection
        }
        .padding(16)
        .background(CardBackground(isSelected: isCurrent, useAccentGradientWhenSelected: isCurrent))
        .onAppear {
            loadStreamingPreference()
        }
    }

    private func loadStreamingPreference() {
        if UserDefaults.standard.object(forKey: streamingModeKey) == nil {
            isStreamingEnabled = true  // Default to streaming enabled
        } else {
            isStreamingEnabled = UserDefaults.standard.bool(forKey: streamingModeKey)
        }
    }

    private func saveStreamingPreference(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: streamingModeKey)
    }

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(model.displayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.labelColor))
            
            Text("Experimental")
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.orange.opacity(0.8)))
                .foregroundColor(.white)

            statusBadge
            Spacer()
        }
    }

    private var statusBadge: some View {
        Group {
            if isCurrent {
                Text("Default")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundColor(.white)
            } else if isDownloaded {
                Text("Downloaded")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color(.quaternaryLabelColor)))
                    .foregroundColor(Color(.labelColor))
            }
        }
    }

    private var metadataSection: some View {
        HStack(spacing: 12) {
            Label(model.language, systemImage: "globe")
            Label(model.size, systemImage: "internaldrive")
            HStack(spacing: 3) {
                Text("Speed")
                progressDotsWithNumber(value: model.speed * 10)
            }
            .fixedSize(horizontal: true, vertical: false)
            HStack(spacing: 3) {
                Text("Accuracy")
                progressDotsWithNumber(value: model.accuracy * 10)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .font(.system(size: 11))
        .foregroundColor(Color(.secondaryLabelColor))
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

    private var streamingToggleSection: some View {
        HStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { isStreamingEnabled },
                set: { newValue in
                    isStreamingEnabled = newValue
                    saveStreamingPreference(newValue)
                }
            )) {
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.system(size: 10))
                    Text(isStreamingEnabled ? "Streaming Mode" : "Batch Mode")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .toggleStyle(.switch)
            .controlSize(.mini)

            Text(isStreamingEnabled ? "Real-time transcription" : "Full audio processing")
                .font(.system(size: 10))
                .foregroundColor(Color(.tertiaryLabelColor))
        }
        .padding(.top, 4)
    }

    private var progressSection: some View {
        Group {
            if isDownloading {
                let progress = whisperState.downloadProgress[model.name] ?? 0.0
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
        }
    }

    private var actionSection: some View {
        HStack(spacing: 8) {
            if isCurrent {
                Text("Default Model")
                    .font(.system(size: 12))
                    .foregroundColor(Color(.secondaryLabelColor))
            } else if isDownloaded {
                Button(action: {
                    Task {
                        await whisperState.setDefaultTranscriptionModel(model)
                    }
                }) {
                    Text("Set as Default")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button(action: {
                    Task {
                        await whisperState.downloadParakeetModel(model)
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(isDownloading ? "Downloading..." : "Download")
                        Image(systemName: "arrow.down.circle")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .disabled(isDownloading)
            }
            
            if isDownloaded {
                Menu {
                    Button(action: {
                         whisperState.deleteParakeetModel(model)
                    }) {
                        Label("Delete Model", systemImage: "trash")
                    }
                    
                    Button {
                        whisperState.showParakeetModelInFinder(model)
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 20, height: 20)
            }
        }
    }
}

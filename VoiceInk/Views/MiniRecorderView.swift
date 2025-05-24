import SwiftUI

struct MiniRecorderView: View {
    @ObservedObject var whisperState: WhisperState
    @ObservedObject var recorder: Recorder
    @EnvironmentObject var windowManager: MiniWindowManager
    @State private var showPowerModePopover = false
    @ObservedObject private var powerModeManager = PowerModeManager.shared
    
    var body: some View {
        Group {
            if windowManager.isVisible {
                Capsule()
                    .fill(.clear)
                    .background(
                        ZStack {
                            // Base dark background
                            Color.black.opacity(0.9)
                            
                            // Subtle gradient overlay
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.95),
                                    Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.9)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            
                            // Very subtle visual effect for depth
                            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                                .opacity(0.05)
                        }
                        .clipShape(Capsule())
                    )
                    .overlay {
                        // Subtle inner border
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                    }
                    .overlay {
                        HStack(spacing: 16) {
                            // Record Button
                            NotchRecordButton(
                                isRecording: whisperState.isRecording,
                                isProcessing: whisperState.isProcessing
                            ) {
                                Task { await whisperState.toggleRecord() }
                            }
                            .frame(width: 18)
                            .padding(.leading, -4)
                            
                            // Visualizer - moved to middle position
                            Group {
                                if whisperState.isProcessing {
                                    NotchStaticVisualizer(color: .white)
                                } else {
                                    NotchAudioVisualizer(
                                        audioMeter: recorder.audioMeter,
                                        color: .white,
                                        isActive: whisperState.isRecording
                                    )
                                }
                            }
                            .frame(width: 18)
                            
                            // Empty space for future use
                            Spacer()
                                .frame(width: 18)
                            
                            // Power Mode Button - moved to last position
                            NotchToggleButton(
                                isEnabled: powerModeManager.isPowerModeEnabled,
                                icon: powerModeManager.currentActiveConfiguration.emoji,
                                color: .orange
                            ) {
                                showPowerModePopover.toggle()
                            }
                            .frame(width: 18)
                            .padding(.trailing, -4)
                            .popover(isPresented: $showPowerModePopover, arrowEdge: .bottom) {
                                PowerModePopover()
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
                    .opacity(windowManager.isVisible ? 1 : 0)
            }
        }
    }
}

// Visual Effect View wrapper for NSVisualEffectVie

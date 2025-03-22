import Foundation
import SwiftUI
import os

// MARK: - UI Management Extension
extension WhisperState {
    
    // MARK: - Recorder Panel Management
    
    func showRecorderPanel() {
        logger.notice("📱 Showing \(self.recorderType) recorder")
        if recorderType == "notch" {
            if notchWindowManager == nil {
                notchWindowManager = NotchWindowManager(whisperState: self, recorder: recorder)
                logger.info("Created new notch window manager")
            }
            notchWindowManager?.show()
        } else {
            if miniWindowManager == nil {
                miniWindowManager = MiniWindowManager(whisperState: self, recorder: recorder)
                logger.info("Created new mini window manager")
            }
            miniWindowManager?.show()
        }
    }
    
    func hideRecorderPanel() {
        if isRecording {
            Task {
                await toggleRecord()
            }
        }
    }
    
    // MARK: - Mini Recorder Management
    
    func toggleMiniRecorder() async {
        if isMiniRecorderVisible {
            await dismissMiniRecorder()
        } else {
            Task {
                await toggleRecord()
                
                SoundManager.shared.playStartSound()
                
                await MainActor.run {
                    showRecorderPanel()
                    isMiniRecorderVisible = true
                }
            }
        }
    }
    
    func dismissMiniRecorder() async {
        logger.notice("📱 Dismissing \(self.recorderType) recorder")
        shouldCancelRecording = true
        if isRecording {
            await recorder.stopRecording()
        }
        
        if recorderType == "notch" {
            notchWindowManager?.hide()
        } else {
            miniWindowManager?.hide()
        }
        
        await MainActor.run {
            isRecording = false
            isVisualizerActive = false
            isProcessing = false
            isTranscribing = false
            canTranscribe = true
            isMiniRecorderVisible = false
            shouldCancelRecording = false
        }
        
        try? await Task.sleep(nanoseconds: 150_000_000)
        await cleanupModelResources()
    }
    
    func cancelRecording() async {
        shouldCancelRecording = true
        SoundManager.shared.playEscSound()
        if isRecording {
            await recorder.stopRecording()
        }
        await dismissMiniRecorder()
    }
    
    // MARK: - Notification Handling
    
    func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleToggleMiniRecorder), name: .toggleMiniRecorder, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleLicenseStatusChanged), name: .licenseStatusChanged, object: nil)
    }
    
    @objc public func handleToggleMiniRecorder() {
        if isMiniRecorderVisible {
            Task {
                await toggleRecord()
            }
        } else {
            Task {
                await toggleRecord()
                
                SoundManager.shared.playStartSound()
                
                await MainActor.run {
                    showRecorderPanel()
                    isMiniRecorderVisible = true
                }
            }
        }
    }
    
    @objc func handleLicenseStatusChanged() {
        // This will refresh the license state when it changes elsewhere in the app
        self.licenseViewModel = LicenseViewModel()
    }
} 
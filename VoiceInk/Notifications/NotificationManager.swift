import SwiftUI
import AppKit

class NotificationManager {
    static let shared = NotificationManager()

    private var notificationWindow: NSPanel?
    private var dismissTimer: Timer?

    private init() {}

    @MainActor
    func showNotification(
        title: String,
        message: String,
        type: AppNotificationView.NotificationType,
        duration: TimeInterval = 8.0
    ) {
        // If a notification is already showing, dismiss it before showing the new one.
        if notificationWindow != nil {
            dismissNotification()
        }
        
        let notificationView = AppNotificationView(
            title: title, 
            message: message, 
            type: type,
            duration: duration,
            onClose: { [weak self] in
                Task { @MainActor in
                    self?.dismissNotification()
                }
            }
        )
        let hostingController = NSHostingController(rootView: notificationView)
        let size = hostingController.view.fittingSize

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.contentView = hostingController.view
        panel.isFloatingPanel = true
        panel.level = .mainMenu
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        
        // Position at final location and start with fade animation
        positionWindow(panel)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        
        self.notificationWindow = panel
        
        // Simple fade-in animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        })
        
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(
            withTimeInterval: duration,
            repeats: false
        ) { [weak self] _ in
            self?.dismissNotification()
        }
    }

    @MainActor
    private func positionWindow(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        let windowRect = window.frame
        
        let x = screenRect.maxX - windowRect.width - 20 // 20px padding from the right
        let y = screenRect.maxY - windowRect.height - 20 // 20px padding from the top
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
    

    


    @MainActor
    func dismissNotification() {
        guard let window = notificationWindow else { return }
        
        dismissTimer?.invalidate()
        dismissTimer = nil
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.close()
            self.notificationWindow = nil
        })
    }
} 
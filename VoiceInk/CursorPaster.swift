import Foundation
import AppKit

class CursorPaster {
    private static let pasteCompletionDelay: TimeInterval = 0.3
    
    static func pasteAtCursor(_ text: String) {
        guard AXIsProcessTrusted() else {
            print("Accessibility permissions not granted. Cannot paste at cursor.")
            return
        }
        
        // Save the current pasteboard contents
        let pasteboard = NSPasteboard.general
        let oldContents = pasteboard.string(forType: .string)
        
        // Set the new text to paste
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Simulate cmd+v key press to paste
        let source = CGEventSource(stateID: .hidSystemState)
        
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        
        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
        
        // Restore the original pasteboard contents after a delay
        // Use a background queue to not block the main thread
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + pasteCompletionDelay) {
            if let oldContents = oldContents {
                pasteboard.clearContents()
                pasteboard.setString(oldContents, forType: .string)
            }
        }
    }
}

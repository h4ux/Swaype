import AppKit
import ApplicationServices

enum AccessibilityService {
    /// Whether Swaype currently has Accessibility permission.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user to grant Accessibility permission if not already granted.
    /// macOS shows the standard system prompt and routes them to System Settings.
    @discardableResult
    static func requestTrust() -> Bool {
        let options: CFDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

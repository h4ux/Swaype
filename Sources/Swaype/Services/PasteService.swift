import AppKit

@MainActor
final class PasteService {
    /// Simulates ⌘V at the system level. Requires Accessibility permission.
    func paste() {
        post(virtualKey: 0x09) // V
    }

    /// Simulates ⌘C. Used by Convert Selection to capture the highlighted text.
    func copy() {
        post(virtualKey: 0x08) // C
    }

    private func post(virtualKey: CGKeyCode) {
        guard let src = CGEventSource(stateID: .combinedSessionState) else { return }
        let down = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }
}

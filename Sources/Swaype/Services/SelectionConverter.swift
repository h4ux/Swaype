import AppKit
import SwaypeCore

/// "Convert Selection" flow: copies the focused app's selection via ⌘C,
/// converts it, pastes the converted text back via ⌘V, then restores the
/// user's original clipboard. Requires Accessibility permission.
@MainActor
enum SelectionConverter {
    static func run(
        converter: LayoutConverter,
        clipboard: ClipboardService,
        paste: PasteService
    ) async {
        guard AccessibilityService.isTrusted else {
            AccessibilityService.requestTrust()
            return
        }

        let originalClip = clipboard.readString()
        clipboard.clear()

        paste.copy()
        // Give the frontmost app time to write the selection to the pasteboard.
        try? await Task.sleep(nanoseconds: 120_000_000)

        guard let selected = clipboard.readString(), !selected.isEmpty else {
            if let original = originalClip { clipboard.write(original) }
            NSSound.beep()
            return
        }

        let converted = converter.convert(selected)
        clipboard.write(converted)
        paste.paste()

        // Restore the user's clipboard once the paste has been consumed.
        try? await Task.sleep(nanoseconds: 350_000_000)
        if let original = originalClip { clipboard.write(original) }
    }
}

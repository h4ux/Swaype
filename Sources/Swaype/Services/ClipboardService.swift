import AppKit

@MainActor
final class ClipboardService {
    private let pasteboard = NSPasteboard.general

    func readString() -> String? {
        pasteboard.string(forType: .string)
    }

    func write(_ string: String) {
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    func clear() {
        pasteboard.clearContents()
    }
}

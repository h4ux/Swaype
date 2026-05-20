import AppKit

@MainActor
final class MenuBuilder {
    private weak var target: AppDelegate?

    init(target: AppDelegate) {
        self.target = target
    }

    func build() -> NSMenu {
        let menu = NSMenu()

        // Primary action — same flow as the global hotkey.
        menu.addItem(item(
            title: "Swap Selection",
            action: #selector(AppDelegate.swapSelection(_:)),
            keyEquivalent: ""
        ))

        // Secondary: convert what's already on the clipboard, no paste.
        menu.addItem(item(
            title: "Convert Clipboard",
            action: #selector(AppDelegate.convertClipboard(_:)),
            keyEquivalent: ""
        ))

        menu.addItem(.separator())

        let pairItem = NSMenuItem(
            title: "Pair: \(AppState.shared.pairName)",
            action: nil,
            keyEquivalent: ""
        )
        pairItem.isEnabled = false
        menu.addItem(pairItem)

        menu.addItem(.separator())

        let launchAtLoginItem = item(
            title: "Launch at Login",
            action: #selector(AppDelegate.toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchAtLoginItem.state = Preferences.launchAtLogin ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(item(
            title: "Settings…",
            action: #selector(AppDelegate.openSettings(_:)),
            keyEquivalent: ","
        ))

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit Swaype",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        return menu
    }

    private func item(title: String, action: Selector, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = target
        return item
    }
}

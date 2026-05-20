import AppKit
import Combine
import KeyboardShortcuts
import SwaypeCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private(set) var menuBuilder: MenuBuilder!
    private var cancellables: Set<AnyCancellable> = []

    let clipboard = ClipboardService()
    let paste = PasteService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Force AppState init so default layouts are seeded before the menu reads them.
        _ = AppState.shared

        menuBuilder = MenuBuilder(target: self)
        setupStatusItem()
        setupHotkey()
        observePairChanges()
        syncLaunchAtLoginPreference()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = AppDelegate.makeStatusImage()
        }
        item.menu = menuBuilder.build()
        self.statusItem = item
    }

    /// Returns the colourful brand icon from the .app bundle's Resources.
    /// Falls back to an SF Symbol when running unbundled (e.g. `swift run`).
    private static func makeStatusImage() -> NSImage? {
        if let bundled = NSImage(named: "MenuBarIcon") {
            bundled.size = NSSize(width: 22, height: 22)
            bundled.isTemplate = false
            return bundled
        }
        let symbol = NSImage(
            systemSymbolName: "arrow.left.arrow.right",
            accessibilityDescription: "Swaype"
        )
        symbol?.isTemplate = true
        return symbol
    }

    private func refreshMenu() {
        statusItem?.menu = menuBuilder.build()
    }

    private func observePairChanges() {
        AppState.shared.$pairName
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshMenu() }
            .store(in: &cancellables)
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        KeyboardShortcuts.onKeyUp(for: .swap) { [weak self] in
            self?.swapSelection(nil)
        }
    }

    // MARK: - Actions

    /// Hotkey + menu primary action. Copies the focused app's selection,
    /// converts it through the active layout pair, pastes it back in place,
    /// and restores the user's clipboard.
    @objc func swapSelection(_ sender: Any?) {
        Task { @MainActor in
            await SelectionConverter.run(
                converter: AppState.shared.converter,
                clipboard: clipboard,
                paste: paste
            )
        }
    }

    /// Convert whatever is currently on the clipboard, leaving the converted
    /// text on the clipboard. No paste — useful when you just need the text
    /// in a different layout to use somewhere later.
    @objc func convertClipboard(_ sender: Any?) {
        guard let text = clipboard.readString(), !text.isEmpty else {
            NSSound.beep()
            return
        }
        let converted = AppState.shared.converter.convert(text)
        clipboard.write(converted)
    }

    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let next = !Preferences.launchAtLogin
        if LaunchAtLoginService.setEnabled(next) {
            Preferences.launchAtLogin = next
            refreshMenu()
        }
    }

    @objc func openSettings(_ sender: Any?) {
        SettingsWindowController.shared.show()
    }

    // MARK: - Helpers

    private func syncLaunchAtLoginPreference() {
        Preferences.launchAtLogin = LaunchAtLoginService.isEnabled
    }
}

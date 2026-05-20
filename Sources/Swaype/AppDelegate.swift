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

    let state = AppState()
    let updater = UpdateService()
    let clipboard = ClipboardService()
    let paste = PasteService()

    private lazy var settingsController = SettingsWindowController(
        state: state,
        updater: updater
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Install the exception handler FIRST so any crash during the rest of
        // launch surfaces in Console.app.
        NSSetUncaughtExceptionHandler { exception in
            NSLog("Swaype uncaught exception: \(exception.name.rawValue) — \(exception.reason ?? "no reason") — \(exception.userInfo ?? [:])")
        }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let repo = Bundle.main.infoDictionary?["SwaypeUpdateRepository"] as? String ?? "?"
        NSLog("Swaype launching — version \(version) (build \(build)), updates from \(repo)")
        NSLog("Swaype bundle: \(Bundle.main.bundleURL.path)")
        NSLog("Swaype installed keyboards: \(state.installed.count) (active pair: \(state.pairName))")

        NSApp.setActivationPolicy(.accessory)

        menuBuilder = MenuBuilder(target: self, state: state)
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

    private func refreshMenu() {
        statusItem?.menu = menuBuilder.build()
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

    private func observePairChanges() {
        state.$pairName
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
                converter: state.converter,
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
        let converted = state.converter.convert(text)
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
        settingsController.show()
    }

    @objc func checkForUpdatesFromMenu(_ sender: Any?) {
        settingsController.show()
        Task { await updater.checkForUpdate() }
    }

    // MARK: - Helpers

    private func syncLaunchAtLoginPreference() {
        Preferences.launchAtLogin = LaunchAtLoginService.isEnabled
    }
}

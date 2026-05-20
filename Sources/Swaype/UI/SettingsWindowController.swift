import AppKit
import SwiftUI

/// Manually-managed Settings window. The SwiftUI `Settings` scene approach is
/// unreliable from `.accessory` (menu-bar-only) apps — the `showSettingsWindow:`
/// selector silently no-ops in many real-world configurations. A plain
/// NSWindowController is far easier to keep working.
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    static let shared: SettingsWindowController = make()

    private static func make() -> SettingsWindowController {
        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.title = "Swaype Settings"
        window.isReleasedWhenClosed = false
        window.center()

        let controller = SettingsWindowController(window: window)
        window.delegate = controller
        return controller
    }

    func show() {
        // Promote to regular policy so AppKit reliably brings our window front
        // and accepts keyboard focus. We drop back to accessory in windowWillClose.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if window?.isVisible != true {
            window?.center()
        }
        window?.makeKeyAndOrderFront(nil)
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

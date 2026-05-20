import AppKit
import SwiftUI

/// Manually-managed Settings window. The SwiftUI `Settings` scene approach is
/// unreliable from `.accessory` (menu-bar-only) apps — `showSettingsWindow:`
/// silently no-ops in many configurations. A plain NSWindowController is
/// simpler and avoids the activation-policy juggling that can crash on macOS
/// builds where Swaype is not the foreground app at launch time.
@MainActor
final class SettingsWindowController: NSWindowController {

    convenience init(state: AppState, updater: UpdateService) {
        let rootView = SettingsView()
            .environmentObject(state)
            .environmentObject(updater)
        let hosting = NSHostingController(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 540),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.title = "Swaype Settings"
        window.isReleasedWhenClosed = false
        // Allow the window to appear on every Space and over fullscreen apps —
        // important for a menu-bar app the user might invoke from any context.
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.center()

        self.init(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if window?.isVisible != true {
            window?.center()
        }
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}

import SwiftUI

@main
struct SwaypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // SwiftUI App requires at least one Scene. The actual Settings window is
    // managed by SettingsWindowController, not this scene — it's just a stub.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

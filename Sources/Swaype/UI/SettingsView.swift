import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var state = AppState.shared

    @AppStorage(Preferences.Key.launchAtLogin) private var launchAtLogin = false
    @AppStorage(Preferences.Key.primaryLayoutId) private var primaryLayoutId = ""
    @AppStorage(Preferences.Key.secondaryLayoutId) private var secondaryLayoutId = ""

    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Swap layout:", name: .swap)
                Text("Press the shortcut while text is selected — Swaype copies it, converts it through the layout pair below, and pastes it back in place.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Shortcut")
            }

            Section {
                if state.installed.isEmpty {
                    Text("No keyboard layouts detected.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Primary:", selection: $primaryLayoutId) {
                        Text("—").tag("")
                        ForEach(state.installed) { layout in
                            Text(layout.name).tag(layout.id)
                        }
                    }
                    .onChange(of: primaryLayoutId) { _ in state.rebuildConverter() }

                    Picker("Secondary:", selection: $secondaryLayoutId) {
                        Text("—").tag("")
                        ForEach(state.installed) { layout in
                            Text(layout.name).tag(layout.id)
                        }
                    }
                    .onChange(of: secondaryLayoutId) { _ in state.rebuildConverter() }

                    Text("Active pair: \(state.pairName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Layouts")
            } footer: {
                Text("Defaults are picked from your installed keyboards (System Settings → Keyboard → Input Sources). Add more layouts there to see them here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        if !LaunchAtLoginService.setEnabled(newValue) {
                            launchAtLogin = !newValue
                        }
                    }
            } header: {
                Text("Behavior")
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 440)
    }
}

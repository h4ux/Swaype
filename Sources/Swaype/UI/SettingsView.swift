import AppKit
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var updater: UpdateService

    @AppStorage(Preferences.Key.launchAtLogin) private var launchAtLogin = false
    @AppStorage(Preferences.Key.primaryLayoutId) private var primaryLayoutId = ""
    @AppStorage(Preferences.Key.secondaryLayoutId) private var secondaryLayoutId = ""
    @AppStorage(Preferences.Key.updateRepository) private var updateRepository = ""

    var body: some View {
        Form {
            shortcutSection
            layoutsSection
            behaviorSection
            updatesSection
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 540)
    }

    // MARK: - Sections

    private var shortcutSection: some View {
        Section {
            KeyboardShortcuts.Recorder("Swap layout:", name: .swap)
            Text("Press the shortcut while text is selected — Swaype copies it, converts it through the layout pair below, and pastes it back in place.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text("Shortcut")
        }
    }

    private var layoutsSection: some View {
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
    }

    private var behaviorSection: some View {
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

    private var updatesSection: some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current version: \(updater.currentVersion)")
                    statusLine
                }
                Spacer()
                actionButton
            }

            HStack {
                TextField(
                    "owner/repo",
                    text: $updateRepository,
                    prompt: Text(updater.repository)
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

                if let url = updater.releasesURL {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderless)
                    .help("Open releases page in browser")
                }
            }
        } header: {
            Text("Updates")
        } footer: {
            Text("CI builds auto-fill the repository from `${{ github.repository }}`. Override above if you forked the repo or want to track a different release stream.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Updater sub-views

    @ViewBuilder
    private var statusLine: some View {
        switch updater.status {
        case .idle:
            EmptyView()
        case .checking:
            Text("Checking…").font(.caption).foregroundStyle(.secondary)
        case .upToDate:
            Text("You're on the latest version.")
                .font(.caption).foregroundStyle(.secondary)
        case .available(let u):
            Text("Update available: \(u.version)")
                .font(.caption).foregroundStyle(.blue)
        case .downloading(let p):
            Text("Downloading… \(Int(p * 100))%")
                .font(.caption).foregroundStyle(.secondary)
        case .installing:
            Text("Installing — Swaype will restart in a moment.")
                .font(.caption).foregroundStyle(.secondary)
        case .failed(let msg):
            Text("Couldn't check: \(msg)")
                .font(.caption).foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch updater.status {
        case .checking, .downloading, .installing:
            ProgressView().controlSize(.small)
        case .available(let update):
            Button("Install \(update.version)") {
                Task { await updater.installUpdate(update) }
            }
            .buttonStyle(.borderedProminent)
        default:
            Button("Check for Updates") {
                Task { await updater.checkForUpdate() }
            }
        }
    }
}

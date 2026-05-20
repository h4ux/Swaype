import AppKit
import Foundation
import SwiftUI

/// In-app updater: queries GitHub Releases for the latest `Swaype.dmg`, and if
/// it's newer than the running version, downloads it, mounts the DMG, swaps
/// the installed .app, and relaunches the new version. No third-party
/// dependency — we own the entire pipeline.
@MainActor
final class UpdateService: ObservableObject {
    /// GitHub owner/repo the updater queries. Change before publishing.
    static let owner = "h4ux"
    static let repo = "Swaype"

    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(AvailableUpdate)
        case downloading(progress: Double)
        case installing
        case failed(String)
    }

    struct AvailableUpdate: Equatable {
        let version: String
        let downloadURL: URL
        let releaseNotes: String
    }

    @Published private(set) var status: Status = .idle

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    // MARK: - Check

    func checkForUpdate() async {
        status = .checking
        do {
            let url = URL(string: "https://api.github.com/repos/\(Self.owner)/\(Self.repo)/releases/latest")!
            var req = URLRequest(url: url)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.setValue("Swaype/\(currentVersion)", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                status = .failed("GitHub returned \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latest = release.tag_name.replacingOccurrences(of: "^v", with: "", options: .regularExpression)

            if !VersionCompare.isNewer(latest, than: currentVersion) {
                status = .upToDate
                return
            }

            guard
                let asset = release.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }),
                let dl = URL(string: asset.browser_download_url)
            else {
                status = .failed("No DMG asset attached to the latest release.")
                return
            }

            status = .available(AvailableUpdate(
                version: latest,
                downloadURL: dl,
                releaseNotes: release.body ?? ""
            ))
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - Install

    func installUpdate(_ update: AvailableUpdate) async {
        status = .downloading(progress: 0)
        do {
            // 1. Download DMG to a temp file.
            let (tempURL, _) = try await URLSession.shared.download(from: update.downloadURL)
            let dmgURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("Swaype-update-\(UUID().uuidString).dmg")
            try? FileManager.default.removeItem(at: dmgURL)
            try FileManager.default.moveItem(at: tempURL, to: dmgURL)

            status = .installing

            // 2. Mount it.
            let mountPoint = "/tmp/swaype-update-\(ProcessInfo.processInfo.processIdentifier)"
            try? FileManager.default.removeItem(atPath: mountPoint)
            try FileManager.default.createDirectory(atPath: mountPoint, withIntermediateDirectories: true)
            try shell("/usr/bin/hdiutil", [
                "attach", dmgURL.path,
                "-mountpoint", mountPoint,
                "-nobrowse", "-noautoopen"
            ])

            // 3. Copy the .app from the mounted DMG to a staging directory.
            let mounted = URL(fileURLWithPath: "\(mountPoint)/Swaype.app")
            guard FileManager.default.fileExists(atPath: mounted.path) else {
                _ = try? shell("/usr/bin/hdiutil", ["detach", mountPoint, "-force"])
                status = .failed("Downloaded DMG didn't contain Swaype.app.")
                return
            }
            let staging = FileManager.default.temporaryDirectory
                .appendingPathComponent("Swaype-staging-\(UUID().uuidString).app")
            try? FileManager.default.removeItem(at: staging)
            try FileManager.default.copyItem(at: mounted, to: staging)

            // 4. Eject DMG.
            _ = try? shell("/usr/bin/hdiutil", ["detach", mountPoint, "-force"])
            try? FileManager.default.removeItem(at: dmgURL)

            // 5. Write a small bash script that waits for us to quit, then
            //    swaps the .app and relaunches. We can't replace our own
            //    bundle from inside ourselves.
            let installPath = Bundle.main.bundleURL
            let pid = ProcessInfo.processInfo.processIdentifier
            let script = try writeInstallerScript(
                stagingApp: staging,
                installPath: installPath,
                pid: pid
            )

            // 6. Launch the installer detached.
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = [script.path]
            try proc.run()

            // 7. Quit so the installer can do its thing.
            //    Small delay to give the helper a chance to actually start.
            try? await Task.sleep(nanoseconds: 200_000_000)
            NSApp.terminate(nil)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func writeInstallerScript(stagingApp: URL, installPath: URL, pid: Int32) throws -> URL {
        let script = """
        #!/bin/bash
        set -e
        # Wait for the running Swaype (PID \(pid)) to exit.
        for _ in $(seq 1 60); do
            if ! kill -0 \(pid) 2>/dev/null; then break; fi
            sleep 0.25
        done
        sleep 0.5

        TARGET="\(installPath.path)"
        STAGING="\(stagingApp.path)"

        # Replace the installed bundle.
        rm -rf "$TARGET"
        mv "$STAGING" "$TARGET"

        # Strip quarantine so Gatekeeper doesn't block the relaunch,
        # then re-sign ad-hoc to keep code identity stable.
        xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null || true
        codesign --force --deep --sign - "$TARGET" 2>/dev/null || true

        open "$TARGET"
        """

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("swaype-installer-\(UUID().uuidString).sh")
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    @discardableResult
    private func shell(_ tool: String, _ args: [String]) throws -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: tool)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()
        proc.waitUntilExit()
        let out = String(
            data: pipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        guard proc.terminationStatus == 0 else {
            throw NSError(
                domain: "Swaype.UpdateService",
                code: Int(proc.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "\(tool) failed: \(out)"]
            )
        }
        return out
    }
}

// MARK: - Version comparison

enum VersionCompare {
    /// Compares "1.2.3"-style versions numerically. Returns true if `a > b`.
    /// Missing components are treated as zero, so "1.2" == "1.2.0".
    static func isNewer(_ a: String, than b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(aParts.count, bParts.count) {
            let av = i < aParts.count ? aParts[i] : 0
            let bv = i < bParts.count ? bParts[i] : 0
            if av != bv { return av > bv }
        }
        return false
    }
}

// MARK: - GitHub Releases payload

private struct GitHubRelease: Decodable {
    let tag_name: String
    let body: String?
    let assets: [Asset]

    struct Asset: Decodable {
        let name: String
        let browser_download_url: String
    }
}

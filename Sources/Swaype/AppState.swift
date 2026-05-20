import Foundation
import SwaypeCore
import SwiftUI

/// Shared, observable app state. Owns the active `LayoutConverter` and rebuilds
/// it when the user picks different layouts in Settings.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    /// All keyboard layouts the user has installed.
    let installed: [InstalledLayout]

    @Published private(set) var converter: LayoutConverter
    @Published private(set) var pairName: String

    private init() {
        let layouts = InputSourceService.installedKeyboards()
        self.installed = layouts
        AppState.seedDefaultsIfNeeded(from: layouts)
        let (converter, name) = AppState.makeConverter(from: layouts)
        self.converter = converter
        self.pairName = name
    }

    func rebuildConverter() {
        let (converter, name) = AppState.makeConverter(from: installed)
        self.converter = converter
        self.pairName = name
    }

    // MARK: - Defaults

    /// On first launch (or when an installed keyboard goes away), pick a
    /// reasonable default pair: first Latin layout vs. first non-Latin one.
    private static func seedDefaultsIfNeeded(from installed: [InstalledLayout]) {
        let existingIds = Set(installed.map(\.id))

        if !existingIds.contains(Preferences.primaryLayoutId) {
            Preferences.primaryLayoutId = installed.first { $0.isLatin }?.id ?? ""
        }
        if !existingIds.contains(Preferences.secondaryLayoutId) {
            Preferences.secondaryLayoutId = installed.first { !$0.isLatin }?.id ?? ""
        }
    }

    private static func makeConverter(from installed: [InstalledLayout]) -> (LayoutConverter, String) {
        let primary = installed.first { $0.id == Preferences.primaryLayoutId }
        let secondary = installed.first { $0.id == Preferences.secondaryLayoutId }

        if let primary, let secondary {
            let pair = InputSourceService.buildPair(primary: primary, secondary: secondary)
            return (LayoutConverter(pair: pair), pair.name)
        }

        // Only one keyboard installed — fall back to the bundled English↔Hebrew
        // mapping so the app is still useful out of the box.
        let fallback = LayoutPair.englishHebrew
        return (LayoutConverter(pair: fallback), fallback.name)
    }
}

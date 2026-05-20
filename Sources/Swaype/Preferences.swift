import Foundation

/// UserDefaults-backed app preferences. Same keys are used by AppKit code and
/// by SwiftUI `@AppStorage`, so both views see the same values.
enum Preferences {
    enum Key {
        static let launchAtLogin = "launchAtLogin"
        static let primaryLayoutId = "primaryLayoutId"
        static let secondaryLayoutId = "secondaryLayoutId"
        static let updateRepository = "updateRepository"
    }

    static var launchAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: Key.launchAtLogin) }
        set { UserDefaults.standard.set(newValue, forKey: Key.launchAtLogin) }
    }

    static var primaryLayoutId: String {
        get { UserDefaults.standard.string(forKey: Key.primaryLayoutId) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Key.primaryLayoutId) }
    }

    static var secondaryLayoutId: String {
        get { UserDefaults.standard.string(forKey: Key.secondaryLayoutId) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Key.secondaryLayoutId) }
    }

    /// User override for "owner/repo". When empty, UpdateService falls back
    /// to the Info.plist value (which CI fills in with `github.repository`).
    static var updateRepository: String {
        get { UserDefaults.standard.string(forKey: Key.updateRepository) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Key.updateRepository) }
    }
}

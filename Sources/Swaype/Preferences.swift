import Foundation

/// UserDefaults-backed app preferences. Same keys are used by AppKit code and
/// by SwiftUI `@AppStorage`, so both views see the same values.
enum Preferences {
    enum Key {
        static let launchAtLogin = "launchAtLogin"
        static let primaryLayoutId = "primaryLayoutId"
        static let secondaryLayoutId = "secondaryLayoutId"
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
}

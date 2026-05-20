import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// The primary action: copy current selection, convert, paste in place.
    /// Default: ⌘⌥V. Users can rebind in Settings.
    static let swap = Self("swap", default: .init(.v, modifiers: [.command, .option]))
}

import Foundation

extension LayoutPair {
    /// US QWERTY ↔ Standard Israeli Hebrew (Apple "Hebrew" input source).
    ///
    /// Each entry pairs the character produced by a physical key on the
    /// US layout with the character produced by the same key on the
    /// standard Israeli Hebrew layout. Only positions that DIFFER between
    /// the two layouts are listed — digits, space, `-`, `=`, `[`, `]`, `\`,
    /// and `` ` `` pass through unchanged on both layouts.
    public static let englishHebrew = LayoutPair(
        id: "en-he",
        name: "English ↔ Hebrew",
        positions: [
            // Top letter row — QWERTYUIOP
            .init(en: "q", "/"),
            .init(en: "w", "'"),
            .init(en: "e", "ק"),
            .init(en: "r", "ר"),
            .init(en: "t", "א"),
            .init(en: "y", "ט"),
            .init(en: "u", "ו"),
            .init(en: "i", "ן"),
            .init(en: "o", "ם"),
            .init(en: "p", "פ"),

            // Home row — ASDFGHJKL;'
            .init(en: "a", "ש"),
            .init(en: "s", "ד"),
            .init(en: "d", "ג"),
            .init(en: "f", "כ"),
            .init(en: "g", "ע"),
            .init(en: "h", "י"),
            .init(en: "j", "ח"),
            .init(en: "k", "ל"),
            .init(en: "l", "ך"),
            .init(en: ";", "ף"),
            .init(en: "'", ","),

            // Bottom row — ZXCVBNM,./
            .init(en: "z", "ז"),
            .init(en: "x", "ס"),
            .init(en: "c", "ב"),
            .init(en: "v", "ה"),
            .init(en: "b", "נ"),
            .init(en: "n", "מ"),
            .init(en: "m", "צ"),
            .init(en: ",", "ת"),
            .init(en: ".", "ץ"),
            .init(en: "/", ".")
        ]
    )
}

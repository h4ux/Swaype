import Foundation

/// A pair of keyboard layouts that share the same physical key positions
/// but produce different characters. Used to convert text that was typed
/// on the wrong layout back to the user's intended text.
public struct LayoutPair: Sendable {
    /// A single physical-key position and the characters produced by
    /// each layout at that position.
    public struct Position: Hashable, Sendable {
        public let en: String   // character on US QWERTY (the "ASCII" layout)
        public let target: String  // character on the target layout (e.g. Hebrew)

        public init(en: String, _ target: String) {
            self.en = en
            self.target = target
        }
    }

    public let id: String
    public let name: String
    public let positions: [Position]

    public init(id: String, name: String, positions: [Position]) {
        self.id = id
        self.name = name
        self.positions = positions
    }

    /// Map: character produced on US layout → character produced on target layout
    /// at the same physical key. Only includes positions that actually differ.
    public func englishToTarget() -> [Character: String] {
        var dict: [Character: String] = [:]
        for p in positions where p.en != p.target {
            for ch in p.en { dict[ch] = p.target }
        }
        return dict
    }

    /// Reverse direction: target layout char → US layout char at the same key.
    public func targetToEnglish() -> [Character: String] {
        var dict: [Character: String] = [:]
        for p in positions where p.en != p.target {
            for ch in p.target { dict[ch] = p.en }
        }
        return dict
    }
}

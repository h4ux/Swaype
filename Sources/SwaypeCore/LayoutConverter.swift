import Foundation

public enum ConversionDirection: Sendable {
    case englishToTarget
    case targetToEnglish
    case auto
}

/// Converts text typed on the wrong keyboard layout back to the user's
/// intended text. Pass-through for any character not in the layout mapping.
public struct LayoutConverter: Sendable {
    public let pair: LayoutPair

    private let enToTarget: [Character: String]
    private let targetToEn: [Character: String]
    private let targetScalars: Set<Unicode.Scalar>

    public init(pair: LayoutPair) {
        self.pair = pair
        self.enToTarget = pair.englishToTarget()
        self.targetToEn = pair.targetToEnglish()

        var scalars = Set<Unicode.Scalar>()
        for p in pair.positions where p.en != p.target {
            for s in p.target.unicodeScalars { scalars.insert(s) }
        }
        self.targetScalars = scalars
    }

    /// Convert `input` using the given direction. With `.auto`, the direction
    /// is chosen per-call: if the input contains any target-script character
    /// (e.g. Hebrew), convert target→English; otherwise English→target.
    public func convert(_ input: String, direction: ConversionDirection = .auto) -> String {
        let dir: ConversionDirection
        switch direction {
        case .auto:
            dir = containsTargetScript(input) ? .targetToEnglish : .englishToTarget
        case .englishToTarget, .targetToEnglish:
            dir = direction
        }

        var out = ""
        out.reserveCapacity(input.count)
        for ch in input {
            out.append(mapped(ch, direction: dir))
        }
        return out
    }

    private func mapped(_ ch: Character, direction: ConversionDirection) -> String {
        switch direction {
        case .englishToTarget:
            if let v = enToTarget[ch] { return v }
            // Hebrew has no case — let uppercase English letters map too.
            if ch.isLetter && ch.isUppercase {
                let lower = Character(ch.lowercased())
                if let v = enToTarget[lower] { return v }
            }
            return String(ch)
        case .targetToEnglish:
            if let v = targetToEn[ch] { return v }
            return String(ch)
        case .auto:
            return String(ch) // unreachable; resolved by caller
        }
    }

    /// Returns true if `input` contains any character that belongs to the
    /// target script of this layout pair (e.g. any Hebrew letter).
    public func containsTargetScript(_ input: String) -> Bool {
        for scalar in input.unicodeScalars where targetScalars.contains(scalar) {
            return true
        }
        return false
    }
}

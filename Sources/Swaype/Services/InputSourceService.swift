import Carbon
import Foundation
import SwaypeCore

/// One installed keyboard layout discovered via Carbon's Text Input Sources API.
struct InstalledLayout: Identifiable, Hashable {
    let id: String
    let name: String
    let layoutData: Data

    /// Heuristic: true if pressing the US-"a" key on this layout yields a
    /// lowercase Latin letter. Used to pick a sensible "primary" default.
    var isLatin: Bool {
        guard
            let s = InputSourceService.translate(virtualKey: 0, layout: layoutData),
            let scalar = s.unicodeScalars.first
        else { return false }
        return scalar.value >= 0x61 && scalar.value <= 0x7A
    }
}

enum InputSourceService {
    /// All keyboard *layouts* currently installed on the system (input methods
    /// like Pinyin or Kotoeri are filtered out — they don't have a translatable
    /// key map).
    static func installedKeyboards() -> [InstalledLayout] {
        guard let listRef = TISCreateInputSourceList(nil, false) else { return [] }
        guard let sources = listRef.takeRetainedValue() as? [TISInputSource] else { return [] }

        var out: [InstalledLayout] = []
        for src in sources {
            guard let typeRaw = TISGetInputSourceProperty(src, kTISPropertyInputSourceType) else { continue }
            let type = Unmanaged<CFString>.fromOpaque(typeRaw).takeUnretainedValue() as String
            guard type == (kTISTypeKeyboardLayout as String) else { continue }

            guard let idRaw = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) else { continue }
            let id = Unmanaged<CFString>.fromOpaque(idRaw).takeUnretainedValue() as String

            let nameRaw = TISGetInputSourceProperty(src, kTISPropertyLocalizedName)
            let name = nameRaw.flatMap {
                Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String
            } ?? id

            guard let dataRaw = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData) else { continue }
            let data = Unmanaged<CFData>.fromOpaque(dataRaw).takeUnretainedValue() as Data

            out.append(InstalledLayout(id: id, name: name, layoutData: data))
        }
        return out.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Translate a virtual key code through the given layout, returning the
    /// character that key produces on that layout (with `modifiers` applied).
    static func translate(virtualKey: UInt16, modifiers: UInt32 = 0, layout: Data) -> String? {
        return layout.withUnsafeBytes { raw -> String? in
            guard let base = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return nil }

            var deadKeyState: UInt32 = 0
            var actualLength = 0
            var buffer = [UniChar](repeating: 0, count: 8)

            let status = UCKeyTranslate(
                base,
                virtualKey,
                UInt16(kUCKeyActionDisplay),
                modifiers,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                buffer.count,
                &actualLength,
                &buffer
            )
            guard status == noErr, actualLength > 0 else { return nil }
            return String(utf16CodeUnits: buffer, count: actualLength)
        }
    }

    /// Build a `LayoutPair` by walking the standard letter/punctuation key
    /// codes and looking up what `primary` and `secondary` produce at each
    /// physical key. Only positions that *differ* are included.
    static func buildPair(primary: InstalledLayout, secondary: InstalledLayout) -> LayoutPair {
        // US virtual key codes for letters and punctuation we care about.
        // Source: Carbon Events.h.
        let keyCodes: [UInt16] = [
            // home row
            0,   // a
            1,   // s
            2,   // d
            3,   // f
            5,   // g
            4,   // h
            38,  // j
            40,  // k
            37,  // l
            41,  // ;
            39,  // '
            // top letter row
            12,  // q
            13,  // w
            14,  // e
            15,  // r
            17,  // t
            16,  // y
            32,  // u
            34,  // i
            31,  // o
            35,  // p
            // bottom row
            6,   // z
            7,   // x
            8,   // c
            9,   // v
            11,  // b
            45,  // n
            46,  // m
            43,  // ,
            47,  // .
            44   // /
        ]

        var positions: [LayoutPair.Position] = []
        for code in keyCodes {
            guard
                let a = translate(virtualKey: code, layout: primary.layoutData),
                let b = translate(virtualKey: code, layout: secondary.layoutData),
                a != b
            else { continue }
            positions.append(.init(en: a, b))
        }

        return LayoutPair(
            id: "\(primary.id)__\(secondary.id)",
            name: "\(primary.name) ↔ \(secondary.name)",
            positions: positions
        )
    }
}

import XCTest
@testable import SwaypeCore

final class LayoutConverterTests: XCTestCase {
    let converter = LayoutConverter(pair: .englishHebrew)

    // MARK: - Brief examples

    func testEnglishTypedMeantHebrew() {
        // "akuo guko" typed on English layout → user meant "שלום עולם"
        XCTAssertEqual(converter.convert("akuo guko"), "שלום עולם")
    }

    func testHebrewTypedMeantEnglish() {
        // "hello world" typed on Hebrew layout produces "יקךךם 'םרךג"
        // (d → ג, not ד — ד is the position of `s`)
        XCTAssertEqual(converter.convert("יקךךם 'םרךג"), "hello world")
    }

    // MARK: - Auto-detect

    func testAutoDetect_pureEnglishGoesToHebrew() {
        XCTAssertEqual(converter.convert("akuo"), "שלום")
    }

    func testAutoDetect_pureHebrewGoesToEnglish() {
        XCTAssertEqual(converter.convert("שלום"), "akuo")
    }

    func testAutoDetect_mixedTreatedAsHebrewSource() {
        // Any Hebrew character flips direction to target→English.
        let out = converter.convert("שhi")
        XCTAssertEqual(out, "ahi")
    }

    // MARK: - Pass-through

    func testDigitsAndSpaceUnchanged() {
        XCTAssertEqual(
            converter.convert("123 abc", direction: .englishToTarget),
            "123 שנב"
        )
    }

    func testEmojiUnchanged() {
        let out = converter.convert("hi 😀", direction: .englishToTarget)
        XCTAssertTrue(out.contains("😀"))
    }

    func testUnmappedSymbolsPassThrough() {
        XCTAssertEqual(
            converter.convert("a-b=c", direction: .englishToTarget),
            "ש-נ=ב"
        )
    }

    func testEmptyInput() {
        XCTAssertEqual(converter.convert(""), "")
    }

    // MARK: - Case handling

    func testUppercaseEnglishMaps() {
        // Hebrew has no case, so uppercase letters still map.
        XCTAssertEqual(converter.convert("AKUO", direction: .englishToTarget), "שלום")
    }

    // MARK: - Punctuation positions

    func testPunctuation_englishToHebrew() {
        XCTAssertEqual(converter.convert(",", direction: .englishToTarget), "ת")
        XCTAssertEqual(converter.convert(".", direction: .englishToTarget), "ץ")
        XCTAssertEqual(converter.convert("/", direction: .englishToTarget), ".")
        XCTAssertEqual(converter.convert("'", direction: .englishToTarget), ",")
        XCTAssertEqual(converter.convert(";", direction: .englishToTarget), "ף")
        XCTAssertEqual(converter.convert("w", direction: .englishToTarget), "'")
        XCTAssertEqual(converter.convert("q", direction: .englishToTarget), "/")
    }

    func testPunctuation_hebrewToEnglish() {
        XCTAssertEqual(converter.convert("ת", direction: .targetToEnglish), ",")
        XCTAssertEqual(converter.convert("ץ", direction: .targetToEnglish), ".")
        XCTAssertEqual(converter.convert("ף", direction: .targetToEnglish), ";")
    }

    // MARK: - Round trip

    func testRoundTrip_englishToHebrewAndBack() {
        let original = "hello world"
        let mid = converter.convert(original, direction: .englishToTarget)
        let back = converter.convert(mid, direction: .targetToEnglish)
        XCTAssertEqual(back, original)
    }

    func testRoundTrip_hebrewToEnglishAndBack() {
        let original = "שלום עולם"
        let mid = converter.convert(original, direction: .targetToEnglish)
        let back = converter.convert(mid, direction: .englishToTarget)
        XCTAssertEqual(back, original)
    }
}

import XCTest
@testable import shouldrest

final class LanguageOptionTests: XCTestCase {
    func testMapsBundledLanguageIdentifiers() {
        XCTAssertEqual(LanguageOption(identifier: "en"), .english)
        XCTAssertEqual(LanguageOption(identifier: " zh-Hans "), .simplifiedChinese)
    }

    func testUsesSystemForNilEmptyAndUnsupportedIdentifiers() {
        XCTAssertEqual(LanguageOption(identifier: nil), .system)
        XCTAssertEqual(LanguageOption(identifier: ""), .system)
        XCTAssertEqual(LanguageOption(identifier: "fr"), .system)
    }

    func testPopupValuesRoundTripToSettingsIdentifiers() {
        XCTAssertEqual(LanguageOption(popupValue: "").identifier, nil)
        XCTAssertEqual(LanguageOption(popupValue: "en").identifier, "en")
        XCTAssertEqual(LanguageOption(popupValue: "zh-Hans").identifier, "zh-Hans")
        XCTAssertEqual(LanguageOption(popupValue: "pt-BR").identifier, nil)
    }
}

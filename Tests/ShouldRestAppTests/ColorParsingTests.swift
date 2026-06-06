import AppKit
import XCTest
@testable import shouldrest

final class ColorParsingTests: XCTestCase {
    func testInvalidHexUsesProvidedFallbackInsteadOfBlack() {
        let color = NSColor(hex: "not-a-color", fallback: "#478484")

        assertColor(color, matchesHex: "#478484")
    }

    func testInvalidHexAndInvalidFallbackUseBlackAsLastResort() {
        let color = NSColor(hex: "not-a-color", fallback: "also-invalid")

        assertColor(color, matchesHex: "#000000")
    }

    private func assertColor(_ color: NSColor, matchesHex hex: String, file: StaticString = #filePath, line: UInt = #line) {
        let expected = NSColor(hex: hex)
        guard let actualRGB = color.usingColorSpace(.deviceRGB),
              let expectedRGB = expected.usingColorSpace(.deviceRGB) else {
            XCTFail("Unable to compare colors", file: file, line: line)
            return
        }

        XCTAssertEqual(actualRGB.redComponent, expectedRGB.redComponent, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualRGB.greenComponent, expectedRGB.greenComponent, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualRGB.blueComponent, expectedRGB.blueComponent, accuracy: 0.001, file: file, line: line)
    }
}

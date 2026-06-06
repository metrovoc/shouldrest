import AppKit
import XCTest
@testable import shouldrest

final class DisplayIdentifierTests: XCTestCase {
    func testParsesScreenNumberFromCommonDeviceDescriptionTypes() {
        XCTAssertEqual(DisplayIdentifier.directDisplayID(from: CGDirectDisplayID(42)), 42)
        XCTAssertEqual(DisplayIdentifier.directDisplayID(from: NSNumber(value: 43)), 43)
        XCTAssertEqual(DisplayIdentifier.directDisplayID(from: Int(44)), 44)
    }

    func testRejectsInvalidScreenNumberValues() {
        XCTAssertNil(DisplayIdentifier.directDisplayID(from: nil))
        XCTAssertNil(DisplayIdentifier.directDisplayID(from: NSNumber(value: 0)))
        XCTAssertNil(DisplayIdentifier.directDisplayID(from: NSNumber(value: -1)))
        XCTAssertNil(DisplayIdentifier.directDisplayID(from: NSNumber(value: true)))
        XCTAssertNil(DisplayIdentifier.directDisplayID(from: UInt64(CGDirectDisplayID.max) + 1))
    }

    func testFallsBackToStableSyntheticIDWhenScreenNumberIsUnavailable() {
        let frame = NSRect(x: 1440, y: 0, width: 1920, height: 1080)
        let first = DisplayIdentifier.value(from: [:], fallbackFrame: frame)
        let second = DisplayIdentifier.value(from: [:], fallbackFrame: frame)

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, 0)
        XCTAssertGreaterThanOrEqual(first, 0x8000_0000)
    }

    func testSyntheticIDsDistinguishDifferentScreenFrames() {
        let builtIn = DisplayIdentifier.syntheticDisplayID(for: NSRect(x: 0, y: 0, width: 1440, height: 900))
        let external = DisplayIdentifier.syntheticDisplayID(for: NSRect(x: 1440, y: 0, width: 1920, height: 1080))

        XCTAssertNotEqual(builtIn, external)
    }
}

import AppKit
import XCTest
@testable import shouldrest

@MainActor
final class RestGateIconTests: XCTestCase {
    func testMenuBarIconIsTemplateAndCompact() {
        let image = RestGateIcon.menuBarImage(accessibilityDescription: "ShouldRest")

        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.accessibilityDescription, "ShouldRest")
        XCTAssertNotNil(image.tiffRepresentation)
    }

    func testFallbackAppIconUsesRequestedSizeAndIsNotTemplate() {
        let image = RestGateIcon.fallbackAppImage(size: 64, accessibilityDescription: "ShouldRest")

        XCTAssertEqual(image.size, NSSize(width: 64, height: 64))
        XCTAssertFalse(image.isTemplate)
        XCTAssertEqual(image.accessibilityDescription, "ShouldRest")
        XCTAssertNotNil(image.tiffRepresentation)
    }
}

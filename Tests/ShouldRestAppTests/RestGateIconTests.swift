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

    func testMenuBarIconDrawsClosedEyeWithClearCorners() throws {
        let image = RestGateIcon.menuBarImage(accessibilityDescription: "ShouldRest")
        let bitmap = try XCTUnwrap(bitmapRepresentation(of: image))

        // The lid dips through the middle and the lashes hang below it.
        XCTAssertGreaterThan(maxAlpha(in: bitmap, x: 8...9, y: 8...10), 0.85)
        XCTAssertGreaterThan(maxAlpha(in: bitmap, x: 8...9, y: 11...12), 0.7)
        XCTAssertLessThan(maxAlpha(in: bitmap, x: 6...11, y: 1...4), 0.1)
        XCTAssertLessThan(averageAlpha(in: bitmap, x: 0...17, y: 15...17), 0.05)
    }

    func testMenuBarHealthIndicatorAddsCompactCornerBadgeWithoutChangingSize() throws {
        let image = RestGateIcon.menuBarImage(
            accessibilityDescription: "ShouldRest",
            badge: .restDebt
        )
        let bitmap = try XCTUnwrap(bitmapRepresentation(of: image))

        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        XCTAssertTrue(image.isTemplate)
        XCTAssertGreaterThan(maxAlpha(in: bitmap, x: 14...16, y: 1...3), 0.85)
    }

    func testGlyphImageIsTemplateAtRequestedSize() {
        let image = RestGateIcon.glyphImage(pointSize: 22, accessibilityDescription: "ShouldRest")

        XCTAssertEqual(image.size, NSSize(width: 22, height: 22))
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.accessibilityDescription, "ShouldRest")
    }

    func testFallbackAppIconUsesRequestedSizeAndIsNotTemplate() {
        let image = RestGateIcon.fallbackAppImage(size: 64, accessibilityDescription: "ShouldRest")

        XCTAssertEqual(image.size, NSSize(width: 64, height: 64))
        XCTAssertFalse(image.isTemplate)
        XCTAssertEqual(image.accessibilityDescription, "ShouldRest")
        XCTAssertNotNil(image.tiffRepresentation)
    }

    private func bitmapRepresentation(of image: NSImage) -> NSBitmapImageRep? {
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(image.size.width),
            pixelsHigh: Int(image.size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
        image.draw(
            in: NSRect(origin: .zero, size: image.size),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()
        return representation
    }

    private func maxAlpha(in bitmap: NSBitmapImageRep, x xRange: ClosedRange<Int>, y yRange: ClosedRange<Int>) -> CGFloat {
        var value: CGFloat = 0
        for x in xRange {
            for y in yRange {
                value = max(value, bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0)
            }
        }
        return value
    }

    private func averageAlpha(in bitmap: NSBitmapImageRep, x xRange: ClosedRange<Int>, y yRange: ClosedRange<Int>) -> CGFloat {
        var total: CGFloat = 0
        var count: CGFloat = 0
        for x in xRange {
            for y in yRange {
                total += bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0
                count += 1
            }
        }
        return count > 0 ? total / count : 0
    }
}

import AppKit
import XCTest
@testable import shouldrest

@MainActor
final class StatusMenuImageFactoryTests: XCTestCase {
    func testEyeMenuBarImageUsesBrandMarkInsteadOfSystemFallback() throws {
        let image = try XCTUnwrap(StatusMenuImageFactory.image(
            for: .eye,
            accessibilityDescription: "ShouldRest"
        ))
        let bitmap = try XCTUnwrap(bitmapRepresentation(of: image))

        XCTAssertEqual(StatusMenuImageFactory.cacheKey(for: .eye), "eye:full:none")
        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.accessibilityDescription, "ShouldRest")
        XCTAssertGreaterThan(maxAlpha(in: bitmap, x: 8...9, y: 8...12), 0.85)
        XCTAssertLessThan(maxAlpha(in: bitmap, x: 13...16, y: 0...3), 0.1)
    }

    func testRestDebtMenuBarImageUsesCompactBadgeWithoutTextOccupancy() throws {
        let icon = MenuStatusPresenter.MenuBarIcon(glyph: .eye, badge: .restDebt)
        let image = try XCTUnwrap(StatusMenuImageFactory.image(
            for: icon,
            accessibilityDescription: "ShouldRest: Debt 3/10"
        ))
        let bitmap = try XCTUnwrap(bitmapRepresentation(of: image))

        XCTAssertEqual(StatusMenuImageFactory.cacheKey(for: icon), "eye:full:restDebt")
        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.accessibilityDescription, "ShouldRest: Debt 3/10")
        XCTAssertGreaterThan(maxAlpha(in: bitmap, x: 14...16, y: 1...3), 0.85)
    }

    func testPausedMenuBarImageDimsTheEyeAndAddsPauseBadge() throws {
        let image = try XCTUnwrap(StatusMenuImageFactory.image(
            for: .paused,
            accessibilityDescription: "Paused"
        ))
        let bitmap = try XCTUnwrap(bitmapRepresentation(of: image))

        XCTAssertEqual(StatusMenuImageFactory.cacheKey(for: .paused), "eye:dimmed:paused")
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.accessibilityDescription, "Paused")
        let eyeAlpha = maxAlpha(in: bitmap, x: 8...9, y: 8...12)
        XCTAssertGreaterThan(eyeAlpha, 0.25)
        XCTAssertLessThan(eyeAlpha, 0.6)
        XCTAssertGreaterThan(maxAlpha(in: bitmap, x: 13...14, y: 1...4), 0.85)
    }

    func testDeferredMenuBarImageOnlyDimsTheEye() throws {
        let image = try XCTUnwrap(StatusMenuImageFactory.image(
            for: .deferred,
            accessibilityDescription: "Delayed"
        ))
        let bitmap = try XCTUnwrap(bitmapRepresentation(of: image))

        XCTAssertEqual(StatusMenuImageFactory.cacheKey(for: .deferred), "eye:dimmed:none")
        XCTAssertLessThan(maxAlpha(in: bitmap, x: 8...9, y: 8...12), 0.6)
        XCTAssertLessThan(maxAlpha(in: bitmap, x: 13...16, y: 0...3), 0.1)
    }

    func testBodyBreakMenuBarImageCanCarryRestDebtBadge() throws {
        let icon = MenuStatusPresenter.MenuBarIcon(glyph: .bodyBreak, badge: .restDebt)
        let image = try XCTUnwrap(StatusMenuImageFactory.image(
            for: icon,
            accessibilityDescription: "Body Break. Debt 4/10"
        ))
        let bitmap = try XCTUnwrap(bitmapRepresentation(of: image))

        XCTAssertEqual(StatusMenuImageFactory.cacheKey(for: icon), "bodyBreak:full:restDebt")
        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.accessibilityDescription, "Body Break. Debt 4/10")
        XCTAssertGreaterThan(maxAlpha(in: bitmap, x: 14...16, y: 1...3), 0.85)
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

    private func maxAlpha(
        in bitmap: NSBitmapImageRep,
        x xRange: ClosedRange<Int>,
        y yRange: ClosedRange<Int>
    ) -> CGFloat {
        var value: CGFloat = 0
        for x in xRange {
            for y in yRange {
                value = max(value, bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0)
            }
        }
        return value
    }

    private func averageAlpha(
        in bitmap: NSBitmapImageRep,
        x xRange: ClosedRange<Int>,
        y yRange: ClosedRange<Int>
    ) -> CGFloat {
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

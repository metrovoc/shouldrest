import AppKit
import XCTest
@testable import shouldrest

@MainActor
final class StatusMenuImageFactoryTests: XCTestCase {
    func testRestGateMenuBarImageUsesBrandMarkInsteadOfSystemFallback() throws {
        let image = try XCTUnwrap(StatusMenuImageFactory.image(
            for: .restGate,
            accessibilityDescription: "ShouldRest"
        ))
        let bitmap = try XCTUnwrap(bitmapRepresentation(of: image))

        XCTAssertEqual(StatusMenuImageFactory.cacheKey(for: .restGate), "restGate:brand")
        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.accessibilityDescription, "ShouldRest")
        XCTAssertGreaterThan(maxAlpha(in: bitmap, x: 7...8, y: 7...11), 0.70)
        XCTAssertGreaterThan(maxAlpha(in: bitmap, x: 10...11, y: 7...11), 0.70)
        XCTAssertLessThan(averageAlpha(in: bitmap, x: 12...13, y: 12...13), 0.42)
    }

    func testSystemStatusMenuImageUsesRequestedSymbolAndAccessibilityDescription() throws {
        let image = try XCTUnwrap(StatusMenuImageFactory.image(
            for: .systemSymbol("pause.circle"),
            accessibilityDescription: "Paused"
        ))

        XCTAssertEqual(StatusMenuImageFactory.cacheKey(for: .systemSymbol("pause.circle")), "symbol:pause.circle")
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.accessibilityDescription, "Paused")
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

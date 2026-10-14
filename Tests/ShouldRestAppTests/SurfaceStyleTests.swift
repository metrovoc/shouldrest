import AppKit
import XCTest
@testable import shouldrest

@MainActor
final class SurfaceStyleTests: XCTestCase {
    func testSurfacesApplyTheirStyleWhenCreated() throws {
        let card = SurfaceStackView(style: .card)
        let notice = SurfaceView(style: .accentNotice)

        XCTAssertNotNil(card.layer?.backgroundColor)
        XCTAssertEqual(card.layer?.cornerRadius, 12)
        XCTAssertEqual(card.layer?.cornerCurve, .continuous)
        XCTAssertNotNil(notice.layer?.backgroundColor)
        XCTAssertNotNil(notice.layer?.borderColor)
        XCTAssertEqual(notice.layer?.borderWidth, 1)
        XCTAssertLessThanOrEqual(notice.layer?.cornerRadius ?? 99, 8)
    }

    func testSurfaceColorsFollowAppearanceChanges() throws {
        let card = SurfaceStackView(style: .card)

        card.appearance = NSAppearance(named: .aqua)
        let light = try XCTUnwrap(card.layer?.backgroundColor?.components)
        card.appearance = NSAppearance(named: .darkAqua)
        let dark = try XCTUnwrap(card.layer?.backgroundColor?.components)

        // Light cards are a faint gray wash; dark cards a faint white lift.
        XCTAssertLessThan(light.first ?? 1, 0.5)
        XCTAssertGreaterThan(dark.first ?? 0, 0.5)
    }

    func testTranslucentStrokesKeepTheirOwnAlpha() throws {
        let card = SurfaceStackView(style: .card)
        card.appearance = NSAppearance(named: .aqua)

        let strokeAlpha = try XCTUnwrap(card.layer?.borderColor?.alpha)
        XCTAssertLessThan(strokeAlpha, 0.15)
    }
}

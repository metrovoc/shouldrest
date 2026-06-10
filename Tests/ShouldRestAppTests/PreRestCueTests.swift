import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreRestCueTests: XCTestCase {
    func testCueStyleUsesVisibleLowIntensityAccent() throws {
        let eyeStyle = PreRestCueStyle.make(kind: .eyeGate, settings: .defaults)
        let bodyStyle = PreRestCueStyle.make(kind: .bodyBreak, settings: .defaults)

        XCTAssertGreaterThan(eyeStyle.edgeThickness, 0)
        XCTAssertGreaterThan(eyeStyle.glowRadius, eyeStyle.edgeThickness)
        XCTAssertGreaterThan(eyeStyle.peakOpacity, eyeStyle.baseOpacity)
        XCTAssertEqual(eyeStyle.edgeThickness, 56)
        XCTAssertEqual(eyeStyle.glowRadius, 72)
        XCTAssertLessThanOrEqual(eyeStyle.peakOpacity, 0.40)
        XCTAssertLessThanOrEqual(bodyStyle.peakOpacity, 0.40)
        XCTAssertGreaterThan(try brightness(of: eyeStyle.accentColor), 0.45)
        XCTAssertGreaterThan(try brightness(of: bodyStyle.accentColor), 0.45)
        XCTAssertTrue(eyeStyle.fullScreenCueEnabled)
        XCTAssertTrue(bodyStyle.fullScreenCueEnabled)
        XCTAssertGreaterThan(eyeStyle.fillPeakOpacity, eyeStyle.fillBaseOpacity)
        XCTAssertGreaterThan(eyeStyle.vignettePeakOpacity, eyeStyle.vignetteBaseOpacity)
    }

    func testCueStyleCanDisableFullScreenPulseIndependently() {
        var settings = RestSettings.defaults
        settings.notifications.eyeGateFullScreenCueEnabled = false

        let style = PreRestCueStyle.make(kind: .eyeGate, settings: settings)

        XCTAssertFalse(style.fullScreenCueEnabled)
    }

    func testCueViewBuildsFullScreenAndScreenEdgeLayers() {
        let view = PreRestCueView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        view.configure(style: PreRestCueStyle.make(kind: .eyeGate, settings: .defaults), reduceMotion: true)

        XCTAssertTrue(view.wantsLayer)
        XCTAssertEqual(view.fullScreenLayerCountForTesting, 2)
        XCTAssertEqual(view.edgeLayerCountForTesting, 4)
        XCTAssertTrue(view.fullScreenCueEnabledForTesting)
    }

    func testCueViewKeepsEdgeLayersWhenFullScreenPulseIsDisabled() {
        var settings = RestSettings.defaults
        settings.notifications.eyeGateFullScreenCueEnabled = false
        let view = PreRestCueView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        view.configure(style: PreRestCueStyle.make(kind: .eyeGate, settings: settings), reduceMotion: true)

        XCTAssertEqual(view.fullScreenLayerCountForTesting, 2)
        XCTAssertEqual(view.edgeLayerCountForTesting, 4)
        XCTAssertFalse(view.fullScreenCueEnabledForTesting)
    }

    func testCueWindowDoesNotStealInputOrFocus() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let window = PreRestCueWindow(
            screen: screen,
            kind: .eyeGate,
            settings: .defaults,
            reduceMotion: true
        )
        defer { window.close() }

        XCTAssertFalse(window.canBecomeKey)
        XCTAssertFalse(window.canBecomeMain)
        XCTAssertTrue(window.ignoresMouseEvents)
        XCTAssertFalse(window.isOpaque)
        XCTAssertEqual(window.backgroundColor, .clear)
        XCTAssertEqual(window.level, .screenSaver)
        XCTAssertTrue(window.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(window.collectionBehavior.contains(.stationary))
        XCTAssertTrue(window.collectionBehavior.contains(.ignoresCycle))
        XCTAssertEqual(window.cueView.edgeLayerCountForTesting, 4)
    }

    func testCueWindowKeepsContentInLocalCoordinatesForNonZeroScreenFrames() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let window = PreRestCueWindow(
            screen: screen,
            kind: .eyeGate,
            settings: .defaults,
            reduceMotion: true
        )
        defer { window.close() }
        let frame = NSRect(x: 1800, y: 1169, width: 2560, height: 1440)

        window.setFrame(frame, display: true)

        XCTAssertEqual(window.frame, frame)
        XCTAssertEqual(window.cueView.frame.origin, .zero)
        XCTAssertEqual(window.cueView.frame.size, frame.size)
    }

    private func brightness(of color: NSColor, file: StaticString = #filePath, line: UInt = #line) throws -> CGFloat {
        let rgb = try XCTUnwrap(color.usingColorSpace(.deviceRGB), file: file, line: line)
        return (rgb.redComponent + rgb.greenComponent + rgb.blueComponent) / 3
    }
}

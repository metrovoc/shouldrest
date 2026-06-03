import XCTest
@testable import shouldrest

final class StatusMenuActionIconTests: XCTestCase {
    func testHighFrequencyMenuActionsHaveSystemSymbols() {
        let expectedSymbols = [
            "takeEyeGateNow": "timer",
            "takeBodyBreakNow": "figure.walk",
            "emergencyOverrideEyeGate": "exclamationmark.triangle",
            "postponeBodyBreak": "clock.arrow.circlepath",
            "skipBodyBreak": "forward.end",
            "resumeBreaks": "play.circle",
            "resetBreaks": "arrow.counterclockwise",
            "openPreferences": "gearshape",
            "copyDebugInfo": "doc.on.doc",
            "openDebugPanel": "stethoscope",
            "showAboutPanel": "info.circle",
            "showSettingsFile": "folder",
            "copySettingsPath": "doc.on.doc"
        ]

        for (actionName, symbolName) in expectedSymbols {
            XCTAssertEqual(StatusMenuActionIcon.symbolName(forActionName: actionName), symbolName)
        }
    }

    func testUnknownMenuActionsDoNotClaimAnIcon() {
        XCTAssertNil(StatusMenuActionIcon.symbolName(forActionName: "notARealMenuAction"))
    }
}

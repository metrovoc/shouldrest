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
            "checkForUpdatesNow": "arrow.triangle.2.circlepath",
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

    func testDisabledStatusMenuItemsCarryTooltipAndAccessibilityHelp() {
        let item = DisabledStatusMenuItemFactory.make(
            title: L10n.tr("menu.emergencyOverlayOnly"),
            toolTip: L10n.tr("menu.emergencyOverlayOnlyHelp")
        )

        XCTAssertFalse(item.isEnabled)
        XCTAssertEqual(item.title, L10n.tr("menu.emergencyOverlayOnly"))
        XCTAssertEqual(item.toolTip, L10n.tr("menu.emergencyOverlayOnlyHelp"))
        XCTAssertEqual(item.accessibilityHelp(), L10n.tr("menu.emergencyOverlayOnlyHelp"))
    }
}

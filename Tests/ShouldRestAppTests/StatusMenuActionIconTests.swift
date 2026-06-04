import AppKit
import XCTest
@testable import shouldrest

final class StatusMenuActionIconTests: XCTestCase {
    func testHighFrequencyMenuActionsHaveSystemSymbols() {
        let expectedSymbols = [
            "takeEyeGateNow": "timer",
            "takeBodyBreakNow": "figure.walk",
            "takeNextScheduledRestNow": "play.circle",
            "finishActiveBreak": "checkmark.circle",
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
        XCTAssertNotEqual(
            StatusMenuActionIcon.symbolName(forActionName: "takeNextScheduledRestNow"),
            StatusMenuActionIcon.symbolName(forActionName: "skipBodyBreak")
        )
    }

    func testUnknownMenuActionsDoNotClaimAnIcon() {
        XCTAssertNil(StatusMenuActionIcon.symbolName(forActionName: "notARealMenuAction"))
    }

    func testHighFrequencyMenuActionsHaveBehaviorHelp() {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        let expectedHelp = [
            "takeEyeGateNow": L10n.tr("menu.takeEyeGateNowHelp"),
            "takeBodyBreakNow": L10n.tr("menu.takeBodyBreakNowHelp"),
            "takeNextScheduledRestNow": L10n.tr("menu.takeNextScheduledRestNowHelp"),
            "postponeBodyBreak": L10n.tr("menu.postponeBodyBreakHelp"),
            "skipBodyBreak": L10n.tr("menu.skipBodyBreakHelp"),
            "resumeBreaks": L10n.tr("menu.resumeHelp"),
            "pauseFor30Minutes": L10n.tr("menu.pauseDurationHelp"),
            "pauseUntilMorning": L10n.tr("menu.pauseUntilMorningHelp"),
            "pauseIndefinitely": L10n.tr("menu.pauseIndefinitelyHelp"),
            "resetBreaks": L10n.tr("menu.resetHelp"),
            "openPreferences": L10n.tr("menu.preferencesHelp"),
            "checkForUpdatesNow": L10n.tr("menu.checkUpdatesHelp"),
            "copyDebugInfo": L10n.tr("menu.copyDebugHelp"),
            "openDebugPanel": L10n.tr("menu.debugPanelHelp"),
            "showAboutPanel": L10n.tr("menu.aboutHelp"),
            "showSettingsFile": L10n.tr("menu.showSettingsFileHelp"),
            "copySettingsPath": L10n.tr("menu.copySettingsPathHelp")
        ]

        for (actionName, help) in expectedHelp {
            XCTAssertEqual(StatusMenuActionHelp.help(forActionName: actionName), help, actionName)
        }

        let emergencyHelp = try! XCTUnwrap(StatusMenuActionHelp.help(forActionName: "emergencyOverrideEyeGate"))
        XCTAssertTrue(emergencyHelp.contains("overlay"))
        XCTAssertFalse(emergencyHelp.localizedCaseInsensitiveContains("shortcut again"))
    }

    func testSettingsLocationMenuKeepsRawPathOutOfHoverText() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"
        let target = StatusMenuActionTestTarget()
        let item = StatusMenuSettingsLocationMenuItemFactory.make(
            target: target,
            showAction: #selector(StatusMenuActionTestTarget.showSettingsFile),
            copyAction: #selector(StatusMenuActionTestTarget.copySettingsPath)
        )
        let submenu = try XCTUnwrap(item.submenu)
        let showItem = try XCTUnwrap(submenu.items.first)
        let copyItem = try XCTUnwrap(submenu.items.last)

        XCTAssertEqual(item.title, L10n.tr("menu.settingsFile"))
        XCTAssertEqual(item.toolTip, L10n.tr("menu.settingsFileHelp"))
        XCTAssertEqual(item.accessibilityHelp(), L10n.tr("menu.settingsFileHelp"))
        XCTAssertEqual(showItem.toolTip, L10n.tr("menu.showSettingsFileHelp"))
        XCTAssertEqual(showItem.accessibilityHelp(), L10n.tr("menu.showSettingsFileHelp"))
        XCTAssertEqual(copyItem.title, L10n.tr("menu.copySettingsPath"))
        XCTAssertEqual(copyItem.toolTip, L10n.tr("menu.copySettingsPathHelp"))
        XCTAssertEqual(copyItem.accessibilityHelp(), L10n.tr("menu.copySettingsPathHelp"))

        for menuItem in [item, showItem, copyItem] {
            XCTAssertFalse(menuItem.toolTip?.contains("\n") ?? true)
            XCTAssertFalse(menuItem.toolTip?.contains("/") ?? true)
            XCTAssertFalse(menuItem.accessibilityHelp()?.contains("/") ?? true)
            XCTAssertFalse(menuItem.toolTip?.localizedCaseInsensitiveContains("settings.json") ?? true)
        }
    }

    func testUnknownMenuActionsDoNotClaimHelp() {
        XCTAssertNil(StatusMenuActionHelp.help(forActionName: "notARealMenuAction"))
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
        XCTAssertTrue(item.toolTip?.contains("This menu cannot exit") ?? false)
        XCTAssertTrue(item.toolTip?.contains("lower-right Emergency Exit twice") ?? false)
        XCTAssertTrue(item.toolTip?.contains("Esc twice") ?? false)
        XCTAssertNil(item.image)
    }

    func testDisabledStatusMenuItemsCanCarryAccessibleStatusIcon() {
        let item = DisabledStatusMenuItemFactory.make(
            title: L10n.tr("menu.emergencyOverlayOnly"),
            toolTip: L10n.tr("menu.emergencyOverlayOnlyHelp"),
            symbolName: "info.circle"
        )

        XCTAssertFalse(item.isEnabled)
        XCTAssertNotNil(item.image)
        XCTAssertTrue(item.image?.isTemplate ?? false)
        XCTAssertEqual(item.image?.accessibilityDescription, L10n.tr("menu.emergencyOverlayOnly"))
        XCTAssertEqual(item.toolTip, L10n.tr("menu.emergencyOverlayOnlyHelp"))
        XCTAssertEqual(item.accessibilityHelp(), L10n.tr("menu.emergencyOverlayOnlyHelp"))
    }
}

private final class StatusMenuActionTestTarget: NSObject {
    @objc func showSettingsFile() {}
    @objc func copySettingsPath() {}
}

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
            "copySupportReport": "doc.on.doc",
            "openSupportReportPanel": "doc.text.magnifyingglass",
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
            "copySupportReport": L10n.tr("menu.copyDebugHelp"),
            "openSupportReportPanel": L10n.tr("menu.debugPanelHelp"),
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
        XCTAssertEqual(item.accessibilityLabel(), L10n.tr("menu.settingsFile"))
        XCTAssertEqual(item.accessibilityHelp(), L10n.tr("menu.settingsFileHelp"))
        XCTAssertEqual(showItem.toolTip, L10n.tr("menu.showSettingsFileHelp"))
        XCTAssertEqual(showItem.accessibilityLabel(), L10n.tr("menu.showSettingsFile"))
        XCTAssertEqual(showItem.accessibilityHelp(), L10n.tr("menu.showSettingsFileHelp"))
        XCTAssertEqual(copyItem.title, L10n.tr("menu.copySettingsPath"))
        XCTAssertEqual(copyItem.title, "Copy Settings Location")
        XCTAssertNotEqual(copyItem.title, "Copy Location")
        XCTAssertEqual(copyItem.toolTip, L10n.tr("menu.copySettingsPathHelp"))
        XCTAssertEqual(copyItem.accessibilityLabel(), L10n.tr("menu.copySettingsPath"))
        XCTAssertEqual(copyItem.accessibilityHelp(), L10n.tr("menu.copySettingsPathHelp"))

        for menuItem in [item, showItem, copyItem] {
            XCTAssertFalse(menuItem.toolTip?.contains("\n") ?? true)
            XCTAssertFalse(menuItem.toolTip?.contains("/") ?? true)
            XCTAssertFalse(menuItem.accessibilityHelp()?.contains("/") ?? true)
            XCTAssertFalse(menuItem.toolTip?.localizedCaseInsensitiveContains("settings.json") ?? true)
        }
    }

    func testSettingsLocationMenuIconsUseVisibleTitlesAsAccessibleDescriptions() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"
        let target = StatusMenuActionTestTarget()
        let item = StatusMenuSettingsLocationMenuItemFactory.make(
            target: target,
            showAction: #selector(StatusMenuActionTestTarget.showSettingsFile),
            copyAction: #selector(StatusMenuActionTestTarget.copySettingsPath),
            imageProvider: { symbolName in
                NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            }
        )
        let submenu = try XCTUnwrap(item.submenu)
        let showItem = try XCTUnwrap(submenu.items.first)
        let copyItem = try XCTUnwrap(submenu.items.last)

        XCTAssertEqual(item.image?.accessibilityDescription, item.title)
        XCTAssertEqual(showItem.image?.accessibilityDescription, showItem.title)
        XCTAssertEqual(copyItem.image?.accessibilityDescription, copyItem.title)
    }

    func testMenuItemPresentationUpdatesTooltipAccessibilityAndImageDescriptionTogether() {
        let image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        let item = NSMenuItem(title: "Preferences", action: nil, keyEquivalent: "")
        item.image = image

        StatusMenuItemPresentation.apply(help: "Open preferences.", to: item)

        XCTAssertEqual(item.toolTip, "Open preferences.")
        XCTAssertEqual(item.accessibilityLabel(), "Preferences")
        XCTAssertEqual(item.accessibilityHelp(), "Open preferences.")
        XCTAssertEqual(item.image?.accessibilityDescription, "Preferences")

        StatusMenuItemPresentation.apply(title: "Settings", help: "Open settings.", to: item)

        XCTAssertEqual(item.toolTip, "Open settings.")
        XCTAssertEqual(item.accessibilityLabel(), "Settings")
        XCTAssertEqual(item.accessibilityHelp(), "Open settings.")
        XCTAssertEqual(item.image?.accessibilityDescription, "Settings")
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
        XCTAssertEqual(item.accessibilityLabel(), L10n.tr("menu.emergencyOverlayOnly"))
        XCTAssertEqual(item.toolTip, L10n.tr("menu.emergencyOverlayOnlyHelp"))
        XCTAssertEqual(item.accessibilityHelp(), L10n.tr("menu.emergencyOverlayOnlyHelp"))
        XCTAssertTrue(item.toolTip?.contains("This menu cannot exit") ?? false)
        XCTAssertTrue(item.toolTip?.contains("Return to the overlay") ?? false)
        XCTAssertTrue(item.toolTip?.contains("Emergency Exit twice") ?? false)
        XCTAssertTrue(item.toolTip?.contains("Esc twice") ?? false)
        XCTAssertFalse(item.toolTip?.contains("lower-right") ?? true)
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
        XCTAssertEqual(item.accessibilityLabel(), L10n.tr("menu.emergencyOverlayOnly"))
        XCTAssertEqual(item.toolTip, L10n.tr("menu.emergencyOverlayOnlyHelp"))
        XCTAssertEqual(item.accessibilityHelp(), L10n.tr("menu.emergencyOverlayOnlyHelp"))
    }

    func testOverlayEmergencyFocusMenuItemIsEnabledButDoesNotExitFromMenu() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"
        let target = StatusMenuActionTestTarget()
        let item = StatusMenuOverlayFocusItemFactory.make(
            target: target,
            action: #selector(StatusMenuActionTestTarget.emergencyOverrideEyeGate),
            imageProvider: { symbolName in
                NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            }
        )

        XCTAssertTrue(item.isEnabled)
        XCTAssertTrue(item.target === target)
        XCTAssertEqual(item.action, #selector(StatusMenuActionTestTarget.emergencyOverrideEyeGate))
        XCTAssertEqual(item.title, L10n.tr("menu.emergencyOverlayOnly"))
        XCTAssertEqual(item.toolTip, L10n.tr("menu.emergencyOverlayOnlyHelp"))
        XCTAssertEqual(item.accessibilityLabel(), item.title)
        XCTAssertEqual(item.accessibilityHelp(), item.toolTip)
        XCTAssertTrue(item.image?.isTemplate ?? false)
        XCTAssertEqual(item.image?.accessibilityDescription, item.title)
        XCTAssertTrue(item.toolTip?.contains("This menu cannot exit") ?? false)
        XCTAssertTrue(item.toolTip?.contains("Return to the overlay") ?? false)
        XCTAssertTrue(item.toolTip?.contains("Emergency Exit twice") ?? false)
        XCTAssertTrue(item.toolTip?.contains("Esc twice") ?? false)
    }
}

private final class StatusMenuActionTestTarget: NSObject {
    @objc func showSettingsFile() {}
    @objc func copySettingsPath() {}
    @objc func emergencyOverrideEyeGate() {}
}

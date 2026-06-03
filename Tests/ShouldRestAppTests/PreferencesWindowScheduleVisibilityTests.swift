import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowScheduleVisibilityTests: XCTestCase {
    func testDisabledEyeGateHidesDependentScheduleRows() throws {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = false
        settings.bodyBreak.isEnabled = true
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectScheduleTab(in: contentView)

        XCTAssertFalse(try view(withIdentifier: "prefs.eyeEnabled", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.eyeIntervalRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.eyeDurationRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.eyeColorRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.eyeNotify", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.eyeLeadRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.eyeManualFinish", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.eyeEmergencyOverride", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.eyeEmergencyHoldRow", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.everyMinutes")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.eyeEmergencyHold")))
    }

    func testEyeNotificationAndEmergencyRowsHideWhenTheirSwitchesAreOffAndAutosave() throws {
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectScheduleTab(in: contentView)
        let notify = try XCTUnwrap(view(withIdentifier: "prefs.eyeNotify", in: contentView) as? NSButton)
        notify.state = .off

        XCTAssertTrue(sendAction(from: notify))
        XCTAssertTrue(try view(withIdentifier: "prefs.eyeLeadRow", in: contentView).isHidden)
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.notifications.eyeGateEnabled, false)

        savedSettings.value = nil
        let emergency = try XCTUnwrap(view(withIdentifier: "prefs.eyeEmergencyOverride", in: contentView) as? NSButton)
        emergency.state = .off

        XCTAssertTrue(sendAction(from: emergency))
        XCTAssertTrue(try view(withIdentifier: "prefs.eyeEmergencyHoldRow", in: contentView).isHidden)
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.eyeGate.emergencyOverride.isEnabled, false)
    }

    func testDisabledBodyBreakHidesDependentScheduleRows() throws {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = true
        settings.bodyBreak.isEnabled = false
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectScheduleTab(in: contentView)

        XCTAssertFalse(try view(withIdentifier: "prefs.bodyEnabled", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyIntervalRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyDurationRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyAfterEyeGatesRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyColorRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyNotify", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyLeadRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyPostponeMinutesRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyPostponeLimitRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyPostponeWindowPercentRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyAllowSkip", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyManualFinish", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyCoversAllDisplays", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyCoveredDisplayRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyContentDisplayRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyBlankSecondaryDisplays", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyConfiguredDisplayRow", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.bodyIntervalMinutes")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.afterEyeGates")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.maxPostpones")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.bodyContentDisplay")))
    }

    func testBodyNotificationLeadRowHidesWhenNotificationIsOffAndAutosaves() throws {
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectScheduleTab(in: contentView)
        let notify = try XCTUnwrap(view(withIdentifier: "prefs.bodyNotify", in: contentView) as? NSButton)
        notify.state = .off

        XCTAssertTrue(sendAction(from: notify))
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyLeadRow", in: contentView).isHidden)
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.notifications.bodyBreakEnabled, false)
    }

    private func selectScheduleTab(in view: NSView) throws {
        let tabView = try XCTUnwrap(firstTabView(in: view))
        tabView.selectTabViewItem(withIdentifier: L10n.tr("prefs.tabSchedule"))
    }

    private func firstTabView(in view: NSView) -> NSTabView? {
        if let tabView = view as? NSTabView {
            return tabView
        }
        for subview in view.subviews {
            if let found = firstTabView(in: subview) {
                return found
            }
        }
        return nil
    }

    private func view(withIdentifier identifier: String, in rootView: NSView) throws -> NSView {
        try XCTUnwrap(findView(withIdentifier: identifier, in: rootView))
    }

    private func findView(withIdentifier identifier: String, in view: NSView) -> NSView? {
        if view.identifier?.rawValue == identifier {
            return view
        }
        for subview in view.subviews {
            if let found = self.findView(withIdentifier: identifier, in: subview) {
                return found
            }
        }
        return nil
    }

    private func sendAction(from control: NSControl) -> Bool {
        guard let action = control.action else { return false }
        return NSApplication.shared.sendAction(action, to: control.target, from: control)
    }

    private func waitUntilSavedSettingsArrive(_ settings: SavedSettingsBox) {
        let deadline = Date().addingTimeInterval(2)
        while settings.value == nil && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private func visibleTexts(in view: NSView, ancestorHidden: Bool = false) -> [String] {
        let hidden = ancestorHidden || view.isHidden
        var texts: [String] = []
        if !hidden {
            if let popup = view as? NSPopUpButton, !popup.title.isEmpty {
                texts.append(popup.title)
            } else if let button = view as? NSButton, !button.title.isEmpty {
                texts.append(button.title)
            } else if let textField = view as? NSTextField, !textField.stringValue.isEmpty {
                texts.append(textField.stringValue)
            }
        }
        for subview in view.subviews {
            texts.append(contentsOf: visibleTexts(in: subview, ancestorHidden: hidden))
        }
        return texts
    }
}

private final class SavedSettingsBox {
    var value: RestSettings?
}

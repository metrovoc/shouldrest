import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowScheduleVisibilityTests: XCTestCase {
    func testScheduleTabShowsReadableCurrentRhythmSummary() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectScheduleTab(in: contentView)

        let summary = try XCTUnwrap(view(withIdentifier: "prefs.scheduleSummary", in: contentView) as? NSStackView)
        let icon = try XCTUnwrap(view(withIdentifier: "prefs.scheduleSummaryIcon", in: contentView) as? NSImageView)
        let label = try XCTUnwrap(view(withIdentifier: "prefs.scheduleSummaryLabel", in: contentView) as? NSTextField)

        XCTAssertFalse(summary.isHidden)
        XCTAssertNotNil(icon.image)
        XCTAssertEqual(
            label.stringValue,
            L10n.format("prefs.scheduleSummary.eyeAndBody", 20, 20, 60, 3)
        )
        XCTAssertEqual(label.toolTip, label.stringValue)
        XCTAssertEqual(label.accessibilityLabel(), label.stringValue)
        XCTAssertEqual(label.accessibilityHelp(), label.stringValue)
        XCTAssertEqual(icon.image?.accessibilityDescription, label.stringValue)
        XCTAssertEqual(icon.accessibilityHelp(), label.stringValue)
    }

    func testScheduleControlsExposeBehaviorHelp() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectScheduleTab(in: contentView)

        let expectedHelp: [(identifier: String, helpKey: String)] = [
            ("prefs.eyeEnabled", "prefs.enableEyeGateHelp"),
            ("eyeIntervalField", "prefs.eyeIntervalHelp"),
            ("eyeIntervalStepper", "prefs.eyeIntervalHelp"),
            ("eyeIntervalSlider", "prefs.eyeIntervalHelp"),
            ("eyeDurationField", "prefs.eyeDurationHelp"),
            ("eyeDurationStepper", "prefs.eyeDurationHelp"),
            ("eyeDurationSlider", "prefs.eyeDurationHelp"),
            ("prefs.eyeNotify", "prefs.notifyEyeGateHelp"),
            ("eyeLeadField", "prefs.notificationLeadHelp"),
            ("eyeLeadStepper", "prefs.notificationLeadHelp"),
            ("prefs.bodyEnabled", "prefs.enableBodyBreakHelp"),
            ("bodyIntervalField", "prefs.bodyIntervalHelp"),
            ("bodyIntervalStepper", "prefs.bodyIntervalHelp"),
            ("bodyIntervalSlider", "prefs.bodyIntervalHelp"),
            ("bodyDurationField", "prefs.bodyDurationHelp"),
            ("bodyDurationStepper", "prefs.bodyDurationHelp"),
            ("bodyDurationSlider", "prefs.bodyDurationHelp"),
            ("prefs.bodyNotify", "prefs.notifyBodyBreakHelp"),
            ("bodyLeadField", "prefs.notificationLeadHelp"),
            ("bodyLeadStepper", "prefs.notificationLeadHelp"),
            ("bodyPostponeMinutesField", "prefs.bodyPostponeMinutesHelp"),
            ("bodyPostponeMinutesStepper", "prefs.bodyPostponeMinutesHelp"),
            ("bodyPostponeLimitField", "prefs.bodyPostponeLimitHelp"),
            ("bodyPostponeLimitStepper", "prefs.bodyPostponeLimitHelp"),
            ("bodyPostponeWindowPercentField", "prefs.bodyPostponeWindowPercentHelp"),
            ("bodyPostponeWindowPercentStepper", "prefs.bodyPostponeWindowPercentHelp"),
            ("prefs.bodyCoversAllDisplays", "prefs.bodyAllDisplaysHelp"),
            ("prefs.bodyCoveredDisplay", "prefs.bodyCoveredDisplayHelp"),
            ("prefs.bodyContentDisplay", "prefs.bodyContentDisplayHelp"),
            ("prefs.bodyBlankSecondaryDisplays", "prefs.bodyBlankSecondaryHelp"),
            ("prefs.bodyConfiguredDisplay", "prefs.configuredDisplayIndexHelp")
        ]

        for expectation in expectedHelp {
            let control = try XCTUnwrap(
                view(withIdentifier: expectation.identifier, in: contentView) as? NSControl,
                expectation.identifier
            )
            XCTAssertEqual(control.toolTip, L10n.tr(expectation.helpKey), expectation.identifier)
            XCTAssertEqual(control.accessibilityHelp(), L10n.tr(expectation.helpKey), expectation.identifier)
        }
        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.enableEyeGateHelp")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.eyeManualFinishHelp")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.eyeEmergencyOverrideHelp")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.enableBodyBreakHelp")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.bodyAllowSkipHelp")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.eyeIntervalHelp")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.bodyPostponeLimitHelp")))

        try assertInlineHelp("prefs.eyeEnabledHelp", text: L10n.tr("prefs.enableEyeGateHelp"), in: contentView)
        try assertInlineHelp("prefs.eyeManualFinishHelp", text: L10n.tr("prefs.eyeManualFinishHelp"), in: contentView)
        try assertInlineHelp("prefs.eyeEmergencyOverrideHelp", text: L10n.tr("prefs.eyeEmergencyOverrideHelp"), in: contentView)
        try assertInlineHelp("prefs.bodyEnabledHelp", text: L10n.tr("prefs.enableBodyBreakHelp"), in: contentView)
        try assertInlineHelp("prefs.bodyAllowSkipHelp", text: L10n.tr("prefs.bodyAllowSkipHelp"), in: contentView)
    }

    func testScheduleSummaryUpdatesWhenCoreSliderChangesAndAutosaves() throws {
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectScheduleTab(in: contentView)
        let slider = try XCTUnwrap(view(withIdentifier: "eyeIntervalSlider", in: contentView) as? NSSlider)
        let label = try XCTUnwrap(view(withIdentifier: "prefs.scheduleSummaryLabel", in: contentView) as? NSTextField)

        slider.doubleValue = 45
        XCTAssertTrue(sendAction(from: slider))

        XCTAssertEqual(
            label.stringValue,
            L10n.format("prefs.scheduleSummary.eyeAndBody", 45, 20, 60, 3)
        )
        XCTAssertEqual(label.accessibilityLabel(), label.stringValue)
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.eyeGate.interval, 45 * 60)
    }

    func testScheduleSummaryFollowsDisabledRestTypes() throws {
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectScheduleTab(in: contentView)
        let bodyEnabled = try XCTUnwrap(view(withIdentifier: "prefs.bodyEnabled", in: contentView) as? NSButton)
        let eyeEnabled = try XCTUnwrap(view(withIdentifier: "prefs.eyeEnabled", in: contentView) as? NSButton)
        let label = try XCTUnwrap(view(withIdentifier: "prefs.scheduleSummaryLabel", in: contentView) as? NSTextField)

        bodyEnabled.state = .off
        XCTAssertTrue(sendAction(from: bodyEnabled))

        XCTAssertEqual(
            label.stringValue,
            L10n.format("prefs.scheduleSummary.eyeOnly", 20, 20)
        )
        XCTAssertEqual(label.accessibilityLabel(), label.stringValue)
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.bodyBreak.isEnabled, false)

        savedSettings.value = nil
        bodyEnabled.state = .on
        XCTAssertTrue(sendAction(from: bodyEnabled))
        waitUntilSavedSettingsArrive(savedSettings)

        savedSettings.value = nil
        eyeEnabled.state = .off
        XCTAssertTrue(sendAction(from: eyeEnabled))

        XCTAssertEqual(
            label.stringValue,
            L10n.format("prefs.scheduleSummary.bodyOnly", 60, 3)
        )
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.eyeGate.isEnabled, false)
    }

    func testLastEnabledRestTypeCannotBeDisabledFromScheduleUI() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectScheduleTab(in: contentView)
        let bodyEnabled = try XCTUnwrap(view(withIdentifier: "prefs.bodyEnabled", in: contentView) as? NSButton)
        let eyeEnabled = try XCTUnwrap(view(withIdentifier: "prefs.eyeEnabled", in: contentView) as? NSButton)

        XCTAssertTrue(eyeEnabled.isEnabled)
        XCTAssertTrue(bodyEnabled.isEnabled)

        bodyEnabled.state = .off
        XCTAssertTrue(sendAction(from: bodyEnabled))

        XCTAssertFalse(eyeEnabled.isEnabled)
        XCTAssertTrue(bodyEnabled.isEnabled)
        XCTAssertEqual(eyeEnabled.toolTip, L10n.tr("prefs.cannotDisableEyeGateLastRest"))
        XCTAssertEqual(eyeEnabled.accessibilityHelp(), L10n.tr("prefs.cannotDisableEyeGateLastRest"))
        let eyeEnabledHelp = try XCTUnwrap(view(withIdentifier: "prefs.eyeEnabledHelp", in: contentView) as? NSTextField)
        XCTAssertEqual(eyeEnabledHelp.stringValue, L10n.tr("prefs.cannotDisableEyeGateLastRest"))
        XCTAssertEqual(eyeEnabledHelp.toolTip, L10n.tr("prefs.cannotDisableEyeGateLastRest"))

        bodyEnabled.state = .on
        XCTAssertTrue(sendAction(from: bodyEnabled))
        eyeEnabled.state = .off
        XCTAssertTrue(sendAction(from: eyeEnabled))

        XCTAssertTrue(eyeEnabled.isEnabled)
        XCTAssertFalse(bodyEnabled.isEnabled)
        XCTAssertEqual(eyeEnabled.toolTip, L10n.tr("prefs.enableEyeGateHelp"))
        XCTAssertEqual(eyeEnabled.accessibilityHelp(), L10n.tr("prefs.enableEyeGateHelp"))
        XCTAssertEqual(bodyEnabled.toolTip, L10n.tr("prefs.cannotDisableBodyBreakLastRest"))
        XCTAssertEqual(bodyEnabled.accessibilityHelp(), L10n.tr("prefs.cannotDisableBodyBreakLastRest"))
        XCTAssertEqual(eyeEnabledHelp.stringValue, L10n.tr("prefs.enableEyeGateHelp"))
        let bodyEnabledHelp = try XCTUnwrap(view(withIdentifier: "prefs.bodyEnabledHelp", in: contentView) as? NSTextField)
        XCTAssertEqual(bodyEnabledHelp.stringValue, L10n.tr("prefs.cannotDisableBodyBreakLastRest"))
        XCTAssertEqual(bodyEnabledHelp.toolTip, L10n.tr("prefs.cannotDisableBodyBreakLastRest"))
    }

    func testCannotDisableBothRestsAlertExplainsRecoveryAction() {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })

        let alert = controller.makeCannotDisableBothRestsAlert()

        XCTAssertEqual(alert.messageText, L10n.tr("prefs.cannotDisableBothRests"))
        XCTAssertEqual(alert.informativeText, L10n.tr("prefs.cannotDisableBothRestsHelp"))
        XCTAssertEqual(alert.alertStyle, .warning)
    }

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
        XCTAssertTrue(try view(withIdentifier: "prefs.eyeManualFinishHelpRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.eyeEmergencyOverride", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.eyeEmergencyOverrideHelpRow", in: contentView).isHidden)
        XCTAssertNil(findView(withIdentifier: "prefs.eyeEmergencyHoldRow", in: contentView))
        XCTAssertFalse(try view(withIdentifier: "prefs.bodyIntervalRow", in: contentView).isHidden)
    }

    func testReenablingEyeGateKeepsBodyIntervalIndependentAndAutosaves() throws {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = false
        settings.bodyBreak.isEnabled = true
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectScheduleTab(in: contentView)
        let eyeEnabled = try XCTUnwrap(view(withIdentifier: "prefs.eyeEnabled", in: contentView) as? NSButton)
        XCTAssertFalse(try view(withIdentifier: "prefs.bodyIntervalRow", in: contentView).isHidden)

        eyeEnabled.state = .on
        XCTAssertTrue(sendAction(from: eyeEnabled))

        XCTAssertFalse(try view(withIdentifier: "prefs.bodyIntervalRow", in: contentView).isHidden)
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.eyeGate.isEnabled, true)
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
        let statusLabel = try XCTUnwrap(view(withIdentifier: "autosaveStatusLabel", in: contentView) as? NSTextField)
        emergency.state = .off

        XCTAssertTrue(sendAction(from: emergency))
        XCTAssertNil(findView(withIdentifier: "prefs.eyeEmergencyHoldRow", in: contentView))
        try assertInlineHelp(
            "prefs.eyeEmergencyOverrideHelp",
            text: L10n.tr("prefs.eyeEmergencyOverrideDisabledHelp"),
            in: contentView
        )
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.eyeGate.emergencyOverride.isEnabled, false)
        XCTAssertEqual(statusLabel.stringValue, L10n.tr("prefs.autosaveEmergencyExitDisabled"))
        XCTAssertEqual(statusLabel.toolTip, L10n.tr("prefs.autosaveEmergencyExitDisabled"))

        savedSettings.value = nil
        emergency.state = .on

        XCTAssertTrue(sendAction(from: emergency))
        try assertInlineHelp(
            "prefs.eyeEmergencyOverrideHelp",
            text: L10n.tr("prefs.eyeEmergencyOverrideHelp"),
            in: contentView
        )
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.eyeGate.emergencyOverride.isEnabled, true)
        XCTAssertEqual(statusLabel.stringValue, L10n.tr("prefs.autosaveEmergencyExitEnabled"))
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
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyColorRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyNotify", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyLeadRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyPostponeMinutesRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyPostponeLimitRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyPostponeWindowPercentRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyAllowSkip", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyAllowSkipHelpRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyManualFinish", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyCoversAllDisplays", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyCoveredDisplayRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyContentDisplayRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyBlankSecondaryDisplays", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyConfiguredDisplayRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyDisplaySummaryLabel", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.maxPostpones")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.bodyContentDisplay")))
    }

    func testDisablingBodyPostponesHidesPostponeDurationAndWindowAndAutosaves() throws {
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectScheduleTab(in: contentView)
        let postponeLimit = try XCTUnwrap(view(withIdentifier: "bodyPostponeLimitField", in: contentView) as? NSTextField)
        XCTAssertFalse(try view(withIdentifier: "prefs.bodyPostponeMinutesRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.bodyPostponeWindowPercentRow", in: contentView).isHidden)

        postponeLimit.stringValue = "0"
        controller.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: postponeLimit))

        XCTAssertTrue(try view(withIdentifier: "prefs.bodyPostponeMinutesRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyPostponeWindowPercentRow", in: contentView).isHidden)
        var texts = visibleTexts(in: contentView)
        XCTAssertFalse(texts.contains(L10n.tr("prefs.postponeMinutes")))
        XCTAssertFalse(texts.contains(L10n.tr("prefs.postponeWindowPercent")))
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertFalse(savedSettings.value?.bodyBreak.postpone.isEnabled ?? true)
        XCTAssertEqual(savedSettings.value?.bodyBreak.postpone.maxCount, 0)

        savedSettings.value = nil
        postponeLimit.stringValue = "1"
        controller.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: postponeLimit))

        XCTAssertFalse(try view(withIdentifier: "prefs.bodyPostponeMinutesRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.bodyPostponeWindowPercentRow", in: contentView).isHidden)
        texts = visibleTexts(in: contentView)
        XCTAssertTrue(texts.contains(L10n.tr("prefs.postponeMinutes")))
        XCTAssertTrue(texts.contains(L10n.tr("prefs.postponeWindowPercent")))
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertTrue(savedSettings.value?.bodyBreak.postpone.isEnabled ?? false)
        XCTAssertEqual(savedSettings.value?.bodyBreak.postpone.maxCount, 1)
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

    private func assertInlineHelp(_ identifier: String, text: String, in rootView: NSView) throws {
        let label = try XCTUnwrap(view(withIdentifier: identifier, in: rootView) as? NSTextField)
        XCTAssertEqual(label.stringValue, text)
        XCTAssertEqual(label.toolTip, text)
        XCTAssertEqual(label.accessibilityLabel(), text)
        XCTAssertEqual(label.accessibilityHelp(), text)
        XCTAssertEqual(label.maximumNumberOfLines, 2)
        XCTAssertEqual(label.lineBreakMode, .byWordWrapping)
        XCTAssertFalse(label.isHidden)
        let row = try view(withIdentifier: "\(identifier)Row", in: rootView)
        XCTAssertFalse(row.isHidden)
        XCTAssertEqual(row.toolTip, text)
        XCTAssertEqual(row.accessibilityHelp(), text)
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

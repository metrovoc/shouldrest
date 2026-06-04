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
            L10n.format("prefs.scheduleSummary.eyeAndBody", 10, 20, 4, 5)
        )
    }

    func testScheduleRhythmPresetsExposeIconButtonsWithHelp() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectScheduleTab(in: contentView)

        let row = try XCTUnwrap(view(withIdentifier: "prefs.rhythmPresetRow", in: contentView) as? NSStackView)
        let recommended = try XCTUnwrap(view(withIdentifier: "prefs.rhythmPreset.recommended", in: contentView) as? NSButton)
        let frequentEye = try XCTUnwrap(view(withIdentifier: "prefs.rhythmPreset.frequentEye", in: contentView) as? NSButton)
        let movement = try XCTUnwrap(view(withIdentifier: "prefs.rhythmPreset.movement", in: contentView) as? NSButton)

        XCTAssertFalse(row.isHidden)
        XCTAssertEqual(recommended.title, L10n.tr("prefs.rhythmPreset.recommended"))
        XCTAssertEqual(frequentEye.title, L10n.tr("prefs.rhythmPreset.frequentEye"))
        XCTAssertEqual(movement.title, L10n.tr("prefs.rhythmPreset.movement"))
        [recommended, frequentEye, movement].forEach { button in
            XCTAssertNotNil(button.image)
            XCTAssertEqual(button.imagePosition, .imageLeading)
            XCTAssertFalse(button.toolTip?.isEmpty ?? true)
            XCTAssertEqual(button.accessibilityLabel(), button.title)
            XCTAssertEqual(button.accessibilityHelp(), button.toolTip)
        }
        XCTAssertEqual(recommended.state, .off)
        XCTAssertEqual(frequentEye.state, .on)
        XCTAssertEqual(movement.state, .off)
        XCTAssertNil(recommended.contentTintColor)
        XCTAssertNotNil(frequentEye.contentTintColor)
        XCTAssertNil(movement.contentTintColor)
        XCTAssertEqual(
            frequentEye.toolTip,
            L10n.format(
                "prefs.rhythmPreset.selectedHelp",
                RestRhythmPreset.frequentEye.title,
                RestRhythmPreset.frequentEye.help
            )
        )
    }

    func testFrequentEyeRhythmPresetUpdatesFieldsSlidersSummaryAndAutosaves() throws {
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectScheduleTab(in: contentView)
        let preset = try XCTUnwrap(view(withIdentifier: "prefs.rhythmPreset.frequentEye", in: contentView) as? NSButton)
        let eyeInterval = try XCTUnwrap(view(withIdentifier: "eyeIntervalField", in: contentView) as? NSTextField)
        let eyeIntervalSlider = try XCTUnwrap(view(withIdentifier: "eyeIntervalSlider", in: contentView) as? NSSlider)
        let bodyAfterEyeGates = try XCTUnwrap(view(withIdentifier: "bodyAfterEyeGatesField", in: contentView) as? NSTextField)
        let summary = try XCTUnwrap(view(withIdentifier: "prefs.scheduleSummaryLabel", in: contentView) as? NSTextField)

        XCTAssertTrue(sendAction(from: preset))

        XCTAssertEqual(eyeInterval.stringValue, "10")
        XCTAssertEqual(eyeIntervalSlider.doubleValue, 10)
        XCTAssertEqual(bodyAfterEyeGates.stringValue, "4")
        XCTAssertEqual(
            summary.stringValue,
            L10n.format("prefs.scheduleSummary.eyeAndBody", 10, 20, 4, 5)
        )
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.eyeGate.isEnabled, true)
        XCTAssertEqual(savedSettings.value?.bodyBreak.isEnabled, true)
        XCTAssertEqual(savedSettings.value?.eyeGate.interval, 10 * 60)
        XCTAssertEqual(savedSettings.value?.eyeGate.duration, 20)
        XCTAssertEqual(savedSettings.value?.bodyBreakAfterEyeGates, 4)
        XCTAssertEqual(savedSettings.value?.bodyBreak.duration, 5 * 60)
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
            L10n.format("prefs.scheduleSummary.eyeAndBody", 45, 20, 4, 5)
        )
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.eyeGate.interval, 45 * 60)
    }

    func testRhythmPresetSelectionFollowsAppliedAndCustomScheduleValues() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectScheduleTab(in: contentView)
        let frequentEye = try XCTUnwrap(view(withIdentifier: "prefs.rhythmPreset.frequentEye", in: contentView) as? NSButton)
        let movement = try XCTUnwrap(view(withIdentifier: "prefs.rhythmPreset.movement", in: contentView) as? NSButton)
        let bodyDurationSlider = try XCTUnwrap(view(withIdentifier: "bodyDurationSlider", in: contentView) as? NSSlider)

        XCTAssertEqual(frequentEye.state, .on)
        XCTAssertEqual(movement.state, .off)

        XCTAssertTrue(sendAction(from: movement))

        XCTAssertEqual(frequentEye.state, .off)
        XCTAssertEqual(movement.state, .on)
        XCTAssertEqual(
            movement.toolTip,
            L10n.format(
                "prefs.rhythmPreset.selectedHelp",
                RestRhythmPreset.movement.title,
                RestRhythmPreset.movement.help
            )
        )

        bodyDurationSlider.doubleValue = 7
        XCTAssertTrue(sendAction(from: bodyDurationSlider))

        XCTAssertEqual(frequentEye.state, .off)
        XCTAssertEqual(movement.state, .off)
        XCTAssertNil(frequentEye.contentTintColor)
        XCTAssertNil(movement.contentTintColor)
        XCTAssertEqual(
            movement.toolTip,
            L10n.format(
                "prefs.rhythmPreset.applyHelp",
                RestRhythmPreset.movement.title,
                RestRhythmPreset.movement.help
            )
        )
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
            L10n.format("prefs.scheduleSummary.eyeOnly", 10, 20)
        )
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
            L10n.format("prefs.scheduleSummary.bodyOnly", 20, 5)
        )
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.eyeGate.isEnabled, false)
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
        XCTAssertTrue(try view(withIdentifier: "prefs.eyeEmergencyOverride", in: contentView).isHidden)
        XCTAssertNil(findView(withIdentifier: "prefs.eyeEmergencyHoldRow", in: contentView))
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyAfterEyeGatesRow", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.everyMinutes")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.afterEyeGates")))
    }

    func testReenablingEyeGateShowsBodyAfterEyeGatesAndAutosaves() throws {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = false
        settings.bodyBreak.isEnabled = true
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectScheduleTab(in: contentView)
        let eyeEnabled = try XCTUnwrap(view(withIdentifier: "prefs.eyeEnabled", in: contentView) as? NSButton)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyAfterEyeGatesRow", in: contentView).isHidden)

        eyeEnabled.state = .on
        XCTAssertTrue(sendAction(from: eyeEnabled))

        XCTAssertFalse(try view(withIdentifier: "prefs.bodyAfterEyeGatesRow", in: contentView).isHidden)
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
        emergency.state = .off

        XCTAssertTrue(sendAction(from: emergency))
        XCTAssertNil(findView(withIdentifier: "prefs.eyeEmergencyHoldRow", in: contentView))
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

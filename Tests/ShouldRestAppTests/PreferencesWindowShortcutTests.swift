import AppKit
import Carbon
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowShortcutTests: XCTestCase {
    func testShortcutRecorderUsesCompactStatefulDisplay() {
        let button = ShortcutRecorderButton()

        XCTAssertEqual(button.title, L10n.tr("shortcut.add"))
        XCTAssertEqual(button.toolTip, L10n.tr("shortcut.recordHelp"))
        XCTAssertNotNil(button.image)
        XCTAssertEqual(button.imagePosition, .imageLeading)
        XCTAssertEqual(button.accessibilityLabel(), L10n.tr("shortcut.add"))
        XCTAssertEqual(button.accessibilityHelp(), L10n.tr("shortcut.recordHelp"))
        XCTAssertEqual(button.image?.accessibilityDescription, L10n.tr("shortcut.add"))
        XCTAssertNotEqual(button.image?.accessibilityDescription, "keyboard.badge.ellipsis")

        button.shortcutValue = "CmdOrCtrl+Option+E"
        XCTAssertEqual(button.title, "⌘⌥E")
        XCTAssertEqual(button.toolTip, L10n.tr("shortcut.clearHelp"))
        XCTAssertNotNil(button.image)
        XCTAssertEqual(button.accessibilityLabel(), "⌘⌥E")
        XCTAssertEqual(button.accessibilityHelp(), L10n.tr("shortcut.clearHelp"))
        XCTAssertEqual(button.image?.accessibilityDescription, "⌘⌥E")

        button.performClick(nil)
        XCTAssertEqual(button.title, L10n.tr("shortcut.recording"))
        XCTAssertEqual(button.toolTip, L10n.tr("shortcut.recordingHelp"))
        XCTAssertNotNil(button.image)
        XCTAssertEqual(button.accessibilityLabel(), L10n.tr("shortcut.recording"))
        XCTAssertEqual(button.accessibilityHelp(), L10n.tr("shortcut.recordingHelp"))
        XCTAssertEqual(button.image?.accessibilityDescription, L10n.tr("shortcut.recording"))
    }

    func testInvalidShortcutInputShowsVisibleRecordingFeedbackAndKeepsRecording() throws {
        let button = ShortcutRecorderButton()
        var changeCount = 0
        button.onChange = { changeCount += 1 }

        button.performClick(nil)
        button.keyDown(with: try keyEvent(keyCode: kVK_ANSI_A, characters: "a"))

        XCTAssertEqual(button.title, L10n.tr("shortcut.recordingInvalid"))
        XCTAssertEqual(button.toolTip, L10n.tr("shortcut.recordingHelp"))
        XCTAssertEqual(button.accessibilityLabel(), L10n.tr("shortcut.recordingInvalid"))
        XCTAssertEqual(button.accessibilityHelp(), L10n.tr("shortcut.recordingHelp"))
        XCTAssertEqual(button.image?.accessibilityDescription, L10n.tr("shortcut.recordingInvalid"))
        XCTAssertEqual(button.shortcutValue, "")
        XCTAssertEqual(changeCount, 0)
        XCTAssertWarningTint(button)

        button.keyDown(with: try keyEvent(
            keyCode: kVK_ANSI_A,
            characters: "a",
            modifierFlags: [.command]
        ))

        XCTAssertEqual(button.shortcutValue, "Cmd+A")
        XCTAssertEqual(button.title, "⌘A")
        XCTAssertEqual(changeCount, 1)
    }

    func testShortcutRecorderCancelsRecordingWhenFocusMovesAwayWithoutSaving() throws {
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)
        try selectShortcutsTab(in: contentView)
        let recorder = try XCTUnwrap(control(withIdentifier: "shortcut.pause30", in: contentView) as? ShortcutRecorderButton)
        let searchField = try XCTUnwrap(view(withIdentifier: "prefs.searchField", in: contentView) as? NSSearchField)

        recorder.performClick(nil)

        XCTAssertEqual(recorder.title, L10n.tr("shortcut.recording"))
        XCTAssertTrue(isFirstResponder(recorder, in: window))

        XCTAssertTrue(window.makeFirstResponder(searchField))

        XCTAssertEqual(recorder.title, L10n.tr("shortcut.add"))
        XCTAssertEqual(recorder.toolTip, shortcutHelp("prefs.pause30ShortcutHelp", "shortcut.recordHelp"))
        XCTAssertTrue(isFirstResponder(searchField, in: window))
        XCTAssertNil(savedSettings.value)
    }

    func testShortcutRecorderEscapeShowsCanceledFeedbackWithoutSaving() throws {
        let button = ShortcutRecorderButton()
        button.shortcutValue = "Cmd+1"
        var changeCount = 0
        button.onChange = { changeCount += 1 }

        button.performClick(nil)
        button.keyDown(with: try keyEvent(keyCode: kVK_Escape))

        XCTAssertEqual(button.shortcutValue, "Cmd+1")
        XCTAssertEqual(changeCount, 0)
        XCTAssertEqual(button.title, L10n.tr("shortcut.recordingCanceled"))
        XCTAssertEqual(button.toolTip, L10n.tr("shortcut.recordingCanceledHelp"))
        XCTAssertEqual(button.accessibilityLabel(), L10n.tr("shortcut.recordingCanceled"))
        XCTAssertEqual(button.accessibilityHelp(), L10n.tr("shortcut.recordingCanceledHelp"))
        XCTAssertEqual(button.image?.accessibilityDescription, L10n.tr("shortcut.recordingCanceled"))

        RunLoop.current.run(until: Date().addingTimeInterval(1.0))

        XCTAssertEqual(button.title, "⌘1")
        XCTAssertEqual(button.toolTip, L10n.tr("shortcut.clearHelp"))
        XCTAssertEqual(button.accessibilityLabel(), "⌘1")
        XCTAssertEqual(button.accessibilityHelp(), L10n.tr("shortcut.clearHelp"))
        XCTAssertEqual(button.image?.accessibilityDescription, "⌘1")
    }

    func testRequiredShortcutRecorderRestoresFallbackInsteadOfClearing() throws {
        let button = ShortcutRecorderButton()
        button.requiredFallbackShortcutValue = ShortcutSettings.defaultEmergencyEyeGateOverride

        XCTAssertEqual(button.title, "⌘⌥E")
        XCTAssertEqual(button.toolTip, L10n.tr("shortcut.requiredHelp"))

        button.shortcutValue = "Cmd+1"
        XCTAssertEqual(button.title, "⌘1")
        XCTAssertEqual(button.toolTip, L10n.tr("shortcut.requiredHelp"))

        button.shortcutValue = ""
        XCTAssertEqual(button.shortcutValue, ShortcutSettings.defaultEmergencyEyeGateOverride)
        XCTAssertEqual(button.title, "⌘⌥E")
        XCTAssertEqual(button.toolTip, L10n.tr("shortcut.requiredHelp"))

        button.shortcutValue = "Cmd+1"
        button.performClick(nil)
        XCTAssertEqual(button.toolTip, L10n.tr("shortcut.requiredRecordingHelp"))
        button.keyDown(with: try keyEvent(keyCode: kVK_Delete))

        XCTAssertEqual(button.shortcutValue, ShortcutSettings.defaultEmergencyEyeGateOverride)
        XCTAssertEqual(button.title, "⌘⌥E")
        XCTAssertEqual(button.toolTip, L10n.tr("shortcut.requiredHelp"))
    }

    func testUnsetShortcutsExposeSetShortcutActionWithoutLongRecordInstruction() throws {
        let settings = RestSettings.defaults
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)
        let visibleTexts = visibleTexts(in: contentView)

        XCTAssertTrue(visibleTexts.contains(L10n.tr("shortcut.add")))
        XCTAssertFalse(visibleTexts.contains("Not set"))
        XCTAssertFalse(visibleTexts.contains("未设置"))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("shortcut.record")))
        XCTAssertTrue(visibleTexts.contains("⌘⌥E"))
    }

    func testShortcutTabGroupsActionsIntoScannableSections() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)

        try assertShortcutGroup("prefs.shortcutGroupPause", in: contentView)
        try assertShortcutGroup("prefs.shortcutGroupStart", in: contentView)
        try assertShortcutGroup("prefs.shortcutGroupDuringRest", in: contentView)
        try assertShortcutGroup("prefs.shortcutGroupMaintenance", in: contentView)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.shortcutGroupPause")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.shortcutGroupStart")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.shortcutGroupDuringRest")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.shortcutGroupMaintenance")))
    }

    func testDuringRestShortcutGroupHidesWhenNoDuringRestShortcutApplies() throws {
        var settings = RestSettings.defaults
        settings.bodyBreak.isEnabled = false
        settings.eyeGate.manualFinishEnabled = false
        settings.eyeGate.emergencyOverride.isEnabled = false
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)

        let group = try XCTUnwrap(view(withIdentifier: "prefs.shortcutGroupDuringRest", in: contentView) as? NSStackView)
        XCTAssertTrue(group.isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.shortcutEndBodyRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.shortcutEmergencyEyeRow", in: contentView).isHidden)
        XCTAssertFalse(visibleTexts(in: contentView).contains(L10n.tr("prefs.shortcutGroupDuringRest")))
    }

    func testPauseShortcutUsesActionCopyInsteadOfImplementationTerm() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)
        let visibleTexts = visibleTexts(in: contentView)

        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.pauseToggle")))
        XCTAssertEqual(L10n.tr("prefs.pauseToggle"), "Pause or resume")
        XCTAssertFalse(visibleTexts.contains("Pause toggle"))
    }

    func testNextScheduledShortcutUsesStartActionCopy() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)
        let visibleTexts = visibleTexts(in: contentView)
        let recorder = try XCTUnwrap(control(withIdentifier: "shortcut.nextScheduled", in: contentView) as? ShortcutRecorderButton)

        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.nextScheduledRest")))
        XCTAssertEqual(L10n.tr("prefs.nextScheduledRest"), "Start next scheduled rest")
        XCTAssertFalse(visibleTexts.contains("Next scheduled rest now"))
        XCTAssertEqual(recorder.toolTip, shortcutHelp("prefs.nextScheduledRestHelp", "shortcut.recordHelp"))
    }

    func testShortcutControlsExposeActionHelpAlongsideRecorderInstructions() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)

        let pause30 = try XCTUnwrap(control(withIdentifier: "shortcut.pause30", in: contentView) as? ShortcutRecorderButton)
        let emergency = try XCTUnwrap(control(withIdentifier: "shortcut.emergencyEye", in: contentView) as? ShortcutRecorderButton)
        let endActive = try XCTUnwrap(control(withIdentifier: "shortcut.endBody", in: contentView) as? ShortcutRecorderButton)

        XCTAssertEqual(pause30.toolTip, shortcutHelp("prefs.pause30ShortcutHelp", "shortcut.recordHelp"))
        XCTAssertEqual(pause30.accessibilityHelp(), shortcutHelp("prefs.pause30ShortcutHelp", "shortcut.recordHelp"))
        XCTAssertEqual(emergency.toolTip, shortcutHelp("prefs.emergencyEyeGateShortcutHelp", "shortcut.requiredHelp"))
        XCTAssertEqual(emergency.accessibilityHelp(), shortcutHelp("prefs.emergencyEyeGateShortcutHelp", "shortcut.requiredHelp"))
        XCTAssertEqual(endActive.toolTip, shortcutHelp("prefs.activeRestShortcut.bodyHelp", "shortcut.clearHelp"))
        XCTAssertFalse((emergency.toolTip ?? "").localizedCaseInsensitiveContains("shortcut again"))

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.pause30ShortcutHelp")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.emergencyEyeGateShortcutHelp")))
    }

    func testActiveRestShortcutUsesBodyBreakActionCopyByDefault() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)

        let label = try XCTUnwrap(view(withIdentifier: "prefs.shortcutEndBodyLabel", in: contentView) as? NSTextField)
        XCTAssertEqual(label.stringValue, L10n.tr("prefs.activeRestShortcut.body"))
        XCTAssertEqual(label.toolTip, L10n.tr("prefs.activeRestShortcut.bodyHelp"))
        XCTAssertEqual(label.accessibilityLabel(), L10n.tr("prefs.activeRestShortcut.body"))
        XCTAssertEqual(label.accessibilityHelp(), L10n.tr("prefs.activeRestShortcut.bodyHelp"))
        XCTAssertFalse(visibleTexts(in: contentView).contains("End active rest"))
    }

    func testActiveRestShortcutNamesCombinedEyeAndBodyBehaviorWhenBothApply() throws {
        var settings = RestSettings.defaults
        settings.eyeGate.manualFinishEnabled = true
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)

        let label = try XCTUnwrap(view(withIdentifier: "prefs.shortcutEndBodyLabel", in: contentView) as? NSTextField)
        XCTAssertEqual(label.stringValue, L10n.tr("prefs.activeRestShortcut.eyeAndBody"))
        XCTAssertEqual(label.toolTip, L10n.tr("prefs.activeRestShortcut.eyeAndBodyHelp"))
        XCTAssertEqual(label.accessibilityLabel(), L10n.tr("prefs.activeRestShortcut.eyeAndBody"))
        XCTAssertEqual(label.accessibilityHelp(), L10n.tr("prefs.activeRestShortcut.eyeAndBodyHelp"))
        XCTAssertTrue(visibleTexts(in: contentView).contains(L10n.tr("prefs.activeRestShortcut.eyeAndBody")))
    }

    func testActiveRestShortcutConflictUsesSpecificActionCopy() throws {
        var settings = RestSettings.defaults
        settings.shortcuts.pauseToggle = "Cmd+1"
        settings.shortcuts.endBodyBreak = "Command+1"
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)

        let warning = try XCTUnwrap(
            visibleTexts(in: contentView).first {
                $0.contains(L10n.tr("prefs.pauseToggle")) &&
                    $0.contains(L10n.tr("prefs.activeRestShortcut.body"))
            }
        )
        XCTAssertFalse(warning.localizedCaseInsensitiveContains("end active rest"))
        XCTAssertTrue(warning.contains("⌘1"))
    }

    func testDuplicateShortcutsShowVisibleConflictWarning() throws {
        var settings = RestSettings.defaults
        settings.shortcuts.takeEyeGateNow = "Cmd+1"
        settings.shortcuts.takeBodyBreakNow = "Command+1"
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)

        try selectShortcutsTab(in: contentView)
        let visibleTexts = visibleTexts(in: contentView)

        let warning = try XCTUnwrap(visibleTexts.first { $0.contains(L10n.tr("prefs.eyeGateNow")) && $0.contains(L10n.tr("prefs.bodyBreakNow")) })
        XCTAssertTrue(warning.contains("⌘1"))

        let eyeNow = try XCTUnwrap(control(withIdentifier: "shortcut.eyeNow", in: contentView) as? ShortcutRecorderButton)
        let bodyNow = try XCTUnwrap(control(withIdentifier: "shortcut.bodyNow", in: contentView) as? ShortcutRecorderButton)
        XCTAssertEqual(eyeNow.validationWarning, warning)
        XCTAssertEqual(bodyNow.validationWarning, warning)
        XCTAssertEqual(eyeNow.toolTip, warning)
        XCTAssertEqual(bodyNow.toolTip, warning)
        XCTAssertEqual(eyeNow.accessibilityHelp(), warning)
        XCTAssertEqual(bodyNow.accessibilityHelp(), warning)
        XCTAssertEqual(eyeNow.image?.accessibilityDescription, eyeNow.title)
        XCTAssertNotEqual(eyeNow.image?.accessibilityDescription, "exclamationmark.triangle.fill")
        let warningRow = try XCTUnwrap(view(withIdentifier: "prefs.shortcutConflictRow", in: contentView) as? NSStackView)
        XCTAssertFalse(warningRow.isHidden)
        XCTAssertTrue(warningRow.wantsLayer)
        XCTAssertEqual(warningRow.edgeInsets.top, 8)
        XCTAssertEqual(warningRow.edgeInsets.left, 12)
        XCTAssertLessThanOrEqual(warningRow.layer?.cornerRadius ?? 99, 8)
        XCTAssertEqual(warningRow.layer?.borderWidth, 1)
        XCTAssertNotNil(warningRow.layer?.backgroundColor)
        XCTAssertNotNil(warningRow.layer?.borderColor)
        XCTAssertTrue(
            warningRow.constraints.contains { constraint in
                constraint.firstAttribute == .width &&
                    constraint.relation == .lessThanOrEqual &&
                    constraint.constant >= 650
            }
        )
        XCTAssertFalse(
            warningRow.constraints.contains { constraint in
                constraint.firstAttribute == .width &&
                    constraint.relation == .equal &&
                    abs(constraint.constant - 650) < 0.1
            }
        )
        XCTAssertEqual(warningRow.toolTip, warning)
        XCTAssertEqual(warningRow.accessibilityLabel(), warning)
        XCTAssertEqual(warningRow.accessibilityHelp(), warning)
        let warningIcon = try XCTUnwrap(view(withIdentifier: "prefs.shortcutConflictIcon", in: contentView) as? NSImageView)
        let warningLabel = try XCTUnwrap(view(withIdentifier: "prefs.shortcutConflictLabel", in: contentView) as? NSTextField)
        XCTAssertEqual(warningLabel.stringValue, warning)
        XCTAssertEqual(warningLabel.toolTip, warning)
        XCTAssertEqual(warningLabel.accessibilityLabel(), warning)
        XCTAssertEqual(warningLabel.accessibilityHelp(), warning)
        XCTAssertEqual(warningLabel.lineBreakMode, .byWordWrapping)
        XCTAssertTrue(warningLabel.cell?.wraps ?? false)
        XCTAssertFalse(warningLabel.cell?.isScrollable ?? true)
        XCTAssertEqual(warningLabel.maximumNumberOfLines, 0)
        XCTAssertGreaterThanOrEqual(warningLabel.preferredMaxLayoutWidth, 500)
        XCTAssertTrue(
            warningLabel.constraints.contains { constraint in
                constraint.firstAttribute == .width &&
                    constraint.relation == .lessThanOrEqual &&
                    constraint.constant >= 510
            }
        )
        XCTAssertFalse(
            warningLabel.constraints.contains { constraint in
                constraint.firstAttribute == .width &&
                    constraint.relation == .equal &&
                    abs(constraint.constant - 510) < 0.1
            }
        )
        XCTAssertEqual(warningIcon.image?.accessibilityDescription, warning)
        XCTAssertEqual(warningIcon.accessibilityHelp(), warning)
        let reviewButton = try XCTUnwrap(control(withIdentifier: "prefs.shortcutConflictReviewButton", in: contentView) as? NSButton)
        XCTAssertFalse(reviewButton.isHidden)
        XCTAssertTrue(reviewButton.isEnabled)
        XCTAssertEqual(reviewButton.title, L10n.tr("prefs.shortcutConflictReview"))
        XCTAssertEqual(reviewButton.title, "Review Conflict")
        XCTAssertNotEqual(reviewButton.title, "Show")
        XCTAssertEqual(reviewButton.toolTip, L10n.tr("prefs.shortcutConflictReviewHelp"))
        XCTAssertEqual(reviewButton.accessibilityLabel(), L10n.tr("prefs.shortcutConflictReview"))
        XCTAssertEqual(reviewButton.accessibilityHelp(), L10n.tr("prefs.shortcutConflictReviewHelp"))
        XCTAssertEqual(reviewButton.image?.accessibilityDescription, L10n.tr("prefs.shortcutConflictReview"))
        XCTAssertTrue(sendAction(from: reviewButton))
        XCTAssertTrue(isFirstResponder(eyeNow, in: window))
        XCTAssertWarningTint(eyeNow)
        XCTAssertWarningTint(bodyNow)
    }

    func testShortcutConflictWarningWrapsManyActionNamesWithoutTruncation() throws {
        var settings = RestSettings.defaults
        settings.shortcuts.pauseToggle = "Cmd+1"
        settings.shortcuts.pauseFor30Minutes = "Command+1"
        settings.shortcuts.pauseFor1Hour = "Cmd+1"
        settings.shortcuts.pauseFor2Hours = "Cmd+1"
        settings.shortcuts.takeEyeGateNow = "Cmd+1"
        settings.shortcuts.takeBodyBreakNow = "Cmd+1"
        settings.shortcuts.reset = "Cmd+1"
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)

        let warningLabel = try XCTUnwrap(view(withIdentifier: "prefs.shortcutConflictLabel", in: contentView) as? NSTextField)
        let warning = warningLabel.stringValue

        XCTAssertTrue(warning.contains(L10n.tr("prefs.pauseToggle")))
        XCTAssertTrue(warning.contains(L10n.tr("prefs.pause30Shortcut")))
        XCTAssertTrue(warning.contains(L10n.tr("prefs.pause1hShortcut")))
        XCTAssertTrue(warning.contains(L10n.tr("prefs.pause2hShortcut")))
        XCTAssertTrue(warning.contains(L10n.tr("prefs.eyeGateNow")))
        XCTAssertTrue(warning.contains(L10n.tr("prefs.bodyBreakNow")))
        XCTAssertTrue(warning.contains(L10n.tr("prefs.reset")))
        XCTAssertEqual(warningLabel.maximumNumberOfLines, 0)
        XCTAssertEqual(warningLabel.toolTip, warning)
        XCTAssertEqual(warningLabel.accessibilityHelp(), warning)
    }

    func testDistinctShortcutsHideConflictWarning() throws {
        var settings = RestSettings.defaults
        settings.shortcuts.takeEyeGateNow = "Cmd+1"
        settings.shortcuts.takeBodyBreakNow = "Cmd+2"
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)
        let visibleTexts = visibleTexts(in: contentView)

        XCTAssertFalse(visibleTexts.contains { $0.contains(L10n.tr("prefs.shortcutConflict").prefix(12)) })
    }

    func testShortcutWarningClearsWhenConflictIsResolved() throws {
        var settings = RestSettings.defaults
        settings.shortcuts.takeEyeGateNow = "Cmd+1"
        settings.shortcuts.takeBodyBreakNow = "Command+1"
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)
        let eyeNow = try XCTUnwrap(control(withIdentifier: "shortcut.eyeNow", in: contentView) as? ShortcutRecorderButton)
        let bodyNow = try XCTUnwrap(control(withIdentifier: "shortcut.bodyNow", in: contentView) as? ShortcutRecorderButton)
        XCTAssertNotNil(eyeNow.validationWarning)
        XCTAssertNotNil(bodyNow.validationWarning)

        bodyNow.shortcutValue = "Cmd+2"
        bodyNow.onChange?()

        XCTAssertNil(eyeNow.validationWarning)
        XCTAssertNil(bodyNow.validationWarning)
        XCTAssertEqual(eyeNow.toolTip, shortcutHelp("prefs.eyeGateNowHelp", "shortcut.clearHelp"))
        XCTAssertEqual(bodyNow.toolTip, shortcutHelp("prefs.bodyBreakNowHelp", "shortcut.clearHelp"))
        let warningRow = try XCTUnwrap(view(withIdentifier: "prefs.shortcutConflictRow", in: contentView) as? NSStackView)
        XCTAssertTrue(warningRow.isHidden)
        XCTAssertNil(warningRow.toolTip)
        XCTAssertNil(warningRow.accessibilityLabel())
        XCTAssertNil(warningRow.accessibilityHelp())
        let warningLabel = try XCTUnwrap(view(withIdentifier: "prefs.shortcutConflictLabel", in: contentView) as? NSTextField)
        XCTAssertEqual(warningLabel.stringValue, "")
        XCTAssertNil(warningLabel.accessibilityLabel())
        XCTAssertNil(warningLabel.accessibilityHelp())
        let reviewButton = try XCTUnwrap(control(withIdentifier: "prefs.shortcutConflictReviewButton", in: contentView) as? NSButton)
        XCTAssertFalse(reviewButton.isEnabled)
    }

    func testUnsupportedShortcutMarksOnlyInvalidRecorder() throws {
        var settings = RestSettings.defaults
        settings.shortcuts.takeEyeGateNow = "Meta+X"
        settings.shortcuts.takeBodyBreakNow = "Command+2"
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)

        try selectShortcutsTab(in: contentView)
        let warning = try XCTUnwrap(visibleTexts(in: contentView).first { $0.contains(L10n.tr("prefs.eyeGateNow")) && $0.contains("Meta+X") })
        let eyeNow = try XCTUnwrap(control(withIdentifier: "shortcut.eyeNow", in: contentView) as? ShortcutRecorderButton)
        let bodyNow = try XCTUnwrap(control(withIdentifier: "shortcut.bodyNow", in: contentView) as? ShortcutRecorderButton)

        XCTAssertEqual(eyeNow.validationWarning, warning)
        XCTAssertEqual(eyeNow.title, "Meta+X")
        XCTAssertFalse(warning.contains("METAX"))
        XCTAssertNil(bodyNow.validationWarning)
        XCTAssertEqual(eyeNow.toolTip, warning)
        let reviewButton = try XCTUnwrap(control(withIdentifier: "prefs.shortcutConflictReviewButton", in: contentView) as? NSButton)
        XCTAssertEqual(reviewButton.title, L10n.tr("prefs.shortcutConflictReview"))
        XCTAssertTrue(reviewButton.isEnabled)
        XCTAssertTrue(sendAction(from: reviewButton))
        XCTAssertTrue(isFirstResponder(eyeNow, in: window))
        XCTAssertWarningTint(eyeNow)
    }

    func testHiddenEmergencyShortcutIsIgnoredForConflictWarning() throws {
        var settings = RestSettings.defaults
        settings.admin.hideStrictPreferences = true
        settings.shortcuts.takeEyeGateNow = "Cmd+1"
        settings.shortcuts.emergencyEyeGateOverride = "Cmd+1"
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)
        let visibleTexts = visibleTexts(in: contentView)

        XCTAssertFalse(visibleTexts.contains { $0.contains(L10n.tr("prefs.shortcutConflict").prefix(12)) })
    }

    func testDisabledEyeGateHidesEyeShortcutRowsAndIgnoresHiddenConflicts() throws {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = false
        settings.bodyBreak.isEnabled = true
        settings.shortcuts.takeEyeGateNow = "Cmd+1"
        settings.shortcuts.takeBodyBreakNow = "Command+1"
        settings.shortcuts.emergencyEyeGateOverride = "Cmd+1"
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)

        XCTAssertTrue(try view(withIdentifier: "prefs.shortcutEyeNowRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.shortcutEmergencyEyeRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.shortcutBodyNowRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.shortcutEndBodyRow", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertFalse(visibleTexts.contains { $0.contains(L10n.tr("prefs.shortcutConflict").prefix(12)) })
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.eyeGateNow")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.emergencyEyeGate")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.skipToBodyBreak")))
    }

    func testDisabledBodyBreakHidesBodyShortcutRowsAndIgnoresHiddenConflicts() throws {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = true
        settings.bodyBreak.isEnabled = false
        settings.shortcuts.takeEyeGateNow = "Cmd+1"
        settings.shortcuts.takeBodyBreakNow = "Command+1"
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)

        XCTAssertFalse(try view(withIdentifier: "prefs.shortcutEyeNowRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.shortcutEmergencyEyeRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.shortcutBodyNowRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.shortcutEndBodyRow", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertFalse(visibleTexts.contains { $0.contains(L10n.tr("prefs.shortcutConflict").prefix(12)) })
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.bodyBreakNow")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.skipToBodyBreak")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.activeRestShortcut.body")))
    }

    func testBodyShortcutRowsFollowBodyBreakToggleAndAutosave() throws {
        var settings = RestSettings.defaults
        settings.bodyBreak.isEnabled = false
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)
        XCTAssertTrue(try view(withIdentifier: "prefs.shortcutBodyNowRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.shortcutEndBodyRow", in: contentView).isHidden)

        try selectScheduleTab(in: contentView)
        let bodyEnabled = try XCTUnwrap(view(withIdentifier: "prefs.bodyEnabled", in: contentView) as? NSButton)
        bodyEnabled.state = .on

        XCTAssertTrue(sendAction(from: bodyEnabled))
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.bodyBreak.isEnabled, true)

        try selectShortcutsTab(in: contentView)
        XCTAssertFalse(try view(withIdentifier: "prefs.shortcutBodyNowRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.shortcutEndBodyRow", in: contentView).isHidden)
    }

    func testEndActiveRestShortcutFollowsEyeManualFinishWhenBodyBreakIsDisabled() throws {
        var settings = RestSettings.defaults
        settings.bodyBreak.isEnabled = false
        settings.eyeGate.manualFinishEnabled = false
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)
        XCTAssertTrue(try view(withIdentifier: "prefs.shortcutBodyNowRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.shortcutEndBodyRow", in: contentView).isHidden)

        try selectScheduleTab(in: contentView)
        let eyeManualFinish = try XCTUnwrap(view(withIdentifier: "prefs.eyeManualFinish", in: contentView) as? NSButton)
        eyeManualFinish.state = .on

        XCTAssertTrue(sendAction(from: eyeManualFinish))
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.eyeGate.manualFinishEnabled, true)

        try selectShortcutsTab(in: contentView)
        XCTAssertTrue(try view(withIdentifier: "prefs.shortcutBodyNowRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.shortcutEndBodyRow", in: contentView).isHidden)
        let label = try XCTUnwrap(view(withIdentifier: "prefs.shortcutEndBodyLabel", in: contentView) as? NSTextField)
        XCTAssertEqual(label.stringValue, L10n.tr("prefs.activeRestShortcut.eye"))
        XCTAssertEqual(label.toolTip, L10n.tr("prefs.activeRestShortcut.eyeHelp"))
        XCTAssertEqual(label.accessibilityLabel(), L10n.tr("prefs.activeRestShortcut.eye"))
        XCTAssertEqual(label.accessibilityHelp(), L10n.tr("prefs.activeRestShortcut.eyeHelp"))
        XCTAssertTrue(visibleTexts(in: contentView).contains(L10n.tr("prefs.activeRestShortcut.eye")))
        XCTAssertFalse(visibleTexts(in: contentView).contains(L10n.tr("prefs.activeRestShortcut.body")))
    }

    func testLegacySkipToBodyShortcutIsShownAsBodyBreakNowWithoutDuplicateRow() throws {
        var settings = RestSettings.defaults
        settings.shortcuts.takeBodyBreakNow = ""
        settings.shortcuts.skipToNextBodyBreak = "Cmd+3"
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)
        let visibleTexts = visibleTexts(in: contentView)

        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.bodyBreakNow")))
        XCTAssertTrue(visibleTexts.contains("⌘3"))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.skipToBodyBreak")))
        XCTAssertNil(findView(withIdentifier: "prefs.shortcutSkipBodyRow", in: contentView))

        let bodyNow = try XCTUnwrap(control(withIdentifier: "shortcut.bodyNow", in: contentView) as? ShortcutRecorderButton)
        bodyNow.shortcutValue = "Cmd+4"
        bodyNow.onChange?()
        waitUntilSavedSettingsArrive(savedSettings)

        XCTAssertEqual(savedSettings.value?.shortcuts.takeBodyBreakNow, "Cmd+4")
        XCTAssertEqual(savedSettings.value?.shortcuts.skipToNextBodyBreak, "")
    }

    func testShortcutRowsExposeVisibleClearButtons() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)
        let clearButton = try XCTUnwrap(control(withIdentifier: "shortcut.pause30.clear", in: contentView) as? NSButton)

        XCTAssertEqual(clearButton.title, "")
        XCTAssertNotNil(clearButton.image)
        XCTAssertEqual(clearButton.imagePosition, .imageOnly)
        XCTAssertFalse(clearButton.isEnabled)
        XCTAssertEqual(clearButton.toolTip, L10n.tr("shortcut.clearButtonDisabledEmptyHelp"))
        XCTAssertEqual(clearButton.accessibilityLabel(), L10n.tr("shortcut.clearButton"))
        XCTAssertEqual(clearButton.accessibilityHelp(), L10n.tr("shortcut.clearButtonDisabledEmptyHelp"))
        XCTAssertEqual(clearButton.image?.accessibilityDescription, L10n.tr("shortcut.clearButton"))

        let restoreButton = try XCTUnwrap(control(withIdentifier: "shortcut.emergencyEye.clear", in: contentView) as? NSButton)
        XCTAssertEqual(restoreButton.title, "")
        XCTAssertNotNil(restoreButton.image)
        XCTAssertEqual(restoreButton.imagePosition, .imageOnly)
        XCTAssertFalse(restoreButton.isEnabled)
        XCTAssertEqual(restoreButton.toolTip, L10n.tr("shortcut.restoreDefaultButtonDisabledDefaultHelp"))
        XCTAssertEqual(restoreButton.accessibilityLabel(), L10n.tr("shortcut.restoreDefaultButton"))
        XCTAssertEqual(restoreButton.accessibilityHelp(), L10n.tr("shortcut.restoreDefaultButtonDisabledDefaultHelp"))
        XCTAssertEqual(
            restoreButton.image?.accessibilityDescription,
            L10n.tr("shortcut.restoreDefaultButton")
        )
    }

    func testShortcutClearButtonClearsShortcutAndAutosaves() throws {
        var settings = RestSettings.defaults
        settings.shortcuts.pauseFor30Minutes = "Cmd+1"
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)
        let recorder = try XCTUnwrap(control(withIdentifier: "shortcut.pause30", in: contentView) as? ShortcutRecorderButton)
        let clearButton = try XCTUnwrap(control(withIdentifier: "shortcut.pause30.clear", in: contentView) as? NSButton)

        XCTAssertTrue(clearButton.isEnabled)
        XCTAssertEqual(clearButton.toolTip, L10n.tr("shortcut.clearButtonHelp"))
        XCTAssertEqual(clearButton.accessibilityLabel(), L10n.tr("shortcut.clearButton"))
        XCTAssertEqual(clearButton.accessibilityHelp(), L10n.tr("shortcut.clearButtonHelp"))
        XCTAssertEqual(clearButton.image?.accessibilityDescription, L10n.tr("shortcut.clearButton"))
        clearButton.performClick(nil)
        waitUntilSavedSettingsArrive(savedSettings)

        XCTAssertEqual(recorder.shortcutValue, "")
        XCTAssertEqual(recorder.title, L10n.tr("shortcut.add"))
        XCTAssertEqual(savedSettings.value?.shortcuts.pauseFor30Minutes, "")
        XCTAssertFalse(clearButton.isEnabled)
        XCTAssertEqual(clearButton.toolTip, L10n.tr("shortcut.clearButtonDisabledEmptyHelp"))
        XCTAssertEqual(clearButton.accessibilityLabel(), L10n.tr("shortcut.clearButton"))
        XCTAssertEqual(clearButton.accessibilityHelp(), L10n.tr("shortcut.clearButtonDisabledEmptyHelp"))
        XCTAssertEqual(clearButton.image?.accessibilityDescription, L10n.tr("shortcut.clearButton"))
    }

    func testRequiredShortcutClearButtonRestoresDefaultAndAutosaves() throws {
        var settings = RestSettings.defaults
        settings.shortcuts.emergencyEyeGateOverride = "Cmd+1"
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)
        let recorder = try XCTUnwrap(control(withIdentifier: "shortcut.emergencyEye", in: contentView) as? ShortcutRecorderButton)
        let restoreButton = try XCTUnwrap(control(withIdentifier: "shortcut.emergencyEye.clear", in: contentView) as? NSButton)

        XCTAssertEqual(restoreButton.toolTip, L10n.tr("shortcut.restoreDefaultButtonHelp"))
        XCTAssertEqual(restoreButton.accessibilityLabel(), L10n.tr("shortcut.restoreDefaultButton"))
        XCTAssertEqual(restoreButton.accessibilityHelp(), L10n.tr("shortcut.restoreDefaultButtonHelp"))
        XCTAssertTrue(restoreButton.isEnabled)
        restoreButton.performClick(nil)
        waitUntilSavedSettingsArrive(savedSettings)

        XCTAssertEqual(recorder.shortcutValue, ShortcutSettings.defaultEmergencyEyeGateOverride)
        XCTAssertEqual(recorder.title, "⌘⌥E")
        XCTAssertEqual(savedSettings.value?.shortcuts.emergencyEyeGateOverride, ShortcutSettings.defaultEmergencyEyeGateOverride)
        XCTAssertFalse(restoreButton.isEnabled)
        XCTAssertEqual(restoreButton.toolTip, L10n.tr("shortcut.restoreDefaultButtonDisabledDefaultHelp"))
        XCTAssertEqual(restoreButton.accessibilityLabel(), L10n.tr("shortcut.restoreDefaultButton"))
        XCTAssertEqual(restoreButton.accessibilityHelp(), L10n.tr("shortcut.restoreDefaultButtonDisabledDefaultHelp"))
        XCTAssertEqual(
            restoreButton.image?.accessibilityDescription,
            L10n.tr("shortcut.restoreDefaultButton")
        )
    }

    func testEmergencyShortcutDeleteRestoresDefaultAndAutosaves() throws {
        var settings = RestSettings.defaults
        settings.shortcuts.emergencyEyeGateOverride = "Cmd+1"
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)
        let emergencyShortcut = try XCTUnwrap(control(withIdentifier: "shortcut.emergencyEye", in: contentView) as? ShortcutRecorderButton)

        XCTAssertEqual(emergencyShortcut.toolTip, shortcutHelp("prefs.emergencyEyeGateShortcutHelp", "shortcut.requiredHelp"))
        emergencyShortcut.performClick(nil)
        XCTAssertEqual(
            emergencyShortcut.toolTip,
            shortcutHelp("prefs.emergencyEyeGateShortcutHelp", "shortcut.requiredRecordingHelp")
        )
        emergencyShortcut.keyDown(with: try keyEvent(keyCode: kVK_Delete))
        waitUntilSavedSettingsArrive(savedSettings)

        XCTAssertEqual(emergencyShortcut.shortcutValue, ShortcutSettings.defaultEmergencyEyeGateOverride)
        XCTAssertEqual(emergencyShortcut.title, "⌘⌥E")
        XCTAssertEqual(savedSettings.value?.shortcuts.emergencyEyeGateOverride, ShortcutSettings.defaultEmergencyEyeGateOverride)
    }

    private func selectShortcutsTab(in view: NSView) throws {
        let tabView = try XCTUnwrap(firstTabView(in: view))
        tabView.selectTabViewItem(withIdentifier: L10n.tr("prefs.tabShortcuts"))
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

    private func control(withIdentifier identifier: String, in rootView: NSView) throws -> NSControl {
        try XCTUnwrap(findView(withIdentifier: identifier, in: rootView) as? NSControl)
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

    private func isFirstResponder(_ control: NSControl, in window: NSWindow) -> Bool {
        window.firstResponder === control || control.currentEditor() === window.firstResponder
    }

    private func XCTAssertWarningTint(
        _ button: ShortcutRecorderButton,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let color = button.contentTintColor?.usingColorSpace(.sRGB)
        XCTAssertNotNil(color, file: file, line: line)
        XCTAssertGreaterThan(color?.redComponent ?? 0, 0.85, file: file, line: line)
        XCTAssertGreaterThan(color?.greenComponent ?? 0, 0.25, file: file, line: line)
        XCTAssertLessThan(color?.blueComponent ?? 1, 0.25, file: file, line: line)
    }

    private func assertShortcutGroup(
        _ identifier: String,
        in contentView: NSView,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let group = try XCTUnwrap(
            view(withIdentifier: identifier, in: contentView) as? NSStackView,
            file: file,
            line: line
        )
        let icon = try XCTUnwrap(
            view(withIdentifier: "\(identifier).icon", in: contentView) as? NSImageView,
            file: file,
            line: line
        )
        let label = try XCTUnwrap(
            view(withIdentifier: "\(identifier).label", in: contentView) as? NSTextField,
            file: file,
            line: line
        )
        XCTAssertFalse(group.isHidden, file: file, line: line)
        XCTAssertEqual(group.orientation, .horizontal, file: file, line: line)
        XCTAssertEqual(group.edgeInsets.top, 10, file: file, line: line)
        XCTAssertEqual(group.accessibilityLabel(), L10n.tr(identifier), file: file, line: line)
        XCTAssertNotNil(icon.image, file: file, line: line)
        XCTAssertEqual(icon.image?.accessibilityDescription, L10n.tr(identifier), file: file, line: line)
        XCTAssertEqual(label.stringValue, L10n.tr(identifier), file: file, line: line)
        XCTAssertEqual(label.textColor, .secondaryLabelColor, file: file, line: line)
    }

    private func keyEvent(
        keyCode: Int,
        characters: String = "",
        modifierFlags: NSEvent.ModifierFlags = []
    ) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifierFlags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: UInt16(keyCode)
        ))
    }

    private func waitUntilSavedSettingsArrive(_ settings: SavedSettingsBox) {
        let deadline = Date().addingTimeInterval(2)
        while settings.value == nil && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private func shortcutHelp(_ actionHelpKey: String, _ interactionHelpKey: String) -> String {
        "\(L10n.tr(actionHelpKey))\n\(L10n.tr(interactionHelpKey))"
    }

    private func visibleTexts(in view: NSView, ancestorHidden: Bool = false) -> [String] {
        let hidden = ancestorHidden || view.isHidden
        var texts: [String] = []
        if !hidden {
            if let button = view as? NSButton, !button.title.isEmpty {
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

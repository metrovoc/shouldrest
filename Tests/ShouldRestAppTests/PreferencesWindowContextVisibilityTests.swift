import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowContextVisibilityTests: XCTestCase {
    func testDisabledContextOptionsHideDependentPreferences() throws {
        var settings = RestSettings.defaults
        settings.naturalBreaks.isEnabled = false
        settings.workingHours.isEnabled = false
        settings.appExclusions = [
            AppExclusionRule(
                id: "legacy-disabled",
                name: "Video calls",
                matchTerms: ["zoom"],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: false
            )
        ]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectContextTab(in: contentView)

        XCTAssertFalse(try view(withIdentifier: "prefs.naturalBreaks", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.naturalIdleMinutesRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.workingHours", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.workingStartRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.workingEndRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.focusMonitor", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.focusDefersBody", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.appExclusionEnabled", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.appExclusionNameRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.appExclusionTermsRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.appExclusionModeRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.appExclusionAppliesEye", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.appExclusionAppliesBody", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.appExclusionPreviewLabel", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "appExclusions", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.appExclusionsJSONRow", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.naturalIdleMinutes")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.workingStart")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.workingEnd")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.matchTerms")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.advancedRulesJSON")))
    }

    func testDisabledBodyBreakHidesFocusModeContextControls() throws {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = true
        settings.bodyBreak.isEnabled = false
        settings.focusMode.monitorFocusMode = true
        settings.focusMode.deferBodyBreak = true
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectContextTab(in: contentView)

        XCTAssertTrue(try view(withIdentifier: "prefs.focusMonitor", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.focusDefersBody", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.monitorFocus")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.focusDefersBody")))
    }

    func testEnablingFocusMonitorShowsBodyDeferralAndAutosaves() throws {
        var settings = RestSettings.defaults
        settings.bodyBreak.isEnabled = true
        settings.focusMode.monitorFocusMode = false
        settings.focusMode.deferBodyBreak = true
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectContextTab(in: contentView)
        let focusMonitor = try XCTUnwrap(view(withIdentifier: "prefs.focusMonitor", in: contentView) as? NSButton)
        XCTAssertFalse(focusMonitor.isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.focusDefersBody", in: contentView).isHidden)

        focusMonitor.state = .on
        XCTAssertTrue(sendAction(from: focusMonitor))

        XCTAssertFalse(try view(withIdentifier: "prefs.focusDefersBody", in: contentView).isHidden)
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.focusMode.monitorFocusMode, true)
    }

    func testEnablingWorkingHoursShowsTimeRowsAndAutosaves() throws {
        var settings = RestSettings.defaults
        settings.workingHours.isEnabled = false
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectContextTab(in: contentView)
        let checkbox = try XCTUnwrap(view(withIdentifier: "prefs.workingHours", in: contentView) as? NSButton)
        checkbox.state = .on

        XCTAssertTrue(sendAction(from: checkbox))

        XCTAssertFalse(try view(withIdentifier: "prefs.workingStartRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.workingEndRow", in: contentView).isHidden)

        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.workingHours.isEnabled, true)
    }

    func testEnabledAppExclusionShowsDetailRowsAndNativeRuleList() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        var settings = RestSettings.defaults
        settings.appExclusions = [
            AppExclusionRule(
                id: "primary",
                name: "Deep work",
                matchTerms: ["xcode"],
                mode: .resumeOnlyWhenMatched,
                appliesTo: [.eyeGate, .bodyBreak],
                isEnabled: true
            ),
            AppExclusionRule(
                id: "secondary",
                name: "Calls",
                matchTerms: ["zoom"],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: true
            )
        ]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectContextTab(in: contentView)

        XCTAssertFalse(try view(withIdentifier: "prefs.appExclusionNameRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.appExclusionTermsRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.appExclusionModeRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.appExclusionAppliesEye", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.appExclusionAppliesBody", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.appExclusionPreviewLabel", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "appExclusions", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.appExclusionAddRuleRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.appExclusionRulesListRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.appExclusionsJSONRow", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.name")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.matchTerms")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.mode")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.appExclusionRules")))
        XCTAssertTrue(visibleTexts.contains("Deep work"))
        XCTAssertTrue(visibleTexts.contains("Calls"))
        XCTAssertFalse(visibleTexts.contains("Name"))
        XCTAssertFalse(visibleTexts.contains("Match terms"))
        XCTAssertFalse(visibleTexts.contains("Mode"))
        XCTAssertFalse(visibleTexts.contains("Current rules"))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.advancedRulesJSON")))
    }

    func testAppExclusionPreviewShowsEmptyDraftGuidance() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        var settings = RestSettings.defaults
        settings.appExclusions = [
            AppExclusionRule(
                id: "empty-draft",
                name: "Calls",
                matchTerms: [],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: true
            )
        ]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectContextTab(in: contentView)
        let preview = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionPreviewLabel", in: contentView) as? NSTextField)

        XCTAssertFalse(preview.isHidden)
        XCTAssertEqual(preview.stringValue, "Add an app name or bundle ID to preview this rule.")
        XCTAssertEqual(preview.toolTip, preview.stringValue)
        XCTAssertEqual(preview.accessibilityHelp(), preview.stringValue)
    }

    func testAppExclusionPreviewExplainsDraftAndUpdatesWhileEditing() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        var settings = RestSettings.defaults
        settings.appExclusions = [
            AppExclusionRule(
                id: "enabled",
                name: "Calls",
                matchTerms: [],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: true
            )
        ]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectContextTab(in: contentView)
        let terms = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionTermsField", in: contentView) as? NSTokenField)
        let mode = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionMode", in: contentView) as? NSPopUpButton)
        let appliesEye = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionAppliesEye", in: contentView) as? NSButton)
        let preview = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionPreviewLabel", in: contentView) as? NSTextField)

        terms.objectValue = ["Zoom", "us.zoom.xos"]
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: terms))

        XCTAssertEqual(preview.stringValue, "Matches Zoom, us.zoom.xos. Pauses Body Break while matched.")

        selectPopup(mode, representedObject: AppExclusionRule.Mode.resumeOnlyWhenMatched.rawValue)
        XCTAssertTrue(sendAction(from: mode))
        appliesEye.state = .on
        XCTAssertTrue(sendAction(from: appliesEye))

        XCTAssertEqual(
            preview.stringValue,
            "Matches Zoom, us.zoom.xos. Runs Eye Gate and Body Break only while matched."
        )
    }

    func testEnabledAppExclusionOffersRunningAppPicker() throws {
        var settings = RestSettings.defaults
        settings.appExclusions = [
            AppExclusionRule(
                id: "primary",
                name: "Calls",
                matchTerms: ["zoom"],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: true
            )
        ]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectContextTab(in: contentView)

        let button = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionAddRunningApp", in: contentView) as? NSButton)
        XCTAssertFalse(button.isHidden)
        XCTAssertTrue(button.isEnabled)
        XCTAssertEqual(button.title, L10n.tr("prefs.addRunningApp"))
        XCTAssertEqual(button.toolTip, L10n.tr("prefs.addRunningAppHelp"))
        XCTAssertNotNil(button.image)
    }

    func testLegacyTargetlessAppExclusionGetsVisibleDefaultTarget() throws {
        var settings = RestSettings.defaults
        settings.appExclusions = [
            AppExclusionRule(
                id: "legacy",
                name: "Calls",
                matchTerms: ["zoom"],
                mode: .pauseWhenMatched,
                appliesTo: [],
                isEnabled: true
            )
        ]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectContextTab(in: contentView)
        let body = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionRuleBody.0", in: contentView) as? NSTextField)
        let editor = try XCTUnwrap(view(withIdentifier: "appExclusionsJSONEditor", in: contentView) as? NSTextView)
        let editButton = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionRuleEdit.0", in: contentView) as? NSButton)
        let appliesEye = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionAppliesEye", in: contentView) as? NSButton)
        let appliesBody = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionAppliesBody", in: contentView) as? NSButton)

        XCTAssertTrue(body.stringValue.contains(L10n.tr("prefs.appExclusionAppliesBody")))
        XCTAssertFalse(body.stringValue.contains(L10n.tr("prefs.appExclusionAppliesNone")))
        XCTAssertTrue(editor.string.contains(RestKind.bodyBreak.rawValue))
        XCTAssertFalse(editor.string.contains(#""appliesTo" : []"#))

        XCTAssertTrue(sendAction(from: editButton))

        XCTAssertEqual(appliesEye.state, .off)
        XCTAssertEqual(appliesBody.state, .on)
        XCTAssertTrue(appliesEye.isEnabled)
        XCTAssertFalse(appliesBody.isEnabled)
    }

    func testLastAppExclusionTargetCannotBeClearedFromUI() throws {
        var settings = RestSettings.defaults
        settings.appExclusions = [
            AppExclusionRule(
                id: "primary",
                name: "Calls",
                matchTerms: ["zoom"],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: true
            )
        ]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectContextTab(in: contentView)
        let appliesEye = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionAppliesEye", in: contentView) as? NSButton)
        let appliesBody = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionAppliesBody", in: contentView) as? NSButton)

        XCTAssertEqual(appliesEye.state, .off)
        XCTAssertEqual(appliesBody.state, .on)
        XCTAssertTrue(appliesEye.isEnabled)
        XCTAssertFalse(appliesBody.isEnabled)
        XCTAssertNil(appliesEye.toolTip)
        XCTAssertEqual(appliesBody.toolTip, L10n.tr("prefs.appExclusionNeedsTarget"))
        XCTAssertEqual(appliesBody.accessibilityHelp(), L10n.tr("prefs.appExclusionNeedsTarget"))

        appliesEye.state = .on
        XCTAssertTrue(sendAction(from: appliesEye))

        XCTAssertTrue(appliesEye.isEnabled)
        XCTAssertTrue(appliesBody.isEnabled)
        XCTAssertNil(appliesEye.toolTip)
        XCTAssertNil(appliesBody.toolTip)

        appliesBody.state = .off
        XCTAssertTrue(sendAction(from: appliesBody))

        XCTAssertEqual(appliesEye.state, .on)
        XCTAssertEqual(appliesBody.state, .off)
        XCTAssertFalse(appliesEye.isEnabled)
        XCTAssertTrue(appliesBody.isEnabled)
        XCTAssertEqual(appliesEye.toolTip, L10n.tr("prefs.appExclusionNeedsTarget"))
        XCTAssertEqual(appliesEye.accessibilityHelp(), L10n.tr("prefs.appExclusionNeedsTarget"))
        XCTAssertNil(appliesBody.toolTip)
    }

    func testRunningAppPickerAddsCandidateTermsAndAutosaves() throws {
        var settings = RestSettings.defaults
        settings.appExclusions = [
            AppExclusionRule(
                id: "primary",
                name: "",
                matchTerms: [],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: true
            )
        ]
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        controller.appExclusionApplicationCandidatesProvider = {
            [AppExclusionApplicationCandidate(name: "Zoom", bundleIdentifier: "us.zoom.xos")]
        }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectContextTab(in: contentView)
        let button = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionAddRunningApp", in: contentView) as? NSButton)

        XCTAssertTrue(sendAction(from: button))

        waitUntilSavedSettingsArrive(savedSettings)
        let rule = try XCTUnwrap(savedSettings.value?.appExclusions.first)
        XCTAssertEqual(rule.name, "Zoom")
        XCTAssertEqual(rule.matchTerms, ["Zoom", "us.zoom.xos"])
    }

    func testRunningAppPickerAppendsRuleWhenRuleListIsActive() throws {
        var settings = RestSettings.defaults
        settings.appExclusions = [
            AppExclusionRule(
                id: "primary",
                name: "Old",
                matchTerms: ["old"],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: true
            ),
            AppExclusionRule(
                id: "secondary",
                name: "Keep",
                matchTerms: ["keep"],
                mode: .resumeOnlyWhenMatched,
                appliesTo: [.eyeGate],
                isEnabled: true
            )
        ]
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        controller.appExclusionApplicationCandidatesProvider = {
            [AppExclusionApplicationCandidate(name: "Keynote", bundleIdentifier: "com.apple.iWork.Keynote")]
        }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectContextTab(in: contentView)
        let button = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionAddRunningApp", in: contentView) as? NSButton)

        XCTAssertTrue(sendAction(from: button))

        waitUntilSavedSettingsArrive(savedSettings)
        let rules = try XCTUnwrap(savedSettings.value?.appExclusions)
        XCTAssertEqual(rules.count, 3)
        XCTAssertEqual(rules[0], settings.appExclusions[0])
        XCTAssertEqual(rules[1], settings.appExclusions[1])
        XCTAssertEqual(rules[2].name, "Keynote")
        XCTAssertEqual(rules[2].matchTerms, ["Keynote", "com.apple.iWork.Keynote"])
        XCTAssertEqual(rules[2].appliesTo, Set([RestKind.bodyBreak]))
    }

    func testAppExclusionRuleListRemovesRuleAndAutosaves() throws {
        var settings = RestSettings.defaults
        settings.appExclusions = [
            AppExclusionRule(
                id: "primary",
                name: "Deep work",
                matchTerms: ["xcode"],
                mode: .resumeOnlyWhenMatched,
                appliesTo: [.eyeGate, .bodyBreak],
                isEnabled: true
            ),
            AppExclusionRule(
                id: "secondary",
                name: "Calls",
                matchTerms: ["zoom"],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: true
            )
        ]
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectContextTab(in: contentView)
        let removeButton = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionRuleRemove.0", in: contentView) as? NSButton)

        XCTAssertEqual(removeButton.toolTip, L10n.tr("prefs.removeAppExclusionRuleHelp"))
        XCTAssertEqual(removeButton.accessibilityLabel(), L10n.tr("prefs.removeAppExclusionRuleHelp"))
        XCTAssertEqual(removeButton.accessibilityHelp(), L10n.tr("prefs.removeAppExclusionRuleHelp"))
        XCTAssertTrue(sendAction(from: removeButton))

        waitUntilSavedSettingsArrive(savedSettings)
        let rules = try XCTUnwrap(savedSettings.value?.appExclusions)
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules.first?.id, "secondary")
        XCTAssertTrue(try view(withIdentifier: "prefs.appExclusionsJSONRow", in: contentView).isHidden)
    }

    func testAppExclusionRuleListEditsExistingRuleAndAutosavesOnUpdateOnly() throws {
        var settings = RestSettings.defaults
        settings.appExclusions = [
            AppExclusionRule(
                id: "primary",
                name: "Deep work",
                matchTerms: ["xcode"],
                mode: .resumeOnlyWhenMatched,
                appliesTo: [.eyeGate, .bodyBreak],
                isEnabled: true
            ),
            AppExclusionRule(
                id: "secondary",
                name: "Calls",
                matchTerms: ["zoom"],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: true
            )
        ]
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectContextTab(in: contentView)
        let name = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionNameField", in: contentView) as? NSTextField)
        let terms = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionTermsField", in: contentView) as? NSTokenField)
        let mode = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionMode", in: contentView) as? NSPopUpButton)
        let appliesEye = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionAppliesEye", in: contentView) as? NSButton)
        let appliesBody = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionAppliesBody", in: contentView) as? NSButton)
        let actionButton = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionAddRuleButton", in: contentView) as? NSButton)
        let cancelButton = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionCancelEditButton", in: contentView) as? NSButton)
        let editCalls = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionRuleEdit.1", in: contentView) as? NSButton)
        let jsonRow = try view(withIdentifier: "prefs.appExclusionsJSONRow", in: contentView)

        XCTAssertTrue(cancelButton.isHidden)
        XCTAssertEqual(actionButton.title, L10n.tr("prefs.addAppExclusionRule"))
        XCTAssertGreaterThanOrEqual(
            actionButton.constraints.first { $0.firstAttribute == .width }?.constant ?? 0,
            156
        )
        XCTAssertEqual(editCalls.toolTip, L10n.tr("prefs.editAppExclusionRuleHelp"))
        XCTAssertEqual(editCalls.accessibilityLabel(), L10n.tr("prefs.editAppExclusionRuleHelp"))
        XCTAssertEqual(editCalls.accessibilityHelp(), L10n.tr("prefs.editAppExclusionRuleHelp"))

        XCTAssertTrue(sendAction(from: editCalls))

        XCTAssertEqual(name.stringValue, "Calls")
        XCTAssertEqual(terms.objectValue as? [String], ["zoom"])
        XCTAssertEqual(mode.selectedItem?.representedObject as? String, AppExclusionRule.Mode.pauseWhenMatched.rawValue)
        XCTAssertEqual(appliesEye.state, .off)
        XCTAssertEqual(appliesBody.state, .on)
        XCTAssertFalse(cancelButton.isHidden)
        XCTAssertEqual(actionButton.title, L10n.tr("prefs.updateAppExclusionRule"))
        XCTAssertEqual(actionButton.toolTip, L10n.tr("prefs.updateAppExclusionRuleHelp"))

        name.stringValue = "Meetings"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: name))
        terms.objectValue = ["teams"]
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: terms))
        selectPopup(mode, representedObject: AppExclusionRule.Mode.resumeOnlyWhenMatched.rawValue)
        appliesEye.state = .on
        XCTAssertTrue(sendAction(from: appliesEye))
        appliesBody.state = .off
        XCTAssertTrue(sendAction(from: appliesBody))

        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        XCTAssertNil(savedSettings.value)

        XCTAssertTrue(sendAction(from: actionButton))

        waitUntilSavedSettingsArrive(savedSettings)
        let rules = try XCTUnwrap(savedSettings.value?.appExclusions)
        XCTAssertEqual(rules.map(\.id), ["primary", "secondary"])
        XCTAssertEqual(rules[1].name, "Meetings")
        XCTAssertEqual(rules[1].matchTerms, ["teams"])
        XCTAssertEqual(rules[1].mode, .resumeOnlyWhenMatched)
        XCTAssertEqual(rules[1].appliesTo, Set([RestKind.eyeGate]))
        XCTAssertEqual(name.stringValue, "")
        XCTAssertEqual(terms.objectValue as? [String] ?? [], [])
        XCTAssertTrue(cancelButton.isHidden)
        XCTAssertEqual(actionButton.title, L10n.tr("prefs.addAppExclusionRule"))
        XCTAssertEqual(
            (try view(withIdentifier: "prefs.appExclusionRuleTitle.1", in: contentView) as? NSTextField)?.stringValue,
            "Meetings"
        )
        XCTAssertTrue(jsonRow.isHidden)
    }

    func testAppExclusionRuleEditCancelClearsDraftWithoutAutosaving() throws {
        var settings = RestSettings.defaults
        settings.appExclusions = [
            AppExclusionRule(
                id: "primary",
                name: "Deep work",
                matchTerms: ["xcode"],
                mode: .resumeOnlyWhenMatched,
                appliesTo: [.eyeGate, .bodyBreak],
                isEnabled: true
            ),
            AppExclusionRule(
                id: "secondary",
                name: "Calls",
                matchTerms: ["zoom"],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: true
            )
        ]
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectContextTab(in: contentView)
        let name = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionNameField", in: contentView) as? NSTextField)
        let terms = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionTermsField", in: contentView) as? NSTokenField)
        let actionButton = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionAddRuleButton", in: contentView) as? NSButton)
        let cancelButton = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionCancelEditButton", in: contentView) as? NSButton)
        let editDeepWork = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionRuleEdit.0", in: contentView) as? NSButton)

        XCTAssertTrue(sendAction(from: editDeepWork))

        name.stringValue = "Changed"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: name))
        terms.objectValue = ["changed"]
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: terms))

        XCTAssertTrue(sendAction(from: cancelButton))

        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        XCTAssertNil(savedSettings.value)
        XCTAssertEqual(name.stringValue, "")
        XCTAssertEqual(terms.objectValue as? [String] ?? [], [])
        XCTAssertTrue(cancelButton.isHidden)
        XCTAssertEqual(actionButton.title, L10n.tr("prefs.addAppExclusionRule"))
        XCTAssertEqual(
            (try view(withIdentifier: "prefs.appExclusionRuleTitle.0", in: contentView) as? NSTextField)?.stringValue,
            "Deep work"
        )
    }

    func testDraftingAppExclusionRuleDoesNotAutosaveOverExistingRulesBeforeAdd() throws {
        var settings = RestSettings.defaults
        settings.appExclusions = [
            AppExclusionRule(
                id: "primary",
                name: "Deep work",
                matchTerms: ["xcode"],
                mode: .resumeOnlyWhenMatched,
                appliesTo: [.eyeGate, .bodyBreak],
                isEnabled: true
            ),
            AppExclusionRule(
                id: "secondary",
                name: "Calls",
                matchTerms: ["zoom"],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: true
            )
        ]
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectContextTab(in: contentView)
        let name = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionNameField", in: contentView) as? NSTextField)
        let terms = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionTermsField", in: contentView) as? NSTokenField)
        let addButton = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionAddRuleButton", in: contentView) as? NSButton)

        name.stringValue = "Presentation"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: name))
        terms.objectValue = ["keynote"]
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: terms))
        controller.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: terms))

        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        XCTAssertNil(savedSettings.value)
        XCTAssertTrue(addButton.isEnabled)

        XCTAssertTrue(sendAction(from: addButton))

        waitUntilSavedSettingsArrive(savedSettings)
        let rules = try XCTUnwrap(savedSettings.value?.appExclusions)
        XCTAssertEqual(rules.count, 3)
        XCTAssertEqual(rules[0], settings.appExclusions[0])
        XCTAssertEqual(rules[1], settings.appExclusions[1])
        XCTAssertEqual(rules[2].name, "Presentation")
        XCTAssertEqual(rules[2].matchTerms, ["keynote"])
    }

    func testAppExclusionModeIgnoresRawTitleWithoutRepresentedValue() throws {
        var settings = RestSettings.defaults
        settings.appExclusions = []
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectContextTab(in: contentView)
        let checkbox = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionEnabled", in: contentView) as? NSButton)
        let name = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionNameField", in: contentView) as? NSTextField)
        let terms = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionTermsField", in: contentView) as? NSTokenField)
        let mode = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionMode", in: contentView) as? NSPopUpButton)
        let addButton = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionAddRuleButton", in: contentView) as? NSButton)

        checkbox.state = .on
        XCTAssertTrue(sendAction(from: checkbox))
        savedSettings.value = nil
        name.stringValue = "Calls"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: name))
        terms.objectValue = ["zoom"]
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: terms))

        mode.addItem(withTitle: AppExclusionRule.Mode.resumeOnlyWhenMatched.rawValue)
        mode.selectItem(at: mode.numberOfItems - 1)

        XCTAssertTrue(sendAction(from: addButton))

        waitUntilSavedSettingsArrive(savedSettings)
        let rule = try XCTUnwrap(savedSettings.value?.appExclusions.first)
        XCTAssertEqual(rule.name, "Calls")
        XCTAssertEqual(rule.matchTerms, ["zoom"])
        XCTAssertEqual(rule.mode, .pauseWhenMatched)
    }

    func testEyeOnlyModeHidesBodyAppExclusionTarget() throws {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = true
        settings.bodyBreak.isEnabled = false
        settings.appExclusions = [
            AppExclusionRule(
                id: "eye-only",
                name: "Calls",
                matchTerms: ["zoom"],
                mode: .pauseWhenMatched,
                appliesTo: [.eyeGate, .bodyBreak],
                isEnabled: true
            )
        ]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectContextTab(in: contentView)

        XCTAssertFalse(try view(withIdentifier: "prefs.appExclusionAppliesEye", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.appExclusionAppliesBody", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.appliesEye")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.appliesBody")))
    }

    func testBodyOnlyModeHidesEyeAppExclusionTarget() throws {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = false
        settings.bodyBreak.isEnabled = true
        settings.appExclusions = [
            AppExclusionRule(
                id: "body-only",
                name: "Deep work",
                matchTerms: ["xcode"],
                mode: .resumeOnlyWhenMatched,
                appliesTo: [.eyeGate, .bodyBreak],
                isEnabled: true
            )
        ]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectContextTab(in: contentView)

        XCTAssertTrue(try view(withIdentifier: "prefs.appExclusionAppliesEye", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.appExclusionAppliesBody", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.appliesEye")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.appliesBody")))
    }

    func testEyeOnlyModeDefaultsNewAppExclusionToEyeGateAndAutosaves() throws {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = true
        settings.bodyBreak.isEnabled = false
        settings.appExclusions = []
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectContextTab(in: contentView)
        let checkbox = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionEnabled", in: contentView) as? NSButton)
        let terms = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionTermsField", in: contentView) as? NSTokenField)
        let appliesEye = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionAppliesEye", in: contentView) as? NSButton)
        let appliesBody = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionAppliesBody", in: contentView) as? NSButton)
        terms.objectValue = ["zoom"]
        checkbox.state = .on

        XCTAssertTrue(sendAction(from: checkbox))

        XCTAssertFalse(appliesEye.isHidden)
        XCTAssertTrue(appliesBody.isHidden)
        XCTAssertEqual(appliesEye.state, .on)
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.appExclusions.first?.appliesTo, Set([RestKind.eyeGate]))
    }

    private func selectContextTab(in view: NSView) throws {
        let tabView = try XCTUnwrap(firstTabView(in: view))
        tabView.selectTabViewItem(withIdentifier: L10n.tr("prefs.tabContext"))
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

    private func selectPopup(_ popup: NSPopUpButton, representedObject: String) {
        for index in 0..<popup.numberOfItems where popup.item(at: index)?.representedObject as? String == representedObject {
            popup.selectItem(at: index)
            return
        }
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

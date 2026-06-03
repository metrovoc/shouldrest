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

    func testEnabledAppExclusionShowsDetailRowsAndAdvancedRules() throws {
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
        XCTAssertFalse(try view(withIdentifier: "appExclusions", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.appExclusionsJSONRow", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.matchTerms")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.advancedRulesJSON")))
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

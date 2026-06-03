import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowShortcutTests: XCTestCase {
    func testShortcutRecorderUsesCompactStatefulDisplay() {
        let button = ShortcutRecorderButton()

        XCTAssertEqual(button.title, L10n.tr("shortcut.notSet"))
        XCTAssertEqual(button.toolTip, L10n.tr("shortcut.recordHelp"))
        XCTAssertNotNil(button.image)
        XCTAssertEqual(button.imagePosition, .imageLeading)

        button.shortcutValue = "CmdOrCtrl+Option+E"
        XCTAssertEqual(button.title, "⌘⌥E")
        XCTAssertEqual(button.toolTip, L10n.tr("shortcut.clearHelp"))
        XCTAssertNotNil(button.image)

        button.performClick(nil)
        XCTAssertEqual(button.title, L10n.tr("shortcut.recording"))
        XCTAssertEqual(button.toolTip, L10n.tr("shortcut.recordingHelp"))
        XCTAssertNotNil(button.image)
    }

    func testUnsetShortcutsDoNotRepeatRecordInstructionAsButtonText() throws {
        let settings = RestSettings.defaults
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)
        let visibleTexts = visibleTexts(in: contentView)

        XCTAssertTrue(visibleTexts.contains(L10n.tr("shortcut.notSet")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("shortcut.record")))
        XCTAssertTrue(visibleTexts.contains("⌘⌥E"))
    }

    func testDuplicateShortcutsShowVisibleConflictWarning() throws {
        var settings = RestSettings.defaults
        settings.shortcuts.takeEyeGateNow = "Cmd+1"
        settings.shortcuts.takeBodyBreakNow = "Command+1"
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectShortcutsTab(in: contentView)
        let visibleTexts = visibleTexts(in: contentView)

        let warning = try XCTUnwrap(visibleTexts.first { $0.contains(L10n.tr("prefs.eyeGateNow")) && $0.contains(L10n.tr("prefs.bodyBreakNow")) })
        XCTAssertTrue(warning.contains("⌘1"))
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
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.endBodyBreak")))
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

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

    private func selectShortcutsTab(in view: NSView) throws {
        let tabView = try XCTUnwrap(firstTabView(in: view))
        tabView.selectTabViewItem(withIdentifier: L10n.tr("prefs.tabShortcuts"))
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

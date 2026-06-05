import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowAutosaveStatusTests: XCTestCase {
    func testPreferencesShowIconAutosaveStatusWithoutSaveButton() throws {
        L10n.languageOverride = "en"
        defer { L10n.languageOverride = nil }

        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        let icon = try XCTUnwrap(view(withIdentifier: "autosaveStatusIcon", in: contentView) as? NSImageView)
        let label = try XCTUnwrap(view(withIdentifier: "autosaveStatusLabel", in: contentView) as? NSTextField)

        XCTAssertNotNil(icon.image)
        XCTAssertEqual(label.stringValue, L10n.tr("prefs.autosaveReady"))
        XCTAssertEqual(label.stringValue, "All changes saved")
        XCTAssertEqual(label.toolTip, L10n.tr("prefs.autosaveReady"))
        XCTAssertEqual(label.accessibilityLabel(), L10n.tr("prefs.autosaveReady"))
        XCTAssertEqual(label.accessibilityHelp(), L10n.tr("prefs.autosaveReady"))
        XCTAssertFalse(buttonTitles(in: contentView).contains("Save"))
    }

    func testPreferencesStartWithBrandedHeaderAndAutosaveStatus() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        let header = try XCTUnwrap(view(withIdentifier: "prefs.header", in: contentView))
        let icon = try XCTUnwrap(view(withIdentifier: "prefs.headerIcon", in: contentView) as? NSImageView)
        let title = try XCTUnwrap(view(withIdentifier: "prefs.headerTitle", in: contentView) as? NSTextField)
        let subtitle = try XCTUnwrap(view(withIdentifier: "prefs.headerSubtitle", in: contentView) as? NSTextField)
        let status = try XCTUnwrap(view(withIdentifier: "prefs.headerAutosave", in: contentView))
        let statusLabel = try XCTUnwrap(view(withIdentifier: "autosaveStatusLabel", in: contentView) as? NSTextField)

        XCTAssertTrue(contains(icon, in: header))
        XCTAssertTrue(contains(title, in: header))
        XCTAssertTrue(contains(subtitle, in: header))
        XCTAssertTrue(contains(statusLabel, in: status))
        XCTAssertEqual(icon.image?.size, NSSize(width: 36, height: 36))
        XCTAssertEqual(title.stringValue, L10n.tr("preferences.title"))
        XCTAssertEqual(subtitle.stringValue, L10n.tr("prefs.headerSubtitle"))
        XCTAssertEqual(statusLabel.stringValue, L10n.tr("prefs.autosaveReady"))
        let restoreDefaultsButton = try XCTUnwrap(view(withIdentifier: "prefs.restoreDefaultsButton", in: contentView) as? NSButton)
        XCTAssertFalse(restoreDefaultsButton.isEnabled)
        XCTAssertEqual(restoreDefaultsButton.toolTip, L10n.tr("prefs.restoreDefaultsDisabledDefaultHelp"))
        XCTAssertEqual(restoreDefaultsButton.accessibilityLabel(), L10n.tr("prefs.restoreDefaults"))
        XCTAssertEqual(restoreDefaultsButton.accessibilityHelp(), L10n.tr("prefs.restoreDefaultsDisabledDefaultHelp"))
        XCTAssertNotNil(restoreDefaultsButton.image)
        XCTAssertEqual(restoreDefaultsButton.image?.accessibilityDescription, L10n.tr("prefs.restoreDefaults"))
        XCTAssertEqual(restoreDefaultsButton.imagePosition, .imageLeading)
    }

    func testRestoreDefaultsButtonEnablesOnlyForVisiblePreferenceChanges() throws {
        var onboardingCompletedDefaults = RestSettings.defaults
        onboardingCompletedDefaults.operations.hasCompletedOnboarding = true
        let defaultController = PreferencesWindowController(settings: onboardingCompletedDefaults, onSave: { _ in })
        let defaultContent = try XCTUnwrap(defaultController.window?.contentView)
        let defaultButton = try XCTUnwrap(view(withIdentifier: "prefs.restoreDefaultsButton", in: defaultContent) as? NSButton)

        XCTAssertFalse(defaultButton.isEnabled)
        XCTAssertEqual(defaultButton.toolTip, L10n.tr("prefs.restoreDefaultsDisabledDefaultHelp"))

        var customSettings = RestSettings.restoredDefaults
        customSettings.eyeGate.interval = 25 * 60
        let customController = PreferencesWindowController(settings: customSettings, onSave: { _ in })
        let customContent = try XCTUnwrap(customController.window?.contentView)
        let customButton = try XCTUnwrap(view(withIdentifier: "prefs.restoreDefaultsButton", in: customContent) as? NSButton)

        XCTAssertTrue(customButton.isEnabled)
        XCTAssertEqual(customButton.toolTip, L10n.tr("prefs.restoreDefaultsHelp"))
        XCTAssertEqual(customButton.accessibilityHelp(), L10n.tr("prefs.restoreDefaultsHelp"))
    }

    func testRestoreDefaultsButtonEnablesImmediatelyForPendingTextEdits() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let restoreDefaultsButton = try XCTUnwrap(view(withIdentifier: "prefs.restoreDefaultsButton", in: contentView) as? NSButton)
        let eyeInterval = try XCTUnwrap(view(withIdentifier: "eyeIntervalField", in: contentView) as? NSTextField)

        XCTAssertFalse(restoreDefaultsButton.isEnabled)

        eyeInterval.stringValue = "21"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: eyeInterval))

        XCTAssertTrue(restoreDefaultsButton.isEnabled)
        XCTAssertEqual(restoreDefaultsButton.toolTip, L10n.tr("prefs.restoreDefaultsHelp"))
    }

    func testRestoreDefaultsConfirmationDefaultsToCancel() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let alert = controller.makeRestoreDefaultsAlert()

        XCTAssertEqual(alert.messageText, L10n.tr("prefs.restoreDefaults"))
        XCTAssertEqual(alert.informativeText, L10n.tr("prefs.restoreDefaultsWarning"))
        XCTAssertEqual(alert.alertStyle, .warning)
        XCTAssertEqual(alert.buttons.map(\.title), [
            L10n.tr("prefs.restoreDefaultsCancel"),
            L10n.tr("prefs.restoreDefaultsContinue")
        ])
        XCTAssertEqual(alert.buttons[0].keyEquivalent, "\r")
        XCTAssertEqual(alert.buttons[1].keyEquivalent, "")
        if #available(macOS 11.0, *) {
            XCTAssertFalse(alert.buttons[0].hasDestructiveAction)
            XCTAssertTrue(alert.buttons[1].hasDestructiveAction)
        }
    }

    func testAutosaveReadyCopyUsesSavedStateInEnglishAndChinese() {
        defer { L10n.languageOverride = nil }

        L10n.languageOverride = "en"
        XCTAssertEqual(L10n.tr("prefs.autosaveReady"), "All changes saved")
        XCTAssertEqual(L10n.tr("prefs.autosaveCopied"), "Copied to clipboard")
        XCTAssertEqual(L10n.format("prefs.autosaveCopiedField", "App Rules Export"), "Copied App Rules Export to clipboard")
        XCTAssertEqual(L10n.tr("prefs.autosaveAppRulesRestored"), "Saved app rules restored")
        XCTAssertEqual(L10n.tr("prefs.autosaveIdeasRestored"), "Saved ideas restored")
        XCTAssertEqual(L10n.tr("prefs.autosaveUpdateSourceRestored"), "Default update source restored")
        XCTAssertEqual(L10n.tr("prefs.autosaveShortcutCleared"), "Shortcut cleared")
        XCTAssertEqual(L10n.tr("prefs.autosaveShortcutRestored"), "Default shortcut restored")
        XCTAssertEqual(L10n.tr("prefs.autosaveBodyImageSelected"), "Body Break image selected")
        XCTAssertEqual(L10n.tr("prefs.autosaveBodyImageCleared"), "Body Break image cleared")
        XCTAssertEqual(L10n.tr("prefs.restoreDefaultsDisabledDefaultHelp"), "Current preferences already match the app defaults.")

        L10n.languageOverride = "zh-Hans"
        XCTAssertEqual(L10n.tr("prefs.autosaveReady"), "所有更改已保存")
        XCTAssertEqual(L10n.tr("prefs.autosaveCopied"), "已复制到剪贴板")
        XCTAssertEqual(L10n.format("prefs.autosaveCopiedField", "应用规则导出文本"), "应用规则导出文本已复制到剪贴板")
        XCTAssertEqual(L10n.tr("prefs.autosaveAppRulesRestored"), "已还原保存的应用规则")
        XCTAssertEqual(L10n.tr("prefs.autosaveIdeasRestored"), "已还原保存的提示")
        XCTAssertEqual(L10n.tr("prefs.autosaveUpdateSourceRestored"), "默认更新来源已恢复")
        XCTAssertEqual(L10n.tr("prefs.autosaveShortcutCleared"), "快捷键已清空")
        XCTAssertEqual(L10n.tr("prefs.autosaveShortcutRestored"), "默认快捷键已恢复")
        XCTAssertEqual(L10n.tr("prefs.autosaveBodyImageSelected"), "活动休息图片已选择")
        XCTAssertEqual(L10n.tr("prefs.autosaveBodyImageCleared"), "活动休息图片已清空")
        XCTAssertEqual(L10n.tr("prefs.restoreDefaultsDisabledDefaultHelp"), "当前偏好设置已是应用默认值。")
    }

    private func view(withIdentifier identifier: String, in view: NSView) -> NSView? {
        if view.identifier?.rawValue == identifier {
            return view
        }
        for subview in view.subviews {
            if let found = self.view(withIdentifier: identifier, in: subview) {
                return found
            }
        }
        return nil
    }

    private func buttonTitles(in view: NSView) -> [String] {
        var titles: [String] = []
        if let button = view as? NSButton, !button.title.isEmpty {
            titles.append(button.title)
        }
        for subview in view.subviews {
            titles.append(contentsOf: buttonTitles(in: subview))
        }
        return titles
    }

    private func contains(_ child: NSView, in ancestor: NSView) -> Bool {
        if child === ancestor {
            return true
        }
        for subview in ancestor.subviews {
            if contains(child, in: subview) {
                return true
            }
        }
        return false
    }
}

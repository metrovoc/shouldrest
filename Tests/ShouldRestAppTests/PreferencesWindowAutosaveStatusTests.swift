import AppKit
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
        XCTAssertEqual(restoreDefaultsButton.toolTip, L10n.tr("prefs.restoreDefaultsHelp"))
        XCTAssertEqual(restoreDefaultsButton.accessibilityLabel(), L10n.tr("prefs.restoreDefaults"))
        XCTAssertEqual(restoreDefaultsButton.accessibilityHelp(), L10n.tr("prefs.restoreDefaultsHelp"))
        XCTAssertNotNil(restoreDefaultsButton.image)
        XCTAssertEqual(restoreDefaultsButton.image?.accessibilityDescription, L10n.tr("prefs.restoreDefaults"))
        XCTAssertEqual(restoreDefaultsButton.imagePosition, .imageLeading)
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

        L10n.languageOverride = "zh-Hans"
        XCTAssertEqual(L10n.tr("prefs.autosaveReady"), "所有更改已保存")
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

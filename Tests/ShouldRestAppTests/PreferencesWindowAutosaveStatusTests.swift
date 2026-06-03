import AppKit
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowAutosaveStatusTests: XCTestCase {
    func testPreferencesShowIconAutosaveStatusWithoutSaveButton() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        let icon = try XCTUnwrap(view(withIdentifier: "autosaveStatusIcon", in: contentView) as? NSImageView)
        let label = try XCTUnwrap(view(withIdentifier: "autosaveStatusLabel", in: contentView) as? NSTextField)

        XCTAssertNotNil(icon.image)
        XCTAssertEqual(label.stringValue, L10n.tr("prefs.autosaveReady"))
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
        XCTAssertNotNil(view(withIdentifier: "prefs.restoreDefaultsButton", in: contentView) as? NSButton)
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

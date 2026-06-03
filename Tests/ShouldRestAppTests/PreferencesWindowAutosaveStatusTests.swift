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
}

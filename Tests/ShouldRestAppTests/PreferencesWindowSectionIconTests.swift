import AppKit
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowSectionIconTests: XCTestCase {
    func testEyeGateSectionUsesRestGateMark() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        let icon = try XCTUnwrap(
            contentView.descendant(withIdentifier: "prefs.section.eyeGate.restGateIcon") as? NSImageView
        )

        XCTAssertEqual(icon.image?.size, NSSize(width: 18, height: 18))
        XCTAssertTrue(icon.image?.isTemplate ?? false)
        XCTAssertEqual(icon.image?.accessibilityDescription, L10n.tr("prefs.sectionEyeGate"))
    }

    func testBodyBreakSectionKeepsSystemIcon() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        let icon = try XCTUnwrap(
            contentView.descendant(withIdentifier: "prefs.section.bodyBreak.systemIcon") as? NSImageView
        )

        XCTAssertNotNil(icon.image)
        XCTAssertEqual(icon.image?.accessibilityDescription, L10n.tr("prefs.sectionBodyBreak"))
    }
}

private extension NSView {
    func descendant(withIdentifier rawIdentifier: String) -> NSView? {
        if identifier?.rawValue == rawIdentifier {
            return self
        }
        for subview in subviews {
            if let match = subview.descendant(withIdentifier: rawIdentifier) {
                return match
            }
        }
        return nil
    }
}

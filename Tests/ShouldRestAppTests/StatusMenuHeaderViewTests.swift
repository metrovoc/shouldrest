import AppKit
import XCTest
@testable import shouldrest

@MainActor
final class StatusMenuHeaderViewTests: XCTestCase {
    func testHeaderViewRendersTitleStatusSecondaryAndBadge() throws {
        let view = StatusMenuHeaderView(
            content: MenuStatusPresenter.HeaderContent(
                title: "ShouldRest",
                primary: "Next: Eye Gate at 8:00 PM",
                secondary: "Next Body Break after 2 Eye Gate(s)",
                healthBadge: "Danger 3/10",
                icon: .restGate
            )
        )

        XCTAssertEqual(view.frame.size, NSSize(width: 318, height: 70))
        XCTAssertNotNil(view.descendant(withIdentifier: "statusMenu.headerIcon") as? NSImageView)
        XCTAssertEqual(try textField("statusMenu.headerTitle", in: view).stringValue, "ShouldRest")
        XCTAssertEqual(try textField("statusMenu.headerPrimary", in: view).stringValue, "Next: Eye Gate at 8:00 PM")
        XCTAssertEqual(try textField("statusMenu.headerSecondary", in: view).stringValue, "Next Body Break after 2 Eye Gate(s)")
        XCTAssertFalse(try textField("statusMenu.headerSecondary", in: view).isHidden)
        XCTAssertEqual(try textField("statusMenu.headerBadge", in: view).stringValue, "Danger 3/10")
        XCTAssertFalse(try textField("statusMenu.headerBadge", in: view).isHidden)
    }

    func testHeaderViewCanHideOptionalSecondaryAndBadge() throws {
        let view = StatusMenuHeaderView(
            content: MenuStatusPresenter.HeaderContent(
                title: "ShouldRest",
                primary: "Paused indefinitely",
                secondary: nil,
                healthBadge: nil,
                icon: .systemSymbol("pause.circle")
            )
        )

        XCTAssertEqual(try textField("statusMenu.headerPrimary", in: view).stringValue, "Paused indefinitely")
        XCTAssertTrue(try textField("statusMenu.headerSecondary", in: view).isHidden)
        XCTAssertTrue(try textField("statusMenu.headerBadge", in: view).isHidden)
    }

    private func textField(_ identifier: String, in view: NSView) throws -> NSTextField {
        try XCTUnwrap(view.descendant(withIdentifier: identifier) as? NSTextField)
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

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
                secondary: "Next Body Break after 2 Eye Gates",
                healthBadge: "Debt 3/10",
                icon: .restGate
            )
        )

        let expectedSummary = "ShouldRest. Next: Eye Gate at 8:00 PM. Next Body Break after 2 Eye Gates. Debt 3/10"
        XCTAssertEqual(view.frame.size, NSSize(width: 318, height: 82))
        XCTAssertEqual(view.toolTip, expectedSummary)
        XCTAssertEqual(view.accessibilityLabel(), expectedSummary)
        XCTAssertEqual(view.accessibilityHelp(), expectedSummary)

        let icon = try XCTUnwrap(view.descendant(withIdentifier: "statusMenu.headerIcon") as? NSImageView)
        XCTAssertEqual(icon.accessibilityLabel(), "ShouldRest")
        XCTAssertEqual(icon.accessibilityHelp(), expectedSummary)
        XCTAssertEqual(icon.toolTip, "ShouldRest")
        assertTextField("statusMenu.headerTitle", in: view, text: "ShouldRest")
        assertTextField("statusMenu.headerPrimary", in: view, text: "Next: Eye Gate at 8:00 PM")
        assertTextField("statusMenu.headerSecondary", in: view, text: "Next Body Break after 2 Eye Gates", isHidden: false)
        assertTextField("statusMenu.headerBadge", in: view, text: "Debt 3/10", isHidden: false)
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

        XCTAssertEqual(view.accessibilityLabel(), "ShouldRest. Paused indefinitely")
        XCTAssertEqual(view.accessibilityHelp(), "ShouldRest. Paused indefinitely")
        XCTAssertEqual(try textField("statusMenu.headerPrimary", in: view).stringValue, "Paused indefinitely")
        let secondary = try textField("statusMenu.headerSecondary", in: view)
        XCTAssertTrue(secondary.isHidden)
        XCTAssertNil(secondary.toolTip)
        XCTAssertNil(secondary.accessibilityLabel())
        XCTAssertNil(secondary.accessibilityHelp())

        let badge = try textField("statusMenu.headerBadge", in: view)
        XCTAssertTrue(badge.isHidden)
        XCTAssertNil(badge.toolTip)
        XCTAssertNil(badge.accessibilityLabel())
        XCTAssertNil(badge.accessibilityHelp())
    }

    func testHeaderSecondaryWrapsGuidanceCopy() throws {
        let view = StatusMenuHeaderView(
            content: MenuStatusPresenter.HeaderContent(
                title: "ShouldRest",
                primary: "Eye Gate active, 15s remaining",
                secondary: "Click Emergency Exit twice in the overlay, or press Esc twice.",
                healthBadge: nil,
                icon: .restGate
            )
        )

        let secondary = try textField("statusMenu.headerSecondary", in: view)

        XCTAssertFalse(secondary.isHidden)
        XCTAssertEqual(secondary.lineBreakMode, .byWordWrapping)
        XCTAssertEqual(secondary.maximumNumberOfLines, 2)
        XCTAssertEqual(
            secondary.stringValue,
            "Click Emergency Exit twice in the overlay, or press Esc twice."
        )
        XCTAssertEqual(
            secondary.accessibilityLabel(),
            "Click Emergency Exit twice in the overlay, or press Esc twice."
        )
        XCTAssertEqual(
            secondary.accessibilityHelp(),
            "Click Emergency Exit twice in the overlay, or press Esc twice."
        )
    }

    private func assertTextField(
        _ identifier: String,
        in view: NSView,
        text: String,
        isHidden: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            let field = try textField(identifier, in: view)
            XCTAssertEqual(field.stringValue, text, file: file, line: line)
            XCTAssertEqual(field.isHidden, isHidden, file: file, line: line)
            XCTAssertEqual(field.toolTip, text, file: file, line: line)
            XCTAssertEqual(field.accessibilityLabel(), text, file: file, line: line)
            XCTAssertEqual(field.accessibilityHelp(), text, file: file, line: line)
        } catch {
            XCTFail("Missing text field \(identifier): \(error)", file: file, line: line)
        }
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

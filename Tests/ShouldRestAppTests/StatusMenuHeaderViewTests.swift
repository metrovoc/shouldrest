import AppKit
import XCTest
@testable import shouldrest

@MainActor
final class StatusMenuHeaderViewTests: XCTestCase {
    func testHeaderViewLeadsWithStatusAndShowsDetailBadgeAndProgress() throws {
        let view = StatusMenuHeaderView(
            content: MenuStatusPresenter.HeaderContent(
                title: "Eye Gate in 10m",
                primary: "Due around 8:00 PM",
                secondary: "Body Break in 30m",
                healthBadge: "Debt 3/10",
                icon: .eye,
                progress: 0.25
            )
        )

        let expectedSummary = "Eye Gate in 10m. Due around 8:00 PM. Body Break in 30m. Debt 3/10"
        XCTAssertEqual(view.frame.width, 300)
        XCTAssertGreaterThan(view.frame.height, 60)
        XCTAssertEqual(view.toolTip, expectedSummary)
        XCTAssertEqual(view.accessibilityLabel(), expectedSummary)
        XCTAssertEqual(view.accessibilityHelp(), expectedSummary)

        let icon = try XCTUnwrap(view.descendant(withIdentifier: "statusMenu.headerIcon") as? NSImageView)
        XCTAssertEqual(icon.accessibilityLabel(), L10n.tr("app.name"))
        XCTAssertEqual(icon.accessibilityHelp(), expectedSummary)
        XCTAssertTrue(icon.image?.isTemplate ?? false)
        assertTextField("statusMenu.headerTitle", in: view, text: "Eye Gate in 10m")
        assertTextField("statusMenu.headerPrimary", in: view, text: "Due around 8:00 PM")
        assertTextField("statusMenu.headerSecondary", in: view, text: "Body Break in 30m", isHidden: false)
        assertTextField("statusMenu.headerBadge", in: view, text: "Debt 3/10", isHidden: false)
        XCTAssertEqual(view.progressForTesting ?? -1, 0.25, accuracy: 0.001)
    }

    func testHeaderViewCanHideOptionalSecondaryBadgeAndProgress() throws {
        let view = StatusMenuHeaderView(
            content: MenuStatusPresenter.HeaderContent(
                title: "Paused indefinitely",
                primary: "Paused by you",
                secondary: nil,
                healthBadge: nil,
                icon: .paused
            )
        )

        XCTAssertEqual(view.accessibilityLabel(), "Paused indefinitely. Paused by you")
        XCTAssertEqual(view.accessibilityHelp(), "Paused indefinitely. Paused by you")
        XCTAssertEqual(try textField("statusMenu.headerTitle", in: view).stringValue, "Paused indefinitely")
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
        XCTAssertNil(view.progressForTesting)
    }

    func testHeaderSecondaryWrapsGuidanceCopy() throws {
        let view = StatusMenuHeaderView(
            content: MenuStatusPresenter.HeaderContent(
                title: "Eye Gate in 10m",
                primary: "Due around 8:00 PM",
                secondary: "Click Emergency Exit twice in the overlay, or press Esc twice.",
                healthBadge: nil,
                icon: .eye
            )
        )

        let secondary = try textField("statusMenu.headerSecondary", in: view)

        XCTAssertFalse(secondary.isHidden)
        XCTAssertEqual(secondary.lineBreakMode, .byWordWrapping)
        XCTAssertEqual(secondary.maximumNumberOfLines, 2)
        XCTAssertEqual(
            secondary.accessibilityLabel(),
            "Click Emergency Exit twice in the overlay, or press Esc twice."
        )
    }

    func testHeaderUpdatesInPlaceWhileMenuIsOpen() throws {
        let view = StatusMenuHeaderView(
            content: MenuStatusPresenter.HeaderContent(
                title: "Eye Gate in 10m",
                primary: "Due around 8:00 PM",
                secondary: nil,
                healthBadge: nil,
                icon: .eye,
                progress: 0.5
            )
        )
        let title = try textField("statusMenu.headerTitle", in: view)

        view.update(content: MenuStatusPresenter.HeaderContent(
            title: "Eye Gate in 9m",
            primary: "Due around 8:00 PM",
            secondary: nil,
            healthBadge: "Debt 1/10",
            icon: .eye,
            progress: 0.55
        ))

        XCTAssertTrue(title === (try textField("statusMenu.headerTitle", in: view)))
        XCTAssertEqual(title.stringValue, "Eye Gate in 9m")
        XCTAssertFalse(try textField("statusMenu.headerBadge", in: view).isHidden)
        XCTAssertEqual(view.progressForTesting ?? -1, 0.55, accuracy: 0.001)
        XCTAssertEqual(view.accessibilityLabel(), "Eye Gate in 9m. Due around 8:00 PM. Debt 1/10")
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

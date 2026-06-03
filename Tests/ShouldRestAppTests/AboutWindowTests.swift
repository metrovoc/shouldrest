import AppKit
import XCTest
@testable import shouldrest

@MainActor
final class AboutWindowTests: XCTestCase {
    func testAboutWindowUsesPolishedBrandLayout() throws {
        let controller = AboutWindowController(
            version: "9.9.9",
            projectURL: URL(string: "https://example.com")!,
            onOpenDebug: {}
        )
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)

        XCTAssertGreaterThanOrEqual(window.frame.width, 580)
        XCTAssertGreaterThanOrEqual(window.frame.height, 400)
        XCTAssertEqual(window.level, .floating)
        XCTAssertFalse(window.hidesOnDeactivate)
        XCTAssertNotNil(contentView.descendant(withIdentifier: "about.brandIcon"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "about.heading"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "about.version"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "about.summaryPanel"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "about.feature.eyeGate"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "about.feature.bodyBreak"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "about.feature.compatibility"))
    }

    func testAboutWindowCopySeparatesVersionAndProductChoices() throws {
        let controller = AboutWindowController(
            version: "9.9.9",
            projectURL: URL(string: "https://example.com")!,
            onOpenDebug: {}
        )
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let texts = visibleTexts(in: contentView)

        XCTAssertTrue(texts.contains(L10n.tr("app.name")))
        XCTAssertTrue(texts.contains(L10n.format("about.version", "9.9.9")))
        XCTAssertTrue(texts.contains(L10n.tr("about.tagline")))
        XCTAssertTrue(texts.contains(L10n.tr("about.eyeGateTitle")))
        XCTAssertTrue(texts.contains(L10n.tr("about.bodyBreakTitle")))
        XCTAssertTrue(texts.contains(L10n.tr("about.compatibilityTitle")))
    }

    func testAboutButtonsUseIconsAndInvokeActions() throws {
        var openedDebug = false
        var openedProjectURL: URL?
        let projectURL = try XCTUnwrap(URL(string: "https://example.com/project"))
        let controller = AboutWindowController(
            version: "9.9.9",
            projectURL: projectURL,
            onOpenDebug: {
                openedDebug = true
            },
            onOpenProject: {
                openedProjectURL = $0
            }
        )
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let buttons = try actionButtons(in: contentView)

        for button in buttons.all {
            XCTAssertNotNil(button.image)
            XCTAssertEqual(button.imagePosition, .imageLeading)
            XCTAssertFalse(button.toolTip?.isEmpty ?? true)
        }
        XCTAssertEqual(buttons.close.keyEquivalent, "\r")

        buttons.debug.sendAction(buttons.debug.action, to: buttons.debug.target)
        XCTAssertTrue(openedDebug)

        buttons.project.sendAction(buttons.project.action, to: buttons.project.target)
        XCTAssertEqual(openedProjectURL, projectURL)
    }

    private func actionButtons(in view: NSView) throws -> AboutActionButtons {
        AboutActionButtons(
            project: try XCTUnwrap(view.descendant(withIdentifier: "about.projectButton") as? NSButton),
            debug: try XCTUnwrap(view.descendant(withIdentifier: "about.debugButton") as? NSButton),
            close: try XCTUnwrap(view.descendant(withIdentifier: "about.closeButton") as? NSButton)
        )
    }
}

private struct AboutActionButtons {
    var project: NSButton
    var debug: NSButton
    var close: NSButton

    var all: [NSButton] {
        [project, debug, close]
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

@MainActor
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

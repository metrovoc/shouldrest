import AppKit
import XCTest
@testable import shouldrest

@MainActor
final class DebugWindowTests: XCTestCase {
    func testDebugWindowUsesSupportLayout() throws {
        let controller = DebugWindowController(debugInfoProvider: { "state=refreshed" })
        controller.update(
            text: "state=initial",
            logURL: URL(fileURLWithPath: "/tmp/shouldrest.log"),
            settingsURL: URL(fileURLWithPath: "/tmp/settings.json")
        )

        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)

        XCTAssertEqual(window.title, L10n.tr("debug.title"))
        XCTAssertEqual(L10n.tr("debug.title"), "ShouldRest Diagnostics")
        XCTAssertGreaterThanOrEqual(window.frame.width, 740)
        XCTAssertGreaterThanOrEqual(window.frame.height, 540)
        XCTAssertNotNil(contentView.descendant(withIdentifier: "debug.headerIcon"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "debug.heading"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "debug.subtitle"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "debug.safetyPanel"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "debug.textScroll"))

        XCTAssertEqual(contentView.label(withIdentifier: "debug.safetyTitle")?.stringValue, L10n.tr("debug.summaryReadyTitle"))
        XCTAssertEqual(contentView.label(withIdentifier: "debug.safetyBody")?.stringValue, L10n.tr("debug.summaryReadyBody"))

        let textView = try XCTUnwrap(contentView.debugTextView())
        XCTAssertEqual(textView.string, "state=initial")
        XCTAssertFalse(textView.isEditable)
        XCTAssertTrue(textView.isSelectable)
        XCTAssertNotNil(textView.font)
    }

    func testDebugActionsUseIconsAndLocalWindowState() throws {
        var summary = DebugSafetySummary(
            title: "Initial safety state",
            body: "Initial recovery guidance",
            symbolName: "checkmark.shield",
            severity: .ready
        )
        let controller = DebugWindowController(
            debugInfoProvider: { "state=refreshed" },
            safetySummaryProvider: { summary }
        )
        controller.update(
            text: "state=initial",
            logURL: URL(fileURLWithPath: "/tmp/shouldrest.log"),
            settingsURL: URL(fileURLWithPath: "/tmp/settings.json")
        )
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let buttons = try actionButtons(in: contentView)

        for button in buttons.all {
            XCTAssertNotNil(button.image)
            XCTAssertEqual(button.imagePosition, .imageLeading)
            XCTAssertFalse(button.toolTip?.isEmpty ?? true)
        }

        NSPasteboard.general.clearContents()
        buttons.copy.sendAction(buttons.copy.action, to: buttons.copy.target)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "state=initial")
        XCTAssertEqual(contentView.label(withIdentifier: "debug.status")?.stringValue, L10n.tr("debug.copied"))

        summary = DebugSafetySummary(
            title: "Updated safety state",
            body: "Updated recovery guidance",
            symbolName: "exclamationmark.shield",
            severity: .active
        )
        buttons.refresh.sendAction(buttons.refresh.action, to: buttons.refresh.target)
        XCTAssertEqual(contentView.debugTextView()?.string, "state=refreshed")
        XCTAssertEqual(contentView.label(withIdentifier: "debug.safetyTitle")?.stringValue, "Updated safety state")
        XCTAssertEqual(contentView.label(withIdentifier: "debug.safetyBody")?.stringValue, "Updated recovery guidance")
        XCTAssertEqual(contentView.label(withIdentifier: "debug.status")?.stringValue, L10n.tr("debug.updated"))
    }

    func testDebugPathButtonsDisableWhenPathsAreHidden() throws {
        let controller = DebugWindowController()
        controller.update(text: "paths hidden", logURL: nil, settingsURL: nil)

        let contentView = try XCTUnwrap(controller.window?.contentView)
        let buttons = try actionButtons(in: contentView)

        XCTAssertFalse(buttons.openLog.isEnabled)
        XCTAssertFalse(buttons.openSettings.isEnabled)
        XCTAssertEqual(buttons.openLog.toolTip, L10n.tr("debug.pathHidden"))
        XCTAssertEqual(buttons.openSettings.toolTip, L10n.tr("debug.pathHidden"))
    }

    private func actionButtons(in view: NSView) throws -> DebugActionButtons {
        DebugActionButtons(
            copy: try XCTUnwrap(view.descendant(withIdentifier: "debug.copyButton") as? NSButton),
            refresh: try XCTUnwrap(view.descendant(withIdentifier: "debug.refreshButton") as? NSButton),
            openLog: try XCTUnwrap(view.descendant(withIdentifier: "debug.openLogButton") as? NSButton),
            openSettings: try XCTUnwrap(view.descendant(withIdentifier: "debug.openSettingsButton") as? NSButton)
        )
    }
}

private struct DebugActionButtons {
    var copy: NSButton
    var refresh: NSButton
    var openLog: NSButton
    var openSettings: NSButton

    var all: [NSButton] {
        [copy, refresh, openLog, openSettings]
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
        if let scrollView = self as? NSScrollView,
           let documentView = scrollView.documentView {
            return documentView.descendant(withIdentifier: rawIdentifier)
        }
        return nil
    }

    func debugTextView() -> NSTextView? {
        descendant(withIdentifier: "debug.textView") as? NSTextView
    }

    func label(withIdentifier rawIdentifier: String) -> NSTextField? {
        descendant(withIdentifier: rawIdentifier) as? NSTextField
    }
}

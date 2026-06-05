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
        XCTAssertEqual(L10n.tr("debug.title"), "ShouldRest Support Report")
        XCTAssertGreaterThanOrEqual(window.frame.width, 740)
        XCTAssertGreaterThanOrEqual(window.frame.height, 540)
        XCTAssertNotNil(contentView.descendant(withIdentifier: "debug.headerIcon"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "debug.heading"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "debug.subtitle"))
        let searchField = try XCTUnwrap(contentView.descendant(withIdentifier: "debug.searchField") as? NSSearchField)
        XCTAssertEqual(searchField.placeholderString, L10n.tr("debug.searchPlaceholder"))
        XCTAssertEqual(searchField.toolTip, L10n.tr("debug.searchHelp"))
        XCTAssertEqual(searchField.accessibilityLabel(), L10n.tr("debug.searchPlaceholder"))
        XCTAssertEqual(searchField.accessibilityHelp(), L10n.tr("debug.searchHelp"))
        XCTAssertTrue(searchField.sendsSearchStringImmediately)
        XCTAssertFalse(searchField.sendsWholeSearchString)
        XCTAssertNotNil(contentView.descendant(withIdentifier: "debug.safetyPanel"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "debug.textScroll"))
        XCTAssertEqual(contentView.label(withIdentifier: "debug.subtitle")?.stringValue, L10n.tr("debug.subtitle"))

        XCTAssertEqual(contentView.label(withIdentifier: "debug.safetyTitle")?.stringValue, L10n.tr("debug.summaryReadyTitle"))
        XCTAssertEqual(contentView.label(withIdentifier: "debug.safetyBody")?.stringValue, L10n.tr("debug.summaryReadyBody"))
        XCTAssertEqual(contentView.label(withIdentifier: "debug.safetyTitle")?.toolTip, L10n.tr("debug.summaryReadyTitle"))
        XCTAssertEqual(contentView.label(withIdentifier: "debug.safetyTitle")?.accessibilityLabel(), L10n.tr("debug.summaryReadyTitle"))
        XCTAssertEqual(contentView.label(withIdentifier: "debug.safetyTitle")?.accessibilityHelp(), L10n.tr("debug.summaryReadyBody"))
        XCTAssertEqual(contentView.label(withIdentifier: "debug.safetyBody")?.toolTip, L10n.tr("debug.summaryReadyBody"))
        XCTAssertEqual(contentView.label(withIdentifier: "debug.safetyBody")?.accessibilityLabel(), L10n.tr("debug.summaryReadyBody"))
        XCTAssertEqual(contentView.label(withIdentifier: "debug.safetyBody")?.accessibilityHelp(), L10n.tr("debug.summaryReadyBody"))
        XCTAssertFalse(try XCTUnwrap(contentView.label(withIdentifier: "debug.subtitle")?.stringValue).contains("runtime flags"))
        XCTAssertFalse(try XCTUnwrap(contentView.label(withIdentifier: "debug.safetyTitle")?.stringValue).contains("blocking"))
        let headerIcon = try XCTUnwrap(contentView.descendant(withIdentifier: "debug.headerIcon") as? NSImageView)
        XCTAssertEqual(headerIcon.image?.accessibilityDescription, L10n.tr("debug.heading"))
        let safetyPanel = try XCTUnwrap(contentView.descendant(withIdentifier: "debug.safetyPanel"))
        XCTAssertEqual(safetyPanel.accessibilityLabel(), L10n.tr("debug.summaryReadyTitle"))
        XCTAssertEqual(safetyPanel.accessibilityHelp(), L10n.tr("debug.summaryReadyBody"))
        let safetyIcon = try XCTUnwrap(contentView.descendant(withIdentifier: "debug.safetyIcon") as? NSImageView)
        XCTAssertEqual(safetyIcon.image?.accessibilityDescription, L10n.tr("debug.summaryReadyTitle"))
        XCTAssertEqual(safetyIcon.accessibilityHelp(), L10n.tr("debug.summaryReadyBody"))

        let textView = try XCTUnwrap(contentView.debugTextView())
        XCTAssertEqual(textView.string, "state=initial")
        XCTAssertFalse(textView.isEditable)
        XCTAssertTrue(textView.isSelectable)
        XCTAssertNotNil(textView.font)
        XCTAssertEqual(textView.toolTip, L10n.tr("debug.textHelp"))
        XCTAssertEqual(textView.accessibilityHelp(), L10n.tr("debug.textHelp"))
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
            XCTAssertEqual(button.image?.accessibilityDescription, button.title)
            XCTAssertEqual(button.imagePosition, .imageLeading)
            XCTAssertFalse(button.toolTip?.isEmpty ?? true)
            XCTAssertEqual(button.accessibilityLabel(), button.title)
            XCTAssertEqual(button.accessibilityHelp(), button.toolTip)
        }
        XCTAssertEqual(buttons.copy.title, "Copy Report")
        XCTAssertEqual(buttons.refresh.title, "Refresh Report")
        XCTAssertEqual(buttons.openLog.title, L10n.tr("debug.openLog"))
        XCTAssertEqual(buttons.openSettings.title, L10n.tr("debug.openSettings"))
        XCTAssertEqual(buttons.openLog.title, "Show Log in Finder")
        XCTAssertEqual(buttons.openSettings.title, "Show Settings in Finder")
        XCTAssertEqual(buttons.openLog.toolTip, L10n.tr("debug.openLogHelp"))
        XCTAssertEqual(buttons.openSettings.toolTip, L10n.tr("debug.openSettingsHelp"))
        let status = try XCTUnwrap(contentView.label(withIdentifier: "debug.status"))
        XCTAssertEqual(status.stringValue, "Report ready")
        XCTAssertEqual(status.accessibilityLabel(), L10n.tr("debug.ready"))
        XCTAssertEqual(status.toolTip, L10n.tr("debug.ready"))
        XCTAssertEqual(status.accessibilityHelp(), L10n.tr("debug.ready"))

        NSPasteboard.general.clearContents()
        buttons.copy.sendAction(buttons.copy.action, to: buttons.copy.target)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "state=initial")
        XCTAssertEqual(status.stringValue, "Copied to clipboard")
        XCTAssertEqual(status.stringValue, L10n.tr("debug.copied"))
        XCTAssertEqual(status.accessibilityLabel(), L10n.tr("debug.copied"))
        XCTAssertEqual(status.toolTip, L10n.tr("debug.copied"))
        XCTAssertEqual(status.accessibilityHelp(), L10n.tr("debug.copied"))

        summary = DebugSafetySummary(
            title: "Updated safety state",
            body: "Updated recovery guidance",
            symbolName: "exclamationmark.shield",
            severity: .active
        )
        buttons.refresh.sendAction(buttons.refresh.action, to: buttons.refresh.target)
        XCTAssertEqual(contentView.debugTextView()?.string, "state=refreshed")
        let safetyTitle = try XCTUnwrap(contentView.label(withIdentifier: "debug.safetyTitle"))
        let safetyBody = try XCTUnwrap(contentView.label(withIdentifier: "debug.safetyBody"))
        let safetyPanel = try XCTUnwrap(contentView.descendant(withIdentifier: "debug.safetyPanel"))
        XCTAssertEqual(safetyTitle.stringValue, "Updated safety state")
        XCTAssertEqual(safetyTitle.toolTip, "Updated safety state")
        XCTAssertEqual(safetyTitle.accessibilityLabel(), "Updated safety state")
        XCTAssertEqual(safetyTitle.accessibilityHelp(), "Updated recovery guidance")
        XCTAssertEqual(safetyBody.stringValue, "Updated recovery guidance")
        XCTAssertEqual(safetyBody.toolTip, "Updated recovery guidance")
        XCTAssertEqual(safetyBody.accessibilityLabel(), "Updated recovery guidance")
        XCTAssertEqual(safetyBody.accessibilityHelp(), "Updated recovery guidance")
        XCTAssertEqual(safetyPanel.accessibilityLabel(), "Updated safety state")
        XCTAssertEqual(safetyPanel.accessibilityHelp(), "Updated recovery guidance")
        let safetyIcon = try XCTUnwrap(contentView.descendant(withIdentifier: "debug.safetyIcon") as? NSImageView)
        XCTAssertEqual(safetyIcon.image?.accessibilityDescription, "Updated safety state")
        XCTAssertEqual(safetyIcon.accessibilityHelp(), "Updated recovery guidance")
        XCTAssertEqual(status.stringValue, "Report refreshed")
        XCTAssertEqual(status.stringValue, L10n.tr("debug.updated"))
        XCTAssertEqual(status.accessibilityLabel(), L10n.tr("debug.updated"))
        XCTAssertEqual(status.toolTip, L10n.tr("debug.updated"))
        XCTAssertEqual(status.accessibilityHelp(), L10n.tr("debug.updated"))
    }

    func testDebugSearchFindsCyclesAndClearsSupportReportText() throws {
        let controller = DebugWindowController()
        controller.update(text: "state=initial\nactiveSession=none\nstate=refreshed")
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let searchField = try XCTUnwrap(contentView.descendant(withIdentifier: "debug.searchField") as? NSSearchField)
        let textView = try XCTUnwrap(contentView.debugTextView())
        let status = try XCTUnwrap(contentView.label(withIdentifier: "debug.status"))

        searchField.stringValue = "state"
        XCTAssertTrue(searchField.sendAction(searchField.action, to: searchField.target))

        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 5))
        XCTAssertEqual(status.stringValue, L10n.format("debug.searchMatched", 1, 2, "state"))
        XCTAssertEqual(status.toolTip, status.stringValue)
        XCTAssertEqual(status.accessibilityLabel(), status.stringValue)
        XCTAssertEqual(status.accessibilityHelp(), status.stringValue)

        XCTAssertTrue(controller.control(
            searchField,
            textView: NSTextView(),
            doCommandBy: #selector(NSResponder.insertNewline(_:))
        ))

        XCTAssertEqual(textView.selectedRange(), NSRange(location: 33, length: 5))
        XCTAssertEqual(status.stringValue, L10n.format("debug.searchMatched", 2, 2, "state"))

        searchField.stringValue = "missing"
        XCTAssertTrue(searchField.sendAction(searchField.action, to: searchField.target))

        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 0))
        XCTAssertEqual(status.stringValue, L10n.format("debug.searchNoResults", "missing"))
        XCTAssertEqual(status.textColor, .systemOrange)

        XCTAssertTrue(controller.control(
            searchField,
            textView: NSTextView(),
            doCommandBy: #selector(NSResponder.cancelOperation(_:))
        ))

        XCTAssertEqual(searchField.stringValue, "")
        XCTAssertEqual(status.stringValue, L10n.tr("debug.ready"))
    }

    func testCommandFFocusesDebugSearch() throws {
        let controller = DebugWindowController()
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)
        let searchField = try XCTUnwrap(contentView.descendant(withIdentifier: "debug.searchField") as? NSSearchField)

        XCTAssertTrue(window.performKeyEquivalent(with: try keyEvent(
            characters: "f",
            modifierFlags: .command,
            window: window
        )))

        XCTAssertTrue(isFirstResponder(searchField, in: window))
    }

    func testDebugPathButtonsDisableWhenPathsAreHidden() throws {
        let controller = DebugWindowController()
        controller.update(text: "paths hidden", logURL: nil, settingsURL: nil)

        let contentView = try XCTUnwrap(controller.window?.contentView)
        let buttons = try actionButtons(in: contentView)

        XCTAssertFalse(buttons.openLog.isEnabled)
        XCTAssertFalse(buttons.openSettings.isEnabled)
        XCTAssertEqual(buttons.openLog.title, L10n.tr("debug.openLogHidden"))
        XCTAssertEqual(buttons.openSettings.title, L10n.tr("debug.openSettingsHidden"))
        XCTAssertEqual(buttons.openLog.image?.accessibilityDescription, L10n.tr("debug.openLogHidden"))
        XCTAssertEqual(buttons.openSettings.image?.accessibilityDescription, L10n.tr("debug.openSettingsHidden"))
        XCTAssertEqual(buttons.openLog.accessibilityLabel(), L10n.tr("debug.openLogHidden"))
        XCTAssertEqual(buttons.openSettings.accessibilityLabel(), L10n.tr("debug.openSettingsHidden"))
        XCTAssertEqual(buttons.openLog.toolTip, L10n.tr("debug.openLogHiddenHelp"))
        XCTAssertEqual(buttons.openSettings.toolTip, L10n.tr("debug.openSettingsHiddenHelp"))
        XCTAssertEqual(buttons.openLog.accessibilityHelp(), L10n.tr("debug.openLogHiddenHelp"))
        XCTAssertEqual(buttons.openSettings.accessibilityHelp(), L10n.tr("debug.openSettingsHiddenHelp"))
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

@MainActor
private func keyEvent(
    characters: String,
    modifierFlags: NSEvent.ModifierFlags,
    window: NSWindow
) throws -> NSEvent {
    try XCTUnwrap(NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: modifierFlags,
        timestamp: 0,
        windowNumber: window.windowNumber,
        context: nil,
        characters: characters,
        charactersIgnoringModifiers: characters,
        isARepeat: false,
        keyCode: 0
    ))
}

@MainActor
private func isFirstResponder(_ view: NSView, in window: NSWindow) -> Bool {
    if window.firstResponder === view {
        return true
    }
    if let editor = window.firstResponder as? NSTextView,
       let fieldEditorTarget = editor.delegate as? NSObject,
       fieldEditorTarget === view {
        return true
    }
    return false
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

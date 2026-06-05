import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowSoundPreviewTests: XCTestCase {
    func testSoundPreviewButtonsUseIconAndContextualHelp() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)

        let expected: [(identifier: String, labelKey: String)] = [
            ("eyeStart", "prefs.eyeStartSound"),
            ("eyeFinish", "prefs.eyeFinishSound"),
            ("bodyStart", "prefs.bodyStartSound"),
            ("bodyFinish", "prefs.bodyFinishSound")
        ]

        var labels = Set<String>()
        for item in expected {
            let button = try XCTUnwrap(view(withIdentifier: item.identifier, in: contentView) as? NSButton)
            let soundLabel = L10n.tr(item.labelKey)
            let expectedLabel = L10n.format("prefs.previewSoundLabel", soundLabel)
            let expectedHelp = L10n.format("prefs.previewSoundSpecificHelp", soundLabel)
            XCTAssertEqual(button.title, L10n.tr("prefs.previewSound"))
            XCTAssertEqual(button.title, "Play Preview")
            XCTAssertNotNil(button.image)
            XCTAssertEqual(button.image?.accessibilityDescription, expectedLabel)
            XCTAssertEqual(button.imagePosition, .imageLeading)
            XCTAssertEqual(button.toolTip, expectedHelp)
            XCTAssertEqual(button.accessibilityLabel(), expectedLabel)
            XCTAssertEqual(button.accessibilityHelp(), expectedHelp)
            labels.insert(expectedLabel)
        }

        XCTAssertEqual(labels.count, expected.count)
    }

    func testPreviewingSilentSoundShowsVisibleStatus() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let button = try XCTUnwrap(view(withIdentifier: "eyeStart", in: contentView) as? NSButton)
        button.sendAction(button.action, to: button.target)

        let statusRow = try XCTUnwrap(view(withIdentifier: "soundPreviewStatusRow", in: contentView) as? NSStackView)
        let statusIcon = try XCTUnwrap(view(withIdentifier: "soundPreviewStatusIcon", in: contentView) as? NSImageView)
        let status = try XCTUnwrap(view(withIdentifier: "soundPreviewStatus", in: contentView) as? NSTextField)
        let expectedStatus = L10n.format("prefs.soundPreviewSilence", L10n.tr("prefs.eyeStartSound"))
        XCTAssertFalse(statusRow.isHidden)
        XCTAssertTrue(statusRow.wantsLayer)
        XCTAssertEqual(statusRow.edgeInsets.top, 8)
        XCTAssertEqual(statusRow.edgeInsets.left, 12)
        XCTAssertLessThanOrEqual(statusRow.layer?.cornerRadius ?? 99, 8)
        XCTAssertEqual(statusRow.layer?.borderWidth, 1)
        XCTAssertNotNil(statusRow.layer?.backgroundColor)
        XCTAssertNotNil(statusRow.layer?.borderColor)
        XCTAssertGreaterThanOrEqual(statusRow.constraints.first { $0.firstAttribute == .width }?.constant ?? 0, 650)
        XCTAssertEqual(statusRow.toolTip, expectedStatus)
        XCTAssertEqual(statusRow.accessibilityLabel(), L10n.tr("prefs.previewSound"))
        XCTAssertEqual(statusRow.accessibilityHelp(), expectedStatus)
        XCTAssertFalse(statusIcon.isHidden)
        XCTAssertNotNil(statusIcon.image)
        XCTAssertEqual(statusIcon.image?.accessibilityDescription, L10n.tr("prefs.previewSound"))
        XCTAssertEqual(statusIcon.accessibilityLabel(), L10n.tr("prefs.previewSound"))
        XCTAssertEqual(statusIcon.accessibilityHelp(), expectedStatus)
        XCTAssertFalse(status.isHidden)
        XCTAssertEqual(status.stringValue, expectedStatus)
        XCTAssertGreaterThanOrEqual(status.maximumNumberOfLines, 2)
        XCTAssertEqual(status.toolTip, expectedStatus)
        XCTAssertEqual(status.accessibilityLabel(), expectedStatus)
        XCTAssertEqual(status.accessibilityHelp(), expectedStatus)
    }

    func testSoundPreviewStatusStartsHiddenWithoutReadableResidualState() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)

        let statusRow = try XCTUnwrap(view(withIdentifier: "soundPreviewStatusRow", in: contentView) as? NSStackView)
        let statusIcon = try XCTUnwrap(view(withIdentifier: "soundPreviewStatusIcon", in: contentView) as? NSImageView)
        let status = try XCTUnwrap(view(withIdentifier: "soundPreviewStatus", in: contentView) as? NSTextField)

        assertHiddenSoundPreviewStatusIsCleared(
            row: statusRow,
            icon: statusIcon,
            label: status
        )
    }

    func testPreviewingSelectedSoundShowsRowAndSoundName() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let button = try XCTUnwrap(view(withIdentifier: "eyeStart", in: contentView) as? NSButton)
        let popup = try XCTUnwrap(soundPopup(containingButton: button, in: contentView))
        popup.selectItem(at: min(1, popup.numberOfItems - 1))
        let soundTitle = try XCTUnwrap(popup.selectedItem?.title)

        button.sendAction(button.action, to: button.target)

        let status = try XCTUnwrap(view(withIdentifier: "soundPreviewStatus", in: contentView) as? NSTextField)
        let expectedStatus = L10n.format("prefs.soundPreviewPlayed", L10n.tr("prefs.eyeStartSound"), soundTitle)
        XCTAssertFalse(status.isHidden)
        XCTAssertEqual(status.stringValue, expectedStatus)
        XCTAssertEqual(status.toolTip, expectedStatus)
        XCTAssertEqual(status.accessibilityLabel(), expectedStatus)
        XCTAssertEqual(status.accessibilityHelp(), expectedStatus)
    }

    func testSilentNotificationsMuteSoundPreviewWithoutHidingConfiguration() throws {
        var settings = RestSettings.defaults
        settings.notifications.silentNotifications = true
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let toggle = try XCTUnwrap(view(withIdentifier: "prefs.silentNotifications", in: contentView) as? NSButton)
        let button = try XCTUnwrap(view(withIdentifier: "eyeStart", in: contentView) as? NSButton)
        let popup = try XCTUnwrap(soundPopup(containingButton: button, in: contentView))
        let soundLabel = L10n.tr("prefs.eyeStartSound")
        let mutedHelp = L10n.format("prefs.previewSoundMutedHelp", soundLabel)

        XCTAssertTrue(popup.isEnabled)
        XCTAssertTrue(button.isEnabled)
        XCTAssertEqual(button.toolTip, mutedHelp)
        XCTAssertEqual(button.accessibilityHelp(), mutedHelp)

        button.sendAction(button.action, to: button.target)

        let status = try XCTUnwrap(view(withIdentifier: "soundPreviewStatus", in: contentView) as? NSTextField)
        let expectedStatus = L10n.format("prefs.soundPreviewMuted", soundLabel)
        XCTAssertFalse(status.isHidden)
        XCTAssertEqual(status.stringValue, expectedStatus)
        XCTAssertEqual(status.toolTip, expectedStatus)
        XCTAssertEqual(status.accessibilityLabel(), expectedStatus)
        XCTAssertEqual(status.accessibilityHelp(), expectedStatus)

        toggle.state = .off
        toggle.sendAction(toggle.action, to: toggle.target)

        let normalHelp = L10n.format("prefs.previewSoundSpecificHelp", soundLabel)
        XCTAssertEqual(button.toolTip, normalHelp)
        XCTAssertEqual(button.accessibilityHelp(), normalHelp)
    }

    func testChangingSoundSelectionClearsPreviewStatus() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let button = try XCTUnwrap(view(withIdentifier: "eyeStart", in: contentView) as? NSButton)
        button.sendAction(button.action, to: button.target)
        let statusRow = try XCTUnwrap(view(withIdentifier: "soundPreviewStatusRow", in: contentView) as? NSStackView)
        let statusIcon = try XCTUnwrap(view(withIdentifier: "soundPreviewStatusIcon", in: contentView) as? NSImageView)
        let status = try XCTUnwrap(view(withIdentifier: "soundPreviewStatus", in: contentView) as? NSTextField)
        XCTAssertFalse(statusRow.isHidden)
        XCTAssertFalse(status.isHidden)

        let popup = try XCTUnwrap(soundPopup(containingButton: button, in: contentView))
        popup.selectItem(at: min(1, popup.numberOfItems - 1))
        popup.sendAction(popup.action, to: popup.target)

        XCTAssertTrue(statusRow.isHidden)
        XCTAssertNil(statusRow.toolTip)
        XCTAssertNil(statusRow.accessibilityLabel())
        XCTAssertNil(statusRow.accessibilityHelp())
        XCTAssertTrue(statusIcon.isHidden)
        XCTAssertNil(statusIcon.image)
        XCTAssertNil(statusIcon.toolTip)
        XCTAssertNil(statusIcon.accessibilityLabel())
        XCTAssertNil(statusIcon.accessibilityHelp())
        XCTAssertTrue(status.isHidden)
        XCTAssertEqual(status.stringValue, "")
        XCTAssertNil(status.toolTip)
        XCTAssertNil(status.accessibilityLabel())
        XCTAssertNil(status.accessibilityHelp())
    }

    private func assertHiddenSoundPreviewStatusIsCleared(
        row: NSStackView,
        icon: NSImageView,
        label: NSTextField,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(row.isHidden, file: file, line: line)
        XCTAssertNil(row.toolTip, file: file, line: line)
        XCTAssertNil(row.accessibilityLabel(), file: file, line: line)
        XCTAssertNil(row.accessibilityHelp(), file: file, line: line)
        XCTAssertTrue(icon.isHidden, file: file, line: line)
        XCTAssertNil(icon.image, file: file, line: line)
        XCTAssertNil(icon.toolTip, file: file, line: line)
        XCTAssertNil(icon.accessibilityLabel(), file: file, line: line)
        XCTAssertNil(icon.accessibilityHelp(), file: file, line: line)
        XCTAssertTrue(label.isHidden, file: file, line: line)
        XCTAssertEqual(label.stringValue, "", file: file, line: line)
        XCTAssertNil(label.toolTip, file: file, line: line)
        XCTAssertNil(label.accessibilityLabel(), file: file, line: line)
        XCTAssertNil(label.accessibilityHelp(), file: file, line: line)
    }

    private func soundPopup(containingButton button: NSButton, in view: NSView) -> NSPopUpButton? {
        guard let row = button.superview else { return nil }
        return firstPopup(in: row) ?? firstPopup(in: view)
    }

    private func selectAppearanceTab(in view: NSView) throws {
        let tabView = try XCTUnwrap(firstTabView(in: view))
        tabView.selectTabViewItem(withIdentifier: L10n.tr("prefs.tabAppearance"))
    }

    private func firstTabView(in view: NSView) -> NSTabView? {
        if let tabView = view as? NSTabView {
            return tabView
        }
        for subview in view.subviews {
            if let found = firstTabView(in: subview) {
                return found
            }
        }
        return nil
    }

    private func firstPopup(in view: NSView) -> NSPopUpButton? {
        if let popup = view as? NSPopUpButton {
            return popup
        }
        for subview in view.subviews {
            if let found = firstPopup(in: subview) {
                return found
            }
        }
        return nil
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
}

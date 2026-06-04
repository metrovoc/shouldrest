import AppKit
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowSoundPreviewTests: XCTestCase {
    func testSoundPreviewButtonsUseIconAndTooltip() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)

        let button = try XCTUnwrap(view(withIdentifier: "eyeStart", in: contentView) as? NSButton)
        XCTAssertEqual(button.title, L10n.tr("prefs.previewSound"))
        XCTAssertNotNil(button.image)
        XCTAssertEqual(button.image?.accessibilityDescription, button.title)
        XCTAssertEqual(button.imagePosition, .imageLeading)
        XCTAssertEqual(button.toolTip, L10n.tr("prefs.previewSoundHelp"))
        XCTAssertEqual(button.accessibilityLabel(), button.title)
        XCTAssertEqual(button.accessibilityHelp(), L10n.tr("prefs.previewSoundHelp"))
    }

    func testPreviewingSilentSoundShowsVisibleStatus() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let button = try XCTUnwrap(view(withIdentifier: "eyeStart", in: contentView) as? NSButton)
        button.sendAction(button.action, to: button.target)

        let status = try XCTUnwrap(view(withIdentifier: "soundPreviewStatus", in: contentView) as? NSTextField)
        XCTAssertFalse(status.isHidden)
        XCTAssertEqual(status.stringValue, L10n.tr("prefs.soundPreviewSilence"))
        XCTAssertEqual(status.toolTip, L10n.tr("prefs.soundPreviewSilence"))
        XCTAssertEqual(status.accessibilityHelp(), L10n.tr("prefs.soundPreviewSilence"))
    }

    func testChangingSoundSelectionClearsPreviewStatus() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let button = try XCTUnwrap(view(withIdentifier: "eyeStart", in: contentView) as? NSButton)
        button.sendAction(button.action, to: button.target)
        let status = try XCTUnwrap(view(withIdentifier: "soundPreviewStatus", in: contentView) as? NSTextField)
        XCTAssertFalse(status.isHidden)

        let popup = try XCTUnwrap(soundPopup(containingButton: button, in: contentView))
        popup.selectItem(at: min(1, popup.numberOfItems - 1))
        popup.sendAction(popup.action, to: popup.target)

        XCTAssertTrue(status.isHidden)
        XCTAssertEqual(status.stringValue, "")
        XCTAssertNil(status.toolTip)
        XCTAssertNil(status.accessibilityHelp())
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

import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowUpdatePreferencesTests: XCTestCase {
    func testUpdateDependentPreferencesAreVisibleWhenCheckingForUpdates() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)

        XCTAssertFalse(try view(withIdentifier: "prefs.notifyNewVersion", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.updateFeedURLRow", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.notifyNewVersion")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.updateFeedURL")))
    }

    func testDisabledUpdateCheckingHidesDependentPreferences() throws {
        var settings = RestSettings.defaults
        settings.operations.checkForUpdates = false
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)

        XCTAssertFalse(try view(withIdentifier: "prefs.checkUpdates", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.notifyNewVersion", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.updateFeedURLRow", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.checkUpdates")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.notifyNewVersion")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.updateFeedURL")))
    }

    func testTurningOffUpdateCheckingHidesDependentPreferencesAndAutosaves() throws {
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)
        let checkbox = try XCTUnwrap(view(withIdentifier: "prefs.checkUpdates", in: contentView) as? NSButton)
        checkbox.state = .off

        XCTAssertTrue(sendAction(from: checkbox))

        XCTAssertTrue(try view(withIdentifier: "prefs.notifyNewVersion", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.updateFeedURLRow", in: contentView).isHidden)

        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.operations.checkForUpdates, false)
    }

    func testClosingPreferencesFlushesPendingAutosaveImmediately() throws {
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)

        try selectAdvancedTab(in: contentView)
        let checkbox = try XCTUnwrap(view(withIdentifier: "prefs.checkUpdates", in: contentView) as? NSButton)
        checkbox.state = .off

        XCTAssertTrue(sendAction(from: checkbox))
        XCTAssertNil(savedSettings.value)

        XCTAssertTrue(controller.windowShouldClose(window))
        XCTAssertEqual(savedSettings.value?.operations.checkForUpdates, false)
    }

    func testClosingPreferencesCommitsInProgressTextEditing() throws {
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)

        try selectAdvancedTab(in: contentView)
        let field = try XCTUnwrap(view(withIdentifier: "prefs.updateFeedURLField", in: contentView) as? NSTextField)
        field.stringValue = "https://example.com/shouldrest.json"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))

        XCTAssertNil(savedSettings.value)

        XCTAssertTrue(controller.windowShouldClose(window))
        XCTAssertEqual(savedSettings.value?.operations.updateFeedURL, "https://example.com/shouldrest.json")
    }

    private func selectAdvancedTab(in view: NSView) throws {
        let tabView = try XCTUnwrap(firstTabView(in: view))
        tabView.selectTabViewItem(withIdentifier: L10n.tr("prefs.tabAdvanced"))
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

    private func view(withIdentifier identifier: String, in rootView: NSView) throws -> NSView {
        try XCTUnwrap(findView(withIdentifier: identifier, in: rootView))
    }

    private func findView(withIdentifier identifier: String, in view: NSView) -> NSView? {
        if view.identifier?.rawValue == identifier {
            return view
        }
        for subview in view.subviews {
            if let found = self.findView(withIdentifier: identifier, in: subview) {
                return found
            }
        }
        return nil
    }

    private func sendAction(from control: NSControl) -> Bool {
        guard let action = control.action else { return false }
        return NSApplication.shared.sendAction(action, to: control.target, from: control)
    }

    private func waitUntilSavedSettingsArrive(_ settings: SavedSettingsBox) {
        let deadline = Date().addingTimeInterval(2)
        while settings.value == nil && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private func visibleTexts(in view: NSView, ancestorHidden: Bool = false) -> [String] {
        let hidden = ancestorHidden || view.isHidden
        var texts: [String] = []
        if !hidden {
            if let popup = view as? NSPopUpButton, !popup.title.isEmpty {
                texts.append(popup.title)
            } else if let button = view as? NSButton, !button.title.isEmpty {
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
}

private final class SavedSettingsBox {
    var value: RestSettings?
}

import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowMorningPauseTests: XCTestCase {
    func testFixedHourMorningModeHidesSunriseLocationFields() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)

        XCTAssertFalse(try row("prefs.pauseUntilMorningHourRow", in: contentView).isHidden)
        XCTAssertTrue(try row("prefs.pauseUntilMorningLatitudeRow", in: contentView).isHidden)
        XCTAssertTrue(try row("prefs.pauseUntilMorningLongitudeRow", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.pauseUntilMorningHour")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.pauseUntilMorningLatitude")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.pauseUntilMorningLongitude")))
    }

    func testSunriseMorningModeHidesFixedHourAndAutosavesMode() throws {
        var settings = RestSettings.defaults
        settings.operations.pauseUntilMorningMode = .hour
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)
        let popup = try XCTUnwrap(view(withIdentifier: "prefs.pauseUntilMorningMode", in: contentView) as? NSPopUpButton)
        selectPopup(popup, representedObject: MorningPauseMode.sunrise.rawValue)

        XCTAssertTrue(sendAction(from: popup))

        XCTAssertTrue(try row("prefs.pauseUntilMorningHourRow", in: contentView).isHidden)
        XCTAssertFalse(try row("prefs.pauseUntilMorningLatitudeRow", in: contentView).isHidden)
        XCTAssertFalse(try row("prefs.pauseUntilMorningLongitudeRow", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.pauseUntilMorningHour")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.pauseUntilMorningLatitude")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.pauseUntilMorningLongitude")))

        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.operations.pauseUntilMorningMode, .sunrise)
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

    private func row(_ identifier: String, in rootView: NSView) throws -> NSView {
        try XCTUnwrap(view(withIdentifier: identifier, in: rootView))
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

    private func selectPopup(_ popup: NSPopUpButton, representedObject: String) {
        for index in 0..<popup.numberOfItems where popup.item(at: index)?.representedObject as? String == representedObject {
            popup.selectItem(at: index)
            return
        }
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

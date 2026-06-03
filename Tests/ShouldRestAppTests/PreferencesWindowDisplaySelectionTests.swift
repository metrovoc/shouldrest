import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowDisplaySelectionTests: XCTestCase {
    func testSpecificDisplayPickerIsHiddenUntilSpecificDisplayIsSelected() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let visibleTexts = visibleTexts(in: contentView)

        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.bodyCoveredDisplay")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.configuredDisplayIndex")))
        XCTAssertFalse(visibleTexts.contains { $0.hasPrefix(displayPrefix) })
    }

    func testSingleDisplayTargetAppearsWhenAllDisplayCoverageIsDisabled() throws {
        var settings = RestSettings.defaults
        settings.bodyBreak.enforcement.coversAllDisplays = false
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let visibleTexts = visibleTexts(in: contentView)

        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.bodyCoveredDisplay")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.configuredDisplayIndex")))
    }

    func testCoveredDisplaySpecificChoiceStaysHiddenWhileCoveringAllDisplays() throws {
        var settings = RestSettings.defaults
        settings.bodyBreak.enforcement.coversAllDisplays = true
        settings.bodyBreak.enforcement.coveredDisplay = .configured
        settings.bodyBreak.enforcement.contentDisplay = .all
        settings.bodyBreak.enforcement.configuredDisplayIndex = 0
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let visibleTexts = visibleTexts(in: contentView)

        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.bodyCoveredDisplay")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.configuredDisplayIndex")))
    }

    func testSpecificDisplayPickerShowsAvailableDisplays() throws {
        var settings = RestSettings.defaults
        settings.bodyBreak.enforcement.contentDisplay = .configured
        settings.bodyBreak.enforcement.configuredDisplayIndex = 0
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let visibleTexts = visibleTexts(in: contentView)

        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.configuredDisplayIndex")))
        XCTAssertTrue(visibleTexts.contains { $0.hasPrefix(displayPrefix) })
        XCTAssertFalse(visibleTexts.contains("Configured display index"))
    }

    func testSpecificDisplayPickerAutosavesSelectedDisplay() throws {
        var settings = RestSettings.defaults
        settings.bodyBreak.enforcement.contentDisplay = .configured
        settings.bodyBreak.enforcement.configuredDisplayIndex = 0
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let popup = try XCTUnwrap(configuredDisplayPopup(in: contentView))
        let targetItemIndex = min(1, max(0, popup.numberOfItems - 1))

        XCTAssertNotNil(popup.target)
        XCTAssertNotNil(popup.action)
        popup.selectItem(at: targetItemIndex)
        popup.sendAction(popup.action, to: popup.target)
        waitUntilSavedSettingsArrive(savedSettings)

        XCTAssertEqual(
            savedSettings.value?.bodyBreak.enforcement.configuredDisplayIndex,
            popup.selectedItem?.representedObject as? Int
        )
    }

    private var displayPrefix: String {
        L10n.format("prefs.displayPicker.item", 1, 1, 1, "").components(separatedBy: "1").first ?? "Display"
    }

    private func configuredDisplayPopup(in view: NSView) -> NSPopUpButton? {
        if let popup = view as? NSPopUpButton,
           popup.identifier?.rawValue == "prefs.bodyConfiguredDisplay" {
            return popup
        }
        for subview in view.subviews {
            if let found = configuredDisplayPopup(in: subview) {
                return found
            }
        }
        return nil
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

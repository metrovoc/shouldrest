import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowDisplaySelectionTests: XCTestCase {
    func testBodyDisplaySummaryExplainsDefaultAllDisplayCoverage() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let summary = try XCTUnwrap(view(withIdentifier: "prefs.bodyDisplaySummaryLabel", in: contentView) as? NSTextField)

        XCTAssertEqual(
            summary.stringValue,
            "\(L10n.tr("prefs.bodyDisplaySummary.coverAll")) \(L10n.tr("prefs.bodyDisplaySummary.contentAll"))"
        )
        XCTAssertTrue(visibleTexts(in: contentView).contains(summary.stringValue))
    }

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

    func testBodyDisplaySummaryExplainsSingleDisplayCoverageAndBlankContentTargets() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        var settings = RestSettings.defaults
        settings.bodyBreak.enforcement.coversAllDisplays = false
        settings.bodyBreak.enforcement.coveredDisplay = .cursor
        settings.bodyBreak.enforcement.contentDisplay = .primary
        settings.bodyBreak.enforcement.blankSecondaryDisplays = true
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let summary = try XCTUnwrap(view(withIdentifier: "prefs.bodyDisplaySummaryLabel", in: contentView) as? NSTextField)

        XCTAssertEqual(
            summary.stringValue,
            "\(L10n.format("prefs.bodyDisplaySummary.coverOne", L10n.tr("prefs.display.cursor"))) " +
                L10n.format("prefs.bodyDisplaySummary.contentTargetBlank", L10n.tr("prefs.display.primary"))
        )
    }

    func testBodyDisplaySummaryUpdatesWhenContentDisplayChanges() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let popup = try XCTUnwrap(view(withIdentifier: "prefs.bodyContentDisplay", in: contentView) as? NSPopUpButton)
        let summary = try XCTUnwrap(view(withIdentifier: "prefs.bodyDisplaySummaryLabel", in: contentView) as? NSTextField)

        selectPopup(popup, representedObject: DisplaySelection.none.rawValue)

        XCTAssertTrue(sendAction(from: popup))
        XCTAssertEqual(
            summary.stringValue,
            "\(L10n.tr("prefs.bodyDisplaySummary.coverAll")) \(L10n.tr("prefs.bodyDisplaySummary.contentNone"))"
        )
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

    func testDisplayPopupsExposeRowTitlesAsAccessibilityLabels() throws {
        var settings = RestSettings.defaults
        settings.bodyBreak.enforcement.coversAllDisplays = false
        settings.bodyBreak.enforcement.coveredDisplay = .cursor
        settings.bodyBreak.enforcement.contentDisplay = .configured
        settings.bodyBreak.enforcement.configuredDisplayIndex = 0
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        let coveredDisplay = try XCTUnwrap(view(withIdentifier: "prefs.bodyCoveredDisplay", in: contentView) as? NSPopUpButton)
        let contentDisplay = try XCTUnwrap(view(withIdentifier: "prefs.bodyContentDisplay", in: contentView) as? NSPopUpButton)
        let configuredDisplay = try XCTUnwrap(view(withIdentifier: "prefs.bodyConfiguredDisplay", in: contentView) as? NSPopUpButton)

        XCTAssertEqual(coveredDisplay.accessibilityLabel(), L10n.tr("prefs.bodyCoveredDisplay"))
        XCTAssertEqual(contentDisplay.accessibilityLabel(), L10n.tr("prefs.bodyContentDisplay"))
        XCTAssertEqual(configuredDisplay.accessibilityLabel(), L10n.tr("prefs.configuredDisplayIndex"))
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

import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowNavigationTests: XCTestCase {
    func testPreferenceTabsUseIconsAndTooltipsForScanning() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let tabView = try XCTUnwrap(view(withIdentifier: "prefs.tabView", in: contentView) as? NSTabView)

        let expectedTitles = [
            L10n.tr("prefs.tabSchedule"),
            L10n.tr("prefs.tabContext"),
            L10n.tr("prefs.tabAppearance"),
            L10n.tr("prefs.tabShortcuts"),
            L10n.tr("prefs.tabAdvanced")
        ]

        XCTAssertEqual(tabView.tabViewItems.map(\.label), expectedTitles)
        for item in tabView.tabViewItems {
            XCTAssertEqual(item.toolTip, item.label)
            XCTAssertNotNil(item.image, "\(item.label) should have a tab icon.")
            XCTAssertTrue(item.image?.isTemplate ?? false, "\(item.label) tab icon should adapt to light and dark mode.")
            XCTAssertEqual(item.image?.accessibilityDescription, item.label)
        }
    }

    func testPreferenceSearchJumpsToMatchingSettingWithoutAutosave() throws {
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let tabView = try XCTUnwrap(view(withIdentifier: "prefs.tabView", in: contentView) as? NSTabView)
        let searchField = try XCTUnwrap(view(withIdentifier: "prefs.searchField", in: contentView) as? NSSearchField)
        let searchStatus = try XCTUnwrap(view(withIdentifier: "prefs.searchStatusLabel", in: contentView) as? NSTextField)
        let saveStatus = try XCTUnwrap(view(withIdentifier: "autosaveStatusLabel", in: contentView) as? NSTextField)

        XCTAssertEqual(searchField.placeholderString, L10n.tr("prefs.searchPlaceholder"))
        searchField.stringValue = L10n.tr("prefs.pause5hShortcut")

        XCTAssertTrue(sendAction(from: searchField))

        XCTAssertEqual(tabView.selectedTabViewItem?.identifier as? String, L10n.tr("prefs.tabShortcuts"))
        XCTAssertFalse(searchStatus.isHidden)
        XCTAssertTrue(searchStatus.stringValue.contains(L10n.tr("prefs.tabShortcuts")))
        XCTAssertTrue(searchStatus.stringValue.contains(L10n.tr("prefs.pause5hShortcut")))

        let pause5h = try XCTUnwrap(view(withIdentifier: "shortcut.pause5h", in: contentView))
        let highlightedRow = try XCTUnwrap(pause5h.superview)
        XCTAssertEqual(highlightedRow.layer?.borderWidth, 1)
        XCTAssertNotNil(highlightedRow.layer?.backgroundColor)
        XCTAssertEqual(saveStatus.stringValue, L10n.tr("prefs.autosaveReady"))
        XCTAssertNil(savedSettings.value)
    }

    func testPreferenceSearchShowsNoResultWithoutChangingSelection() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let tabView = try XCTUnwrap(view(withIdentifier: "prefs.tabView", in: contentView) as? NSTabView)
        let searchField = try XCTUnwrap(view(withIdentifier: "prefs.searchField", in: contentView) as? NSSearchField)
        let searchStatus = try XCTUnwrap(view(withIdentifier: "prefs.searchStatusLabel", in: contentView) as? NSTextField)
        let originalSelection = tabView.selectedTabViewItem?.identifier as? String

        searchField.stringValue = "setting-that-does-not-exist"

        XCTAssertTrue(sendAction(from: searchField))

        XCTAssertEqual(tabView.selectedTabViewItem?.identifier as? String, originalSelection)
        XCTAssertFalse(searchStatus.isHidden)
        XCTAssertEqual(searchStatus.stringValue, L10n.tr("prefs.searchNoResults"))
        XCTAssertEqual(searchStatus.textColor, .systemOrange)
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

    private func sendAction(from control: NSControl) -> Bool {
        guard let action = control.action else { return false }
        return NSApplication.shared.sendAction(action, to: control.target, from: control)
    }
}

private final class SavedSettingsBox {
    var value: RestSettings?
}

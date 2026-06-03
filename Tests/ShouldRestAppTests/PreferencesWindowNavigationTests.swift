import AppKit
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

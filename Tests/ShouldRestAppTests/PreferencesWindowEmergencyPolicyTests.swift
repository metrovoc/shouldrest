import AppKit
import XCTest
@testable import shouldrest
@testable import ShouldRestCore

@MainActor
final class PreferencesWindowEmergencyPolicyTests: XCTestCase {
    func testEyeGateEmergencyPolicyControlsAreVisibleByDefault() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let visibleTexts = visibleTexts(in: contentView)

        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.eyeEmergencyOverride")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.eyeEmergencyOverrideHelp")))
        XCTAssertFalse(visibleTexts.contains("Emergency Exit hold time"))
        XCTAssertFalse(visibleTexts.contains("紧急退出等待时长"))
        XCTAssertFalse(visibleTexts.contains { $0.localizedCaseInsensitiveContains("confirmation") })
        XCTAssertFalse(visibleTexts.contains { $0.localizedCaseInsensitiveContains("available after") })
        XCTAssertFalse(visibleTexts.contains { $0.contains("确认次数") })
        XCTAssertFalse(visibleTexts.contains { $0.contains("可用等待") })
    }

    func testEmergencyPolicyControlExplainsTwoClickOverlayConfirmationAsHelpOnly() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        let button = try XCTUnwrap(view(withIdentifier: "prefs.eyeEmergencyOverride", in: contentView) as? NSButton)

        XCTAssertEqual(button.toolTip, L10n.tr("prefs.eyeEmergencyOverrideHelp"))
        XCTAssertEqual(button.accessibilityHelp(), L10n.tr("prefs.eyeEmergencyOverrideHelp"))
        XCTAssertTrue(button.toolTip?.contains("inside the overlay") ?? false)
        XCTAssertTrue(button.toolTip?.localizedCaseInsensitiveContains("second click") ?? false)
        XCTAssertTrue(button.toolTip?.localizedCaseInsensitiveContains("Esc") ?? false)
        XCTAssertFalse(button.toolTip?.localizedCaseInsensitiveContains("hold") ?? true)
    }

    func testStrictAdminVisibilityHidesEyeGateEmergencyPolicyControls() throws {
        var settings = RestSettings.defaults
        settings.admin.hideStrictPreferences = true
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let visibleTexts = visibleTexts(in: contentView)

        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.eyeEmergencyOverride")))
        XCTAssertFalse(visibleTexts.contains("Emergency Exit hold time"))
        XCTAssertFalse(visibleTexts.contains("紧急退出等待时长"))
        XCTAssertFalse(visibleTexts.contains { $0.localizedCaseInsensitiveContains("confirmation") })
        XCTAssertFalse(visibleTexts.contains { $0.contains("确认次数") })
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

    private func visibleTexts(in view: NSView, ancestorHidden: Bool = false) -> [String] {
        let hidden = ancestorHidden || view.isHidden
        var texts: [String] = []
        if !hidden {
            if let button = view as? NSButton, !button.title.isEmpty {
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

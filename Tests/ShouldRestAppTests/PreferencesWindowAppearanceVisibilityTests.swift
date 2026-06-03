import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowAppearanceVisibilityTests: XCTestCase {
    func testMenuBarStyleOptionsShowConcreteLengthPreviews() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let popup = try XCTUnwrap(view(withIdentifier: "prefs.trayStyle", in: contentView) as? NSPopUpButton)
        let titles = (0..<popup.numberOfItems).compactMap { popup.item(at: $0)?.title }

        XCTAssertTrue(titles.contains(L10n.tr("prefs.trayStyle.default")))
        XCTAssertTrue(titles.contains(L10n.tr("prefs.trayStyle.appName")))
        XCTAssertTrue(titles.contains(L10n.tr("prefs.trayStyle.timeToBreak")))
        XCTAssertTrue(titles.contains(L10n.tr("prefs.trayStyle.progress")))
        XCTAssertTrue(titles.contains { $0.contains("shortest") || $0.contains("最短") })
        XCTAssertTrue(titles.contains { $0.contains("SR") })
        XCTAssertTrue(titles.contains { $0.contains("20m") })
        XCTAssertTrue(titles.contains { $0.contains("E 20s") })
        XCTAssertGreaterThanOrEqual(popup.constraints.first { $0.firstAttribute == .width }?.constant ?? 0, 320)
    }

    func testMenuBarStylePreviewTitlesKeepRawSavedValues() throws {
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let popup = try XCTUnwrap(view(withIdentifier: "prefs.trayStyle", in: contentView) as? NSPopUpButton)
        selectPopup(popup, representedObject: TrayIconStyle.progress.rawValue)

        XCTAssertTrue(sendAction(from: popup))
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.presentation.trayIconStyle, .progress)
    }

    func testDisabledBodyBreakHidesBodyOnlyAppearanceControls() throws {
        var settings = RestSettings.defaults
        settings.bodyBreak.isEnabled = false
        settings.contentLibrary.customBodyBreakIdeas = [
            RestIdea(id: "stretch", kind: .bodyBreak, title: "Stretch", body: "Open shoulders"),
            RestIdea(id: "walk", kind: .bodyBreak, title: "Walk", body: "Walk around")
        ]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)

        XCTAssertFalse(try view(withIdentifier: "prefs.useBuiltInIdeas", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.eyeStartSoundRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.eyeFinishSoundRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.currentTimeBody", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyStartSoundRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.bodyFinishSoundRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.localImagePathRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.customBodyTitleRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.customBodyTextRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "customIdeas", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.customBodyIdeasJSONRow", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.localImagePath")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.advancedIdeasJSON")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.bodyStartSound")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.bodyFinishSound")))
    }

    func testDisabledEyeGateHidesEyeOnlyAppearanceControls() throws {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = false
        settings.bodyBreak.isEnabled = true
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)

        XCTAssertTrue(try view(withIdentifier: "prefs.eyeStartSoundRow", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.eyeFinishSoundRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.bodyStartSoundRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.bodyFinishSoundRow", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.eyeStartSound")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.eyeFinishSound")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.bodyStartSound")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.bodyFinishSound")))
    }

    func testReenablingBodyBreakShowsBodyOnlyAppearanceControlsAndAutosaves() throws {
        var settings = RestSettings.defaults
        settings.bodyBreak.isEnabled = false
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectScheduleTab(in: contentView)
        let bodyEnabled = try XCTUnwrap(view(withIdentifier: "prefs.bodyEnabled", in: contentView) as? NSButton)
        bodyEnabled.state = .on

        XCTAssertTrue(sendAction(from: bodyEnabled))
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.bodyBreak.isEnabled, true)

        try selectAppearanceTab(in: contentView)
        XCTAssertFalse(try view(withIdentifier: "prefs.currentTimeBody", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.bodyStartSoundRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.bodyFinishSoundRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.localImagePathRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.customBodyTitleRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.customBodyTextRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "customIdeas", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.customBodyIdeasJSONRow", in: contentView).isHidden)
    }

    func testReenablingEyeGateShowsEyeOnlyAppearanceControlsAndAutosaves() throws {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = false
        settings.bodyBreak.isEnabled = true
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectScheduleTab(in: contentView)
        let eyeEnabled = try XCTUnwrap(view(withIdentifier: "prefs.eyeEnabled", in: contentView) as? NSButton)
        eyeEnabled.state = .on

        XCTAssertTrue(sendAction(from: eyeEnabled))
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.eyeGate.isEnabled, true)

        try selectAppearanceTab(in: contentView)
        XCTAssertFalse(try view(withIdentifier: "prefs.eyeStartSoundRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.eyeFinishSoundRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.bodyStartSoundRow", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "prefs.bodyFinishSoundRow", in: contentView).isHidden)
    }

    private func selectScheduleTab(in view: NSView) throws {
        let tabView = try XCTUnwrap(firstTabView(in: view))
        tabView.selectTabViewItem(withIdentifier: L10n.tr("prefs.tabSchedule"))
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

    private func selectPopup(_ popup: NSPopUpButton, representedObject: String) {
        for index in 0..<popup.numberOfItems where popup.item(at: index)?.representedObject as? String == representedObject {
            popup.selectItem(at: index)
            return
        }
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

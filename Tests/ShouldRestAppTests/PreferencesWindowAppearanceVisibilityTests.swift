import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowAppearanceVisibilityTests: XCTestCase {
    func testMenuBarStyleControlIsNotShownInPolishedUI() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)

        XCTAssertNil(findView(withIdentifier: "prefs.trayStyle", in: contentView) as? NSPopUpButton)
        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertFalse(visibleTexts.contains("Menu bar style"))
        XCTAssertFalse(visibleTexts.contains("Icon only - shortest"))
        XCTAssertFalse(visibleTexts.contains("菜单栏样式"))
        XCTAssertFalse(visibleTexts.contains("仅图标 - 最短"))
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
        XCTAssertTrue(try view(withIdentifier: "prefs.customBodyIdeasListRow", in: contentView).isHidden)
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
        XCTAssertTrue(try view(withIdentifier: "prefs.customBodyIdeasListRow", in: contentView).isHidden)
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

    func testCustomBodyIdeaAddButtonCreatesRotationEntryAndAutosaves() throws {
        var settings = RestSettings.defaults
        settings.contentLibrary.customBodyBreakIdeas = []
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let title = try XCTUnwrap(view(withIdentifier: "prefs.customBodyTitleField", in: contentView) as? NSTextField)
        let body = try XCTUnwrap(view(withIdentifier: "customBodyTextEditor", in: contentView) as? NSTextView)
        let button = try XCTUnwrap(view(withIdentifier: "prefs.customBodyAddIdeaButton", in: contentView) as? NSButton)
        let listRow = try view(withIdentifier: "prefs.customBodyIdeasListRow", in: contentView)
        let jsonRow = try view(withIdentifier: "prefs.customBodyIdeasJSONRow", in: contentView)

        XCTAssertFalse(button.isHidden)
        XCTAssertFalse(button.isEnabled)
        XCTAssertTrue(listRow.isHidden)
        XCTAssertEqual(button.title, L10n.tr("prefs.addCustomIdea"))
        XCTAssertEqual(button.toolTip, L10n.tr("prefs.addCustomIdeaHelp"))
        XCTAssertNotNil(button.image)

        title.stringValue = "Loosen neck"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: title))
        body.string = "Roll shoulders and breathe."
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: body))

        XCTAssertTrue(button.isEnabled)
        XCTAssertTrue(sendAction(from: button))

        waitUntilSavedSettingsArrive(savedSettings)
        let ideas = try XCTUnwrap(savedSettings.value?.contentLibrary.customBodyBreakIdeas)
        XCTAssertEqual(ideas.count, 1)
        XCTAssertEqual(ideas[0].title, "Loosen neck")
        XCTAssertEqual(ideas[0].body, "Roll shoulders and breathe.")
        XCTAssertEqual(title.stringValue, "")
        XCTAssertEqual(body.string, "")
        XCTAssertFalse(listRow.isHidden)
        XCTAssertEqual(
            (try view(withIdentifier: "prefs.customBodyIdeaTitle.0", in: contentView) as? NSTextField)?.stringValue,
            "Loosen neck"
        )
        XCTAssertEqual(
            (try view(withIdentifier: "prefs.customBodyIdeaBody.0", in: contentView) as? NSTextField)?.stringValue,
            "Roll shoulders and breathe."
        )
        let removeButton = try XCTUnwrap(view(withIdentifier: "prefs.customBodyIdeaRemove.0", in: contentView) as? NSButton)
        XCTAssertNotNil(removeButton.image)
        XCTAssertEqual(removeButton.toolTip, L10n.tr("prefs.removeCustomIdeaHelp"))
        XCTAssertTrue(jsonRow.isHidden)
        XCTAssertFalse(button.isEnabled)
    }

    func testCustomBodyIdeaAddButtonAppendsToAdvancedIdeaRotation() throws {
        var settings = RestSettings.defaults
        settings.contentLibrary.customBodyBreakIdeas = [
            RestIdea(id: "stretch", kind: .bodyBreak, title: "Stretch", body: "Open shoulders"),
            RestIdea(id: "walk", kind: .bodyBreak, title: "Walk", body: "Walk around")
        ]
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let title = try XCTUnwrap(view(withIdentifier: "prefs.customBodyTitleField", in: contentView) as? NSTextField)
        let body = try XCTUnwrap(view(withIdentifier: "customBodyTextEditor", in: contentView) as? NSTextView)
        let button = try XCTUnwrap(view(withIdentifier: "prefs.customBodyAddIdeaButton", in: contentView) as? NSButton)
        let jsonRow = try view(withIdentifier: "prefs.customBodyIdeasJSONRow", in: contentView)

        title.stringValue = "Look outside"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: title))
        body.string = "Focus on a far object."
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: body))

        XCTAssertTrue(sendAction(from: button))

        waitUntilSavedSettingsArrive(savedSettings)
        let ideas = try XCTUnwrap(savedSettings.value?.contentLibrary.customBodyBreakIdeas)
        XCTAssertEqual(ideas.map(\.title), ["Stretch", "Walk", "Look outside"])
        XCTAssertEqual(ideas[2].body, "Focus on a far object.")
        XCTAssertFalse(try view(withIdentifier: "prefs.customBodyIdeasListRow", in: contentView).isHidden)
        XCTAssertEqual(
            (try view(withIdentifier: "prefs.customBodyIdeaTitle.2", in: contentView) as? NSTextField)?.stringValue,
            "Look outside"
        )
        XCTAssertTrue(jsonRow.isHidden)
    }

    func testCustomBodyIdeaRotationListRemovesIdeasAndAutosaves() throws {
        var settings = RestSettings.defaults
        settings.contentLibrary.customBodyBreakIdeas = [
            RestIdea(id: "stretch", kind: .bodyBreak, title: "Stretch", body: "Open shoulders"),
            RestIdea(id: "walk", kind: .bodyBreak, title: "Walk", body: "Walk around")
        ]
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let listRow = try view(withIdentifier: "prefs.customBodyIdeasListRow", in: contentView)
        let removeWalk = try XCTUnwrap(view(withIdentifier: "prefs.customBodyIdeaRemove.1", in: contentView) as? NSButton)
        let jsonRow = try view(withIdentifier: "prefs.customBodyIdeasJSONRow", in: contentView)

        XCTAssertFalse(listRow.isHidden)
        XCTAssertEqual(
            (try view(withIdentifier: "prefs.customBodyIdeaTitle.0", in: contentView) as? NSTextField)?.stringValue,
            "Stretch"
        )
        XCTAssertEqual(
            (try view(withIdentifier: "prefs.customBodyIdeaTitle.1", in: contentView) as? NSTextField)?.stringValue,
            "Walk"
        )
        XCTAssertTrue(jsonRow.isHidden)

        XCTAssertTrue(sendAction(from: removeWalk))

        waitUntilSavedSettingsArrive(savedSettings)
        let ideas = try XCTUnwrap(savedSettings.value?.contentLibrary.customBodyBreakIdeas)
        XCTAssertEqual(ideas.map(\.title), ["Stretch"])
        XCTAssertTrue(listRow.isHidden)
        XCTAssertEqual(
            (try view(withIdentifier: "prefs.customBodyTitleField", in: contentView) as? NSTextField)?.stringValue,
            "Stretch"
        )
        XCTAssertTrue(jsonRow.isHidden)
    }

    func testExistingCustomBodyIdeasLoadAsNativeRotationListWithAdvancedCollapsed() throws {
        var settings = RestSettings.defaults
        settings.contentLibrary.customBodyBreakIdeas = [
            RestIdea(id: "stretch", kind: .bodyBreak, title: "Stretch", body: "Open shoulders"),
            RestIdea(id: "walk", kind: .bodyBreak, title: "Walk", body: "Walk around")
        ]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let title = try XCTUnwrap(view(withIdentifier: "prefs.customBodyTitleField", in: contentView) as? NSTextField)
        let body = try XCTUnwrap(view(withIdentifier: "customBodyTextEditor", in: contentView) as? NSTextView)
        let listRow = try view(withIdentifier: "prefs.customBodyIdeasListRow", in: contentView)
        let jsonRow = try view(withIdentifier: "prefs.customBodyIdeasJSONRow", in: contentView)

        XCTAssertEqual(title.stringValue, "")
        XCTAssertEqual(body.string, "")
        XCTAssertFalse(listRow.isHidden)
        XCTAssertTrue(jsonRow.isHidden)
        XCTAssertEqual(
            (try view(withIdentifier: "prefs.customBodyIdeaTitle.0", in: contentView) as? NSTextField)?.stringValue,
            "Stretch"
        )
        XCTAssertEqual(
            (try view(withIdentifier: "prefs.customBodyIdeaBody.1", in: contentView) as? NSTextField)?.stringValue,
            "Walk around"
        )
    }

    func testDraftingCustomIdeaDoesNotAutosaveOverExistingRotationBeforeAdd() throws {
        var settings = RestSettings.defaults
        settings.contentLibrary.customBodyBreakIdeas = [
            RestIdea(id: "stretch", kind: .bodyBreak, title: "Stretch", body: "Open shoulders"),
            RestIdea(id: "walk", kind: .bodyBreak, title: "Walk", body: "Walk around")
        ]
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let title = try XCTUnwrap(view(withIdentifier: "prefs.customBodyTitleField", in: contentView) as? NSTextField)
        let body = try XCTUnwrap(view(withIdentifier: "customBodyTextEditor", in: contentView) as? NSTextView)
        let button = try XCTUnwrap(view(withIdentifier: "prefs.customBodyAddIdeaButton", in: contentView) as? NSButton)

        title.stringValue = "Look outside"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: title))
        body.string = "Focus on a far object."
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: body))

        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        XCTAssertNil(savedSettings.value)

        XCTAssertTrue(sendAction(from: button))

        waitUntilSavedSettingsArrive(savedSettings)
        let ideas = try XCTUnwrap(savedSettings.value?.contentLibrary.customBodyBreakIdeas)
        XCTAssertEqual(ideas.map(\.title), ["Stretch", "Walk", "Look outside"])
        XCTAssertEqual(ideas[2].body, "Focus on a far object.")
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

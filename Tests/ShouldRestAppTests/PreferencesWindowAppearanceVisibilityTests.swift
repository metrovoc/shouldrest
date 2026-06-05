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

    func testAppearanceControlsExposeBehaviorHelp() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)

        let expectedHelp: [(identifier: String, helpKey: String)] = [
            ("prefs.theme", "prefs.themeHelp"),
            ("prefs.language", "prefs.languageHelp"),
            ("prefs.currentTimeBody", "prefs.currentTimeBodyHelp"),
            ("prefs.breakHealth", "prefs.breakHealthHelp"),
            ("prefs.silentNotifications", "prefs.silentNotificationsHelp"),
            ("prefs.eyeStartSound", "prefs.eyeStartSoundHelp"),
            ("prefs.eyeFinishSound", "prefs.eyeFinishSoundHelp"),
            ("prefs.bodyStartSound", "prefs.bodyStartSoundHelp"),
            ("prefs.bodyFinishSound", "prefs.bodyFinishSoundHelp"),
            ("prefs.soundVolumeSlider", "prefs.soundVolumeHelp"),
            ("prefs.useBuiltInIdeas", "prefs.useBuiltInIdeasHelp"),
            ("prefs.customBodyTitleField", "prefs.customBodyTitleHelp")
        ]

        for expectation in expectedHelp {
            let control = try XCTUnwrap(
                view(withIdentifier: expectation.identifier, in: contentView) as? NSControl,
                expectation.identifier
            )
            XCTAssertEqual(control.toolTip, L10n.tr(expectation.helpKey), expectation.identifier)
            XCTAssertEqual(control.accessibilityHelp(), L10n.tr(expectation.helpKey), expectation.identifier)
        }
        let visibleHelpTexts = visibleTexts(in: contentView)
        XCTAssertFalse(visibleHelpTexts.contains(L10n.tr("prefs.themeHelp")))
        XCTAssertFalse(visibleHelpTexts.contains(L10n.tr("prefs.languageHelp")))
        XCTAssertTrue(visibleHelpTexts.contains(L10n.tr("prefs.silentNotificationsHelp")))
        XCTAssertTrue(visibleHelpTexts.contains(L10n.tr("prefs.soundVolumeHelp")))
        try assertInlineHelp(
            "prefs.silentNotificationsInlineHelp",
            text: L10n.tr("prefs.silentNotificationsHelp"),
            in: contentView
        )
        try assertInlineHelp(
            "prefs.soundVolumeInlineHelp",
            text: L10n.tr("prefs.soundVolumeHelp"),
            in: contentView
        )

        let soundVolumeSlider = try XCTUnwrap(view(withIdentifier: "prefs.soundVolumeSlider", in: contentView) as? NSSlider)
        let soundVolumeValue = try XCTUnwrap(view(withIdentifier: "prefs.soundVolumeValue", in: contentView) as? NSTextField)
        let expectedVolumeHelp = L10n.format("prefs.soundVolumeValueHelp", "100%")
        XCTAssertEqual(soundVolumeValue.stringValue, "100%")
        XCTAssertEqual(soundVolumeValue.toolTip, expectedVolumeHelp)
        XCTAssertEqual(soundVolumeValue.accessibilityLabel(), "100%")
        XCTAssertEqual(soundVolumeValue.accessibilityHelp(), expectedVolumeHelp)
        XCTAssertEqual(soundVolumeSlider.accessibilityValue() as? String, "100%")

        let customBodyText = try XCTUnwrap(view(withIdentifier: "customBodyTextEditor", in: contentView) as? NSTextView)
        XCTAssertEqual(customBodyText.toolTip, L10n.tr("prefs.customBodyTextHelp"))
        XCTAssertEqual(customBodyText.accessibilityHelp(), L10n.tr("prefs.customBodyTextHelp"))
    }

    func testCustomBodyTextEditorUsesVisiblePlaceholderWithoutSavingItAsBodyText() throws {
        var settings = RestSettings.defaults
        settings.contentLibrary.customBodyBreakIdeas = []
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let title = try XCTUnwrap(view(withIdentifier: "prefs.customBodyTitleField", in: contentView) as? NSTextField)
        let body = try XCTUnwrap(view(withIdentifier: "customBodyTextEditor", in: contentView) as? PlaceholderTextView)
        let button = try XCTUnwrap(view(withIdentifier: "prefs.customBodyAddIdeaButton", in: contentView) as? NSButton)

        XCTAssertEqual(title.placeholderString, L10n.tr("prefs.customBodyTitlePlaceholder"))
        XCTAssertEqual(body.placeholderString, L10n.tr("prefs.customBodyTextPlaceholder"))
        XCTAssertTrue(body.isPlaceholderVisible)
        XCTAssertEqual(body.string, "")

        body.string = "Roll shoulders and breathe."
        XCTAssertFalse(body.isPlaceholderVisible)

        body.string = ""
        XCTAssertTrue(body.isPlaceholderVisible)
        title.stringValue = "Loosen neck"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: title))

        XCTAssertTrue(button.isEnabled)
        XCTAssertTrue(sendAction(from: button))

        waitUntilSavedSettingsArrive(savedSettings)
        let ideas = try XCTUnwrap(savedSettings.value?.contentLibrary.customBodyBreakIdeas)
        XCTAssertEqual(ideas.first?.title, "Loosen neck")
        XCTAssertEqual(ideas.first?.body, "")
        XCTAssertNotEqual(ideas.first?.body, L10n.tr("prefs.customBodyTextPlaceholder"))
    }

    func testRowBackedAppearanceControlsExposeReadableAccessibilityLabels() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)

        let theme = try XCTUnwrap(view(withIdentifier: "prefs.theme", in: contentView) as? NSPopUpButton)
        let language = try XCTUnwrap(view(withIdentifier: "prefs.language", in: contentView) as? NSPopUpButton)
        let eyeStartSound = try XCTUnwrap(view(withIdentifier: "prefs.eyeStartSound", in: contentView) as? NSPopUpButton)
        let eyeStartPreview = try XCTUnwrap(view(withIdentifier: "eyeStart", in: contentView) as? NSButton)
        let customTitle = try XCTUnwrap(view(withIdentifier: "prefs.customBodyTitleField", in: contentView) as? NSTextField)
        let customBodyText = try XCTUnwrap(view(withIdentifier: "customBodyTextEditor", in: contentView) as? NSTextView)

        XCTAssertEqual(theme.accessibilityLabel(), L10n.tr("prefs.theme"))
        XCTAssertEqual(language.accessibilityLabel(), L10n.tr("prefs.language"))
        XCTAssertEqual(eyeStartSound.accessibilityLabel(), L10n.tr("prefs.eyeStartSound"))
        XCTAssertEqual(
            eyeStartPreview.accessibilityLabel(),
            L10n.format("prefs.previewSoundLabel", L10n.tr("prefs.eyeStartSound"))
        )
        XCTAssertNotEqual(eyeStartPreview.accessibilityLabel(), L10n.tr("prefs.eyeStartSound"))
        XCTAssertEqual(customTitle.accessibilityLabel(), L10n.tr("prefs.title"))
        XCTAssertEqual(customBodyText.accessibilityLabel(), L10n.tr("prefs.text"))
    }

    func testSilentModeCopyMatchesSoundPreviewBehavior() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let toggle = try XCTUnwrap(view(withIdentifier: "prefs.silentNotifications", in: contentView) as? NSButton)

        XCTAssertEqual(toggle.title, "Silent mode")
        XCTAssertEqual(
            toggle.toolTip,
            "Keep notifications visible but mute notification sounds, rest sounds, and sound previews."
        )
        XCTAssertTrue(
            visibleTexts(in: contentView).contains(
                "Keep notifications visible but mute notification sounds, rest sounds, and sound previews."
            )
        )
        XCTAssertFalse(visibleTexts(in: contentView).contains("Silent notifications"))

        L10n.languageOverride = "zh-Hans"
        XCTAssertEqual(L10n.tr("prefs.silentNotifications"), "静音模式")
        XCTAssertFalse(L10n.tr("prefs.silentNotifications").contains("静默通知"))
        XCTAssertTrue(L10n.tr("prefs.silentNotificationsHelp").contains("声音试听"))
    }

    func testSoundVolumeValueHelpTracksSliderChanges() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let slider = try XCTUnwrap(view(withIdentifier: "prefs.soundVolumeSlider", in: contentView) as? NSSlider)
        let value = try XCTUnwrap(view(withIdentifier: "prefs.soundVolumeValue", in: contentView) as? NSTextField)

        slider.doubleValue = 0.35
        XCTAssertTrue(sendAction(from: slider))

        let expectedHelp = L10n.format("prefs.soundVolumeValueHelp", "35%")
        XCTAssertEqual(value.stringValue, "35%")
        XCTAssertEqual(value.toolTip, expectedHelp)
        XCTAssertEqual(value.accessibilityLabel(), "35%")
        XCTAssertEqual(value.accessibilityHelp(), expectedHelp)
        XCTAssertEqual(slider.accessibilityValue() as? String, "35%")
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
        let bodyContentSummary = try XCTUnwrap(
            view(withIdentifier: "prefs.bodyContentSummaryLabel", in: contentView) as? NSTextField
        )
        XCTAssertTrue(bodyContentSummary.isHidden)
        XCTAssertEqual(bodyContentSummary.stringValue, "")
        XCTAssertNil(bodyContentSummary.accessibilityLabel())
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
        XCTAssertFalse(try view(withIdentifier: "prefs.bodyContentSummaryLabel", in: contentView).isHidden)
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

    func testBodyContentSummaryExplainsDefaultBuiltInIdeas() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let summary = try XCTUnwrap(view(withIdentifier: "prefs.bodyContentSummaryLabel", in: contentView) as? NSTextField)

        XCTAssertFalse(summary.isHidden)
        XCTAssertEqual(summary.stringValue, "Body Breaks rotate through built-in ideas.")
        XCTAssertEqual(summary.toolTip, summary.stringValue)
        XCTAssertEqual(summary.accessibilityLabel(), summary.stringValue)
        XCTAssertEqual(summary.accessibilityHelp(), summary.stringValue)
    }

    func testBodyContentSummaryTracksBuiltInToggleAndDraftCustomIdea() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        var settings = RestSettings.defaults
        settings.contentLibrary.customBodyBreakIdeas = []
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let builtIns = try XCTUnwrap(view(withIdentifier: "prefs.useBuiltInIdeas", in: contentView) as? NSButton)
        let title = try XCTUnwrap(view(withIdentifier: "prefs.customBodyTitleField", in: contentView) as? NSTextField)
        let body = try XCTUnwrap(view(withIdentifier: "customBodyTextEditor", in: contentView) as? NSTextView)
        let summary = try XCTUnwrap(view(withIdentifier: "prefs.bodyContentSummaryLabel", in: contentView) as? NSTextField)

        builtIns.state = .off
        XCTAssertTrue(sendAction(from: builtIns))
        XCTAssertEqual(
            summary.stringValue,
            "No ideas are enabled; Body Breaks use the default standing prompt."
        )
        XCTAssertEqual(summary.accessibilityLabel(), summary.stringValue)

        title.stringValue = "Loosen neck"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: title))
        body.string = "Roll shoulders and breathe."
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: body))

        XCTAssertEqual(summary.stringValue, "Body Breaks rotate through 1 custom idea.")
        XCTAssertEqual(summary.accessibilityLabel(), summary.stringValue)
    }

    func testBodyContentSummaryTracksExistingCustomIdeasAndImage() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        var settings = RestSettings.defaults
        settings.contentLibrary.customBodyBreakIdeas = [
            RestIdea(id: "stretch", kind: .bodyBreak, title: "Stretch", body: "Open shoulders"),
            RestIdea(id: "walk", kind: .bodyBreak, title: "Walk", body: "Walk around")
        ]
        settings.contentLibrary.localImagePaths = ["/tmp/shouldrest-break.png"]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let summary = try XCTUnwrap(view(withIdentifier: "prefs.bodyContentSummaryLabel", in: contentView) as? NSTextField)

        XCTAssertEqual(
            summary.stringValue,
            "Body Breaks rotate through built-in ideas plus 2 custom ideas. Image: shouldrest-break.png."
        )
        XCTAssertEqual(summary.accessibilityLabel(), summary.stringValue)
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
        XCTAssertEqual(button.toolTip, L10n.tr("prefs.addCustomIdeaDisabledEmptyHelp"))
        XCTAssertEqual(button.accessibilityLabel(), L10n.tr("prefs.addCustomIdea"))
        XCTAssertEqual(button.accessibilityHelp(), L10n.tr("prefs.addCustomIdeaDisabledEmptyHelp"))
        XCTAssertEqual(button.image?.accessibilityDescription, L10n.tr("prefs.addCustomIdea"))
        XCTAssertNotNil(button.image)

        title.stringValue = "Loosen neck"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: title))
        body.string = "Roll shoulders and breathe."
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: body))

        XCTAssertTrue(button.isEnabled)
        XCTAssertEqual(button.toolTip, L10n.tr("prefs.addCustomIdeaHelp"))
        XCTAssertEqual(button.accessibilityHelp(), L10n.tr("prefs.addCustomIdeaHelp"))
        XCTAssertTrue(sendAction(from: button))

        waitUntilSavedSettingsArrive(savedSettings)
        let ideas = try XCTUnwrap(savedSettings.value?.contentLibrary.customBodyBreakIdeas)
        XCTAssertEqual(ideas.count, 1)
        XCTAssertEqual(ideas[0].title, "Loosen neck")
        XCTAssertEqual(ideas[0].body, "Roll shoulders and breathe.")
        try assertAutosaveStatus("prefs.autosaveCustomIdeaAdded", in: contentView)
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
        XCTAssertEqual(removeButton.accessibilityLabel(), L10n.tr("prefs.removeCustomIdea"))
        XCTAssertEqual(removeButton.accessibilityHelp(), L10n.tr("prefs.removeCustomIdeaHelp"))
        XCTAssertEqual(removeButton.image?.accessibilityDescription, L10n.tr("prefs.removeCustomIdea"))
        XCTAssertTrue(jsonRow.isHidden)
        XCTAssertFalse(button.isEnabled)
    }

    func testBodyOnlyCustomIdeaUsesLocalizedDefaultTitle() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "zh-Hans"

        var settings = RestSettings.defaults
        settings.contentLibrary.customBodyBreakIdeas = []
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let title = try XCTUnwrap(view(withIdentifier: "prefs.customBodyTitleField", in: contentView) as? NSTextField)
        let body = try XCTUnwrap(view(withIdentifier: "customBodyTextEditor", in: contentView) as? NSTextView)
        let button = try XCTUnwrap(view(withIdentifier: "prefs.customBodyAddIdeaButton", in: contentView) as? NSButton)

        XCTAssertEqual(title.placeholderString, L10n.tr("prefs.customBodyTitlePlaceholder"))
        body.string = "转动肩膀，放松呼吸。"
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: body))

        XCTAssertTrue(button.isEnabled)
        XCTAssertTrue(sendAction(from: button))

        waitUntilSavedSettingsArrive(savedSettings)
        let ideas = try XCTUnwrap(savedSettings.value?.contentLibrary.customBodyBreakIdeas)
        XCTAssertEqual(ideas.first?.title, L10n.tr("prefs.defaultCustomIdeaTitle"))
        XCTAssertNotEqual(ideas.first?.title, L10n.tr("prefs.customBodyTitlePlaceholder"))
        XCTAssertFalse(ideas.first?.title.contains("Custom Body Break") ?? true)
        XCTAssertEqual(
            (try view(withIdentifier: "prefs.customBodyIdeaTitle.0", in: contentView) as? NSTextField)?.stringValue,
            L10n.tr("prefs.defaultCustomIdeaTitle")
        )
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

        XCTAssertNil(savedSettings.value)
        XCTAssertEqual(removeWalk.toolTip, L10n.tr("prefs.removeCustomIdeaConfirmHelp"))
        XCTAssertEqual(removeWalk.accessibilityLabel(), L10n.tr("prefs.confirmRemoveCustomIdea"))
        XCTAssertEqual(removeWalk.accessibilityHelp(), L10n.tr("prefs.removeCustomIdeaConfirmHelp"))
        XCTAssertEqual(removeWalk.image?.accessibilityDescription, L10n.tr("prefs.confirmRemoveCustomIdea"))
        let armedTint = try XCTUnwrap(removeWalk.contentTintColor?.usingColorSpace(.sRGB))
        XCTAssertGreaterThan(armedTint.redComponent, armedTint.greenComponent)
        XCTAssertGreaterThan(armedTint.redComponent, armedTint.blueComponent)

        XCTAssertTrue(sendAction(from: removeWalk))

        waitUntilSavedSettingsArrive(savedSettings)
        let ideas = try XCTUnwrap(savedSettings.value?.contentLibrary.customBodyBreakIdeas)
        XCTAssertEqual(ideas.map(\.title), ["Stretch"])
        try assertAutosaveStatus("prefs.autosaveCustomIdeaRemoved", in: contentView)
        XCTAssertTrue(listRow.isHidden)
        XCTAssertEqual(
            (try view(withIdentifier: "prefs.customBodyTitleField", in: contentView) as? NSTextField)?.stringValue,
            "Stretch"
        )
        XCTAssertTrue(jsonRow.isHidden)
    }

    func testCustomBodyIdeaRotationListEditsExistingIdeaAndAutosavesOnUpdateOnly() throws {
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
        let actionButton = try XCTUnwrap(view(withIdentifier: "prefs.customBodyAddIdeaButton", in: contentView) as? NSButton)
        let cancelButton = try XCTUnwrap(view(withIdentifier: "prefs.customBodyCancelEditButton", in: contentView) as? NSButton)
        let editWalk = try XCTUnwrap(view(withIdentifier: "prefs.customBodyIdeaEdit.1", in: contentView) as? NSButton)
        let jsonRow = try view(withIdentifier: "prefs.customBodyIdeasJSONRow", in: contentView)

        XCTAssertTrue(cancelButton.isHidden)
        XCTAssertEqual(actionButton.title, L10n.tr("prefs.addCustomIdea"))
        XCTAssertEqual(actionButton.toolTip, L10n.tr("prefs.addCustomIdeaDisabledEmptyHelp"))
        XCTAssertEqual(actionButton.accessibilityLabel(), L10n.tr("prefs.addCustomIdea"))
        XCTAssertEqual(actionButton.accessibilityHelp(), L10n.tr("prefs.addCustomIdeaDisabledEmptyHelp"))
        XCTAssertEqual(actionButton.image?.accessibilityDescription, L10n.tr("prefs.addCustomIdea"))
        XCTAssertEqual(cancelButton.accessibilityLabel(), L10n.tr("prefs.cancelCustomIdeaEdit"))
        XCTAssertEqual(cancelButton.accessibilityHelp(), L10n.tr("prefs.cancelCustomIdeaEditHelp"))
        XCTAssertEqual(cancelButton.image?.accessibilityDescription, L10n.tr("prefs.cancelCustomIdeaEdit"))
        XCTAssertGreaterThanOrEqual(
            cancelButton.constraints.first { $0.firstAttribute == .width }?.constant ?? 0,
            126
        )
        XCTAssertEqual(editWalk.toolTip, L10n.tr("prefs.editCustomIdeaHelp"))
        XCTAssertEqual(editWalk.accessibilityLabel(), L10n.tr("prefs.editCustomIdea"))
        XCTAssertEqual(editWalk.accessibilityHelp(), L10n.tr("prefs.editCustomIdeaHelp"))
        XCTAssertEqual(editWalk.image?.accessibilityDescription, L10n.tr("prefs.editCustomIdea"))

        XCTAssertTrue(sendAction(from: editWalk))

        XCTAssertEqual(title.stringValue, "Walk")
        XCTAssertEqual(body.string, "Walk around")
        XCTAssertFalse(cancelButton.isHidden)
        XCTAssertEqual(actionButton.title, L10n.tr("prefs.updateCustomIdea"))
        XCTAssertEqual(actionButton.toolTip, L10n.tr("prefs.updateCustomIdeaHelp"))
        XCTAssertEqual(actionButton.accessibilityLabel(), L10n.tr("prefs.updateCustomIdea"))
        XCTAssertEqual(actionButton.accessibilityHelp(), L10n.tr("prefs.updateCustomIdeaHelp"))
        XCTAssertEqual(actionButton.image?.accessibilityDescription, L10n.tr("prefs.updateCustomIdea"))

        title.stringValue = "Look outside"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: title))
        body.string = "Focus on a far object."
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: body))

        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        XCTAssertNil(savedSettings.value)

        XCTAssertTrue(sendAction(from: actionButton))

        waitUntilSavedSettingsArrive(savedSettings)
        let ideas = try XCTUnwrap(savedSettings.value?.contentLibrary.customBodyBreakIdeas)
        XCTAssertEqual(ideas.map(\.id), ["stretch", "walk"])
        XCTAssertEqual(ideas.map(\.title), ["Stretch", "Look outside"])
        XCTAssertEqual(ideas[1].body, "Focus on a far object.")
        try assertAutosaveStatus("prefs.autosaveCustomIdeaUpdated", in: contentView)
        XCTAssertEqual(title.stringValue, "")
        XCTAssertEqual(body.string, "")
        XCTAssertTrue(cancelButton.isHidden)
        XCTAssertEqual(actionButton.title, L10n.tr("prefs.addCustomIdea"))
        XCTAssertEqual(actionButton.accessibilityLabel(), L10n.tr("prefs.addCustomIdea"))
        XCTAssertEqual(actionButton.accessibilityHelp(), L10n.tr("prefs.addCustomIdeaDisabledEmptyHelp"))
        XCTAssertEqual(actionButton.image?.accessibilityDescription, L10n.tr("prefs.addCustomIdea"))
        XCTAssertEqual(
            (try view(withIdentifier: "prefs.customBodyIdeaTitle.1", in: contentView) as? NSTextField)?.stringValue,
            "Look outside"
        )
        XCTAssertTrue(jsonRow.isHidden)
    }

    func testCustomBodyIdeaEditCancelClearsDraftWithoutAutosaving() throws {
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
        let actionButton = try XCTUnwrap(view(withIdentifier: "prefs.customBodyAddIdeaButton", in: contentView) as? NSButton)
        let cancelButton = try XCTUnwrap(view(withIdentifier: "prefs.customBodyCancelEditButton", in: contentView) as? NSButton)
        let editStretch = try XCTUnwrap(view(withIdentifier: "prefs.customBodyIdeaEdit.0", in: contentView) as? NSButton)

        XCTAssertTrue(sendAction(from: editStretch))

        title.stringValue = "Changed"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: title))
        body.string = "Changed body"
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: body))

        XCTAssertTrue(sendAction(from: cancelButton))

        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        XCTAssertNil(savedSettings.value)
        XCTAssertEqual(title.stringValue, "")
        XCTAssertEqual(body.string, "")
        XCTAssertTrue(cancelButton.isHidden)
        XCTAssertEqual(actionButton.title, L10n.tr("prefs.addCustomIdea"))
        XCTAssertEqual(
            (try view(withIdentifier: "prefs.customBodyIdeaTitle.0", in: contentView) as? NSTextField)?.stringValue,
            "Stretch"
        )
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

    func testCustomBodyIdeaRowsUseScannableListItemPresentation() throws {
        var settings = RestSettings.defaults
        settings.contentLibrary.customBodyBreakIdeas = [
            RestIdea(id: "stretch", kind: .bodyBreak, title: "Stretch", body: "Open shoulders")
        ]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)

        let row = try XCTUnwrap(view(withIdentifier: "prefs.customBodyIdeaRow.0", in: contentView) as? NSStackView)
        let title = try XCTUnwrap(view(withIdentifier: "prefs.customBodyIdeaTitle.0", in: contentView) as? NSTextField)
        let body = try XCTUnwrap(view(withIdentifier: "prefs.customBodyIdeaBody.0", in: contentView) as? NSTextField)

        XCTAssertTrue(row.wantsLayer)
        XCTAssertEqual(row.edgeInsets.top, 6)
        XCTAssertEqual(row.edgeInsets.left, 8)
        XCTAssertLessThanOrEqual(row.layer?.cornerRadius ?? 99, 8)
        XCTAssertEqual(row.layer?.borderWidth, 1)
        XCTAssertNotNil(row.layer?.backgroundColor)
        XCTAssertNotNil(row.layer?.borderColor)
        XCTAssertGreaterThanOrEqual(row.constraints.first { $0.firstAttribute == .width }?.constant ?? 0, 360)
        XCTAssertGreaterThanOrEqual(row.constraints.first { $0.firstAttribute == .height }?.constant ?? 0, 52)
        XCTAssertLessThanOrEqual(title.constraints.first { $0.firstAttribute == .width }?.constant ?? 999, 284)
        XCTAssertLessThanOrEqual(body.constraints.first { $0.firstAttribute == .width }?.constant ?? 999, 284)
        XCTAssertEqual(row.toolTip, "\(title.stringValue). \(body.stringValue)")
        XCTAssertEqual(row.accessibilityHelp(), row.toolTip)
    }

    func testBlankExistingCustomIdeaTitleUsesLocalizedDefaultTitle() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "zh-Hans"

        var settings = RestSettings.defaults
        settings.contentLibrary.customBodyBreakIdeas = [
            RestIdea(id: "body-only", kind: .bodyBreak, title: " ", body: "转动肩膀。")
        ]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)

        XCTAssertEqual(
            (try view(withIdentifier: "prefs.customBodyIdeaTitle.0", in: contentView) as? NSTextField)?.stringValue,
            L10n.tr("prefs.defaultCustomIdeaTitle")
        )
        XCTAssertFalse(visibleTexts(in: contentView).contains("Custom Body Break"))
    }

    func testCustomBodyIdeaSummariesUseSingleCharacterEllipsisWhenTruncated() throws {
        let longBody = String(repeating: "slow shoulder roll ", count: 8)
        var settings = RestSettings.defaults
        settings.contentLibrary.customBodyBreakIdeas = [
            RestIdea(id: "long", kind: .bodyBreak, title: "Long idea", body: longBody)
        ]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let body = try XCTUnwrap(view(withIdentifier: "prefs.customBodyIdeaBody.0", in: contentView) as? NSTextField)

        XCTAssertTrue(body.stringValue.hasSuffix("…"))
        XCTAssertFalse(body.stringValue.contains("..."))
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

    private func assertInlineHelp(_ identifier: String, text: String, in rootView: NSView) throws {
        let label = try XCTUnwrap(view(withIdentifier: identifier, in: rootView) as? NSTextField)
        XCTAssertFalse(label.isHidden)
        XCTAssertEqual(label.stringValue, text)
        XCTAssertEqual(label.toolTip, text)
        XCTAssertEqual(label.accessibilityLabel(), text)
        XCTAssertEqual(label.accessibilityHelp(), text)
        XCTAssertEqual(label.maximumNumberOfLines, 2)
        XCTAssertEqual(label.lineBreakMode, .byWordWrapping)

        let row = try view(withIdentifier: "\(identifier)Row", in: rootView)
        XCTAssertFalse(row.isHidden)
        XCTAssertEqual(row.toolTip, text)
        XCTAssertEqual(row.accessibilityHelp(), text)
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

    private func assertAutosaveStatus(
        _ key: String,
        in rootView: NSView,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let text = L10n.tr(key)
        let label = try XCTUnwrap(
            view(withIdentifier: "autosaveStatusLabel", in: rootView) as? NSTextField,
            file: file,
            line: line
        )
        let icon = try XCTUnwrap(
            view(withIdentifier: "autosaveStatusIcon", in: rootView) as? NSImageView,
            file: file,
            line: line
        )

        XCTAssertEqual(label.stringValue, text, file: file, line: line)
        XCTAssertEqual(label.toolTip, text, file: file, line: line)
        XCTAssertEqual(label.accessibilityHelp(), text, file: file, line: line)
        XCTAssertEqual(icon.image?.accessibilityDescription, text, file: file, line: line)
        XCTAssertEqual(icon.accessibilityHelp(), text, file: file, line: line)
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

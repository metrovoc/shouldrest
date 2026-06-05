import AppKit
import Carbon
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

    func testPreferencesOpenWithSafeSearchFocusInsteadOfEditableScheduleField() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)
        let searchField = try XCTUnwrap(view(withIdentifier: "prefs.searchField", in: contentView) as? NSSearchField)
        let eyeInterval = try XCTUnwrap(view(withIdentifier: "eyeIntervalField", in: contentView) as? NSTextField)

        XCTAssertTrue(isFirstResponder(searchField, in: window))
        XCTAssertFalse(isFirstResponder(eyeInterval, in: window))
        XCTAssertEqual(searchField.stringValue, "")
    }

    func testEscapeOnInitialEmptySearchFocusOnlyResignsSearchFocus() throws {
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)
        let searchField = try XCTUnwrap(view(withIdentifier: "prefs.searchField", in: contentView) as? NSSearchField)

        XCTAssertTrue(isFirstResponder(searchField, in: window))

        window.cancelOperation(nil)

        XCTAssertFalse(isFirstResponder(searchField, in: window))
        XCTAssertEqual(searchField.stringValue, "")
        XCTAssertNil(savedSettings.value)
    }

    func testPreferenceSearchJumpsToMatchingSettingWithoutAutosave() throws {
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let tabView = try XCTUnwrap(view(withIdentifier: "prefs.tabView", in: contentView) as? NSTabView)
        let searchField = try XCTUnwrap(view(withIdentifier: "prefs.searchField", in: contentView) as? NSSearchField)
        let searchStatus = try XCTUnwrap(view(withIdentifier: "prefs.searchStatusLabel", in: contentView) as? NSTextField)
        let saveStatus = try XCTUnwrap(view(withIdentifier: "autosaveStatusLabel", in: contentView) as? NSTextField)

        XCTAssertEqual(searchField.placeholderString, L10n.tr("prefs.searchPlaceholder"))
        XCTAssertEqual(searchField.toolTip, L10n.tr("prefs.searchHelp"))
        XCTAssertEqual(searchField.accessibilityLabel(), L10n.tr("prefs.searchPlaceholder"))
        XCTAssertEqual(searchField.accessibilityHelp(), L10n.tr("prefs.searchHelp"))
        XCTAssertTrue(searchField.sendsSearchStringImmediately)
        XCTAssertFalse(searchField.sendsWholeSearchString)
        searchField.stringValue = L10n.tr("prefs.pause5hShortcut")

        XCTAssertTrue(sendAction(from: searchField))

        XCTAssertEqual(tabView.selectedTabViewItem?.identifier as? String, L10n.tr("prefs.tabShortcuts"))
        XCTAssertFalse(searchStatus.isHidden)
        XCTAssertTrue(searchStatus.stringValue.contains(L10n.tr("prefs.tabShortcuts")))
        XCTAssertTrue(searchStatus.stringValue.contains(L10n.tr("prefs.pause5hShortcut")))
        XCTAssertEqual(searchStatus.toolTip, searchStatus.stringValue)
        XCTAssertEqual(searchStatus.accessibilityLabel(), searchStatus.stringValue)
        XCTAssertEqual(searchStatus.accessibilityHelp(), searchStatus.stringValue)

        let pause5h = try XCTUnwrap(view(withIdentifier: "shortcut.pause5h", in: contentView))
        let pause5hRecorder = try XCTUnwrap(pause5h as? ShortcutRecorderButton)
        let highlightedRow = try XCTUnwrap(highlightedAncestor(of: pause5h))
        XCTAssertEqual(highlightedRow.layer?.borderWidth, 1)
        XCTAssertNotNil(highlightedRow.layer?.backgroundColor)
        XCTAssertEqual(highlightedRow.toolTip, searchStatus.stringValue)
        XCTAssertEqual(highlightedRow.accessibilityLabel(), searchStatus.stringValue)
        XCTAssertEqual(highlightedRow.accessibilityHelp(), searchStatus.stringValue)
        XCTAssertTrue(isFirstResponder(searchField, in: window))
        XCTAssertFalse(isFirstResponder(pause5hRecorder, in: window))
        XCTAssertNotEqual(pause5hRecorder.title, L10n.tr("shortcut.recording"))
        XCTAssertEqual(saveStatus.stringValue, L10n.tr("prefs.autosaveReady"))
        XCTAssertNil(savedSettings.value)
    }

    func testPreferenceSearchHeaderUsesReadableFlexibleWidth() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let searchField = try XCTUnwrap(view(withIdentifier: "prefs.searchField", in: contentView) as? NSSearchField)
        let searchStatus = try XCTUnwrap(view(withIdentifier: "prefs.searchStatusLabel", in: contentView) as? NSTextField)
        let constraints = allConstraints(in: contentView)

        XCTAssertTrue(constraints.contains {
            $0.firstItem === searchField &&
                $0.firstAttribute == .width &&
                $0.relation == .greaterThanOrEqual &&
                $0.secondItem == nil &&
                $0.constant == 240
        })
        XCTAssertTrue(constraints.contains {
            $0.firstItem === searchField &&
                $0.firstAttribute == .width &&
                $0.relation == .lessThanOrEqual &&
                $0.secondItem == nil &&
                $0.constant == 320
        })
        XCTAssertTrue(constraints.contains {
            (($0.firstItem === searchStatus && $0.secondItem === searchField) ||
                ($0.firstItem === searchField && $0.secondItem === searchStatus)) &&
                $0.firstAttribute == .width &&
                $0.secondAttribute == .width &&
                $0.relation == .equal
        })
    }

    func testPreferenceSearchHighlightsMatchedTextFieldWithoutStealingFocusOrAutosave() throws {
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)
        let tabView = try XCTUnwrap(view(withIdentifier: "prefs.tabView", in: contentView) as? NSTabView)
        let searchField = try XCTUnwrap(view(withIdentifier: "prefs.searchField", in: contentView) as? NSSearchField)

        searchField.stringValue = L10n.tr("prefs.updateFeedURL")

        XCTAssertTrue(sendAction(from: searchField))

        let updateFeedURL = try XCTUnwrap(view(withIdentifier: "prefs.updateFeedURLField", in: contentView) as? NSTextField)
        XCTAssertEqual(tabView.selectedTabViewItem?.identifier as? String, L10n.tr("prefs.tabAdvanced"))
        XCTAssertTrue(isFirstResponder(searchField, in: window))
        XCTAssertFalse(isFirstResponder(updateFeedURL, in: window))
        XCTAssertNil(savedSettings.value)
    }

    func testPreferenceSearchMatchesHelpTextForEmergencyExit() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)
        let tabView = try XCTUnwrap(view(withIdentifier: "prefs.tabView", in: contentView) as? NSTabView)
        let searchField = try XCTUnwrap(view(withIdentifier: "prefs.searchField", in: contentView) as? NSSearchField)
        let searchStatus = try XCTUnwrap(view(withIdentifier: "prefs.searchStatusLabel", in: contentView) as? NSTextField)

        searchField.stringValue = "second click"

        XCTAssertTrue(sendAction(from: searchField))

        let emergency = try XCTUnwrap(view(withIdentifier: "prefs.eyeEmergencyOverride", in: contentView) as? NSButton)
        XCTAssertEqual(tabView.selectedTabViewItem?.identifier as? String, L10n.tr("prefs.tabSchedule"))
        XCTAssertTrue(searchStatus.stringValue.contains(L10n.tr("prefs.eyeEmergencyOverride")))
        XCTAssertEqual(emergency.layer?.borderWidth, 1)
        XCTAssertTrue(isFirstResponder(searchField, in: window))
        XCTAssertFalse(isFirstResponder(emergency, in: window))
        XCTAssertNil(savedSettings.value)
    }

    func testPreferenceSearchMatchesPopupMenuOptionsThatAreNotSelected() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)
        let tabView = try XCTUnwrap(view(withIdentifier: "prefs.tabView", in: contentView) as? NSTabView)
        let searchField = try XCTUnwrap(view(withIdentifier: "prefs.searchField", in: contentView) as? NSSearchField)
        let searchStatus = try XCTUnwrap(view(withIdentifier: "prefs.searchStatusLabel", in: contentView) as? NSTextField)

        searchField.stringValue = L10n.tr("prefs.theme.dark")

        XCTAssertTrue(sendAction(from: searchField))

        let theme = try XCTUnwrap(firstPopup(withSelectedTitle: L10n.tr("prefs.theme.system"), in: contentView))
        XCTAssertEqual(tabView.selectedTabViewItem?.identifier as? String, L10n.tr("prefs.tabAppearance"))
        XCTAssertTrue(searchStatus.stringValue.contains(L10n.tr("prefs.theme")))
        XCTAssertEqual(theme.title, L10n.tr("prefs.theme.system"))
        XCTAssertTrue(isFirstResponder(searchField, in: window))
        XCTAssertFalse(isFirstResponder(theme, in: window))
        XCTAssertNil(savedSettings.value)
    }

    func testPreferenceSearchFindsImportEditorsByImportQueryWithoutJSONTerminology() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        var settings = RestSettings.defaults
        settings.appExclusions = [
            AppExclusionRule(
                id: "calls",
                name: "Calls",
                matchTerms: ["zoom"],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: true
            )
        ]
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)
        let tabView = try XCTUnwrap(view(withIdentifier: "prefs.tabView", in: contentView) as? NSTabView)
        let searchField = try XCTUnwrap(view(withIdentifier: "prefs.searchField", in: contentView) as? NSSearchField)
        let searchStatus = try XCTUnwrap(view(withIdentifier: "prefs.searchStatusLabel", in: contentView) as? NSTextField)

        searchField.stringValue = "import app rules"

        XCTAssertTrue(sendAction(from: searchField))

        let bulkRules = try XCTUnwrap(view(withIdentifier: "appExclusions", in: contentView) as? NSButton)
        let bulkRulesRow = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionsJSONRow", in: contentView))
        XCTAssertEqual(tabView.selectedTabViewItem?.identifier as? String, L10n.tr("prefs.tabContext"))
        XCTAssertFalse(bulkRulesRow.isHidden)
        XCTAssertEqual(bulkRules.title, L10n.tr("prefs.hideAdvancedRules"))
        XCTAssertTrue(searchStatus.stringValue.contains(L10n.tr("prefs.advancedRulesJSON")))
        XCTAssertTrue(isFirstResponder(searchField, in: window))
        XCTAssertFalse(isFirstResponder(bulkRules, in: window))
        XCTAssertNil(savedSettings.value)

        searchField.stringValue = "json"

        XCTAssertTrue(sendAction(from: searchField))
        XCTAssertEqual(searchStatus.stringValue, L10n.format("prefs.searchNoResults", "json"))
        XCTAssertEqual(searchStatus.toolTip, searchStatus.stringValue)
        XCTAssertEqual(searchStatus.accessibilityLabel(), searchStatus.stringValue)
        XCTAssertEqual(searchStatus.accessibilityHelp(), searchStatus.stringValue)
        XCTAssertNil(savedSettings.value)
    }

    func testPreferenceSearchExpandsCustomIdeaImportEditor() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)
        let tabView = try XCTUnwrap(view(withIdentifier: "prefs.tabView", in: contentView) as? NSTabView)
        let searchField = try XCTUnwrap(view(withIdentifier: "prefs.searchField", in: contentView) as? NSSearchField)
        let searchStatus = try XCTUnwrap(view(withIdentifier: "prefs.searchStatusLabel", in: contentView) as? NSTextField)

        searchField.stringValue = "import ideas"

        XCTAssertTrue(sendAction(from: searchField))

        let ideasButton = try XCTUnwrap(view(withIdentifier: "customIdeas", in: contentView) as? NSButton)
        let ideasRow = try XCTUnwrap(view(withIdentifier: "prefs.customBodyIdeasJSONRow", in: contentView))
        XCTAssertEqual(tabView.selectedTabViewItem?.identifier as? String, L10n.tr("prefs.tabAppearance"))
        XCTAssertFalse(ideasRow.isHidden)
        XCTAssertEqual(ideasButton.title, L10n.tr("prefs.hideAdvancedIdeas"))
        XCTAssertTrue(searchStatus.stringValue.contains(L10n.tr("prefs.advancedIdeasJSON")))
        XCTAssertTrue(isFirstResponder(searchField, in: window))
        XCTAssertFalse(isFirstResponder(ideasButton, in: window))
        XCTAssertNil(savedSettings.value)
    }

    func testPreferenceSearchExpandsAdminControls() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)
        let tabView = try XCTUnwrap(view(withIdentifier: "prefs.tabView", in: contentView) as? NSTabView)
        let searchField = try XCTUnwrap(view(withIdentifier: "prefs.searchField", in: contentView) as? NSSearchField)
        let searchStatus = try XCTUnwrap(view(withIdentifier: "prefs.searchStatusLabel", in: contentView) as? NSTextField)

        searchField.stringValue = "hide update"

        XCTAssertTrue(sendAction(from: searchField))

        let adminButton = try XCTUnwrap(view(withIdentifier: "adminControls", in: contentView) as? NSButton)
        let updateControl = try XCTUnwrap(view(withIdentifier: "prefs.adminHideUpdates", in: contentView) as? NSButton)
        XCTAssertEqual(tabView.selectedTabViewItem?.identifier as? String, L10n.tr("prefs.tabAdvanced"))
        XCTAssertFalse(updateControl.isHidden)
        XCTAssertEqual(adminButton.title, L10n.tr("prefs.hideAdminControls"))
        XCTAssertTrue(searchStatus.stringValue.contains(L10n.tr("prefs.adminHideUpdates")))
        XCTAssertTrue(isFirstResponder(searchField, in: window))
        XCTAssertFalse(isFirstResponder(adminButton, in: window))
        XCTAssertNil(savedSettings.value)
    }

    func testPreferenceSearchExpandsCustomUpdateSource() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)
        let tabView = try XCTUnwrap(view(withIdentifier: "prefs.tabView", in: contentView) as? NSTabView)
        let searchField = try XCTUnwrap(view(withIdentifier: "prefs.searchField", in: contentView) as? NSSearchField)
        let searchStatus = try XCTUnwrap(view(withIdentifier: "prefs.searchStatusLabel", in: contentView) as? NSTextField)

        searchField.stringValue = "release location"

        XCTAssertTrue(sendAction(from: searchField))

        let disclosure = try XCTUnwrap(view(withIdentifier: "updateSource", in: contentView) as? NSButton)
        let row = try XCTUnwrap(view(withIdentifier: "prefs.updateFeedURLRow", in: contentView))
        XCTAssertEqual(tabView.selectedTabViewItem?.identifier as? String, L10n.tr("prefs.tabAdvanced"))
        XCTAssertFalse(row.isHidden)
        XCTAssertEqual(disclosure.title, L10n.tr("prefs.hideUpdateSource"))
        XCTAssertTrue(searchStatus.stringValue.contains(L10n.tr("prefs.updateFeedURL")))
        XCTAssertTrue(isFirstResponder(searchField, in: window))
        XCTAssertFalse(isFirstResponder(disclosure, in: window))
        XCTAssertNil(savedSettings.value)
    }

    func testReturnInPreferenceSearchCyclesToNextVisibleMatchWithoutAutosave() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let tabView = try XCTUnwrap(view(withIdentifier: "prefs.tabView", in: contentView) as? NSTabView)
        let searchField = try XCTUnwrap(view(withIdentifier: "prefs.searchField", in: contentView) as? NSSearchField)
        let searchStatus = try XCTUnwrap(view(withIdentifier: "prefs.searchStatusLabel", in: contentView) as? NSTextField)

        searchField.stringValue = "start sound"

        XCTAssertTrue(sendAction(from: searchField))

        XCTAssertEqual(tabView.selectedTabViewItem?.identifier as? String, L10n.tr("prefs.tabAppearance"))
        let firstRow = try XCTUnwrap(view(withIdentifier: "prefs.eyeStartSoundRow", in: contentView))
        let secondRow = try XCTUnwrap(view(withIdentifier: "prefs.bodyStartSoundRow", in: contentView))
        XCTAssertEqual(firstRow.layer?.borderWidth, 1)
        XCTAssertTrue(searchStatus.stringValue.hasPrefix("1/2"))
        XCTAssertTrue(searchStatus.stringValue.contains(L10n.tr("prefs.eyeStartSound")))

        XCTAssertTrue(controller.control(
            searchField,
            textView: NSTextView(),
            doCommandBy: #selector(NSResponder.insertNewline(_:))
        ))

        XCTAssertEqual(secondRow.layer?.borderWidth, 1)
        XCTAssertNotEqual(firstRow.layer?.borderWidth, 1)
        XCTAssertTrue(searchStatus.stringValue.hasPrefix("2/2"))
        XCTAssertTrue(searchStatus.stringValue.contains(L10n.tr("prefs.bodyStartSound")))
        XCTAssertTrue(isFirstResponder(searchField, in: try XCTUnwrap(controller.window)))
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
        XCTAssertEqual(
            searchStatus.stringValue,
            L10n.format("prefs.searchNoResults", "setting-that-does-not-exist")
        )
        XCTAssertEqual(searchStatus.textColor, .systemOrange)
        XCTAssertEqual(searchStatus.toolTip, searchStatus.stringValue)
        XCTAssertEqual(searchStatus.accessibilityLabel(), searchStatus.stringValue)
        XCTAssertEqual(searchStatus.accessibilityHelp(), searchStatus.stringValue)
    }

    func testPreferenceSearchIgnoresCurrentlyHiddenSettings() throws {
        var settings = RestSettings.defaults
        settings.bodyBreak.isEnabled = false
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let tabView = try XCTUnwrap(view(withIdentifier: "prefs.tabView", in: contentView) as? NSTabView)
        let searchField = try XCTUnwrap(view(withIdentifier: "prefs.searchField", in: contentView) as? NSSearchField)
        let searchStatus = try XCTUnwrap(view(withIdentifier: "prefs.searchStatusLabel", in: contentView) as? NSTextField)
        let hiddenRow = try XCTUnwrap(view(withIdentifier: "prefs.bodyPostponeLimitRow", in: contentView))

        tabView.selectTabViewItem(withIdentifier: L10n.tr("prefs.tabAppearance"))
        let originalSelection = tabView.selectedTabViewItem?.identifier as? String
        XCTAssertTrue(hiddenRow.isHidden)

        searchField.stringValue = L10n.tr("prefs.maxPostpones")

        XCTAssertTrue(sendAction(from: searchField))

        XCTAssertEqual(tabView.selectedTabViewItem?.identifier as? String, originalSelection)
        XCTAssertFalse(searchStatus.isHidden)
        XCTAssertEqual(
            searchStatus.stringValue,
            L10n.format("prefs.searchHiddenResults", L10n.tr("prefs.maxPostpones"))
        )
        XCTAssertEqual(searchStatus.textColor, .systemOrange)
        XCTAssertEqual(searchStatus.toolTip, searchStatus.stringValue)
        XCTAssertEqual(searchStatus.accessibilityLabel(), searchStatus.stringValue)
        XCTAssertEqual(searchStatus.accessibilityHelp(), searchStatus.stringValue)
        XCTAssertNil(savedSettings.value)
    }

    func testCommandFFocusesPreferenceSearch() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)
        let searchField = try XCTUnwrap(view(withIdentifier: "prefs.searchField", in: contentView) as? NSSearchField)

        XCTAssertTrue(window.performKeyEquivalent(with: try keyEvent(
            keyCode: kVK_ANSI_F,
            characters: "f",
            modifierFlags: .command,
            window: window
        )))

        XCTAssertTrue(isFirstResponder(searchField, in: window))
    }

    func testEscapeClearsPreferenceSearchOnlyWhenSearchFieldIsFocused() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)
        let searchField = try XCTUnwrap(view(withIdentifier: "prefs.searchField", in: contentView) as? NSSearchField)
        let searchStatus = try XCTUnwrap(view(withIdentifier: "prefs.searchStatusLabel", in: contentView) as? NSTextField)

        searchField.stringValue = L10n.tr("prefs.pause5hShortcut")
        XCTAssertTrue(sendAction(from: searchField))
        XCTAssertFalse(searchStatus.isHidden)
        let pause5h = try XCTUnwrap(view(withIdentifier: "shortcut.pause5h", in: contentView))
        let highlightedRow = try XCTUnwrap(highlightedAncestor(of: pause5h))
        XCTAssertEqual(highlightedRow.toolTip, searchStatus.stringValue)
        XCTAssertEqual(highlightedRow.accessibilityLabel(), searchStatus.stringValue)
        XCTAssertEqual(highlightedRow.accessibilityHelp(), searchStatus.stringValue)

        XCTAssertTrue(window.makeFirstResponder(searchField))
        window.cancelOperation(nil)

        XCTAssertEqual(searchField.stringValue, "")
        XCTAssertTrue(searchStatus.isHidden)
        XCTAssertNil(searchStatus.accessibilityLabel())
        XCTAssertNil(highlightedRow.toolTip)
        XCTAssertNil(highlightedRow.accessibilityLabel())
        XCTAssertNil(highlightedRow.accessibilityHelp())
        XCTAssertNotEqual(highlightedRow.layer?.borderWidth, 1)

        searchField.stringValue = L10n.tr("prefs.pause5hShortcut")
        XCTAssertTrue(sendAction(from: searchField))
        XCTAssertFalse(searchStatus.isHidden)
        let tabView = try XCTUnwrap(view(withIdentifier: "prefs.tabView", in: contentView) as? NSTabView)
        XCTAssertTrue(window.makeFirstResponder(tabView))
        window.cancelOperation(nil)

        XCTAssertEqual(searchField.stringValue, L10n.tr("prefs.pause5hShortcut"))
        XCTAssertFalse(searchStatus.isHidden)
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

    private func firstPopup(withSelectedTitle title: String, in view: NSView) -> NSPopUpButton? {
        if let popup = view as? NSPopUpButton, popup.title == title {
            return popup
        }
        for subview in view.subviews {
            if let found = firstPopup(withSelectedTitle: title, in: subview) {
                return found
            }
        }
        return nil
    }

    private func sendAction(from control: NSControl) -> Bool {
        guard let action = control.action else { return false }
        return NSApplication.shared.sendAction(action, to: control.target, from: control)
    }

    private func isFirstResponder(_ control: NSControl, in window: NSWindow) -> Bool {
        window.firstResponder === control || control.currentEditor() === window.firstResponder
    }

    private func highlightedAncestor(of view: NSView) -> NSView? {
        var candidate = view.superview
        while let current = candidate {
            if current.layer?.borderWidth == 1 {
                return current
            }
            candidate = current.superview
        }
        return nil
    }

    private func allConstraints(in view: NSView) -> [NSLayoutConstraint] {
        view.constraints + view.subviews.flatMap { allConstraints(in: $0) }
    }

    private func keyEvent(
        keyCode: Int,
        characters: String,
        modifierFlags: NSEvent.ModifierFlags = [],
        window: NSWindow
    ) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifierFlags,
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: UInt16(keyCode)
        ))
    }
}

private final class SavedSettingsBox {
    var value: RestSettings?
}

import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowUpdatePreferencesTests: XCTestCase {
    func testAdvancedPreferencesAreGroupedIntoScannableSections() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)

        let expectedSections: [(identifier: String, key: String)] = [
            ("prefs.section.startup", "prefs.sectionStartup"),
            ("prefs.section.pauseBehavior", "prefs.sectionPauseBehavior"),
            ("prefs.section.updates", "prefs.sectionUpdates"),
            ("prefs.section.supportControls", "prefs.sectionSupportControls")
        ]

        for section in expectedSections {
            let sectionView = try view(withIdentifier: section.identifier, in: contentView)
            let label = try XCTUnwrap(
                view(withIdentifier: "\(section.identifier).label", in: contentView) as? NSTextField
            )
            let icon = try XCTUnwrap(
                view(withIdentifier: "\(section.identifier).systemIcon", in: contentView) as? NSImageView
            )
            XCTAssertFalse(sectionView.isHidden, section.identifier)
            XCTAssertEqual(label.stringValue, L10n.tr(section.key), section.identifier)
            XCTAssertNotNil(icon.image, section.identifier)
            XCTAssertEqual(icon.image?.accessibilityDescription, L10n.tr(section.key), section.identifier)
        }

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.sectionStartup")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.sectionPauseBehavior")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.sectionUpdates")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.sectionSupportControls")))
    }

    func testUpdateDependentPreferencesAreVisibleWhenCheckingForUpdates() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)

        XCTAssertFalse(try view(withIdentifier: "prefs.notifyNewVersion", in: contentView).isHidden)
        XCTAssertFalse(try view(withIdentifier: "updateSource", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.updateFeedURLRow", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.notifyNewVersion")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.showUpdateSource")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.updateFeedURL")))
    }

    func testDisabledUpdateCheckingHidesDependentPreferences() throws {
        var settings = RestSettings.defaults
        settings.operations.checkForUpdates = false
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)

        XCTAssertFalse(try view(withIdentifier: "prefs.checkUpdates", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.notifyNewVersion", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "updateSource", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.updateFeedURLRow", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.checkUpdates")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.notifyNewVersion")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.showUpdateSource")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.updateFeedURL")))
    }

    func testHiddenUpdateFeaturesHideAdvancedUpdateSection() throws {
        var settings = RestSettings.defaults
        settings.admin.disableAppUpdateFeatures = true
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)

        XCTAssertTrue(try view(withIdentifier: "prefs.section.updates.separator", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.section.updates", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.checkUpdates", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.notifyNewVersion", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "updateSource", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.sectionUpdates")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.checkUpdates")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.sectionSupportControls")))
    }

    func testUpdateSourceDisclosureRevealsURLOnlyOnDemand() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)

        let disclosure = try XCTUnwrap(view(withIdentifier: "updateSource", in: contentView) as? NSButton)
        let row = try view(withIdentifier: "prefs.updateFeedURLRow", in: contentView)

        XCTAssertEqual(disclosure.title, L10n.tr("prefs.showUpdateSource"))
        XCTAssertEqual(disclosure.toolTip, L10n.tr("prefs.updateSourceDisclosureHelp"))
        XCTAssertEqual(disclosure.accessibilityHelp(), L10n.tr("prefs.updateSourceDisclosureHelp"))
        XCTAssertTrue(row.isHidden)

        XCTAssertTrue(sendAction(from: disclosure))

        XCTAssertEqual(disclosure.title, L10n.tr("prefs.hideUpdateSource"))
        XCTAssertFalse(row.isHidden)
    }

    func testAdvancedSupportControlsDisclosureUsesActionCopyWhenCollapsed() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)
        let supportDisclosure = try XCTUnwrap(view(withIdentifier: "adminControls", in: contentView) as? NSButton)

        XCTAssertEqual(supportDisclosure.title, L10n.tr("prefs.showAdminControls"))
        XCTAssertEqual(supportDisclosure.title, "Show advanced support controls")
        XCTAssertEqual(supportDisclosure.toolTip, L10n.tr("prefs.adminControlsHelp"))
        XCTAssertEqual(supportDisclosure.accessibilityLabel(), L10n.tr("prefs.showAdminControls"))
        XCTAssertEqual(supportDisclosure.accessibilityHelp(), L10n.tr("prefs.adminControlsHelp"))
        XCTAssertFalse(visibleTexts(in: contentView).contains("Advanced support controls"))
    }

    func testAdministrativeControlsDoNotRepeatAdminPrefix() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        var settings = RestSettings.defaults
        settings.admin.disableAppUpdateFeatures = true
        settings.admin.hideSettingsFileLocation = true
        settings.admin.hideStrictPreferences = true
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)
        let visibleTexts = visibleTexts(in: contentView)

        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.adminHideUpdates")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.adminHideSettingsPath")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.adminHideStrict")))
        XCTAssertFalse(visibleTexts.contains { $0.contains("Admin:") })
    }

    func testAdvancedOperationControlsExposeUserFacingHelp() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        var settings = RestSettings.defaults
        settings.admin.disableAppUpdateFeatures = true
        settings.admin.hideSettingsFileLocation = true
        settings.admin.hideStrictPreferences = true
        settings.admin.customPreferencesMessage = "Managed by your team"
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)
        let supportDisclosure = try XCTUnwrap(view(withIdentifier: "adminControls", in: contentView) as? NSButton)

        XCTAssertEqual(supportDisclosure.title, L10n.tr("prefs.hideAdminControls"))
        XCTAssertEqual(supportDisclosure.toolTip, L10n.tr("prefs.adminControlsHelp"))
        XCTAssertEqual(supportDisclosure.accessibilityHelp(), L10n.tr("prefs.adminControlsHelp"))

        let expectedHelp: [(identifier: String, helpKey: String)] = [
            ("prefs.openAtLogin", "prefs.openAtLoginHelp"),
            ("prefs.showMenuBarItem", "prefs.showMenuBarItemHelp"),
            ("prefs.checkUpdates", "prefs.checkUpdatesHelp"),
            ("prefs.notifyNewVersion", "prefs.notifyNewVersionHelp"),
            ("prefs.showOnboardingNextLaunch", "prefs.showOnboardingNextLaunchHelp"),
            ("prefs.pauseUntilMorningMode", "prefs.pauseUntilMorningModeHelp"),
            ("prefs.pauseUntilMorningLocation", "prefs.pauseUntilMorningLocationHelp"),
            ("prefs.pauseForSuspendOrLock", "prefs.pauseForSuspendOrLockHelp"),
            ("updateSource", "prefs.updateSourceDisclosureHelp"),
            ("prefs.updateFeedURLField", "prefs.updateFeedURLHelp"),
            ("prefs.restoreUpdateSourceButton", "prefs.restoreUpdateSourceDisabledUpdatesOffHelp"),
            ("prefs.adminHideUpdates", "prefs.adminHideUpdatesHelp"),
            ("prefs.adminHideSettingsPath", "prefs.adminHideSettingsPathHelp"),
            ("prefs.adminHideStrict", "prefs.adminHideStrictHelp"),
            ("prefs.preferencesMessageField", "prefs.preferencesMessageHelp")
        ]

        for expectation in expectedHelp {
            let control = try XCTUnwrap(
                view(withIdentifier: expectation.identifier, in: contentView) as? NSControl,
                expectation.identifier
            )
            XCTAssertEqual(control.toolTip, L10n.tr(expectation.helpKey), expectation.identifier)
            XCTAssertEqual(control.accessibilityHelp(), L10n.tr(expectation.helpKey), expectation.identifier)
        }

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.pauseForSuspendOrLock")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.preferencesMessage")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.hideAdminControls")))
        XCTAssertFalse(visibleTexts.contains("Administrative controls"))
        XCTAssertFalse(visibleTexts.contains("Hide administrative controls"))
        XCTAssertFalse(L10n.tr("prefs.adminControlsHelp").localizedCaseInsensitiveContains("deployment"))
        XCTAssertFalse(L10n.tr("prefs.preferencesMessageHelp").localizedCaseInsensitiveContains("managed setup"))
        XCTAssertTrue(L10n.tr("prefs.showMenuBarItemHelp").contains("shouldrest preferences"))
        XCTAssertTrue(L10n.tr("prefs.showMenuBarItemHelp").contains("shouldrest://preferences"))
        XCTAssertFalse(visibleTexts.contains("Pause scheduler on sleep or lock"))
    }

    func testMenuBarVisibilityPreferenceDefaultsVisibleAndAutosavesHiddenChoice() throws {
        let savedSettings = SavedSettingsBox()
        var settings = RestSettings.defaults
        settings.presentation.showMenuBarItem = nil
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)
        let checkbox = try XCTUnwrap(view(withIdentifier: "prefs.showMenuBarItem", in: contentView) as? NSButton)
        let recoveryRow = try view(withIdentifier: "prefs.showMenuBarItemRecoveryRow", in: contentView)
        let recoveryNotice = try XCTUnwrap(
            view(withIdentifier: "prefs.showMenuBarItemRecoveryNotice", in: contentView) as? NSStackView
        )
        let recoveryIcon = try XCTUnwrap(
            view(withIdentifier: "prefs.showMenuBarItemRecoveryIcon", in: contentView) as? NSImageView
        )
        let recoveryLabel = try XCTUnwrap(
            view(withIdentifier: "prefs.showMenuBarItemRecovery", in: contentView) as? NSTextField
        )

        XCTAssertFalse(checkbox.isHidden)
        XCTAssertEqual(checkbox.title, L10n.tr("prefs.showMenuBarItem"))
        XCTAssertEqual(checkbox.state, .on)
        XCTAssertEqual(checkbox.toolTip, L10n.tr("prefs.showMenuBarItemHelp"))
        XCTAssertEqual(checkbox.accessibilityHelp(), L10n.tr("prefs.showMenuBarItemHelp"))
        XCTAssertEqual(recoveryNotice.toolTip, L10n.tr("prefs.showMenuBarItemRecovery"))
        XCTAssertEqual(recoveryNotice.accessibilityHelp(), L10n.tr("prefs.showMenuBarItemRecovery"))
        XCTAssertNotNil(recoveryNotice.layer?.backgroundColor)
        XCTAssertNotNil(recoveryNotice.layer?.borderColor)
        XCTAssertTrue(recoveryRow.isHidden)
        XCTAssertTrue(recoveryIcon.isHidden)
        XCTAssertTrue(recoveryLabel.isHidden)

        checkbox.state = .off
        XCTAssertTrue(sendAction(from: checkbox))

        XCTAssertFalse(recoveryRow.isHidden)
        XCTAssertFalse(recoveryIcon.isHidden)
        XCTAssertFalse(recoveryLabel.isHidden)
        XCTAssertNotNil(recoveryIcon.image)
        XCTAssertEqual(recoveryIcon.accessibilityHelp(), L10n.tr("prefs.showMenuBarItemRecovery"))
        XCTAssertEqual(recoveryIcon.image?.accessibilityDescription, L10n.tr("prefs.showMenuBarItemRecovery"))
        XCTAssertEqual(recoveryLabel.stringValue, L10n.tr("prefs.showMenuBarItemRecovery"))
        XCTAssertEqual(recoveryLabel.toolTip, L10n.tr("prefs.showMenuBarItemRecovery"))
        XCTAssertEqual(recoveryLabel.accessibilityHelp(), L10n.tr("prefs.showMenuBarItemRecovery"))
        XCTAssertTrue(recoveryLabel.stringValue.contains("shouldrest preferences"))
        XCTAssertTrue(recoveryLabel.stringValue.contains("shouldrest://preferences"))

        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.presentation.showMenuBarItem, false)
        XCTAssertFalse(savedSettings.value?.presentation.resolvedShowMenuBarItem ?? true)

        checkbox.state = .on
        XCTAssertTrue(sendAction(from: checkbox))
        XCTAssertTrue(recoveryRow.isHidden)
        XCTAssertTrue(recoveryIcon.isHidden)
        XCTAssertTrue(recoveryLabel.isHidden)
    }

    func testDefaultUpdateSourceRestoreButtonExplainsAlreadyDefaultState() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)

        let field = try XCTUnwrap(view(withIdentifier: "prefs.updateFeedURLField", in: contentView) as? NSTextField)
        let button = try XCTUnwrap(view(withIdentifier: "prefs.restoreUpdateSourceButton", in: contentView) as? NSButton)

        XCTAssertEqual(field.stringValue, RestSettings.defaults.operations.updateFeedURL)
        XCTAssertFalse(button.isEnabled)
        XCTAssertEqual(button.title, "")
        XCTAssertNotNil(button.image)
        XCTAssertEqual(button.toolTip, L10n.tr("prefs.restoreUpdateSourceDisabledDefaultHelp"))
        XCTAssertEqual(button.accessibilityLabel(), L10n.tr("prefs.restoreUpdateSource"))
        XCTAssertEqual(button.accessibilityHelp(), L10n.tr("prefs.restoreUpdateSourceDisabledDefaultHelp"))
        XCTAssertEqual(button.image?.accessibilityDescription, L10n.tr("prefs.restoreUpdateSource"))
    }

    func testUpdateSourceRestoreButtonRestoresDefaultAndAutosaves() throws {
        let savedSettings = SavedSettingsBox()
        var settings = RestSettings.defaults
        settings.operations.updateFeedURL = ""
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)

        let field = try XCTUnwrap(view(withIdentifier: "prefs.updateFeedURLField", in: contentView) as? NSTextField)
        let button = try XCTUnwrap(view(withIdentifier: "prefs.restoreUpdateSourceButton", in: contentView) as? NSButton)

        XCTAssertEqual(field.stringValue, "")
        XCTAssertTrue(button.isEnabled)
        XCTAssertEqual(button.toolTip, L10n.tr("prefs.restoreUpdateSourceHelp"))
        XCTAssertEqual(button.accessibilityHelp(), L10n.tr("prefs.restoreUpdateSourceHelp"))

        XCTAssertTrue(sendAction(from: button))

        XCTAssertEqual(field.stringValue, RestSettings.defaults.operations.updateFeedURL)
        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.operations.updateFeedURL, RestSettings.defaults.operations.updateFeedURL)
        XCTAssertFalse(button.isEnabled)
        XCTAssertEqual(button.toolTip, L10n.tr("prefs.restoreUpdateSourceDisabledDefaultHelp"))
    }

    func testUpdateSourceRestoreButtonExplainsUpdateCheckingPrerequisite() throws {
        var settings = RestSettings.defaults
        settings.operations.checkForUpdates = false
        settings.operations.updateFeedURL = ""
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)

        let button = try XCTUnwrap(view(withIdentifier: "prefs.restoreUpdateSourceButton", in: contentView) as? NSButton)

        XCTAssertFalse(button.isEnabled)
        XCTAssertEqual(button.toolTip, L10n.tr("prefs.restoreUpdateSourceDisabledUpdatesOffHelp"))
        XCTAssertEqual(button.accessibilityHelp(), L10n.tr("prefs.restoreUpdateSourceDisabledUpdatesOffHelp"))
    }

    func testAdminPreferencesMessageBannerMirrorsFullMessageForHoverAndAccessibility() throws {
        let message = "Managed by your team\nAsk Facilities before changing schedules."
        var settings = RestSettings.defaults
        settings.admin.customPreferencesMessage = message
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        let bannerRow = try XCTUnwrap(view(withIdentifier: "prefs.adminMessageBanner", in: contentView) as? NSStackView)
        let icon = try XCTUnwrap(view(withIdentifier: "prefs.adminMessageIcon", in: contentView) as? NSImageView)
        let banner = try XCTUnwrap(view(withIdentifier: "prefs.adminMessageLabel", in: contentView) as? NSTextField)

        XCTAssertFalse(bannerRow.isHidden)
        XCTAssertTrue(bannerRow.wantsLayer)
        XCTAssertEqual(bannerRow.edgeInsets.top, 8)
        XCTAssertEqual(bannerRow.edgeInsets.left, 12)
        XCTAssertLessThanOrEqual(bannerRow.layer?.cornerRadius ?? 99, 8)
        XCTAssertEqual(bannerRow.layer?.borderWidth, 1)
        XCTAssertNotNil(bannerRow.layer?.backgroundColor)
        XCTAssertNotNil(bannerRow.layer?.borderColor)
        XCTAssertGreaterThanOrEqual(bannerRow.constraints.first { $0.firstAttribute == .width }?.constant ?? 0, 650)
        XCTAssertEqual(bannerRow.toolTip, message)
        XCTAssertEqual(bannerRow.accessibilityLabel(), L10n.tr("prefs.preferencesMessage"))
        XCTAssertEqual(bannerRow.accessibilityHelp(), message)
        XCTAssertFalse(icon.isHidden)
        XCTAssertNotNil(icon.image)
        XCTAssertEqual(icon.image?.accessibilityDescription, L10n.tr("prefs.preferencesMessage"))
        XCTAssertEqual(icon.accessibilityLabel(), L10n.tr("prefs.preferencesMessage"))
        XCTAssertEqual(icon.accessibilityHelp(), message)
        XCTAssertFalse(banner.isHidden)
        XCTAssertEqual(banner.stringValue, message)
        XCTAssertGreaterThanOrEqual(banner.maximumNumberOfLines, 3)
        XCTAssertEqual(banner.toolTip, message)
        XCTAssertEqual(banner.accessibilityLabel(), message)
        XCTAssertEqual(banner.accessibilityHelp(), message)
    }

    func testBlankAdminPreferencesMessageDoesNotExposeEmptyBanner() throws {
        var settings = RestSettings.defaults
        settings.admin.customPreferencesMessage = "   \n  "
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        let bannerRow = try XCTUnwrap(view(withIdentifier: "prefs.adminMessageBanner", in: contentView) as? NSStackView)
        let icon = try XCTUnwrap(view(withIdentifier: "prefs.adminMessageIcon", in: contentView) as? NSImageView)
        let banner = try XCTUnwrap(view(withIdentifier: "prefs.adminMessageLabel", in: contentView) as? NSTextField)

        XCTAssertTrue(bannerRow.isHidden)
        XCTAssertNil(bannerRow.toolTip)
        XCTAssertNil(bannerRow.accessibilityHelp())
        XCTAssertTrue(icon.isHidden)
        XCTAssertNil(icon.accessibilityHelp())
        XCTAssertTrue(banner.isHidden)
        XCTAssertEqual(banner.stringValue, "")
        XCTAssertNil(banner.toolTip)
        XCTAssertNil(banner.accessibilityLabel())
        XCTAssertNil(banner.accessibilityHelp())
    }

    func testEditingAdminPreferencesMessageUpdatesBannerBeforeAutosaveCompletes() throws {
        var settings = RestSettings.defaults
        settings.admin.customPreferencesMessage = "Managed by your team"
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let bannerRow = try XCTUnwrap(view(withIdentifier: "prefs.adminMessageBanner", in: contentView) as? NSStackView)
        let banner = try XCTUnwrap(view(withIdentifier: "prefs.adminMessageLabel", in: contentView) as? NSTextField)

        try selectAdvancedTab(in: contentView)
        let messageField = try XCTUnwrap(view(withIdentifier: "prefs.preferencesMessageField", in: contentView) as? NSTextField)
        messageField.stringValue = "Use the shared team rhythm."

        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: messageField))

        XCTAssertFalse(bannerRow.isHidden)
        XCTAssertEqual(bannerRow.toolTip, "Use the shared team rhythm.")
        XCTAssertEqual(bannerRow.accessibilityHelp(), "Use the shared team rhythm.")
        XCTAssertEqual(banner.stringValue, "Use the shared team rhythm.")
        XCTAssertEqual(banner.toolTip, "Use the shared team rhythm.")
        XCTAssertEqual(banner.accessibilityLabel(), "Use the shared team rhythm.")
        XCTAssertEqual(banner.accessibilityHelp(), "Use the shared team rhythm.")
    }

    func testTurningOffUpdateCheckingHidesDependentPreferencesAndAutosaves() throws {
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)
        let checkbox = try XCTUnwrap(view(withIdentifier: "prefs.checkUpdates", in: contentView) as? NSButton)
        checkbox.state = .off

        XCTAssertTrue(sendAction(from: checkbox))

        XCTAssertTrue(try view(withIdentifier: "prefs.notifyNewVersion", in: contentView).isHidden)
        XCTAssertTrue(try view(withIdentifier: "prefs.updateFeedURLRow", in: contentView).isHidden)

        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.operations.checkForUpdates, false)
    }

    func testClosingPreferencesFlushesPendingAutosaveImmediately() throws {
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)

        try selectAdvancedTab(in: contentView)
        let checkbox = try XCTUnwrap(view(withIdentifier: "prefs.checkUpdates", in: contentView) as? NSButton)
        checkbox.state = .off

        XCTAssertTrue(sendAction(from: checkbox))
        XCTAssertNil(savedSettings.value)

        XCTAssertTrue(controller.windowShouldClose(window))
        XCTAssertEqual(savedSettings.value?.operations.checkForUpdates, false)
    }

    func testClosingPreferencesCommitsInProgressTextEditing() throws {
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)

        try selectAdvancedTab(in: contentView)
        let field = try XCTUnwrap(view(withIdentifier: "prefs.updateFeedURLField", in: contentView) as? NSTextField)
        field.stringValue = "https://example.com/shouldrest.json"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))

        XCTAssertNil(savedSettings.value)

        XCTAssertTrue(controller.windowShouldClose(window))
        XCTAssertEqual(savedSettings.value?.operations.updateFeedURL, "https://example.com/shouldrest.json")
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

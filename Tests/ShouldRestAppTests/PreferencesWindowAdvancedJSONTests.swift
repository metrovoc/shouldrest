import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowAdvancedJSONTests: XCTestCase {
    func testAdvancedJSONDisclosuresDescribeSecondaryRawEditors() throws {
        var settings = RestSettings.defaults
        settings.appExclusions = [
            AppExclusionRule(
                id: "alpha",
                name: "Alpha",
                matchTerms: ["alpha.app"],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: true
            )
        ]
        settings.contentLibrary.customBodyBreakIdeas = [
            RestIdea(id: "stretch", kind: .bodyBreak, title: "Stretch", body: "Open shoulders")
        ]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        let appButton = try XCTUnwrap(view(withIdentifier: "appExclusions", in: contentView) as? NSButton)
        let appRow = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionsJSONRow", in: contentView))
        XCTAssertFalse(appButton.isHidden)
        XCTAssertTrue(appRow.isHidden)
        XCTAssertEqual(appButton.title, L10n.tr("prefs.showAdvancedRules"))
        XCTAssertEqual(appButton.toolTip, L10n.tr("prefs.advancedRulesHelp"))
        XCTAssertEqual(appButton.accessibilityLabel(), L10n.tr("prefs.showAdvancedRules"))
        XCTAssertEqual(appButton.accessibilityHelp(), L10n.tr("prefs.advancedRulesHelp"))
        XCTAssertEqual(appButton.image?.accessibilityDescription, L10n.tr("prefs.showAdvancedRules"))
        XCTAssertFalse((appButton.toolTip ?? "").localizedCaseInsensitiveContains("json editor"))

        XCTAssertTrue(sendAction(from: appButton))
        XCTAssertFalse(appRow.isHidden)
        XCTAssertEqual(appButton.title, L10n.tr("prefs.hideAdvancedRules"))
        XCTAssertEqual(appButton.accessibilityLabel(), L10n.tr("prefs.hideAdvancedRules"))
        XCTAssertEqual(appButton.accessibilityHelp(), L10n.tr("prefs.advancedRulesHelp"))
        XCTAssertEqual(appButton.image?.accessibilityDescription, L10n.tr("prefs.hideAdvancedRules"))

        let ideasButton = try XCTUnwrap(view(withIdentifier: "customIdeas", in: contentView) as? NSButton)
        let ideasRow = try XCTUnwrap(view(withIdentifier: "prefs.customBodyIdeasJSONRow", in: contentView))
        XCTAssertFalse(ideasButton.isHidden)
        XCTAssertTrue(ideasRow.isHidden)
        XCTAssertEqual(ideasButton.title, L10n.tr("prefs.showAdvancedIdeas"))
        XCTAssertEqual(ideasButton.toolTip, L10n.tr("prefs.advancedIdeasHelp"))
        XCTAssertEqual(ideasButton.accessibilityLabel(), L10n.tr("prefs.showAdvancedIdeas"))
        XCTAssertEqual(ideasButton.accessibilityHelp(), L10n.tr("prefs.advancedIdeasHelp"))
        XCTAssertFalse((ideasButton.toolTip ?? "").localizedCaseInsensitiveContains("json editor"))

        XCTAssertTrue(sendAction(from: ideasButton))
        XCTAssertFalse(ideasRow.isHidden)
        XCTAssertEqual(ideasButton.title, L10n.tr("prefs.hideAdvancedIdeas"))
        XCTAssertEqual(ideasButton.accessibilityLabel(), L10n.tr("prefs.hideAdvancedIdeas"))
        XCTAssertEqual(ideasButton.accessibilityHelp(), L10n.tr("prefs.advancedIdeasHelp"))
    }

    func testAdvancedJSONEditorsExplainBulkUseInPlace() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        let appButton = try XCTUnwrap(view(withIdentifier: "appExclusions", in: contentView) as? NSButton)
        let appRow = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionsJSONRow", in: contentView))
        let appGuidance = try XCTUnwrap(
            view(withIdentifier: "prefs.appExclusionsJSONGuidance", in: contentView) as? NSTextField
        )
        XCTAssertTrue(appRow.isHidden)
        XCTAssertEqual(appGuidance.stringValue, L10n.tr("prefs.advancedRulesGuidance"))
        XCTAssertEqual(appGuidance.toolTip, L10n.tr("prefs.advancedRulesGuidance"))
        XCTAssertEqual(appGuidance.accessibilityHelp(), L10n.tr("prefs.advancedRulesGuidance"))
        XCTAssertFalse(appGuidance.stringValue.localizedCaseInsensitiveContains("json array"))
        XCTAssertFalse(appGuidance.stringValue.localizedCaseInsensitiveContains("json editor"))
        XCTAssertTrue(appGuidance.stringValue.localizedCaseInsensitiveContains("exported"))

        XCTAssertTrue(sendAction(from: appButton))
        XCTAssertFalse(appRow.isHidden)

        let ideasButton = try XCTUnwrap(view(withIdentifier: "customIdeas", in: contentView) as? NSButton)
        let ideasRow = try XCTUnwrap(view(withIdentifier: "prefs.customBodyIdeasJSONRow", in: contentView))
        let ideasGuidance = try XCTUnwrap(
            view(withIdentifier: "prefs.customBodyIdeasJSONGuidance", in: contentView) as? NSTextField
        )
        XCTAssertTrue(ideasRow.isHidden)
        XCTAssertEqual(ideasGuidance.stringValue, L10n.tr("prefs.advancedIdeasGuidance"))
        XCTAssertEqual(ideasGuidance.toolTip, L10n.tr("prefs.advancedIdeasGuidance"))
        XCTAssertEqual(ideasGuidance.accessibilityHelp(), L10n.tr("prefs.advancedIdeasGuidance"))
        XCTAssertFalse(ideasGuidance.stringValue.localizedCaseInsensitiveContains("json array"))
        XCTAssertFalse(ideasGuidance.stringValue.localizedCaseInsensitiveContains("json editor"))
        XCTAssertTrue(ideasGuidance.stringValue.localizedCaseInsensitiveContains("exported"))

        XCTAssertTrue(sendAction(from: ideasButton))
        XCTAssertFalse(ideasRow.isHidden)
    }

    func testAdvancedJSONEditorsUseScrollableMultilineTextViews() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        let appEditor = try XCTUnwrap(view(withIdentifier: "appExclusionsJSONEditor", in: contentView) as? NSTextView)
        let ideasEditor = try XCTUnwrap(view(withIdentifier: "customBodyIdeasJSONEditor", in: contentView) as? NSTextView)
        let appScrollView = try XCTUnwrap(view(withIdentifier: "appExclusionsJSONEditorScrollView", in: contentView) as? NSScrollView)
        let ideasScrollView = try XCTUnwrap(view(withIdentifier: "customBodyIdeasJSONEditorScrollView", in: contentView) as? NSScrollView)

        XCTAssertFalse(appEditor.isRichText)
        XCTAssertFalse(ideasEditor.isRichText)
        XCTAssertTrue(appEditor.allowsUndo)
        XCTAssertTrue(ideasEditor.allowsUndo)
        XCTAssertTrue(appEditor.font?.fontDescriptor.symbolicTraits.contains(.monoSpace) ?? false)
        XCTAssertTrue(ideasEditor.font?.fontDescriptor.symbolicTraits.contains(.monoSpace) ?? false)
        XCTAssertFalse(appEditor.isAutomaticQuoteSubstitutionEnabled)
        XCTAssertFalse(ideasEditor.isAutomaticQuoteSubstitutionEnabled)
        XCTAssertFalse(appEditor.isAutomaticDashSubstitutionEnabled)
        XCTAssertFalse(ideasEditor.isAutomaticDashSubstitutionEnabled)
        XCTAssertFalse(appEditor.isAutomaticTextReplacementEnabled)
        XCTAssertFalse(ideasEditor.isAutomaticTextReplacementEnabled)
        XCTAssertFalse(appEditor.isAutomaticSpellingCorrectionEnabled)
        XCTAssertFalse(ideasEditor.isAutomaticSpellingCorrectionEnabled)
        XCTAssertFalse(appEditor.isContinuousSpellCheckingEnabled)
        XCTAssertFalse(ideasEditor.isContinuousSpellCheckingEnabled)
        XCTAssertFalse(appEditor.isGrammarCheckingEnabled)
        XCTAssertFalse(ideasEditor.isGrammarCheckingEnabled)
        XCTAssertFalse(appEditor.isAutomaticLinkDetectionEnabled)
        XCTAssertFalse(ideasEditor.isAutomaticLinkDetectionEnabled)
        XCTAssertFalse(appEditor.isAutomaticDataDetectionEnabled)
        XCTAssertFalse(ideasEditor.isAutomaticDataDetectionEnabled)
        XCTAssertTrue(appScrollView.hasVerticalScroller)
        XCTAssertTrue(ideasScrollView.hasVerticalScroller)
        XCTAssertTrue(appScrollView.documentView === appEditor)
        XCTAssertTrue(ideasScrollView.documentView === ideasEditor)
        XCTAssertEqual(appEditor.toolTip, L10n.tr("prefs.advancedRulesGuidance"))
        XCTAssertEqual(appEditor.accessibilityHelp(), L10n.tr("prefs.advancedRulesGuidance"))
        XCTAssertEqual(appScrollView.toolTip, L10n.tr("prefs.advancedRulesGuidance"))
        XCTAssertEqual(appScrollView.accessibilityHelp(), L10n.tr("prefs.advancedRulesGuidance"))
        XCTAssertEqual(ideasEditor.toolTip, L10n.tr("prefs.advancedIdeasGuidance"))
        XCTAssertEqual(ideasEditor.accessibilityHelp(), L10n.tr("prefs.advancedIdeasGuidance"))
        XCTAssertEqual(ideasScrollView.toolTip, L10n.tr("prefs.advancedIdeasGuidance"))
        XCTAssertEqual(ideasScrollView.accessibilityHelp(), L10n.tr("prefs.advancedIdeasGuidance"))
    }

    func testAdvancedJSONEditorsOfferCopyAndRestoreActions() throws {
        var settings = RestSettings.defaults
        settings.appExclusions = [
            AppExclusionRule(
                id: "alpha",
                name: "Alpha",
                matchTerms: ["alpha.app"],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: true
            )
        ]
        settings.contentLibrary.customBodyBreakIdeas = [
            RestIdea(id: "stretch", kind: .bodyBreak, title: "Stretch", body: "Open shoulders")
        ]
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let appEditor = try XCTUnwrap(view(withIdentifier: "appExclusionsJSONEditor", in: contentView) as? NSTextView)
        let appCopy = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionsCopyBulkButton", in: contentView) as? NSButton)
        let appRestore = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionsRestoreBulkButton", in: contentView) as? NSButton)
        let ideasEditor = try XCTUnwrap(view(withIdentifier: "customBodyIdeasJSONEditor", in: contentView) as? NSTextView)
        let ideasCopy = try XCTUnwrap(view(withIdentifier: "prefs.customBodyIdeasCopyBulkButton", in: contentView) as? NSButton)
        let ideasRestore = try XCTUnwrap(view(withIdentifier: "prefs.customBodyIdeasRestoreBulkButton", in: contentView) as? NSButton)
        let statusIcon = try XCTUnwrap(view(withIdentifier: "autosaveStatusIcon", in: contentView) as? NSImageView)
        let statusLabel = try XCTUnwrap(view(withIdentifier: "autosaveStatusLabel", in: contentView) as? NSTextField)

        XCTAssertEqual(appCopy.title, L10n.tr("prefs.copyBulkEditor"))
        XCTAssertEqual(appCopy.toolTip, L10n.tr("prefs.copyAppRulesBulkEditorHelp"))
        XCTAssertEqual(appCopy.accessibilityLabel(), L10n.tr("prefs.copyBulkEditor"))
        XCTAssertEqual(appCopy.accessibilityHelp(), L10n.tr("prefs.copyAppRulesBulkEditorHelp"))
        XCTAssertEqual(appCopy.image?.accessibilityDescription, L10n.tr("prefs.copyBulkEditor"))
        XCTAssertEqual(appRestore.title, L10n.tr("prefs.restoreBulkEditor"))
        XCTAssertEqual(appRestore.toolTip, L10n.tr("prefs.restoreBulkEditorDisabledNoChangesHelp"))
        XCTAssertEqual(appRestore.accessibilityHelp(), L10n.tr("prefs.restoreBulkEditorDisabledNoChangesHelp"))
        XCTAssertEqual(appRestore.image?.accessibilityDescription, L10n.tr("prefs.restoreBulkEditor"))
        XCTAssertEqual(ideasCopy.toolTip, L10n.tr("prefs.copyIdeasBulkEditorHelp"))
        XCTAssertEqual(ideasRestore.toolTip, L10n.tr("prefs.restoreBulkEditorDisabledNoChangesHelp"))
        XCTAssertEqual(ideasRestore.accessibilityHelp(), L10n.tr("prefs.restoreBulkEditorDisabledNoChangesHelp"))
        XCTAssertTrue(appCopy.isEnabled)
        XCTAssertFalse(appRestore.isEnabled)
        XCTAssertTrue(ideasCopy.isEnabled)
        XCTAssertFalse(ideasRestore.isEnabled)

        NSPasteboard.general.clearContents()
        XCTAssertTrue(sendAction(from: appCopy))
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), appEditor.string)
        XCTAssertEqual(statusLabel.stringValue, L10n.tr("prefs.autosaveCopied"))
        XCTAssertEqual(statusLabel.toolTip, L10n.tr("prefs.autosaveCopied"))
        XCTAssertEqual(statusLabel.accessibilityHelp(), L10n.tr("prefs.autosaveCopied"))
        XCTAssertEqual(statusIcon.image?.accessibilityDescription, L10n.tr("prefs.autosaveCopied"))
        XCTAssertEqual(statusIcon.accessibilityLabel(), L10n.tr("prefs.autosaveCopied"))
        XCTAssertEqual(statusIcon.accessibilityHelp(), L10n.tr("prefs.autosaveCopied"))

        appEditor.string = "{ invalid json"
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: appEditor))
        XCTAssertTrue(appRestore.isEnabled)
        XCTAssertEqual(appRestore.toolTip, L10n.tr("prefs.restoreAppRulesBulkEditorHelp"))
        XCTAssertEqual(appRestore.accessibilityHelp(), L10n.tr("prefs.restoreAppRulesBulkEditorHelp"))

        XCTAssertTrue(sendAction(from: appRestore))
        XCTAssertTrue(appEditor.string.contains("Alpha"))
        XCTAssertFalse(appRestore.isEnabled)
        XCTAssertEqual(appRestore.toolTip, L10n.tr("prefs.restoreBulkEditorDisabledNoChangesHelp"))
        XCTAssertEqual(appRestore.accessibilityHelp(), L10n.tr("prefs.restoreBulkEditorDisabledNoChangesHelp"))
        XCTAssertTrue(controller.flushPendingAutosave(showAlerts: false))
        XCTAssertEqual(savedSettings.value?.appExclusions.first?.name, "Alpha")

        NSPasteboard.general.clearContents()
        XCTAssertTrue(sendAction(from: ideasCopy))
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), ideasEditor.string)

        ideasEditor.string = "{ invalid json"
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: ideasEditor))
        XCTAssertTrue(ideasRestore.isEnabled)
        XCTAssertEqual(ideasRestore.toolTip, L10n.tr("prefs.restoreIdeasBulkEditorHelp"))
        XCTAssertEqual(ideasRestore.accessibilityHelp(), L10n.tr("prefs.restoreIdeasBulkEditorHelp"))

        XCTAssertTrue(sendAction(from: ideasRestore))
        XCTAssertTrue(ideasEditor.string.contains("Stretch"))
        XCTAssertFalse(ideasRestore.isEnabled)
        XCTAssertEqual(ideasRestore.toolTip, L10n.tr("prefs.restoreBulkEditorDisabledNoChangesHelp"))
        XCTAssertEqual(ideasRestore.accessibilityHelp(), L10n.tr("prefs.restoreBulkEditorDisabledNoChangesHelp"))
        XCTAssertTrue(controller.flushPendingAutosave(showAlerts: false))
        XCTAssertEqual(savedSettings.value?.contentLibrary.customBodyBreakIdeas.first?.title, "Stretch")
    }

    func testAdvancedBulkCopyButtonsExplainDisabledPrerequisites() throws {
        var settings = RestSettings.defaults
        settings.appExclusions = []
        settings.contentLibrary.customBodyBreakIdeas = []
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let appCheckbox = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionEnabled", in: contentView) as? NSButton)
        let appEditor = try XCTUnwrap(view(withIdentifier: "appExclusionsJSONEditor", in: contentView) as? NSTextView)
        let appCopy = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionsCopyBulkButton", in: contentView) as? NSButton)
        let ideasEditor = try XCTUnwrap(view(withIdentifier: "customBodyIdeasJSONEditor", in: contentView) as? NSTextView)
        let ideasCopy = try XCTUnwrap(view(withIdentifier: "prefs.customBodyIdeasCopyBulkButton", in: contentView) as? NSButton)

        XCTAssertFalse(appCopy.isEnabled)
        XCTAssertEqual(appCopy.toolTip, L10n.tr("prefs.copyAppRulesBulkEditorDisabledOffHelp"))
        XCTAssertEqual(appCopy.accessibilityHelp(), L10n.tr("prefs.copyAppRulesBulkEditorDisabledOffHelp"))

        appCheckbox.state = .on
        XCTAssertTrue(sendAction(from: appCheckbox))

        XCTAssertFalse(appCopy.isEnabled)
        XCTAssertEqual(appCopy.toolTip, L10n.tr("prefs.copyBulkEditorDisabledEmptyHelp"))
        XCTAssertEqual(appCopy.accessibilityHelp(), L10n.tr("prefs.copyBulkEditorDisabledEmptyHelp"))

        appEditor.string = "[{}]"
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: appEditor))

        XCTAssertTrue(appCopy.isEnabled)
        XCTAssertEqual(appCopy.toolTip, L10n.tr("prefs.copyAppRulesBulkEditorHelp"))
        XCTAssertEqual(appCopy.accessibilityHelp(), L10n.tr("prefs.copyAppRulesBulkEditorHelp"))

        XCTAssertFalse(ideasCopy.isEnabled)
        XCTAssertEqual(ideasCopy.toolTip, L10n.tr("prefs.copyBulkEditorDisabledEmptyHelp"))
        XCTAssertEqual(ideasCopy.accessibilityHelp(), L10n.tr("prefs.copyBulkEditorDisabledEmptyHelp"))

        ideasEditor.string = "[{}]"
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: ideasEditor))

        XCTAssertTrue(ideasCopy.isEnabled)
        XCTAssertEqual(ideasCopy.toolTip, L10n.tr("prefs.copyIdeasBulkEditorHelp"))
        XCTAssertEqual(ideasCopy.accessibilityHelp(), L10n.tr("prefs.copyIdeasBulkEditorHelp"))
    }

    func testIdeasBulkCopyButtonExplainsDisabledBodyBreakPrerequisite() throws {
        var settings = RestSettings.defaults
        settings.bodyBreak.isEnabled = false
        settings.contentLibrary.customBodyBreakIdeas = [
            RestIdea(id: "stretch", kind: .bodyBreak, title: "Stretch", body: "Open shoulders")
        ]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let ideasCopy = try XCTUnwrap(view(withIdentifier: "prefs.customBodyIdeasCopyBulkButton", in: contentView) as? NSButton)

        XCTAssertFalse(ideasCopy.isEnabled)
        XCTAssertEqual(ideasCopy.toolTip, L10n.tr("prefs.copyIdeasBulkEditorDisabledBodyOffHelp"))
        XCTAssertEqual(ideasCopy.accessibilityHelp(), L10n.tr("prefs.copyIdeasBulkEditorDisabledBodyOffHelp"))
    }

    func testAdvancedJSONLoadsPrettyPrintedMultilineContent() throws {
        var settings = RestSettings.defaults
        settings.appExclusions = [
            AppExclusionRule(
                id: "alpha",
                name: "Alpha",
                matchTerms: ["alpha.app"],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: true
            ),
            AppExclusionRule(
                id: "beta",
                name: "Beta",
                matchTerms: ["beta.app"],
                mode: .resumeOnlyWhenMatched,
                appliesTo: [.eyeGate],
                isEnabled: true
            )
        ]
        settings.contentLibrary.customBodyBreakIdeas = [
            RestIdea(id: "stretch", kind: .bodyBreak, title: "Stretch", body: "Open shoulders"),
            RestIdea(id: "walk", kind: .bodyBreak, title: "Walk", body: "Walk around")
        ]

        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let appEditor = try XCTUnwrap(view(withIdentifier: "appExclusionsJSONEditor", in: contentView) as? NSTextView)
        let ideasEditor = try XCTUnwrap(view(withIdentifier: "customBodyIdeasJSONEditor", in: contentView) as? NSTextView)

        XCTAssertTrue(appEditor.string.contains("\n"))
        XCTAssertTrue(appEditor.string.contains("\"name\""))
        XCTAssertTrue(appEditor.string.contains("Alpha"))
        XCTAssertTrue(ideasEditor.string.contains("\n"))
        XCTAssertTrue(ideasEditor.string.contains("\"title\""))
        XCTAssertTrue(ideasEditor.string.contains("Stretch"))
    }

    func testTurningOffAppExclusionsIgnoresHiddenAdvancedRulesAndAutosaves() throws {
        var settings = RestSettings.defaults
        settings.appExclusions = [
            AppExclusionRule(
                id: "alpha",
                name: "Alpha",
                matchTerms: ["alpha.app"],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: true
            ),
            AppExclusionRule(
                id: "beta",
                name: "Beta",
                matchTerms: ["beta.app"],
                mode: .resumeOnlyWhenMatched,
                appliesTo: [.eyeGate],
                isEnabled: true
            )
        ]
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let checkbox = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionEnabled", in: contentView) as? NSButton)
        let editor = try XCTUnwrap(view(withIdentifier: "appExclusionsJSONEditor", in: contentView) as? NSTextView)
        let restoreButton = try XCTUnwrap(
            view(withIdentifier: "prefs.appExclusionsRestoreBulkButton", in: contentView) as? NSButton
        )

        XCTAssertEqual(checkbox.state, .on)
        XCTAssertFalse(editor.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        checkbox.state = .off
        XCTAssertTrue(sendAction(from: checkbox))

        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.appExclusions, [])
        XCTAssertFalse(restoreButton.isEnabled)
        XCTAssertEqual(restoreButton.toolTip, L10n.tr("prefs.restoreAppRulesBulkEditorDisabledOffHelp"))
        XCTAssertEqual(restoreButton.accessibilityHelp(), L10n.tr("prefs.restoreAppRulesBulkEditorDisabledOffHelp"))
    }

    func testInvalidAdvancedJSONKeepsPendingAutosaveAfterFlushFailure() throws {
        var settings = RestSettings.defaults
        settings.appExclusions = [
            AppExclusionRule(
                id: "alpha",
                name: "Alpha",
                matchTerms: ["alpha.app"],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: true
            )
        ]
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let editor = try XCTUnwrap(view(withIdentifier: "appExclusionsJSONEditor", in: contentView) as? NSTextView)

        editor.string = "{ invalid json"
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))

        XCTAssertFalse(controller.flushPendingAutosave(showAlerts: false))
        XCTAssertNil(savedSettings.value)
        XCTAssertFalse(controller.flushPendingAutosave(showAlerts: false))
        XCTAssertNil(savedSettings.value)
    }

    func testInvalidAdvancedJSONStatusNamesBrokenEditor() throws {
        var settings = RestSettings.defaults
        settings.appExclusions = [
            AppExclusionRule(
                id: "alpha",
                name: "Alpha",
                matchTerms: ["alpha.app"],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: true
            )
        ]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let editor = try XCTUnwrap(view(withIdentifier: "appExclusionsJSONEditor", in: contentView) as? NSTextView)
        let statusIcon = try XCTUnwrap(view(withIdentifier: "autosaveStatusIcon", in: contentView) as? NSImageView)
        let statusLabel = try XCTUnwrap(view(withIdentifier: "autosaveStatusLabel", in: contentView) as? NSTextField)

        editor.string = "{ invalid json"
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))

        XCTAssertFalse(controller.flushPendingAutosave(showAlerts: false))

        let expectedTitle = L10n.format("prefs.autosaveInvalidField", L10n.tr("prefs.advancedRulesJSON"))
        XCTAssertEqual(statusLabel.stringValue, expectedTitle)
        XCTAssertTrue(statusLabel.toolTip?.contains(L10n.tr("prefs.advancedRulesJSON")) ?? false)
        XCTAssertNotEqual(statusLabel.toolTip, L10n.tr("prefs.autosaveInvalid"))
        XCTAssertEqual(statusIcon.toolTip, statusLabel.toolTip)
        XCTAssertEqual(statusIcon.accessibilityLabel(), expectedTitle)
        XCTAssertEqual(statusIcon.accessibilityHelp(), statusLabel.toolTip)
        XCTAssertEqual(statusLabel.accessibilityHelp(), statusLabel.toolTip)
    }

    func testInvalidAppRulesBulkEditorIsRevealedWhenAutosaveFails() throws {
        var settings = RestSettings.defaults
        settings.appExclusions = [
            AppExclusionRule(
                id: "alpha",
                name: "Alpha",
                matchTerms: ["alpha.app"],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: true
            )
        ]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)
        let tabView = try XCTUnwrap(view(withIdentifier: "prefs.tabView", in: contentView) as? NSTabView)
        let appRow = try XCTUnwrap(view(withIdentifier: "prefs.appExclusionsJSONRow", in: contentView))
        let appButton = try XCTUnwrap(view(withIdentifier: "appExclusions", in: contentView) as? NSButton)
        let editor = try XCTUnwrap(view(withIdentifier: "appExclusionsJSONEditor", in: contentView) as? NSTextView)
        let statusLabel = try XCTUnwrap(view(withIdentifier: "autosaveStatusLabel", in: contentView) as? NSTextField)

        XCTAssertTrue(appRow.isHidden)
        tabView.selectTabViewItem(withIdentifier: L10n.tr("prefs.tabAppearance"))
        editor.string = "{ invalid json"
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))

        XCTAssertFalse(controller.flushPendingAutosave(showAlerts: false))

        XCTAssertEqual(tabView.selectedTabViewItem?.identifier as? String, L10n.tr("prefs.tabContext"))
        XCTAssertFalse(appRow.isHidden)
        XCTAssertEqual(appButton.title, L10n.tr("prefs.hideAdvancedRules"))
        XCTAssertEqual(statusLabel.stringValue, L10n.format("prefs.autosaveInvalidField", L10n.tr("prefs.advancedRulesJSON")))
        XCTAssertTrue(window.firstResponder === editor)
    }

    func testInvalidIdeasBulkEditorIsRevealedWhenAutosaveFails() throws {
        var settings = RestSettings.defaults
        settings.contentLibrary.customBodyBreakIdeas = [
            RestIdea(id: "stretch", kind: .bodyBreak, title: "Stretch", body: "Open shoulders")
        ]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)
        let tabView = try XCTUnwrap(view(withIdentifier: "prefs.tabView", in: contentView) as? NSTabView)
        let ideasRow = try XCTUnwrap(view(withIdentifier: "prefs.customBodyIdeasJSONRow", in: contentView))
        let ideasButton = try XCTUnwrap(view(withIdentifier: "customIdeas", in: contentView) as? NSButton)
        let editor = try XCTUnwrap(view(withIdentifier: "customBodyIdeasJSONEditor", in: contentView) as? NSTextView)
        let statusLabel = try XCTUnwrap(view(withIdentifier: "autosaveStatusLabel", in: contentView) as? NSTextField)

        XCTAssertTrue(ideasRow.isHidden)
        tabView.selectTabViewItem(withIdentifier: L10n.tr("prefs.tabSchedule"))
        editor.string = "{ invalid json"
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))

        XCTAssertFalse(controller.flushPendingAutosave(showAlerts: false))

        XCTAssertEqual(tabView.selectedTabViewItem?.identifier as? String, L10n.tr("prefs.tabAppearance"))
        XCTAssertFalse(ideasRow.isHidden)
        XCTAssertEqual(ideasButton.title, L10n.tr("prefs.hideAdvancedIdeas"))
        XCTAssertEqual(statusLabel.stringValue, L10n.format("prefs.autosaveInvalidField", L10n.tr("prefs.advancedIdeasJSON")))
        XCTAssertTrue(window.firstResponder === editor)
    }

    private func view(withIdentifier identifier: String, in view: NSView) -> NSView? {
        if view.identifier?.rawValue == identifier {
            return view
        }
        if let tabView = view as? NSTabView {
            for item in tabView.tabViewItems {
                if let itemView = item.view,
                   let found = self.view(withIdentifier: identifier, in: itemView) {
                    return found
                }
            }
        }
        if let scrollView = view as? NSScrollView,
           let documentView = scrollView.documentView,
           let found = self.view(withIdentifier: identifier, in: documentView) {
            return found
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

    private func waitUntilSavedSettingsArrive(_ settings: SavedSettingsBox) {
        let deadline = Date().addingTimeInterval(2)
        while settings.value == nil && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }
}

private final class SavedSettingsBox {
    var value: RestSettings?
}

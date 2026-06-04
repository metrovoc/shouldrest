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

        XCTAssertTrue(sendAction(from: ideasButton))
        XCTAssertFalse(ideasRow.isHidden)
        XCTAssertEqual(ideasButton.title, L10n.tr("prefs.hideAdvancedIdeas"))
        XCTAssertEqual(ideasButton.accessibilityLabel(), L10n.tr("prefs.hideAdvancedIdeas"))
        XCTAssertEqual(ideasButton.accessibilityHelp(), L10n.tr("prefs.advancedIdeasHelp"))
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

        XCTAssertEqual(checkbox.state, .on)
        XCTAssertFalse(editor.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        checkbox.state = .off
        XCTAssertTrue(sendAction(from: checkbox))

        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.appExclusions, [])
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

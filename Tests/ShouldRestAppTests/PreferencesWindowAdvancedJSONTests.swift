import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowAdvancedJSONTests: XCTestCase {
    func testAdvancedJSONEditorsUseScrollableMultilineTextViews() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        let appEditor = try XCTUnwrap(view(withIdentifier: "appExclusionsJSONEditor", in: contentView) as? NSTextView)
        let ideasEditor = try XCTUnwrap(view(withIdentifier: "customBodyIdeasJSONEditor", in: contentView) as? NSTextView)
        let appScrollView = try XCTUnwrap(view(withIdentifier: "appExclusionsJSONEditorScrollView", in: contentView) as? NSScrollView)
        let ideasScrollView = try XCTUnwrap(view(withIdentifier: "customBodyIdeasJSONEditorScrollView", in: contentView) as? NSScrollView)

        XCTAssertFalse(appEditor.isRichText)
        XCTAssertFalse(ideasEditor.isRichText)
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

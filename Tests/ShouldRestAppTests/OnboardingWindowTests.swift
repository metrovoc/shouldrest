import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class OnboardingWindowTests: XCTestCase {
    func testOnboardingWindowUsesPolishedFirstRunLayout() throws {
        let controller = OnboardingWindowController(
            onUsePreset: { _ in },
            onOpenPreferences: { _ in },
            onLearnMore: {}
        )
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)

        XCTAssertGreaterThanOrEqual(window.frame.width, 620)
        XCTAssertGreaterThanOrEqual(window.frame.height, 480)
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.brandIcon"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.featureList"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.feature.eye"))
        let eyeIcon = try XCTUnwrap(
            contentView.descendant(withIdentifier: "onboarding.feature.eye.restGateIcon") as? NSImageView
        )
        XCTAssertEqual(eyeIcon.image?.size, NSSize(width: 18, height: 18))
        XCTAssertTrue(eyeIcon.image?.isTemplate ?? false)
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.feature.emergency"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.feature.body"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.rhythmPresetPanel"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.rhythmPresetControl"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.rhythmPresetDescription"))
    }

    func testOnboardingCopyExplainsCoreProductChoices() throws {
        let controller = OnboardingWindowController(
            onUsePreset: { _ in },
            onOpenPreferences: { _ in },
            onLearnMore: {}
        )
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let texts = visibleTexts(in: contentView)

        XCTAssertTrue(texts.contains(L10n.tr("onboarding.heading")))
        XCTAssertTrue(texts.contains(L10n.tr("onboarding.subtitle")))
        XCTAssertTrue(texts.contains(L10n.tr("onboarding.body")))
        XCTAssertTrue(texts.contains(L10n.tr("onboarding.eyeFeatureTitle")))
        XCTAssertTrue(texts.contains(L10n.tr("onboarding.emergencyFeatureTitle")))
        XCTAssertTrue(texts.contains(L10n.tr("onboarding.bodyFeatureTitle")))
        XCTAssertTrue(texts.contains(L10n.tr("onboarding.rhythmTitle")))
        XCTAssertTrue(texts.contains(RestRhythmPreset.recommended.help))
    }

    func testOnboardingButtonsUseIconsAndDefaultAction() throws {
        let controller = OnboardingWindowController(
            onUsePreset: { _ in },
            onOpenPreferences: { _ in },
            onLearnMore: {}
        )
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let buttons = buttonsByTitle(in: contentView)

        let learnMore = try XCTUnwrap(buttons[L10n.tr("onboarding.learnMore")])
        let preferences = try XCTUnwrap(buttons[L10n.tr("onboarding.preferences")])
        let useSelected = try XCTUnwrap(buttons[L10n.tr("onboarding.useSelected")])

        for button in [learnMore, preferences, useSelected] {
            XCTAssertNotNil(button.image)
            XCTAssertEqual(button.imagePosition, .imageLeading)
        }
        XCTAssertEqual(useSelected.keyEquivalent, "\r")
        XCTAssertEqual(useSelected.bezelStyle, .rounded)
    }

    func testOnboardingRhythmPresetSelectionUpdatesDescriptionAndPrimaryAction() throws {
        var selectedPreset: RestRhythmPreset?
        let controller = OnboardingWindowController(
            onUsePreset: { selectedPreset = $0 },
            onOpenPreferences: { _ in },
            onLearnMore: {}
        )
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let control = try XCTUnwrap(
            contentView.descendant(withIdentifier: "onboarding.rhythmPresetControl") as? NSSegmentedControl
        )
        let description = try XCTUnwrap(
            contentView.descendant(withIdentifier: "onboarding.rhythmPresetDescription") as? NSTextField
        )

        XCTAssertEqual(control.segmentCount, RestRhythmPreset.allCases.count)
        XCTAssertEqual(control.selectedSegment, RestRhythmPreset.recommended.rawValue)
        XCTAssertEqual(description.stringValue, RestRhythmPreset.recommended.help)

        control.selectedSegment = RestRhythmPreset.frequentEye.rawValue
        XCTAssertTrue(control.sendAction(control.action, to: control.target))

        XCTAssertEqual(description.stringValue, RestRhythmPreset.frequentEye.help)

        let buttons = buttonsByTitle(in: contentView)
        let useSelected = try XCTUnwrap(buttons[L10n.tr("onboarding.useSelected")])
        useSelected.performClick(nil)

        XCTAssertEqual(selectedPreset, .frequentEye)
    }

    func testOnboardingOpenPreferencesUsesSelectedRhythmPreset() throws {
        var selectedPreset: RestRhythmPreset?
        let controller = OnboardingWindowController(
            onUsePreset: { _ in },
            onOpenPreferences: { selectedPreset = $0 },
            onLearnMore: {}
        )
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let control = try XCTUnwrap(
            contentView.descendant(withIdentifier: "onboarding.rhythmPresetControl") as? NSSegmentedControl
        )

        control.selectedSegment = RestRhythmPreset.movement.rawValue
        XCTAssertTrue(control.sendAction(control.action, to: control.target))

        let buttons = buttonsByTitle(in: contentView)
        let preferences = try XCTUnwrap(buttons[L10n.tr("onboarding.preferences")])
        preferences.performClick(nil)

        XCTAssertEqual(selectedPreset, .movement)
    }

    func testRhythmPresetAppliesScheduleValuesToSettings() {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = false
        settings.bodyBreak.isEnabled = false

        RestRhythmPreset.frequentEye.apply(to: &settings)

        XCTAssertTrue(settings.eyeGate.isEnabled)
        XCTAssertTrue(settings.bodyBreak.isEnabled)
        XCTAssertEqual(settings.eyeGate.interval, 10 * 60)
        XCTAssertEqual(settings.eyeGate.duration, 20)
        XCTAssertEqual(settings.bodyBreak.interval, 20 * 60)
        XCTAssertEqual(settings.bodyBreakAfterEyeGates, 4)
        XCTAssertEqual(settings.bodyBreak.duration, 5 * 60)
    }
}

private extension NSView {
    func descendant(withIdentifier rawIdentifier: String) -> NSView? {
        if identifier?.rawValue == rawIdentifier {
            return self
        }
        for subview in subviews {
            if let match = subview.descendant(withIdentifier: rawIdentifier) {
                return match
            }
        }
        return nil
    }
}

@MainActor
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

@MainActor
private func buttonsByTitle(in view: NSView, ancestorHidden: Bool = false) -> [String: NSButton] {
    let hidden = ancestorHidden || view.isHidden
    var buttons: [String: NSButton] = [:]
    if !hidden, let button = view as? NSButton, !button.title.isEmpty {
        buttons[button.title] = button
    }
    for subview in view.subviews {
        buttons.merge(buttonsByTitle(in: subview, ancestorHidden: hidden)) { current, _ in current }
    }
    return buttons
}

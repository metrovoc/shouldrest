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
        XCTAssertGreaterThanOrEqual(window.frame.height, 540)
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
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.rhythmMetricRow"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.metric.eyeInterval"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.metric.eyeDuration"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.metric.bodyAfter"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.metric.bodyDuration"))
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
        XCTAssertTrue(texts.contains(RestRhythmPreset.firstRunDefault.help))
        XCTAssertTrue(texts.contains(L10n.tr("onboarding.metric.eyeInterval")))
        XCTAssertTrue(texts.contains(L10n.tr("onboarding.metric.eyeDuration")))
        XCTAssertTrue(texts.contains(L10n.tr("onboarding.metric.bodyAfter")))
        XCTAssertTrue(texts.contains(L10n.tr("onboarding.metric.bodyDuration")))
    }

    func testOnboardingButtonsUseIconsHelpAndDefaultAction() throws {
        let controller = OnboardingWindowController(
            onUsePreset: { _ in },
            onOpenPreferences: { _ in },
            onLearnMore: {}
        )
        let contentView = try XCTUnwrap(controller.window?.contentView)

        let learnMore = try XCTUnwrap(button(withIdentifier: "onboarding.aboutButton", in: contentView))
        let preferences = try XCTUnwrap(button(withIdentifier: "onboarding.preferencesButton", in: contentView))
        let useSelected = try XCTUnwrap(button(withIdentifier: "onboarding.useSelectedButton", in: contentView))

        for button in [learnMore, preferences, useSelected] {
            XCTAssertNotNil(button.image)
            XCTAssertEqual(button.imagePosition, .imageLeading)
            XCTAssertEqual(button.accessibilityLabel(), button.title)
            XCTAssertEqual(button.accessibilityHelp(), button.toolTip)
        }
        XCTAssertEqual(learnMore.title, L10n.tr("onboarding.learnMore"))
        XCTAssertEqual(learnMore.toolTip, L10n.tr("onboarding.learnMoreHelp"))
        XCTAssertEqual(preferences.title, L10n.tr("onboarding.preferences"))
        XCTAssertEqual(preferences.toolTip, L10n.tr("onboarding.preferencesHelp"))
        XCTAssertEqual(
            useSelected.title,
            L10n.format("onboarding.useSelectedWithPreset", RestRhythmPreset.firstRunDefault.title)
        )
        XCTAssertEqual(useSelected.toolTip, L10n.tr("onboarding.useSelectedHelp"))
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
        let eyeInterval = try XCTUnwrap(
            contentView.descendant(withIdentifier: "onboarding.metric.eyeInterval.value") as? NSTextField
        )
        let eyeDuration = try XCTUnwrap(
            contentView.descendant(withIdentifier: "onboarding.metric.eyeDuration.value") as? NSTextField
        )
        let bodyAfter = try XCTUnwrap(
            contentView.descendant(withIdentifier: "onboarding.metric.bodyAfter.value") as? NSTextField
        )
        let bodyDuration = try XCTUnwrap(
            contentView.descendant(withIdentifier: "onboarding.metric.bodyDuration.value") as? NSTextField
        )
        let useSelected = try XCTUnwrap(button(withIdentifier: "onboarding.useSelectedButton", in: contentView))

        XCTAssertEqual(control.segmentCount, RestRhythmPreset.allCases.count)
        XCTAssertEqual(control.selectedSegment, RestRhythmPreset.firstRunDefault.rawValue)
        XCTAssertEqual(control.label(forSegment: RestRhythmPreset.recommended.rawValue), "Balanced")
        XCTAssertEqual(control.label(forSegment: RestRhythmPreset.frequentEye.rawValue), "More Eye Rests")
        XCTAssertEqual(control.label(forSegment: RestRhythmPreset.movement.rawValue), "More Movement")
        XCTAssertEqual(description.stringValue, RestRhythmPreset.firstRunDefault.help)
        XCTAssertEqual(control.accessibilityHelp(), RestRhythmPreset.firstRunDefault.help)
        XCTAssertEqual(eyeInterval.stringValue, L10n.format("onboarding.metric.eyeIntervalValue", 10))
        XCTAssertEqual(eyeDuration.stringValue, L10n.format("onboarding.metric.eyeDurationValue", 20))
        XCTAssertEqual(bodyAfter.stringValue, L10n.format("onboarding.metric.bodyAfterValue", 4))
        XCTAssertEqual(bodyDuration.stringValue, L10n.format("onboarding.metric.bodyDurationValue", 5))
        XCTAssertEqual(
            useSelected.title,
            L10n.format("onboarding.useSelectedWithPreset", RestRhythmPreset.firstRunDefault.title)
        )

        control.selectedSegment = RestRhythmPreset.movement.rawValue
        XCTAssertTrue(control.sendAction(control.action, to: control.target))

        XCTAssertEqual(description.stringValue, RestRhythmPreset.movement.help)
        XCTAssertEqual(control.accessibilityHelp(), RestRhythmPreset.movement.help)
        XCTAssertEqual(eyeInterval.stringValue, L10n.format("onboarding.metric.eyeIntervalValue", 20))
        XCTAssertEqual(eyeDuration.stringValue, L10n.format("onboarding.metric.eyeDurationValue", 20))
        XCTAssertEqual(bodyAfter.stringValue, L10n.format("onboarding.metric.bodyAfterValue", 2))
        XCTAssertEqual(bodyDuration.stringValue, L10n.format("onboarding.metric.bodyDurationValue", 8))
        XCTAssertEqual(
            useSelected.title,
            L10n.format("onboarding.useSelectedWithPreset", RestRhythmPreset.movement.title)
        )
        XCTAssertEqual(useSelected.accessibilityLabel(), useSelected.title)

        useSelected.performClick(nil)

        XCTAssertEqual(selectedPreset, .movement)
    }

    func testOnboardingPrimaryActionUsesFrequentEyeFirstRunDefault() throws {
        var selectedPreset: RestRhythmPreset?
        let controller = OnboardingWindowController(
            onUsePreset: { selectedPreset = $0 },
            onOpenPreferences: { _ in },
            onLearnMore: {}
        )
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let useSelected = try XCTUnwrap(button(withIdentifier: "onboarding.useSelectedButton", in: contentView))

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

@MainActor
private func button(withIdentifier identifier: String, in view: NSView) -> NSButton? {
    if view.identifier?.rawValue == identifier {
        return view as? NSButton
    }
    for subview in view.subviews {
        if let button = button(withIdentifier: identifier, in: subview) {
            return button
        }
    }
    return nil
}

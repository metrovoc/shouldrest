import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class OnboardingWindowTests: XCTestCase {
    func testOnboardingWindowUsesPolishedFirstRunLayoutWithoutPresetSelection() throws {
        let controller = OnboardingWindowController(
            onStart: {},
            onOpenPreferences: {},
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
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.rhythmPanel"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.rhythmDescription"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.rhythmRationaleRow"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.rhythmRationaleIcon"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.rhythmRationale"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.rhythmMetricRow"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.metric.eyeInterval"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.metric.eyeDuration"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.metric.bodyInterval"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.metric.bodyDuration"))
    }

    func testOnboardingCopyExplainsSingleRecommendedRhythm() throws {
        let controller = OnboardingWindowController(
            onStart: {},
            onOpenPreferences: {},
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
        XCTAssertTrue(texts.contains(defaultRhythmDescription()))
        XCTAssertTrue(texts.contains(L10n.tr("onboarding.rhythmRationale")))
        XCTAssertTrue(texts.contains(L10n.tr("onboarding.metric.eyeInterval")))
        XCTAssertTrue(texts.contains(L10n.tr("onboarding.metric.eyeDuration")))
        XCTAssertTrue(texts.contains(L10n.tr("onboarding.metric.bodyInterval")))
        XCTAssertTrue(texts.contains(L10n.tr("onboarding.metric.bodyDuration")))
    }

    func testOnboardingButtonsUseIconsHelpAndDefaultAction() throws {
        let controller = OnboardingWindowController(
            onStart: {},
            onOpenPreferences: {},
            onLearnMore: {}
        )
        let contentView = try XCTUnwrap(controller.window?.contentView)

        let learnMore = try XCTUnwrap(button(withIdentifier: "onboarding.aboutButton", in: contentView))
        let preferences = try XCTUnwrap(button(withIdentifier: "onboarding.preferencesButton", in: contentView))
        let start = try XCTUnwrap(button(withIdentifier: "onboarding.startButton", in: contentView))

        for button in [learnMore, preferences, start] {
            XCTAssertNotNil(button.image)
            XCTAssertEqual(button.image?.accessibilityDescription, button.title)
            XCTAssertEqual(button.imagePosition, .imageLeading)
            XCTAssertEqual(button.accessibilityLabel(), button.title)
            XCTAssertEqual(button.accessibilityHelp(), button.toolTip)
        }
        XCTAssertEqual(learnMore.title, L10n.tr("onboarding.learnMore"))
        XCTAssertEqual(learnMore.toolTip, L10n.tr("onboarding.learnMoreHelp"))
        XCTAssertEqual(preferences.title, L10n.tr("onboarding.preferences"))
        XCTAssertEqual(preferences.toolTip, L10n.tr("onboarding.preferencesHelp"))
        XCTAssertEqual(start.title, L10n.tr("onboarding.useRecommended"))
        XCTAssertEqual(start.toolTip, L10n.tr("onboarding.startHelp"))
        XCTAssertEqual(start.keyEquivalent, "\r")
        XCTAssertEqual(start.bezelStyle, .rounded)
    }

    func testOnboardingRecommendedRhythmDetailsReflectDefaultSettings() throws {
        let controller = OnboardingWindowController(
            onStart: {},
            onOpenPreferences: {},
            onLearnMore: {}
        )
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let description = try XCTUnwrap(
            contentView.descendant(withIdentifier: "onboarding.rhythmDescription") as? NSTextField
        )
        let icon = try XCTUnwrap(
            contentView.descendant(withIdentifier: "onboarding.rhythmIcon") as? NSImageView
        )
        let rationaleIcon = try XCTUnwrap(
            contentView.descendant(withIdentifier: "onboarding.rhythmRationaleIcon") as? NSImageView
        )
        let rationale = try XCTUnwrap(
            contentView.descendant(withIdentifier: "onboarding.rhythmRationale") as? NSTextField
        )
        let eyeInterval = try XCTUnwrap(
            contentView.descendant(withIdentifier: "onboarding.metric.eyeInterval.value") as? NSTextField
        )
        let eyeDuration = try XCTUnwrap(
            contentView.descendant(withIdentifier: "onboarding.metric.eyeDuration.value") as? NSTextField
        )
        let bodyInterval = try XCTUnwrap(
            contentView.descendant(withIdentifier: "onboarding.metric.bodyInterval.value") as? NSTextField
        )
        let bodyDuration = try XCTUnwrap(
            contentView.descendant(withIdentifier: "onboarding.metric.bodyDuration.value") as? NSTextField
        )

        XCTAssertEqual(description.stringValue, defaultRhythmDescription())
        XCTAssertEqual(description.toolTip, defaultRhythmDescription())
        XCTAssertEqual(description.accessibilityLabel(), defaultRhythmDescription())
        XCTAssertEqual(description.accessibilityHelp(), defaultRhythmDescription())
        XCTAssertEqual(icon.image?.accessibilityDescription, "\(L10n.tr("onboarding.rhythmTitle")): \(defaultRhythmDescription())")
        XCTAssertNotNil(icon.image)
        XCTAssertEqual(icon.accessibilityHelp(), defaultRhythmDescription())
        XCTAssertEqual(rationale.stringValue, L10n.tr("onboarding.rhythmRationale"))
        XCTAssertEqual(rationale.toolTip, L10n.tr("onboarding.rhythmRationale"))
        XCTAssertEqual(rationale.accessibilityLabel(), L10n.tr("onboarding.rhythmRationale"))
        XCTAssertEqual(rationale.accessibilityHelp(), L10n.tr("onboarding.rhythmRationale"))
        XCTAssertEqual(rationaleIcon.image?.accessibilityDescription, L10n.tr("onboarding.rhythmRationale"))
        XCTAssertEqual(rationaleIcon.accessibilityLabel(), L10n.tr("onboarding.rhythmRationale"))
        XCTAssertEqual(eyeInterval.stringValue, L10n.format("onboarding.metric.eyeIntervalValue", 20))
        XCTAssertEqual(eyeDuration.stringValue, L10n.format("onboarding.metric.eyeDurationValue", 20))
        XCTAssertEqual(bodyInterval.stringValue, L10n.format("onboarding.metric.bodyIntervalValue", 60))
        XCTAssertEqual(bodyDuration.stringValue, L10n.format("onboarding.metric.bodyDurationValue", 3))
        assertMetricHelp(eyeInterval, titleKey: "onboarding.metric.eyeInterval")
        assertMetricHelp(eyeDuration, titleKey: "onboarding.metric.eyeDuration")
        assertMetricHelp(bodyInterval, titleKey: "onboarding.metric.bodyInterval")
        assertMetricHelp(bodyDuration, titleKey: "onboarding.metric.bodyDuration")
    }

    func testOnboardingPrimaryActionCompletesWithoutApplyingPreset() throws {
        var didStart = false
        let controller = OnboardingWindowController(
            onStart: { didStart = true },
            onOpenPreferences: {},
            onLearnMore: {}
        )
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let start = try XCTUnwrap(button(withIdentifier: "onboarding.startButton", in: contentView))

        XCTAssertEqual(start.title, L10n.tr("onboarding.useRecommended"))

        start.performClick(nil)

        XCTAssertTrue(didStart)
    }

    func testOnboardingOpenPreferencesCompletesWithoutApplyingPreset() throws {
        var didOpenPreferences = false
        let controller = OnboardingWindowController(
            onStart: {},
            onOpenPreferences: { didOpenPreferences = true },
            onLearnMore: {}
        )
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let buttons = buttonsByTitle(in: contentView)
        let preferences = try XCTUnwrap(buttons[L10n.tr("onboarding.preferences")])

        preferences.performClick(nil)

        XCTAssertTrue(didOpenPreferences)
    }

    func testDefaultRhythmUsesSingleRecommendedScheduleValues() {
        XCTAssertTrue(RestSettings.defaults.eyeGate.isEnabled)
        XCTAssertTrue(RestSettings.defaults.bodyBreak.isEnabled)
        XCTAssertEqual(RestSettings.defaults.eyeGate.interval, 20 * 60)
        XCTAssertEqual(RestSettings.defaults.eyeGate.duration, 20)
        XCTAssertEqual(RestSettings.defaults.bodyBreak.interval, 60 * 60)
        XCTAssertEqual(RestSettings.defaults.bodyBreak.duration, 3 * 60)
        XCTAssertFalse(RestSettings.defaults.bodyBreak.manualFinishEnabled)
        XCTAssertEqual(RestSettings.defaults.naturalBreaks.inactivityResetTime, 10 * 60)
    }
}

@MainActor
private func defaultRhythmDescription() -> String {
    L10n.format("onboarding.rhythmDescription", 20, 20, 60, 3)
}

@MainActor
private func assertMetricHelp(
    _ label: NSTextField,
    titleKey: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let expectedHelp = "\(L10n.tr(titleKey)): \(label.stringValue)"
    XCTAssertEqual(label.toolTip, expectedHelp, file: file, line: line)
    XCTAssertEqual(label.accessibilityLabel(), expectedHelp, file: file, line: line)
    XCTAssertEqual(label.accessibilityHelp(), expectedHelp, file: file, line: line)
}

@MainActor
private func button(withIdentifier identifier: String, in view: NSView) -> NSButton? {
    view.descendant(withIdentifier: identifier) as? NSButton
}

@MainActor
private func buttonsByTitle(in view: NSView) -> [String: NSButton] {
    var result: [String: NSButton] = [:]
    collectButtons(in: view, into: &result)
    return result
}

@MainActor
private func collectButtons(in view: NSView, into result: inout [String: NSButton]) {
    if let button = view as? NSButton {
        result[button.title] = button
    }
    for subview in view.subviews {
        collectButtons(in: subview, into: &result)
    }
}

@MainActor
private func visibleTexts(in view: NSView, ancestorHidden: Bool = false) -> [String] {
    let hidden = ancestorHidden || view.isHidden
    var texts: [String] = []
    if !hidden, let label = view as? NSTextField, !label.stringValue.isEmpty {
        texts.append(label.stringValue)
    }
    if !hidden, let button = view as? NSButton, !button.title.isEmpty {
        texts.append(button.title)
    }
    for subview in view.subviews {
        texts.append(contentsOf: visibleTexts(in: subview, ancestorHidden: hidden))
    }
    return texts
}

private extension NSView {
    @MainActor
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

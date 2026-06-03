import AppKit
import XCTest
@testable import shouldrest

@MainActor
final class OnboardingWindowTests: XCTestCase {
    func testOnboardingWindowUsesPolishedFirstRunLayout() throws {
        let controller = OnboardingWindowController(
            onUseDefaults: {},
            onOpenPreferences: {},
            onLearnMore: {}
        )
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)

        XCTAssertGreaterThanOrEqual(window.frame.width, 620)
        XCTAssertGreaterThanOrEqual(window.frame.height, 360)
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.brandIcon"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.featureList"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.feature.eye"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.feature.emergency"))
        XCTAssertNotNil(contentView.descendant(withIdentifier: "onboarding.feature.body"))
    }

    func testOnboardingCopyExplainsCoreProductChoices() throws {
        let controller = OnboardingWindowController(
            onUseDefaults: {},
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
    }

    func testOnboardingButtonsUseIconsAndDefaultAction() throws {
        let controller = OnboardingWindowController(
            onUseDefaults: {},
            onOpenPreferences: {},
            onLearnMore: {}
        )
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let buttons = buttonsByTitle(in: contentView)

        let learnMore = try XCTUnwrap(buttons[L10n.tr("onboarding.learnMore")])
        let preferences = try XCTUnwrap(buttons[L10n.tr("onboarding.preferences")])
        let useDefaults = try XCTUnwrap(buttons[L10n.tr("onboarding.useDefaults")])

        for button in [learnMore, preferences, useDefaults] {
            XCTAssertNotNil(button.image)
            XCTAssertEqual(button.imagePosition, .imageLeading)
        }
        XCTAssertEqual(useDefaults.keyEquivalent, "\r")
        XCTAssertEqual(useDefaults.bezelStyle, .rounded)
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

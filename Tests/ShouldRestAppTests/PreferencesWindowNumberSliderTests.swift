import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowNumberSliderTests: XCTestCase {
    func testCoreScheduleNumberRowsExposeSliders() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        let expectedSliders: [(identifier: String, min: Double, max: Double)] = [
            ("eyeIntervalSlider", 1, 240),
            ("eyeDurationSlider", 1, 300),
            ("bodyIntervalSlider", 1, 720),
            ("bodyDurationSlider", 1, 180)
        ]

        for expected in expectedSliders {
            let slider = try XCTUnwrap(view(withIdentifier: expected.identifier, in: contentView) as? NSSlider)
            XCTAssertEqual(slider.minValue, expected.min)
            XCTAssertEqual(slider.maxValue, expected.max)
            XCTAssertEqual(slider.numberOfTickMarks, 5)
        }
    }

    func testCoreScheduleSliderSynchronizesFieldAndStepper() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let slider = try XCTUnwrap(view(withIdentifier: "eyeIntervalSlider", in: contentView) as? NSSlider)
        let field = try XCTUnwrap(view(withIdentifier: "eyeIntervalField", in: contentView) as? NSTextField)
        let stepper = try XCTUnwrap(view(withIdentifier: "eyeIntervalStepper", in: contentView) as? NSStepper)

        slider.doubleValue = 31.2
        XCTAssertTrue(sendAction(from: slider))
        XCTAssertEqual(field.stringValue, "31")
        XCTAssertEqual(stepper.doubleValue, 31)

        stepper.doubleValue = 42
        XCTAssertTrue(sendAction(from: stepper))
        XCTAssertEqual(field.stringValue, "42")
        XCTAssertEqual(slider.doubleValue, 42)
    }

    func testNumberControlsExposeReadableAccessibilityLabelsWithFullUnits() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        let expectedLabels: [(identifier: String, label: String)] = [
            (
                "eyeInterval",
                L10n.format(
                    "prefs.numberInputAccessibilityLabel",
                    L10n.tr("prefs.everyMinutes"),
                    L10n.tr("prefs.unitAccessibility.minutes")
                )
            ),
            (
                "eyeDuration",
                L10n.format(
                    "prefs.numberInputAccessibilityLabel",
                    L10n.tr("prefs.durationSeconds"),
                    L10n.tr("prefs.unitAccessibility.seconds")
                )
            ),
            (
                "bodyInterval",
                L10n.format(
                    "prefs.numberInputAccessibilityLabel",
                    L10n.tr("prefs.bodyIntervalMinutes"),
                    L10n.tr("prefs.unitAccessibility.minutes")
                )
            ),
            (
                "bodyPostponeWindowPercent",
                L10n.format(
                    "prefs.numberInputAccessibilityLabel",
                    L10n.tr("prefs.postponeWindowPercent"),
                    L10n.tr("prefs.unitAccessibility.percent")
                )
            )
        ]

        for expected in expectedLabels {
            let field = try XCTUnwrap(view(withIdentifier: "\(expected.identifier)Field", in: contentView) as? NSControl)
            let stepper = try XCTUnwrap(view(withIdentifier: "\(expected.identifier)Stepper", in: contentView) as? NSControl)
            XCTAssertEqual(field.accessibilityLabel(), expected.label, expected.identifier)
            XCTAssertEqual(stepper.accessibilityLabel(), expected.label, expected.identifier)

            if let slider = view(withIdentifier: "\(expected.identifier)Slider", in: contentView) as? NSControl {
                XCTAssertEqual(slider.accessibilityLabel(), expected.label, expected.identifier)
            }
        }
    }

    func testManualNumberEntryClampsAndSynchronizesSlider() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        let slider = try XCTUnwrap(view(withIdentifier: "eyeDurationSlider", in: contentView) as? NSSlider)
        let field = try XCTUnwrap(view(withIdentifier: "eyeDurationField", in: contentView) as? NSTextField)
        let stepper = try XCTUnwrap(view(withIdentifier: "eyeDurationStepper", in: contentView) as? NSStepper)

        field.stringValue = "999"
        controller.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: field))

        XCTAssertEqual(field.stringValue, "300")
        XCTAssertEqual(slider.doubleValue, 300)
        XCTAssertEqual(stepper.doubleValue, 300)
    }

    func testDisablingRestTypeDisablesAssociatedScheduleSliders() throws {
        var settings = RestSettings.defaults
        settings.eyeGate.isEnabled = false
        settings.bodyBreak.isEnabled = true
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        let eyeIntervalSlider = try XCTUnwrap(view(withIdentifier: "eyeIntervalSlider", in: contentView) as? NSSlider)
        let bodyIntervalSlider = try XCTUnwrap(view(withIdentifier: "bodyIntervalSlider", in: contentView) as? NSSlider)

        XCTAssertFalse(eyeIntervalSlider.isEnabled)
        XCTAssertTrue(bodyIntervalSlider.isEnabled)
    }

    private func sendAction(from control: NSControl) -> Bool {
        guard let action = control.action else { return false }
        return NSApplication.shared.sendAction(action, to: control.target, from: control)
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
}

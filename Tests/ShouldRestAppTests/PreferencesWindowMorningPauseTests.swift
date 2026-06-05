import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowMorningPauseTests: XCTestCase {
    func testMorningPauseSummaryExplainsFixedResumeHour() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        var settings = RestSettings.defaults
        settings.operations.pauseUntilMorningMode = .hour
        settings.operations.pauseUntilMorningHour = 9
        let now = try fixedNow()
        let controller = PreferencesWindowController(settings: settings, nowProvider: { now }, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)
        let summary = try XCTUnwrap(view(withIdentifier: "prefs.pauseUntilMorningSummaryLabel", in: contentView) as? NSTextField)

        XCTAssertEqual(
            summary.stringValue,
            expectedMorningSummary(
                ruleSummary: L10n.format("prefs.morningSummary.hour", "09:00"),
                now: now,
                hour: 9,
                mode: .hour
            )
        )
        XCTAssertEqual(summary.toolTip, summary.stringValue)
        XCTAssertEqual(summary.accessibilityLabel(), summary.stringValue)
        XCTAssertEqual(summary.accessibilityHelp(), summary.stringValue)
        XCTAssertTrue(visibleTexts(in: contentView).contains(summary.stringValue))
    }

    func testFixedHourMorningModeHidesSunriseLocationFields() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)

        XCTAssertTrue(try row("prefs.pauseUntilMorningLocationRow", in: contentView).isHidden)
        XCTAssertFalse(try row("prefs.pauseUntilMorningHourRow", in: contentView).isHidden)
        XCTAssertTrue(try row("prefs.pauseUntilMorningLatitudeRow", in: contentView).isHidden)
        XCTAssertTrue(try row("prefs.pauseUntilMorningLongitudeRow", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.pauseUntilMorningHour")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.pauseUntilMorningLocation")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.pauseUntilMorningLatitude")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.pauseUntilMorningLongitude")))
    }

    func testSunriseMorningModeShowsLocationPresetAndAutosavesMode() throws {
        var settings = RestSettings.defaults
        settings.operations.pauseUntilMorningMode = .hour
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)
        let popup = try XCTUnwrap(view(withIdentifier: "prefs.pauseUntilMorningMode", in: contentView) as? NSPopUpButton)
        selectPopup(popup, representedObject: MorningPauseMode.sunrise.rawValue)

        XCTAssertTrue(sendAction(from: popup))

        XCTAssertTrue(try row("prefs.pauseUntilMorningHourRow", in: contentView).isHidden)
        XCTAssertFalse(try row("prefs.pauseUntilMorningLocationRow", in: contentView).isHidden)
        XCTAssertTrue(try row("prefs.pauseUntilMorningLatitudeRow", in: contentView).isHidden)
        XCTAssertTrue(try row("prefs.pauseUntilMorningLongitudeRow", in: contentView).isHidden)

        let visibleTexts = visibleTexts(in: contentView)
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.pauseUntilMorningHour")))
        XCTAssertTrue(visibleTexts.contains(L10n.tr("prefs.pauseUntilMorningLocation")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.pauseUntilMorningLatitude")))
        XCTAssertFalse(visibleTexts.contains(L10n.tr("prefs.pauseUntilMorningLongitude")))

        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.operations.pauseUntilMorningMode, .sunrise)
        XCTAssertNotEqual(savedSettings.value?.operations.pauseUntilMorningLatitude, 0)
        XCTAssertNotEqual(savedSettings.value?.operations.pauseUntilMorningLongitude, 0)
    }

    func testSunriseLocationCopyNamesCityAndEstimatePurpose() throws {
        defer { L10n.languageOverride = nil }

        L10n.languageOverride = "en"
        XCTAssertEqual(L10n.tr("prefs.pauseUntilMorningLocation"), "Sunrise city")
        XCTAssertEqual(
            L10n.tr("prefs.pauseUntilMorningLocationHelp"),
            "Choose the city used to estimate sunrise for Pause Until Morning."
        )
        XCTAssertNotEqual(L10n.tr("prefs.pauseUntilMorningLocation"), "Use sunrise for")

        var settings = RestSettings.defaults
        settings.operations.pauseUntilMorningMode = .sunrise
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)
        try selectAdvancedTab(in: contentView)
        let location = try XCTUnwrap(view(withIdentifier: "prefs.pauseUntilMorningLocation", in: contentView) as? NSPopUpButton)

        XCTAssertEqual(location.accessibilityLabel(), L10n.tr("prefs.pauseUntilMorningLocation"))
        XCTAssertEqual(location.accessibilityHelp(), L10n.tr("prefs.pauseUntilMorningLocationHelp"))
        XCTAssertEqual(location.toolTip, L10n.tr("prefs.pauseUntilMorningLocationHelp"))

        L10n.languageOverride = "zh-Hans"
        XCTAssertEqual(L10n.tr("prefs.pauseUntilMorningLocation"), "日出城市")
        XCTAssertEqual(
            L10n.tr("prefs.pauseUntilMorningLocationHelp"),
            "选择用于估算“暂停到早晨”日出的城市。"
        )
    }

    func testMorningPauseSummaryTracksSunrisePresetSelection() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        var settings = RestSettings.defaults
        settings.operations.pauseUntilMorningMode = .sunrise
        settings.operations.pauseUntilMorningLatitude = 12.34
        settings.operations.pauseUntilMorningLongitude = 56.78
        let now = try fixedNow()
        let controller = PreferencesWindowController(settings: settings, nowProvider: { now }, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)
        let popup = try XCTUnwrap(view(withIdentifier: "prefs.pauseUntilMorningLocation", in: contentView) as? NSPopUpButton)
        selectPopup(popup, representedObject: "tokyo")

        XCTAssertTrue(sendAction(from: popup))

        let summary = try XCTUnwrap(view(withIdentifier: "prefs.pauseUntilMorningSummaryLabel", in: contentView) as? NSTextField)
        XCTAssertEqual(
            summary.stringValue,
            expectedMorningSummary(
                ruleSummary: L10n.format(
                    "prefs.morningSummary.sunrisePreset",
                    L10n.tr("prefs.sunriseLocation.tokyo")
                ),
                now: now,
                mode: .sunrise,
                latitude: 35.6762,
                longitude: 139.6503
            )
        )
        XCTAssertEqual(summary.accessibilityLabel(), summary.stringValue)
    }

    func testSunriseCustomCoordinatesShowLatitudeAndLongitudeRows() throws {
        var settings = RestSettings.defaults
        settings.operations.pauseUntilMorningMode = .sunrise
        settings.operations.pauseUntilMorningLatitude = 12.34
        settings.operations.pauseUntilMorningLongitude = 56.78
        let now = try fixedNow()
        let controller = PreferencesWindowController(settings: settings, nowProvider: { now }, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)

        XCTAssertTrue(try row("prefs.pauseUntilMorningHourRow", in: contentView).isHidden)
        XCTAssertFalse(try row("prefs.pauseUntilMorningLocationRow", in: contentView).isHidden)
        XCTAssertFalse(try row("prefs.pauseUntilMorningLatitudeRow", in: contentView).isHidden)
        XCTAssertFalse(try row("prefs.pauseUntilMorningLongitudeRow", in: contentView).isHidden)

        let locationPopup = try XCTUnwrap(view(withIdentifier: "prefs.pauseUntilMorningLocation", in: contentView) as? NSPopUpButton)
        XCTAssertEqual(locationPopup.selectedItem?.representedObject as? String, "custom")
    }

    func testMorningPauseSummaryTracksCustomSunriseCoordinatesWhileEditing() throws {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        var settings = RestSettings.defaults
        settings.operations.pauseUntilMorningMode = .sunrise
        settings.operations.pauseUntilMorningLatitude = 12.34
        settings.operations.pauseUntilMorningLongitude = 56.78
        let now = try fixedNow()
        let controller = PreferencesWindowController(settings: settings, nowProvider: { now }, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)
        let latitudeField = try XCTUnwrap(view(withIdentifier: "prefs.pauseUntilMorningLatitudeField", in: contentView) as? NSTextField)
        let longitudeField = try XCTUnwrap(view(withIdentifier: "prefs.pauseUntilMorningLongitudeField", in: contentView) as? NSTextField)
        let summary = try XCTUnwrap(view(withIdentifier: "prefs.pauseUntilMorningSummaryLabel", in: contentView) as? NSTextField)

        XCTAssertEqual(
            summary.stringValue,
            expectedMorningSummary(
                ruleSummary: L10n.format("prefs.morningSummary.sunriseCustom", "12.3400", "56.7800"),
                now: now,
                mode: .sunrise,
                latitude: 12.34,
                longitude: 56.78
            )
        )
        XCTAssertEqual(summary.accessibilityLabel(), summary.stringValue)

        latitudeField.stringValue = "-33.8688"
        longitudeField.stringValue = "151.2093"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: latitudeField))
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: longitudeField))

        XCTAssertEqual(
            summary.stringValue,
            expectedMorningSummary(
                ruleSummary: L10n.format("prefs.morningSummary.sunriseCustom", "-33.8688", "151.2093"),
                now: now,
                mode: .sunrise,
                latitude: -33.8688,
                longitude: 151.2093
            )
        )
        XCTAssertEqual(summary.accessibilityLabel(), summary.stringValue)
    }

    private func fixedNow() throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-06-04T15:30:00+09:00"))
    }

    private func expectedMorningSummary(
        ruleSummary: String,
        now: Date,
        hour: Int = OperationsSettings.defaultPauseUntilMorningHour,
        mode: MorningPauseMode,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) -> String {
        let target = now.addingTimeInterval(OperationsSettings.secondsUntilMorning(
            from: now,
            morningHour: hour,
            mode: mode,
            latitude: latitude,
            longitude: longitude
        ))
        return L10n.format(
            "prefs.morningSummary.withEstimate",
            ruleSummary,
            target.formatted(date: .abbreviated, time: .shortened)
        )
    }

    func testSelectingSunrisePresetHidesCoordinatesAndAutosavesPresetCoordinates() throws {
        var settings = RestSettings.defaults
        settings.operations.pauseUntilMorningMode = .sunrise
        settings.operations.pauseUntilMorningLatitude = 12.34
        settings.operations.pauseUntilMorningLongitude = 56.78
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)
        let popup = try XCTUnwrap(view(withIdentifier: "prefs.pauseUntilMorningLocation", in: contentView) as? NSPopUpButton)
        selectPopup(popup, representedObject: "tokyo")

        XCTAssertTrue(sendAction(from: popup))

        XCTAssertFalse(try row("prefs.pauseUntilMorningLocationRow", in: contentView).isHidden)
        XCTAssertTrue(try row("prefs.pauseUntilMorningLatitudeRow", in: contentView).isHidden)
        XCTAssertTrue(try row("prefs.pauseUntilMorningLongitudeRow", in: contentView).isHidden)

        let latitudeField = try XCTUnwrap(view(withIdentifier: "prefs.pauseUntilMorningLatitudeField", in: contentView) as? NSTextField)
        let longitudeField = try XCTUnwrap(view(withIdentifier: "prefs.pauseUntilMorningLongitudeField", in: contentView) as? NSTextField)
        XCTAssertEqual(latitudeField.stringValue, "35.6762")
        XCTAssertEqual(longitudeField.stringValue, "139.6503")

        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(savedSettings.value?.operations.pauseUntilMorningLatitude, 35.6762)
        XCTAssertEqual(savedSettings.value?.operations.pauseUntilMorningLongitude, 139.6503)
    }

    func testMorningPauseControlsExposeRowTitlesAsAccessibilityLabels() throws {
        var settings = RestSettings.defaults
        settings.operations.pauseUntilMorningMode = .sunrise
        settings.operations.pauseUntilMorningLatitude = 12.34
        settings.operations.pauseUntilMorningLongitude = 56.78
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAdvancedTab(in: contentView)

        let mode = try XCTUnwrap(view(withIdentifier: "prefs.pauseUntilMorningMode", in: contentView) as? NSPopUpButton)
        let location = try XCTUnwrap(view(withIdentifier: "prefs.pauseUntilMorningLocation", in: contentView) as? NSPopUpButton)
        let latitude = try XCTUnwrap(view(withIdentifier: "prefs.pauseUntilMorningLatitudeField", in: contentView) as? NSTextField)
        let longitude = try XCTUnwrap(view(withIdentifier: "prefs.pauseUntilMorningLongitudeField", in: contentView) as? NSTextField)

        XCTAssertEqual(mode.accessibilityLabel(), L10n.tr("prefs.pauseUntilMorningMode"))
        XCTAssertEqual(location.accessibilityLabel(), L10n.tr("prefs.pauseUntilMorningLocation"))
        XCTAssertEqual(latitude.accessibilityLabel(), L10n.tr("prefs.pauseUntilMorningLatitude"))
        XCTAssertEqual(longitude.accessibilityLabel(), L10n.tr("prefs.pauseUntilMorningLongitude"))
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

    private func row(_ identifier: String, in rootView: NSView) throws -> NSView {
        try XCTUnwrap(view(withIdentifier: identifier, in: rootView))
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

    private func selectPopup(_ popup: NSPopUpButton, representedObject: String) {
        for index in 0..<popup.numberOfItems where popup.item(at: index)?.representedObject as? String == representedObject {
            popup.selectItem(at: index)
            return
        }
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

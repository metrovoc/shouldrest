import XCTest
import ShouldRestCore
@testable import shouldrest

final class PreferencesLanguageRefreshPolicyTests: XCTestCase {
    func testRefreshesVisiblePreferencesWhenNormalizedLanguageChanges() {
        var previous = RestSettings.defaults
        previous.presentation.languageIdentifier = nil
        var next = previous
        next.presentation.languageIdentifier = "zh-Hans"

        XCTAssertTrue(PreferencesLanguageRefreshPolicy.shouldRefreshPreferences(
            previousSettings: previous,
            nextSettings: next,
            isPreferencesWindowVisible: true
        ))
    }

    func testDoesNotRefreshHiddenPreferencesOrEquivalentLanguageValues() {
        var previous = RestSettings.defaults
        previous.presentation.languageIdentifier = nil
        var next = previous
        next.presentation.languageIdentifier = "zh-Hans"

        XCTAssertFalse(PreferencesLanguageRefreshPolicy.shouldRefreshPreferences(
            previousSettings: previous,
            nextSettings: next,
            isPreferencesWindowVisible: false
        ))

        var equivalentSystem = previous
        equivalentSystem.presentation.languageIdentifier = "  "
        XCTAssertFalse(PreferencesLanguageRefreshPolicy.shouldRefreshPreferences(
            previousSettings: previous,
            nextSettings: equivalentSystem,
            isPreferencesWindowVisible: true
        ))
    }
}

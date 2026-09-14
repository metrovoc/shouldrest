import Foundation
import XCTest
@testable import shouldrest

final class ReminderSoundPolicyTests: XCTestCase {
    func testSoundsRequireAwakeScreenAndNoFocusEvenWhenSchedulerContinues() {
        for silent in [false, true] {
            for suspended in [false, true] {
                for asleep in [false, true] {
                    for focus in [false, true] {
                        let allowed = ReminderSoundPolicy.allowsPlayback(
                            silentNotifications: silent,
                            systemSuspended: suspended,
                            displaysAsleep: asleep,
                            focusModeActive: focus
                        )
                        if silent || suspended || asleep || focus {
                            XCTAssertFalse(allowed)
                        } else {
                            XCTAssertTrue(allowed)
                        }
                    }
                }
            }
        }
    }

    func testSleepAndCustomFocusAssertionsAreActive() {
        for mode in ["com.apple.sleep.sleep-mode", "com.apple.focus.custom"] {
            let json = """
            {"data":[{"storeAssertionRecords":[{"assertionDetails":{
              "assertionDetailsModeIdentifier":"\(mode)"
            }}]}]}
            """
            XCTAssertEqual(FocusModeDetector.activeFocusFromAssertions(Data(json.utf8)), true)
        }
    }

    func testInactiveFocusIgnoresInvalidatedAssertions() {
        let json = """
        {"data":[{"storeAssertionRecords":[],"storeInvalidationRecords":[{
          "invalidationAssertion":{"assertionDetails":{
            "assertionDetailsModeIdentifier":"com.apple.sleep.sleep-mode"
          }}
        }]}]}
        """
        XCTAssertEqual(FocusModeDetector.activeFocusFromAssertions(Data(json.utf8)), false)
    }

    func testUnreadableOrUnknownFormatAllowsFallback() {
        for json in ["invalid", "{}", "{\"data\":[]}", "{\"data\":[{}]}"] {
            XCTAssertNil(FocusModeDetector.activeFocusFromAssertions(Data(json.utf8)))
        }
    }
}

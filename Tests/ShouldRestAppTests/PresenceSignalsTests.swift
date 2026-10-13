import Foundation
import XCTest
@testable import shouldrest

final class PresenceSignalsTests: XCTestCase {
    func testDisplayAssertionFromPlaybackMeansScreenIsWatched() {
        let assertions: [NSNumber: [[String: Any]]] = [
            501: [[
                "AssertType": "PreventUserIdleDisplaySleep",
                "AssertName": "Video Wake Lock",
                "AssertLevel": 255,
                "Process Name": "Google Chrome Helper"
            ]]
        ]

        XCTAssertTrue(ScreenAttentionDetector.isScreenWatched(assertionsByProcess: assertions, ownProcessIdentifier: 42))
    }

    func testSystemSleepAssertionsAndKeepAwakeUtilitiesDoNotMeanScreenIsWatched() {
        let assertions: [NSNumber: [[String: Any]]] = [
            758: [[
                "AssertType": "NoIdleSleepAssertion",
                "AssertName": "Electron",
                "AssertLevel": 255,
                "Process Name": "ChatGPT"
            ]],
            66594: [[
                "AssertType": "PreventUserIdleDisplaySleep",
                "AssertName": "caffeinate command-line tool",
                "AssertLevel": 255,
                "Process Name": "caffeinate"
            ]],
            900: [[
                "AssertType": "PreventUserIdleDisplaySleep",
                "AssertName": "Amphetamine",
                "AssertLevel": 255,
                "Process Name": "Amphetamine"
            ]],
            901: [[
                "AssertType": "PreventUserIdleDisplaySleep",
                "AssertName": "Released",
                "AssertLevel": 0,
                "Process Name": "QuickTime Player"
            ]]
        ]

        XCTAssertFalse(ScreenAttentionDetector.isScreenWatched(assertionsByProcess: assertions, ownProcessIdentifier: 42))
    }

    func testOwnDisplayAssertionDoesNotMeanScreenIsWatched() {
        let assertions: [NSNumber: [[String: Any]]] = [
            42: [[
                "AssertType": "PreventUserIdleDisplaySleep",
                "AssertLevel": 255,
                "Process Name": "shouldrest"
            ]]
        ]

        XCTAssertFalse(ScreenAttentionDetector.isScreenWatched(assertionsByProcess: assertions, ownProcessIdentifier: 42))
    }
}

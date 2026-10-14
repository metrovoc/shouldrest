import CoreAudio
import Foundation
import XCTest
@testable import shouldrest

final class PresenceSignalsTests: XCTestCase {
    func testOutputOnlyAudioDoesNotCountAsACall() {
        XCTAssertFalse(MicrophoneActivityDetector.isInUse(processes: [42]) { _, selector in
            selector == kAudioProcessPropertyIsRunningInput ? 0 : 1
        })
    }

    func testActiveInputCountsAsACallEvenWithOtherUnreadableProcesses() {
        XCTAssertTrue(MicrophoneActivityDetector.isInUse(processes: [41, 42]) { process, selector in
            guard process == 42, selector == kAudioProcessPropertyIsRunningInput else { return nil }
            return 1
        })
        XCTAssertFalse(MicrophoneActivityDetector.isInUse(processes: [41]) { _, _ in nil })
    }

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

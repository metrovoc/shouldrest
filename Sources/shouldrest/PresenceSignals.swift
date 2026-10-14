import CoreAudio
import Foundation
import IOKit.pwr_mgt

/// Another app keeping the display awake (video playback, a call, a presentation) means the user is
/// probably watching the screen even without input. Keep-awake utilities hold the same assertion
/// without saying anything about attention, so they are ignored.
enum ScreenAttentionDetector {
    static let keepAwakeUtilityNames: Set<String> = [
        "amphetamine",
        "caffeinate",
        "caffeine",
        "keepingyouawake",
        "lungo",
        "owly",
        "theine"
    ]

    private static let displayAssertionTypes: Set<String> = [
        "PreventUserIdleDisplaySleep",
        "NoDisplaySleepAssertion"
    ]

    static func isScreenWatched() -> Bool {
        var assertionsByProcess: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&assertionsByProcess) == kIOReturnSuccess,
              let assertions = assertionsByProcess?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else {
            return false
        }
        return isScreenWatched(
            assertionsByProcess: assertions,
            ownProcessIdentifier: ProcessInfo.processInfo.processIdentifier
        )
    }

    static func isScreenWatched(
        assertionsByProcess: [NSNumber: [[String: Any]]],
        ownProcessIdentifier: Int32
    ) -> Bool {
        assertionsByProcess.contains { processIdentifier, assertions in
            processIdentifier.int32Value != ownProcessIdentifier && assertions.contains(where: isWatchingAssertion)
        }
    }

    private static func isWatchingAssertion(_ assertion: [String: Any]) -> Bool {
        guard let type = assertion["AssertType"] as? String,
              displayAssertionTypes.contains(type) else {
            return false
        }
        if let level = assertion["AssertLevel"] as? Int, level == 0 {
            return false
        }
        let processName = (assertion["Process Name"] as? String ?? "").lowercased()
        return !keepAwakeUtilityNames.contains(processName)
    }
}

/// Active input streams indicate a possible call; output on a duplex device does not.
enum MicrophoneActivityDetector {
    static func isInUse() -> Bool {
        isInUse(processes: audioProcesses(), read: readUInt32)
    }

    static func isInUse(
        processes: [AudioObjectID],
        read: (AudioObjectID, AudioObjectPropertySelector) -> UInt32?
    ) -> Bool {
        processes.contains { read($0, kAudioProcessPropertyIsRunningInput) == 1 }
    }

    private static func audioProcesses() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else {
            return []
        }
        var processes = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &processes) == noErr else {
            return []
        }
        return Array(processes.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
    }

    private static func readUInt32(_ object: AudioObjectID, selector: AudioObjectPropertySelector) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }
}

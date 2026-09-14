import CoreGraphics

enum ReminderSoundPolicy {
    static func allowsPlayback(
        silentNotifications: Bool,
        systemSuspended: Bool,
        displaysAsleep: Bool,
        focusModeActive: Bool
    ) -> Bool {
        !silentNotifications && !systemSuspended && !displaysAsleep && !focusModeActive
    }
}

enum DisplaySleepDetector {
    static func allDisplaysAsleep() -> Bool {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return false }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &displays, &count) == .success else { return false }
        return count > 0 && displays.prefix(Int(count)).allSatisfy { CGDisplayIsAsleep($0) != 0 }
    }
}

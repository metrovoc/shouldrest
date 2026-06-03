import Foundation

public struct RestSettings: Codable, Equatable, Sendable {
    public var eyeGate: RestRule
    public var bodyBreak: RestRule
    public var bodyBreakAfterEyeGates: Int
    public var notifications: NotificationSettings
    public var naturalBreaks: NaturalBreakSettings
    public var focusMode: FocusModeSettings
    public var workingHours: WorkingHoursSettings
    public var appExclusions: [AppExclusionRule]
    public var contentLibrary: ContentLibrarySettings
    public var presentation: PresentationSettings
    public var shortcuts: ShortcutSettings
    public var operations: OperationsSettings
    public var admin: AdminSettings

    public init(
        eyeGate: RestRule,
        bodyBreak: RestRule,
        bodyBreakAfterEyeGates: Int,
        notifications: NotificationSettings,
        naturalBreaks: NaturalBreakSettings,
        focusMode: FocusModeSettings,
        workingHours: WorkingHoursSettings,
        appExclusions: [AppExclusionRule],
        contentLibrary: ContentLibrarySettings,
        presentation: PresentationSettings,
        shortcuts: ShortcutSettings,
        operations: OperationsSettings,
        admin: AdminSettings
    ) {
        self.eyeGate = eyeGate
        self.bodyBreak = bodyBreak
        self.bodyBreakAfterEyeGates = max(1, bodyBreakAfterEyeGates)
        self.notifications = notifications
        self.naturalBreaks = naturalBreaks
        self.focusMode = focusMode
        self.workingHours = workingHours
        self.appExclusions = appExclusions
        self.contentLibrary = contentLibrary
        self.presentation = presentation
        self.shortcuts = shortcuts
        self.operations = operations
        self.admin = admin
    }

    public static let defaults = RestSettings(
        eyeGate: .eyeGateDefault,
        bodyBreak: .bodyBreakDefault,
        bodyBreakAfterEyeGates: 2,
        notifications: .defaults,
        naturalBreaks: .defaults,
        focusMode: .defaults,
        workingHours: .always,
        appExclusions: [],
        contentLibrary: .defaults,
        presentation: .defaults,
        shortcuts: .defaults,
        operations: .defaults,
        admin: .defaults
    )

    public static var restoredDefaults: RestSettings {
        var settings = defaults
        settings.operations.hasCompletedOnboarding = true
        settings.operations.showOnboardingOnNextLaunch = false
        return settings
    }

    public func rule(for kind: RestKind) -> RestRule {
        switch kind {
        case .eyeGate:
            eyeGate
        case .bodyBreak:
            bodyBreak
        }
    }

    public func enforcingAtLeastOneEnabledRest() -> RestSettings {
        guard !eyeGate.isEnabled, !bodyBreak.isEnabled else { return self }
        var copy = self
        copy.eyeGate.isEnabled = true
        return copy
    }
}

public struct RestRule: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var interval: TimeInterval
    public var duration: TimeInterval
    public var ordinarySkipEnabled: Bool
    public var postpone: PostponePolicy
    public var manualFinishEnabled: Bool
    public var emergencyOverride: EmergencyOverridePolicy
    public var enforcement: EnforcementProfile
    public var content: RestContentPolicy
    public var colorHex: String
    public var startSound: SoundPolicy
    public var finishSound: SoundPolicy

    public init(
        isEnabled: Bool,
        interval: TimeInterval,
        duration: TimeInterval,
        ordinarySkipEnabled: Bool,
        postpone: PostponePolicy,
        manualFinishEnabled: Bool,
        emergencyOverride: EmergencyOverridePolicy,
        enforcement: EnforcementProfile,
        content: RestContentPolicy,
        colorHex: String,
        startSound: SoundPolicy,
        finishSound: SoundPolicy
    ) {
        self.isEnabled = isEnabled
        self.interval = max(1, interval)
        self.duration = max(1, duration)
        self.ordinarySkipEnabled = ordinarySkipEnabled
        self.postpone = postpone
        self.manualFinishEnabled = manualFinishEnabled
        self.emergencyOverride = emergencyOverride
        self.enforcement = enforcement
        self.content = content
        self.colorHex = colorHex
        self.startSound = startSound
        self.finishSound = finishSound
    }

    public static let eyeGateDefault = RestRule(
        isEnabled: true,
        interval: 20 * 60,
        duration: 20,
        ordinarySkipEnabled: false,
        postpone: .disabled,
        manualFinishEnabled: false,
        emergencyOverride: .defaults,
        enforcement: .eyeGateDefault,
        content: .minimalAwayFromScreen,
        colorHex: "#000000",
        startSound: .silent,
        finishSound: .named("crystal-glass", volume: 1)
    )

    public static let bodyBreakDefault = RestRule(
        isEnabled: true,
        interval: 20 * 60,
        duration: 5 * 60,
        ordinarySkipEnabled: true,
        postpone: PostponePolicy(isEnabled: true, duration: 5 * 60, maxCount: 1, allowedDuringFirstPercent: 30),
        manualFinishEnabled: true,
        emergencyOverride: .disabled,
        enforcement: .bodyBreakDefault,
        content: .richRestIdea,
        colorHex: "#478484",
        startSound: .silent,
        finishSound: .named("crystal-glass", volume: 1)
    )
}

public struct PostponePolicy: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var duration: TimeInterval
    public var maxCount: Int
    public var allowedDuringFirstPercent: Double

    public init(
        isEnabled: Bool,
        duration: TimeInterval,
        maxCount: Int,
        allowedDuringFirstPercent: Double
    ) {
        self.isEnabled = isEnabled
        self.duration = max(1, duration)
        self.maxCount = max(0, maxCount)
        self.allowedDuringFirstPercent = min(100, max(0, allowedDuringFirstPercent))
    }

    public static let disabled = PostponePolicy(
        isEnabled: false,
        duration: 1,
        maxCount: 0,
        allowedDuringFirstPercent: 0
    )
}

public struct EmergencyOverridePolicy: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var confirmationSteps: Int
    public var minimumHoldDuration: TimeInterval

    public init(isEnabled: Bool, confirmationSteps: Int, minimumHoldDuration: TimeInterval) {
        self.isEnabled = isEnabled
        self.confirmationSteps = max(0, confirmationSteps)
        self.minimumHoldDuration = max(0, minimumHoldDuration)
    }

    public static let defaults = EmergencyOverridePolicy(
        isEnabled: true,
        confirmationSteps: 2,
        minimumHoldDuration: 3
    )

    public static let disabled = EmergencyOverridePolicy(
        isEnabled: false,
        confirmationSteps: 0,
        minimumHoldDuration: 0
    )
}

public struct EnforcementProfile: Codable, Equatable, Sendable {
    public var coversAllDisplays: Bool
    public var usesScreenSaverLevel: Bool
    public var isOpaque: Bool
    public var opacity: Double
    public var allowRegularWindowMode: Bool
    public var coveredDisplay: DisplaySelection?
    public var contentDisplay: DisplaySelection
    public var blankSecondaryDisplays: Bool
    public var configuredDisplayIndex: Int?

    public init(
        coversAllDisplays: Bool,
        usesScreenSaverLevel: Bool,
        isOpaque: Bool,
        opacity: Double,
        allowRegularWindowMode: Bool,
        coveredDisplay: DisplaySelection? = nil,
        contentDisplay: DisplaySelection,
        blankSecondaryDisplays: Bool,
        configuredDisplayIndex: Int? = nil
    ) {
        self.coversAllDisplays = coversAllDisplays
        self.usesScreenSaverLevel = usesScreenSaverLevel
        self.isOpaque = isOpaque
        self.opacity = min(1, max(0, opacity))
        self.allowRegularWindowMode = allowRegularWindowMode
        self.coveredDisplay = coveredDisplay
        self.contentDisplay = contentDisplay
        self.blankSecondaryDisplays = blankSecondaryDisplays
        self.configuredDisplayIndex = configuredDisplayIndex.map { max(0, $0) }
    }

    public static let eyeGateDefault = EnforcementProfile(
        coversAllDisplays: true,
        usesScreenSaverLevel: true,
        isOpaque: true,
        opacity: 1,
        allowRegularWindowMode: false,
        contentDisplay: .primary,
        blankSecondaryDisplays: true
    )

    public static let bodyBreakDefault = EnforcementProfile(
        coversAllDisplays: true,
        usesScreenSaverLevel: true,
        isOpaque: true,
        opacity: 1,
        allowRegularWindowMode: false,
        contentDisplay: .all,
        blankSecondaryDisplays: false
    )
}

public enum DisplaySelection: String, Codable, Equatable, Sendable {
    case none
    case all
    case primary
    case cursor
    case configured
}

public enum RestContentPolicy: String, Codable, Equatable, Sendable {
    case minimalAwayFromScreen
    case richRestIdea
    case customRichText
    case localImage
    case blank
}

public enum SoundPolicy: Codable, Equatable, Sendable {
    case silent
    case named(String, volume: Double)
}

public struct NotificationSettings: Codable, Equatable, Sendable {
    public var eyeGateEnabled: Bool
    public var bodyBreakEnabled: Bool
    public var eyeGateLeadTime: TimeInterval
    public var bodyBreakLeadTime: TimeInterval
    public var silentNotifications: Bool

    public init(
        eyeGateEnabled: Bool,
        bodyBreakEnabled: Bool,
        eyeGateLeadTime: TimeInterval,
        bodyBreakLeadTime: TimeInterval,
        silentNotifications: Bool
    ) {
        self.eyeGateEnabled = eyeGateEnabled
        self.bodyBreakEnabled = bodyBreakEnabled
        self.eyeGateLeadTime = max(0, eyeGateLeadTime)
        self.bodyBreakLeadTime = max(0, bodyBreakLeadTime)
        self.silentNotifications = silentNotifications
    }

    public static let defaults = NotificationSettings(
        eyeGateEnabled: true,
        bodyBreakEnabled: true,
        eyeGateLeadTime: 10,
        bodyBreakLeadTime: 30,
        silentNotifications: false
    )

    public func isEnabled(for kind: RestKind) -> Bool {
        switch kind {
        case .eyeGate:
            eyeGateEnabled
        case .bodyBreak:
            bodyBreakEnabled
        }
    }

    public func leadTime(for kind: RestKind) -> TimeInterval {
        switch kind {
        case .eyeGate:
            eyeGateLeadTime
        case .bodyBreak:
            bodyBreakLeadTime
        }
    }
}

public struct NaturalBreakSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var inactivityResetTime: TimeInterval

    public init(isEnabled: Bool, inactivityResetTime: TimeInterval) {
        self.isEnabled = isEnabled
        self.inactivityResetTime = max(1, inactivityResetTime)
    }

    public static let defaults = NaturalBreakSettings(
        isEnabled: true,
        inactivityResetTime: 5 * 60
    )
}

public struct FocusModeSettings: Codable, Equatable, Sendable {
    public var monitorFocusMode: Bool
    public var deferEyeGate: Bool
    public var deferBodyBreak: Bool

    public init(monitorFocusMode: Bool, deferEyeGate: Bool, deferBodyBreak: Bool) {
        self.monitorFocusMode = monitorFocusMode
        self.deferEyeGate = deferEyeGate
        self.deferBodyBreak = deferBodyBreak
    }

    public static let defaults = FocusModeSettings(
        monitorFocusMode: true,
        deferEyeGate: false,
        deferBodyBreak: true
    )

    public func defers(_ kind: RestKind) -> Bool {
        switch kind {
        case .eyeGate:
            deferEyeGate
        case .bodyBreak:
            deferBodyBreak
        }
    }
}

public struct WorkingHoursSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var startMinuteOfDay: Int
    public var endMinuteOfDay: Int

    public init(isEnabled: Bool, startMinuteOfDay: Int, endMinuteOfDay: Int) {
        self.isEnabled = isEnabled
        self.startMinuteOfDay = min(1_439, max(0, startMinuteOfDay))
        self.endMinuteOfDay = min(1_439, max(0, endMinuteOfDay))
    }

    public static let always = WorkingHoursSettings(
        isEnabled: false,
        startMinuteOfDay: 9 * 60,
        endMinuteOfDay: 18 * 60
    )

    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard isEnabled else { return true }
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        if startMinuteOfDay <= endMinuteOfDay {
            return minute >= startMinuteOfDay && minute < endMinuteOfDay
        }
        return minute >= startMinuteOfDay || minute < endMinuteOfDay
    }
}

public struct AppExclusionRule: Codable, Equatable, Identifiable, Sendable {
    public enum Mode: String, Codable, CaseIterable, Equatable, Sendable {
        case pauseWhenMatched
        case resumeOnlyWhenMatched
    }

    public var id: String
    public var name: String
    public var matchTerms: [String]
    public var mode: Mode
    public var appliesTo: Set<RestKind>
    public var isEnabled: Bool

    public init(
        id: String,
        name: String,
        matchTerms: [String],
        mode: Mode,
        appliesTo: Set<RestKind>,
        isEnabled: Bool
    ) {
        self.id = id
        self.name = name
        self.matchTerms = matchTerms
        self.mode = mode
        self.appliesTo = appliesTo
        self.isEnabled = isEnabled
    }
}

public struct AppExclusionEvaluation: Equatable, Sendable {
    public var rule: AppExclusionRule
    public var isMatched: Bool

    public init(rule: AppExclusionRule, isMatched: Bool) {
        self.rule = rule
        self.isMatched = isMatched
    }
}

public struct PresentationSettings: Codable, Equatable, Sendable {
    public var themeSource: ThemeSource
    public var trayIconStyle: TrayIconStyle
    public var showCurrentTimeDuringBodyBreak: Bool
    public var breakHealthMode: Bool
    public var showMenuBarItem: Bool?
    public var languageIdentifier: String?

    public init(
        themeSource: ThemeSource,
        trayIconStyle: TrayIconStyle,
        showCurrentTimeDuringBodyBreak: Bool,
        breakHealthMode: Bool,
        showMenuBarItem: Bool? = nil,
        languageIdentifier: String? = nil
    ) {
        self.themeSource = themeSource
        self.trayIconStyle = trayIconStyle
        self.showCurrentTimeDuringBodyBreak = showCurrentTimeDuringBodyBreak
        self.breakHealthMode = breakHealthMode
        self.showMenuBarItem = showMenuBarItem
        self.languageIdentifier = languageIdentifier
    }

    public static let defaults = PresentationSettings(
        themeSource: .system,
        trayIconStyle: .default,
        showCurrentTimeDuringBodyBreak: false,
        breakHealthMode: true,
        showMenuBarItem: true,
        languageIdentifier: nil
    )

    public var resolvedShowMenuBarItem: Bool {
        true
    }
}

public enum ThemeSource: String, Codable, CaseIterable, Equatable, Sendable {
    case system
    case light
    case dark
}

public enum TrayIconStyle: String, Codable, CaseIterable, Equatable, Sendable {
    case `default`
    case appName
    case timeToBreak
    case progress
}

public struct ShortcutSettings: Codable, Equatable, Sendable {
    public static let defaultEndBodyBreakShortcut = "CmdOrCtrl+X"
    public static let defaultEmergencyEyeGateOverride = "CmdOrCtrl+Option+E"

    public var pauseToggle: String
    public var pauseFor30Minutes: String
    public var pauseFor1Hour: String
    public var pauseFor2Hours: String
    public var pauseFor5Hours: String
    public var pauseUntilMorning: String
    public var skipToNextScheduledRest: String?
    public var takeEyeGateNow: String
    public var takeBodyBreakNow: String
    public var skipToNextBodyBreak: String
    public var endBodyBreak: String?
    public var emergencyEyeGateOverride: String?
    public var reset: String

    public var resolvedEndBodyBreakShortcut: String {
        endBodyBreak ?? Self.defaultEndBodyBreakShortcut
    }

    public var resolvedEmergencyEyeGateOverride: String {
        emergencyEyeGateOverride ?? Self.defaultEmergencyEyeGateOverride
    }

    public init(
        pauseToggle: String,
        pauseFor30Minutes: String,
        pauseFor1Hour: String,
        pauseFor2Hours: String,
        pauseFor5Hours: String,
        pauseUntilMorning: String,
        skipToNextScheduledRest: String? = nil,
        takeEyeGateNow: String,
        takeBodyBreakNow: String,
        skipToNextBodyBreak: String,
        endBodyBreak: String? = nil,
        emergencyEyeGateOverride: String? = nil,
        reset: String
    ) {
        self.pauseToggle = pauseToggle
        self.pauseFor30Minutes = pauseFor30Minutes
        self.pauseFor1Hour = pauseFor1Hour
        self.pauseFor2Hours = pauseFor2Hours
        self.pauseFor5Hours = pauseFor5Hours
        self.pauseUntilMorning = pauseUntilMorning
        self.skipToNextScheduledRest = skipToNextScheduledRest
        self.takeEyeGateNow = takeEyeGateNow
        self.takeBodyBreakNow = takeBodyBreakNow
        self.skipToNextBodyBreak = skipToNextBodyBreak
        self.endBodyBreak = endBodyBreak
        self.emergencyEyeGateOverride = emergencyEyeGateOverride
        self.reset = reset
    }

    public static let defaults = ShortcutSettings(
        pauseToggle: "",
        pauseFor30Minutes: "",
        pauseFor1Hour: "",
        pauseFor2Hours: "",
        pauseFor5Hours: "",
        pauseUntilMorning: "",
        takeEyeGateNow: "",
        takeBodyBreakNow: "",
        skipToNextBodyBreak: "",
        endBodyBreak: defaultEndBodyBreakShortcut,
        emergencyEyeGateOverride: defaultEmergencyEyeGateOverride,
        reset: ""
    )
}

public struct OperationsSettings: Codable, Equatable, Sendable {
    public static let defaultPauseUntilMorningHour = 6

    public var openAtLogin: Bool
    public var checkForUpdates: Bool
    public var notifyNewVersion: Bool
    public var updateFeedURL: String
    public var hasCompletedOnboarding: Bool
    public var showOnboardingOnNextLaunch: Bool?
    public var pauseUntilMorningHour: Int?
    public var pauseUntilMorningMode: MorningPauseMode?
    public var pauseUntilMorningLatitude: Double?
    public var pauseUntilMorningLongitude: Double?
    public var pauseForSuspendOrLock: Bool?

    public init(
        openAtLogin: Bool,
        checkForUpdates: Bool,
        notifyNewVersion: Bool,
        updateFeedURL: String,
        hasCompletedOnboarding: Bool,
        showOnboardingOnNextLaunch: Bool? = nil,
        pauseUntilMorningHour: Int? = nil,
        pauseUntilMorningMode: MorningPauseMode? = nil,
        pauseUntilMorningLatitude: Double? = nil,
        pauseUntilMorningLongitude: Double? = nil,
        pauseForSuspendOrLock: Bool? = nil
    ) {
        self.openAtLogin = openAtLogin
        self.checkForUpdates = checkForUpdates
        self.notifyNewVersion = notifyNewVersion
        self.updateFeedURL = updateFeedURL
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.showOnboardingOnNextLaunch = showOnboardingOnNextLaunch
        self.pauseUntilMorningHour = pauseUntilMorningHour.map(Self.normalizedMorningHour)
        self.pauseUntilMorningMode = pauseUntilMorningMode
        self.pauseUntilMorningLatitude = pauseUntilMorningLatitude.map { min(89.8, max(-89.8, $0)) }
        self.pauseUntilMorningLongitude = pauseUntilMorningLongitude.map(Self.normalizedLongitude)
        self.pauseForSuspendOrLock = pauseForSuspendOrLock
    }

    public static let defaults = OperationsSettings(
        openAtLogin: false,
        checkForUpdates: true,
        notifyNewVersion: true,
        updateFeedURL: "https://api.github.com/repos/metrovoc/shouldrest/releases/latest",
        hasCompletedOnboarding: false,
        showOnboardingOnNextLaunch: false,
        pauseUntilMorningHour: defaultPauseUntilMorningHour,
        pauseUntilMorningMode: .hour,
        pauseUntilMorningLatitude: 0,
        pauseUntilMorningLongitude: 0,
        pauseForSuspendOrLock: true
    )

    public var resolvedPauseUntilMorningHour: Int {
        Self.normalizedMorningHour(pauseUntilMorningHour ?? Self.defaultPauseUntilMorningHour)
    }

    public var resolvedPauseUntilMorningMode: MorningPauseMode {
        pauseUntilMorningMode ?? .hour
    }

    public var resolvedPauseForSuspendOrLock: Bool {
        pauseForSuspendOrLock ?? true
    }

    public var resolvedShowOnboardingOnNextLaunch: Bool {
        showOnboardingOnNextLaunch ?? false
    }

    public func secondsUntilMorning(from now: Date = Date(), calendar: Calendar = .current) -> TimeInterval {
        Self.secondsUntilMorning(
            from: now,
            calendar: calendar,
            morningHour: resolvedPauseUntilMorningHour,
            mode: resolvedPauseUntilMorningMode,
            latitude: pauseUntilMorningLatitude,
            longitude: pauseUntilMorningLongitude
        )
    }

    public static func secondsUntilMorning(
        from now: Date = Date(),
        calendar: Calendar = .current,
        morningHour: Int? = nil,
        mode: MorningPauseMode? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) -> TimeInterval {
        if (mode ?? .hour) == .sunrise,
           let target = nextSunrise(from: now, calendar: calendar, latitude: latitude ?? 0, longitude: longitude ?? 0) {
            return max(1, target.timeIntervalSince(now))
        }

        let hour = normalizedMorningHour(morningHour ?? defaultPauseUntilMorningHour)
        let sameDayTarget = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now)
            ?? now.addingTimeInterval(24 * 60 * 60)
        let target = sameDayTarget > now
            ? sameDayTarget
            : calendar.date(byAdding: .day, value: 1, to: sameDayTarget) ?? sameDayTarget.addingTimeInterval(24 * 60 * 60)
        return max(1, target.timeIntervalSince(now))
    }

    private static func normalizedMorningHour(_ hour: Int) -> Int {
        min(23, max(0, hour))
    }

    private static func nextSunrise(from now: Date, calendar: Calendar, latitude: Double, longitude: Double) -> Date? {
        for dayOffset in 0...3 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let sunrise = sunrise(on: day, calendar: calendar, latitude: latitude, longitude: longitude) else {
                continue
            }
            if sunrise > now {
                return sunrise
            }
        }
        return nil
    }

    private static func sunrise(on day: Date, calendar: Calendar, latitude: Double, longitude: Double) -> Date? {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayOfYear = calendar.ordinality(of: .day, in: .year, for: dayStart) else {
            return nil
        }

        let lat = min(89.8, max(-89.8, latitude))
        let lon = normalizedLongitude(longitude)
        let zenith = 90.833
        let longitudeHour = lon / 15
        let approximateTime = Double(dayOfYear) + ((6 - longitudeHour) / 24)
        let meanAnomaly = (0.9856 * approximateTime) - 3.289
        let trueLongitude = normalizedDegrees(
            meanAnomaly
                + (1.916 * sin(degreesToRadians(meanAnomaly)))
                + (0.020 * sin(2 * degreesToRadians(meanAnomaly)))
                + 282.634
        )
        var rightAscension = radiansToDegrees(atan(0.91764 * tan(degreesToRadians(trueLongitude))))
        rightAscension = normalizedDegrees(rightAscension)
        let longitudeQuadrant = floor(trueLongitude / 90) * 90
        let ascensionQuadrant = floor(rightAscension / 90) * 90
        rightAscension = (rightAscension + longitudeQuadrant - ascensionQuadrant) / 15

        let sinDeclination = 0.39782 * sin(degreesToRadians(trueLongitude))
        let cosDeclination = cos(asin(sinDeclination))
        let cosHourAngle = (
            cos(degreesToRadians(zenith)) - (sinDeclination * sin(degreesToRadians(lat)))
        ) / (cosDeclination * cos(degreesToRadians(lat)))
        guard cosHourAngle >= -1, cosHourAngle <= 1 else {
            return nil
        }

        let localHourAngle = (360 - radiansToDegrees(acos(cosHourAngle))) / 15
        let localMeanTime = localHourAngle + rightAscension - (0.06571 * approximateTime) - 6.622
        let utcHours = normalizedHours(localMeanTime - longitudeHour)
        let offsetHours = Double(calendar.timeZone.secondsFromGMT(for: dayStart)) / 3600
        let localHours = normalizedHours(utcHours + offsetHours)
        return dayStart.addingTimeInterval(localHours * 60 * 60)
    }

    private static func normalizedLongitude(_ longitude: Double) -> Double {
        var value = longitude.truncatingRemainder(dividingBy: 360)
        if value > 180 {
            value -= 360
        } else if value < -180 {
            value += 360
        }
        return value
    }

    private static func normalizedDegrees(_ degrees: Double) -> Double {
        var value = degrees.truncatingRemainder(dividingBy: 360)
        if value < 0 {
            value += 360
        }
        return value
    }

    private static func normalizedHours(_ hours: Double) -> Double {
        var value = hours.truncatingRemainder(dividingBy: 24)
        if value < 0 {
            value += 24
        }
        return value
    }

    private static func degreesToRadians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    private static func radiansToDegrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }
}

public enum MorningPauseMode: String, Codable, CaseIterable, Equatable, Sendable {
    case hour
    case sunrise
}

public struct AdminSettings: Codable, Equatable, Sendable {
    public var disableAppUpdateFeatures: Bool
    public var hideSettingsFileLocation: Bool
    public var hideStrictPreferences: Bool
    public var customPreferencesMessage: String

    public init(
        disableAppUpdateFeatures: Bool,
        hideSettingsFileLocation: Bool,
        hideStrictPreferences: Bool,
        customPreferencesMessage: String
    ) {
        self.disableAppUpdateFeatures = disableAppUpdateFeatures
        self.hideSettingsFileLocation = hideSettingsFileLocation
        self.hideStrictPreferences = hideStrictPreferences
        self.customPreferencesMessage = customPreferencesMessage
    }

    public static let defaults = AdminSettings(
        disableAppUpdateFeatures: false,
        hideSettingsFileLocation: false,
        hideStrictPreferences: false,
        customPreferencesMessage: ""
    )
}

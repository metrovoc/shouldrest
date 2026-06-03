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

    public func rule(for kind: RestKind) -> RestRule {
        switch kind {
        case .eyeGate:
            eyeGate
        case .bodyBreak:
            bodyBreak
        }
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

    public init(
        themeSource: ThemeSource,
        trayIconStyle: TrayIconStyle,
        showCurrentTimeDuringBodyBreak: Bool,
        breakHealthMode: Bool
    ) {
        self.themeSource = themeSource
        self.trayIconStyle = trayIconStyle
        self.showCurrentTimeDuringBodyBreak = showCurrentTimeDuringBodyBreak
        self.breakHealthMode = breakHealthMode
    }

    public static let defaults = PresentationSettings(
        themeSource: .system,
        trayIconStyle: .default,
        showCurrentTimeDuringBodyBreak: false,
        breakHealthMode: true
    )
}

public enum ThemeSource: String, Codable, CaseIterable, Equatable, Sendable {
    case system
    case light
    case dark
}

public enum TrayIconStyle: String, Codable, CaseIterable, Equatable, Sendable {
    case `default`
    case timeToBreak
    case progress
}

public struct ShortcutSettings: Codable, Equatable, Sendable {
    public var pauseToggle: String
    public var pauseFor30Minutes: String
    public var pauseFor1Hour: String
    public var pauseFor2Hours: String
    public var pauseFor5Hours: String
    public var pauseUntilMorning: String
    public var takeEyeGateNow: String
    public var takeBodyBreakNow: String
    public var skipToNextBodyBreak: String
    public var emergencyEyeGateOverride: String?
    public var reset: String

    public init(
        pauseToggle: String,
        pauseFor30Minutes: String,
        pauseFor1Hour: String,
        pauseFor2Hours: String,
        pauseFor5Hours: String,
        pauseUntilMorning: String,
        takeEyeGateNow: String,
        takeBodyBreakNow: String,
        skipToNextBodyBreak: String,
        emergencyEyeGateOverride: String? = nil,
        reset: String
    ) {
        self.pauseToggle = pauseToggle
        self.pauseFor30Minutes = pauseFor30Minutes
        self.pauseFor1Hour = pauseFor1Hour
        self.pauseFor2Hours = pauseFor2Hours
        self.pauseFor5Hours = pauseFor5Hours
        self.pauseUntilMorning = pauseUntilMorning
        self.takeEyeGateNow = takeEyeGateNow
        self.takeBodyBreakNow = takeBodyBreakNow
        self.skipToNextBodyBreak = skipToNextBodyBreak
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
    public var pauseUntilMorningHour: Int?

    public init(
        openAtLogin: Bool,
        checkForUpdates: Bool,
        notifyNewVersion: Bool,
        updateFeedURL: String,
        hasCompletedOnboarding: Bool,
        pauseUntilMorningHour: Int? = nil
    ) {
        self.openAtLogin = openAtLogin
        self.checkForUpdates = checkForUpdates
        self.notifyNewVersion = notifyNewVersion
        self.updateFeedURL = updateFeedURL
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.pauseUntilMorningHour = pauseUntilMorningHour.map(Self.normalizedMorningHour)
    }

    public static let defaults = OperationsSettings(
        openAtLogin: false,
        checkForUpdates: true,
        notifyNewVersion: true,
        updateFeedURL: "https://api.github.com/repos/tovkaic/shouldrest/releases/latest",
        hasCompletedOnboarding: false,
        pauseUntilMorningHour: defaultPauseUntilMorningHour
    )

    public var resolvedPauseUntilMorningHour: Int {
        Self.normalizedMorningHour(pauseUntilMorningHour ?? Self.defaultPauseUntilMorningHour)
    }

    public func secondsUntilMorning(from now: Date = Date(), calendar: Calendar = .current) -> TimeInterval {
        Self.secondsUntilMorning(
            from: now,
            calendar: calendar,
            morningHour: resolvedPauseUntilMorningHour
        )
    }

    public static func secondsUntilMorning(
        from now: Date = Date(),
        calendar: Calendar = .current,
        morningHour: Int? = nil
    ) -> TimeInterval {
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

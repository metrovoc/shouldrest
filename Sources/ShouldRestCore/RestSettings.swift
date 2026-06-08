import Foundation

private enum SettingsNormalization {
    static func atLeast(_ lowerBound: TimeInterval, _ value: TimeInterval) -> TimeInterval {
        guard value.isFinite else { return lowerBound }
        return max(lowerBound, value)
    }

    static func nonNegative(_ value: TimeInterval) -> TimeInterval {
        guard value.isFinite else { return 0 }
        return max(0, value)
    }

    static func clamped(_ value: Double, min lowerBound: Double, max upperBound: Double, fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return min(upperBound, max(lowerBound, value))
    }
}

extension KeyedDecodingContainer {
    func decodeLossy<T: Decodable>(_ type: T.Type, forKey key: Key, default defaultValue: @autoclosure () -> T) -> T {
        (try? decodeIfPresent(type, forKey: key)) ?? defaultValue()
    }

    func decodeLossyOptional<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        try? decodeIfPresent(type, forKey: key)
    }
}

public struct RestSettings: Codable, Equatable, Sendable {
    public var eyeGate: RestRule
    public var bodyBreak: RestRule
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

    private enum CodingKeys: String, CodingKey {
        case eyeGate
        case bodyBreak
        case notifications
        case naturalBreaks
        case focusMode
        case workingHours
        case appExclusions
        case contentLibrary
        case presentation
        case shortcuts
        case operations
        case admin
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.defaults
        self.init(
            eyeGate: Self.decodeRule(.eyeGate, from: container, fallback: defaults.eyeGate),
            bodyBreak: Self.decodeRule(.bodyBreak, from: container, fallback: defaults.bodyBreak),
            notifications: container.decodeLossy(NotificationSettings.self, forKey: .notifications, default: defaults.notifications),
            naturalBreaks: container.decodeLossy(NaturalBreakSettings.self, forKey: .naturalBreaks, default: defaults.naturalBreaks),
            focusMode: container.decodeLossy(FocusModeSettings.self, forKey: .focusMode, default: defaults.focusMode),
            workingHours: container.decodeLossy(WorkingHoursSettings.self, forKey: .workingHours, default: defaults.workingHours),
            appExclusions: container.decodeLossy([AppExclusionRule].self, forKey: .appExclusions, default: defaults.appExclusions),
            contentLibrary: container.decodeLossy(ContentLibrarySettings.self, forKey: .contentLibrary, default: defaults.contentLibrary),
            presentation: container.decodeLossy(PresentationSettings.self, forKey: .presentation, default: defaults.presentation),
            shortcuts: container.decodeLossy(ShortcutSettings.self, forKey: .shortcuts, default: defaults.shortcuts),
            operations: container.decodeLossy(OperationsSettings.self, forKey: .operations, default: defaults.operations),
            admin: container.decodeLossy(AdminSettings.self, forKey: .admin, default: defaults.admin)
        )
    }

    private static func decodeRule(_ key: CodingKeys, from container: KeyedDecodingContainer<CodingKeys>, fallback: RestRule) -> RestRule {
        guard let decoder = try? container.superDecoder(forKey: key) else {
            return fallback
        }
        return RestRule(from: decoder, fallback: fallback)
    }

    public static let defaults = RestSettings(
        eyeGate: .eyeGateDefault,
        bodyBreak: .bodyBreakDefault,
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
        var copy = normalized()
        guard !copy.eyeGate.isEnabled, !copy.bodyBreak.isEnabled else { return copy }
        copy.eyeGate.isEnabled = true
        return copy
    }

    public func normalized() -> RestSettings {
        RestSettings(
            eyeGate: eyeGate.normalized(fallback: .eyeGateDefault),
            bodyBreak: bodyBreak.normalized(fallback: .bodyBreakDefault),
            notifications: notifications.normalized(),
            naturalBreaks: naturalBreaks.normalized(),
            focusMode: focusMode,
            workingHours: workingHours.normalized(),
            appExclusions: appExclusions.map { $0.normalized() },
            contentLibrary: contentLibrary,
            presentation: presentation,
            shortcuts: shortcuts,
            operations: operations.normalized(),
            admin: admin
        )
    }

    public func normalizedForCurrentDesign() -> RestSettings {
        var copy = enforcingAtLeastOneEnabledRest()
        copy.eyeGate.emergencyOverride.confirmationSteps = EmergencyOverridePolicy.confirmationStepsForCurrentDesign(
            isEnabled: copy.eyeGate.emergencyOverride.isEnabled
        )
        copy.eyeGate.enforcement = .eyeGateDefault
        copy.bodyBreak.emergencyOverride = .disabled
        if let emergencyShortcut = copy.shortcuts.emergencyEyeGateOverride,
           emergencyShortcut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copy.shortcuts.emergencyEyeGateOverride = ShortcutSettings.defaultEmergencyEyeGateOverride
        }
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
        self.interval = SettingsNormalization.atLeast(1, interval)
        self.duration = SettingsNormalization.atLeast(1, duration)
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

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case interval
        case duration
        case ordinarySkipEnabled
        case postpone
        case manualFinishEnabled
        case emergencyOverride
        case enforcement
        case content
        case colorHex
        case startSound
        case finishSound
    }

    public init(from decoder: Decoder) throws {
        self.init(from: decoder, fallback: .bodyBreakDefault)
    }

    init(from decoder: Decoder, fallback: RestRule) {
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = fallback
            return
        }
        self.init(
            isEnabled: container.decodeLossy(Bool.self, forKey: .isEnabled, default: fallback.isEnabled),
            interval: container.decodeLossy(TimeInterval.self, forKey: .interval, default: fallback.interval),
            duration: container.decodeLossy(TimeInterval.self, forKey: .duration, default: fallback.duration),
            ordinarySkipEnabled: container.decodeLossy(
                Bool.self,
                forKey: .ordinarySkipEnabled,
                default: fallback.ordinarySkipEnabled
            ),
            postpone: Self.decodePostpone(from: container, fallback: fallback.postpone),
            manualFinishEnabled: container.decodeLossy(
                Bool.self,
                forKey: .manualFinishEnabled,
                default: fallback.manualFinishEnabled
            ),
            emergencyOverride: Self.decodeEmergencyOverride(from: container, fallback: fallback.emergencyOverride),
            enforcement: Self.decodeEnforcement(from: container, fallback: fallback.enforcement),
            content: container.decodeLossy(RestContentPolicy.self, forKey: .content, default: fallback.content),
            colorHex: container.decodeLossy(String.self, forKey: .colorHex, default: fallback.colorHex),
            startSound: container.decodeLossy(SoundPolicy.self, forKey: .startSound, default: fallback.startSound),
            finishSound: container.decodeLossy(SoundPolicy.self, forKey: .finishSound, default: fallback.finishSound)
        )
    }

    private static func decodePostpone(
        from container: KeyedDecodingContainer<CodingKeys>,
        fallback: PostponePolicy
    ) -> PostponePolicy {
        guard let decoder = try? container.superDecoder(forKey: .postpone) else {
            return fallback
        }
        return PostponePolicy(from: decoder, fallback: fallback)
    }

    private static func decodeEmergencyOverride(
        from container: KeyedDecodingContainer<CodingKeys>,
        fallback: EmergencyOverridePolicy
    ) -> EmergencyOverridePolicy {
        guard let decoder = try? container.superDecoder(forKey: .emergencyOverride) else {
            return fallback
        }
        return EmergencyOverridePolicy(from: decoder, fallback: fallback)
    }

    private static func decodeEnforcement(
        from container: KeyedDecodingContainer<CodingKeys>,
        fallback: EnforcementProfile
    ) -> EnforcementProfile {
        guard let decoder = try? container.superDecoder(forKey: .enforcement) else {
            return fallback
        }
        return EnforcementProfile(from: decoder, fallback: fallback)
    }

    public static let eyeGateDefault = RestRule(
        isEnabled: true,
        interval: 10 * 60,
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
        interval: 45 * 60,
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

    public func normalized(fallback: RestRule) -> RestRule {
        RestRule(
            isEnabled: isEnabled,
            interval: interval,
            duration: duration,
            ordinarySkipEnabled: ordinarySkipEnabled,
            postpone: postpone.normalized(),
            manualFinishEnabled: manualFinishEnabled,
            emergencyOverride: emergencyOverride.normalized(),
            enforcement: enforcement.normalized(),
            content: content,
            colorHex: Self.normalizedColorHex(colorHex, fallback: fallback.colorHex),
            startSound: startSound.normalized(),
            finishSound: finishSound.normalized()
        )
    }

    public static func normalizedColorHex(_ rawValue: String, fallback: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard body.count == 6,
              body.allSatisfy(\.isHexDigit) else {
            return fallback
        }
        return "#\(body.uppercased())"
    }
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
        self.duration = SettingsNormalization.atLeast(1, duration)
        self.maxCount = max(0, maxCount)
        self.allowedDuringFirstPercent = SettingsNormalization.clamped(
            allowedDuringFirstPercent,
            min: 0,
            max: 100,
            fallback: 0
        )
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case duration
        case maxCount
        case allowedDuringFirstPercent
    }

    public init(from decoder: Decoder) throws {
        self.init(from: decoder, fallback: .disabled)
    }

    init(from decoder: Decoder, fallback: PostponePolicy) {
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = fallback
            return
        }
        self.init(
            isEnabled: container.decodeLossy(Bool.self, forKey: .isEnabled, default: fallback.isEnabled),
            duration: container.decodeLossy(TimeInterval.self, forKey: .duration, default: fallback.duration),
            maxCount: container.decodeLossy(Int.self, forKey: .maxCount, default: fallback.maxCount),
            allowedDuringFirstPercent: container.decodeLossy(
                Double.self,
                forKey: .allowedDuringFirstPercent,
                default: fallback.allowedDuringFirstPercent
            )
        )
    }

    public static let disabled = PostponePolicy(
        isEnabled: false,
        duration: 1,
        maxCount: 0,
        allowedDuringFirstPercent: 0
    )

    public func normalized() -> PostponePolicy {
        PostponePolicy(
            isEnabled: isEnabled,
            duration: duration,
            maxCount: maxCount,
            allowedDuringFirstPercent: allowedDuringFirstPercent
        )
    }
}

public struct EmergencyOverridePolicy: Codable, Equatable, Sendable {
    /// Current design is fixed at two explicit in-overlay requests.
    /// Stored confirmation-step values are kept only for settings compatibility.
    public static let inOverlayRequestCount = 2
    public static let currentDesignConfirmationSteps = inOverlayRequestCount - 1

    public var isEnabled: Bool
    /// Compatibility field: this does not configure long-press timing or extra confirmation UI.
    public var confirmationSteps: Int

    public init(isEnabled: Bool, confirmationSteps: Int) {
        self.isEnabled = isEnabled
        self.confirmationSteps = max(0, confirmationSteps)
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case confirmationSteps
    }

    public init(from decoder: Decoder) throws {
        self.init(from: decoder, fallback: .disabled)
    }

    init(from decoder: Decoder, fallback: EmergencyOverridePolicy) {
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = fallback
            return
        }
        self.init(
            isEnabled: container.decodeLossy(Bool.self, forKey: .isEnabled, default: fallback.isEnabled),
            confirmationSteps: container.decodeLossy(Int.self, forKey: .confirmationSteps, default: fallback.confirmationSteps)
        )
    }

    public static func confirmationStepsForCurrentDesign(isEnabled: Bool) -> Int {
        isEnabled ? currentDesignConfirmationSteps : 0
    }

    public static let defaults = EmergencyOverridePolicy(
        isEnabled: true,
        confirmationSteps: currentDesignConfirmationSteps
    )

    public static let disabled = EmergencyOverridePolicy(
        isEnabled: false,
        confirmationSteps: 0
    )

    public func normalized() -> EmergencyOverridePolicy {
        EmergencyOverridePolicy(isEnabled: isEnabled, confirmationSteps: confirmationSteps)
    }
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
        self.opacity = SettingsNormalization.clamped(opacity, min: 0, max: 1, fallback: 1)
        self.allowRegularWindowMode = allowRegularWindowMode
        self.coveredDisplay = coveredDisplay
        self.contentDisplay = contentDisplay
        self.blankSecondaryDisplays = blankSecondaryDisplays
        self.configuredDisplayIndex = configuredDisplayIndex.map { max(0, $0) }
    }

    private enum CodingKeys: String, CodingKey {
        case coversAllDisplays
        case usesScreenSaverLevel
        case isOpaque
        case opacity
        case allowRegularWindowMode
        case coveredDisplay
        case contentDisplay
        case blankSecondaryDisplays
        case configuredDisplayIndex
    }

    public init(from decoder: Decoder) throws {
        self.init(from: decoder, fallback: .bodyBreakDefault)
    }

    init(from decoder: Decoder, fallback: EnforcementProfile) {
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = fallback
            return
        }
        self.init(
            coversAllDisplays: container.decodeLossy(
                Bool.self,
                forKey: .coversAllDisplays,
                default: fallback.coversAllDisplays
            ),
            usesScreenSaverLevel: container.decodeLossy(
                Bool.self,
                forKey: .usesScreenSaverLevel,
                default: fallback.usesScreenSaverLevel
            ),
            isOpaque: container.decodeLossy(Bool.self, forKey: .isOpaque, default: fallback.isOpaque),
            opacity: container.decodeLossy(Double.self, forKey: .opacity, default: fallback.opacity),
            allowRegularWindowMode: container.decodeLossy(
                Bool.self,
                forKey: .allowRegularWindowMode,
                default: fallback.allowRegularWindowMode
            ),
            coveredDisplay: container.decodeLossyOptional(DisplaySelection.self, forKey: .coveredDisplay) ?? fallback.coveredDisplay,
            contentDisplay: container.decodeLossy(
                DisplaySelection.self,
                forKey: .contentDisplay,
                default: fallback.contentDisplay
            ),
            blankSecondaryDisplays: container.decodeLossy(
                Bool.self,
                forKey: .blankSecondaryDisplays,
                default: fallback.blankSecondaryDisplays
            ),
            configuredDisplayIndex: container.decodeLossyOptional(Int.self, forKey: .configuredDisplayIndex) ??
                fallback.configuredDisplayIndex
        )
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

    public func normalized() -> EnforcementProfile {
        EnforcementProfile(
            coversAllDisplays: coversAllDisplays,
            usesScreenSaverLevel: usesScreenSaverLevel,
            isOpaque: isOpaque,
            opacity: opacity,
            allowRegularWindowMode: allowRegularWindowMode,
            coveredDisplay: coveredDisplay,
            contentDisplay: contentDisplay,
            blankSecondaryDisplays: blankSecondaryDisplays,
            configuredDisplayIndex: configuredDisplayIndex
        )
    }
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

    public func normalized() -> SoundPolicy {
        switch self {
        case .silent:
            return .silent
        case .named(let name, let volume):
            return .named(name, volume: SettingsNormalization.clamped(volume, min: 0, max: 1, fallback: 1))
        }
    }
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
        self.eyeGateLeadTime = SettingsNormalization.nonNegative(eyeGateLeadTime)
        self.bodyBreakLeadTime = SettingsNormalization.nonNegative(bodyBreakLeadTime)
        self.silentNotifications = silentNotifications
    }

    private enum CodingKeys: String, CodingKey {
        case eyeGateEnabled
        case bodyBreakEnabled
        case eyeGateLeadTime
        case bodyBreakLeadTime
        case silentNotifications
    }

    public init(from decoder: Decoder) throws {
        let defaults = Self.defaults
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = defaults
            return
        }
        self.init(
            eyeGateEnabled: container.decodeLossy(Bool.self, forKey: .eyeGateEnabled, default: defaults.eyeGateEnabled),
            bodyBreakEnabled: container.decodeLossy(Bool.self, forKey: .bodyBreakEnabled, default: defaults.bodyBreakEnabled),
            eyeGateLeadTime: container.decodeLossy(TimeInterval.self, forKey: .eyeGateLeadTime, default: defaults.eyeGateLeadTime),
            bodyBreakLeadTime: container.decodeLossy(
                TimeInterval.self,
                forKey: .bodyBreakLeadTime,
                default: defaults.bodyBreakLeadTime
            ),
            silentNotifications: container.decodeLossy(Bool.self, forKey: .silentNotifications, default: defaults.silentNotifications)
        )
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

    public func normalized() -> NotificationSettings {
        NotificationSettings(
            eyeGateEnabled: eyeGateEnabled,
            bodyBreakEnabled: bodyBreakEnabled,
            eyeGateLeadTime: eyeGateLeadTime,
            bodyBreakLeadTime: bodyBreakLeadTime,
            silentNotifications: silentNotifications
        )
    }
}

public struct NaturalBreakSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var inactivityResetTime: TimeInterval

    public init(isEnabled: Bool, inactivityResetTime: TimeInterval) {
        self.isEnabled = isEnabled
        self.inactivityResetTime = SettingsNormalization.atLeast(1, inactivityResetTime)
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case inactivityResetTime
    }

    public init(from decoder: Decoder) throws {
        let defaults = Self.defaults
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = defaults
            return
        }
        self.init(
            isEnabled: container.decodeLossy(Bool.self, forKey: .isEnabled, default: defaults.isEnabled),
            inactivityResetTime: container.decodeLossy(
                TimeInterval.self,
                forKey: .inactivityResetTime,
                default: defaults.inactivityResetTime
            )
        )
    }

    public static let defaults = NaturalBreakSettings(
        isEnabled: true,
        inactivityResetTime: 5 * 60
    )

    public func normalized() -> NaturalBreakSettings {
        NaturalBreakSettings(isEnabled: isEnabled, inactivityResetTime: inactivityResetTime)
    }
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

    private enum CodingKeys: String, CodingKey {
        case monitorFocusMode
        case deferEyeGate
        case deferBodyBreak
    }

    public init(from decoder: Decoder) throws {
        let defaults = Self.defaults
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = defaults
            return
        }
        self.init(
            monitorFocusMode: container.decodeLossy(Bool.self, forKey: .monitorFocusMode, default: defaults.monitorFocusMode),
            deferEyeGate: container.decodeLossy(Bool.self, forKey: .deferEyeGate, default: defaults.deferEyeGate),
            deferBodyBreak: container.decodeLossy(Bool.self, forKey: .deferBodyBreak, default: defaults.deferBodyBreak)
        )
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

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case startMinuteOfDay
        case endMinuteOfDay
    }

    public init(from decoder: Decoder) throws {
        let defaults = Self.always
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = defaults
            return
        }
        self.init(
            isEnabled: container.decodeLossy(Bool.self, forKey: .isEnabled, default: defaults.isEnabled),
            startMinuteOfDay: container.decodeLossy(Int.self, forKey: .startMinuteOfDay, default: defaults.startMinuteOfDay),
            endMinuteOfDay: container.decodeLossy(Int.self, forKey: .endMinuteOfDay, default: defaults.endMinuteOfDay)
        )
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

    public func normalized() -> WorkingHoursSettings {
        WorkingHoursSettings(
            isEnabled: isEnabled,
            startMinuteOfDay: startMinuteOfDay,
            endMinuteOfDay: endMinuteOfDay
        )
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

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case matchTerms
        case mode
        case appliesTo
        case isEnabled
    }

    public init(from decoder: Decoder) throws {
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self.init(
                id: UUID().uuidString,
                name: "",
                matchTerms: [],
                mode: .pauseWhenMatched,
                appliesTo: [.bodyBreak],
                isEnabled: false
            )
            return
        }
        self.init(
            id: container.decodeLossy(String.self, forKey: .id, default: UUID().uuidString),
            name: container.decodeLossy(String.self, forKey: .name, default: ""),
            matchTerms: container.decodeLossy([String].self, forKey: .matchTerms, default: []),
            mode: container.decodeLossy(Mode.self, forKey: .mode, default: .pauseWhenMatched),
            appliesTo: container.decodeLossy(Set<RestKind>.self, forKey: .appliesTo, default: [.bodyBreak]),
            isEnabled: container.decodeLossy(Bool.self, forKey: .isEnabled, default: true)
        )
    }

    public func normalized() -> AppExclusionRule {
        AppExclusionRule(
            id: id,
            name: name,
            matchTerms: normalizedMatchTerms,
            mode: mode,
            appliesTo: appliesTo,
            isEnabled: isEnabled
        )
    }

    public var normalizedMatchTerms: [String] {
        matchTerms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    public var isActionable: Bool {
        isEnabled && !normalizedMatchTerms.isEmpty && !appliesTo.isEmpty
    }

    public var displayName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            return trimmedName
        }
        return normalizedMatchTerms.first ?? id
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

    private enum CodingKeys: String, CodingKey {
        case themeSource
        case trayIconStyle
        case showCurrentTimeDuringBodyBreak
        case breakHealthMode
        case showMenuBarItem
        case languageIdentifier
    }

    public init(from decoder: Decoder) throws {
        let defaults = Self.defaults
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = defaults
            return
        }
        self.init(
            themeSource: container.decodeLossy(ThemeSource.self, forKey: .themeSource, default: defaults.themeSource),
            trayIconStyle: container.decodeLossy(TrayIconStyle.self, forKey: .trayIconStyle, default: defaults.trayIconStyle),
            showCurrentTimeDuringBodyBreak: container.decodeLossy(
                Bool.self,
                forKey: .showCurrentTimeDuringBodyBreak,
                default: defaults.showCurrentTimeDuringBodyBreak
            ),
            breakHealthMode: container.decodeLossy(Bool.self, forKey: .breakHealthMode, default: defaults.breakHealthMode),
            showMenuBarItem: container.decodeLossyOptional(Bool.self, forKey: .showMenuBarItem),
            languageIdentifier: container.decodeLossyOptional(String.self, forKey: .languageIdentifier)
        )
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
        showMenuBarItem ?? true
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
        guard let emergencyEyeGateOverride,
              !emergencyEyeGateOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Self.defaultEmergencyEyeGateOverride
        }
        return emergencyEyeGateOverride
    }

    public var resolvedTakeBodyBreakNowShortcut: String {
        let primary = takeBodyBreakNow.trimmingCharacters(in: .whitespacesAndNewlines)
        return primary.isEmpty ? skipToNextBodyBreak : takeBodyBreakNow
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

    private enum CodingKeys: String, CodingKey {
        case pauseToggle
        case pauseFor30Minutes
        case pauseFor1Hour
        case pauseFor2Hours
        case pauseFor5Hours
        case pauseUntilMorning
        case skipToNextScheduledRest
        case takeEyeGateNow
        case takeBodyBreakNow
        case skipToNextBodyBreak
        case endBodyBreak
        case emergencyEyeGateOverride
        case reset
    }

    public init(from decoder: Decoder) throws {
        let defaults = Self.defaults
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = defaults
            return
        }
        self.init(
            pauseToggle: container.decodeLossy(String.self, forKey: .pauseToggle, default: defaults.pauseToggle),
            pauseFor30Minutes: container.decodeLossy(
                String.self,
                forKey: .pauseFor30Minutes,
                default: defaults.pauseFor30Minutes
            ),
            pauseFor1Hour: container.decodeLossy(String.self, forKey: .pauseFor1Hour, default: defaults.pauseFor1Hour),
            pauseFor2Hours: container.decodeLossy(String.self, forKey: .pauseFor2Hours, default: defaults.pauseFor2Hours),
            pauseFor5Hours: container.decodeLossy(String.self, forKey: .pauseFor5Hours, default: defaults.pauseFor5Hours),
            pauseUntilMorning: container.decodeLossy(
                String.self,
                forKey: .pauseUntilMorning,
                default: defaults.pauseUntilMorning
            ),
            skipToNextScheduledRest: container.decodeLossyOptional(String.self, forKey: .skipToNextScheduledRest),
            takeEyeGateNow: container.decodeLossy(String.self, forKey: .takeEyeGateNow, default: defaults.takeEyeGateNow),
            takeBodyBreakNow: container.decodeLossy(
                String.self,
                forKey: .takeBodyBreakNow,
                default: defaults.takeBodyBreakNow
            ),
            skipToNextBodyBreak: container.decodeLossy(
                String.self,
                forKey: .skipToNextBodyBreak,
                default: defaults.skipToNextBodyBreak
            ),
            endBodyBreak: container.decodeLossyOptional(String.self, forKey: .endBodyBreak),
            emergencyEyeGateOverride: container.decodeLossyOptional(String.self, forKey: .emergencyEyeGateOverride),
            reset: container.decodeLossy(String.self, forKey: .reset, default: defaults.reset)
        )
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
        self.pauseUntilMorningLatitude = pauseUntilMorningLatitude.map {
            SettingsNormalization.clamped($0, min: -89.8, max: 89.8, fallback: 0)
        }
        self.pauseUntilMorningLongitude = pauseUntilMorningLongitude.map(Self.normalizedLongitude)
        self.pauseForSuspendOrLock = pauseForSuspendOrLock
    }

    private enum CodingKeys: String, CodingKey {
        case openAtLogin
        case checkForUpdates
        case notifyNewVersion
        case updateFeedURL
        case hasCompletedOnboarding
        case showOnboardingOnNextLaunch
        case pauseUntilMorningHour
        case pauseUntilMorningMode
        case pauseUntilMorningLatitude
        case pauseUntilMorningLongitude
        case pauseForSuspendOrLock
    }

    public init(from decoder: Decoder) throws {
        let defaults = Self.defaults
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = defaults
            return
        }
        self.init(
            openAtLogin: container.decodeLossy(Bool.self, forKey: .openAtLogin, default: defaults.openAtLogin),
            checkForUpdates: container.decodeLossy(Bool.self, forKey: .checkForUpdates, default: defaults.checkForUpdates),
            notifyNewVersion: container.decodeLossy(Bool.self, forKey: .notifyNewVersion, default: defaults.notifyNewVersion),
            updateFeedURL: container.decodeLossy(String.self, forKey: .updateFeedURL, default: defaults.updateFeedURL),
            hasCompletedOnboarding: container.decodeLossy(
                Bool.self,
                forKey: .hasCompletedOnboarding,
                default: defaults.hasCompletedOnboarding
            ),
            showOnboardingOnNextLaunch: container.decodeLossyOptional(Bool.self, forKey: .showOnboardingOnNextLaunch),
            pauseUntilMorningHour: container.decodeLossyOptional(Int.self, forKey: .pauseUntilMorningHour),
            pauseUntilMorningMode: container.decodeLossyOptional(MorningPauseMode.self, forKey: .pauseUntilMorningMode),
            pauseUntilMorningLatitude: container.decodeLossyOptional(Double.self, forKey: .pauseUntilMorningLatitude),
            pauseUntilMorningLongitude: container.decodeLossyOptional(Double.self, forKey: .pauseUntilMorningLongitude),
            pauseForSuspendOrLock: container.decodeLossyOptional(Bool.self, forKey: .pauseForSuspendOrLock)
        )
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

    public func normalized() -> OperationsSettings {
        OperationsSettings(
            openAtLogin: openAtLogin,
            checkForUpdates: checkForUpdates,
            notifyNewVersion: notifyNewVersion,
            updateFeedURL: updateFeedURL,
            hasCompletedOnboarding: hasCompletedOnboarding,
            showOnboardingOnNextLaunch: showOnboardingOnNextLaunch,
            pauseUntilMorningHour: pauseUntilMorningHour,
            pauseUntilMorningMode: pauseUntilMorningMode,
            pauseUntilMorningLatitude: pauseUntilMorningLatitude,
            pauseUntilMorningLongitude: pauseUntilMorningLongitude,
            pauseForSuspendOrLock: pauseForSuspendOrLock
        )
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

    private enum CodingKeys: String, CodingKey {
        case disableAppUpdateFeatures
        case hideSettingsFileLocation
        case hideStrictPreferences
        case customPreferencesMessage
    }

    public init(from decoder: Decoder) throws {
        let defaults = Self.defaults
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = defaults
            return
        }
        self.init(
            disableAppUpdateFeatures: container.decodeLossy(
                Bool.self,
                forKey: .disableAppUpdateFeatures,
                default: defaults.disableAppUpdateFeatures
            ),
            hideSettingsFileLocation: container.decodeLossy(
                Bool.self,
                forKey: .hideSettingsFileLocation,
                default: defaults.hideSettingsFileLocation
            ),
            hideStrictPreferences: container.decodeLossy(
                Bool.self,
                forKey: .hideStrictPreferences,
                default: defaults.hideStrictPreferences
            ),
            customPreferencesMessage: container.decodeLossy(
                String.self,
                forKey: .customPreferencesMessage,
                default: defaults.customPreferencesMessage
            )
        )
    }

    public static let defaults = AdminSettings(
        disableAppUpdateFeatures: false,
        hideSettingsFileLocation: false,
        hideStrictPreferences: false,
        customPreferencesMessage: ""
    )
}

import AppKit
import Carbon
import Foundation
import ShouldRestCore
import UniformTypeIdentifiers

final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}

private struct SunriseLocationPreset: Equatable {
    static let customID = "custom"

    let id: String
    let titleKey: String
    let latitude: Double
    let longitude: Double
    let timeZoneIdentifiers: Set<String>

    var title: String {
        L10n.tr(titleKey)
    }

    static let presets: [SunriseLocationPreset] = [
        SunriseLocationPreset(
            id: "tokyo",
            titleKey: "prefs.sunriseLocation.tokyo",
            latitude: 35.6762,
            longitude: 139.6503,
            timeZoneIdentifiers: ["Asia/Tokyo"]
        ),
        SunriseLocationPreset(
            id: "san-francisco",
            titleKey: "prefs.sunriseLocation.sanFrancisco",
            latitude: 37.7749,
            longitude: -122.4194,
            timeZoneIdentifiers: ["America/Los_Angeles", "America/Vancouver"]
        ),
        SunriseLocationPreset(
            id: "new-york",
            titleKey: "prefs.sunriseLocation.newYork",
            latitude: 40.7128,
            longitude: -74.0060,
            timeZoneIdentifiers: ["America/New_York", "America/Toronto"]
        ),
        SunriseLocationPreset(
            id: "london",
            titleKey: "prefs.sunriseLocation.london",
            latitude: 51.5074,
            longitude: -0.1278,
            timeZoneIdentifiers: ["Europe/London"]
        ),
        SunriseLocationPreset(
            id: "berlin",
            titleKey: "prefs.sunriseLocation.berlin",
            latitude: 52.5200,
            longitude: 13.4050,
            timeZoneIdentifiers: ["Europe/Berlin", "Europe/Paris", "Europe/Rome", "Europe/Madrid"]
        ),
        SunriseLocationPreset(
            id: "singapore",
            titleKey: "prefs.sunriseLocation.singapore",
            latitude: 1.3521,
            longitude: 103.8198,
            timeZoneIdentifiers: ["Asia/Singapore", "Asia/Kuala_Lumpur"]
        ),
        SunriseLocationPreset(
            id: "sydney",
            titleKey: "prefs.sunriseLocation.sydney",
            latitude: -33.8688,
            longitude: 151.2093,
            timeZoneIdentifiers: ["Australia/Sydney", "Australia/Melbourne"]
        ),
        SunriseLocationPreset(
            id: "beijing",
            titleKey: "prefs.sunriseLocation.beijing",
            latitude: 39.9042,
            longitude: 116.4074,
            timeZoneIdentifiers: ["Asia/Shanghai", "Asia/Beijing", "Asia/Hong_Kong", "Asia/Taipei"]
        )
    ]

    static func matching(latitude: Double?, longitude: Double?) -> SunriseLocationPreset? {
        guard let latitude, let longitude else { return nil }
        return presets.first { preset in
            abs(preset.latitude - latitude) < 0.02 &&
                abs(normalizedLongitude(preset.longitude - longitude)) < 0.02
        }
    }

    static func defaultForCurrentTimeZone(_ timeZone: TimeZone = .current, now: Date = Date()) -> SunriseLocationPreset? {
        if let exact = presets.first(where: { $0.timeZoneIdentifiers.contains(timeZone.identifier) }) {
            return exact
        }
        let approximateLongitude = Double(timeZone.secondsFromGMT(for: now)) / 240
        return presets.min { lhs, rhs in
            abs(normalizedLongitude(lhs.longitude - approximateLongitude)) <
                abs(normalizedLongitude(rhs.longitude - approximateLongitude))
        }
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
}

@MainActor
final class LocalImagePreviewView: NSImageView {
    var onImageURLDropped: ((URL) -> Void)?
    var isDropEnabled = true {
        didSet {
            updateDropRegistration()
        }
    }
    private var isDropHighlighted = false
    private var restingBorderColor: CGColor?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        updateDropRegistration()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        updateDropRegistration()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard isDropEnabled,
              Self.imageFileURL(from: sender.draggingPasteboard) != nil else {
            return []
        }
        setDropHighlighted(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard isDropEnabled,
              Self.imageFileURL(from: sender.draggingPasteboard) != nil else {
            setDropHighlighted(false)
            return []
        }
        setDropHighlighted(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setDropHighlighted(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        setDropHighlighted(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDropEnabled && Self.imageFileURL(from: sender.draggingPasteboard) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { setDropHighlighted(false) }
        guard let url = Self.imageFileURL(from: sender.draggingPasteboard) else { return false }
        onImageURLDropped?(url)
        return true
    }

    @discardableResult
    func acceptImageDrop(url: URL) -> Bool {
        guard isDropEnabled,
              Self.isImageFileURL(url) else {
            return false
        }
        onImageURLDropped?(url.standardizedFileURL)
        return true
    }

    static func imageFileURL(from pasteboard: NSPasteboard) -> URL? {
        let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        return urls.first(where: isImageFileURL)?.standardizedFileURL
    }

    static func isImageFileURL(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return contentType.conforms(to: .image)
        }
        return NSImage(contentsOf: url) != nil
    }

    private func updateDropRegistration() {
        if isDropEnabled {
            registerForDraggedTypes([.fileURL])
        } else {
            unregisterDraggedTypes()
            setDropHighlighted(false)
        }
    }

    private func setDropHighlighted(_ highlighted: Bool) {
        guard highlighted != isDropHighlighted else { return }
        isDropHighlighted = highlighted
        if highlighted {
            restingBorderColor = layer?.borderColor
            layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.66).cgColor
        } else {
            layer?.borderColor = restingBorderColor ?? NSColor.separatorColor.cgColor
            restingBorderColor = nil
        }
    }
}

private struct NumberInput {
    var field: NSTextField
    var stepper: NSStepper
    var slider: NSSlider?
    var min: Double
    var max: Double
}

private enum PreferencesSaveStatus {
    case ready
    case editing
    case saving
    case saved
    case copied
    case restored
    case invalid
}

private enum PreferencesAdvancedBulkEditor {
    case appRules
    case customIdeas

    var fieldName: String {
        switch self {
        case .appRules:
            L10n.tr("prefs.advancedRulesJSON")
        case .customIdeas:
            L10n.tr("prefs.advancedIdeasJSON")
        }
    }

    var tabIdentifier: String {
        switch self {
        case .appRules:
            L10n.tr("prefs.tabContext")
        case .customIdeas:
            L10n.tr("prefs.tabAppearance")
        }
    }
}

private enum PreferencesSectionIcon {
    case restGate
    case systemSymbol(String)
}

private enum PreferencesTabIcon {
    case systemSymbol(String)
}

private struct PreferencesSearchTarget {
    var tabIdentifier: String
    var title: String
    var normalizedText: String
    var view: NSView
}

private struct PreferencesHighlightSnapshot {
    weak var view: NSView?
    var wantsLayer: Bool
    var backgroundColor: CGColor?
    var borderColor: CGColor?
    var borderWidth: CGFloat
    var cornerRadius: CGFloat
}

struct AppExclusionApplicationCandidate: Equatable {
    var name: String
    var bundleIdentifier: String?

    var terms: [String] {
        Self.uniqueNonemptyTerms([name, bundleIdentifier])
    }

    var menuTitle: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBundleIdentifier = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? trimmedBundleIdentifier : trimmedName
    }

    static func currentRegularApplications() -> [AppExclusionApplicationCandidate] {
        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        var seenKeys: Set<String> = []
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> AppExclusionApplicationCandidate? in
                let name = app.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let bundleIdentifier = app.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty || !(bundleIdentifier?.isEmpty ?? true) else { return nil }
                if let bundleIdentifier, bundleIdentifier == ownBundleIdentifier {
                    return nil
                }
                return AppExclusionApplicationCandidate(name: name, bundleIdentifier: bundleIdentifier)
            }
            .filter { candidate in
                let key = "\(candidate.name.lowercased())|\((candidate.bundleIdentifier ?? "").lowercased())"
                guard !seenKeys.contains(key) else { return false }
                seenKeys.insert(key)
                return true
            }
            .sorted { lhs, rhs in
                lhs.menuTitle.localizedCaseInsensitiveCompare(rhs.menuTitle) == .orderedAscending
            }
    }

    static func uniqueNonemptyTerms(_ values: [String?]) -> [String] {
        var seenTerms: Set<String> = []
        return values.compactMap { value in
            guard let term = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !term.isEmpty else {
                return nil
            }
            let key = term.lowercased()
            guard !seenTerms.contains(key) else { return nil }
            seenTerms.insert(key)
            return term
        }
    }
}

private final class AppExclusionApplicationCandidateBox: NSObject {
    let candidate: AppExclusionApplicationCandidate

    init(_ candidate: AppExclusionApplicationCandidate) {
        self.candidate = candidate
    }
}

@MainActor
private protocol PreferencesWindowKeyboardDelegate: AnyObject {
    func focusPreferencesSearch()
    func clearPreferencesSearchIfFocused() -> Bool
}

private final class PreferencesWindow: NSWindow {
    weak var keyboardDelegate: PreferencesWindowKeyboardDelegate?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.type == .keyDown,
           flags == .command,
           event.charactersIgnoringModifiers?.lowercased() == "f" {
            keyboardDelegate?.focusPreferencesSearch()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        if keyboardDelegate?.clearPreferencesSearchIfFocused() == true {
            return
        }
        super.cancelOperation(sender)
    }
}

@MainActor
final class PreferencesWindowController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate, NSSearchFieldDelegate, NSTextViewDelegate, PreferencesWindowKeyboardDelegate {
    private static let defaultUpdateFeedURL = RestSettings.defaults.operations.updateFeedURL

    private var settings: RestSettings
    private let onSave: (RestSettings) -> Void
    private let adminMessageLabel = NSTextField(labelWithString: "")
    private let searchField = NSSearchField()
    private let searchStatusLabel = NSTextField(labelWithString: "")
    private let saveStatusIcon = NSImageView()
    private let saveStatusLabel = NSTextField(labelWithString: "")
    private let restoreDefaultsButton = NSButton()
    private let scheduleSummaryIcon = NSImageView()
    private let scheduleSummaryLabel = NSTextField(labelWithString: "")
    private let rhythmPresetRecommendedButton = NSButton()
    private let rhythmPresetFrequentEyeButton = NSButton()
    private let rhythmPresetMovementButton = NSButton()
    private var rhythmPresetButtonEntries: [(button: NSButton, preset: RestRhythmPreset)] {
        [
            (rhythmPresetRecommendedButton, .recommended),
            (rhythmPresetFrequentEyeButton, .frequentEye),
            (rhythmPresetMovementButton, .movement)
        ]
    }
    private let soundPlayer = SoundPlayer()
    private var isLoadingSettings = false
    private var hasPendingTextEditing = false
    private var hasPendingAutosave = false
    private var autosaveGeneration = 0
    private var autosaveTask: Task<Void, Never>?
    private var saveStatusInvalidFieldName: String?
    private var saveStatusInvalidDetail: String?
    private var numberInputs: [NumberInput] = []
    private weak var preferencesTabView: NSTabView?
    private var searchTargets: [PreferencesSearchTarget] = []
    private var highlightedSearchTarget: PreferencesHighlightSnapshot?
    private var currentSearchQuery = ""
    private var currentSearchMatchIndex: Int?
    private weak var currentSearchTargetView: NSView?

    private let eyeEnabled = NSButton(checkboxWithTitle: L10n.tr("prefs.enableEyeGate"), target: nil, action: nil)
    private let eyeInterval = NSTextField()
    private let eyeDuration = NSTextField()
    private let eyeColor = NSColorWell()
    private let eyeNotify = NSButton(checkboxWithTitle: L10n.tr("prefs.notifyEyeGate"), target: nil, action: nil)
    private let eyeLead = NSTextField()
    private let eyeManualFinish = NSButton(checkboxWithTitle: L10n.tr("prefs.eyeManualFinish"), target: nil, action: nil)
    private let eyeEmergencyOverride = NSButton(checkboxWithTitle: L10n.tr("prefs.eyeEmergencyOverride"), target: nil, action: nil)
    private var eyeIntervalRow: NSView?
    private var eyeDurationRow: NSView?
    private var eyeColorRow: NSView?
    private var eyeLeadRow: NSView?

    private let bodyEnabled = NSButton(checkboxWithTitle: L10n.tr("prefs.enableBodyBreak"), target: nil, action: nil)
    private let bodyInterval = NSTextField()
    private let bodyDuration = NSTextField()
    private let bodyAfterEyeGates = NSTextField()
    private let bodyColor = NSColorWell()
    private let bodyNotify = NSButton(checkboxWithTitle: L10n.tr("prefs.notifyBodyBreak"), target: nil, action: nil)
    private let bodyLead = NSTextField()
    private let bodyPostponeMinutes = NSTextField()
    private let bodyPostponeLimit = NSTextField()
    private let bodyPostponeWindowPercent = NSTextField()
    private let bodyAllowSkip = NSButton(checkboxWithTitle: L10n.tr("prefs.bodyAllowSkip"), target: nil, action: nil)
    private let bodyManualFinish = NSButton(checkboxWithTitle: L10n.tr("prefs.manualFinish"), target: nil, action: nil)
    private let bodyCoversAllDisplays = NSButton(checkboxWithTitle: L10n.tr("prefs.bodyAllDisplays"), target: nil, action: nil)
    private let bodyCoveredDisplay = NSPopUpButton()
    private var bodyIntervalRow: NSView?
    private var bodyDurationRow: NSView?
    private var bodyAfterEyeGatesRow: NSView?
    private var bodyColorRow: NSView?
    private var bodyLeadRow: NSView?
    private var bodyPostponeMinutesRow: NSView?
    private var bodyPostponeLimitRow: NSView?
    private var bodyPostponeWindowPercentRow: NSView?
    private var bodyCoveredDisplayRow: NSView?
    private let bodyContentDisplay = NSPopUpButton()
    private var bodyContentDisplayRow: NSView?
    private let bodyBlankSecondaryDisplays = NSButton(checkboxWithTitle: L10n.tr("prefs.bodyBlankSecondary"), target: nil, action: nil)
    private let bodyConfiguredDisplay = NSPopUpButton()
    private var bodyConfiguredDisplayRow: NSView?
    private let bodyDisplaySummaryLabel = NSTextField(labelWithString: "")
    private let contextSummaryIcon = NSImageView()
    private let contextSummaryLabel = NSTextField(labelWithString: "")

    private let naturalBreaks = NSButton(checkboxWithTitle: L10n.tr("prefs.naturalBreaks"), target: nil, action: nil)
    private let naturalIdleMinutes = NSTextField()
    private var naturalIdleMinutesRow: NSView?
    private let focusMonitor = NSButton(checkboxWithTitle: L10n.tr("prefs.monitorFocus"), target: nil, action: nil)
    private let focusDefersBody = NSButton(checkboxWithTitle: L10n.tr("prefs.focusDefersBody"), target: nil, action: nil)
    private let workingHoursEnabled = NSButton(checkboxWithTitle: L10n.tr("prefs.workingHours"), target: nil, action: nil)
    private let workingStart = NSTextField()
    private let workingEnd = NSTextField()
    private let workingStartPicker = NSDatePicker()
    private let workingEndPicker = NSDatePicker()
    private var workingStartRow: NSView?
    private var workingEndRow: NSView?

    private let appExclusionEnabled = NSButton(checkboxWithTitle: L10n.tr("prefs.enablePrimaryExclusion"), target: nil, action: nil)
    private let appExclusionName = NSTextField()
    private let appExclusionTerms = NSTokenField()
    private let appExclusionAddRunningApp = NSButton()
    private let appExclusionAddRuleButton = NSButton()
    private let appExclusionCancelEditButton = NSButton()
    private let appExclusionMode = NSPopUpButton()
    private let appExclusionAppliesEye = NSButton(checkboxWithTitle: L10n.tr("prefs.appliesEye"), target: nil, action: nil)
    private let appExclusionAppliesBody = NSButton(checkboxWithTitle: L10n.tr("prefs.appliesBody"), target: nil, action: nil)
    private let appExclusionPreviewLabel = NSTextField(labelWithString: "")
    private var appExclusionNameRow: NSView?
    private var appExclusionTermsRow: NSView?
    private var appExclusionModeRow: NSView?
    private var appExclusionAddRuleRow: NSView?
    private let appExclusionRulesListStack = NSStackView()
    private let appExclusionsJSONEditor = NSTextView()
    private let appExclusionsJSONScrollView = NSScrollView()
    private let appExclusionsAdvancedButton = NSButton()
    private let appExclusionsCopyBulkButton = NSButton()
    private let appExclusionsRestoreBulkButton = NSButton()
    private var appExclusionRulesListRow: NSView?
    private var appExclusionsJSONRow: NSView?
    private var appExclusionRuleRemoveControls: [(id: String, button: NSButton)] = []
    private var appExclusionRuleEditControls: [(id: String, button: NSButton)] = []
    private var editingAppExclusionRuleID: String?
    private var armedAppExclusionRuleRemovalID: String?

    private let themeSource = NSPopUpButton()
    private let languageIdentifier = NSPopUpButton()
    private let currentTimeInBodyBreak = NSButton(checkboxWithTitle: L10n.tr("prefs.currentTimeBody"), target: nil, action: nil)
    private let breakHealth = NSButton(checkboxWithTitle: L10n.tr("prefs.breakHealth"), target: nil, action: nil)
    private let silentNotifications = NSButton(checkboxWithTitle: L10n.tr("prefs.silentNotifications"), target: nil, action: nil)
    private let eyeStartSound = NSPopUpButton()
    private let eyeFinishSound = NSPopUpButton()
    private let bodyStartSound = NSPopUpButton()
    private let bodyFinishSound = NSPopUpButton()
    private let eyeStartSoundPreview = NSButton()
    private let eyeFinishSoundPreview = NSButton()
    private let bodyStartSoundPreview = NSButton()
    private let bodyFinishSoundPreview = NSButton()
    private var eyeStartSoundRow: NSView?
    private var eyeFinishSoundRow: NSView?
    private var bodyStartSoundRow: NSView?
    private var bodyFinishSoundRow: NSView?
    private let soundVolume = NSTextField()
    private let soundVolumeSlider = NSSlider()
    private let soundVolumeValueLabel = NSTextField(labelWithString: "")
    private let soundPreviewStatusLabel = NSTextField(labelWithString: "")

    private let customBodyTitle = NSTextField()
    private let customBodyTextEditor = NSTextView()
    private let customBodyTextScrollView = NSScrollView()
    private let customBodyIdeasJSONEditor = NSTextView()
    private let customBodyIdeasJSONScrollView = NSScrollView()
    private let customBodyIdeasAdvancedButton = NSButton()
    private let customBodyIdeasCopyBulkButton = NSButton()
    private let customBodyIdeasRestoreBulkButton = NSButton()
    private let customBodyAddIdeaButton = NSButton()
    private let customBodyCancelEditButton = NSButton()
    private let customBodyIdeasListStack = NSStackView()
    private let bodyContentSummaryLabel = NSTextField(labelWithString: "")
    private var localImagePathRow: NSView?
    private var customBodyTitleRow: NSView?
    private var customBodyTextRow: NSView?
    private var customBodyAddIdeaButtonRow: NSView?
    private var customBodyIdeasListRow: NSView?
    private var customBodyIdeasJSONRow: NSView?
    private var customBodyIdeaRemoveControls: [(id: String, button: NSButton)] = []
    private var customBodyIdeaEditControls: [(id: String, button: NSButton)] = []
    private var editingCustomBodyIdeaID: String?
    private var armedCustomBodyIdeaRemovalID: String?
    private let localImagePath = NSTextField()
    private let localImageChooseButton = NSButton()
    private let localImageClearButton = NSButton()
    private let localImagePreview = LocalImagePreviewView()
    private let localImagePreviewLabel = NSTextField(labelWithString: "")
    private let useBuiltInIdeas = NSButton(checkboxWithTitle: L10n.tr("prefs.useBuiltInIdeas"), target: nil, action: nil)

    private let shortcutPauseToggle = ShortcutRecorderButton()
    private let shortcutPause30 = ShortcutRecorderButton()
    private let shortcutPause1h = ShortcutRecorderButton()
    private let shortcutPause2h = ShortcutRecorderButton()
    private let shortcutPause5h = ShortcutRecorderButton()
    private let shortcutPauseUntilMorning = ShortcutRecorderButton()
    private let shortcutNextScheduled = ShortcutRecorderButton()
    private let shortcutEyeNow = ShortcutRecorderButton()
    private let shortcutBodyNow = ShortcutRecorderButton()
    private let shortcutEndBody = ShortcutRecorderButton()
    private let shortcutEmergencyEye = ShortcutRecorderButton()
    private var shortcutEyeNowRow: NSView?
    private var shortcutBodyNowRow: NSView?
    private var shortcutEndBodyRow: NSView?
    private weak var shortcutEndBodyLabel: NSTextField?
    private var shortcutEmergencyEyeRow: NSView?
    private let shortcutReset = ShortcutRecorderButton()
    private var shortcutClearControls: [(recorder: ShortcutRecorderButton, button: NSButton)] = []
    private let shortcutConflictRow = NSStackView()
    private let shortcutConflictIcon = NSImageView()
    private let shortcutConflictLabel = NSTextField(labelWithString: "")
    private let shortcutConflictReviewButton = NSButton()
    private var shortcutConflictRecorders: [ShortcutRecorderButton] = []

    private let openAtLogin = NSButton(checkboxWithTitle: L10n.tr("prefs.openAtLogin"), target: nil, action: nil)
    private let checkUpdates = NSButton(checkboxWithTitle: L10n.tr("prefs.checkUpdates"), target: nil, action: nil)
    private let notifyNewVersion = NSButton(checkboxWithTitle: L10n.tr("prefs.notifyNewVersion"), target: nil, action: nil)
    private let showOnboardingNextLaunch = NSButton(
        checkboxWithTitle: L10n.tr("prefs.showOnboardingNextLaunch"),
        target: nil,
        action: nil
    )
    private let pauseUntilMorningMode = NSPopUpButton()
    private let pauseUntilMorningLocation = NSPopUpButton()
    private let pauseUntilMorningHour = NSTextField()
    private let pauseUntilMorningLatitude = NSTextField()
    private let pauseUntilMorningLongitude = NSTextField()
    private let pauseUntilMorningSummaryLabel = NSTextField(labelWithString: "")
    private var pauseUntilMorningLocationRow: NSView?
    private var pauseUntilMorningHourRow: NSView?
    private var pauseUntilMorningLatitudeRow: NSView?
    private var pauseUntilMorningLongitudeRow: NSView?
    private let pauseForSuspendOrLock = NSButton(checkboxWithTitle: L10n.tr("prefs.pauseForSuspendOrLock"), target: nil, action: nil)
    private let updateFeedURL = NSTextField()
    private let restoreUpdateSourceButton = NSButton()
    private let updateSourceAdvancedButton = NSButton()
    private var updateFeedURLRow: NSView?
    private let disableUpdateFeatures = NSButton(checkboxWithTitle: L10n.tr("prefs.adminHideUpdates"), target: nil, action: nil)
    private let hideSettingsPath = NSButton(checkboxWithTitle: L10n.tr("prefs.adminHideSettingsPath"), target: nil, action: nil)
    private let hideStrictPreferences = NSButton(checkboxWithTitle: L10n.tr("prefs.adminHideStrict"), target: nil, action: nil)
    private let customPreferencesMessage = NSTextField()
    var appExclusionApplicationCandidatesProvider: () -> [AppExclusionApplicationCandidate] = {
        AppExclusionApplicationCandidate.currentRegularApplications()
    }
    private let adminControlsAdvancedButton = NSButton()
    private let adminControlsStack = NSStackView()
    private let nowProvider: () -> Date

    init(settings: RestSettings, nowProvider: @escaping () -> Date = Date.init, onSave: @escaping (RestSettings) -> Void) {
        self.settings = settings
        self.onSave = onSave
        self.nowProvider = nowProvider

        let window = PreferencesWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 760),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr("preferences.title")
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.center()
        super.init(window: window)
        window.keyboardDelegate = self
        window.delegate = self

        buildContent()
        loadSettings()
        focusPreferencesSearch()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(settings: RestSettings) {
        self.settings = settings
        loadSettings()
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        configurePopups()
        configureFieldWidths()
        configureImagePickerControls()
        configureAdvancedDisclosureButtons()
        configureTimePickers()
        configureMorningPauseSummary()
        configureBodyDisplaySummary()
        configureSoundVolumeControls()
        configureCustomBodyTextEditor()
        configureAdvancedBulkEditorActions()
        configureBodyContentSummary()
        configureAppExclusionTokenField()
        configureAppExclusionPreview()
        configureAppExclusionRunningAppButton()
        configureAppExclusionAddRuleButton()
        configureAppExclusionRulesList()
        configureRhythmPresetButtons()
        configureCustomBodyAddIdeaButton()
        configureCustomBodyIdeasList()
        configureSoundPreviewButtons()
        configureUpdateSourceRestoreButton()
        configureSearchField()
        configureShortcutConflictWarning()
        configureShortcutRecorders()
        configurePreferenceHelp()
        configureEnablementGuards()
        configureSaveStatusControls()
        configureAutosave()

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 0
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        let header = preferencesHeaderBar()
        root.addArrangedSubview(header)

        let tabView = NSTabView()
        tabView.identifier = NSUserInterfaceItemIdentifier("prefs.tabView")
        preferencesTabView = tabView
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.setContentHuggingPriority(.defaultLow, for: .vertical)
        tabView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        root.addArrangedSubview(tabView)

        let scheduleStack = contentStack()
        adminMessageLabel.identifier = NSUserInterfaceItemIdentifier("prefs.adminMessageLabel")
        adminMessageLabel.lineBreakMode = .byWordWrapping
        adminMessageLabel.widthAnchor.constraint(equalToConstant: 620).isActive = true
        scheduleStack.addArrangedSubview(adminMessageLabel)
        scheduleStack.addArrangedSubview(section(
            L10n.tr("prefs.sectionEyeGate"),
            icon: .restGate,
            identifier: "prefs.section.eyeGate"
        ))
        scheduleStack.addArrangedSubview(scheduleSummaryView())
        scheduleStack.addArrangedSubview(row(L10n.tr("prefs.rhythmPresets"), rhythmPresetRow()))
        eyeEnabled.identifier = NSUserInterfaceItemIdentifier("prefs.eyeEnabled")
        scheduleStack.addArrangedSubview(eyeEnabled)
        let eyeIntervalRow = numberRow(
            L10n.tr("prefs.everyMinutes"),
            eyeInterval,
            unit: L10n.tr("prefs.unit.minutes"),
            min: 1,
            max: 240,
            identifier: "eyeInterval",
            showsSlider: true
        )
        eyeIntervalRow.identifier = NSUserInterfaceItemIdentifier("prefs.eyeIntervalRow")
        self.eyeIntervalRow = eyeIntervalRow
        scheduleStack.addArrangedSubview(eyeIntervalRow)
        let eyeDurationRow = numberRow(
            L10n.tr("prefs.durationSeconds"),
            eyeDuration,
            unit: L10n.tr("prefs.unit.seconds"),
            min: 1,
            max: 300,
            identifier: "eyeDuration",
            showsSlider: true
        )
        eyeDurationRow.identifier = NSUserInterfaceItemIdentifier("prefs.eyeDurationRow")
        self.eyeDurationRow = eyeDurationRow
        scheduleStack.addArrangedSubview(eyeDurationRow)
        let eyeColorRow = row(L10n.tr("prefs.overlayColor"), eyeColor)
        eyeColorRow.identifier = NSUserInterfaceItemIdentifier("prefs.eyeColorRow")
        self.eyeColorRow = eyeColorRow
        scheduleStack.addArrangedSubview(eyeColorRow)
        eyeNotify.identifier = NSUserInterfaceItemIdentifier("prefs.eyeNotify")
        scheduleStack.addArrangedSubview(eyeNotify)
        let eyeLeadRow = numberRow(
            L10n.tr("prefs.notificationLead"),
            eyeLead,
            unit: L10n.tr("prefs.unit.seconds"),
            min: 0,
            max: 3600,
            identifier: "eyeLead"
        )
        eyeLeadRow.identifier = NSUserInterfaceItemIdentifier("prefs.eyeLeadRow")
        self.eyeLeadRow = eyeLeadRow
        scheduleStack.addArrangedSubview(eyeLeadRow)
        eyeManualFinish.identifier = NSUserInterfaceItemIdentifier("prefs.eyeManualFinish")
        scheduleStack.addArrangedSubview(eyeManualFinish)
        eyeEmergencyOverride.identifier = NSUserInterfaceItemIdentifier("prefs.eyeEmergencyOverride")
        scheduleStack.addArrangedSubview(eyeEmergencyOverride)
        scheduleStack.addArrangedSubview(separator())
        scheduleStack.addArrangedSubview(section(
            L10n.tr("prefs.sectionBodyBreak"),
            icon: .systemSymbol("figure.walk"),
            identifier: "prefs.section.bodyBreak"
        ))
        bodyEnabled.identifier = NSUserInterfaceItemIdentifier("prefs.bodyEnabled")
        scheduleStack.addArrangedSubview(bodyEnabled)
        let bodyIntervalRow = numberRow(
            L10n.tr("prefs.bodyIntervalMinutes"),
            bodyInterval,
            unit: L10n.tr("prefs.unit.minutes"),
            min: 1,
            max: 720,
            identifier: "bodyInterval",
            showsSlider: true
        )
        bodyIntervalRow.identifier = NSUserInterfaceItemIdentifier("prefs.bodyIntervalRow")
        self.bodyIntervalRow = bodyIntervalRow
        scheduleStack.addArrangedSubview(bodyIntervalRow)
        let bodyDurationRow = numberRow(
            L10n.tr("prefs.durationMinutes"),
            bodyDuration,
            unit: L10n.tr("prefs.unit.minutes"),
            min: 1,
            max: 180,
            identifier: "bodyDuration",
            showsSlider: true
        )
        bodyDurationRow.identifier = NSUserInterfaceItemIdentifier("prefs.bodyDurationRow")
        self.bodyDurationRow = bodyDurationRow
        scheduleStack.addArrangedSubview(bodyDurationRow)
        let bodyAfterEyeGatesRow = numberRow(
            L10n.tr("prefs.afterEyeGates"),
            bodyAfterEyeGates,
            unit: L10n.tr("prefs.unit.eyeGates"),
            min: 1,
            max: 99,
            identifier: "bodyAfterEyeGates",
            showsSlider: true
        )
        bodyAfterEyeGatesRow.identifier = NSUserInterfaceItemIdentifier("prefs.bodyAfterEyeGatesRow")
        self.bodyAfterEyeGatesRow = bodyAfterEyeGatesRow
        scheduleStack.addArrangedSubview(bodyAfterEyeGatesRow)
        let bodyColorRow = row(L10n.tr("prefs.overlayColor"), bodyColor)
        bodyColorRow.identifier = NSUserInterfaceItemIdentifier("prefs.bodyColorRow")
        self.bodyColorRow = bodyColorRow
        scheduleStack.addArrangedSubview(bodyColorRow)
        bodyNotify.identifier = NSUserInterfaceItemIdentifier("prefs.bodyNotify")
        scheduleStack.addArrangedSubview(bodyNotify)
        let bodyLeadRow = numberRow(
            L10n.tr("prefs.notificationLead"),
            bodyLead,
            unit: L10n.tr("prefs.unit.seconds"),
            min: 0,
            max: 3600,
            identifier: "bodyLead"
        )
        bodyLeadRow.identifier = NSUserInterfaceItemIdentifier("prefs.bodyLeadRow")
        self.bodyLeadRow = bodyLeadRow
        scheduleStack.addArrangedSubview(bodyLeadRow)
        let bodyPostponeMinutesRow = numberRow(
            L10n.tr("prefs.postponeMinutes"),
            bodyPostponeMinutes,
            unit: L10n.tr("prefs.unit.minutes"),
            min: 1,
            max: 120,
            identifier: "bodyPostponeMinutes"
        )
        bodyPostponeMinutesRow.identifier = NSUserInterfaceItemIdentifier("prefs.bodyPostponeMinutesRow")
        self.bodyPostponeMinutesRow = bodyPostponeMinutesRow
        scheduleStack.addArrangedSubview(bodyPostponeMinutesRow)
        let bodyPostponeLimitRow = numberRow(
            L10n.tr("prefs.maxPostpones"),
            bodyPostponeLimit,
            unit: L10n.tr("prefs.unit.times"),
            min: 0,
            max: 20,
            identifier: "bodyPostponeLimit"
        )
        bodyPostponeLimitRow.identifier = NSUserInterfaceItemIdentifier("prefs.bodyPostponeLimitRow")
        self.bodyPostponeLimitRow = bodyPostponeLimitRow
        scheduleStack.addArrangedSubview(bodyPostponeLimitRow)
        let bodyPostponeWindowPercentRow = numberRow(
            L10n.tr("prefs.postponeWindowPercent"),
            bodyPostponeWindowPercent,
            unit: L10n.tr("prefs.unit.percent"),
            min: 0,
            max: 100,
            identifier: "bodyPostponeWindowPercent"
        )
        bodyPostponeWindowPercentRow.identifier = NSUserInterfaceItemIdentifier("prefs.bodyPostponeWindowPercentRow")
        self.bodyPostponeWindowPercentRow = bodyPostponeWindowPercentRow
        scheduleStack.addArrangedSubview(bodyPostponeWindowPercentRow)
        bodyAllowSkip.identifier = NSUserInterfaceItemIdentifier("prefs.bodyAllowSkip")
        scheduleStack.addArrangedSubview(bodyAllowSkip)
        bodyManualFinish.identifier = NSUserInterfaceItemIdentifier("prefs.bodyManualFinish")
        scheduleStack.addArrangedSubview(bodyManualFinish)
        bodyCoversAllDisplays.identifier = NSUserInterfaceItemIdentifier("prefs.bodyCoversAllDisplays")
        scheduleStack.addArrangedSubview(bodyCoversAllDisplays)
        let bodyCoveredDisplayRow = row(L10n.tr("prefs.bodyCoveredDisplay"), bodyCoveredDisplay)
        bodyCoveredDisplay.identifier = NSUserInterfaceItemIdentifier("prefs.bodyCoveredDisplay")
        bodyCoveredDisplayRow.identifier = NSUserInterfaceItemIdentifier("prefs.bodyCoveredDisplayRow")
        self.bodyCoveredDisplayRow = bodyCoveredDisplayRow
        scheduleStack.addArrangedSubview(bodyCoveredDisplayRow)
        let bodyContentDisplayRow = row(L10n.tr("prefs.bodyContentDisplay"), bodyContentDisplay)
        bodyContentDisplay.identifier = NSUserInterfaceItemIdentifier("prefs.bodyContentDisplay")
        bodyContentDisplayRow.identifier = NSUserInterfaceItemIdentifier("prefs.bodyContentDisplayRow")
        self.bodyContentDisplayRow = bodyContentDisplayRow
        scheduleStack.addArrangedSubview(bodyContentDisplayRow)
        bodyBlankSecondaryDisplays.identifier = NSUserInterfaceItemIdentifier("prefs.bodyBlankSecondaryDisplays")
        scheduleStack.addArrangedSubview(bodyBlankSecondaryDisplays)
        let bodyConfiguredDisplayRow = row(L10n.tr("prefs.configuredDisplayIndex"), bodyConfiguredDisplay)
        bodyConfiguredDisplayRow.identifier = NSUserInterfaceItemIdentifier("prefs.bodyConfiguredDisplayRow")
        self.bodyConfiguredDisplayRow = bodyConfiguredDisplayRow
        scheduleStack.addArrangedSubview(bodyConfiguredDisplayRow)
        scheduleStack.addArrangedSubview(indentedControlRow(bodyDisplaySummaryLabel))
        configureSchedulePreferenceHelp()
        addTab(to: tabView, title: L10n.tr("prefs.tabSchedule"), icon: .systemSymbol("clock"), stack: scheduleStack)

        let contextStack = contentStack()
        contextStack.addArrangedSubview(section(L10n.tr("prefs.sectionContext"), symbolName: "scope"))
        contextStack.addArrangedSubview(contextSummaryView())
        naturalBreaks.identifier = NSUserInterfaceItemIdentifier("prefs.naturalBreaks")
        contextStack.addArrangedSubview(naturalBreaks)
        let naturalIdleMinutesRow = numberRow(
            L10n.tr("prefs.naturalIdleMinutes"),
            naturalIdleMinutes,
            unit: L10n.tr("prefs.unit.minutes"),
            min: 1,
            max: 120,
            identifier: "naturalIdleMinutes"
        )
        naturalIdleMinutesRow.identifier = NSUserInterfaceItemIdentifier("prefs.naturalIdleMinutesRow")
        self.naturalIdleMinutesRow = naturalIdleMinutesRow
        contextStack.addArrangedSubview(naturalIdleMinutesRow)
        focusMonitor.identifier = NSUserInterfaceItemIdentifier("prefs.focusMonitor")
        contextStack.addArrangedSubview(focusMonitor)
        focusDefersBody.identifier = NSUserInterfaceItemIdentifier("prefs.focusDefersBody")
        contextStack.addArrangedSubview(focusDefersBody)
        workingHoursEnabled.identifier = NSUserInterfaceItemIdentifier("prefs.workingHours")
        contextStack.addArrangedSubview(workingHoursEnabled)
        let workingStartRow = row(L10n.tr("prefs.workingStart"), workingStartPicker)
        workingStartPicker.identifier = NSUserInterfaceItemIdentifier("prefs.workingStartPicker")
        workingStartRow.identifier = NSUserInterfaceItemIdentifier("prefs.workingStartRow")
        self.workingStartRow = workingStartRow
        contextStack.addArrangedSubview(workingStartRow)
        let workingEndRow = row(L10n.tr("prefs.workingEnd"), workingEndPicker)
        workingEndPicker.identifier = NSUserInterfaceItemIdentifier("prefs.workingEndPicker")
        workingEndRow.identifier = NSUserInterfaceItemIdentifier("prefs.workingEndRow")
        self.workingEndRow = workingEndRow
        contextStack.addArrangedSubview(workingEndRow)
        contextStack.addArrangedSubview(separator())
        contextStack.addArrangedSubview(section(L10n.tr("prefs.sectionExclusion"), symbolName: "app.badge"))
        appExclusionEnabled.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionEnabled")
        contextStack.addArrangedSubview(appExclusionEnabled)
        let appExclusionNameRow = row(L10n.tr("prefs.name"), appExclusionName)
        appExclusionName.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionNameField")
        appExclusionNameRow.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionNameRow")
        self.appExclusionNameRow = appExclusionNameRow
        contextStack.addArrangedSubview(appExclusionNameRow)
        let appExclusionTermsRow = row(L10n.tr("prefs.matchTerms"), appExclusionTermsPickerRow())
        appExclusionTerms.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionTermsField")
        appExclusionTermsRow.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionTermsRow")
        self.appExclusionTermsRow = appExclusionTermsRow
        contextStack.addArrangedSubview(appExclusionTermsRow)
        let appExclusionModeRow = row(L10n.tr("prefs.mode"), appExclusionMode)
        appExclusionMode.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionMode")
        appExclusionModeRow.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionModeRow")
        self.appExclusionModeRow = appExclusionModeRow
        contextStack.addArrangedSubview(appExclusionModeRow)
        appExclusionAppliesEye.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionAppliesEye")
        contextStack.addArrangedSubview(appExclusionAppliesEye)
        appExclusionAppliesBody.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionAppliesBody")
        contextStack.addArrangedSubview(appExclusionAppliesBody)
        contextStack.addArrangedSubview(indentedControlRow(appExclusionPreviewLabel))
        let appExclusionAddRuleRow = indentedControlRow(appExclusionRuleActionRow())
        appExclusionAddRuleRow.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionAddRuleRow")
        self.appExclusionAddRuleRow = appExclusionAddRuleRow
        contextStack.addArrangedSubview(appExclusionAddRuleRow)
        let appExclusionRulesListRow = multilineRow(L10n.tr("prefs.appExclusionRules"), appExclusionRulesListStack)
        appExclusionRulesListRow.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionRulesListRow")
        self.appExclusionRulesListRow = appExclusionRulesListRow
        contextStack.addArrangedSubview(appExclusionRulesListRow)
        contextStack.addArrangedSubview(appExclusionsAdvancedButton)
        let appExclusionsJSONRow = advancedBulkEditorRow(
            L10n.tr("prefs.advancedRulesJSON"),
            guidance: L10n.tr("prefs.advancedRulesGuidance"),
            field: appExclusionsJSONScrollView,
            guidanceIdentifier: "prefs.appExclusionsJSONGuidance",
            actions: [appExclusionsCopyBulkButton, appExclusionsRestoreBulkButton]
        )
        appExclusionsJSONRow.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionsJSONRow")
        self.appExclusionsJSONRow = appExclusionsJSONRow
        contextStack.addArrangedSubview(appExclusionsJSONRow)
        addTab(to: tabView, title: L10n.tr("prefs.tabContext"), icon: .systemSymbol("scope"), stack: contextStack)

        let appearanceStack = contentStack()
        appearanceStack.addArrangedSubview(section(L10n.tr("prefs.sectionPresentation"), symbolName: "paintbrush"))
        themeSource.identifier = NSUserInterfaceItemIdentifier("prefs.theme")
        appearanceStack.addArrangedSubview(row(L10n.tr("prefs.theme"), themeSource))
        languageIdentifier.identifier = NSUserInterfaceItemIdentifier("prefs.language")
        appearanceStack.addArrangedSubview(row(L10n.tr("prefs.language"), languageIdentifier))
        currentTimeInBodyBreak.identifier = NSUserInterfaceItemIdentifier("prefs.currentTimeBody")
        appearanceStack.addArrangedSubview(currentTimeInBodyBreak)
        breakHealth.identifier = NSUserInterfaceItemIdentifier("prefs.breakHealth")
        appearanceStack.addArrangedSubview(breakHealth)
        silentNotifications.identifier = NSUserInterfaceItemIdentifier("prefs.silentNotifications")
        appearanceStack.addArrangedSubview(silentNotifications)
        let eyeStartSoundRow = row(L10n.tr("prefs.eyeStartSound"), soundPickerRow(eyeStartSound, eyeStartSoundPreview))
        eyeStartSound.identifier = NSUserInterfaceItemIdentifier("prefs.eyeStartSound")
        eyeStartSoundRow.identifier = NSUserInterfaceItemIdentifier("prefs.eyeStartSoundRow")
        self.eyeStartSoundRow = eyeStartSoundRow
        appearanceStack.addArrangedSubview(eyeStartSoundRow)
        let eyeFinishSoundRow = row(L10n.tr("prefs.eyeFinishSound"), soundPickerRow(eyeFinishSound, eyeFinishSoundPreview))
        eyeFinishSound.identifier = NSUserInterfaceItemIdentifier("prefs.eyeFinishSound")
        eyeFinishSoundRow.identifier = NSUserInterfaceItemIdentifier("prefs.eyeFinishSoundRow")
        self.eyeFinishSoundRow = eyeFinishSoundRow
        appearanceStack.addArrangedSubview(eyeFinishSoundRow)
        let bodyStartSoundRow = row(L10n.tr("prefs.bodyStartSound"), soundPickerRow(bodyStartSound, bodyStartSoundPreview))
        bodyStartSound.identifier = NSUserInterfaceItemIdentifier("prefs.bodyStartSound")
        bodyStartSoundRow.identifier = NSUserInterfaceItemIdentifier("prefs.bodyStartSoundRow")
        self.bodyStartSoundRow = bodyStartSoundRow
        appearanceStack.addArrangedSubview(bodyStartSoundRow)
        let bodyFinishSoundRow = row(L10n.tr("prefs.bodyFinishSound"), soundPickerRow(bodyFinishSound, bodyFinishSoundPreview))
        bodyFinishSound.identifier = NSUserInterfaceItemIdentifier("prefs.bodyFinishSound")
        bodyFinishSoundRow.identifier = NSUserInterfaceItemIdentifier("prefs.bodyFinishSoundRow")
        self.bodyFinishSoundRow = bodyFinishSoundRow
        appearanceStack.addArrangedSubview(bodyFinishSoundRow)
        let soundVolumeControlRow = row(L10n.tr("prefs.volume"), soundVolumeRow())
        soundVolumeControlRow.identifier = NSUserInterfaceItemIdentifier("prefs.soundVolumeRow")
        appearanceStack.addArrangedSubview(soundVolumeControlRow)
        appearanceStack.addArrangedSubview(soundPreviewStatusLabel)
        appearanceStack.addArrangedSubview(separator())
        appearanceStack.addArrangedSubview(section(L10n.tr("prefs.sectionCustomIdea"), symbolName: "text.bubble"))
        useBuiltInIdeas.identifier = NSUserInterfaceItemIdentifier("prefs.useBuiltInIdeas")
        appearanceStack.addArrangedSubview(useBuiltInIdeas)
        let localImagePathRow = row(L10n.tr("prefs.localImagePath"), localImagePickerRow())
        localImagePathRow.identifier = NSUserInterfaceItemIdentifier("prefs.localImagePathRow")
        self.localImagePathRow = localImagePathRow
        appearanceStack.addArrangedSubview(localImagePathRow)
        appearanceStack.addArrangedSubview(indentedControlRow(bodyContentSummaryLabel))
        let customBodyTitleRow = row(L10n.tr("prefs.title"), customBodyTitle)
        customBodyTitle.identifier = NSUserInterfaceItemIdentifier("prefs.customBodyTitleField")
        customBodyTitleRow.identifier = NSUserInterfaceItemIdentifier("prefs.customBodyTitleRow")
        self.customBodyTitleRow = customBodyTitleRow
        appearanceStack.addArrangedSubview(customBodyTitleRow)
        let customBodyTextRow = multilineRow(L10n.tr("prefs.text"), customBodyTextScrollView)
        customBodyTextRow.identifier = NSUserInterfaceItemIdentifier("prefs.customBodyTextRow")
        self.customBodyTextRow = customBodyTextRow
        appearanceStack.addArrangedSubview(customBodyTextRow)
        let customBodyAddIdeaButtonRow = indentedControlRow(customBodyIdeaActionRow())
        customBodyAddIdeaButtonRow.identifier = NSUserInterfaceItemIdentifier("prefs.customBodyAddIdeaButtonRow")
        self.customBodyAddIdeaButtonRow = customBodyAddIdeaButtonRow
        appearanceStack.addArrangedSubview(customBodyAddIdeaButtonRow)
        let customBodyIdeasListRow = multilineRow(L10n.tr("prefs.customIdeaRotation"), customBodyIdeasListStack)
        customBodyIdeasListRow.identifier = NSUserInterfaceItemIdentifier("prefs.customBodyIdeasListRow")
        self.customBodyIdeasListRow = customBodyIdeasListRow
        appearanceStack.addArrangedSubview(customBodyIdeasListRow)
        appearanceStack.addArrangedSubview(customBodyIdeasAdvancedButton)
        let customBodyIdeasJSONRow = advancedBulkEditorRow(
            L10n.tr("prefs.advancedIdeasJSON"),
            guidance: L10n.tr("prefs.advancedIdeasGuidance"),
            field: customBodyIdeasJSONScrollView,
            guidanceIdentifier: "prefs.customBodyIdeasJSONGuidance",
            actions: [customBodyIdeasCopyBulkButton, customBodyIdeasRestoreBulkButton]
        )
        customBodyIdeasJSONRow.identifier = NSUserInterfaceItemIdentifier("prefs.customBodyIdeasJSONRow")
        self.customBodyIdeasJSONRow = customBodyIdeasJSONRow
        appearanceStack.addArrangedSubview(customBodyIdeasJSONRow)
        configureAppearancePreferenceHelp()
        addTab(to: tabView, title: L10n.tr("prefs.tabAppearance"), icon: .systemSymbol("paintbrush"), stack: appearanceStack)

        let shortcutsStack = contentStack()
        shortcutsStack.addArrangedSubview(section(L10n.tr("prefs.sectionShortcuts"), symbolName: "keyboard"))
        shortcutsStack.addArrangedSubview(shortcutConflictRow)
        shortcutPauseToggle.identifier = NSUserInterfaceItemIdentifier("shortcut.pauseToggle")
        shortcutPause30.identifier = NSUserInterfaceItemIdentifier("shortcut.pause30")
        shortcutPause1h.identifier = NSUserInterfaceItemIdentifier("shortcut.pause1h")
        shortcutPause2h.identifier = NSUserInterfaceItemIdentifier("shortcut.pause2h")
        shortcutPause5h.identifier = NSUserInterfaceItemIdentifier("shortcut.pause5h")
        shortcutPauseUntilMorning.identifier = NSUserInterfaceItemIdentifier("shortcut.pauseUntilMorning")
        shortcutNextScheduled.identifier = NSUserInterfaceItemIdentifier("shortcut.nextScheduled")
        shortcutEyeNow.identifier = NSUserInterfaceItemIdentifier("shortcut.eyeNow")
        shortcutBodyNow.identifier = NSUserInterfaceItemIdentifier("shortcut.bodyNow")
        shortcutEndBody.identifier = NSUserInterfaceItemIdentifier("shortcut.endBody")
        shortcutEmergencyEye.identifier = NSUserInterfaceItemIdentifier("shortcut.emergencyEye")
        shortcutReset.identifier = NSUserInterfaceItemIdentifier("shortcut.reset")
        shortcutsStack.addArrangedSubview(shortcutRow(
            L10n.tr("prefs.pauseToggle"),
            shortcutPauseToggle,
            help: L10n.tr("prefs.pauseToggleShortcutHelp")
        ))
        shortcutsStack.addArrangedSubview(shortcutRow(
            L10n.tr("prefs.pause30Shortcut"),
            shortcutPause30,
            help: L10n.tr("prefs.pause30ShortcutHelp")
        ))
        shortcutsStack.addArrangedSubview(shortcutRow(
            L10n.tr("prefs.pause1hShortcut"),
            shortcutPause1h,
            help: L10n.tr("prefs.pause1hShortcutHelp")
        ))
        shortcutsStack.addArrangedSubview(shortcutRow(
            L10n.tr("prefs.pause2hShortcut"),
            shortcutPause2h,
            help: L10n.tr("prefs.pause2hShortcutHelp")
        ))
        shortcutsStack.addArrangedSubview(shortcutRow(
            L10n.tr("prefs.pause5hShortcut"),
            shortcutPause5h,
            help: L10n.tr("prefs.pause5hShortcutHelp")
        ))
        shortcutsStack.addArrangedSubview(shortcutRow(
            L10n.tr("prefs.pauseUntilMorningShortcut"),
            shortcutPauseUntilMorning,
            help: L10n.tr("prefs.pauseUntilMorningShortcutHelp")
        ))
        shortcutsStack.addArrangedSubview(shortcutRow(
            L10n.tr("prefs.nextScheduledRest"),
            shortcutNextScheduled,
            help: L10n.tr("prefs.nextScheduledRestHelp")
        ))
        let shortcutEyeNowRow = shortcutRow(
            L10n.tr("prefs.eyeGateNow"),
            shortcutEyeNow,
            help: L10n.tr("prefs.eyeGateNowHelp")
        )
        shortcutEyeNowRow.identifier = NSUserInterfaceItemIdentifier("prefs.shortcutEyeNowRow")
        self.shortcutEyeNowRow = shortcutEyeNowRow
        shortcutsStack.addArrangedSubview(shortcutEyeNowRow)
        let shortcutBodyNowRow = shortcutRow(
            L10n.tr("prefs.bodyBreakNow"),
            shortcutBodyNow,
            help: L10n.tr("prefs.bodyBreakNowHelp")
        )
        shortcutBodyNowRow.identifier = NSUserInterfaceItemIdentifier("prefs.shortcutBodyNowRow")
        self.shortcutBodyNowRow = shortcutBodyNowRow
        shortcutsStack.addArrangedSubview(shortcutBodyNowRow)
        let shortcutEndBodyRow = shortcutRow(
            activeRestShortcutTitle(
                eyeGateEnabled: settings.eyeGate.isEnabled,
                bodyBreakEnabled: settings.bodyBreak.isEnabled,
                eyeManualFinishEnabled: settings.eyeGate.manualFinishEnabled
            ),
            shortcutEndBody,
            help: activeRestShortcutHelp(
                eyeGateEnabled: settings.eyeGate.isEnabled,
                bodyBreakEnabled: settings.bodyBreak.isEnabled,
                eyeManualFinishEnabled: settings.eyeGate.manualFinishEnabled
            )
        )
        shortcutEndBodyRow.identifier = NSUserInterfaceItemIdentifier("prefs.shortcutEndBodyRow")
        if let label = shortcutEndBodyRow.arrangedSubviews.first as? NSTextField {
            label.identifier = NSUserInterfaceItemIdentifier("prefs.shortcutEndBodyLabel")
            shortcutEndBodyLabel = label
        }
        self.shortcutEndBodyRow = shortcutEndBodyRow
        shortcutsStack.addArrangedSubview(shortcutEndBodyRow)
        let shortcutEmergencyEyeRow = shortcutRow(
            L10n.tr("prefs.emergencyEyeGate"),
            shortcutEmergencyEye,
            help: L10n.tr("prefs.emergencyEyeGateShortcutHelp")
        )
        shortcutEmergencyEyeRow.identifier = NSUserInterfaceItemIdentifier("prefs.shortcutEmergencyEyeRow")
        self.shortcutEmergencyEyeRow = shortcutEmergencyEyeRow
        shortcutsStack.addArrangedSubview(shortcutEmergencyEyeRow)
        shortcutsStack.addArrangedSubview(shortcutRow(
            L10n.tr("prefs.reset"),
            shortcutReset,
            help: L10n.tr("prefs.resetShortcutHelp")
        ))
        addTab(to: tabView, title: L10n.tr("prefs.tabShortcuts"), icon: .systemSymbol("keyboard"), stack: shortcutsStack)

        let advancedStack = contentStack()
        advancedStack.addArrangedSubview(section(L10n.tr("prefs.sectionOperations"), symbolName: "gearshape"))
        openAtLogin.identifier = NSUserInterfaceItemIdentifier("prefs.openAtLogin")
        advancedStack.addArrangedSubview(openAtLogin)
        checkUpdates.identifier = NSUserInterfaceItemIdentifier("prefs.checkUpdates")
        advancedStack.addArrangedSubview(checkUpdates)
        notifyNewVersion.identifier = NSUserInterfaceItemIdentifier("prefs.notifyNewVersion")
        advancedStack.addArrangedSubview(notifyNewVersion)
        showOnboardingNextLaunch.identifier = NSUserInterfaceItemIdentifier("prefs.showOnboardingNextLaunch")
        advancedStack.addArrangedSubview(showOnboardingNextLaunch)
        let pauseUntilMorningModeRow = row(L10n.tr("prefs.pauseUntilMorningMode"), pauseUntilMorningMode)
        pauseUntilMorningMode.identifier = NSUserInterfaceItemIdentifier("prefs.pauseUntilMorningMode")
        advancedStack.addArrangedSubview(pauseUntilMorningModeRow)
        let pauseUntilMorningLocationRow = row(L10n.tr("prefs.pauseUntilMorningLocation"), pauseUntilMorningLocation)
        pauseUntilMorningLocation.identifier = NSUserInterfaceItemIdentifier("prefs.pauseUntilMorningLocation")
        pauseUntilMorningLocationRow.identifier = NSUserInterfaceItemIdentifier("prefs.pauseUntilMorningLocationRow")
        self.pauseUntilMorningLocationRow = pauseUntilMorningLocationRow
        advancedStack.addArrangedSubview(pauseUntilMorningLocationRow)
        let pauseUntilMorningHourRow = numberRow(
            L10n.tr("prefs.pauseUntilMorningHour"),
            pauseUntilMorningHour,
            unit: L10n.tr("prefs.unit.hour"),
            min: 0,
            max: 23,
            identifier: "pauseUntilMorningHour"
        )
        pauseUntilMorningHourRow.identifier = NSUserInterfaceItemIdentifier("prefs.pauseUntilMorningHourRow")
        self.pauseUntilMorningHourRow = pauseUntilMorningHourRow
        advancedStack.addArrangedSubview(pauseUntilMorningHourRow)
        let pauseUntilMorningLatitudeRow = row(L10n.tr("prefs.pauseUntilMorningLatitude"), pauseUntilMorningLatitude)
        pauseUntilMorningLatitude.identifier = NSUserInterfaceItemIdentifier("prefs.pauseUntilMorningLatitudeField")
        pauseUntilMorningLatitudeRow.identifier = NSUserInterfaceItemIdentifier("prefs.pauseUntilMorningLatitudeRow")
        self.pauseUntilMorningLatitudeRow = pauseUntilMorningLatitudeRow
        advancedStack.addArrangedSubview(pauseUntilMorningLatitudeRow)
        let pauseUntilMorningLongitudeRow = row(L10n.tr("prefs.pauseUntilMorningLongitude"), pauseUntilMorningLongitude)
        pauseUntilMorningLongitude.identifier = NSUserInterfaceItemIdentifier("prefs.pauseUntilMorningLongitudeField")
        pauseUntilMorningLongitudeRow.identifier = NSUserInterfaceItemIdentifier("prefs.pauseUntilMorningLongitudeRow")
        self.pauseUntilMorningLongitudeRow = pauseUntilMorningLongitudeRow
        advancedStack.addArrangedSubview(pauseUntilMorningLongitudeRow)
        advancedStack.addArrangedSubview(indentedControlRow(pauseUntilMorningSummaryLabel))
        pauseForSuspendOrLock.identifier = NSUserInterfaceItemIdentifier("prefs.pauseForSuspendOrLock")
        advancedStack.addArrangedSubview(pauseForSuspendOrLock)
        advancedStack.addArrangedSubview(updateSourceAdvancedButton)
        let updateFeedURLRow = row(L10n.tr("prefs.updateFeedURL"), updateSourceRow())
        updateFeedURL.identifier = NSUserInterfaceItemIdentifier("prefs.updateFeedURLField")
        updateFeedURLRow.identifier = NSUserInterfaceItemIdentifier("prefs.updateFeedURLRow")
        self.updateFeedURLRow = updateFeedURLRow
        advancedStack.addArrangedSubview(updateFeedURLRow)
        advancedStack.addArrangedSubview(separator())
        adminControlsStack.orientation = .vertical
        adminControlsStack.alignment = .leading
        adminControlsStack.spacing = 14
        adminControlsStack.edgeInsets = NSEdgeInsets(top: 0, left: 22, bottom: 0, right: 0)
        disableUpdateFeatures.identifier = NSUserInterfaceItemIdentifier("prefs.adminHideUpdates")
        adminControlsStack.addArrangedSubview(disableUpdateFeatures)
        hideSettingsPath.identifier = NSUserInterfaceItemIdentifier("prefs.adminHideSettingsPath")
        adminControlsStack.addArrangedSubview(hideSettingsPath)
        hideStrictPreferences.identifier = NSUserInterfaceItemIdentifier("prefs.adminHideStrict")
        adminControlsStack.addArrangedSubview(hideStrictPreferences)
        customPreferencesMessage.identifier = NSUserInterfaceItemIdentifier("prefs.preferencesMessageField")
        adminControlsStack.addArrangedSubview(row(L10n.tr("prefs.preferencesMessage"), customPreferencesMessage))
        advancedStack.addArrangedSubview(adminControlsAdvancedButton)
        advancedStack.addArrangedSubview(adminControlsStack)
        addTab(to: tabView, title: L10n.tr("prefs.tabAdvanced"), icon: .systemSymbol("gearshape"), stack: advancedStack)

        let footer = footerBar()
        root.addArrangedSubview(footer)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            header.widthAnchor.constraint(equalTo: root.widthAnchor),
            tabView.widthAnchor.constraint(equalTo: root.widthAnchor),
            footer.widthAnchor.constraint(equalTo: root.widthAnchor)
        ])
    }

    private func preferencesHeaderBar() -> NSStackView {
        let icon = NSImageView(image: RestGateIcon.fallbackAppImage(
            size: 36,
            accessibilityDescription: L10n.tr("app.name")
        ))
        icon.identifier = NSUserInterfaceItemIdentifier("prefs.headerIcon")
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.widthAnchor.constraint(equalToConstant: 36).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let title = NSTextField(labelWithString: L10n.tr("preferences.title"))
        title.identifier = NSUserInterfaceItemIdentifier("prefs.headerTitle")
        title.font = .systemFont(ofSize: 17, weight: .semibold)

        let subtitle = NSTextField(labelWithString: L10n.tr("prefs.headerSubtitle"))
        subtitle.identifier = NSUserInterfaceItemIdentifier("prefs.headerSubtitle")
        subtitle.font = .systemFont(ofSize: 12, weight: .regular)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byWordWrapping
        subtitle.maximumNumberOfLines = 2
        subtitle.widthAnchor.constraint(lessThanOrEqualToConstant: 340).isActive = true

        let copy = NSStackView(views: [title, subtitle])
        copy.orientation = .vertical
        copy.alignment = .leading
        copy.spacing = 2

        let statusStack = NSStackView(views: [saveStatusIcon, saveStatusLabel])
        statusStack.identifier = NSUserInterfaceItemIdentifier("prefs.headerAutosave")
        statusStack.orientation = .horizontal
        statusStack.spacing = 6
        statusStack.alignment = .centerY
        statusStack.setContentHuggingPriority(.required, for: .horizontal)
        statusStack.setContentCompressionResistancePriority(.required, for: .horizontal)

        let searchStack = NSStackView(views: [searchField, searchStatusLabel])
        searchStack.identifier = NSUserInterfaceItemIdentifier("prefs.headerSearch")
        searchStack.orientation = .vertical
        searchStack.spacing = 2
        searchStack.alignment = .leading
        searchStack.setContentHuggingPriority(.required, for: .horizontal)
        searchStack.setContentCompressionResistancePriority(.required, for: .horizontal)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let header = NSStackView(views: [icon, copy, spacer, searchStack, statusStack])
        header.identifier = NSUserInterfaceItemIdentifier("prefs.header")
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12
        header.edgeInsets = NSEdgeInsets(top: 14, left: 24, bottom: 14, right: 24)
        header.wantsLayer = true
        header.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.55).cgColor
        header.layer?.borderWidth = 1
        header.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.7).cgColor
        return header
    }

    private func footerBar() -> NSStackView {
        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.spacing = 12
        footer.alignment = .centerY
        footer.edgeInsets = NSEdgeInsets(top: 10, left: 24, bottom: 14, right: 24)
        restoreDefaultsButton.title = L10n.tr("prefs.restoreDefaults")
        restoreDefaultsButton.target = self
        restoreDefaultsButton.action = #selector(restoreDefaultsPressed)
        restoreDefaultsButton.identifier = NSUserInterfaceItemIdentifier("prefs.restoreDefaultsButton")
        restoreDefaultsButton.image = NSImage(
            systemSymbolName: "arrow.counterclockwise",
            accessibilityDescription: restoreDefaultsButton.title
        )
        restoreDefaultsButton.imagePosition = .imageLeading
        updateRestoreDefaultsButtonState()
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        footer.addArrangedSubview(spacer)
        footer.addArrangedSubview(restoreDefaultsButton)
        return footer
    }

    private func contentStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func scheduleSummaryView() -> NSStackView {
        scheduleSummaryIcon.identifier = NSUserInterfaceItemIdentifier("prefs.scheduleSummaryIcon")
        scheduleSummaryIcon.image = NSImage(
            systemSymbolName: "timer",
            accessibilityDescription: L10n.tr("prefs.tabSchedule")
        )
        scheduleSummaryIcon.symbolConfiguration = .init(pointSize: 15, weight: .semibold)
        scheduleSummaryIcon.contentTintColor = .secondaryLabelColor
        scheduleSummaryIcon.setAccessibilityLabel(L10n.tr("prefs.tabSchedule"))
        scheduleSummaryIcon.widthAnchor.constraint(equalToConstant: 20).isActive = true

        scheduleSummaryLabel.identifier = NSUserInterfaceItemIdentifier("prefs.scheduleSummaryLabel")
        scheduleSummaryLabel.textColor = .secondaryLabelColor
        scheduleSummaryLabel.lineBreakMode = .byWordWrapping
        scheduleSummaryLabel.maximumNumberOfLines = 3
        scheduleSummaryLabel.widthAnchor.constraint(equalToConstant: 590).isActive = true

        let stack = NSStackView(views: [scheduleSummaryIcon, scheduleSummaryLabel])
        stack.identifier = NSUserInterfaceItemIdentifier("prefs.scheduleSummary")
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .top
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        stack.wantsLayer = true
        stack.layer?.cornerRadius = 7
        stack.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
        stack.layer?.borderWidth = 1
        stack.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor
        return stack
    }

    private func contextSummaryView() -> NSStackView {
        contextSummaryIcon.identifier = NSUserInterfaceItemIdentifier("prefs.contextSummaryIcon")
        contextSummaryIcon.image = NSImage(
            systemSymbolName: "scope",
            accessibilityDescription: L10n.tr("prefs.tabContext")
        )
        contextSummaryIcon.symbolConfiguration = .init(pointSize: 15, weight: .semibold)
        contextSummaryIcon.contentTintColor = .secondaryLabelColor
        contextSummaryIcon.setAccessibilityLabel(L10n.tr("prefs.tabContext"))
        contextSummaryIcon.widthAnchor.constraint(equalToConstant: 20).isActive = true

        contextSummaryLabel.identifier = NSUserInterfaceItemIdentifier("prefs.contextSummaryLabel")
        contextSummaryLabel.textColor = .secondaryLabelColor
        contextSummaryLabel.lineBreakMode = .byWordWrapping
        contextSummaryLabel.maximumNumberOfLines = 4
        contextSummaryLabel.widthAnchor.constraint(equalToConstant: 590).isActive = true

        let stack = NSStackView(views: [contextSummaryIcon, contextSummaryLabel])
        stack.identifier = NSUserInterfaceItemIdentifier("prefs.contextSummary")
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .top
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        stack.wantsLayer = true
        stack.layer?.cornerRadius = 7
        stack.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
        stack.layer?.borderWidth = 1
        stack.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor
        return stack
    }

    private func rhythmPresetRow() -> NSStackView {
        let stack = NSStackView(views: [
            rhythmPresetRecommendedButton,
            rhythmPresetFrequentEyeButton,
            rhythmPresetMovementButton
        ])
        stack.identifier = NSUserInterfaceItemIdentifier("prefs.rhythmPresetRow")
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        return stack
    }

    private func addTab(to tabView: NSTabView, title: String, icon: PreferencesTabIcon, stack: NSStackView) {
        let item = NSTabViewItem(identifier: title)
        item.label = title
        item.toolTip = title
        item.image = tabImage(icon, accessibilityDescription: title)
        item.view = scrollContainer(for: stack)
        tabView.addTabViewItem(item)
        registerSearchTargets(in: stack, tabIdentifier: title)
    }

    private func tabImage(_ icon: PreferencesTabIcon, accessibilityDescription: String) -> NSImage {
        switch icon {
        case let .systemSymbol(symbolName):
            let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)?
                .withSymbolConfiguration(configuration)
                ?? NSImage(systemSymbolName: "circle", accessibilityDescription: accessibilityDescription)
                ?? NSImage(size: NSSize(width: 14, height: 14))
            image.isTemplate = true
            image.accessibilityDescription = accessibilityDescription
            return image
        }
    }

    private func scrollContainer(for stack: NSStackView) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        let documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView
        documentView.addSubview(stack)

        NSLayoutConstraint.activate([
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor)
        ])

        return scrollView
    }

    private func configurePopups() {
        configurePopup(appExclusionMode, options: [
            (AppExclusionRule.Mode.pauseWhenMatched.rawValue, L10n.tr("prefs.exclusionMode.pauseWhenMatched")),
            (AppExclusionRule.Mode.resumeOnlyWhenMatched.rawValue, L10n.tr("prefs.exclusionMode.resumeOnlyWhenMatched"))
        ])
        configurePopup(themeSource, options: [
            (ThemeSource.system.rawValue, L10n.tr("prefs.theme.system")),
            (ThemeSource.light.rawValue, L10n.tr("prefs.theme.light")),
            (ThemeSource.dark.rawValue, L10n.tr("prefs.theme.dark"))
        ])
        configurePopup(pauseUntilMorningMode, options: [
            (MorningPauseMode.hour.rawValue, L10n.tr("prefs.morningMode.hour")),
            (MorningPauseMode.sunrise.rawValue, L10n.tr("prefs.morningMode.sunrise"))
        ])
        pauseUntilMorningMode.identifier = NSUserInterfaceItemIdentifier("prefs.pauseUntilMorningMode")
        configureSunriseLocationPopup()
        for option in LanguageOption.allCases {
            languageIdentifier.addItem(withTitle: option.title)
            languageIdentifier.lastItem?.representedObject = option.popupValue
        }
        [eyeStartSound, eyeFinishSound, bodyStartSound, bodyFinishSound].forEach(configureSoundPopup)
        configurePopup(bodyCoveredDisplay, options: [
            (DisplaySelection.primary.rawValue, L10n.tr("prefs.display.primary")),
            (DisplaySelection.cursor.rawValue, L10n.tr("prefs.display.cursor")),
            (DisplaySelection.configured.rawValue, L10n.tr("prefs.display.configured"))
        ])
        configurePopup(bodyContentDisplay, options: [
            (DisplaySelection.all.rawValue, L10n.tr("prefs.display.all")),
            (DisplaySelection.primary.rawValue, L10n.tr("prefs.display.primary")),
            (DisplaySelection.cursor.rawValue, L10n.tr("prefs.display.cursor")),
            (DisplaySelection.configured.rawValue, L10n.tr("prefs.display.configured")),
            (DisplaySelection.none.rawValue, L10n.tr("prefs.display.none"))
        ])
        bodyConfiguredDisplay.identifier = NSUserInterfaceItemIdentifier("prefs.bodyConfiguredDisplay")
    }

    private func configureFieldWidths() {
        let compactFields = [
            eyeInterval, eyeDuration, bodyInterval, bodyDuration, bodyAfterEyeGates, eyeLead, bodyLead,
            bodyPostponeMinutes, bodyPostponeLimit, bodyPostponeWindowPercent, naturalIdleMinutes,
            pauseUntilMorningHour,
            pauseUntilMorningLatitude, pauseUntilMorningLongitude
        ]
        compactFields.forEach { $0.widthAnchor.constraint(equalToConstant: 110).isActive = true }
        [eyeColor, bodyColor].forEach { colorWell in
            colorWell.widthAnchor.constraint(equalToConstant: 56).isActive = true
            colorWell.heightAnchor.constraint(equalToConstant: 28).isActive = true
        }

        let wideFields: [NSView] = [
            eyeStartSound, eyeFinishSound, bodyStartSound, bodyFinishSound, customBodyTitle,
            localImagePath, themeSource, languageIdentifier, shortcutPauseToggle,
            shortcutPause30, shortcutPause1h, shortcutPause2h, shortcutPause5h, shortcutPauseUntilMorning,
            shortcutNextScheduled, shortcutEyeNow, shortcutBodyNow, shortcutEndBody,
            shortcutEmergencyEye, shortcutReset,
            appExclusionName, bodyConfiguredDisplay, pauseUntilMorningLocation, updateFeedURL,
            customPreferencesMessage
        ]
        wideFields.forEach { $0.widthAnchor.constraint(equalToConstant: 360).isActive = true }
    }

    private func configureAdvancedDisclosureButtons() {
        configureDisclosureButton(
            appExclusionsAdvancedButton,
            identifier: "appExclusions",
            expanded: false
        )
        configureDisclosureButton(
            customBodyIdeasAdvancedButton,
            identifier: "customIdeas",
            expanded: false
        )
        configureDisclosureButton(
            adminControlsAdvancedButton,
            identifier: "adminControls",
            expanded: false
        )
        configureDisclosureButton(
            updateSourceAdvancedButton,
            identifier: "updateSource",
            expanded: false
        )
    }

    private func configureTimePickers() {
        [workingStartPicker, workingEndPicker].forEach { picker in
            picker.datePickerElements = [.hourMinute]
            picker.datePickerMode = .single
            picker.datePickerStyle = .textFieldAndStepper
            picker.widthAnchor.constraint(equalToConstant: 130).isActive = true
        }
    }

    private func configureMorningPauseSummary() {
        pauseUntilMorningSummaryLabel.identifier = NSUserInterfaceItemIdentifier("prefs.pauseUntilMorningSummaryLabel")
        pauseUntilMorningSummaryLabel.font = .systemFont(ofSize: 12)
        pauseUntilMorningSummaryLabel.textColor = .secondaryLabelColor
        pauseUntilMorningSummaryLabel.lineBreakMode = .byWordWrapping
        pauseUntilMorningSummaryLabel.maximumNumberOfLines = 2
        pauseUntilMorningSummaryLabel.widthAnchor.constraint(equalToConstant: 360).isActive = true
    }

    private func configureBodyDisplaySummary() {
        bodyDisplaySummaryLabel.identifier = NSUserInterfaceItemIdentifier("prefs.bodyDisplaySummaryLabel")
        bodyDisplaySummaryLabel.font = .systemFont(ofSize: 12)
        bodyDisplaySummaryLabel.textColor = .secondaryLabelColor
        bodyDisplaySummaryLabel.lineBreakMode = .byWordWrapping
        bodyDisplaySummaryLabel.maximumNumberOfLines = 3
        bodyDisplaySummaryLabel.widthAnchor.constraint(equalToConstant: 360).isActive = true
    }

    private func configureSoundVolumeControls() {
        soundVolumeSlider.identifier = NSUserInterfaceItemIdentifier("prefs.soundVolumeSlider")
        soundVolumeSlider.minValue = 0
        soundVolumeSlider.maxValue = 1
        soundVolumeSlider.numberOfTickMarks = 5
        soundVolumeSlider.allowsTickMarkValuesOnly = false
        soundVolumeSlider.widthAnchor.constraint(equalToConstant: 190).isActive = true
        soundVolumeValueLabel.identifier = NSUserInterfaceItemIdentifier("prefs.soundVolumeValue")
        soundVolumeValueLabel.textColor = .secondaryLabelColor
        soundVolumeValueLabel.alignment = .right
        soundVolumeValueLabel.widthAnchor.constraint(equalToConstant: 54).isActive = true
        soundPreviewStatusLabel.identifier = NSUserInterfaceItemIdentifier("soundPreviewStatus")
        soundPreviewStatusLabel.textColor = .secondaryLabelColor
        soundPreviewStatusLabel.font = .systemFont(ofSize: 12)
        soundPreviewStatusLabel.isHidden = true
        soundPreviewStatusLabel.widthAnchor.constraint(equalToConstant: 620).isActive = true
    }

    private func configureRhythmPresetButtons() {
        configureRhythmPresetButton(
            rhythmPresetRecommendedButton,
            preset: .recommended
        )
        configureRhythmPresetButton(
            rhythmPresetFrequentEyeButton,
            preset: .frequentEye
        )
        configureRhythmPresetButton(
            rhythmPresetMovementButton,
            preset: .movement
        )
    }

    private func configureRhythmPresetButton(
        _ button: NSButton,
        preset: RestRhythmPreset
    ) {
        button.identifier = NSUserInterfaceItemIdentifier("prefs.rhythmPreset.\(preset.identifier)")
        button.title = preset.title
        button.image = NSImage(systemSymbolName: preset.symbolName, accessibilityDescription: preset.title)
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.bezelStyle = .rounded
        button.setButtonType(.toggle)
        button.allowsMixedState = false
        button.toolTip = rhythmPresetButtonHelp(for: preset, isSelected: false)
        button.setAccessibilityLabel(preset.title)
        button.setAccessibilityHelp(button.toolTip)
        button.tag = preset.rawValue
        button.target = self
        button.action = #selector(rhythmPresetPressed(_:))
    }

    private func configureSaveStatusControls() {
        saveStatusIcon.identifier = NSUserInterfaceItemIdentifier("autosaveStatusIcon")
        saveStatusIcon.symbolConfiguration = .init(pointSize: 13, weight: .semibold)
        saveStatusIcon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        saveStatusIcon.heightAnchor.constraint(equalToConstant: 16).isActive = true
        saveStatusLabel.identifier = NSUserInterfaceItemIdentifier("autosaveStatusLabel")
        saveStatusLabel.textColor = .secondaryLabelColor
        saveStatusLabel.font = .systemFont(ofSize: 12)
        setSaveStatus(.ready)
    }

    private func configureSearchField() {
        searchField.identifier = NSUserInterfaceItemIdentifier("prefs.searchField")
        searchField.placeholderString = L10n.tr("prefs.searchPlaceholder")
        searchField.toolTip = L10n.tr("prefs.searchHelp")
        searchField.setAccessibilityLabel(L10n.tr("prefs.searchPlaceholder"))
        searchField.setAccessibilityHelp(L10n.tr("prefs.searchHelp"))
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(preferencesSearchChanged(_:))
        searchField.widthAnchor.constraint(equalToConstant: 190).isActive = true

        searchStatusLabel.identifier = NSUserInterfaceItemIdentifier("prefs.searchStatusLabel")
        searchStatusLabel.font = .systemFont(ofSize: 11)
        searchStatusLabel.textColor = .secondaryLabelColor
        searchStatusLabel.lineBreakMode = .byTruncatingTail
        searchStatusLabel.widthAnchor.constraint(equalToConstant: 190).isActive = true
        searchStatusLabel.isHidden = true
    }

    private func configureCustomBodyTextEditor() {
        configureTextEditor(
            customBodyTextEditor,
            in: customBodyTextScrollView,
            identifier: "customBodyTextEditor",
            font: .systemFont(ofSize: NSFont.systemFontSize),
            height: 96,
            help: L10n.tr("prefs.customBodyTextHelp")
        )
        configureTextEditor(
            appExclusionsJSONEditor,
            in: appExclusionsJSONScrollView,
            identifier: "appExclusionsJSONEditor",
            font: .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            height: 148,
            help: L10n.tr("prefs.advancedRulesGuidance")
        )
        configureTextEditor(
            customBodyIdeasJSONEditor,
            in: customBodyIdeasJSONScrollView,
            identifier: "customBodyIdeasJSONEditor",
            font: .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            height: 148,
            help: L10n.tr("prefs.advancedIdeasGuidance")
        )
    }

    private func configureAdvancedBulkEditorActions() {
        configureBulkEditorActionButton(
            appExclusionsCopyBulkButton,
            identifier: "prefs.appExclusionsCopyBulkButton",
            title: L10n.tr("prefs.copyAppRulesBulkEditor"),
            symbolName: "doc.on.doc",
            help: L10n.tr("prefs.copyAppRulesBulkEditorHelp"),
            action: #selector(copyAppRulesBulkEditorPressed(_:))
        )
        configureBulkEditorActionButton(
            appExclusionsRestoreBulkButton,
            identifier: "prefs.appExclusionsRestoreBulkButton",
            title: L10n.tr("prefs.restoreAppRulesBulkEditor"),
            symbolName: "arrow.counterclockwise",
            help: L10n.tr("prefs.restoreAppRulesBulkEditorHelp"),
            action: #selector(restoreAppRulesBulkEditorPressed(_:))
        )
        configureBulkEditorActionButton(
            customBodyIdeasCopyBulkButton,
            identifier: "prefs.customBodyIdeasCopyBulkButton",
            title: L10n.tr("prefs.copyIdeasBulkEditor"),
            symbolName: "doc.on.doc",
            help: L10n.tr("prefs.copyIdeasBulkEditorHelp"),
            action: #selector(copyIdeasBulkEditorPressed(_:))
        )
        configureBulkEditorActionButton(
            customBodyIdeasRestoreBulkButton,
            identifier: "prefs.customBodyIdeasRestoreBulkButton",
            title: L10n.tr("prefs.restoreIdeasBulkEditor"),
            symbolName: "arrow.counterclockwise",
            help: L10n.tr("prefs.restoreIdeasBulkEditorHelp"),
            action: #selector(restoreIdeasBulkEditorPressed(_:))
        )
    }

    private func configureBulkEditorActionButton(
        _ button: NSButton,
        identifier: String,
        title: String,
        symbolName: String,
        help: String,
        action: Selector
    ) {
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
        button.title = title
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
        setTextButtonHelp(title: title, help: help, on: button)
    }

    private func configureTextEditor(
        _ editor: NSTextView,
        in scrollView: NSScrollView,
        identifier: String,
        font: NSFont,
        height: CGFloat,
        help: String? = nil
    ) {
        editor.identifier = NSUserInterfaceItemIdentifier(identifier)
        editor.isRichText = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isContinuousSpellCheckingEnabled = false
        editor.isGrammarCheckingEnabled = false
        editor.isAutomaticLinkDetectionEnabled = false
        editor.isAutomaticDataDetectionEnabled = false
        editor.allowsUndo = true
        editor.font = font
        editor.textContainerInset = NSSize(width: 8, height: 6)
        editor.isHorizontallyResizable = false
        editor.isVerticallyResizable = true
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: 360, height: CGFloat.greatestFiniteMagnitude)
        editor.toolTip = help
        editor.setAccessibilityHelp(help)

        scrollView.identifier = NSUserInterfaceItemIdentifier("\(identifier)ScrollView")
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.documentView = editor
        scrollView.toolTip = help
        scrollView.setAccessibilityHelp(help)
        scrollView.widthAnchor.constraint(equalToConstant: 360).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    private func configureBodyContentSummary() {
        bodyContentSummaryLabel.identifier = NSUserInterfaceItemIdentifier("prefs.bodyContentSummaryLabel")
        bodyContentSummaryLabel.font = .systemFont(ofSize: 12)
        bodyContentSummaryLabel.textColor = .secondaryLabelColor
        bodyContentSummaryLabel.lineBreakMode = .byWordWrapping
        bodyContentSummaryLabel.maximumNumberOfLines = 3
        bodyContentSummaryLabel.widthAnchor.constraint(equalToConstant: 360).isActive = true
    }

    private func configureAppExclusionTokenField() {
        appExclusionTerms.tokenStyle = .rounded
        appExclusionTerms.tokenizingCharacterSet = CharacterSet(charactersIn: ",\n")
        appExclusionTerms.placeholderString = L10n.tr("prefs.matchTermsPlaceholder")
    }

    private func configureAppExclusionPreview() {
        appExclusionPreviewLabel.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionPreviewLabel")
        appExclusionPreviewLabel.font = .systemFont(ofSize: 12)
        appExclusionPreviewLabel.textColor = .secondaryLabelColor
        appExclusionPreviewLabel.lineBreakMode = .byWordWrapping
        appExclusionPreviewLabel.maximumNumberOfLines = 3
        appExclusionPreviewLabel.widthAnchor.constraint(equalToConstant: 360).isActive = true
    }

    private func configureAppExclusionRunningAppButton() {
        appExclusionAddRunningApp.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionAddRunningApp")
        appExclusionAddRunningApp.title = L10n.tr("prefs.addRunningApp")
        appExclusionAddRunningApp.image = NSImage(systemSymbolName: "plus.app", accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "plus.circle", accessibilityDescription: nil)
        appExclusionAddRunningApp.imagePosition = .imageLeading
        appExclusionAddRunningApp.bezelStyle = .rounded
        appExclusionAddRunningApp.target = self
        appExclusionAddRunningApp.action = #selector(addRunningAppExclusionPressed(_:))
        setTextButtonHelp(
            title: appExclusionAddRunningApp.title,
            help: L10n.tr("prefs.addRunningAppHelp"),
            on: appExclusionAddRunningApp
        )
        appExclusionAddRunningApp.widthAnchor.constraint(equalToConstant: 168).isActive = true
    }

    private func configureAppExclusionAddRuleButton() {
        appExclusionAddRuleButton.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionAddRuleButton")
        appExclusionAddRuleButton.imagePosition = .imageLeading
        appExclusionAddRuleButton.bezelStyle = .rounded
        appExclusionAddRuleButton.target = self
        appExclusionAddRuleButton.action = #selector(addAppExclusionRulePressed(_:))
        appExclusionAddRuleButton.widthAnchor.constraint(equalToConstant: 156).isActive = true

        appExclusionCancelEditButton.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionCancelEditButton")
        appExclusionCancelEditButton.title = L10n.tr("prefs.cancelAppExclusionRuleEdit")
        appExclusionCancelEditButton.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)
        appExclusionCancelEditButton.imagePosition = .imageLeading
        appExclusionCancelEditButton.bezelStyle = .rounded
        appExclusionCancelEditButton.target = self
        appExclusionCancelEditButton.action = #selector(cancelAppExclusionRuleEditPressed(_:))
        appExclusionCancelEditButton.toolTip = L10n.tr("prefs.cancelAppExclusionRuleEditHelp")
        setTextButtonHelp(
            title: appExclusionCancelEditButton.title,
            help: L10n.tr("prefs.cancelAppExclusionRuleEditHelp"),
            on: appExclusionCancelEditButton
        )
        appExclusionCancelEditButton.widthAnchor.constraint(equalToConstant: 126).isActive = true
        appExclusionCancelEditButton.isHidden = true
        updateAppExclusionActionButtonPresentation()
    }

    private func configureAppExclusionRulesList() {
        appExclusionRulesListStack.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionRulesList")
        appExclusionRulesListStack.orientation = .vertical
        appExclusionRulesListStack.spacing = 6
        appExclusionRulesListStack.alignment = .leading
        appExclusionRulesListStack.widthAnchor.constraint(equalToConstant: 360).isActive = true
    }

    private func appExclusionRuleActionRow() -> NSStackView {
        let stack = NSStackView(views: [appExclusionAddRuleButton, appExclusionCancelEditButton])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        return stack
    }

    private func configureCustomBodyAddIdeaButton() {
        customBodyAddIdeaButton.identifier = NSUserInterfaceItemIdentifier("prefs.customBodyAddIdeaButton")
        customBodyAddIdeaButton.imagePosition = .imageLeading
        customBodyAddIdeaButton.bezelStyle = .rounded
        customBodyAddIdeaButton.target = self
        customBodyAddIdeaButton.action = #selector(addCustomBodyIdeaPressed(_:))
        customBodyAddIdeaButton.widthAnchor.constraint(equalToConstant: 164).isActive = true

        customBodyCancelEditButton.identifier = NSUserInterfaceItemIdentifier("prefs.customBodyCancelEditButton")
        customBodyCancelEditButton.title = L10n.tr("prefs.cancelCustomIdeaEdit")
        customBodyCancelEditButton.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)
        customBodyCancelEditButton.imagePosition = .imageLeading
        customBodyCancelEditButton.bezelStyle = .rounded
        customBodyCancelEditButton.target = self
        customBodyCancelEditButton.action = #selector(cancelCustomBodyIdeaEditPressed(_:))
        customBodyCancelEditButton.toolTip = L10n.tr("prefs.cancelCustomIdeaEditHelp")
        setTextButtonHelp(
            title: customBodyCancelEditButton.title,
            help: L10n.tr("prefs.cancelCustomIdeaEditHelp"),
            on: customBodyCancelEditButton
        )
        customBodyCancelEditButton.widthAnchor.constraint(equalToConstant: 126).isActive = true
        customBodyCancelEditButton.isHidden = true
        updateCustomBodyActionButtonPresentation()
    }

    private func configureCustomBodyIdeasList() {
        customBodyIdeasListStack.identifier = NSUserInterfaceItemIdentifier("prefs.customBodyIdeasList")
        customBodyIdeasListStack.orientation = .vertical
        customBodyIdeasListStack.spacing = 6
        customBodyIdeasListStack.alignment = .leading
        customBodyIdeasListStack.widthAnchor.constraint(equalToConstant: 360).isActive = true
    }

    private func customBodyIdeaActionRow() -> NSStackView {
        let stack = NSStackView(views: [customBodyAddIdeaButton, customBodyCancelEditButton])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        return stack
    }

    private func configureDisclosureButton(_ button: NSButton, identifier: String, expanded: Bool) {
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
        button.target = self
        button.action = #selector(toggleAdvancedDisclosure(_:))
        button.bezelStyle = .inline
        button.isBordered = false
        button.imagePosition = .imageLeading
        button.contentTintColor = .secondaryLabelColor
        updateDisclosureButton(button, expanded: expanded)
    }

    private func updateDisclosureButton(_ button: NSButton, expanded: Bool) {
        let title: String
        let help: String
        switch button.identifier?.rawValue {
        case "customIdeas":
            title = expanded ? L10n.tr("prefs.hideAdvancedIdeas") : L10n.tr("prefs.showAdvancedIdeas")
            help = L10n.tr("prefs.advancedIdeasHelp")
        case "adminControls":
            title = expanded ? L10n.tr("prefs.hideAdminControls") : L10n.tr("prefs.showAdminControls")
            help = L10n.tr("prefs.adminControlsHelp")
        case "updateSource":
            title = expanded ? L10n.tr("prefs.hideUpdateSource") : L10n.tr("prefs.showUpdateSource")
            help = L10n.tr("prefs.updateSourceDisclosureHelp")
        default:
            title = expanded ? L10n.tr("prefs.hideAdvancedRules") : L10n.tr("prefs.showAdvancedRules")
            help = L10n.tr("prefs.advancedRulesHelp")
        }
        button.title = title
        button.toolTip = help
        button.setAccessibilityLabel(title)
        button.setAccessibilityHelp(help)
        button.image = NSImage(
            systemSymbolName: expanded ? "chevron.down" : "chevron.right",
            accessibilityDescription: title
        )
    }

    private func configureImagePickerControls() {
        localImagePath.identifier = NSUserInterfaceItemIdentifier("localImagePathField")
        localImagePath.isEditable = false
        localImagePath.isSelectable = true
        localImagePath.cell?.lineBreakMode = .byTruncatingMiddle
        localImagePath.placeholderString = L10n.tr("prefs.noImageSelected")

        localImageChooseButton.title = L10n.tr("prefs.chooseFile")
        localImageChooseButton.image = NSImage(
            systemSymbolName: "photo",
            accessibilityDescription: localImageChooseButton.title
        )
        localImageChooseButton.imagePosition = .imageLeading
        localImageChooseButton.target = self
        localImageChooseButton.action = #selector(chooseLocalImagePressed)
        setTextButtonHelp(
            title: localImageChooseButton.title,
            help: L10n.tr("prefs.chooseBodyImageHelp"),
            on: localImageChooseButton
        )

        localImageClearButton.title = L10n.tr("prefs.clear")
        localImageClearButton.image = NSImage(
            systemSymbolName: "xmark.circle",
            accessibilityDescription: localImageClearButton.title
        )
        localImageClearButton.imagePosition = .imageLeading
        localImageClearButton.target = self
        localImageClearButton.action = #selector(clearLocalImagePressed)
        setTextButtonHelp(
            title: localImageClearButton.title,
            help: L10n.tr("prefs.clearBodyImageHelp"),
            on: localImageClearButton
        )

        localImagePreview.identifier = NSUserInterfaceItemIdentifier("localImagePreview")
        localImagePreview.translatesAutoresizingMaskIntoConstraints = false
        localImagePreview.imageScaling = .scaleProportionallyUpOrDown
        localImagePreview.wantsLayer = true
        localImagePreview.layer?.cornerRadius = 6
        localImagePreview.layer?.borderWidth = 1
        localImagePreview.layer?.borderColor = NSColor.separatorColor.cgColor
        localImagePreview.layer?.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.45).cgColor
        localImagePreview.setAccessibilityLabel(L10n.tr("prefs.localImagePath"))
        updateLocalImagePreviewDropHelp(bodyBreakEnabled: true)
        localImagePreview.onImageURLDropped = { [weak self] url in
            self?.applyLocalImageURL(url)
        }
        localImagePreview.widthAnchor.constraint(equalToConstant: 92).isActive = true
        localImagePreview.heightAnchor.constraint(equalToConstant: 62).isActive = true

        localImagePreviewLabel.identifier = NSUserInterfaceItemIdentifier("localImagePreviewLabel")
        localImagePreviewLabel.textColor = .secondaryLabelColor
        localImagePreviewLabel.lineBreakMode = .byTruncatingMiddle
        localImagePreviewLabel.widthAnchor.constraint(equalToConstant: 260).isActive = true
    }

    private func configureEnablementGuards() {
        eyeEnabled.target = self
        eyeEnabled.action = #selector(restEnablementChanged(_:))
        bodyEnabled.target = self
        bodyEnabled.action = #selector(restEnablementChanged(_:))
    }

    private func configurePreferenceHelp() {
        setHelp(L10n.tr("prefs.eyeEmergencyOverrideHelp"), on: eyeEmergencyOverride)
        setHelp(L10n.tr("prefs.eyeManualFinishHelp"), on: eyeManualFinish)
        setHelp(L10n.tr("prefs.bodyAllowSkipHelp"), on: bodyAllowSkip)
        setHelp(L10n.tr("prefs.bodyManualFinishHelp"), on: bodyManualFinish)
        setHelp(L10n.tr("prefs.naturalBreaksHelp"), on: naturalBreaks)
        setHelp(L10n.tr("prefs.naturalIdleMinutesHelp"), on: naturalIdleMinutes)
        setHelp(L10n.tr("prefs.focusMonitorHelp"), on: focusMonitor)
        setHelp(L10n.tr("prefs.focusDefersBodyHelp"), on: focusDefersBody)
        setHelp(L10n.tr("prefs.workingHoursHelp"), on: workingHoursEnabled)
        setHelp(L10n.tr("prefs.workingStartHelp"), on: workingStartPicker)
        setHelp(L10n.tr("prefs.workingEndHelp"), on: workingEndPicker)
        setHelp(L10n.tr("prefs.enablePrimaryExclusionHelp"), on: appExclusionEnabled)
        setHelp(L10n.tr("prefs.appExclusionNameHelp"), on: appExclusionName)
        setHelp(L10n.tr("prefs.appExclusionTermsHelp"), on: appExclusionTerms)
        setHelp(L10n.tr("prefs.appExclusionModeHelp"), on: appExclusionMode)
        setHelp(L10n.tr("prefs.openAtLoginHelp"), on: openAtLogin)
        setHelp(L10n.tr("prefs.checkUpdatesHelp"), on: checkUpdates)
        setHelp(L10n.tr("prefs.notifyNewVersionHelp"), on: notifyNewVersion)
        setHelp(L10n.tr("prefs.showOnboardingNextLaunchHelp"), on: showOnboardingNextLaunch)
        setHelp(L10n.tr("prefs.pauseUntilMorningModeHelp"), on: pauseUntilMorningMode)
        setHelp(L10n.tr("prefs.pauseUntilMorningLocationHelp"), on: pauseUntilMorningLocation)
        setHelp(L10n.tr("prefs.pauseForSuspendOrLockHelp"), on: pauseForSuspendOrLock)
        setHelp(L10n.tr("prefs.updateFeedURLHelp"), on: updateFeedURL)
        setHelp(L10n.tr("prefs.adminHideUpdatesHelp"), on: disableUpdateFeatures)
        setHelp(L10n.tr("prefs.adminHideSettingsPathHelp"), on: hideSettingsPath)
        setHelp(L10n.tr("prefs.adminHideStrictHelp"), on: hideStrictPreferences)
        setHelp(L10n.tr("prefs.preferencesMessageHelp"), on: customPreferencesMessage)
    }

    private func configureSchedulePreferenceHelp() {
        setHelp(L10n.tr("prefs.enableEyeGateHelp"), on: eyeEnabled)
        setNumberInputHelp(L10n.tr("prefs.eyeIntervalHelp"), on: eyeInterval)
        setNumberInputHelp(L10n.tr("prefs.eyeDurationHelp"), on: eyeDuration)
        setHelp(L10n.tr("prefs.overlayColorHelp"), on: eyeColor)
        setHelp(L10n.tr("prefs.notifyEyeGateHelp"), on: eyeNotify)
        setNumberInputHelp(L10n.tr("prefs.notificationLeadHelp"), on: eyeLead)
        setHelp(L10n.tr("prefs.eyeManualFinishHelp"), on: eyeManualFinish)
        setHelp(L10n.tr("prefs.eyeEmergencyOverrideHelp"), on: eyeEmergencyOverride)

        setHelp(L10n.tr("prefs.enableBodyBreakHelp"), on: bodyEnabled)
        setNumberInputHelp(L10n.tr("prefs.bodyIntervalHelp"), on: bodyInterval)
        setNumberInputHelp(L10n.tr("prefs.bodyDurationHelp"), on: bodyDuration)
        setNumberInputHelp(L10n.tr("prefs.bodyAfterEyeGatesHelp"), on: bodyAfterEyeGates)
        setHelp(L10n.tr("prefs.overlayColorHelp"), on: bodyColor)
        setHelp(L10n.tr("prefs.notifyBodyBreakHelp"), on: bodyNotify)
        setNumberInputHelp(L10n.tr("prefs.notificationLeadHelp"), on: bodyLead)
        setNumberInputHelp(L10n.tr("prefs.bodyPostponeMinutesHelp"), on: bodyPostponeMinutes)
        setNumberInputHelp(L10n.tr("prefs.bodyPostponeLimitHelp"), on: bodyPostponeLimit)
        setNumberInputHelp(L10n.tr("prefs.bodyPostponeWindowPercentHelp"), on: bodyPostponeWindowPercent)
        setHelp(L10n.tr("prefs.bodyAllowSkipHelp"), on: bodyAllowSkip)
        setHelp(L10n.tr("prefs.bodyManualFinishHelp"), on: bodyManualFinish)
        setHelp(L10n.tr("prefs.bodyAllDisplaysHelp"), on: bodyCoversAllDisplays)
        setHelp(L10n.tr("prefs.bodyCoveredDisplayHelp"), on: bodyCoveredDisplay)
        setHelp(L10n.tr("prefs.bodyContentDisplayHelp"), on: bodyContentDisplay)
        setHelp(L10n.tr("prefs.bodyBlankSecondaryHelp"), on: bodyBlankSecondaryDisplays)
        setHelp(L10n.tr("prefs.configuredDisplayIndexHelp"), on: bodyConfiguredDisplay)
    }

    private func configureAppearancePreferenceHelp() {
        setHelp(L10n.tr("prefs.themeHelp"), on: themeSource)
        setHelp(L10n.tr("prefs.languageHelp"), on: languageIdentifier)
        setHelp(L10n.tr("prefs.currentTimeBodyHelp"), on: currentTimeInBodyBreak)
        setHelp(L10n.tr("prefs.breakHealthHelp"), on: breakHealth)
        setHelp(L10n.tr("prefs.silentNotificationsHelp"), on: silentNotifications)
        setHelp(L10n.tr("prefs.eyeStartSoundHelp"), on: eyeStartSound)
        setHelp(L10n.tr("prefs.eyeFinishSoundHelp"), on: eyeFinishSound)
        setHelp(L10n.tr("prefs.bodyStartSoundHelp"), on: bodyStartSound)
        setHelp(L10n.tr("prefs.bodyFinishSoundHelp"), on: bodyFinishSound)
        setHelp(L10n.tr("prefs.soundVolumeHelp"), on: soundVolumeSlider)
        setHelp(L10n.tr("prefs.soundVolumeHelp"), on: soundVolumeValueLabel)
        setHelp(L10n.tr("prefs.useBuiltInIdeasHelp"), on: useBuiltInIdeas)
        setHelp(L10n.tr("prefs.customBodyTitleHelp"), on: customBodyTitle)
    }

    private func setNumberInputHelp(_ help: String, on field: NSTextField) {
        setHelp(help, on: field)
        guard let input = numberInputs.first(where: { $0.field === field }) else { return }
        setHelp(help, on: input.stepper)
        if let slider = input.slider {
            setHelp(help, on: slider)
        }
    }

    private func setHelp(_ help: String, on control: NSControl) {
        control.toolTip = help
        control.setAccessibilityHelp(help)
    }

    private func setOptionalHelp(_ help: String?, on control: NSControl) {
        control.toolTip = help
        control.setAccessibilityHelp(help)
    }

    private func setIconOnlyActionHelp(_ help: String, on button: NSButton) {
        setIconOnlyActionHelp(label: help, help: help, on: button)
    }

    private func setIconOnlyActionHelp(label: String, help: String, on button: NSButton) {
        setHelp(help, on: button)
        button.setAccessibilityLabel(label)
        button.image?.accessibilityDescription = label
    }

    private func setTextButtonHelp(title: String, help: String, on button: NSButton) {
        setHelp(help, on: button)
        button.setAccessibilityLabel(title)
        button.image?.accessibilityDescription = title
    }

    private func configureAutosave() {
        let textFields = [
            eyeInterval, eyeDuration, eyeLead, bodyInterval, bodyDuration, bodyAfterEyeGates,
            bodyLead, bodyPostponeMinutes, bodyPostponeLimit, bodyPostponeWindowPercent, naturalIdleMinutes,
            appExclusionName, appExclusionTerms,
            customBodyTitle, localImagePath,
            pauseUntilMorningHour, pauseUntilMorningLatitude, pauseUntilMorningLongitude, updateFeedURL,
            customPreferencesMessage
        ]
        textFields.forEach { field in
            field.delegate = self
            field.target = self
            field.action = #selector(controlChanged(_:))
        }
        [customBodyTextEditor, appExclusionsJSONEditor, customBodyIdeasJSONEditor].forEach { editor in
            editor.delegate = self
        }

        let controls: [NSControl] = [
            eyeColor, bodyColor, eyeNotify, eyeManualFinish, eyeEmergencyOverride, bodyNotify, bodyAllowSkip, bodyManualFinish, bodyCoversAllDisplays,
            bodyBlankSecondaryDisplays, naturalBreaks, focusMonitor, focusDefersBody, workingHoursEnabled,
            appExclusionEnabled, appExclusionMode, appExclusionAppliesEye, appExclusionAppliesBody, themeSource,
            languageIdentifier, currentTimeInBodyBreak, breakHealth, silentNotifications,
            eyeStartSound, eyeFinishSound, bodyStartSound, bodyFinishSound, useBuiltInIdeas, openAtLogin,
            checkUpdates, notifyNewVersion, showOnboardingNextLaunch, pauseUntilMorningMode,
            pauseUntilMorningLocation, pauseForSuspendOrLock,
            disableUpdateFeatures, hideSettingsPath, hideStrictPreferences, bodyCoveredDisplay, bodyContentDisplay,
            bodyConfiguredDisplay, workingStartPicker, workingEndPicker, soundVolumeSlider
        ]
        controls.forEach { control in
            control.target = self
            control.action = #selector(controlChanged(_:))
        }

        [
            shortcutPauseToggle, shortcutPause30, shortcutPause1h, shortcutPause2h, shortcutPause5h,
            shortcutPauseUntilMorning, shortcutNextScheduled, shortcutEyeNow, shortcutBodyNow,
            shortcutEndBody, shortcutEmergencyEye, shortcutReset
        ].forEach { recorder in
            recorder.onChange = { [weak self] in
                self?.updateShortcutConflictWarning()
                self?.updateShortcutClearButtons()
                self?.scheduleAutosave()
            }
        }
    }

    private func configureShortcutConflictWarning() {
        shortcutConflictIcon.image = NSImage(
            systemSymbolName: "exclamationmark.triangle.fill",
            accessibilityDescription: L10n.tr("prefs.shortcutConflictTitle")
        )
        shortcutConflictIcon.identifier = NSUserInterfaceItemIdentifier("prefs.shortcutConflictIcon")
        shortcutConflictIcon.setAccessibilityLabel(L10n.tr("prefs.shortcutConflictTitle"))
        shortcutConflictIcon.contentTintColor = .systemOrange
        shortcutConflictIcon.symbolConfiguration = .init(pointSize: 14, weight: .semibold)
        shortcutConflictIcon.widthAnchor.constraint(equalToConstant: 18).isActive = true

        shortcutConflictLabel.identifier = NSUserInterfaceItemIdentifier("prefs.shortcutConflictLabel")
        shortcutConflictLabel.textColor = .systemOrange
        shortcutConflictLabel.lineBreakMode = .byWordWrapping
        shortcutConflictLabel.maximumNumberOfLines = 3
        shortcutConflictLabel.widthAnchor.constraint(equalToConstant: 510).isActive = true

        shortcutConflictReviewButton.identifier = NSUserInterfaceItemIdentifier("prefs.shortcutConflictReviewButton")
        shortcutConflictReviewButton.title = L10n.tr("prefs.shortcutConflictReview")
        shortcutConflictReviewButton.image = NSImage(
            systemSymbolName: "arrow.turn.down.right",
            accessibilityDescription: shortcutConflictReviewButton.title
        )
        shortcutConflictReviewButton.imagePosition = .imageLeading
        shortcutConflictReviewButton.bezelStyle = .rounded
        shortcutConflictReviewButton.target = self
        shortcutConflictReviewButton.action = #selector(reviewShortcutConflictPressed(_:))
        setTextButtonHelp(
            title: shortcutConflictReviewButton.title,
            help: L10n.tr("prefs.shortcutConflictReviewHelp"),
            on: shortcutConflictReviewButton
        )

        shortcutConflictRow.identifier = NSUserInterfaceItemIdentifier("prefs.shortcutConflictRow")
        shortcutConflictRow.orientation = .horizontal
        shortcutConflictRow.alignment = .top
        shortcutConflictRow.spacing = 8
        shortcutConflictRow.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        shortcutConflictRow.wantsLayer = true
        shortcutConflictRow.layer?.cornerRadius = 7
        shortcutConflictRow.layer?.borderWidth = 1
        shortcutConflictRow.layer?.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.08).cgColor
        shortcutConflictRow.layer?.borderColor = NSColor.systemOrange.withAlphaComponent(0.28).cgColor
        shortcutConflictRow.widthAnchor.constraint(equalToConstant: 650).isActive = true
        shortcutConflictRow.addArrangedSubview(shortcutConflictIcon)
        shortcutConflictRow.addArrangedSubview(shortcutConflictLabel)
        shortcutConflictRow.addArrangedSubview(shortcutConflictReviewButton)
        shortcutConflictRow.isHidden = true
    }

    private func configureShortcutRecorders() {
        shortcutEmergencyEye.requiredFallbackShortcutValue = ShortcutSettings.defaultEmergencyEyeGateOverride
    }

    private func configureSoundPopup(_ popup: NSPopUpButton) {
        for option in SoundOption.builtIn {
            popup.addItem(withTitle: option.title)
            popup.lastItem?.representedObject = option.name
        }
    }

    private func configureSoundPreviewButtons() {
        configureSoundPreviewButton(
            eyeStartSoundPreview,
            identifier: "eyeStart",
            soundLabel: L10n.tr("prefs.eyeStartSound")
        )
        configureSoundPreviewButton(
            eyeFinishSoundPreview,
            identifier: "eyeFinish",
            soundLabel: L10n.tr("prefs.eyeFinishSound")
        )
        configureSoundPreviewButton(
            bodyStartSoundPreview,
            identifier: "bodyStart",
            soundLabel: L10n.tr("prefs.bodyStartSound")
        )
        configureSoundPreviewButton(
            bodyFinishSoundPreview,
            identifier: "bodyFinish",
            soundLabel: L10n.tr("prefs.bodyFinishSound")
        )
    }

    private func configureSoundPreviewButton(_ button: NSButton, identifier: String, soundLabel: String) {
        let accessibilityLabel = L10n.format("prefs.previewSoundLabel", soundLabel)
        button.title = L10n.tr("prefs.previewSound")
        button.image = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: accessibilityLabel)
        button.imagePosition = .imageLeading
        button.target = self
        button.action = #selector(previewSound(_:))
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
        updateSoundPreviewButton(button, soundLabel: soundLabel, mutedBySilentNotifications: false)
    }

    private func configureUpdateSourceRestoreButton() {
        restoreUpdateSourceButton.identifier = NSUserInterfaceItemIdentifier("prefs.restoreUpdateSourceButton")
        restoreUpdateSourceButton.title = ""
        restoreUpdateSourceButton.bezelStyle = .inline
        restoreUpdateSourceButton.isBordered = false
        restoreUpdateSourceButton.image = NSImage(systemSymbolName: "arrow.counterclockwise", accessibilityDescription: nil)
        restoreUpdateSourceButton.imagePosition = .imageOnly
        restoreUpdateSourceButton.contentTintColor = .secondaryLabelColor
        restoreUpdateSourceButton.target = self
        restoreUpdateSourceButton.action = #selector(restoreUpdateSourcePressed(_:))
        restoreUpdateSourceButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
        restoreUpdateSourceButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
        updateUpdateSourceRestoreButtonState()
    }

    private func loadSettings() {
        isLoadingSettings = true
        defer {
            isLoadingSettings = false
            setSaveStatus(.ready)
        }

        updateAdminMessageLabel(settings.admin.customPreferencesMessage)

        eyeEnabled.state = state(settings.eyeGate.isEnabled)
        eyeInterval.stringValue = String(Int(settings.eyeGate.interval / 60))
        eyeDuration.stringValue = String(Int(settings.eyeGate.duration))
        eyeColor.color = NSColor(hex: settings.eyeGate.colorHex)
        eyeNotify.state = state(settings.notifications.eyeGateEnabled)
        eyeLead.stringValue = String(Int(settings.notifications.eyeGateLeadTime))
        eyeManualFinish.state = state(settings.eyeGate.manualFinishEnabled)
        eyeEmergencyOverride.state = state(settings.eyeGate.emergencyOverride.isEnabled)

        bodyEnabled.state = state(settings.bodyBreak.isEnabled)
        bodyInterval.stringValue = String(Int(settings.bodyBreak.interval / 60))
        bodyDuration.stringValue = String(Int(settings.bodyBreak.duration / 60))
        bodyAfterEyeGates.stringValue = String(settings.bodyBreakAfterEyeGates)
        bodyColor.color = NSColor(hex: settings.bodyBreak.colorHex)
        bodyNotify.state = state(settings.notifications.bodyBreakEnabled)
        bodyLead.stringValue = String(Int(settings.notifications.bodyBreakLeadTime))
        bodyPostponeMinutes.stringValue = String(Int(settings.bodyBreak.postpone.duration / 60))
        bodyPostponeLimit.stringValue = String(settings.bodyBreak.postpone.maxCount)
        bodyPostponeWindowPercent.stringValue = String(Int(settings.bodyBreak.postpone.allowedDuringFirstPercent))
        bodyAllowSkip.state = state(settings.bodyBreak.ordinarySkipEnabled)
        bodyManualFinish.state = state(settings.bodyBreak.manualFinishEnabled)
        bodyCoversAllDisplays.state = state(settings.bodyBreak.enforcement.coversAllDisplays)
        selectPopup(bodyCoveredDisplay, rawValue: (settings.bodyBreak.enforcement.coveredDisplay ?? .primary).rawValue)
        selectPopup(bodyContentDisplay, rawValue: settings.bodyBreak.enforcement.contentDisplay.rawValue)
        bodyBlankSecondaryDisplays.state = state(settings.bodyBreak.enforcement.blankSecondaryDisplays)
        configureConfiguredDisplayPopup(selectedIndex: settings.bodyBreak.enforcement.configuredDisplayIndex ?? 0)

        naturalBreaks.state = state(settings.naturalBreaks.isEnabled)
        naturalIdleMinutes.stringValue = String(Int(settings.naturalBreaks.inactivityResetTime / 60))
        focusMonitor.state = state(settings.focusMode.monitorFocusMode)
        focusDefersBody.state = state(settings.focusMode.deferBodyBreak)
        workingHoursEnabled.state = state(settings.workingHours.isEnabled)
        workingStart.stringValue = Self.timeString(minutes: settings.workingHours.startMinuteOfDay)
        workingEnd.stringValue = Self.timeString(minutes: settings.workingHours.endMinuteOfDay)
        workingStartPicker.dateValue = Self.dateForTimePicker(minutes: settings.workingHours.startMinuteOfDay)
        workingEndPicker.dateValue = Self.dateForTimePicker(minutes: settings.workingHours.endMinuteOfDay)

        let appExclusionsEnabled = settings.appExclusions.first?.isEnabled ?? false
        appExclusionEnabled.state = state(appExclusionsEnabled)
        clearAppExclusionRuleEditState()
        appExclusionName.stringValue = ""
        appExclusionTerms.objectValue = []
        selectPopup(appExclusionMode, rawValue: AppExclusionRule.Mode.pauseWhenMatched.rawValue)
        setDefaultAppExclusionTargets()
        appExclusionsJSONEditor.string = appExclusionsEnabled ? encodedAppExclusionsForEditor(settings.appExclusions) : ""
        setAdvancedDisclosure(
            row: appExclusionsJSONRow,
            button: appExclusionsAdvancedButton,
            expanded: false
        )

        selectPopup(themeSource, rawValue: settings.presentation.themeSource.rawValue)
        selectLanguageOption(LanguageOption(identifier: settings.presentation.languageIdentifier))
        currentTimeInBodyBreak.state = state(settings.presentation.showCurrentTimeDuringBodyBreak)
        breakHealth.state = state(settings.presentation.breakHealthMode)
        silentNotifications.state = state(settings.notifications.silentNotifications)
        selectSoundOption(SoundOption(name: soundName(settings.eyeGate.startSound)), in: eyeStartSound)
        selectSoundOption(SoundOption(name: soundName(settings.eyeGate.finishSound)), in: eyeFinishSound)
        selectSoundOption(SoundOption(name: soundName(settings.bodyBreak.startSound)), in: bodyStartSound)
        selectSoundOption(SoundOption(name: soundName(settings.bodyBreak.finishSound)), in: bodyFinishSound)
        let volume = preferredSoundVolume()
        soundVolume.stringValue = String(volume)
        soundVolumeSlider.doubleValue = volume
        updateSoundVolumeLabel()

        let customIdeas = settings.contentLibrary.customBodyBreakIdeas
        useBuiltInIdeas.state = state(settings.contentLibrary.useBuiltInIdeas)
        clearCustomBodyIdeaEditState()
        customBodyTitle.stringValue = ""
        customBodyTextEditor.string = ""
        customBodyIdeasJSONEditor.string = customIdeas.isEmpty ? "" : encodedCustomIdeasForEditor(customIdeas)
        setAdvancedDisclosure(
            row: customBodyIdeasJSONRow,
            button: customBodyIdeasAdvancedButton,
            expanded: false
        )
        localImagePath.stringValue = settings.contentLibrary.localImagePaths.first ?? ""
        updateLocalImagePreview()
        updateCustomBodyAddIdeaButtonState()
        refreshCustomBodyIdeaList()

        shortcutPauseToggle.shortcutValue = settings.shortcuts.pauseToggle
        shortcutPause30.shortcutValue = settings.shortcuts.pauseFor30Minutes
        shortcutPause1h.shortcutValue = settings.shortcuts.pauseFor1Hour
        shortcutPause2h.shortcutValue = settings.shortcuts.pauseFor2Hours
        shortcutPause5h.shortcutValue = settings.shortcuts.pauseFor5Hours
        shortcutPauseUntilMorning.shortcutValue = settings.shortcuts.pauseUntilMorning
        shortcutNextScheduled.shortcutValue = settings.shortcuts.skipToNextScheduledRest ?? ""
        shortcutEyeNow.shortcutValue = settings.shortcuts.takeEyeGateNow
        shortcutBodyNow.shortcutValue = settings.shortcuts.resolvedTakeBodyBreakNowShortcut
        shortcutEndBody.shortcutValue = settings.shortcuts.resolvedEndBodyBreakShortcut
        shortcutEmergencyEye.shortcutValue = settings.shortcuts.resolvedEmergencyEyeGateOverride
        shortcutReset.shortcutValue = settings.shortcuts.reset

        openAtLogin.state = state(settings.operations.openAtLogin)
        checkUpdates.state = state(settings.operations.checkForUpdates)
        notifyNewVersion.state = state(settings.operations.notifyNewVersion)
        showOnboardingNextLaunch.state = state(settings.operations.resolvedShowOnboardingOnNextLaunch)
        selectPopup(pauseUntilMorningMode, rawValue: settings.operations.resolvedPauseUntilMorningMode.rawValue)
        pauseUntilMorningHour.stringValue = String(settings.operations.resolvedPauseUntilMorningHour)
        pauseUntilMorningLatitude.stringValue = String(settings.operations.pauseUntilMorningLatitude ?? 0)
        pauseUntilMorningLongitude.stringValue = String(settings.operations.pauseUntilMorningLongitude ?? 0)
        selectSunriseLocationForCurrentSettings()
        pauseForSuspendOrLock.state = state(settings.operations.resolvedPauseForSuspendOrLock)
        updateFeedURL.stringValue = settings.operations.updateFeedURL
        setAdvancedDisclosure(
            row: updateFeedURLRow,
            button: updateSourceAdvancedButton,
            expanded: false
        )
        disableUpdateFeatures.state = state(settings.admin.disableAppUpdateFeatures)
        hideSettingsPath.state = state(settings.admin.hideSettingsFileLocation)
        hideStrictPreferences.state = state(settings.admin.hideStrictPreferences)
        customPreferencesMessage.stringValue = settings.admin.customPreferencesMessage
        setAdvancedDisclosure(
            row: adminControlsStack,
            button: adminControlsAdvancedButton,
            expanded: hasVisibleAdminOverrides(settings.admin)
        )
        syncNumberControlsFromFields()
        updateDependentControlEnablement()
        refreshAppExclusionRuleList()
        updateAppExclusionAddRuleButtonState()
        applyAdminVisibility()
        updateShortcutClearButtons()
        updateAdvancedBulkEditorActionStates()
        updateRestoreDefaultsButtonState()
    }

    @discardableResult
    private func saveCurrentSettings(showAlerts: Bool) -> Bool {
        let appExclusionsEnabled = isOn(appExclusionEnabled)
        let advancedAppExclusions: [AppExclusionRule]?
        let advancedCustomIdeas: [RestIdea]?
        do {
            advancedAppExclusions = appExclusionsEnabled ? try decodedAdvancedAppExclusions() : nil
            advancedCustomIdeas = try decodedAdvancedCustomIdeas()
        } catch {
            if showAlerts {
                showInvalidJSONAlert(error)
            }
            setInvalidSaveStatus(error)
            return false
        }

        var next = settings
        next.eyeGate.isEnabled = isOn(eyeEnabled)
        next.eyeGate.interval = TimeInterval(max(1, intValue(eyeInterval)) * 60)
        next.eyeGate.duration = TimeInterval(max(1, intValue(eyeDuration)))
        next.eyeGate.colorHex = hexString(from: eyeColor.color, fallback: RestSettings.defaults.eyeGate.colorHex)
        next.notifications.eyeGateEnabled = isOn(eyeNotify)
        next.notifications.eyeGateLeadTime = TimeInterval(max(0, intValue(eyeLead)))
        next.eyeGate.manualFinishEnabled = isOn(eyeManualFinish)
        next.eyeGate.emergencyOverride = EmergencyOverridePolicy(
            isEnabled: isOn(eyeEmergencyOverride),
            confirmationSteps: EmergencyOverridePolicy.defaults.confirmationSteps
        )

        next.bodyBreak.isEnabled = isOn(bodyEnabled)
        if !next.eyeGate.isEnabled && !next.bodyBreak.isEnabled {
            next.eyeGate.isEnabled = true
            eyeEnabled.state = .on
            showCannotDisableBothRestsAlert()
        }
        next.bodyBreak.interval = TimeInterval(max(1, intValue(bodyInterval)) * 60)
        next.bodyBreak.duration = TimeInterval(max(1, intValue(bodyDuration)) * 60)
        next.bodyBreakAfterEyeGates = max(1, intValue(bodyAfterEyeGates))
        next.bodyBreak.colorHex = hexString(from: bodyColor.color, fallback: RestSettings.defaults.bodyBreak.colorHex)
        next.notifications.bodyBreakEnabled = isOn(bodyNotify)
        next.notifications.bodyBreakLeadTime = TimeInterval(max(0, intValue(bodyLead)))
        next.bodyBreak.postpone = PostponePolicy(
            isEnabled: max(0, intValue(bodyPostponeLimit)) > 0,
            duration: TimeInterval(max(1, intValue(bodyPostponeMinutes)) * 60),
            maxCount: max(0, intValue(bodyPostponeLimit)),
            allowedDuringFirstPercent: min(100, max(0, doubleValue(bodyPostponeWindowPercent, fallback: 30)))
        )
        if !bodyAllowSkip.isHidden {
            next.bodyBreak.ordinarySkipEnabled = isOn(bodyAllowSkip)
        }
        next.bodyBreak.manualFinishEnabled = isOn(bodyManualFinish)
        next.bodyBreak.enforcement.coversAllDisplays = isOn(bodyCoversAllDisplays)
        next.bodyBreak.enforcement.coveredDisplay = selected(DisplaySelection.self, from: bodyCoveredDisplay, fallback: .primary)
        next.bodyBreak.enforcement.contentDisplay = selected(DisplaySelection.self, from: bodyContentDisplay, fallback: .all)
        next.bodyBreak.enforcement.blankSecondaryDisplays = isOn(bodyBlankSecondaryDisplays)
        next.bodyBreak.enforcement.configuredDisplayIndex = selectedConfiguredDisplayIndex()

        next.naturalBreaks = NaturalBreakSettings(
            isEnabled: isOn(naturalBreaks),
            inactivityResetTime: TimeInterval(max(1, intValue(naturalIdleMinutes)) * 60)
        )
        next.focusMode.monitorFocusMode = isOn(focusMonitor)
        next.focusMode.deferBodyBreak = isOn(focusDefersBody)
        next.workingHours = WorkingHoursSettings(
            isEnabled: isOn(workingHoursEnabled),
            startMinuteOfDay: Self.minutes(fromTimePicker: workingStartPicker, fallback: 9 * 60),
            endMinuteOfDay: Self.minutes(fromTimePicker: workingEndPicker, fallback: 18 * 60)
        )

        next.appExclusions = appExclusionsEnabled ? (advancedAppExclusions ?? savedAppExclusions()) : []
        next.presentation.themeSource = selected(ThemeSource.self, from: themeSource, fallback: .system)
        next.presentation.trayIconStyle = .default
        next.presentation.showMenuBarItem = true
        next.presentation.languageIdentifier = selectedLanguageOption().identifier
        next.presentation.showCurrentTimeDuringBodyBreak = isOn(currentTimeInBodyBreak)
        next.presentation.breakHealthMode = isOn(breakHealth)
        next.notifications.silentNotifications = isOn(silentNotifications)
        let volume = min(1, max(0, soundVolumeSlider.doubleValue))
        next.eyeGate.startSound = soundPolicy(from: eyeStartSound, volume: volume)
        next.eyeGate.finishSound = soundPolicy(from: eyeFinishSound, volume: volume)
        next.bodyBreak.startSound = soundPolicy(from: bodyStartSound, volume: volume)
        next.bodyBreak.finishSound = soundPolicy(from: bodyFinishSound, volume: volume)

        next.contentLibrary.useBuiltInIdeas = isOn(useBuiltInIdeas)
        next.contentLibrary.customBodyBreakIdeas = advancedCustomIdeas ?? savedCustomIdeas()
        next.contentLibrary.localImagePaths = savedLocalImagePaths()
        next.bodyBreak.content = next.contentLibrary.localImagePaths.isEmpty ? .richRestIdea : .localImage
        next.shortcuts.pauseToggle = shortcutPauseToggle.shortcutValue
        next.shortcuts.pauseFor30Minutes = shortcutPause30.shortcutValue
        next.shortcuts.pauseFor1Hour = shortcutPause1h.shortcutValue
        next.shortcuts.pauseFor2Hours = shortcutPause2h.shortcutValue
        next.shortcuts.pauseFor5Hours = shortcutPause5h.shortcutValue
        next.shortcuts.pauseUntilMorning = shortcutPauseUntilMorning.shortcutValue
        next.shortcuts.skipToNextScheduledRest = shortcutNextScheduled.shortcutValue
        next.shortcuts.takeEyeGateNow = shortcutEyeNow.shortcutValue
        next.shortcuts.takeBodyBreakNow = shortcutBodyNow.shortcutValue
        next.shortcuts.skipToNextBodyBreak = ""
        next.shortcuts.endBodyBreak = shortcutEndBody.shortcutValue
        if !(shortcutEmergencyEyeRow?.isHidden ?? false) {
            next.shortcuts.emergencyEyeGateOverride = shortcutEmergencyEye.shortcutValue
        }
        next.shortcuts.reset = shortcutReset.shortcutValue

        next.operations.openAtLogin = isOn(openAtLogin)
        next.operations.checkForUpdates = isOn(checkUpdates)
        next.operations.notifyNewVersion = isOn(notifyNewVersion)
        next.operations.showOnboardingOnNextLaunch = isOn(showOnboardingNextLaunch)
        next.operations.pauseUntilMorningMode = selected(MorningPauseMode.self, from: pauseUntilMorningMode, fallback: .hour)
        next.operations.pauseUntilMorningHour = min(23, max(0, intValue(pauseUntilMorningHour)))
        if let preset = selectedSunriseLocationPreset() {
            next.operations.pauseUntilMorningLatitude = preset.latitude
            next.operations.pauseUntilMorningLongitude = preset.longitude
        } else {
            next.operations.pauseUntilMorningLatitude = min(89.8, max(-89.8, doubleValue(pauseUntilMorningLatitude, fallback: 0)))
            next.operations.pauseUntilMorningLongitude = normalizedLongitude(doubleValue(pauseUntilMorningLongitude, fallback: 0))
        }
        next.operations.pauseForSuspendOrLock = isOn(pauseForSuspendOrLock)
        next.operations.updateFeedURL = updateFeedURL.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        next.admin.disableAppUpdateFeatures = isOn(disableUpdateFeatures)
        next.admin.hideSettingsFileLocation = isOn(hideSettingsPath)
        next.admin.hideStrictPreferences = isOn(hideStrictPreferences)
        next.admin.customPreferencesMessage = customPreferencesMessage.stringValue

        settings = next
        applyAdminVisibility()
        onSave(next)
        setSaveStatus(.saved)
        updateAdvancedBulkEditorActionStates()
        updateRestoreDefaultsButtonState()
        return true
    }

    private func applyAdminVisibility() {
        updateAdminMessageLabel(settings.admin.customPreferencesMessage)
        updateDependentControlEnablement()

        updateUpdatePreferencesVisibility()
        updateShortcutConflictWarning()
    }

    private func updateAdminMessageLabel(_ message: String) {
        let isVisible = !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let visibleMessage = isVisible ? message : ""
        adminMessageLabel.stringValue = visibleMessage
        adminMessageLabel.isHidden = !isVisible
        adminMessageLabel.toolTip = isVisible ? visibleMessage : nil
        adminMessageLabel.setAccessibilityHelp(isVisible ? visibleMessage : nil)
    }

    private func updateUpdatePreferencesVisibility() {
        let hideUpdateControls = settings.admin.disableAppUpdateFeatures
        let showUpdateDependents = !hideUpdateControls && isOn(checkUpdates)
        checkUpdates.isHidden = hideUpdateControls
        notifyNewVersion.isHidden = !showUpdateDependents
        notifyNewVersion.isEnabled = showUpdateDependents
        updateSourceAdvancedButton.isHidden = !showUpdateDependents
        if !showUpdateDependents {
            setAdvancedDisclosure(
                row: updateFeedURLRow,
                button: updateSourceAdvancedButton,
                expanded: false
            )
        }
        updateFeedURL.isEnabled = showUpdateDependents
        updateUpdateSourceRestoreButtonState()
    }

    private func updateUpdateSourceRestoreButtonState() {
        let showUpdateDependents = !settings.admin.disableAppUpdateFeatures && isOn(checkUpdates)
        let usesDefaultSource = updateFeedURL.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines) == Self.defaultUpdateFeedURL
        restoreUpdateSourceButton.isEnabled = showUpdateDependents && !usesDefaultSource

        let help: String
        if !showUpdateDependents {
            help = L10n.tr("prefs.restoreUpdateSourceDisabledUpdatesOffHelp")
        } else if usesDefaultSource {
            help = L10n.tr("prefs.restoreUpdateSourceDisabledDefaultHelp")
        } else {
            help = L10n.tr("prefs.restoreUpdateSourceHelp")
        }
        setIconOnlyActionHelp(
            label: L10n.tr("prefs.restoreUpdateSource"),
            help: help,
            on: restoreUpdateSourceButton
        )
    }

    private func updateShortcutConflictWarning() {
        let entries = visibleShortcutPreferenceEntries()
        entries.forEach { $0.recorder.validationWarning = nil }

        guard let warning = shortcutValidationWarning(for: entries) else {
            shortcutConflictRecorders = []
            shortcutConflictLabel.stringValue = ""
            shortcutConflictLabel.toolTip = nil
            shortcutConflictLabel.setAccessibilityHelp(nil)
            shortcutConflictIcon.image?.accessibilityDescription = L10n.tr("prefs.shortcutConflictTitle")
            shortcutConflictIcon.setAccessibilityHelp(nil)
            shortcutConflictRow.toolTip = nil
            shortcutConflictRow.setAccessibilityHelp(nil)
            shortcutConflictReviewButton.isEnabled = false
            shortcutConflictRow.isHidden = true
            return
        }

        shortcutConflictRecorders = warning.recorders
        shortcutConflictLabel.stringValue = warning.message
        shortcutConflictLabel.toolTip = warning.message
        shortcutConflictLabel.setAccessibilityHelp(warning.message)
        shortcutConflictIcon.image?.accessibilityDescription = warning.message
        shortcutConflictIcon.setAccessibilityHelp(warning.message)
        shortcutConflictRow.toolTip = warning.message
        shortcutConflictRow.setAccessibilityHelp(warning.message)
        shortcutConflictReviewButton.isEnabled = true
        shortcutConflictRow.isHidden = false
        warning.recorders.forEach { $0.validationWarning = warning.message }
    }

    @objc private func reviewShortcutConflictPressed(_ sender: NSButton) {
        guard let recorder = shortcutConflictRecorders.first(where: { !$0.isHidden }) ??
                shortcutConflictRecorders.first else {
            return
        }
        recorder.scrollToVisible(recorder.bounds)
        window?.makeFirstResponder(recorder)
    }

    private func updateShortcutClearButtons() {
        for pair in shortcutClearControls {
            let fallback = pair.recorder.requiredFallbackShortcutValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = pair.recorder.shortcutValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let isRequired = fallback != nil
            let canClear = isRequired ? value != (fallback ?? "") : !value.isEmpty
            let help: String
            if isRequired {
                help = canClear
                    ? L10n.tr("shortcut.restoreDefaultButtonHelp")
                    : L10n.tr("shortcut.restoreDefaultButtonDisabledDefaultHelp")
            } else {
                help = canClear
                    ? L10n.tr("shortcut.clearButtonHelp")
                    : L10n.tr("shortcut.clearButtonDisabledEmptyHelp")
            }
            pair.button.isEnabled = canClear
            pair.button.contentTintColor = canClear ? .secondaryLabelColor : .tertiaryLabelColor
            pair.button.image = NSImage(
                systemSymbolName: isRequired ? "arrow.counterclockwise" : "xmark.circle",
                accessibilityDescription: help
            )
            setIconOnlyActionHelp(help, on: pair.button)
        }
    }

    private struct ShortcutPreferenceEntry {
        var title: String
        var recorder: ShortcutRecorderButton
    }

    private struct ShortcutValidationWarning {
        var message: String
        var recorders: [ShortcutRecorderButton]
    }

    private func shortcutValidationWarning(for entries: [ShortcutPreferenceEntry]) -> ShortcutValidationWarning? {
        var entriesByShortcut: [String: [ShortcutPreferenceEntry]] = [:]
        for entry in entries {
            let rawValue = entry.recorder.shortcutValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawValue.isEmpty else { continue }
            guard let parsed = ParsedShortcut(rawValue) else {
                return ShortcutValidationWarning(
                    message: L10n.format("prefs.shortcutUnsupported", entry.recorder.displayValue, entry.title),
                    recorders: [entry.recorder]
                )
            }
            let key = "\(parsed.modifiers):\(parsed.keyCode)"
            entriesByShortcut[key, default: []].append(entry)
        }

        guard let conflict = entriesByShortcut.values.first(where: { $0.count > 1 }),
              let shortcut = conflict.first?.recorder.displayValue else {
            return nil
        }
        let actions = conflict.map(\.title).joined(separator: ", ")
        return ShortcutValidationWarning(
            message: L10n.format("prefs.shortcutConflict", shortcut, actions),
            recorders: conflict.map(\.recorder)
        )
    }

    private func visibleShortcutPreferenceEntries() -> [ShortcutPreferenceEntry] {
        var entries: [ShortcutPreferenceEntry] = [
            ShortcutPreferenceEntry(title: L10n.tr("prefs.pauseToggle"), recorder: shortcutPauseToggle),
            ShortcutPreferenceEntry(title: L10n.tr("prefs.pause30Shortcut"), recorder: shortcutPause30),
            ShortcutPreferenceEntry(title: L10n.tr("prefs.pause1hShortcut"), recorder: shortcutPause1h),
            ShortcutPreferenceEntry(title: L10n.tr("prefs.pause2hShortcut"), recorder: shortcutPause2h),
            ShortcutPreferenceEntry(title: L10n.tr("prefs.pause5hShortcut"), recorder: shortcutPause5h),
            ShortcutPreferenceEntry(title: L10n.tr("prefs.pauseUntilMorningShortcut"), recorder: shortcutPauseUntilMorning),
            ShortcutPreferenceEntry(title: L10n.tr("prefs.nextScheduledRest"), recorder: shortcutNextScheduled)
        ]

        func appendIfVisible(_ row: NSView?, _ title: String, _ recorder: ShortcutRecorderButton) {
            guard !(row?.isHidden ?? false) else { return }
            entries.append(ShortcutPreferenceEntry(title: title, recorder: recorder))
        }

        appendIfVisible(shortcutEyeNowRow, L10n.tr("prefs.eyeGateNow"), shortcutEyeNow)
        appendIfVisible(shortcutBodyNowRow, L10n.tr("prefs.bodyBreakNow"), shortcutBodyNow)
        appendIfVisible(shortcutEndBodyRow, activeRestShortcutTitleForCurrentControls(), shortcutEndBody)
        appendIfVisible(shortcutEmergencyEyeRow, L10n.tr("prefs.emergencyEyeGate"), shortcutEmergencyEye)
        entries.append(ShortcutPreferenceEntry(title: L10n.tr("prefs.reset"), recorder: shortcutReset))
        return entries
    }

    private func activeRestShortcutTitleForCurrentControls() -> String {
        activeRestShortcutTitle(
            eyeGateEnabled: isOn(eyeEnabled),
            bodyBreakEnabled: isOn(bodyEnabled),
            eyeManualFinishEnabled: isOn(eyeManualFinish)
        )
    }

    private func activeRestShortcutTitle(
        eyeGateEnabled: Bool,
        bodyBreakEnabled: Bool,
        eyeManualFinishEnabled: Bool
    ) -> String {
        if bodyBreakEnabled, eyeGateEnabled, eyeManualFinishEnabled {
            return L10n.tr("prefs.activeRestShortcut.eyeAndBody")
        }
        if bodyBreakEnabled {
            return L10n.tr("prefs.activeRestShortcut.body")
        }
        return L10n.tr("prefs.activeRestShortcut.eye")
    }

    private func activeRestShortcutHelp(
        eyeGateEnabled: Bool,
        bodyBreakEnabled: Bool,
        eyeManualFinishEnabled: Bool
    ) -> String {
        if bodyBreakEnabled, eyeGateEnabled, eyeManualFinishEnabled {
            return L10n.tr("prefs.activeRestShortcut.eyeAndBodyHelp")
        }
        if bodyBreakEnabled {
            return L10n.tr("prefs.activeRestShortcut.bodyHelp")
        }
        return L10n.tr("prefs.activeRestShortcut.eyeHelp")
    }

    private func hasVisibleAdminOverrides(_ admin: AdminSettings) -> Bool {
        admin.disableAppUpdateFeatures ||
            admin.hideSettingsFileLocation ||
            admin.hideStrictPreferences ||
            !admin.customPreferencesMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func updateDependentControlEnablement() {
        let eyeGateEnabled = isOn(eyeEnabled)
        let strictPreferencesHidden = isOn(hideStrictPreferences)
        updateScheduleSummary()
        updateRestEnablementGuards(eyeGateEnabled: eyeGateEnabled)
        [eyeIntervalRow, eyeDurationRow, eyeColorRow].forEach { $0?.isHidden = !eyeGateEnabled }
        [eyeNotify, eyeManualFinish].forEach { $0.isHidden = !eyeGateEnabled }
        setNumberInputEnabled(eyeInterval, eyeGateEnabled)
        setNumberInputEnabled(eyeDuration, eyeGateEnabled)
        eyeColor.isEnabled = eyeGateEnabled
        eyeNotify.isEnabled = eyeGateEnabled
        let eyeNotificationEnabled = eyeGateEnabled && isOn(eyeNotify)
        eyeLeadRow?.isHidden = !eyeNotificationEnabled
        setNumberInputEnabled(eyeLead, eyeNotificationEnabled)
        eyeManualFinish.isEnabled = eyeGateEnabled
        eyeEmergencyOverride.isHidden = strictPreferencesHidden || !eyeGateEnabled
        eyeEmergencyOverride.isEnabled = eyeGateEnabled

        let bodyBreakEnabled = isOn(bodyEnabled)
        [
            bodyIntervalRow,
            bodyDurationRow,
            bodyColorRow,
            bodyPostponeLimitRow,
            bodyContentDisplayRow
        ].forEach { $0?.isHidden = !bodyBreakEnabled }
        [
            bodyNotify,
            bodyManualFinish,
            bodyCoversAllDisplays
        ].forEach { $0.isHidden = !bodyBreakEnabled }
        bodyAllowSkip.isHidden = strictPreferencesHidden || !bodyBreakEnabled
        [
            bodyColor, bodyNotify, bodyAllowSkip, bodyManualFinish, bodyCoversAllDisplays,
            bodyCoveredDisplay, bodyContentDisplay, bodyBlankSecondaryDisplays
        ].forEach { $0.isEnabled = bodyBreakEnabled }
        [
            bodyInterval, bodyDuration, bodyLead, bodyPostponeMinutes,
            bodyPostponeLimit, bodyPostponeWindowPercent
        ].forEach { setNumberInputEnabled($0, bodyBreakEnabled) }
        let bodyAfterEyeGatesVisible = bodyBreakEnabled && eyeGateEnabled
        bodyAfterEyeGatesRow?.isHidden = !bodyAfterEyeGatesVisible
        setNumberInputEnabled(bodyAfterEyeGates, bodyAfterEyeGatesVisible)
        let bodyPostponeEnabled = bodyBreakEnabled && intValue(bodyPostponeLimit) > 0
        [bodyPostponeMinutesRow, bodyPostponeWindowPercentRow].forEach { $0?.isHidden = !bodyPostponeEnabled }
        [bodyPostponeMinutes, bodyPostponeWindowPercent].forEach { setNumberInputEnabled($0, bodyPostponeEnabled) }
        let bodyNotificationEnabled = bodyBreakEnabled && isOn(bodyNotify)
        bodyLeadRow?.isHidden = !bodyNotificationEnabled
        setNumberInputEnabled(bodyLead, bodyNotificationEnabled)
        let coversAllDisplays = isOn(bodyCoversAllDisplays)
        let coveredDisplaySelection = selected(DisplaySelection.self, from: bodyCoveredDisplay, fallback: .primary)
        let contentDisplaySelection = selected(DisplaySelection.self, from: bodyContentDisplay, fallback: .all)
        bodyCoveredDisplayRow?.isHidden = !bodyBreakEnabled || coversAllDisplays
        bodyCoveredDisplay.isEnabled = bodyBreakEnabled && !coversAllDisplays
        let canBlankSecondaryDisplays = contentDisplaySelection != .all && contentDisplaySelection != .none
        bodyBlankSecondaryDisplays.isHidden = !bodyBreakEnabled || !canBlankSecondaryDisplays
        bodyBlankSecondaryDisplays.isEnabled = bodyBreakEnabled && canBlankSecondaryDisplays
        let usesConfiguredDisplay = (!coversAllDisplays && coveredDisplaySelection == .configured) ||
            contentDisplaySelection == .configured
        bodyConfiguredDisplayRow?.isHidden = !bodyBreakEnabled || !usesConfiguredDisplay
        bodyConfiguredDisplay.isEnabled = bodyBreakEnabled && usesConfiguredDisplay
        bodyDisplaySummaryLabel.isHidden = !bodyBreakEnabled
        updateBodyDisplaySummary(
            coversAllDisplays: coversAllDisplays,
            coveredDisplay: coveredDisplaySelection,
            contentDisplay: contentDisplaySelection,
            blanksDisplaysWithoutContent: isOn(bodyBlankSecondaryDisplays)
        )

        let naturalBreaksEnabled = isOn(naturalBreaks)
        naturalIdleMinutesRow?.isHidden = !naturalBreaksEnabled
        setNumberInputEnabled(naturalIdleMinutes, naturalBreaksEnabled)

        let focusMonitorVisible = bodyBreakEnabled
        focusMonitor.isHidden = !focusMonitorVisible
        focusMonitor.isEnabled = focusMonitorVisible
        let focusDefersBodyVisible = focusMonitorVisible && isOn(focusMonitor)
        focusDefersBody.isHidden = !focusDefersBodyVisible
        focusDefersBody.isEnabled = focusDefersBodyVisible

        let workingHoursAreEnabled = isOn(workingHoursEnabled)
        workingStartRow?.isHidden = !workingHoursAreEnabled
        workingEndRow?.isHidden = !workingHoursAreEnabled
        workingStartPicker.isEnabled = workingHoursAreEnabled
        workingEndPicker.isEnabled = workingHoursAreEnabled

        let exclusionEnabled = isOn(appExclusionEnabled)
        [
            appExclusionNameRow, appExclusionTermsRow, appExclusionModeRow, appExclusionAddRuleRow
        ].forEach { $0?.isHidden = !exclusionEnabled }
        [
            appExclusionsAdvancedButton
        ].forEach { $0.isHidden = !exclusionEnabled }
        let appExclusionAppliesEyeVisible = exclusionEnabled && eyeGateEnabled
        let appExclusionAppliesBodyVisible = exclusionEnabled && bodyBreakEnabled
        appExclusionAppliesEye.isHidden = !appExclusionAppliesEyeVisible
        appExclusionAppliesBody.isHidden = !appExclusionAppliesBodyVisible
        appExclusionPreviewLabel.isHidden = !exclusionEnabled
        let hasVisibleExclusionTarget =
            (appExclusionAppliesEyeVisible && isOn(appExclusionAppliesEye)) ||
            (appExclusionAppliesBodyVisible && isOn(appExclusionAppliesBody))
        if exclusionEnabled && !hasVisibleExclusionTarget {
            if appExclusionAppliesBodyVisible {
                appExclusionAppliesBody.state = .on
            } else if appExclusionAppliesEyeVisible {
                appExclusionAppliesEye.state = .on
            }
        }
        updateAppExclusionTargetGuards(
            eyeVisible: appExclusionAppliesEyeVisible,
            bodyVisible: appExclusionAppliesBodyVisible
        )
        if !exclusionEnabled {
            setAdvancedDisclosure(row: appExclusionsJSONRow, button: appExclusionsAdvancedButton, expanded: false)
        }
        [
            appExclusionName, appExclusionTerms, appExclusionMode
        ].forEach { $0.isEnabled = exclusionEnabled }
        appExclusionAddRunningApp.isEnabled = exclusionEnabled
        refreshAppExclusionRuleList()
        updateAppExclusionAddRuleButtonState()
        updateContextSummary()

        updateUpdatePreferencesVisibility()

        let morningMode = selected(MorningPauseMode.self, from: pauseUntilMorningMode, fallback: .hour)
        let usesSunrise = morningMode == .sunrise
        let usesCustomSunriseLocation = usesSunrise && selectedSunriseLocationPreset() == nil
        pauseUntilMorningLocationRow?.isHidden = !usesSunrise
        pauseUntilMorningHourRow?.isHidden = usesSunrise
        pauseUntilMorningLatitudeRow?.isHidden = !usesCustomSunriseLocation
        pauseUntilMorningLongitudeRow?.isHidden = !usesCustomSunriseLocation
        setNumberInputEnabled(pauseUntilMorningHour, !usesSunrise)
        pauseUntilMorningLocation.isEnabled = usesSunrise
        pauseUntilMorningLatitude.isEnabled = usesCustomSunriseLocation
        pauseUntilMorningLongitude.isEnabled = usesCustomSunriseLocation
        updateMorningPauseSummary()

        updateAppearanceEyeGateVisibility(eyeGateEnabled: eyeGateEnabled)
        updateAppearanceBodyBreakVisibility(bodyBreakEnabled: bodyBreakEnabled)
        updateSoundPreviewButtons()
        updateShortcutPreferenceVisibility(
            eyeGateEnabled: eyeGateEnabled,
            bodyBreakEnabled: bodyBreakEnabled,
            eyeManualFinishEnabled: isOn(eyeManualFinish),
            strictPreferencesHidden: strictPreferencesHidden
        )
        updateAdvancedBulkEditorActionStates()
    }

    private func updateSoundPreviewButtons() {
        let mutedBySilentNotifications = isOn(silentNotifications)
        [
            (eyeStartSoundPreview, "eyeStart"),
            (eyeFinishSoundPreview, "eyeFinish"),
            (bodyStartSoundPreview, "bodyStart"),
            (bodyFinishSoundPreview, "bodyFinish")
        ].forEach { button, identifier in
            guard let soundLabel = soundPreviewLabel(for: identifier) else { return }
            updateSoundPreviewButton(
                button,
                soundLabel: soundLabel,
                mutedBySilentNotifications: mutedBySilentNotifications
            )
        }
    }

    private func updateSoundPreviewButton(
        _ button: NSButton,
        soundLabel: String,
        mutedBySilentNotifications: Bool
    ) {
        let accessibilityLabel = L10n.format("prefs.previewSoundLabel", soundLabel)
        let help = mutedBySilentNotifications
            ? L10n.format("prefs.previewSoundMutedHelp", soundLabel)
            : L10n.format("prefs.previewSoundSpecificHelp", soundLabel)
        button.image?.accessibilityDescription = accessibilityLabel
        button.toolTip = help
        button.setAccessibilityLabel(accessibilityLabel)
        button.setAccessibilityHelp(help)
    }

    private func updateRestEnablementGuards(eyeGateEnabled: Bool) {
        let bodyBreakEnabled = isOn(bodyEnabled)
        let canToggleEyeGate = !eyeGateEnabled || bodyBreakEnabled
        let canToggleBodyBreak = !bodyBreakEnabled || eyeGateEnabled
        let help = L10n.tr("prefs.cannotDisableBothRests")

        eyeEnabled.isEnabled = canToggleEyeGate
        bodyEnabled.isEnabled = canToggleBodyBreak
        setOptionalHelp(canToggleEyeGate ? L10n.tr("prefs.enableEyeGateHelp") : help, on: eyeEnabled)
        setOptionalHelp(canToggleBodyBreak ? L10n.tr("prefs.enableBodyBreakHelp") : help, on: bodyEnabled)
    }

    private func updateScheduleSummary() {
        let eyeGateEnabled = isOn(eyeEnabled)
        let bodyBreakEnabled = isOn(bodyEnabled)
        let eyeIntervalMinutes = max(1, intValue(eyeInterval))
        let eyeDurationSeconds = max(1, intValue(eyeDuration))
        let bodyIntervalMinutes = max(1, intValue(bodyInterval))
        let bodyDurationMinutes = max(1, intValue(bodyDuration))
        let bodyAfterEyeGateCount = max(1, intValue(bodyAfterEyeGates))

        if eyeGateEnabled && bodyBreakEnabled {
            scheduleSummaryLabel.stringValue = L10n.format(
                "prefs.scheduleSummary.eyeAndBody",
                eyeIntervalMinutes,
                eyeDurationSeconds,
                bodyAfterEyeGateCount,
                bodyDurationMinutes
            )
        } else if eyeGateEnabled {
            scheduleSummaryLabel.stringValue = L10n.format(
                "prefs.scheduleSummary.eyeOnly",
                eyeIntervalMinutes,
                eyeDurationSeconds
            )
        } else if bodyBreakEnabled {
            scheduleSummaryLabel.stringValue = L10n.format(
                "prefs.scheduleSummary.bodyOnly",
                bodyIntervalMinutes,
                bodyDurationMinutes
            )
        } else {
            scheduleSummaryLabel.stringValue = L10n.tr("prefs.scheduleSummary.none")
        }
        scheduleSummaryLabel.toolTip = scheduleSummaryLabel.stringValue
        scheduleSummaryLabel.setAccessibilityHelp(scheduleSummaryLabel.stringValue)
        scheduleSummaryIcon.image?.accessibilityDescription = scheduleSummaryLabel.stringValue
        scheduleSummaryIcon.setAccessibilityHelp(scheduleSummaryLabel.stringValue)
        updateRhythmPresetButtonStates()
    }

    private func updateRhythmPresetButtonStates() {
        let selectedPreset = currentMatchingRhythmPreset()
        rhythmPresetButtonEntries.forEach { entry in
            let isSelected = entry.preset == selectedPreset
            entry.button.state = isSelected ? .on : .off
            entry.button.contentTintColor = isSelected ? .controlAccentColor : nil
            entry.button.toolTip = rhythmPresetButtonHelp(for: entry.preset, isSelected: isSelected)
            entry.button.setAccessibilityHelp(entry.button.toolTip)
        }
    }

    private func currentMatchingRhythmPreset() -> RestRhythmPreset? {
        guard isOn(eyeEnabled),
              isOn(bodyEnabled) else { return nil }

        let eyeIntervalMinutes = max(1, intValue(eyeInterval))
        let eyeDurationSeconds = max(1, intValue(eyeDuration))
        let bodyIntervalMinutes = max(1, intValue(bodyInterval))
        let bodyDurationMinutes = max(1, intValue(bodyDuration))
        let bodyAfterEyeGateCount = max(1, intValue(bodyAfterEyeGates))

        return RestRhythmPreset.allCases.first { preset in
            preset.eyeIntervalMinutes == eyeIntervalMinutes &&
                preset.eyeDurationSeconds == eyeDurationSeconds &&
                preset.bodyIntervalMinutes == bodyIntervalMinutes &&
                preset.bodyDurationMinutes == bodyDurationMinutes &&
                preset.bodyAfterEyeGateCount == bodyAfterEyeGateCount
        }
    }

    private func rhythmPresetButtonHelp(for preset: RestRhythmPreset, isSelected: Bool) -> String {
        let key = isSelected ? "prefs.rhythmPreset.selectedHelp" : "prefs.rhythmPreset.applyHelp"
        return L10n.format(key, preset.title, preset.help)
    }

    private func updateShortcutPreferenceVisibility(
        eyeGateEnabled: Bool,
        bodyBreakEnabled: Bool,
        eyeManualFinishEnabled: Bool,
        strictPreferencesHidden: Bool
    ) {
        shortcutEyeNowRow?.isHidden = !eyeGateEnabled
        shortcutEyeNow.isEnabled = eyeGateEnabled

        shortcutBodyNowRow?.isHidden = !bodyBreakEnabled
        shortcutBodyNow.isEnabled = bodyBreakEnabled

        let canEndActiveRest = bodyBreakEnabled || (eyeGateEnabled && eyeManualFinishEnabled)
        shortcutEndBodyRow?.isHidden = !canEndActiveRest
        shortcutEndBody.isEnabled = canEndActiveRest
        updateActiveRestShortcutCopy(
            eyeGateEnabled: eyeGateEnabled,
            bodyBreakEnabled: bodyBreakEnabled,
            eyeManualFinishEnabled: eyeManualFinishEnabled
        )

        let emergencyVisible = eyeGateEnabled && !strictPreferencesHidden && isOn(eyeEmergencyOverride)
        shortcutEmergencyEyeRow?.isHidden = !emergencyVisible
        shortcutEmergencyEye.isEnabled = emergencyVisible
        updateShortcutConflictWarning()
    }

    private func updateActiveRestShortcutCopy(
        eyeGateEnabled: Bool,
        bodyBreakEnabled: Bool,
        eyeManualFinishEnabled: Bool
    ) {
        let title = activeRestShortcutTitle(
            eyeGateEnabled: eyeGateEnabled,
            bodyBreakEnabled: bodyBreakEnabled,
            eyeManualFinishEnabled: eyeManualFinishEnabled
        )
        let help = activeRestShortcutHelp(
            eyeGateEnabled: eyeGateEnabled,
            bodyBreakEnabled: bodyBreakEnabled,
            eyeManualFinishEnabled: eyeManualFinishEnabled
        )
        shortcutEndBodyLabel?.stringValue = title
        shortcutEndBodyLabel?.toolTip = help
        shortcutEndBodyLabel?.setAccessibilityHelp(help)
        shortcutEndBody.actionHelp = help
        shortcutEndBodyRow?.toolTip = help
        shortcutEndBodyRow?.setAccessibilityHelp(help)
    }

    private func updateAppearanceEyeGateVisibility(eyeGateEnabled: Bool) {
        eyeStartSoundRow?.isHidden = !eyeGateEnabled
        eyeFinishSoundRow?.isHidden = !eyeGateEnabled
        [eyeStartSound, eyeFinishSound, eyeStartSoundPreview, eyeFinishSoundPreview].forEach {
            $0.isEnabled = eyeGateEnabled
        }
    }

    private func updateAppearanceBodyBreakVisibility(bodyBreakEnabled: Bool) {
        currentTimeInBodyBreak.isHidden = !bodyBreakEnabled
        currentTimeInBodyBreak.isEnabled = bodyBreakEnabled
        bodyStartSoundRow?.isHidden = !bodyBreakEnabled
        bodyFinishSoundRow?.isHidden = !bodyBreakEnabled
        [bodyStartSound, bodyFinishSound, bodyStartSoundPreview, bodyFinishSoundPreview].forEach {
            $0.isEnabled = bodyBreakEnabled
        }
        [localImagePathRow, customBodyTitleRow, customBodyTextRow, customBodyAddIdeaButtonRow].forEach {
            $0?.isHidden = !bodyBreakEnabled
        }
        bodyContentSummaryLabel.isHidden = !bodyBreakEnabled
        refreshCustomBodyIdeaList()
        customBodyIdeasAdvancedButton.isHidden = !bodyBreakEnabled
        if !bodyBreakEnabled {
            setAdvancedDisclosure(row: customBodyIdeasJSONRow, button: customBodyIdeasAdvancedButton, expanded: false)
        }
        customBodyTitle.isEnabled = bodyBreakEnabled
        customBodyTextEditor.isEditable = bodyBreakEnabled
        customBodyTextScrollView.alphaValue = bodyBreakEnabled ? 1 : 0.55
        customBodyIdeasJSONEditor.isEditable = bodyBreakEnabled
        customBodyIdeasJSONScrollView.alphaValue = bodyBreakEnabled ? 1 : 0.55
        updateLocalImageChooseButtonState(bodyBreakEnabled: bodyBreakEnabled)
        updateLocalImageClearButtonState(bodyBreakEnabled: bodyBreakEnabled)
        localImagePreview.isDropEnabled = bodyBreakEnabled
        updateLocalImagePreviewDropHelp(bodyBreakEnabled: bodyBreakEnabled)
        updateBodyContentSummary()
        updateCustomBodyAddIdeaButtonState()
    }

    private func updateLocalImageChooseButtonState(bodyBreakEnabled: Bool) {
        localImageChooseButton.isEnabled = bodyBreakEnabled
        let help = bodyBreakEnabled
            ? L10n.tr("prefs.chooseBodyImageHelp")
            : L10n.tr("prefs.chooseBodyImageDisabledBodyOffHelp")
        setTextButtonHelp(title: localImageChooseButton.title, help: help, on: localImageChooseButton)
    }

    private func updateLocalImagePreviewDropHelp(bodyBreakEnabled: Bool) {
        let help = bodyBreakEnabled
            ? L10n.tr("prefs.imageDropHelp")
            : L10n.tr("prefs.imageDropDisabledBodyOffHelp")
        localImagePreview.toolTip = help
        localImagePreview.setAccessibilityHelp(help)
    }

    private func updateLocalImageClearButtonState(bodyBreakEnabled: Bool) {
        let hasImagePath = !localImagePath.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        localImageClearButton.isEnabled = bodyBreakEnabled && hasImagePath
        let help: String
        if !bodyBreakEnabled {
            help = L10n.tr("prefs.clearBodyImageDisabledBodyOffHelp")
        } else if !hasImagePath {
            help = L10n.tr("prefs.clearBodyImageDisabledEmptyHelp")
        } else {
            help = L10n.tr("prefs.clearBodyImageHelp")
        }
        setTextButtonHelp(title: localImageClearButton.title, help: help, on: localImageClearButton)
    }

    private func setNumberInputEnabled(_ field: NSTextField, _ enabled: Bool) {
        field.isEnabled = enabled
        let input = numberInputs.first(where: { $0.field === field })
        input?.stepper.isEnabled = enabled
        input?.slider?.isEnabled = enabled
    }

    @objc private func restoreDefaultsPressed() {
        guard !restorablePreferencesAreDefault() else {
            updateRestoreDefaultsButtonState()
            return
        }
        guard confirmRestoreDefaults() else { return }
        settings = .restoredDefaults
        loadSettings()
        onSave(settings)
        setSaveStatus(.restored)
    }

    @objc private func restoreUpdateSourcePressed(_ sender: NSButton) {
        guard !settings.admin.disableAppUpdateFeatures,
              isOn(checkUpdates),
              updateFeedURL.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) != Self.defaultUpdateFeedURL else {
            updateUpdateSourceRestoreButtonState()
            return
        }

        updateFeedURL.stringValue = Self.defaultUpdateFeedURL
        updateUpdateSourceRestoreButtonState()
        scheduleAutosave()
    }

    private func confirmRestoreDefaults() -> Bool {
        makeRestoreDefaultsAlert().runModal() == .alertSecondButtonReturn
    }

    private func updateRestoreDefaultsButtonState() {
        let isDefault = restorablePreferencesAreDefault()
        restoreDefaultsButton.isEnabled = !isDefault
        let help = isDefault ? L10n.tr("prefs.restoreDefaultsDisabledDefaultHelp") : L10n.tr("prefs.restoreDefaultsHelp")
        setTextButtonHelp(title: restoreDefaultsButton.title, help: help, on: restoreDefaultsButton)
    }

    private func markRestoreDefaultsAvailableForPendingPreferenceChange() {
        restoreDefaultsButton.isEnabled = true
        setTextButtonHelp(
            title: restoreDefaultsButton.title,
            help: L10n.tr("prefs.restoreDefaultsHelp"),
            on: restoreDefaultsButton
        )
    }

    private func restorablePreferencesAreDefault() -> Bool {
        Self.restorableComparisonSettings(settings) == Self.restorableComparisonSettings(.restoredDefaults)
    }

    private static func restorableComparisonSettings(_ settings: RestSettings) -> RestSettings {
        var copy = settings
        copy.operations.hasCompletedOnboarding = RestSettings.restoredDefaults.operations.hasCompletedOnboarding
        return copy
    }

    func makeRestoreDefaultsAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = L10n.tr("prefs.restoreDefaults")
        alert.informativeText = L10n.tr("prefs.restoreDefaultsWarning")
        alert.alertStyle = .warning
        let cancelButton = alert.addButton(withTitle: L10n.tr("prefs.restoreDefaultsCancel"))
        let restoreButton = alert.addButton(withTitle: L10n.tr("prefs.restoreDefaultsContinue"))
        cancelButton.keyEquivalent = "\r"
        restoreButton.keyEquivalent = ""
        if #available(macOS 11.0, *) {
            restoreButton.hasDestructiveAction = true
        }
        return alert
    }

    @objc private func restEnablementChanged(_ sender: NSButton) {
        guard !isOn(eyeEnabled), !isOn(bodyEnabled) else {
            updateDependentControlEnablement()
            scheduleAutosave()
            return
        }
        sender.state = .on
        showCannotDisableBothRestsAlert()
        updateDependentControlEnablement()
        scheduleAutosave()
    }

    @objc private func controlChanged(_ sender: Any) {
        if let slider = sender as? NSSlider, slider === soundVolumeSlider {
            soundVolume.stringValue = String(soundVolumeSlider.doubleValue)
            updateSoundVolumeLabel()
        }
        if let popup = sender as? NSPopUpButton, isSoundPopup(popup) {
            clearSoundPreviewStatus()
        }
        if let popup = sender as? NSPopUpButton {
            if popup === pauseUntilMorningMode {
                applyDefaultSunriseLocationIfNeeded()
            } else if popup === pauseUntilMorningLocation {
                applySelectedSunriseLocationPreset()
            }
        }
        updateDependentControlEnablement()
        if isAppExclusionDraftControl(sender), hasAppExclusionRuleList {
            updateAppExclusionAddRuleButtonState()
            return
        }
        scheduleAutosave()
    }

    @objc private func rhythmPresetPressed(_ sender: NSButton) {
        guard let preset = RestRhythmPreset(rawValue: sender.tag) else { return }
        applyRhythmPreset(preset)
    }

    private func applyRhythmPreset(_ preset: RestRhythmPreset) {
        eyeEnabled.state = .on
        bodyEnabled.state = .on
        eyeInterval.stringValue = String(preset.eyeIntervalMinutes)
        eyeDuration.stringValue = String(preset.eyeDurationSeconds)
        bodyInterval.stringValue = String(preset.bodyIntervalMinutes)
        bodyAfterEyeGates.stringValue = String(preset.bodyAfterEyeGateCount)
        bodyDuration.stringValue = String(preset.bodyDurationMinutes)
        syncNumberControlsFromFields()
        updateDependentControlEnablement()
        scheduleAutosave()
    }

    @objc private func addRunningAppExclusionPressed(_ sender: NSButton) {
        let candidates = appExclusionApplicationCandidatesProvider()
            .filter { !$0.terms.isEmpty }
        guard !candidates.isEmpty else {
            showNoRunningApplicationsMenu(from: sender)
            return
        }

        if candidates.count == 1, let candidate = candidates.first {
            addAppExclusionApplicationCandidate(candidate)
            return
        }

        let menu = NSMenu()
        for candidate in candidates {
            let item = NSMenuItem(
                title: candidate.menuTitle,
                action: #selector(addRunningAppExclusionMenuItemSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = AppExclusionApplicationCandidateBox(candidate)
            item.image = NSImage(systemSymbolName: "app", accessibilityDescription: nil)
            menu.addItem(item)
        }
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: sender.bounds.maxY + 4),
            in: sender
        )
    }

    @objc private func addRunningAppExclusionMenuItemSelected(_ sender: NSMenuItem) {
        guard let box = sender.representedObject as? AppExclusionApplicationCandidateBox else { return }
        addAppExclusionApplicationCandidate(box.candidate)
    }

    @objc private func addAppExclusionRulePressed(_ sender: NSButton) {
        let id = editingAppExclusionRuleID ?? UUID().uuidString
        guard let rule = currentAppExclusionRule(id: id) else { return }
        clearArmedRemovalState()
        saveAppExclusionRule(rule, replacingID: editingAppExclusionRuleID)
    }

    @objc private func editAppExclusionRulePressed(_ sender: NSButton) {
        guard let match = appExclusionRuleEditControls.first(where: { $0.button === sender }),
              let rule = displayedAppExclusionRules().first(where: { $0.id == match.id }) else {
            return
        }
        clearArmedRemovalState()
        editingAppExclusionRuleID = rule.id
        appExclusionName.stringValue = rule.name
        appExclusionTerms.objectValue = rule.matchTerms
        selectPopup(appExclusionMode, rawValue: rule.mode.rawValue)
        appExclusionAppliesEye.state = state(rule.appliesTo.contains(.eyeGate))
        appExclusionAppliesBody.state = state(rule.appliesTo.contains(.bodyBreak))
        updateAppExclusionAddRuleButtonState()
    }

    @objc private func cancelAppExclusionRuleEditPressed(_ sender: NSButton) {
        clearArmedRemovalState()
        appExclusionName.stringValue = ""
        appExclusionTerms.objectValue = []
        setDefaultAppExclusionTargets()
        clearAppExclusionRuleEditState()
        updateAppExclusionAddRuleButtonState()
    }

    private func showNoRunningApplicationsMenu(from sender: NSButton) {
        let menu = NSMenu()
        let item = NSMenuItem(title: L10n.tr("prefs.noRunningApps"), action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: sender.bounds.maxY + 4),
            in: sender
        )
    }

    @objc private func addCustomBodyIdeaPressed(_ sender: NSButton) {
        let id = editingCustomBodyIdeaID ?? UUID().uuidString
        guard let idea = currentCustomBodyIdea(id: id) else { return }
        do {
            clearArmedRemovalState()
            var ideas = try decodedAdvancedCustomIdeas() ?? []
            if let editingCustomBodyIdeaID,
               let index = ideas.firstIndex(where: { $0.id == editingCustomBodyIdeaID }) {
                ideas[index] = idea
            } else {
                ideas.append(idea)
            }
            customBodyIdeasJSONEditor.string = encodedCustomIdeasForEditor(ideas)
            setAdvancedDisclosure(row: customBodyIdeasJSONRow, button: customBodyIdeasAdvancedButton, expanded: false)
            customBodyTitle.stringValue = ""
            customBodyTextEditor.string = ""
            clearCustomBodyIdeaEditState()
            refreshCustomBodyIdeaList()
            updateCustomBodyAddIdeaButtonState()
            scheduleAutosave()
        } catch {
            showInvalidJSONAlert(error)
            setInvalidSaveStatus(error)
        }
    }

    @objc private func editCustomBodyIdeaPressed(_ sender: NSButton) {
        guard let match = customBodyIdeaEditControls.first(where: { $0.button === sender }),
              let idea = displayedCustomBodyIdeas().first(where: { $0.id == match.id }) else {
            return
        }
        clearArmedRemovalState()
        editingCustomBodyIdeaID = idea.id
        customBodyTitle.stringValue = idea.title
        customBodyTextEditor.string = idea.body
        updateCustomBodyAddIdeaButtonState()
    }

    @objc private func cancelCustomBodyIdeaEditPressed(_ sender: NSButton) {
        clearArmedRemovalState()
        customBodyTitle.stringValue = ""
        customBodyTextEditor.string = ""
        clearCustomBodyIdeaEditState()
        updateCustomBodyAddIdeaButtonState()
    }

    @objc private func removeCustomBodyIdeaPressed(_ sender: NSButton) {
        guard let match = customBodyIdeaRemoveControls.first(where: { $0.button === sender }) else { return }
        guard armedCustomBodyIdeaRemovalID == match.id else {
            armCustomBodyIdeaRemoval(id: match.id)
            return
        }
        do {
            clearArmedRemovalState()
            var ideas = try decodedAdvancedCustomIdeas() ?? []
            ideas.removeAll { $0.id == match.id }
            clearCustomBodyIdeaEditState()
            if let first = ideas.first {
                customBodyTitle.stringValue = first.title
                customBodyTextEditor.string = first.body
            } else {
                customBodyTitle.stringValue = ""
                customBodyTextEditor.string = ""
            }
            customBodyIdeasJSONEditor.string = ideas.count > 1 ? encodedCustomIdeasForEditor(ideas) : ""
            setAdvancedDisclosure(row: customBodyIdeasJSONRow, button: customBodyIdeasAdvancedButton, expanded: false)
            refreshCustomBodyIdeaList()
            updateCustomBodyAddIdeaButtonState()
            scheduleAutosave()
        } catch {
            showInvalidJSONAlert(error)
            setInvalidSaveStatus(error)
        }
    }

    @objc private func removeAppExclusionRulePressed(_ sender: NSButton) {
        guard let match = appExclusionRuleRemoveControls.first(where: { $0.button === sender }) else { return }
        guard armedAppExclusionRuleRemovalID == match.id else {
            armAppExclusionRuleRemoval(id: match.id)
            return
        }
        do {
            clearArmedRemovalState()
            var rules = try decodedAdvancedAppExclusions() ?? []
            rules.removeAll { $0.id == match.id }
            clearAppExclusionRuleEditState()
            if rules.isEmpty {
                appExclusionsJSONEditor.string = ""
                appExclusionEnabled.state = .off
            } else {
                appExclusionsJSONEditor.string = encodedAppExclusionsForEditor(rules)
            }
            appExclusionName.stringValue = ""
            appExclusionTerms.objectValue = []
            setDefaultAppExclusionTargets()
            setAdvancedDisclosure(row: appExclusionsJSONRow, button: appExclusionsAdvancedButton, expanded: false)
            refreshAppExclusionRuleList()
            updateDependentControlEnablement()
            updateAppExclusionAddRuleButtonState()
            scheduleAutosave()
        } catch {
            showInvalidJSONAlert(error)
            setInvalidSaveStatus(error)
        }
    }

    @objc private func shortcutClearPressed(_ sender: NSButton) {
        guard let pair = shortcutClearControls.first(where: { $0.button === sender }) else { return }
        let nextValue = pair.recorder.requiredFallbackShortcutValue ?? ""
        guard pair.recorder.shortcutValue != nextValue else {
            updateShortcutClearButtons()
            return
        }
        pair.recorder.shortcutValue = nextValue
        pair.recorder.onChange?()
    }

    @objc private func toggleAdvancedDisclosure(_ sender: NSButton) {
        switch sender.identifier?.rawValue {
        case "appExclusions":
            setAdvancedDisclosure(
                row: appExclusionsJSONRow,
                button: appExclusionsAdvancedButton,
                expanded: appExclusionsJSONRow?.isHidden ?? true
            )
        case "customIdeas":
            setAdvancedDisclosure(
                row: customBodyIdeasJSONRow,
                button: customBodyIdeasAdvancedButton,
                expanded: customBodyIdeasJSONRow?.isHidden ?? true
            )
        case "adminControls":
            setAdvancedDisclosure(
                row: adminControlsStack,
                button: adminControlsAdvancedButton,
                expanded: adminControlsStack.isHidden
            )
        case "updateSource":
            setAdvancedDisclosure(
                row: updateFeedURLRow,
                button: updateSourceAdvancedButton,
                expanded: updateFeedURLRow?.isHidden ?? true
            )
        default:
            break
        }
    }

    @objc private func copyAppRulesBulkEditorPressed(_ sender: NSButton) {
        copyBulkEditorText(appExclusionsJSONEditor, copiedObjectName: L10n.tr("prefs.advancedRulesJSON"))
    }

    @objc private func restoreAppRulesBulkEditorPressed(_ sender: NSButton) {
        restoreBulkEditorText(
            appExclusionsJSONEditor,
            text: savedAppRulesBulkEditorText()
        ) { [weak self] in
            self?.refreshAppExclusionRuleList()
            self?.updateAppExclusionAddRuleButtonState()
            self?.updateContextSummary()
        }
    }

    @objc private func copyIdeasBulkEditorPressed(_ sender: NSButton) {
        copyBulkEditorText(customBodyIdeasJSONEditor, copiedObjectName: L10n.tr("prefs.advancedIdeasJSON"))
    }

    @objc private func restoreIdeasBulkEditorPressed(_ sender: NSButton) {
        restoreBulkEditorText(
            customBodyIdeasJSONEditor,
            text: savedIdeasBulkEditorText()
        ) { [weak self] in
            self?.refreshCustomBodyIdeaList()
            self?.updateCustomBodyAddIdeaButtonState()
        }
    }

    private func copyBulkEditorText(_ editor: NSTextView, copiedObjectName: String) {
        let text = editor.string
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            updateAdvancedBulkEditorActionStates()
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        setSaveStatus(.copied, objectName: copiedObjectName)
        updateAdvancedBulkEditorActionStates()
    }

    private func restoreBulkEditorText(
        _ editor: NSTextView,
        text: String,
        afterRestore: () -> Void
    ) {
        guard editor.string != text else {
            updateAdvancedBulkEditorActionStates()
            return
        }
        editor.string = text
        afterRestore()
        updateAdvancedBulkEditorActionStates()
        scheduleAutosave()
    }

    private func savedAppRulesBulkEditorText() -> String {
        guard isOn(appExclusionEnabled) else { return "" }
        return encodedAppExclusionsForEditor(settings.appExclusions)
    }

    private func savedIdeasBulkEditorText() -> String {
        guard isOn(bodyEnabled) else { return "" }
        return encodedCustomIdeasForEditor(settings.contentLibrary.customBodyBreakIdeas)
    }

    private func updateAdvancedBulkEditorActionStates() {
        let appText = appExclusionsJSONEditor.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedAppText = savedAppRulesBulkEditorText()
        let appRulesEnabled = isOn(appExclusionEnabled)
        appExclusionsCopyBulkButton.isEnabled = appRulesEnabled && !appText.isEmpty
        setTextButtonHelp(
            title: appExclusionsCopyBulkButton.title,
            help: advancedCopyHelp(
                isFeatureEnabled: appRulesEnabled,
                hasText: !appText.isEmpty,
                enabledHelp: L10n.tr("prefs.copyAppRulesBulkEditorHelp"),
                disabledFeatureHelp: L10n.tr("prefs.copyAppRulesBulkEditorDisabledOffHelp"),
                disabledEmptyHelp: L10n.tr("prefs.copyAppRulesBulkEditorDisabledEmptyHelp")
            ),
            on: appExclusionsCopyBulkButton
        )
        appExclusionsRestoreBulkButton.isEnabled = isOn(appExclusionEnabled) && appExclusionsJSONEditor.string != savedAppText
        setTextButtonHelp(
            title: appExclusionsRestoreBulkButton.title,
            help: advancedRestoreHelp(
                isFeatureEnabled: appRulesEnabled,
                hasUnsavedEditorChanges: appExclusionsJSONEditor.string != savedAppText,
                enabledHelp: L10n.tr("prefs.restoreAppRulesBulkEditorHelp"),
                disabledFeatureHelp: L10n.tr("prefs.restoreAppRulesBulkEditorDisabledOffHelp"),
                disabledNoChangesHelp: L10n.tr("prefs.restoreAppRulesBulkEditorDisabledNoChangesHelp")
            ),
            on: appExclusionsRestoreBulkButton
        )

        let ideasText = customBodyIdeasJSONEditor.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedIdeasText = savedIdeasBulkEditorText()
        let bodyBreakEnabled = isOn(bodyEnabled)
        customBodyIdeasCopyBulkButton.isEnabled = bodyBreakEnabled && !ideasText.isEmpty
        setTextButtonHelp(
            title: customBodyIdeasCopyBulkButton.title,
            help: advancedCopyHelp(
                isFeatureEnabled: bodyBreakEnabled,
                hasText: !ideasText.isEmpty,
                enabledHelp: L10n.tr("prefs.copyIdeasBulkEditorHelp"),
                disabledFeatureHelp: L10n.tr("prefs.copyIdeasBulkEditorDisabledBodyOffHelp"),
                disabledEmptyHelp: L10n.tr("prefs.copyIdeasBulkEditorDisabledEmptyHelp")
            ),
            on: customBodyIdeasCopyBulkButton
        )
        customBodyIdeasRestoreBulkButton.isEnabled = bodyBreakEnabled && customBodyIdeasJSONEditor.string != savedIdeasText
        setTextButtonHelp(
            title: customBodyIdeasRestoreBulkButton.title,
            help: advancedRestoreHelp(
                isFeatureEnabled: bodyBreakEnabled,
                hasUnsavedEditorChanges: customBodyIdeasJSONEditor.string != savedIdeasText,
                enabledHelp: L10n.tr("prefs.restoreIdeasBulkEditorHelp"),
                disabledFeatureHelp: L10n.tr("prefs.restoreIdeasBulkEditorDisabledBodyOffHelp"),
                disabledNoChangesHelp: L10n.tr("prefs.restoreIdeasBulkEditorDisabledNoChangesHelp")
            ),
            on: customBodyIdeasRestoreBulkButton
        )
    }

    private func advancedCopyHelp(
        isFeatureEnabled: Bool,
        hasText: Bool,
        enabledHelp: String,
        disabledFeatureHelp: String,
        disabledEmptyHelp: String
    ) -> String {
        guard isFeatureEnabled else {
            return disabledFeatureHelp
        }
        guard hasText else {
            return disabledEmptyHelp
        }
        return enabledHelp
    }

    private func advancedRestoreHelp(
        isFeatureEnabled: Bool,
        hasUnsavedEditorChanges: Bool,
        enabledHelp: String,
        disabledFeatureHelp: String,
        disabledNoChangesHelp: String
    ) -> String {
        guard isFeatureEnabled else {
            return disabledFeatureHelp
        }
        guard hasUnsavedEditorChanges else {
            return disabledNoChangesHelp
        }
        return enabledHelp
    }

    private func setAdvancedDisclosure(row: NSView?, button: NSButton, expanded: Bool) {
        row?.isHidden = !expanded
        updateDisclosureButton(button, expanded: expanded)
    }

    func controlTextDidChange(_ obj: Notification) {
        if let field = obj.object as? NSSearchField, field === searchField {
            performPreferencesSearch(field.stringValue)
            return
        }
        guard !isLoadingSettings else { return }
        if let field = obj.object as? NSTextField, isAppExclusionDraftControl(field) {
            updateAppExclusionAddRuleButtonState()
            if hasAppExclusionRuleList {
                return
            }
        }
        if let field = obj.object as? NSTextField, field === customBodyTitle {
            updateCustomBodyAddIdeaButtonState()
            if hasCustomBodyIdeaRotation {
                return
            }
        }
        if let field = obj.object as? NSTextField,
           numberInputs.contains(where: { $0.field === field }) {
            updateScheduleSummary()
            updateContextSummary()
        }
        if let field = obj.object as? NSTextField, isMorningPauseSummaryField(field) {
            updateMorningPauseSummary()
        }
        if let field = obj.object as? NSTextField, field === customPreferencesMessage {
            updateAdminMessageLabel(field.stringValue)
        }
        if let field = obj.object as? NSTextField, field === updateFeedURL {
            updateUpdateSourceRestoreButtonState()
        }
        hasPendingTextEditing = true
        markRestoreDefaultsAvailableForPendingPreferenceChange()
        setSaveStatus(.editing)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if let field = obj.object as? NSSearchField, field === searchField {
            return
        }
        if let field = obj.object as? NSTextField {
            syncNumberControls(for: field)
            if isAppExclusionDraftControl(field), hasAppExclusionRuleList {
                updateDependentControlEnablement()
                updateAppExclusionAddRuleButtonState()
                return
            }
            if field === customBodyTitle, hasCustomBodyIdeaRotation {
                return
            }
            if field === updateFeedURL {
                updateUpdateSourceRestoreButtonState()
            }
        }
        hasPendingTextEditing = false
        updateDependentControlEnablement()
        scheduleAutosave()
    }

    func control(_ control: NSControl, textView _: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === searchField,
              commandSelector == #selector(NSResponder.insertNewline(_:)) else {
            return false
        }
        performPreferencesSearch(searchField.stringValue, advances: true, keepsSearchFocused: true)
        return true
    }

    func textDidChange(_ notification: Notification) {
        guard !isLoadingSettings else { return }
        if let editor = notification.object as? NSTextView, editor === customBodyTextEditor {
            updateCustomBodyAddIdeaButtonState()
            if hasCustomBodyIdeaRotation {
                return
            }
        }
        if let editor = notification.object as? NSTextView, editor === customBodyIdeasJSONEditor {
            refreshCustomBodyIdeaList()
            updateAdvancedBulkEditorActionStates()
        }
        if let editor = notification.object as? NSTextView, editor === appExclusionsJSONEditor {
            refreshAppExclusionRuleList()
            updateAppExclusionAddRuleButtonState()
            updateAdvancedBulkEditorActionStates()
        }
        setSaveStatus(.editing)
        markRestoreDefaultsAvailableForPendingPreferenceChange()
        scheduleAutosave()
    }

    func textDidEndEditing(_ notification: Notification) {
        if let editor = notification.object as? NSTextView,
           editor === customBodyTextEditor,
           hasCustomBodyIdeaRotation {
            return
        }
        scheduleAutosave()
    }

    private func scheduleAutosave() {
        guard !isLoadingSettings else { return }
        hasPendingAutosave = true
        autosaveGeneration += 1
        let generation = autosaveGeneration
        autosaveTask?.cancel()
        setSaveStatus(.saving)
        markRestoreDefaultsAvailableForPendingPreferenceChange()
        autosaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            self?.runScheduledAutosave(generation: generation)
        }
    }

    private func runScheduledAutosave(generation: Int) {
        guard generation == autosaveGeneration else { return }
        autosaveTask = nil
        _ = flushPendingAutosave(showAlerts: false, commitTextEditing: false)
    }

    @discardableResult
    func flushPendingAutosave(showAlerts: Bool) -> Bool {
        flushPendingAutosave(showAlerts: showAlerts, commitTextEditing: true)
    }

    @discardableResult
    private func flushPendingAutosave(showAlerts: Bool, commitTextEditing: Bool) -> Bool {
        if commitTextEditing {
            commitPendingTextEditing()
        }
        guard hasPendingAutosave else { return true }
        autosaveGeneration += 1
        autosaveTask?.cancel()
        autosaveTask = nil
        let didSave = saveCurrentSettings(showAlerts: showAlerts)
        hasPendingAutosave = !didSave
        return didSave
    }

    private func commitPendingTextEditing() {
        guard hasPendingTextEditing, !isLoadingSettings else { return }
        syncNumberControlsFromFields()
        updateDependentControlEnablement()
        hasPendingTextEditing = false
        scheduleAutosave()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.makeFirstResponder(nil)
        return flushPendingAutosave(showAlerts: true)
    }

    private func setSaveStatus(_ status: PreferencesSaveStatus, objectName: String? = nil) {
        switch status {
        case .invalid:
            break
        default:
            saveStatusInvalidFieldName = nil
            saveStatusInvalidDetail = nil
        }

        let symbolName: String
        let color: NSColor
        let title: String

        switch status {
        case .ready:
            symbolName = "checkmark.circle"
            color = .secondaryLabelColor
            title = L10n.tr("prefs.autosaveReady")
        case .editing:
            symbolName = "pencil.circle"
            color = .secondaryLabelColor
            title = L10n.tr("prefs.autosaveEditing")
        case .saving:
            symbolName = "arrow.triangle.2.circlepath.circle"
            color = .secondaryLabelColor
            title = L10n.tr("prefs.autosaveSaving")
        case .saved:
            symbolName = "checkmark.circle.fill"
            color = .systemGreen
            title = L10n.tr("prefs.autosaveSaved")
        case .copied:
            symbolName = "doc.on.clipboard"
            color = .systemBlue
            title = objectName.map { L10n.format("prefs.autosaveCopiedField", $0) }
                ?? L10n.tr("prefs.autosaveCopied")
        case .restored:
            symbolName = "arrow.counterclockwise.circle.fill"
            color = .systemBlue
            title = L10n.tr("prefs.autosaveRestored")
        case .invalid:
            symbolName = "exclamationmark.triangle.fill"
            color = .systemOrange
            if let saveStatusInvalidFieldName {
                title = L10n.format("prefs.autosaveInvalidField", saveStatusInvalidFieldName)
            } else {
                title = L10n.tr("prefs.autosaveInvalid")
            }
        }

        saveStatusIcon.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        saveStatusIcon.contentTintColor = color
        saveStatusLabel.stringValue = title
        saveStatusLabel.textColor = color == .secondaryLabelColor ? .secondaryLabelColor : color
        let help = saveStatusInvalidDetail ?? title
        saveStatusIcon.toolTip = help
        saveStatusLabel.toolTip = help
        saveStatusIcon.setAccessibilityLabel(title)
        saveStatusIcon.setAccessibilityHelp(help)
        saveStatusLabel.setAccessibilityLabel(title)
        saveStatusLabel.setAccessibilityHelp(help)
    }

    private func setInvalidSaveStatus(_ error: Error) {
        if let invalid = error as? InvalidAdvancedJSON {
            saveStatusInvalidFieldName = invalid.fieldName
            saveStatusInvalidDetail = invalid.errorDescription
            revealInvalidAdvancedEditor(invalid.editor)
        } else {
            saveStatusInvalidFieldName = nil
            saveStatusInvalidDetail = error.localizedDescription
        }
        setSaveStatus(.invalid)
    }

    private func revealInvalidAdvancedEditor(_ editor: PreferencesAdvancedBulkEditor) {
        preferencesTabView?.selectTabViewItem(withIdentifier: editor.tabIdentifier)

        let textView: NSTextView
        switch editor {
        case .appRules:
            setAdvancedDisclosure(row: appExclusionsJSONRow, button: appExclusionsAdvancedButton, expanded: true)
            textView = appExclusionsJSONEditor
        case .customIdeas:
            setAdvancedDisclosure(row: customBodyIdeasJSONRow, button: customBodyIdeasAdvancedButton, expanded: true)
            textView = customBodyIdeasJSONEditor
        }

        textView.scrollToVisible(textView.bounds)
        window?.makeFirstResponder(textView)
    }

    @objc private func previewSound(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue,
              let popup = soundPopup(for: identifier),
              let soundLabel = soundPreviewLabel(for: identifier) else {
            return
        }
        let volume = min(1, max(0, soundVolumeSlider.doubleValue))
        let option = selectedSoundOption(in: popup)
        guard !isOn(silentNotifications) else {
            showSoundPreviewStatus(L10n.format("prefs.soundPreviewMuted", soundLabel))
            return
        }
        soundPlayer.play(option == .silence ? .silent : .named(option.name, volume: volume))
        let status = option == .silence
            ? L10n.format("prefs.soundPreviewSilence", soundLabel)
            : L10n.format("prefs.soundPreviewPlayed", soundLabel, option.title)
        showSoundPreviewStatus(status)
    }

    private func showSoundPreviewStatus(_ status: String) {
        soundPreviewStatusLabel.stringValue = status
        soundPreviewStatusLabel.toolTip = status
        soundPreviewStatusLabel.setAccessibilityLabel(status)
        soundPreviewStatusLabel.setAccessibilityHelp(status)
        soundPreviewStatusLabel.isHidden = false
    }

    private func clearSoundPreviewStatus() {
        soundPreviewStatusLabel.isHidden = true
        soundPreviewStatusLabel.stringValue = ""
        soundPreviewStatusLabel.toolTip = nil
        soundPreviewStatusLabel.setAccessibilityLabel(nil)
        soundPreviewStatusLabel.setAccessibilityHelp(nil)
    }

    @objc private func chooseLocalImagePressed() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = L10n.tr("prefs.chooseFile")

        if panel.runModal() == .OK, let url = panel.url {
            applyLocalImageURL(url)
        }
    }

    @objc private func clearLocalImagePressed() {
        localImagePath.stringValue = ""
        updateLocalImagePreview()
        updateDependentControlEnablement()
        scheduleAutosave()
    }

    private func applyLocalImageURL(_ url: URL) {
        localImagePath.stringValue = url.standardizedFileURL.path
        updateLocalImagePreview()
        updateDependentControlEnablement()
        scheduleAutosave()
    }

    @objc private func numberStepperChanged(_ sender: NSStepper) {
        guard let input = numberInputs.first(where: { $0.stepper === sender }) else { return }
        let value = Int(sender.doubleValue.rounded())
        input.field.stringValue = String(value)
        input.slider?.doubleValue = Double(value)
        updateDependentControlEnablement()
        scheduleAutosave()
    }

    @objc private func numberSliderChanged(_ sender: NSSlider) {
        guard let input = numberInputs.first(where: { $0.slider === sender }) else { return }
        let value = Int(sender.doubleValue.rounded())
        sender.doubleValue = Double(value)
        input.field.stringValue = String(value)
        input.stepper.doubleValue = Double(value)
        updateDependentControlEnablement()
        scheduleAutosave()
    }

    private func showCannotDisableBothRestsAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.tr("prefs.cannotDisableBothRests")
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func savedAppExclusions() -> [AppExclusionRule] {
        guard let rule = currentAppExclusionRule(id: settings.appExclusions.first?.id ?? UUID().uuidString) else {
            return []
        }
        return [rule]
    }

    private func currentAppExclusionRule(id: String) -> AppExclusionRule? {
        let terms = appExclusionMatchTerms()
        guard isOn(appExclusionEnabled), !terms.isEmpty else { return nil }

        let mode = selected(AppExclusionRule.Mode.self, from: appExclusionMode, fallback: .pauseWhenMatched)
        let name = appExclusionName.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return AppExclusionRule(
            id: id,
            name: name.isEmpty ? defaultAppExclusionRuleName() : name,
            matchTerms: terms,
            mode: mode,
            appliesTo: appExclusionAppliesToSelection(),
            isEnabled: true
        )
    }

    private func appExclusionAppliesToSelection() -> Set<RestKind> {
        var appliesTo: Set<RestKind> = []
        let eyeGateEnabled = isOn(eyeEnabled)
        let bodyBreakEnabled = isOn(bodyEnabled)
        if eyeGateEnabled && isOn(appExclusionAppliesEye) {
            appliesTo.insert(.eyeGate)
        }
        if bodyBreakEnabled && isOn(appExclusionAppliesBody) {
            appliesTo.insert(.bodyBreak)
        }
        if appliesTo.isEmpty {
            if bodyBreakEnabled {
                appliesTo.insert(.bodyBreak)
            } else if eyeGateEnabled {
                appliesTo.insert(.eyeGate)
            }
        }
        return appliesTo
    }

    private func updateAppExclusionTargetGuards(eyeVisible: Bool, bodyVisible: Bool) {
        let eyeSelected = eyeVisible && isOn(appExclusionAppliesEye)
        let bodySelected = bodyVisible && isOn(appExclusionAppliesBody)
        let canToggleEye = eyeVisible && (!eyeSelected || bodySelected)
        let canToggleBody = bodyVisible && (!bodySelected || eyeSelected)
        let help = L10n.tr("prefs.appExclusionNeedsTarget")

        appExclusionAppliesEye.isEnabled = canToggleEye
        appExclusionAppliesBody.isEnabled = canToggleBody
        setOptionalHelp(canToggleEye ? nil : help, on: appExclusionAppliesEye)
        setOptionalHelp(canToggleBody ? nil : help, on: appExclusionAppliesBody)
    }

    private func setDefaultAppExclusionTargets() {
        let eyeGateEnabled = isOn(eyeEnabled)
        let bodyBreakEnabled = isOn(bodyEnabled)
        appExclusionAppliesEye.state = state(eyeGateEnabled && !bodyBreakEnabled)
        appExclusionAppliesBody.state = state(bodyBreakEnabled)
    }

    private func addAppExclusionApplicationCandidate(_ candidate: AppExclusionApplicationCandidate) {
        guard isOn(appExclusionEnabled) else { return }
        let terms = AppExclusionApplicationCandidate.uniqueNonemptyTerms(candidate.terms.map { Optional($0) })
        guard !terms.isEmpty else { return }
        appendAppExclusionRule(AppExclusionRule(
            id: UUID().uuidString,
            name: candidate.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultAppExclusionRuleName() : candidate.name,
            matchTerms: terms,
            mode: selected(AppExclusionRule.Mode.self, from: appExclusionMode, fallback: .pauseWhenMatched),
            appliesTo: appExclusionAppliesToSelection(),
            isEnabled: true
        ))
    }

    private func appendAppExclusionRule(_ rule: AppExclusionRule) {
        saveAppExclusionRule(rule, replacingID: nil)
    }

    private func saveAppExclusionRule(_ rule: AppExclusionRule, replacingID: String?) {
        do {
            clearArmedRemovalState()
            var rules = try decodedAdvancedAppExclusions() ?? []
            if let replacingID,
               let index = rules.firstIndex(where: { $0.id == replacingID }) {
                rules[index] = rule
            } else {
                rules.append(rule)
            }
            appExclusionsJSONEditor.string = encodedAppExclusionsForEditor(rules)
            setAdvancedDisclosure(row: appExclusionsJSONRow, button: appExclusionsAdvancedButton, expanded: false)
            appExclusionName.stringValue = ""
            appExclusionTerms.objectValue = []
            setDefaultAppExclusionTargets()
            clearAppExclusionRuleEditState()
            refreshAppExclusionRuleList()
            updateDependentControlEnablement()
            updateAppExclusionAddRuleButtonState()
            scheduleAutosave()
        } catch {
            showInvalidJSONAlert(error)
            setInvalidSaveStatus(error)
        }
    }

    private func appExclusionMatchTerms() -> [String] {
        AppExclusionApplicationCandidate.uniqueNonemptyTerms(
            tokenFieldValues(appExclusionTerms)
                .flatMap { $0.split(whereSeparator: { $0 == "," || $0 == "\n" }) }
                .map { Optional(String($0)) }
        )
    }

    private func isAppExclusionDraftControl(_ sender: Any) -> Bool {
        if let field = sender as? NSTextField {
            return field === appExclusionName || field === appExclusionTerms
        }
        if let popup = sender as? NSPopUpButton {
            return popup === appExclusionMode
        }
        if let button = sender as? NSButton {
            return button === appExclusionAppliesEye || button === appExclusionAppliesBody
        }
        return false
    }

    private func updateAppExclusionAddRuleButtonState() {
        appExclusionAddRuleButton.isEnabled = isOn(appExclusionEnabled) &&
            currentAppExclusionRule(id: "preview") != nil
        appExclusionCancelEditButton.isEnabled = isOn(appExclusionEnabled)
        updateAppExclusionPreview()
        updateContextSummary()
        updateAppExclusionActionButtonPresentation()
    }

    private func updateAppExclusionPreview() {
        guard isOn(appExclusionEnabled) else {
            appExclusionPreviewLabel.stringValue = ""
            appExclusionPreviewLabel.toolTip = nil
            appExclusionPreviewLabel.setAccessibilityHelp(nil)
            return
        }

        let terms = appExclusionMatchTerms()
        let preview: String
        if terms.isEmpty {
            preview = L10n.tr("prefs.appExclusionPreviewEmpty")
        } else {
            let termSummary = appExclusionTermsSummary(terms, preferredName: appExclusionName.stringValue)
            let targetSummary = appExclusionTargetSummary(appExclusionAppliesToSelection())
            let mode = selected(AppExclusionRule.Mode.self, from: appExclusionMode, fallback: .pauseWhenMatched)
            switch mode {
            case .pauseWhenMatched:
                preview = L10n.format("prefs.appExclusionPreviewPause", termSummary, targetSummary)
            case .resumeOnlyWhenMatched:
                preview = L10n.format("prefs.appExclusionPreviewResumeOnly", termSummary, targetSummary)
            }
        }

        appExclusionPreviewLabel.stringValue = preview
        appExclusionPreviewLabel.toolTip = preview
        appExclusionPreviewLabel.setAccessibilityHelp(preview)
    }

    private func updateAppExclusionActionButtonPresentation() {
        let isEditing = editingAppExclusionRuleID != nil
        let title = isEditing ? L10n.tr("prefs.updateAppExclusionRule") : L10n.tr("prefs.addAppExclusionRule")
        let help = appExclusionActionButtonHelp(isEditing: isEditing)
        appExclusionAddRuleButton.title = title
        appExclusionAddRuleButton.image = NSImage(
            systemSymbolName: isEditing ? "checkmark.circle" : "plus.circle",
            accessibilityDescription: title
        )
        setTextButtonHelp(title: title, help: help, on: appExclusionAddRuleButton)
        appExclusionCancelEditButton.isHidden = !isEditing
    }

    private func appExclusionActionButtonHelp(isEditing: Bool) -> String {
        guard isOn(appExclusionEnabled) else {
            return L10n.tr("prefs.addAppExclusionRuleDisabledOffHelp")
        }
        guard !appExclusionMatchTerms().isEmpty else {
            return L10n.tr("prefs.addAppExclusionRuleDisabledEmptyHelp")
        }
        return isEditing
            ? L10n.tr("prefs.updateAppExclusionRuleHelp")
            : L10n.tr("prefs.addAppExclusionRuleHelp")
    }

    private func clearAppExclusionRuleEditState() {
        editingAppExclusionRuleID = nil
        updateAppExclusionActionButtonPresentation()
    }

    private var hasAppExclusionRuleList: Bool {
        !displayedAppExclusionRules().isEmpty
    }

    private func refreshAppExclusionRuleList() {
        let rules = displayedAppExclusionRules()
        if let armedID = armedAppExclusionRuleRemovalID,
           !rules.contains(where: { $0.id == armedID }) {
            armedAppExclusionRuleRemovalID = nil
        }
        appExclusionRuleRemoveControls.removeAll()
        appExclusionRuleEditControls.removeAll()
        removeArrangedSubviews(from: appExclusionRulesListStack)

        for (index, rule) in rules.enumerated() {
            appExclusionRulesListStack.addArrangedSubview(appExclusionRuleListItem(rule: rule, index: index))
        }

        updateAppExclusionRuleRemoveButtons()
        appExclusionRulesListRow?.isHidden = !isOn(appExclusionEnabled) || rules.isEmpty
        updateContextSummary()
    }

    private func updateContextSummary() {
        let summary = [
            contextIdleSummary(),
            contextFocusSummary(),
            contextWorkingHoursSummary(),
            contextAppRulesSummary()
        ].joined(separator: " ")
        contextSummaryLabel.stringValue = summary
        contextSummaryLabel.toolTip = summary
        contextSummaryLabel.setAccessibilityHelp(summary)
        contextSummaryIcon.image?.accessibilityDescription = summary
        contextSummaryIcon.setAccessibilityHelp(summary)
    }

    private func contextIdleSummary() -> String {
        guard isOn(naturalBreaks) else {
            return L10n.tr("prefs.contextSummary.idleOff")
        }
        return L10n.format("prefs.contextSummary.idleOn", max(1, intValue(naturalIdleMinutes)))
    }

    private func contextFocusSummary() -> String {
        guard isOn(bodyEnabled) else {
            return L10n.tr("prefs.contextSummary.focusUnavailable")
        }
        guard isOn(focusMonitor) else {
            return L10n.tr("prefs.contextSummary.focusOff")
        }
        return isOn(focusDefersBody)
            ? L10n.tr("prefs.contextSummary.focusDefersBody")
            : L10n.tr("prefs.contextSummary.focusObserved")
    }

    private func contextWorkingHoursSummary() -> String {
        guard isOn(workingHoursEnabled) else {
            return L10n.tr("prefs.contextSummary.workingHoursOff")
        }
        let start = Self.timeString(minutes: Self.minutes(
            fromTimePicker: workingStartPicker,
            fallback: settings.workingHours.startMinuteOfDay
        ))
        let end = Self.timeString(minutes: Self.minutes(
            fromTimePicker: workingEndPicker,
            fallback: settings.workingHours.endMinuteOfDay
        ))
        return L10n.format("prefs.contextSummary.workingHoursOn", start, end)
    }

    private func contextAppRulesSummary() -> String {
        guard isOn(appExclusionEnabled) else {
            return L10n.tr("prefs.contextSummary.appRulesOff")
        }
        let count = activeAppExclusionRuleCount()
        guard count > 0 else {
            return L10n.tr("prefs.contextSummary.appRulesEmpty")
        }
        return count == 1
            ? L10n.tr("prefs.contextSummary.appRulesOne")
            : L10n.format("prefs.contextSummary.appRulesMany", count)
    }

    private func activeAppExclusionRuleCount() -> Int {
        let rules = displayedAppExclusionRules()
        if !rules.isEmpty {
            return rules.count
        }
        return currentAppExclusionRule(id: "preview") == nil ? 0 : 1
    }

    private func displayedAppExclusionRules() -> [AppExclusionRule] {
        let raw = appExclusionsJSONEditor.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([AppExclusionRule].self, from: data) else {
            return []
        }
        return decoded.map { rule in
            normalizedAppExclusionRuleForPreferences(rule)
        }.filter { $0.isEnabled && !$0.matchTerms.isEmpty }
    }

    private func appExclusionRuleListItem(rule: AppExclusionRule, index: Int) -> NSView {
        let title = NSTextField(labelWithString: rule.name)
        title.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionRuleTitle.\(index)")
        title.font = .systemFont(ofSize: 12, weight: .medium)
        title.lineBreakMode = .byTruncatingTail
        title.widthAnchor.constraint(equalToConstant: 284).isActive = true

        let body = NSTextField(labelWithString: appExclusionRuleSummary(rule))
        body.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionRuleBody.\(index)")
        body.font = .systemFont(ofSize: 11)
        body.textColor = .secondaryLabelColor
        body.lineBreakMode = .byTruncatingTail
        body.widthAnchor.constraint(equalToConstant: 284).isActive = true

        let textStack = NSStackView(views: [title, body])
        textStack.orientation = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading

        let editButton = NSButton()
        editButton.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionRuleEdit.\(index)")
        editButton.title = ""
        editButton.bezelStyle = .inline
        editButton.isBordered = false
        editButton.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: nil)
        editButton.imagePosition = .imageOnly
        editButton.contentTintColor = .secondaryLabelColor
        setIconOnlyActionHelp(
            label: L10n.tr("prefs.editAppExclusionRule"),
            help: L10n.tr("prefs.editAppExclusionRuleHelp"),
            on: editButton
        )
        editButton.target = self
        editButton.action = #selector(editAppExclusionRulePressed(_:))
        editButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
        editButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
        appExclusionRuleEditControls.append((id: rule.id, button: editButton))

        let removeButton = NSButton()
        removeButton.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionRuleRemove.\(index)")
        removeButton.title = ""
        removeButton.bezelStyle = .inline
        removeButton.isBordered = false
        removeButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        removeButton.imagePosition = .imageOnly
        removeButton.contentTintColor = .secondaryLabelColor
        setIconOnlyActionHelp(
            label: L10n.tr("prefs.removeAppExclusionRule"),
            help: L10n.tr("prefs.removeAppExclusionRuleHelp"),
            on: removeButton
        )
        removeButton.target = self
        removeButton.action = #selector(removeAppExclusionRulePressed(_:))
        removeButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
        removeButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
        appExclusionRuleRemoveControls.append((id: rule.id, button: removeButton))

        let actionStack = NSStackView(views: [editButton, removeButton])
        actionStack.orientation = .horizontal
        actionStack.spacing = 2
        actionStack.alignment = .centerY

        return preferenceListItemRow(
            identifier: "prefs.appExclusionRuleRow.\(index)",
            title: rule.name,
            summary: body.stringValue,
            content: textStack,
            actions: actionStack
        )
    }

    private func appExclusionRuleSummary(_ rule: AppExclusionRule) -> String {
        let terms = appExclusionTermsSummary(rule.matchTerms, preferredName: rule.name)
        let applies = appExclusionTargetSummary(rule.appliesTo)
        let summary: String
        switch rule.mode {
        case .pauseWhenMatched:
            summary = L10n.format("prefs.appExclusionPreviewPause", terms, applies)
        case .resumeOnlyWhenMatched:
            summary = L10n.format("prefs.appExclusionPreviewResumeOnly", terms, applies)
        }
        guard summary.count > 96 else { return summary }
        return "\(summary.prefix(93))…"
    }

    private func appExclusionTermsSummary(_ terms: [String], preferredName: String? = nil) -> String {
        let displayTerms = appExclusionDisplayTerms(terms, preferredName: preferredName)
        let summary = displayTerms.isEmpty ? L10n.tr("prefs.appExclusionNoTerms") : displayTerms.joined(separator: ", ")
        guard summary.count > 80 else { return summary }
        return "\(summary.prefix(77))…"
    }

    private func appExclusionDisplayTerms(_ terms: [String], preferredName: String?) -> [String] {
        let cleanedTerms = AppExclusionApplicationCandidate.uniqueNonemptyTerms(terms.map { Optional($0) })
        let name = preferredName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty,
              cleanedTerms.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else {
            return cleanedTerms
        }
        let extraTerms = cleanedTerms.filter { $0.caseInsensitiveCompare(name) != .orderedSame }
        guard !extraTerms.isEmpty,
              extraTerms.allSatisfy(looksLikeAppIdentifier) else {
            return cleanedTerms
        }
        return [name]
    }

    private func looksLikeAppIdentifier(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("."),
              !trimmed.contains(where: { $0.isWhitespace }) else {
            return false
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private func appExclusionTargetSummary(_ appliesTo: Set<RestKind>) -> String {
        if appliesTo.contains(.eyeGate), appliesTo.contains(.bodyBreak) {
            return L10n.tr("prefs.appExclusionAppliesEyeBody")
        } else if appliesTo.contains(.eyeGate) {
            return L10n.tr("prefs.appExclusionAppliesEye")
        } else if appliesTo.contains(.bodyBreak) {
            return L10n.tr("prefs.appExclusionAppliesBody")
        } else {
            return L10n.tr("prefs.appExclusionAppliesNone")
        }
    }

    private struct InvalidAdvancedJSON: LocalizedError {
        var editor: PreferencesAdvancedBulkEditor
        var underlying: Error

        var fieldName: String {
            editor.fieldName
        }

        var errorDescription: String? {
            L10n.format("prefs.invalidJSONBody", fieldName, underlying.localizedDescription)
        }
    }

    private func showInvalidJSONAlert(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = L10n.tr("prefs.invalidJSONTitle")
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func decodedAdvancedAppExclusions() throws -> [AppExclusionRule]? {
        let raw = appExclusionsJSONEditor.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return nil }
        do {
            return try JSONDecoder()
                .decode([AppExclusionRule].self, from: data)
                .map(normalizedAppExclusionRuleForPreferences)
        } catch {
            throw InvalidAdvancedJSON(editor: .appRules, underlying: error)
        }
    }

    private func encodedAppExclusionsForEditor(_ rules: [AppExclusionRule]) -> String {
        let visibleRules = rules
            .map(normalizedAppExclusionRuleForPreferences)
            .filter { $0.isEnabled && !$0.matchTerms.isEmpty }
        guard !visibleRules.isEmpty,
              let data = try? prettyJSONEncoder().encode(visibleRules),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    private func normalizedAppExclusionRuleForPreferences(_ rule: AppExclusionRule) -> AppExclusionRule {
        AppExclusionRule(
            id: rule.id.isEmpty ? UUID().uuidString : rule.id,
            name: rule.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultAppExclusionRuleName() : rule.name,
            matchTerms: AppExclusionApplicationCandidate.uniqueNonemptyTerms(rule.matchTerms.map { Optional($0) }),
            mode: rule.mode,
            appliesTo: rule.appliesTo.isEmpty ? defaultAppExclusionTargetsForPreferences() : rule.appliesTo,
            isEnabled: rule.isEnabled
        )
    }

    private func defaultAppExclusionTargetsForPreferences() -> Set<RestKind> {
        if isOn(bodyEnabled) {
            return [.bodyBreak]
        }
        if isOn(eyeEnabled) {
            return [.eyeGate]
        }
        return [.eyeGate]
    }

    private func defaultAppExclusionRuleName() -> String {
        L10n.tr("prefs.defaultAppExclusionRuleName")
    }

    private func savedCustomIdeas() -> [RestIdea] {
        guard let idea = currentCustomBodyIdea(id: settings.contentLibrary.customBodyBreakIdeas.first?.id ?? UUID().uuidString) else {
            return []
        }
        return [idea]
    }

    private func currentCustomBodyIdea(id: String) -> RestIdea? {
        let title = customBodyTitle.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = ContentSanitizer.sanitizeRichText(customBodyTextEditor.string)
        guard !title.isEmpty || !body.isEmpty else { return nil }
        return RestIdea(
            id: id,
            kind: .bodyBreak,
            title: title.isEmpty ? defaultCustomBodyIdeaTitle() : title,
            body: body,
            isEnabled: true
        )
    }

    private func defaultCustomBodyIdeaTitle() -> String {
        L10n.tr("prefs.defaultCustomIdeaTitle")
    }

    private func updateCustomBodyAddIdeaButtonState() {
        let bodyBreakEnabled = isOn(bodyEnabled)
        customBodyAddIdeaButton.isEnabled = bodyBreakEnabled &&
            currentCustomBodyIdea(id: "preview") != nil
        customBodyCancelEditButton.isEnabled = bodyBreakEnabled
        updateBodyContentSummary()
        updateCustomBodyActionButtonPresentation()
    }

    private func updateCustomBodyActionButtonPresentation() {
        let isEditing = editingCustomBodyIdeaID != nil
        let title = isEditing ? L10n.tr("prefs.updateCustomIdea") : L10n.tr("prefs.addCustomIdea")
        let help = customBodyActionButtonHelp(isEditing: isEditing)
        customBodyAddIdeaButton.title = title
        customBodyAddIdeaButton.image = NSImage(
            systemSymbolName: isEditing ? "checkmark.circle" : "plus.bubble",
            accessibilityDescription: title
        ) ?? NSImage(systemSymbolName: isEditing ? "checkmark" : "plus.circle", accessibilityDescription: title)
        setTextButtonHelp(title: title, help: help, on: customBodyAddIdeaButton)
        customBodyCancelEditButton.isHidden = !isEditing
    }

    private func customBodyActionButtonHelp(isEditing: Bool) -> String {
        guard isOn(bodyEnabled) else {
            return L10n.tr("prefs.addCustomIdeaDisabledBodyOffHelp")
        }
        guard currentCustomBodyIdea(id: "preview") != nil else {
            return L10n.tr("prefs.addCustomIdeaDisabledEmptyHelp")
        }
        return isEditing ? L10n.tr("prefs.updateCustomIdeaHelp") : L10n.tr("prefs.addCustomIdeaHelp")
    }

    private func clearCustomBodyIdeaEditState() {
        editingCustomBodyIdeaID = nil
        updateCustomBodyActionButtonPresentation()
    }

    private var hasCustomBodyIdeaRotation: Bool {
        !customBodyIdeasJSONEditor.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func refreshCustomBodyIdeaList() {
        let ideas = displayedCustomBodyIdeas()
        if let armedID = armedCustomBodyIdeaRemovalID,
           !ideas.contains(where: { $0.id == armedID }) {
            armedCustomBodyIdeaRemovalID = nil
        }
        customBodyIdeaRemoveControls.removeAll()
        customBodyIdeaEditControls.removeAll()
        removeArrangedSubviews(from: customBodyIdeasListStack)

        for (index, idea) in ideas.enumerated() {
            customBodyIdeasListStack.addArrangedSubview(customBodyIdeaListItem(idea: idea, index: index))
        }

        updateCustomBodyIdeaRemoveButtons()
        customBodyIdeasListRow?.isHidden = !isOn(bodyEnabled) || ideas.isEmpty
        updateBodyContentSummary()
    }

    private func updateBodyContentSummary() {
        guard isOn(bodyEnabled) else {
            bodyContentSummaryLabel.stringValue = ""
            bodyContentSummaryLabel.toolTip = nil
            bodyContentSummaryLabel.setAccessibilityHelp(nil)
            return
        }

        let customCount = activeCustomBodyIdeaCount()
        let baseSummary: String
        if isOn(useBuiltInIdeas) {
            if customCount > 0 {
                baseSummary = L10n.format(
                    "prefs.bodyContentSummaryBuiltInAndCustom",
                    localizedCustomIdeaCount(customCount)
                )
            } else {
                baseSummary = L10n.tr("prefs.bodyContentSummaryBuiltInOnly")
            }
        } else if customCount > 0 {
            baseSummary = L10n.format(
                "prefs.bodyContentSummaryCustomOnly",
                localizedCustomIdeaCount(customCount)
            )
        } else {
            baseSummary = L10n.tr("prefs.bodyContentSummaryFallback")
        }

        let summary: String
        if let imageName = selectedLocalImageName() {
            summary = L10n.format("prefs.bodyContentSummaryWithImage", baseSummary, imageName)
        } else {
            summary = baseSummary
        }
        bodyContentSummaryLabel.stringValue = summary
        bodyContentSummaryLabel.toolTip = summary
        bodyContentSummaryLabel.setAccessibilityHelp(summary)
    }

    private func activeCustomBodyIdeaCount() -> Int {
        let rotationIdeas = displayedCustomBodyIdeas().filter(\.isEnabled)
        if hasCustomBodyIdeaRotation {
            return rotationIdeas.count
        }
        return currentCustomBodyIdea(id: "preview") == nil ? 0 : 1
    }

    private func localizedCustomIdeaCount(_ count: Int) -> String {
        count == 1
            ? L10n.tr("prefs.customIdeaCountOne")
            : L10n.format("prefs.customIdeaCountMany", count)
    }

    private func selectedLocalImageName() -> String? {
        let path = localImagePath.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }
        let name = URL(fileURLWithPath: path).lastPathComponent
        return name.isEmpty ? path : name
    }

    private func displayedCustomBodyIdeas() -> [RestIdea] {
        let raw = customBodyIdeasJSONEditor.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([RestIdea].self, from: data) else {
            return []
        }
        return decoded
            .filter { $0.kind == .bodyBreak }
            .map {
                RestIdea(
                    id: $0.id.isEmpty ? UUID().uuidString : $0.id,
                    kind: .bodyBreak,
                    title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultCustomBodyIdeaTitle() : $0.title,
                    body: ContentSanitizer.sanitizeRichText($0.body),
                    isEnabled: $0.isEnabled
                )
            }
    }

    private func customBodyIdeaListItem(idea: RestIdea, index: Int) -> NSView {
        let title = NSTextField(labelWithString: idea.title)
        title.identifier = NSUserInterfaceItemIdentifier("prefs.customBodyIdeaTitle.\(index)")
        title.font = .systemFont(ofSize: 12, weight: .medium)
        title.lineBreakMode = .byTruncatingTail
        title.widthAnchor.constraint(equalToConstant: 284).isActive = true

        let body = NSTextField(labelWithString: customBodyIdeaBodySummary(idea.body))
        body.identifier = NSUserInterfaceItemIdentifier("prefs.customBodyIdeaBody.\(index)")
        body.font = .systemFont(ofSize: 11)
        body.textColor = .secondaryLabelColor
        body.lineBreakMode = .byTruncatingTail
        body.widthAnchor.constraint(equalToConstant: 284).isActive = true

        let textStack = NSStackView(views: [title, body])
        textStack.orientation = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading

        let editButton = NSButton()
        editButton.identifier = NSUserInterfaceItemIdentifier("prefs.customBodyIdeaEdit.\(index)")
        editButton.title = ""
        editButton.bezelStyle = .inline
        editButton.isBordered = false
        editButton.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: nil)
        editButton.imagePosition = .imageOnly
        editButton.contentTintColor = .secondaryLabelColor
        setIconOnlyActionHelp(
            label: L10n.tr("prefs.editCustomIdea"),
            help: L10n.tr("prefs.editCustomIdeaHelp"),
            on: editButton
        )
        editButton.target = self
        editButton.action = #selector(editCustomBodyIdeaPressed(_:))
        editButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
        editButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
        customBodyIdeaEditControls.append((id: idea.id, button: editButton))

        let removeButton = NSButton()
        removeButton.identifier = NSUserInterfaceItemIdentifier("prefs.customBodyIdeaRemove.\(index)")
        removeButton.title = ""
        removeButton.bezelStyle = .inline
        removeButton.isBordered = false
        removeButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        removeButton.imagePosition = .imageOnly
        removeButton.contentTintColor = .secondaryLabelColor
        setIconOnlyActionHelp(
            label: L10n.tr("prefs.removeCustomIdea"),
            help: L10n.tr("prefs.removeCustomIdeaHelp"),
            on: removeButton
        )
        removeButton.target = self
        removeButton.action = #selector(removeCustomBodyIdeaPressed(_:))
        removeButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
        removeButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
        customBodyIdeaRemoveControls.append((id: idea.id, button: removeButton))

        let actionStack = NSStackView(views: [editButton, removeButton])
        actionStack.orientation = .horizontal
        actionStack.spacing = 2
        actionStack.alignment = .centerY

        return preferenceListItemRow(
            identifier: "prefs.customBodyIdeaRow.\(index)",
            title: idea.title,
            summary: body.stringValue,
            content: textStack,
            actions: actionStack
        )
    }

    private func preferenceListItemRow(
        identifier: String,
        title: String,
        summary: String,
        content: NSView,
        actions: NSView
    ) -> NSStackView {
        let row = NSStackView(views: [content, actions])
        row.identifier = NSUserInterfaceItemIdentifier(identifier)
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        row.edgeInsets = NSEdgeInsets(top: 6, left: 8, bottom: 6, right: 6)
        row.wantsLayer = true
        row.layer?.cornerRadius = 6
        row.layer?.borderWidth = 1
        row.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.42).cgColor
        row.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor
        row.widthAnchor.constraint(equalToConstant: 360).isActive = true
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true

        let help = "\(title). \(summary)"
        row.toolTip = help
        row.setAccessibilityHelp(help)
        return row
    }

    private func customBodyIdeaBodySummary(_ body: String) -> String {
        let collapsed = body
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let summary = collapsed.isEmpty ? L10n.tr("prefs.customIdeaEmptyBody") : collapsed
        guard summary.count > 80 else { return summary }
        return "\(summary.prefix(77))…"
    }

    private func armAppExclusionRuleRemoval(id: String) {
        armedAppExclusionRuleRemovalID = id
        armedCustomBodyIdeaRemovalID = nil
        updateRemovalButtonArmStates()
    }

    private func armCustomBodyIdeaRemoval(id: String) {
        armedCustomBodyIdeaRemovalID = id
        armedAppExclusionRuleRemovalID = nil
        updateRemovalButtonArmStates()
    }

    private func clearArmedRemovalState() {
        guard armedAppExclusionRuleRemovalID != nil ||
              armedCustomBodyIdeaRemovalID != nil else {
            return
        }
        armedAppExclusionRuleRemovalID = nil
        armedCustomBodyIdeaRemovalID = nil
        updateRemovalButtonArmStates()
    }

    private func updateRemovalButtonArmStates() {
        updateAppExclusionRuleRemoveButtons()
        updateCustomBodyIdeaRemoveButtons()
    }

    private func updateAppExclusionRuleRemoveButtons() {
        for control in appExclusionRuleRemoveControls {
            let isArmed = control.id == armedAppExclusionRuleRemovalID
            configureRemoveButton(
                control.button,
                isArmed: isArmed,
                label: L10n.tr("prefs.removeAppExclusionRule"),
                help: isArmed ?
                    L10n.tr("prefs.removeAppExclusionRuleConfirmHelp") :
                    L10n.tr("prefs.removeAppExclusionRuleHelp")
            )
        }
    }

    private func updateCustomBodyIdeaRemoveButtons() {
        for control in customBodyIdeaRemoveControls {
            let isArmed = control.id == armedCustomBodyIdeaRemovalID
            configureRemoveButton(
                control.button,
                isArmed: isArmed,
                label: L10n.tr("prefs.removeCustomIdea"),
                help: isArmed ?
                    L10n.tr("prefs.removeCustomIdeaConfirmHelp") :
                    L10n.tr("prefs.removeCustomIdeaHelp")
            )
        }
    }

    private func configureRemoveButton(
        _ button: NSButton,
        isArmed: Bool,
        label: String,
        help: String
    ) {
        button.image = NSImage(
            systemSymbolName: isArmed ? "trash.fill" : "trash",
            accessibilityDescription: label
        )
        button.contentTintColor = isArmed ? .systemRed : .secondaryLabelColor
        setIconOnlyActionHelp(label: label, help: help, on: button)
    }

    private func removeArrangedSubviews(from stack: NSStackView) {
        for subview in stack.arrangedSubviews {
            stack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
    }

    private func decodedAdvancedCustomIdeas() throws -> [RestIdea]? {
        let raw = customBodyIdeasJSONEditor.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return nil }
        do {
            let decoded = try JSONDecoder().decode([RestIdea].self, from: data)
            return decoded
                .filter { $0.kind == .bodyBreak }
                .map {
                    RestIdea(
                        id: $0.id.isEmpty ? UUID().uuidString : $0.id,
                        kind: .bodyBreak,
                        title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultCustomBodyIdeaTitle() : $0.title,
                        body: ContentSanitizer.sanitizeRichText($0.body),
                        isEnabled: $0.isEnabled
                    )
                }
        } catch {
            throw InvalidAdvancedJSON(editor: .customIdeas, underlying: error)
        }
    }

    private func encodedCustomIdeasForEditor(_ ideas: [RestIdea]) -> String {
        let bodyIdeas = ideas.filter { $0.kind == .bodyBreak }
        guard !bodyIdeas.isEmpty,
              let data = try? prettyJSONEncoder().encode(bodyIdeas),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    private func prettyJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private func savedLocalImagePaths() -> [String] {
        let path = localImagePath.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, URL(string: path)?.scheme == nil else { return [] }
        return [path]
    }

    private func tokenFieldValues(_ tokenField: NSTokenField) -> [String] {
        if let values = tokenField.objectValue as? [String] {
            return values
        }
        if let values = tokenField.objectValue as? [Any] {
            return values.map { String(describing: $0) }
        }
        return tokenField.stringValue.components(separatedBy: CharacterSet(charactersIn: ",\n"))
    }

    private func section(_ title: String, symbolName: String) -> NSStackView {
        section(title, icon: .systemSymbol(symbolName), identifier: nil)
    }

    private func section(
        _ title: String,
        icon: PreferencesSectionIcon,
        identifier: String?
    ) -> NSStackView {
        let imageView = NSImageView()
        switch icon {
        case .restGate:
            imageView.image = RestGateIcon.menuBarImage(accessibilityDescription: title)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            if let identifier {
                imageView.identifier = NSUserInterfaceItemIdentifier("\(identifier).restGateIcon")
            }
        case let .systemSymbol(symbolName):
            imageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
            imageView.symbolConfiguration = .init(pointSize: 16, weight: .semibold)
            if let identifier {
                imageView.identifier = NSUserInterfaceItemIdentifier("\(identifier).systemIcon")
            }
        }
        imageView.contentTintColor = .secondaryLabelColor
        imageView.widthAnchor.constraint(equalToConstant: 22).isActive = true

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        if let identifier {
            label.identifier = NSUserInterfaceItemIdentifier("\(identifier).label")
        }

        let stack = NSStackView(views: [imageView, label])
        if let identifier {
            stack.identifier = NSUserInterfaceItemIdentifier(identifier)
        }
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        return stack
    }

    private func row(_ title: String, _ field: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 220).isActive = true
        let stack = NSStackView(views: [label, field])
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.alignment = .centerY
        return stack
    }

    private func indentedControlRow(_ field: NSView) -> NSStackView {
        let spacer = NSView()
        spacer.widthAnchor.constraint(equalToConstant: 220).isActive = true
        let stack = NSStackView(views: [spacer, field])
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.alignment = .centerY
        return stack
    }

    private func appExclusionTermsPickerRow() -> NSStackView {
        appExclusionTerms.widthAnchor.constraint(equalToConstant: 300).isActive = true
        let stack = NSStackView(views: [appExclusionTerms, appExclusionAddRunningApp])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        return stack
    }

    private func shortcutRow(_ title: String, _ recorder: ShortcutRecorderButton, help: String? = nil) -> NSStackView {
        recorder.actionHelp = help
        let clearButton = NSButton()
        clearButton.title = ""
        clearButton.bezelStyle = .inline
        clearButton.isBordered = false
        clearButton.imagePosition = .imageOnly
        clearButton.target = self
        clearButton.action = #selector(shortcutClearPressed(_:))
        clearButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
        clearButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
        if let identifier = recorder.identifier?.rawValue {
            clearButton.identifier = NSUserInterfaceItemIdentifier("\(identifier).clear")
        }
        shortcutClearControls.append((recorder: recorder, button: clearButton))

        let controls = NSStackView(views: [recorder, clearButton])
        controls.orientation = .horizontal
        controls.spacing = 6
        controls.alignment = .centerY
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 220).isActive = true
        label.toolTip = help
        label.setAccessibilityHelp(help)
        let stack = NSStackView(views: [label, controls])
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.alignment = .centerY
        return stack
    }

    private func multilineRow(_ title: String, _ field: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 220).isActive = true
        let stack = NSStackView(views: [label, field])
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.alignment = .top
        return stack
    }

    private func advancedBulkEditorRow(
        _ title: String,
        guidance: String,
        field: NSView,
        guidanceIdentifier: String,
        actions: [NSButton] = []
    ) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 220).isActive = true

        let guidanceLabel = NSTextField(labelWithString: guidance)
        guidanceLabel.identifier = NSUserInterfaceItemIdentifier(guidanceIdentifier)
        guidanceLabel.font = .systemFont(ofSize: 12)
        guidanceLabel.textColor = .secondaryLabelColor
        guidanceLabel.lineBreakMode = .byWordWrapping
        guidanceLabel.maximumNumberOfLines = 3
        guidanceLabel.widthAnchor.constraint(equalToConstant: 360).isActive = true
        guidanceLabel.toolTip = guidance
        guidanceLabel.setAccessibilityHelp(guidance)

        var fieldViews: [NSView] = [guidanceLabel]
        if !actions.isEmpty {
            let actionStack = NSStackView(views: actions)
            actionStack.identifier = NSUserInterfaceItemIdentifier("\(guidanceIdentifier).actions")
            actionStack.orientation = .horizontal
            actionStack.spacing = 8
            actionStack.alignment = .centerY
            fieldViews.append(actionStack)
        }
        fieldViews.append(field)

        let fieldStack = NSStackView(views: fieldViews)
        fieldStack.orientation = .vertical
        fieldStack.spacing = 6
        fieldStack.alignment = .leading

        let stack = NSStackView(views: [label, fieldStack])
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.alignment = .top
        return stack
    }

    private func numberRow(
        _ title: String,
        _ field: NSTextField,
        unit: String,
        min: Double,
        max: Double,
        identifier: String? = nil,
        showsSlider: Bool = false
    ) -> NSStackView {
        field.alignment = .right
        if let identifier {
            field.identifier = NSUserInterfaceItemIdentifier("\(identifier)Field")
        }

        let stepper = NSStepper()
        if let identifier {
            stepper.identifier = NSUserInterfaceItemIdentifier("\(identifier)Stepper")
        }
        stepper.minValue = min
        stepper.maxValue = max
        stepper.increment = 1
        stepper.target = self
        stepper.action = #selector(numberStepperChanged(_:))

        let slider: NSSlider?
        if showsSlider {
            let control = NSSlider(value: min, minValue: min, maxValue: max, target: self, action: #selector(numberSliderChanged(_:)))
            if let identifier {
                control.identifier = NSUserInterfaceItemIdentifier("\(identifier)Slider")
            }
            control.numberOfTickMarks = 5
            control.allowsTickMarkValuesOnly = false
            control.widthAnchor.constraint(equalToConstant: 160).isActive = true
            slider = control
        } else {
            slider = nil
        }

        numberInputs.append(NumberInput(field: field, stepper: stepper, slider: slider, min: min, max: max))

        let unitLabel = NSTextField(labelWithString: unit)
        unitLabel.textColor = .secondaryLabelColor
        unitLabel.widthAnchor.constraint(equalToConstant: unit.isEmpty ? 0 : 58).isActive = true

        var inputViews: [NSView] = [field, stepper]
        if let slider {
            inputViews.append(slider)
        }
        inputViews.append(unitLabel)

        let inputStack = NSStackView(views: inputViews)
        inputStack.orientation = .horizontal
        inputStack.spacing = 8
        inputStack.alignment = .centerY
        return row(title, inputStack)
    }

    private func soundPickerRow(_ popup: NSPopUpButton, _ previewButton: NSButton) -> NSStackView {
        let stack = NSStackView(views: [popup, previewButton])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        return stack
    }

    private func updateSourceRow() -> NSStackView {
        let stack = NSStackView(views: [updateFeedURL, restoreUpdateSourceButton])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        return stack
    }

    private func soundVolumeRow() -> NSStackView {
        let stack = NSStackView(views: [soundVolumeSlider, soundVolumeValueLabel])
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.alignment = .centerY
        return stack
    }

    private func registerSearchTargets(in stack: NSStackView, tabIdentifier: String) {
        for view in stack.arrangedSubviews {
            let text = searchableText(in: view).joined(separator: " ")
            let normalizedText = Self.normalizedSearchText("\(tabIdentifier) \(text)")
            guard !normalizedText.isEmpty else { continue }
            searchTargets.append(PreferencesSearchTarget(
                tabIdentifier: tabIdentifier,
                title: bestSearchTargetTitle(in: view, fallback: tabIdentifier),
                normalizedText: normalizedText,
                view: view
            ))
        }
    }

    private func searchableText(in view: NSView) -> [String] {
        var texts: [String] = []
        if let button = view as? NSButton, !button.title.isEmpty {
            texts.append(button.title)
        }
        if let popup = view as? NSPopUpButton {
            texts.append(contentsOf: popup.itemArray.map(\.title))
        } else if let label = view as? NSTextField, !label.stringValue.isEmpty {
            texts.append(label.stringValue)
        }
        if let textField = view as? NSTextField,
           let placeholder = textField.placeholderString,
           !placeholder.isEmpty {
            texts.append(placeholder)
        }
        if let tooltip = view.toolTip, !tooltip.isEmpty {
            texts.append(tooltip)
        }
        if let help = view.accessibilityHelp(), !help.isEmpty {
            texts.append(help)
        }
        for subview in view.subviews {
            texts.append(contentsOf: searchableText(in: subview))
        }
        return Self.uniqueSearchTexts(texts)
    }

    private static func uniqueSearchTexts(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in values {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            result.append(normalized)
        }
        return result
    }

    private func bestSearchTargetTitle(in view: NSView, fallback: String) -> String {
        searchableText(in: view).first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? fallback
    }

    @objc private func preferencesSearchChanged(_ sender: NSSearchField) {
        performPreferencesSearch(sender.stringValue, keepsSearchFocused: true)
    }

    private func performPreferencesSearch(
        _ query: String,
        advances: Bool = false,
        keepsSearchFocused: Bool = false
    ) {
        let normalizedQuery = Self.normalizedSearchText(query)
        let previousQuery = currentSearchQuery
        let previousTargetView = currentSearchTargetView
        clearHighlightedSearchTarget()
        guard !normalizedQuery.isEmpty else {
            currentSearchQuery = ""
            currentSearchMatchIndex = nil
            currentSearchTargetView = nil
            setSearchStatus("", hidden: true)
            return
        }

        let allMatches = searchTargets.filter {
            $0.normalizedText.contains(normalizedQuery)
        }
        let revealedTargetView = revealFirstCollapsedSearchTarget(in: allMatches)
        var matches = allMatches.filter {
            isSearchTargetVisible($0.view)
        }
        if let revealedTargetView,
           !matches.contains(where: { $0.view === revealedTargetView }),
           let revealedTarget = searchTargets.first(where: { $0.view === revealedTargetView }) {
            matches.append(revealedTarget)
        }

        guard !matches.isEmpty else {
            currentSearchQuery = normalizedQuery
            currentSearchMatchIndex = nil
            currentSearchTargetView = nil
            let statusKey = allMatches.isEmpty ? "prefs.searchNoResults" : "prefs.searchHiddenResults"
            setSearchStatus(
                L10n.format(
                    statusKey,
                    query.trimmingCharacters(in: .whitespacesAndNewlines)
                ),
                color: .systemOrange
            )
            return
        }

        let targetIndex: Int
        if advances,
           normalizedQuery == previousQuery,
           let currentSearchMatchIndex {
            targetIndex = (currentSearchMatchIndex + 1) % matches.count
        } else if advances,
                  normalizedQuery == previousQuery,
                  let previousTargetView,
                  let previousIndex = matches.firstIndex(where: { $0.view === previousTargetView }) {
            targetIndex = (previousIndex + 1) % matches.count
        } else if let revealedTargetView,
                  let revealedIndex = matches.firstIndex(where: { $0.view === revealedTargetView }) {
            targetIndex = revealedIndex
        } else {
            targetIndex = 0
        }
        let target = matches[targetIndex]
        currentSearchQuery = normalizedQuery
        currentSearchMatchIndex = targetIndex
        currentSearchTargetView = target.view

        preferencesTabView?.selectTabViewItem(withIdentifier: target.tabIdentifier)
        target.view.scrollToVisible(target.view.bounds)
        highlightSearchTarget(target.view)
        if keepsSearchFocused {
            focusSearchFieldIfNeeded()
        } else {
            focusSearchTarget(target.view)
        }
        setSearchStatus(searchStatusText(
            target: target,
            index: targetIndex,
            count: matches.count
        ))
    }

    private func setSearchStatus(
        _ text: String,
        color: NSColor = .secondaryLabelColor,
        hidden: Bool = false
    ) {
        searchStatusLabel.stringValue = text
        searchStatusLabel.textColor = color
        searchStatusLabel.isHidden = hidden
        let help = hidden || text.isEmpty ? nil : text
        searchStatusLabel.toolTip = help
        searchStatusLabel.setAccessibilityHelp(help)
    }

    private func searchStatusText(target: PreferencesSearchTarget, index: Int, count: Int) -> String {
        guard count > 1 else {
            return L10n.format("prefs.searchMatched", target.tabIdentifier, target.title)
        }
        return L10n.format("prefs.searchMatchedIndexed", index + 1, count, target.tabIdentifier, target.title)
    }

    private static func normalizedSearchText(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func isSearchTargetVisible(_ view: NSView) -> Bool {
        var current: NSView? = view
        while let candidate = current {
            if candidate.isHidden { return false }
            current = candidate.superview
        }
        return true
    }

    private func revealFirstCollapsedSearchTarget(in targets: [PreferencesSearchTarget]) -> NSView? {
        for target in targets {
            if let revealedView = revealCollapsedSearchDisclosureTarget(target.view) {
                return revealedView
            }
            if !isSearchTargetVisible(target.view),
               revealCollapsedSearchContainer(containing: target.view) {
                return target.view
            }
        }
        return nil
    }

    private func revealCollapsedSearchDisclosureTarget(_ view: NSView) -> NSView? {
        if view === appExclusionsAdvancedButton,
           appExclusionsJSONRow?.isHidden == true,
           !appExclusionsAdvancedButton.isHidden {
            setAdvancedDisclosure(
                row: appExclusionsJSONRow,
                button: appExclusionsAdvancedButton,
                expanded: true
            )
            return appExclusionsJSONRow
        }

        if view === customBodyIdeasAdvancedButton,
           customBodyIdeasJSONRow?.isHidden == true,
           !customBodyIdeasAdvancedButton.isHidden {
            setAdvancedDisclosure(
                row: customBodyIdeasJSONRow,
                button: customBodyIdeasAdvancedButton,
                expanded: true
            )
            return customBodyIdeasJSONRow
        }

        if view === adminControlsAdvancedButton,
           adminControlsStack.isHidden,
           !adminControlsAdvancedButton.isHidden {
            setAdvancedDisclosure(
                row: adminControlsStack,
                button: adminControlsAdvancedButton,
                expanded: true
            )
            return adminControlsStack
        }

        if view === updateSourceAdvancedButton,
           updateFeedURLRow?.isHidden == true,
           !updateSourceAdvancedButton.isHidden {
            setAdvancedDisclosure(
                row: updateFeedURLRow,
                button: updateSourceAdvancedButton,
                expanded: true
            )
            return updateFeedURLRow
        }

        return nil
    }

    private func revealCollapsedSearchContainer(containing view: NSView) -> Bool {
        if viewIsDescendantOrEqual(view, of: appExclusionsJSONRow),
           !appExclusionsAdvancedButton.isHidden {
            setAdvancedDisclosure(
                row: appExclusionsJSONRow,
                button: appExclusionsAdvancedButton,
                expanded: true
            )
            return true
        }

        if viewIsDescendantOrEqual(view, of: customBodyIdeasJSONRow),
           !customBodyIdeasAdvancedButton.isHidden {
            setAdvancedDisclosure(
                row: customBodyIdeasJSONRow,
                button: customBodyIdeasAdvancedButton,
                expanded: true
            )
            return true
        }

        if viewIsDescendantOrEqual(view, of: adminControlsStack),
           !adminControlsAdvancedButton.isHidden {
            setAdvancedDisclosure(
                row: adminControlsStack,
                button: adminControlsAdvancedButton,
                expanded: true
            )
            return true
        }

        if viewIsDescendantOrEqual(view, of: updateFeedURLRow),
           !updateSourceAdvancedButton.isHidden {
            setAdvancedDisclosure(
                row: updateFeedURLRow,
                button: updateSourceAdvancedButton,
                expanded: true
            )
            return true
        }

        return false
    }

    private func viewIsDescendantOrEqual(_ view: NSView, of container: NSView?) -> Bool {
        guard let container else { return false }
        var current: NSView? = view
        while let candidate = current {
            if candidate === container {
                return true
            }
            current = candidate.superview
        }
        return false
    }

    private func highlightSearchTarget(_ view: NSView) {
        highlightedSearchTarget = PreferencesHighlightSnapshot(
            view: view,
            wantsLayer: view.wantsLayer,
            backgroundColor: view.layer?.backgroundColor,
            borderColor: view.layer?.borderColor,
            borderWidth: view.layer?.borderWidth ?? 0,
            cornerRadius: view.layer?.cornerRadius ?? 0
        )
        view.wantsLayer = true
        view.layer?.cornerRadius = 7
        view.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.14).cgColor
        view.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.36).cgColor
        view.layer?.borderWidth = 1
    }

    private func clearHighlightedSearchTarget() {
        guard let highlightedSearchTarget,
              let view = highlightedSearchTarget.view else {
            self.highlightedSearchTarget = nil
            return
        }
        view.layer?.backgroundColor = highlightedSearchTarget.backgroundColor
        view.layer?.borderColor = highlightedSearchTarget.borderColor
        view.layer?.borderWidth = highlightedSearchTarget.borderWidth
        view.layer?.cornerRadius = highlightedSearchTarget.cornerRadius
        view.wantsLayer = highlightedSearchTarget.wantsLayer
        self.highlightedSearchTarget = nil
    }

    private func focusSearchTarget(_ view: NSView) {
        guard let focusView = firstFocusableSearchTarget(in: view) else { return }
        window?.makeFirstResponder(focusView)
        if let textField = focusView as? NSTextField, textField.isEditable {
            textField.selectText(nil)
        }
    }

    private func firstFocusableSearchTarget(in view: NSView) -> NSView? {
        guard !view.isHidden else { return nil }

        if let textView = view as? NSTextView,
           textView.isEditable {
            return textView
        }

        if let textField = view as? NSTextField,
           textField.isEnabled,
           textField.isEditable {
            return textField
        }

        if let shortcutRecorder = view as? ShortcutRecorderButton,
           shortcutRecorder.isEnabled {
            return shortcutRecorder
        }

        if let popup = view as? NSPopUpButton,
           popup.isEnabled {
            return popup
        }

        if let colorWell = view as? NSColorWell,
           colorWell.isEnabled {
            return colorWell
        }

        if let button = view as? NSButton,
           button.isEnabled,
           button.action != nil {
            return button
        }

        for subview in view.subviews {
            if let focusTarget = firstFocusableSearchTarget(in: subview) {
                return focusTarget
            }
        }
        return nil
    }

    func focusPreferencesSearch() {
        window?.makeFirstResponder(searchField)
        searchField.selectText(nil)
    }

    func clearPreferencesSearchIfFocused() -> Bool {
        guard isSearchFieldFocused() else { return false }
        guard !searchField.stringValue.isEmpty || !searchStatusLabel.isHidden || highlightedSearchTarget != nil else {
            window?.makeFirstResponder(nil)
            return true
        }
        searchField.stringValue = ""
        performPreferencesSearch("")
        return true
    }

    private func isSearchFieldFocused() -> Bool {
        guard let window else { return false }
        if window.firstResponder === searchField {
            return true
        }
        if let editor = searchField.currentEditor(), window.firstResponder === editor {
            return true
        }
        return false
    }

    private func focusSearchFieldIfNeeded() {
        guard !isSearchFieldFocused() else { return }
        window?.makeFirstResponder(searchField)
    }

    private func localImagePickerRow() -> NSStackView {
        let controls = NSStackView(views: [localImageChooseButton, localImageClearButton])
        controls.orientation = .horizontal
        controls.spacing = 8
        controls.alignment = .centerY

        let preview = NSStackView(views: [localImagePreview, localImagePreviewLabel])
        preview.orientation = .horizontal
        preview.spacing = 10
        preview.alignment = .centerY

        let stack = NSStackView(views: [preview, controls])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        return stack
    }

    private func updateLocalImagePreview() {
        let path = localImagePath.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            localImagePreview.image = NSImage(
                systemSymbolName: "photo",
                accessibilityDescription: L10n.tr("prefs.imagePreviewEmpty")
            )
            localImagePreview.contentTintColor = .tertiaryLabelColor
            setLocalImagePreviewLabel(
                L10n.tr("prefs.imagePreviewEmpty"),
                help: L10n.tr("prefs.imageDropHelp")
            )
            return
        }

        let url = URL(fileURLWithPath: path)
        guard let image = NSImage(contentsOfFile: path) else {
            let description = L10n.format("prefs.imagePreviewUnavailable", url.lastPathComponent)
            localImagePreview.image = NSImage(
                systemSymbolName: "exclamationmark.triangle",
                accessibilityDescription: description
            )
            localImagePreview.contentTintColor = .systemOrange
            setLocalImagePreviewLabel(description, help: path)
            return
        }

        image.accessibilityDescription = url.lastPathComponent
        localImagePreview.image = image
        localImagePreview.contentTintColor = nil
        setLocalImagePreviewLabel(url.lastPathComponent, help: path)
    }

    private func setLocalImagePreviewLabel(_ text: String, help: String) {
        localImagePreviewLabel.stringValue = text
        localImagePreviewLabel.toolTip = help
        localImagePreviewLabel.setAccessibilityHelp(help)
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func configurePopup(_ popup: NSPopUpButton, options: [(rawValue: String, title: String)]) {
        popup.removeAllItems()
        for option in options {
            popup.addItem(withTitle: option.title)
            popup.lastItem?.representedObject = option.rawValue
        }
    }

    private func configureSunriseLocationPopup() {
        pauseUntilMorningLocation.removeAllItems()
        for preset in SunriseLocationPreset.presets {
            pauseUntilMorningLocation.addItem(withTitle: preset.title)
            pauseUntilMorningLocation.lastItem?.representedObject = preset.id
        }
        pauseUntilMorningLocation.menu?.addItem(.separator())
        pauseUntilMorningLocation.addItem(withTitle: L10n.tr("prefs.sunriseLocation.custom"))
        pauseUntilMorningLocation.lastItem?.representedObject = SunriseLocationPreset.customID
    }

    private func state(_ value: Bool) -> NSControl.StateValue {
        value ? .on : .off
    }

    private func isOn(_ button: NSButton) -> Bool {
        button.state == .on
    }

    private func intValue(_ field: NSTextField) -> Int {
        Int(field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private func syncNumberControlsFromFields() {
        numberInputs.forEach { syncNumberControls(for: $0.field) }
    }

    private func syncNumberControls(for field: NSTextField) {
        guard let input = numberInputs.first(where: { $0.field === field }) else { return }
        let value = min(input.max, max(input.min, Double(intValue(field))))
        input.stepper.doubleValue = value
        input.slider?.doubleValue = value
        field.stringValue = String(Int(value.rounded()))
    }

    private func doubleValue(_ field: NSTextField, fallback: Double) -> Double {
        Double(field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? fallback
    }

    private func selectSunriseLocationForCurrentSettings() {
        let latitude = settings.operations.pauseUntilMorningLatitude
        let longitude = settings.operations.pauseUntilMorningLongitude
        if let preset = SunriseLocationPreset.matching(latitude: latitude, longitude: longitude) {
            selectPopup(pauseUntilMorningLocation, rawValue: preset.id)
            applySunriseLocationPreset(preset)
            return
        }

        if settings.operations.resolvedPauseUntilMorningMode == .sunrise,
           areSunriseCoordinatesUnset(latitude: latitude, longitude: longitude),
           let preset = SunriseLocationPreset.defaultForCurrentTimeZone() {
            selectPopup(pauseUntilMorningLocation, rawValue: preset.id)
            applySunriseLocationPreset(preset)
            return
        }

        selectPopup(pauseUntilMorningLocation, rawValue: SunriseLocationPreset.customID)
    }

    private func applyDefaultSunriseLocationIfNeeded() {
        guard selected(MorningPauseMode.self, from: pauseUntilMorningMode, fallback: .hour) == .sunrise,
              selectedSunriseLocationPreset() == nil,
              areSunriseCoordinatesUnset(
                  latitude: doubleValue(pauseUntilMorningLatitude, fallback: 0),
                  longitude: doubleValue(pauseUntilMorningLongitude, fallback: 0)
              ),
              let preset = SunriseLocationPreset.defaultForCurrentTimeZone() else {
            return
        }
        selectPopup(pauseUntilMorningLocation, rawValue: preset.id)
        applySunriseLocationPreset(preset)
    }

    private func applySelectedSunriseLocationPreset() {
        guard let preset = selectedSunriseLocationPreset() else { return }
        applySunriseLocationPreset(preset)
    }

    private func selectedSunriseLocationPreset() -> SunriseLocationPreset? {
        guard let id = pauseUntilMorningLocation.selectedItem?.representedObject as? String,
              id != SunriseLocationPreset.customID else {
            return nil
        }
        return SunriseLocationPreset.presets.first { $0.id == id }
    }

    private func applySunriseLocationPreset(_ preset: SunriseLocationPreset) {
        pauseUntilMorningLatitude.stringValue = formattedCoordinate(preset.latitude)
        pauseUntilMorningLongitude.stringValue = formattedCoordinate(preset.longitude)
    }

    private func updateMorningPauseSummary() {
        let ruleSummary: String
        switch selected(MorningPauseMode.self, from: pauseUntilMorningMode, fallback: .hour) {
        case .hour:
            let hour = min(23, max(0, intValue(pauseUntilMorningHour)))
            ruleSummary = L10n.format("prefs.morningSummary.hour", formattedMorningHour(hour))
        case .sunrise:
            if let preset = selectedSunriseLocationPreset() {
                ruleSummary = L10n.format("prefs.morningSummary.sunrisePreset", preset.title)
            } else {
                ruleSummary = L10n.format(
                    "prefs.morningSummary.sunriseCustom",
                    formattedCoordinate(min(89.8, max(-89.8, doubleValue(pauseUntilMorningLatitude, fallback: 0)))),
                    formattedCoordinate(normalizedLongitude(doubleValue(pauseUntilMorningLongitude, fallback: 0)))
                )
            }
        }
        let summary = L10n.format(
            "prefs.morningSummary.withEstimate",
            ruleSummary,
            formattedMorningPauseTarget(pauseUntilMorningTargetDate())
        )
        pauseUntilMorningSummaryLabel.stringValue = summary
        pauseUntilMorningSummaryLabel.toolTip = summary
        pauseUntilMorningSummaryLabel.setAccessibilityHelp(summary)
    }

    private func pauseUntilMorningTargetDate() -> Date {
        let now = nowProvider()
        let mode = selected(MorningPauseMode.self, from: pauseUntilMorningMode, fallback: .hour)
        let hour = min(23, max(0, intValue(pauseUntilMorningHour)))
        let latitude: Double?
        let longitude: Double?
        if let preset = selectedSunriseLocationPreset() {
            latitude = preset.latitude
            longitude = preset.longitude
        } else {
            latitude = min(89.8, max(-89.8, doubleValue(pauseUntilMorningLatitude, fallback: 0)))
            longitude = normalizedLongitude(doubleValue(pauseUntilMorningLongitude, fallback: 0))
        }
        let interval = OperationsSettings.secondsUntilMorning(
            from: now,
            morningHour: hour,
            mode: mode,
            latitude: latitude,
            longitude: longitude
        )
        return now.addingTimeInterval(interval)
    }

    private func formattedMorningPauseTarget(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func updateBodyDisplaySummary(
        coversAllDisplays: Bool,
        coveredDisplay: DisplaySelection,
        contentDisplay: DisplaySelection,
        blanksDisplaysWithoutContent: Bool
    ) {
        let coverage = coversAllDisplays
            ? L10n.tr("prefs.bodyDisplaySummary.coverAll")
            : L10n.format("prefs.bodyDisplaySummary.coverOne", displaySelectionTitle(coveredDisplay))
        let content: String
        switch contentDisplay {
        case .all:
            content = L10n.tr("prefs.bodyDisplaySummary.contentAll")
        case .none:
            content = L10n.tr("prefs.bodyDisplaySummary.contentNone")
        case .primary, .cursor, .configured:
            let display = displaySelectionTitle(contentDisplay)
            content = blanksDisplaysWithoutContent
                ? L10n.format("prefs.bodyDisplaySummary.contentTargetBlank", display)
                : L10n.format("prefs.bodyDisplaySummary.contentTargetMirrored", display)
        }
        let summary = "\(coverage) \(content)"
        bodyDisplaySummaryLabel.stringValue = summary
        bodyDisplaySummaryLabel.toolTip = summary
        bodyDisplaySummaryLabel.setAccessibilityHelp(summary)
    }

    private func displaySelectionTitle(_ selection: DisplaySelection) -> String {
        switch selection {
        case .none:
            return L10n.tr("prefs.display.none")
        case .all:
            return L10n.tr("prefs.display.all")
        case .primary:
            return L10n.tr("prefs.display.primary")
        case .cursor:
            return L10n.tr("prefs.display.cursor")
        case .configured:
            return selectedConfiguredDisplaySummaryTitle()
        }
    }

    private func selectedConfiguredDisplaySummaryTitle() -> String {
        guard let index = selectedConfiguredDisplayIndex() else {
            return L10n.tr("prefs.display.configured")
        }
        return L10n.format("prefs.bodyDisplaySummary.configuredDisplay", index + 1)
    }

    private func isMorningPauseSummaryField(_ field: NSTextField) -> Bool {
        field === pauseUntilMorningHour ||
            field === pauseUntilMorningLatitude ||
            field === pauseUntilMorningLongitude
    }

    private func formattedMorningHour(_ hour: Int) -> String {
        String(format: "%02d:00", min(23, max(0, hour)))
    }

    private func areSunriseCoordinatesUnset(latitude: Double?, longitude: Double?) -> Bool {
        abs(latitude ?? 0) < 0.0001 && abs(longitude ?? 0) < 0.0001
    }

    private func formattedCoordinate(_ value: Double) -> String {
        String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private func hexString(from color: NSColor, fallback: String) -> String {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return fallback }
        let red = min(255, max(0, Int(round(rgb.redComponent * 255))))
        let green = min(255, max(0, Int(round(rgb.greenComponent * 255))))
        let blue = min(255, max(0, Int(round(rgb.blueComponent * 255))))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    private func normalizedHex(_ raw: String, fallback: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = value.hasPrefix("#") ? value : "#\(value)"
        return candidate.range(of: #"^#[0-9a-fA-F]{6}$"#, options: .regularExpression) == nil ? fallback : candidate
    }

    private func normalizedLongitude(_ longitude: Double) -> Double {
        var value = longitude.truncatingRemainder(dividingBy: 360)
        if value > 180 {
            value -= 360
        } else if value < -180 {
            value += 360
        }
        return value
    }

    private func updateSoundVolumeLabel() {
        let value = min(1, max(0, soundVolumeSlider.doubleValue))
        let percentage = "\(Int(round(value * 100)))%"
        let help = L10n.format("prefs.soundVolumeValueHelp", percentage)
        soundVolumeValueLabel.stringValue = percentage
        soundVolumeValueLabel.toolTip = help
        soundVolumeValueLabel.setAccessibilityLabel(percentage)
        soundVolumeValueLabel.setAccessibilityHelp(help)
        soundVolumeSlider.setAccessibilityValue(percentage as NSString)
    }

    private func selected<T: RawRepresentable>(_ type: T.Type, from popup: NSPopUpButton, fallback: T) -> T where T.RawValue == String {
        if let rawValue = popup.selectedItem?.representedObject as? String,
           let value = T(rawValue: rawValue) {
            return value
        }
        return fallback
    }

    private func selectPopup(_ popup: NSPopUpButton, rawValue: String) {
        guard let item = popup.itemArray.first(where: { ($0.representedObject as? String) == rawValue }) else {
            popup.selectItem(at: 0)
            return
        }
        popup.select(item)
    }

    private func configureConfiguredDisplayPopup(selectedIndex: Int) {
        bodyConfiguredDisplay.removeAllItems()
        let screens = NSScreen.screens
        let primaryDisplayID = screens.first?.displayID
        for (index, screen) in screens.enumerated() {
            bodyConfiguredDisplay.addItem(
                withTitle: configuredDisplayTitle(
                    index: index,
                    screen: screen,
                    isPrimary: screen.displayID == primaryDisplayID
                )
            )
            bodyConfiguredDisplay.lastItem?.representedObject = index
        }

        if screens.isEmpty {
            bodyConfiguredDisplay.addItem(withTitle: L10n.format("prefs.displayPicker.unavailable", selectedIndex + 1))
            bodyConfiguredDisplay.lastItem?.representedObject = max(0, selectedIndex)
        } else if !screens.indices.contains(selectedIndex) {
            bodyConfiguredDisplay.addItem(withTitle: L10n.format("prefs.displayPicker.unavailable", selectedIndex + 1))
            bodyConfiguredDisplay.lastItem?.representedObject = selectedIndex
        }

        selectConfiguredDisplayIndex(selectedIndex)
    }

    private func configuredDisplayTitle(index: Int, screen: NSScreen, isPrimary: Bool) -> String {
        let suffix = isPrimary ? L10n.tr("prefs.displayPicker.primarySuffix") : ""
        return L10n.format(
            "prefs.displayPicker.item",
            index + 1,
            Int(screen.frame.width.rounded()),
            Int(screen.frame.height.rounded()),
            suffix
        )
    }

    private func selectConfiguredDisplayIndex(_ index: Int) {
        guard let item = bodyConfiguredDisplay.itemArray.first(where: { ($0.representedObject as? Int) == index }) else {
            bodyConfiguredDisplay.selectItem(at: 0)
            return
        }
        bodyConfiguredDisplay.select(item)
    }

    private func selectedConfiguredDisplayIndex() -> Int? {
        bodyConfiguredDisplay.selectedItem?.representedObject as? Int
    }

    private func selectLanguageOption(_ option: LanguageOption) {
        guard let item = languageIdentifier.itemArray.first(where: { ($0.representedObject as? String) == option.popupValue }) else {
            languageIdentifier.selectItem(at: 0)
            return
        }
        languageIdentifier.select(item)
    }

    private func selectedLanguageOption() -> LanguageOption {
        LanguageOption(popupValue: languageIdentifier.selectedItem?.representedObject as? String)
    }

    private func soundPolicy(from popup: NSPopUpButton, volume: Double) -> SoundPolicy {
        let option = selectedSoundOption(in: popup)
        return option == .silence ? .silent : .named(option.name, volume: volume)
    }

    private func soundName(_ policy: SoundPolicy) -> String {
        switch policy {
        case .silent:
            "silence"
        case .named(let name, _):
            name
        }
    }

    private func preferredSoundVolume() -> Double {
        [
            settings.eyeGate.startSound,
            settings.eyeGate.finishSound,
            settings.bodyBreak.startSound,
            settings.bodyBreak.finishSound
        ]
        .compactMap { policy -> Double? in
            guard case .named(_, let volume) = policy else { return nil }
            return volume
        }
        .first ?? 1
    }

    private func selectSoundOption(_ option: SoundOption, in popup: NSPopUpButton) {
        if popup.itemArray.contains(where: { ($0.representedObject as? String) == option.name }) == false {
            popup.addItem(withTitle: option.title)
            popup.lastItem?.representedObject = option.name
        }

        guard let item = popup.itemArray.first(where: { ($0.representedObject as? String) == option.name }) else {
            popup.selectItem(at: 0)
            return
        }
        popup.select(item)
    }

    private func selectedSoundOption(in popup: NSPopUpButton) -> SoundOption {
        SoundOption(name: popup.selectedItem?.representedObject as? String ?? "silence")
    }

    private func isSoundPopup(_ popup: NSPopUpButton) -> Bool {
        [eyeStartSound, eyeFinishSound, bodyStartSound, bodyFinishSound].contains { $0 === popup }
    }

    private func soundPopup(for identifier: String?) -> NSPopUpButton? {
        switch identifier {
        case "eyeStart":
            eyeStartSound
        case "eyeFinish":
            eyeFinishSound
        case "bodyStart":
            bodyStartSound
        case "bodyFinish":
            bodyFinishSound
        default:
            nil
        }
    }

    private func soundPreviewLabel(for identifier: String?) -> String? {
        switch identifier {
        case "eyeStart":
            L10n.tr("prefs.eyeStartSound")
        case "eyeFinish":
            L10n.tr("prefs.eyeFinishSound")
        case "bodyStart":
            L10n.tr("prefs.bodyStartSound")
        case "bodyFinish":
            L10n.tr("prefs.bodyFinishSound")
        default:
            nil
        }
    }

    private static func timeString(minutes: Int) -> String {
        let hour = minutes / 60
        let minute = minutes % 60
        return String(format: "%02d:%02d", hour, minute)
    }

    private static func dateForTimePicker(minutes: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar.current
        components.year = 2001
        components.month = 1
        components.day = 1
        components.hour = minutes / 60
        components.minute = minutes % 60
        return components.date ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    private static func minutes(fromTimePicker picker: NSDatePicker, fallback: Int) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: picker.dateValue)
        guard let hour = components.hour,
              let minute = components.minute,
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return fallback
        }
        return hour * 60 + minute
    }

    private static func minutes(fromTimeString value: String, fallback: Int) -> Int {
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return fallback
        }
        return hour * 60 + minute
    }
}

@MainActor
final class ShortcutRecorderButton: NSButton {
    var shortcutValue: String = "" {
        didSet {
            if !isRecording {
                if restoreRequiredFallbackIfNeeded() {
                    return
                }
                updateDisplay()
            }
        }
    }
    var validationWarning: String? {
        didSet {
            if !isRecording {
                updateDisplay()
            }
        }
    }
    var actionHelp: String? {
        didSet {
            if !isRecording {
                updateDisplay()
            }
        }
    }
    var displayValue: String {
        ShortcutDisplay.string(shortcutValue)
    }
    var requiredFallbackShortcutValue: String? {
        didSet {
            if !isRecording,
               !restoreRequiredFallbackIfNeeded() {
                updateDisplay()
            }
        }
    }
    var onChange: (() -> Void)?
    private var isRecording = false

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setButtonType(.momentaryPushIn)
        bezelStyle = .rounded
        imagePosition = .imageLeading
        target = self
        action = #selector(beginRecording)
        updateDisplay()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            isRecording = false
            updateDisplay()
        }
        return super.resignFirstResponder()
    }

    @objc private func beginRecording() {
        isRecording = true
        applyDisplayState(.recording)
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        switch Int(event.keyCode) {
        case kVK_Escape:
            finishRecording(didChange: false)
        case kVK_Delete, kVK_ForwardDelete:
            shortcutValue = requiredFallbackShortcutValue ?? ""
            finishRecording(didChange: true)
        default:
            guard let shortcut = Self.shortcutString(from: event) else {
                NSSound.beep()
                showRejectedRecordingInput()
                return
            }
            shortcutValue = shortcut
            finishRecording(didChange: true)
        }
    }

    private func finishRecording(didChange: Bool) {
        isRecording = false
        updateDisplay()
        window?.makeFirstResponder(nil)
        if didChange {
            onChange?()
        }
    }

    private func showRejectedRecordingInput() {
        applyDisplayState(.recordingRejected)
    }

    private func updateDisplay() {
        if shortcutValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            applyDisplayState(.unset)
        } else {
            applyDisplayState(.assigned(ShortcutDisplay.string(shortcutValue)))
        }
    }

    @discardableResult
    private func restoreRequiredFallbackIfNeeded() -> Bool {
        guard let requiredFallbackShortcutValue,
              !requiredFallbackShortcutValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              shortcutValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        shortcutValue = requiredFallbackShortcutValue
        return true
    }

    private enum DisplayState {
        case unset
        case recording
        case recordingRejected
        case assigned(String)
    }

    private func applyDisplayState(_ state: DisplayState) {
        switch state {
        case .unset:
            title = L10n.tr("shortcut.add")
            toolTip = combinedHelp(with: L10n.tr("shortcut.recordHelp"))
            contentTintColor = .secondaryLabelColor
            setSymbol("keyboard.badge.ellipsis", fallback: "keyboard")
        case .recording:
            title = L10n.tr("shortcut.recording")
            let interactionHelp = requiredFallbackShortcutValue == nil
                ? L10n.tr("shortcut.recordingHelp")
                : L10n.tr("shortcut.requiredRecordingHelp")
            toolTip = combinedHelp(with: interactionHelp)
            contentTintColor = .controlAccentColor
            setSymbol("record.circle", fallback: "keyboard")
        case .recordingRejected:
            title = L10n.tr("shortcut.recordingInvalid")
            let interactionHelp = requiredFallbackShortcutValue == nil
                ? L10n.tr("shortcut.recordingHelp")
                : L10n.tr("shortcut.requiredRecordingHelp")
            toolTip = combinedHelp(with: interactionHelp)
            contentTintColor = .systemOrange
            setSymbol("exclamationmark.triangle.fill", fallback: "exclamationmark.triangle")
        case .assigned(let display):
            title = display
            let interactionHelp = requiredFallbackShortcutValue == nil
                ? L10n.tr("shortcut.clearHelp")
                : L10n.tr("shortcut.requiredHelp")
            toolTip = combinedHelp(with: interactionHelp)
            contentTintColor = nil
            setSymbol("keyboard")
        }

        if shouldApplySavedValidationWarning(for: state) {
            applyValidationWarningIfNeeded()
        }
        applyAccessibilityMetadata()
    }

    private func shouldApplySavedValidationWarning(for state: DisplayState) -> Bool {
        switch state {
        case .recording, .recordingRejected:
            return false
        case .unset, .assigned:
            return true
        }
    }

    private func combinedHelp(with interactionHelp: String) -> String {
        guard let actionHelp = actionHelp?.trimmingCharacters(in: .whitespacesAndNewlines),
              !actionHelp.isEmpty else {
            return interactionHelp
        }
        return "\(actionHelp)\n\(interactionHelp)"
    }

    private func applyValidationWarningIfNeeded() {
        guard let validationWarning else { return }
        toolTip = validationWarning
        contentTintColor = .systemOrange
        setSymbol("exclamationmark.triangle.fill", fallback: "exclamationmark.triangle")
    }

    private func applyAccessibilityMetadata() {
        setAccessibilityLabel(title)
        setAccessibilityHelp(toolTip)
        image?.accessibilityDescription = title
    }

    private func setSymbol(_ symbolName: String, fallback: String? = nil) {
        image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            ?? fallback.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
    }

    private static func shortcutString(from event: NSEvent) -> String? {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard flags.contains(.command) || flags.contains(.control) || flags.contains(.option) else {
            return nil
        }
        guard let key = keyName(for: Int(event.keyCode)) else { return nil }

        var parts: [String] = []
        if flags.contains(.command) { parts.append("Cmd") }
        if flags.contains(.control) { parts.append("Ctrl") }
        if flags.contains(.option) { parts.append("Option") }
        if flags.contains(.shift) { parts.append("Shift") }
        parts.append(key)
        return parts.joined(separator: "+")
    }

    private static func keyName(for keyCode: Int) -> String? {
        keyNames[keyCode]
    }

    private static let keyNames: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 49: "Space", 50: "`"
    ]
}

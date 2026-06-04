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
    case restored
    case invalid
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
        if trimmedName.isEmpty {
            return trimmedBundleIdentifier
        }
        if trimmedBundleIdentifier.isEmpty {
            return trimmedName
        }
        return "\(trimmedName) - \(trimmedBundleIdentifier)"
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
    private var settings: RestSettings
    private let onSave: (RestSettings) -> Void
    private let adminMessageLabel = NSTextField(labelWithString: "")
    private let searchField = NSSearchField()
    private let searchStatusLabel = NSTextField(labelWithString: "")
    private let saveStatusIcon = NSImageView()
    private let saveStatusLabel = NSTextField(labelWithString: "")
    private let soundPlayer = SoundPlayer()
    private var isLoadingSettings = false
    private var hasPendingTextEditing = false
    private var hasPendingAutosave = false
    private var autosaveGeneration = 0
    private var autosaveTask: Task<Void, Never>?
    private var numberInputs: [NumberInput] = []
    private weak var preferencesTabView: NSTabView?
    private var searchTargets: [PreferencesSearchTarget] = []
    private var highlightedSearchTarget: PreferencesHighlightSnapshot?

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
    private let appExclusionMode = NSPopUpButton()
    private let appExclusionAppliesEye = NSButton(checkboxWithTitle: L10n.tr("prefs.appliesEye"), target: nil, action: nil)
    private let appExclusionAppliesBody = NSButton(checkboxWithTitle: L10n.tr("prefs.appliesBody"), target: nil, action: nil)
    private var appExclusionNameRow: NSView?
    private var appExclusionTermsRow: NSView?
    private var appExclusionModeRow: NSView?
    private let appExclusionsJSONEditor = NSTextView()
    private let appExclusionsJSONScrollView = NSScrollView()
    private let appExclusionsAdvancedButton = NSButton()
    private var appExclusionsJSONRow: NSView?

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
    private let customBodyAddIdeaButton = NSButton()
    private var localImagePathRow: NSView?
    private var customBodyTitleRow: NSView?
    private var customBodyTextRow: NSView?
    private var customBodyAddIdeaButtonRow: NSView?
    private var customBodyIdeasJSONRow: NSView?
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
    private var shortcutEmergencyEyeRow: NSView?
    private let shortcutReset = ShortcutRecorderButton()
    private var shortcutClearControls: [(recorder: ShortcutRecorderButton, button: NSButton)] = []
    private let shortcutConflictRow = NSStackView()
    private let shortcutConflictIcon = NSImageView()
    private let shortcutConflictLabel = NSTextField(labelWithString: "")

    private let openAtLogin = NSButton(checkboxWithTitle: L10n.tr("prefs.openAtLogin"), target: nil, action: nil)
    private let checkUpdates = NSButton(checkboxWithTitle: L10n.tr("prefs.checkUpdates"), target: nil, action: nil)
    private let notifyNewVersion = NSButton(checkboxWithTitle: L10n.tr("prefs.notifyNewVersion"), target: nil, action: nil)
    private let showOnboardingNextLaunch = NSButton(
        checkboxWithTitle: L10n.tr("prefs.showOnboardingNextLaunch"),
        target: nil,
        action: nil
    )
    private let pauseUntilMorningMode = NSPopUpButton()
    private let pauseUntilMorningHour = NSTextField()
    private let pauseUntilMorningLatitude = NSTextField()
    private let pauseUntilMorningLongitude = NSTextField()
    private var pauseUntilMorningHourRow: NSView?
    private var pauseUntilMorningLatitudeRow: NSView?
    private var pauseUntilMorningLongitudeRow: NSView?
    private let pauseForSuspendOrLock = NSButton(checkboxWithTitle: L10n.tr("prefs.pauseForSuspendOrLock"), target: nil, action: nil)
    private let updateFeedURL = NSTextField()
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

    init(settings: RestSettings, onSave: @escaping (RestSettings) -> Void) {
        self.settings = settings
        self.onSave = onSave

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
        configureSoundVolumeControls()
        configureCustomBodyTextEditor()
        configureAppExclusionTokenField()
        configureAppExclusionRunningAppButton()
        configureCustomBodyAddIdeaButton()
        configureSoundPreviewButtons()
        configureSearchField()
        configureShortcutConflictWarning()
        configureShortcutRecorders()
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
        adminMessageLabel.lineBreakMode = .byWordWrapping
        adminMessageLabel.widthAnchor.constraint(equalToConstant: 620).isActive = true
        scheduleStack.addArrangedSubview(adminMessageLabel)
        scheduleStack.addArrangedSubview(section(
            L10n.tr("prefs.sectionEyeGate"),
            icon: .restGate,
            identifier: "prefs.section.eyeGate"
        ))
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
            max: 3600
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
        let bodyLeadRow = numberRow(L10n.tr("prefs.notificationLead"), bodyLead, unit: L10n.tr("prefs.unit.seconds"), min: 0, max: 3600)
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
        bodyCoveredDisplayRow.identifier = NSUserInterfaceItemIdentifier("prefs.bodyCoveredDisplayRow")
        self.bodyCoveredDisplayRow = bodyCoveredDisplayRow
        scheduleStack.addArrangedSubview(bodyCoveredDisplayRow)
        let bodyContentDisplayRow = row(L10n.tr("prefs.bodyContentDisplay"), bodyContentDisplay)
        bodyContentDisplayRow.identifier = NSUserInterfaceItemIdentifier("prefs.bodyContentDisplayRow")
        self.bodyContentDisplayRow = bodyContentDisplayRow
        scheduleStack.addArrangedSubview(bodyContentDisplayRow)
        bodyBlankSecondaryDisplays.identifier = NSUserInterfaceItemIdentifier("prefs.bodyBlankSecondaryDisplays")
        scheduleStack.addArrangedSubview(bodyBlankSecondaryDisplays)
        let bodyConfiguredDisplayRow = row(L10n.tr("prefs.configuredDisplayIndex"), bodyConfiguredDisplay)
        bodyConfiguredDisplayRow.identifier = NSUserInterfaceItemIdentifier("prefs.bodyConfiguredDisplayRow")
        self.bodyConfiguredDisplayRow = bodyConfiguredDisplayRow
        scheduleStack.addArrangedSubview(bodyConfiguredDisplayRow)
        addTab(to: tabView, title: L10n.tr("prefs.tabSchedule"), icon: .systemSymbol("clock"), stack: scheduleStack)

        let contextStack = contentStack()
        contextStack.addArrangedSubview(section(L10n.tr("prefs.sectionContext"), symbolName: "scope"))
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
        workingStartRow.identifier = NSUserInterfaceItemIdentifier("prefs.workingStartRow")
        self.workingStartRow = workingStartRow
        contextStack.addArrangedSubview(workingStartRow)
        let workingEndRow = row(L10n.tr("prefs.workingEnd"), workingEndPicker)
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
        contextStack.addArrangedSubview(appExclusionsAdvancedButton)
        let appExclusionsJSONRow = multilineRow(L10n.tr("prefs.advancedRulesJSON"), appExclusionsJSONScrollView)
        appExclusionsJSONRow.identifier = NSUserInterfaceItemIdentifier("prefs.appExclusionsJSONRow")
        self.appExclusionsJSONRow = appExclusionsJSONRow
        contextStack.addArrangedSubview(appExclusionsJSONRow)
        addTab(to: tabView, title: L10n.tr("prefs.tabContext"), icon: .systemSymbol("scope"), stack: contextStack)

        let appearanceStack = contentStack()
        appearanceStack.addArrangedSubview(section(L10n.tr("prefs.sectionPresentation"), symbolName: "paintbrush"))
        appearanceStack.addArrangedSubview(row(L10n.tr("prefs.theme"), themeSource))
        appearanceStack.addArrangedSubview(row(L10n.tr("prefs.language"), languageIdentifier))
        currentTimeInBodyBreak.identifier = NSUserInterfaceItemIdentifier("prefs.currentTimeBody")
        appearanceStack.addArrangedSubview(currentTimeInBodyBreak)
        appearanceStack.addArrangedSubview(breakHealth)
        appearanceStack.addArrangedSubview(silentNotifications)
        let eyeStartSoundRow = row(L10n.tr("prefs.eyeStartSound"), soundPickerRow(eyeStartSound, eyeStartSoundPreview))
        eyeStartSoundRow.identifier = NSUserInterfaceItemIdentifier("prefs.eyeStartSoundRow")
        self.eyeStartSoundRow = eyeStartSoundRow
        appearanceStack.addArrangedSubview(eyeStartSoundRow)
        let eyeFinishSoundRow = row(L10n.tr("prefs.eyeFinishSound"), soundPickerRow(eyeFinishSound, eyeFinishSoundPreview))
        eyeFinishSoundRow.identifier = NSUserInterfaceItemIdentifier("prefs.eyeFinishSoundRow")
        self.eyeFinishSoundRow = eyeFinishSoundRow
        appearanceStack.addArrangedSubview(eyeFinishSoundRow)
        let bodyStartSoundRow = row(L10n.tr("prefs.bodyStartSound"), soundPickerRow(bodyStartSound, bodyStartSoundPreview))
        bodyStartSoundRow.identifier = NSUserInterfaceItemIdentifier("prefs.bodyStartSoundRow")
        self.bodyStartSoundRow = bodyStartSoundRow
        appearanceStack.addArrangedSubview(bodyStartSoundRow)
        let bodyFinishSoundRow = row(L10n.tr("prefs.bodyFinishSound"), soundPickerRow(bodyFinishSound, bodyFinishSoundPreview))
        bodyFinishSoundRow.identifier = NSUserInterfaceItemIdentifier("prefs.bodyFinishSoundRow")
        self.bodyFinishSoundRow = bodyFinishSoundRow
        appearanceStack.addArrangedSubview(bodyFinishSoundRow)
        appearanceStack.addArrangedSubview(row(L10n.tr("prefs.volume"), soundVolumeRow()))
        appearanceStack.addArrangedSubview(soundPreviewStatusLabel)
        appearanceStack.addArrangedSubview(separator())
        appearanceStack.addArrangedSubview(section(L10n.tr("prefs.sectionCustomIdea"), symbolName: "text.bubble"))
        useBuiltInIdeas.identifier = NSUserInterfaceItemIdentifier("prefs.useBuiltInIdeas")
        appearanceStack.addArrangedSubview(useBuiltInIdeas)
        let localImagePathRow = row(L10n.tr("prefs.localImagePath"), localImagePickerRow())
        localImagePathRow.identifier = NSUserInterfaceItemIdentifier("prefs.localImagePathRow")
        self.localImagePathRow = localImagePathRow
        appearanceStack.addArrangedSubview(localImagePathRow)
        let customBodyTitleRow = row(L10n.tr("prefs.title"), customBodyTitle)
        customBodyTitle.identifier = NSUserInterfaceItemIdentifier("prefs.customBodyTitleField")
        customBodyTitleRow.identifier = NSUserInterfaceItemIdentifier("prefs.customBodyTitleRow")
        self.customBodyTitleRow = customBodyTitleRow
        appearanceStack.addArrangedSubview(customBodyTitleRow)
        let customBodyTextRow = multilineRow(L10n.tr("prefs.text"), customBodyTextScrollView)
        customBodyTextRow.identifier = NSUserInterfaceItemIdentifier("prefs.customBodyTextRow")
        self.customBodyTextRow = customBodyTextRow
        appearanceStack.addArrangedSubview(customBodyTextRow)
        let customBodyAddIdeaButtonRow = indentedControlRow(customBodyAddIdeaButton)
        customBodyAddIdeaButtonRow.identifier = NSUserInterfaceItemIdentifier("prefs.customBodyAddIdeaButtonRow")
        self.customBodyAddIdeaButtonRow = customBodyAddIdeaButtonRow
        appearanceStack.addArrangedSubview(customBodyAddIdeaButtonRow)
        appearanceStack.addArrangedSubview(customBodyIdeasAdvancedButton)
        let customBodyIdeasJSONRow = multilineRow(L10n.tr("prefs.advancedIdeasJSON"), customBodyIdeasJSONScrollView)
        customBodyIdeasJSONRow.identifier = NSUserInterfaceItemIdentifier("prefs.customBodyIdeasJSONRow")
        self.customBodyIdeasJSONRow = customBodyIdeasJSONRow
        appearanceStack.addArrangedSubview(customBodyIdeasJSONRow)
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
        shortcutsStack.addArrangedSubview(shortcutRow(L10n.tr("prefs.pauseToggle"), shortcutPauseToggle))
        shortcutsStack.addArrangedSubview(shortcutRow(L10n.tr("prefs.pause30Shortcut"), shortcutPause30))
        shortcutsStack.addArrangedSubview(shortcutRow(L10n.tr("prefs.pause1hShortcut"), shortcutPause1h))
        shortcutsStack.addArrangedSubview(shortcutRow(L10n.tr("prefs.pause2hShortcut"), shortcutPause2h))
        shortcutsStack.addArrangedSubview(shortcutRow(L10n.tr("prefs.pause5hShortcut"), shortcutPause5h))
        shortcutsStack.addArrangedSubview(shortcutRow(L10n.tr("prefs.pauseUntilMorningShortcut"), shortcutPauseUntilMorning))
        shortcutsStack.addArrangedSubview(shortcutRow(L10n.tr("prefs.nextScheduledRest"), shortcutNextScheduled))
        let shortcutEyeNowRow = shortcutRow(L10n.tr("prefs.eyeGateNow"), shortcutEyeNow)
        shortcutEyeNowRow.identifier = NSUserInterfaceItemIdentifier("prefs.shortcutEyeNowRow")
        self.shortcutEyeNowRow = shortcutEyeNowRow
        shortcutsStack.addArrangedSubview(shortcutEyeNowRow)
        let shortcutBodyNowRow = shortcutRow(L10n.tr("prefs.bodyBreakNow"), shortcutBodyNow)
        shortcutBodyNowRow.identifier = NSUserInterfaceItemIdentifier("prefs.shortcutBodyNowRow")
        self.shortcutBodyNowRow = shortcutBodyNowRow
        shortcutsStack.addArrangedSubview(shortcutBodyNowRow)
        let shortcutEndBodyRow = shortcutRow(L10n.tr("prefs.endBodyBreak"), shortcutEndBody)
        shortcutEndBodyRow.identifier = NSUserInterfaceItemIdentifier("prefs.shortcutEndBodyRow")
        self.shortcutEndBodyRow = shortcutEndBodyRow
        shortcutsStack.addArrangedSubview(shortcutEndBodyRow)
        let shortcutEmergencyEyeRow = shortcutRow(L10n.tr("prefs.emergencyEyeGate"), shortcutEmergencyEye)
        shortcutEmergencyEyeRow.identifier = NSUserInterfaceItemIdentifier("prefs.shortcutEmergencyEyeRow")
        self.shortcutEmergencyEyeRow = shortcutEmergencyEyeRow
        shortcutsStack.addArrangedSubview(shortcutEmergencyEyeRow)
        shortcutsStack.addArrangedSubview(shortcutRow(L10n.tr("prefs.reset"), shortcutReset))
        addTab(to: tabView, title: L10n.tr("prefs.tabShortcuts"), icon: .systemSymbol("keyboard"), stack: shortcutsStack)

        let advancedStack = contentStack()
        advancedStack.addArrangedSubview(section(L10n.tr("prefs.sectionOperations"), symbolName: "gearshape"))
        advancedStack.addArrangedSubview(openAtLogin)
        checkUpdates.identifier = NSUserInterfaceItemIdentifier("prefs.checkUpdates")
        advancedStack.addArrangedSubview(checkUpdates)
        notifyNewVersion.identifier = NSUserInterfaceItemIdentifier("prefs.notifyNewVersion")
        advancedStack.addArrangedSubview(notifyNewVersion)
        advancedStack.addArrangedSubview(showOnboardingNextLaunch)
        let pauseUntilMorningModeRow = row(L10n.tr("prefs.pauseUntilMorningMode"), pauseUntilMorningMode)
        advancedStack.addArrangedSubview(pauseUntilMorningModeRow)
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
        advancedStack.addArrangedSubview(pauseForSuspendOrLock)
        let updateFeedURLRow = row(L10n.tr("prefs.updateFeedURL"), updateFeedURL)
        updateFeedURL.identifier = NSUserInterfaceItemIdentifier("prefs.updateFeedURLField")
        updateFeedURLRow.identifier = NSUserInterfaceItemIdentifier("prefs.updateFeedURLRow")
        self.updateFeedURLRow = updateFeedURLRow
        advancedStack.addArrangedSubview(updateFeedURLRow)
        advancedStack.addArrangedSubview(separator())
        adminControlsStack.orientation = .vertical
        adminControlsStack.alignment = .leading
        adminControlsStack.spacing = 14
        adminControlsStack.edgeInsets = NSEdgeInsets(top: 0, left: 22, bottom: 0, right: 0)
        adminControlsStack.addArrangedSubview(disableUpdateFeatures)
        adminControlsStack.addArrangedSubview(hideSettingsPath)
        adminControlsStack.addArrangedSubview(hideStrictPreferences)
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
        let restoreDefaultsButton = NSButton(title: L10n.tr("prefs.restoreDefaults"), target: self, action: #selector(restoreDefaultsPressed))
        restoreDefaultsButton.identifier = NSUserInterfaceItemIdentifier("prefs.restoreDefaultsButton")
        restoreDefaultsButton.image = NSImage(systemSymbolName: "arrow.counterclockwise", accessibilityDescription: nil)
        restoreDefaultsButton.imagePosition = .imageLeading
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
            localImagePath, languageIdentifier, shortcutPauseToggle,
            shortcutPause30, shortcutPause1h, shortcutPause2h, shortcutPause5h, shortcutPauseUntilMorning,
            shortcutNextScheduled, shortcutEyeNow, shortcutBodyNow, shortcutEndBody,
            shortcutEmergencyEye, shortcutReset,
            appExclusionName, bodyConfiguredDisplay, updateFeedURL,
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
    }

    private func configureTimePickers() {
        [workingStartPicker, workingEndPicker].forEach { picker in
            picker.datePickerElements = [.hourMinute]
            picker.datePickerMode = .single
            picker.datePickerStyle = .textFieldAndStepper
            picker.widthAnchor.constraint(equalToConstant: 130).isActive = true
        }
    }

    private func configureSoundVolumeControls() {
        soundVolumeSlider.minValue = 0
        soundVolumeSlider.maxValue = 1
        soundVolumeSlider.numberOfTickMarks = 5
        soundVolumeSlider.allowsTickMarkValuesOnly = false
        soundVolumeSlider.widthAnchor.constraint(equalToConstant: 190).isActive = true
        soundVolumeValueLabel.textColor = .secondaryLabelColor
        soundVolumeValueLabel.alignment = .right
        soundVolumeValueLabel.widthAnchor.constraint(equalToConstant: 54).isActive = true
        soundPreviewStatusLabel.identifier = NSUserInterfaceItemIdentifier("soundPreviewStatus")
        soundPreviewStatusLabel.textColor = .secondaryLabelColor
        soundPreviewStatusLabel.font = .systemFont(ofSize: 12)
        soundPreviewStatusLabel.isHidden = true
        soundPreviewStatusLabel.widthAnchor.constraint(equalToConstant: 620).isActive = true
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
        searchField.sendsSearchStringImmediately = true
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
            height: 96
        )
        configureTextEditor(
            appExclusionsJSONEditor,
            in: appExclusionsJSONScrollView,
            identifier: "appExclusionsJSONEditor",
            font: .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            height: 148
        )
        configureTextEditor(
            customBodyIdeasJSONEditor,
            in: customBodyIdeasJSONScrollView,
            identifier: "customBodyIdeasJSONEditor",
            font: .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            height: 148
        )
    }

    private func configureTextEditor(
        _ editor: NSTextView,
        in scrollView: NSScrollView,
        identifier: String,
        font: NSFont,
        height: CGFloat
    ) {
        editor.identifier = NSUserInterfaceItemIdentifier(identifier)
        editor.isRichText = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.font = font
        editor.textContainerInset = NSSize(width: 8, height: 6)
        editor.isHorizontallyResizable = false
        editor.isVerticallyResizable = true
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: 360, height: CGFloat.greatestFiniteMagnitude)

        scrollView.identifier = NSUserInterfaceItemIdentifier("\(identifier)ScrollView")
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.documentView = editor
        scrollView.widthAnchor.constraint(equalToConstant: 360).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    private func configureAppExclusionTokenField() {
        appExclusionTerms.tokenStyle = .rounded
        appExclusionTerms.tokenizingCharacterSet = CharacterSet(charactersIn: ",\n")
        appExclusionTerms.placeholderString = L10n.tr("prefs.matchTermsPlaceholder")
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
        appExclusionAddRunningApp.toolTip = L10n.tr("prefs.addRunningAppHelp")
        appExclusionAddRunningApp.widthAnchor.constraint(equalToConstant: 168).isActive = true
    }

    private func configureCustomBodyAddIdeaButton() {
        customBodyAddIdeaButton.identifier = NSUserInterfaceItemIdentifier("prefs.customBodyAddIdeaButton")
        customBodyAddIdeaButton.title = L10n.tr("prefs.addCustomIdea")
        customBodyAddIdeaButton.image = NSImage(systemSymbolName: "plus.bubble", accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "plus.circle", accessibilityDescription: nil)
        customBodyAddIdeaButton.imagePosition = .imageLeading
        customBodyAddIdeaButton.bezelStyle = .rounded
        customBodyAddIdeaButton.target = self
        customBodyAddIdeaButton.action = #selector(addCustomBodyIdeaPressed(_:))
        customBodyAddIdeaButton.toolTip = L10n.tr("prefs.addCustomIdeaHelp")
        customBodyAddIdeaButton.widthAnchor.constraint(equalToConstant: 158).isActive = true
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
        switch button.identifier?.rawValue {
        case "customIdeas":
            title = expanded ? L10n.tr("prefs.hideAdvancedIdeas") : L10n.tr("prefs.showAdvancedIdeas")
        case "adminControls":
            title = expanded ? L10n.tr("prefs.hideAdminControls") : L10n.tr("prefs.showAdminControls")
        default:
            title = expanded ? L10n.tr("prefs.hideAdvancedRules") : L10n.tr("prefs.showAdvancedRules")
        }
        button.title = title
        button.image = NSImage(
            systemSymbolName: expanded ? "chevron.down" : "chevron.right",
            accessibilityDescription: nil
        )
    }

    private func configureImagePickerControls() {
        localImagePath.isEditable = false
        localImagePath.isSelectable = true
        localImagePath.cell?.lineBreakMode = .byTruncatingMiddle
        localImagePath.placeholderString = L10n.tr("prefs.noImageSelected")

        localImageChooseButton.title = L10n.tr("prefs.chooseFile")
        localImageChooseButton.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
        localImageChooseButton.imagePosition = .imageLeading
        localImageChooseButton.target = self
        localImageChooseButton.action = #selector(chooseLocalImagePressed)

        localImageClearButton.title = L10n.tr("prefs.clear")
        localImageClearButton.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)
        localImageClearButton.imagePosition = .imageLeading
        localImageClearButton.target = self
        localImageClearButton.action = #selector(clearLocalImagePressed)

        localImagePreview.identifier = NSUserInterfaceItemIdentifier("localImagePreview")
        localImagePreview.translatesAutoresizingMaskIntoConstraints = false
        localImagePreview.imageScaling = .scaleProportionallyUpOrDown
        localImagePreview.wantsLayer = true
        localImagePreview.layer?.cornerRadius = 6
        localImagePreview.layer?.borderWidth = 1
        localImagePreview.layer?.borderColor = NSColor.separatorColor.cgColor
        localImagePreview.layer?.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.45).cgColor
        localImagePreview.toolTip = L10n.tr("prefs.imageDropHelp")
        localImagePreview.setAccessibilityLabel(L10n.tr("prefs.localImagePath"))
        localImagePreview.setAccessibilityHelp(L10n.tr("prefs.imageDropHelp"))
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
            appExclusionEnabled, appExclusionAppliesEye, appExclusionAppliesBody, themeSource,
            languageIdentifier, currentTimeInBodyBreak, breakHealth, silentNotifications,
            eyeStartSound, eyeFinishSound, bodyStartSound, bodyFinishSound, useBuiltInIdeas, openAtLogin,
            checkUpdates, notifyNewVersion, showOnboardingNextLaunch, pauseUntilMorningMode, pauseForSuspendOrLock,
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
        shortcutConflictIcon.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
        shortcutConflictIcon.contentTintColor = .systemOrange
        shortcutConflictIcon.symbolConfiguration = .init(pointSize: 14, weight: .semibold)
        shortcutConflictIcon.widthAnchor.constraint(equalToConstant: 18).isActive = true

        shortcutConflictLabel.textColor = .systemOrange
        shortcutConflictLabel.lineBreakMode = .byWordWrapping
        shortcutConflictLabel.widthAnchor.constraint(equalToConstant: 590).isActive = true

        shortcutConflictRow.orientation = .horizontal
        shortcutConflictRow.alignment = .top
        shortcutConflictRow.spacing = 8
        shortcutConflictRow.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        shortcutConflictRow.addArrangedSubview(shortcutConflictIcon)
        shortcutConflictRow.addArrangedSubview(shortcutConflictLabel)
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
        configureSoundPreviewButton(eyeStartSoundPreview, identifier: "eyeStart")
        configureSoundPreviewButton(eyeFinishSoundPreview, identifier: "eyeFinish")
        configureSoundPreviewButton(bodyStartSoundPreview, identifier: "bodyStart")
        configureSoundPreviewButton(bodyFinishSoundPreview, identifier: "bodyFinish")
    }

    private func configureSoundPreviewButton(_ button: NSButton, identifier: String) {
        button.title = L10n.tr("prefs.previewSound")
        button.image = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: nil)
        button.imagePosition = .imageLeading
        button.toolTip = L10n.tr("prefs.previewSoundHelp")
        button.target = self
        button.action = #selector(previewSound(_:))
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
    }

    private func loadSettings() {
        isLoadingSettings = true
        defer {
            isLoadingSettings = false
            setSaveStatus(.ready)
        }

        adminMessageLabel.stringValue = settings.admin.customPreferencesMessage
        adminMessageLabel.isHidden = settings.admin.customPreferencesMessage.isEmpty

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

        let exclusion = settings.appExclusions.first
        appExclusionEnabled.state = state(exclusion?.isEnabled ?? false)
        appExclusionName.stringValue = exclusion?.name ?? ""
        appExclusionTerms.objectValue = exclusion?.matchTerms ?? []
        selectPopup(appExclusionMode, rawValue: (exclusion?.mode ?? .pauseWhenMatched).rawValue)
        appExclusionAppliesEye.state = state(exclusion?.appliesTo.contains(.eyeGate) ?? false)
        appExclusionAppliesBody.state = state(exclusion?.appliesTo.contains(.bodyBreak) ?? true)
        appExclusionsJSONEditor.string = encodedAppExclusions(settings.appExclusions)
        setAdvancedDisclosure(
            row: appExclusionsJSONRow,
            button: appExclusionsAdvancedButton,
            expanded: !appExclusionsJSONEditor.string.isEmpty
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

        let custom = settings.contentLibrary.customBodyBreakIdeas.first
        useBuiltInIdeas.state = state(settings.contentLibrary.useBuiltInIdeas)
        customBodyTitle.stringValue = custom?.title ?? ""
        customBodyTextEditor.string = custom?.body ?? ""
        customBodyIdeasJSONEditor.string = encodedCustomIdeas(settings.contentLibrary.customBodyBreakIdeas)
        setAdvancedDisclosure(
            row: customBodyIdeasJSONRow,
            button: customBodyIdeasAdvancedButton,
            expanded: !customBodyIdeasJSONEditor.string.isEmpty
        )
        localImagePath.stringValue = settings.contentLibrary.localImagePaths.first ?? ""
        updateLocalImagePreview()
        updateCustomBodyAddIdeaButtonState()

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
        pauseForSuspendOrLock.state = state(settings.operations.resolvedPauseForSuspendOrLock)
        updateFeedURL.stringValue = settings.operations.updateFeedURL
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
        applyAdminVisibility()
        updateShortcutClearButtons()
    }

    @discardableResult
    private func saveCurrentSettings(showAlerts: Bool) -> Bool {
        let appExclusionsEnabled = isOn(appExclusionEnabled)
        let advancedAppExclusions: [AppExclusionRule]?
        let advancedCustomIdeas: [RestIdea]?
        do {
            advancedAppExclusions = appExclusionsEnabled ? try decodedAdvancedAppExclusions() : nil
            syncPrimaryCustomIdeaIntoAdvancedJSONIfNeeded()
            advancedCustomIdeas = try decodedAdvancedCustomIdeas()
        } catch {
            if showAlerts {
                showInvalidJSONAlert(error)
            } else {
                setSaveStatus(.invalid)
            }
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
            confirmationSteps: EmergencyOverridePolicy.defaults.confirmationSteps,
            minimumHoldDuration: 0
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
        next.operations.pauseUntilMorningLatitude = min(89.8, max(-89.8, doubleValue(pauseUntilMorningLatitude, fallback: 0)))
        next.operations.pauseUntilMorningLongitude = normalizedLongitude(doubleValue(pauseUntilMorningLongitude, fallback: 0))
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
        return true
    }

    private func applyAdminVisibility() {
        updateDependentControlEnablement()

        updateUpdatePreferencesVisibility()
        updateShortcutConflictWarning()
    }

    private func updateUpdatePreferencesVisibility() {
        let hideUpdateControls = settings.admin.disableAppUpdateFeatures
        let showUpdateDependents = !hideUpdateControls && isOn(checkUpdates)
        checkUpdates.isHidden = hideUpdateControls
        notifyNewVersion.isHidden = !showUpdateDependents
        notifyNewVersion.isEnabled = showUpdateDependents
        updateFeedURLRow?.isHidden = !showUpdateDependents
        updateFeedURL.isEnabled = showUpdateDependents
    }

    private func updateShortcutConflictWarning() {
        let entries = visibleShortcutPreferenceEntries()
        entries.forEach { $0.recorder.validationWarning = nil }

        guard let warning = shortcutValidationWarning(for: entries) else {
            shortcutConflictLabel.stringValue = ""
            shortcutConflictRow.isHidden = true
            return
        }

        shortcutConflictLabel.stringValue = warning.message
        shortcutConflictRow.isHidden = false
        warning.recorders.forEach { $0.validationWarning = warning.message }
    }

    private func updateShortcutClearButtons() {
        for pair in shortcutClearControls {
            let fallback = pair.recorder.requiredFallbackShortcutValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = pair.recorder.shortcutValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let isRequired = fallback != nil
            let canClear = isRequired ? value != (fallback ?? "") : !value.isEmpty
            pair.button.isEnabled = canClear
            pair.button.toolTip = isRequired
                ? L10n.tr("shortcut.restoreDefaultButtonHelp")
                : L10n.tr("shortcut.clearButtonHelp")
            pair.button.contentTintColor = canClear ? .secondaryLabelColor : .tertiaryLabelColor
            pair.button.image = NSImage(
                systemSymbolName: isRequired ? "arrow.counterclockwise" : "xmark.circle",
                accessibilityDescription: pair.button.toolTip
            )
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
        appendIfVisible(shortcutEndBodyRow, L10n.tr("prefs.endBodyBreak"), shortcutEndBody)
        appendIfVisible(shortcutEmergencyEyeRow, L10n.tr("prefs.emergencyEyeGate"), shortcutEmergencyEye)
        entries.append(ShortcutPreferenceEntry(title: L10n.tr("prefs.reset"), recorder: shortcutReset))
        return entries
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
            appExclusionNameRow, appExclusionTermsRow, appExclusionModeRow
        ].forEach { $0?.isHidden = !exclusionEnabled }
        [
            appExclusionsAdvancedButton
        ].forEach { $0.isHidden = !exclusionEnabled }
        let appExclusionAppliesEyeVisible = exclusionEnabled && eyeGateEnabled
        let appExclusionAppliesBodyVisible = exclusionEnabled && bodyBreakEnabled
        appExclusionAppliesEye.isHidden = !appExclusionAppliesEyeVisible
        appExclusionAppliesBody.isHidden = !appExclusionAppliesBodyVisible
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
        if !exclusionEnabled {
            setAdvancedDisclosure(row: appExclusionsJSONRow, button: appExclusionsAdvancedButton, expanded: false)
        }
        [
            appExclusionName, appExclusionTerms, appExclusionMode
        ].forEach { $0.isEnabled = exclusionEnabled }
        appExclusionAddRunningApp.isEnabled = exclusionEnabled
        appExclusionAppliesEye.isEnabled = appExclusionAppliesEyeVisible
        appExclusionAppliesBody.isEnabled = appExclusionAppliesBodyVisible

        updateUpdatePreferencesVisibility()

        let morningMode = selected(MorningPauseMode.self, from: pauseUntilMorningMode, fallback: .hour)
        let usesSunrise = morningMode == .sunrise
        pauseUntilMorningHourRow?.isHidden = usesSunrise
        pauseUntilMorningLatitudeRow?.isHidden = !usesSunrise
        pauseUntilMorningLongitudeRow?.isHidden = !usesSunrise
        setNumberInputEnabled(pauseUntilMorningHour, !usesSunrise)
        pauseUntilMorningLatitude.isEnabled = usesSunrise
        pauseUntilMorningLongitude.isEnabled = usesSunrise

        updateAppearanceEyeGateVisibility(eyeGateEnabled: eyeGateEnabled)
        updateAppearanceBodyBreakVisibility(bodyBreakEnabled: bodyBreakEnabled)
        updateShortcutPreferenceVisibility(
            eyeGateEnabled: eyeGateEnabled,
            bodyBreakEnabled: bodyBreakEnabled,
            eyeManualFinishEnabled: isOn(eyeManualFinish),
            strictPreferencesHidden: strictPreferencesHidden
        )
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

        let emergencyVisible = eyeGateEnabled && !strictPreferencesHidden && isOn(eyeEmergencyOverride)
        shortcutEmergencyEyeRow?.isHidden = !emergencyVisible
        shortcutEmergencyEye.isEnabled = emergencyVisible
        updateShortcutConflictWarning()
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
        customBodyIdeasAdvancedButton.isHidden = !bodyBreakEnabled
        if !bodyBreakEnabled {
            setAdvancedDisclosure(row: customBodyIdeasJSONRow, button: customBodyIdeasAdvancedButton, expanded: false)
        }
        customBodyTitle.isEnabled = bodyBreakEnabled
        customBodyTextEditor.isEditable = bodyBreakEnabled
        customBodyTextScrollView.alphaValue = bodyBreakEnabled ? 1 : 0.55
        customBodyIdeasJSONEditor.isEditable = bodyBreakEnabled
        customBodyIdeasJSONScrollView.alphaValue = bodyBreakEnabled ? 1 : 0.55
        localImageChooseButton.isEnabled = bodyBreakEnabled
        localImageClearButton.isEnabled = bodyBreakEnabled &&
            !localImagePath.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        localImagePreview.isDropEnabled = bodyBreakEnabled
        updateCustomBodyAddIdeaButtonState()
    }

    private func setNumberInputEnabled(_ field: NSTextField, _ enabled: Bool) {
        field.isEnabled = enabled
        let input = numberInputs.first(where: { $0.field === field })
        input?.stepper.isEnabled = enabled
        input?.slider?.isEnabled = enabled
    }

    @objc private func restoreDefaultsPressed() {
        guard confirmRestoreDefaults() else { return }
        settings = .restoredDefaults
        loadSettings()
        onSave(settings)
        setSaveStatus(.restored)
    }

    private func confirmRestoreDefaults() -> Bool {
        makeRestoreDefaultsAlert().runModal() == .alertSecondButtonReturn
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
            soundPreviewStatusLabel.isHidden = true
            soundPreviewStatusLabel.stringValue = ""
        }
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
        guard let idea = currentCustomBodyIdea(id: UUID().uuidString) else { return }
        do {
            var ideas = try decodedAdvancedCustomIdeas() ?? []
            ideas.append(idea)
            customBodyIdeasJSONEditor.string = encodedCustomIdeasForEditor(ideas)
            setAdvancedDisclosure(row: customBodyIdeasJSONRow, button: customBodyIdeasAdvancedButton, expanded: true)
            customBodyTitle.stringValue = ""
            customBodyTextEditor.string = ""
            updateCustomBodyAddIdeaButtonState()
            scheduleAutosave()
        } catch {
            showInvalidJSONAlert(error)
            setSaveStatus(.invalid)
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
        default:
            break
        }
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
        if let field = obj.object as? NSTextField, field === customBodyTitle {
            updateCustomBodyAddIdeaButtonState()
        }
        hasPendingTextEditing = true
        setSaveStatus(.editing)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if let field = obj.object as? NSSearchField, field === searchField {
            performPreferencesSearch(field.stringValue)
            return
        }
        if let field = obj.object as? NSTextField {
            syncNumberControls(for: field)
        }
        hasPendingTextEditing = false
        updateDependentControlEnablement()
        scheduleAutosave()
    }

    func textDidChange(_ notification: Notification) {
        guard !isLoadingSettings else { return }
        if let editor = notification.object as? NSTextView, editor === customBodyTextEditor {
            updateCustomBodyAddIdeaButtonState()
        }
        setSaveStatus(.editing)
        scheduleAutosave()
    }

    func textDidEndEditing(_ notification: Notification) {
        scheduleAutosave()
    }

    private func scheduleAutosave() {
        guard !isLoadingSettings else { return }
        hasPendingAutosave = true
        autosaveGeneration += 1
        let generation = autosaveGeneration
        autosaveTask?.cancel()
        setSaveStatus(.saving)
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

    private func setSaveStatus(_ status: PreferencesSaveStatus) {
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
        case .restored:
            symbolName = "arrow.counterclockwise.circle.fill"
            color = .systemBlue
            title = L10n.tr("prefs.autosaveRestored")
        case .invalid:
            symbolName = "exclamationmark.triangle.fill"
            color = .systemOrange
            title = L10n.tr("prefs.autosaveInvalid")
        }

        saveStatusIcon.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        saveStatusIcon.contentTintColor = color
        saveStatusLabel.stringValue = title
        saveStatusLabel.textColor = color == .secondaryLabelColor ? .secondaryLabelColor : color
    }

    @objc private func previewSound(_ sender: NSButton) {
        guard let popup = soundPopup(for: sender.identifier?.rawValue) else { return }
        let volume = min(1, max(0, soundVolumeSlider.doubleValue))
        let option = selectedSoundOption(in: popup)
        soundPlayer.play(option == .silence ? .silent : .named(option.name, volume: volume))
        soundPreviewStatusLabel.stringValue = option == .silence
            ? L10n.tr("prefs.soundPreviewSilence")
            : L10n.format("prefs.soundPreviewPlayed", option.title)
        soundPreviewStatusLabel.isHidden = false
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
        let terms = appExclusionMatchTerms()
        guard isOn(appExclusionEnabled), !terms.isEmpty else { return [] }

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

        let mode = selected(AppExclusionRule.Mode.self, from: appExclusionMode, fallback: .pauseWhenMatched)
        return [
            AppExclusionRule(
                id: settings.appExclusions.first?.id ?? UUID().uuidString,
                name: appExclusionName.stringValue.isEmpty ? "Primary Exclusion" : appExclusionName.stringValue,
                matchTerms: terms,
                mode: mode,
                appliesTo: appliesTo,
                isEnabled: true
            )
        ]
    }

    private func addAppExclusionApplicationCandidate(_ candidate: AppExclusionApplicationCandidate) {
        guard isOn(appExclusionEnabled) else { return }
        let existingTerms = appExclusionMatchTerms()
        let nextTerms = AppExclusionApplicationCandidate.uniqueNonemptyTerms(
            existingTerms.map { Optional($0) } + candidate.terms.map { Optional($0) }
        )
        appExclusionTerms.objectValue = nextTerms
        let trimmedName = appExclusionName.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty, !candidate.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appExclusionName.stringValue = candidate.name
        }
        syncPrimaryAppExclusionIntoAdvancedJSONIfNeeded()
        updateDependentControlEnablement()
        scheduleAutosave()
    }

    private func appExclusionMatchTerms() -> [String] {
        AppExclusionApplicationCandidate.uniqueNonemptyTerms(
            tokenFieldValues(appExclusionTerms)
                .flatMap { $0.split(whereSeparator: { $0 == "," || $0 == "\n" }) }
                .map { Optional(String($0)) }
        )
    }

    private func syncPrimaryAppExclusionIntoAdvancedJSONIfNeeded() {
        let raw = appExclusionsJSONEditor.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty,
              let data = raw.data(using: .utf8),
              var rules = try? JSONDecoder().decode([AppExclusionRule].self, from: data),
              !rules.isEmpty,
              let primary = savedAppExclusions().first else {
            return
        }

        rules[0] = AppExclusionRule(
            id: rules[0].id,
            name: primary.name,
            matchTerms: primary.matchTerms,
            mode: primary.mode,
            appliesTo: primary.appliesTo,
            isEnabled: primary.isEnabled
        )
        appExclusionsJSONEditor.string = encodedAppExclusions(rules)
    }

    private struct InvalidAdvancedJSON: LocalizedError {
        var fieldName: String
        var underlying: Error

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
            return try JSONDecoder().decode([AppExclusionRule].self, from: data)
        } catch {
            throw InvalidAdvancedJSON(fieldName: L10n.tr("prefs.advancedRulesJSON"), underlying: error)
        }
    }

    private func encodedAppExclusions(_ rules: [AppExclusionRule]) -> String {
        guard rules.count > 1,
              let data = try? prettyJSONEncoder().encode(rules),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
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
            title: title.isEmpty ? "Custom Body Break" : title,
            body: body,
            isEnabled: true
        )
    }

    private func updateCustomBodyAddIdeaButtonState() {
        let bodyBreakEnabled = isOn(bodyEnabled)
        customBodyAddIdeaButton.isEnabled = bodyBreakEnabled &&
            currentCustomBodyIdea(id: "preview") != nil
    }

    private func syncPrimaryCustomIdeaIntoAdvancedJSONIfNeeded() {
        let raw = customBodyIdeasJSONEditor.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty,
              let data = raw.data(using: .utf8),
              var ideas = try? JSONDecoder().decode([RestIdea].self, from: data),
              !ideas.isEmpty,
              let primary = currentCustomBodyIdea(id: ideas[0].id) else {
            return
        }

        ideas[0] = RestIdea(
            id: primary.id,
            kind: .bodyBreak,
            title: primary.title,
            body: primary.body,
            isEnabled: ideas[0].isEnabled
        )
        customBodyIdeasJSONEditor.string = encodedCustomIdeasForEditor(ideas)
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
                        title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom Body Break" : $0.title,
                        body: ContentSanitizer.sanitizeRichText($0.body),
                        isEnabled: $0.isEnabled
                    )
                }
        } catch {
            throw InvalidAdvancedJSON(fieldName: L10n.tr("prefs.advancedIdeasJSON"), underlying: error)
        }
    }

    private func encodedCustomIdeas(_ ideas: [RestIdea]) -> String {
        let bodyIdeas = ideas.filter { $0.kind == .bodyBreak }
        let encoded = encodedCustomIdeasForEditor(bodyIdeas)
        guard bodyIdeas.count > 1, !encoded.isEmpty else {
            return ""
        }
        return encoded
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

    private func shortcutRow(_ title: String, _ recorder: ShortcutRecorderButton) -> NSStackView {
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
        return row(title, controls)
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
        } else if let popup = view as? NSPopUpButton, !popup.title.isEmpty {
            texts.append(popup.title)
        } else if let label = view as? NSTextField, !label.stringValue.isEmpty {
            texts.append(label.stringValue)
        }
        for subview in view.subviews {
            texts.append(contentsOf: searchableText(in: subview))
        }
        return texts
    }

    private func bestSearchTargetTitle(in view: NSView, fallback: String) -> String {
        searchableText(in: view).first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? fallback
    }

    @objc private func preferencesSearchChanged(_ sender: NSSearchField) {
        performPreferencesSearch(sender.stringValue)
    }

    private func performPreferencesSearch(_ query: String) {
        let normalizedQuery = Self.normalizedSearchText(query)
        clearHighlightedSearchTarget()
        guard !normalizedQuery.isEmpty else {
            searchStatusLabel.stringValue = ""
            searchStatusLabel.isHidden = true
            return
        }

        guard let target = searchTargets.first(where: {
            isSearchTargetVisible($0.view) && $0.normalizedText.contains(normalizedQuery)
        }) else {
            searchStatusLabel.stringValue = L10n.tr("prefs.searchNoResults")
            searchStatusLabel.textColor = .systemOrange
            searchStatusLabel.isHidden = false
            return
        }

        preferencesTabView?.selectTabViewItem(withIdentifier: target.tabIdentifier)
        target.view.scrollToVisible(target.view.bounds)
        highlightSearchTarget(target.view)
        focusSearchTarget(target.view)
        searchStatusLabel.stringValue = L10n.format("prefs.searchMatched", target.tabIdentifier, target.title)
        searchStatusLabel.textColor = .secondaryLabelColor
        searchStatusLabel.isHidden = false
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
            return false
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

    private func localImagePickerRow() -> NSStackView {
        let controls = NSStackView(views: [localImagePath, localImageChooseButton, localImageClearButton])
        controls.orientation = .horizontal
        controls.spacing = 8
        controls.alignment = .centerY

        let preview = NSStackView(views: [localImagePreview, localImagePreviewLabel])
        preview.orientation = .horizontal
        preview.spacing = 10
        preview.alignment = .centerY

        let stack = NSStackView(views: [controls, preview])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        return stack
    }

    private func updateLocalImagePreview() {
        let path = localImagePath.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            localImagePreview.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
            localImagePreview.contentTintColor = .tertiaryLabelColor
            localImagePreviewLabel.stringValue = L10n.tr("prefs.imagePreviewEmpty")
            localImagePreviewLabel.toolTip = nil
            return
        }

        let url = URL(fileURLWithPath: path)
        localImagePreviewLabel.toolTip = path
        guard let image = NSImage(contentsOfFile: path) else {
            localImagePreview.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
            localImagePreview.contentTintColor = .systemOrange
            localImagePreviewLabel.stringValue = L10n.format("prefs.imagePreviewUnavailable", url.lastPathComponent)
            return
        }

        localImagePreview.image = image
        localImagePreview.contentTintColor = nil
        localImagePreviewLabel.stringValue = url.lastPathComponent
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
        soundVolumeValueLabel.stringValue = "\(Int(round(value * 100)))%"
    }

    private func selected<T: RawRepresentable>(_ type: T.Type, from popup: NSPopUpButton, fallback: T) -> T where T.RawValue == String {
        if let rawValue = popup.selectedItem?.representedObject as? String,
           let value = T(rawValue: rawValue) {
            return value
        }
        guard let title = popup.selectedItem?.title, let value = T(rawValue: title) else { return fallback }
        return value
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
        case assigned(String)
    }

    private func applyDisplayState(_ state: DisplayState) {
        switch state {
        case .unset:
            title = L10n.tr("shortcut.notSet")
            toolTip = L10n.tr("shortcut.recordHelp")
            contentTintColor = .secondaryLabelColor
            setSymbol("keyboard.badge.ellipsis", fallback: "keyboard")
        case .recording:
            title = L10n.tr("shortcut.recording")
            toolTip = requiredFallbackShortcutValue == nil
                ? L10n.tr("shortcut.recordingHelp")
                : L10n.tr("shortcut.requiredRecordingHelp")
            contentTintColor = .controlAccentColor
            setSymbol("record.circle", fallback: "keyboard")
        case .assigned(let display):
            title = display
            toolTip = requiredFallbackShortcutValue == nil
                ? L10n.tr("shortcut.clearHelp")
                : L10n.tr("shortcut.requiredHelp")
            contentTintColor = nil
            setSymbol("keyboard")
        }

        if case .recording = state {
            return
        }
        applyValidationWarningIfNeeded()
    }

    private func applyValidationWarningIfNeeded() {
        guard let validationWarning else { return }
        toolTip = validationWarning
        contentTintColor = .systemOrange
        setSymbol("exclamationmark.triangle.fill", fallback: "exclamationmark.triangle")
    }

    private func setSymbol(_ symbolName: String, fallback: String? = nil) {
        image = NSImage(systemSymbolName: symbolName, accessibilityDescription: symbolName)
            ?? fallback.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: $0) }
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

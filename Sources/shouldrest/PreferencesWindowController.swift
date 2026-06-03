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

private struct NumberInput {
    var field: NSTextField
    var stepper: NSStepper
    var min: Double
    var max: Double
}

@MainActor
final class PreferencesWindowController: NSWindowController, NSTextFieldDelegate {
    private var settings: RestSettings
    private let onSave: (RestSettings) -> Void
    private let adminMessageLabel = NSTextField(labelWithString: "")
    private let saveStatusLabel = NSTextField(labelWithString: "")
    private let soundPlayer = SoundPlayer()
    private var isLoadingSettings = false
    private var autosaveTask: Task<Void, Never>?
    private var numberInputs: [NumberInput] = []

    private let eyeEnabled = NSButton(checkboxWithTitle: L10n.tr("prefs.enableEyeGate"), target: nil, action: nil)
    private let eyeInterval = NSTextField()
    private let eyeDuration = NSTextField()
    private let eyeColor = NSColorWell()
    private let eyeNotify = NSButton(checkboxWithTitle: L10n.tr("prefs.notifyEyeGate"), target: nil, action: nil)
    private let eyeLead = NSTextField()
    private let eyeManualFinish = NSButton(checkboxWithTitle: L10n.tr("prefs.eyeManualFinish"), target: nil, action: nil)

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
    private let bodyContentDisplay = NSPopUpButton()
    private let bodyBlankSecondaryDisplays = NSButton(checkboxWithTitle: L10n.tr("prefs.bodyBlankSecondary"), target: nil, action: nil)
    private let bodyConfiguredDisplayIndex = NSTextField()

    private let naturalBreaks = NSButton(checkboxWithTitle: L10n.tr("prefs.naturalBreaks"), target: nil, action: nil)
    private let naturalIdleMinutes = NSTextField()
    private let focusMonitor = NSButton(checkboxWithTitle: L10n.tr("prefs.monitorFocus"), target: nil, action: nil)
    private let focusDefersBody = NSButton(checkboxWithTitle: L10n.tr("prefs.focusDefersBody"), target: nil, action: nil)
    private let workingHoursEnabled = NSButton(checkboxWithTitle: L10n.tr("prefs.workingHours"), target: nil, action: nil)
    private let workingStart = NSTextField()
    private let workingEnd = NSTextField()

    private let appExclusionEnabled = NSButton(checkboxWithTitle: L10n.tr("prefs.enablePrimaryExclusion"), target: nil, action: nil)
    private let appExclusionName = NSTextField()
    private let appExclusionTerms = NSTextField()
    private let appExclusionMode = NSPopUpButton()
    private let appExclusionAppliesEye = NSButton(checkboxWithTitle: L10n.tr("prefs.appliesEye"), target: nil, action: nil)
    private let appExclusionAppliesBody = NSButton(checkboxWithTitle: L10n.tr("prefs.appliesBody"), target: nil, action: nil)
    private let appExclusionsJSON = NSTextField()
    private let appExclusionsAdvancedButton = NSButton()
    private var appExclusionsJSONRow: NSView?

    private let themeSource = NSPopUpButton()
    private let trayStyle = NSPopUpButton()
    private let showMenuBarItem = NSButton(checkboxWithTitle: L10n.tr("prefs.showMenuBarItem"), target: nil, action: nil)
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
    private let soundVolume = NSTextField()

    private let customBodyTitle = NSTextField()
    private let customBodyText = NSTextField()
    private let customBodyIdeasJSON = NSTextField()
    private let customBodyIdeasAdvancedButton = NSButton()
    private var customBodyIdeasJSONRow: NSView?
    private let localImagePath = NSTextField()
    private let localImageChooseButton = NSButton()
    private let localImageClearButton = NSButton()
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
    private let shortcutSkipBody = ShortcutRecorderButton()
    private let shortcutEndBody = ShortcutRecorderButton()
    private let shortcutEmergencyEye = ShortcutRecorderButton()
    private var shortcutEmergencyEyeRow: NSView?
    private let shortcutReset = ShortcutRecorderButton()

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
    private let pauseForSuspendOrLock = NSButton(checkboxWithTitle: L10n.tr("prefs.pauseForSuspendOrLock"), target: nil, action: nil)
    private let updateFeedURL = NSTextField()
    private var updateFeedURLRow: NSView?
    private let disableUpdateFeatures = NSButton(checkboxWithTitle: L10n.tr("prefs.adminHideUpdates"), target: nil, action: nil)
    private let hideSettingsPath = NSButton(checkboxWithTitle: L10n.tr("prefs.adminHideSettingsPath"), target: nil, action: nil)
    private let hideStrictPreferences = NSButton(checkboxWithTitle: L10n.tr("prefs.adminHideStrict"), target: nil, action: nil)
    private let customPreferencesMessage = NSTextField()

    init(settings: RestSettings, onSave: @escaping (RestSettings) -> Void) {
        self.settings = settings
        self.onSave = onSave

        let window = NSWindow(
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
        configureSoundPreviewButtons()
        configureEnablementGuards()
        configureAutosave()

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 0
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.setContentHuggingPriority(.defaultLow, for: .vertical)
        tabView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        root.addArrangedSubview(tabView)

        let scheduleStack = contentStack()
        adminMessageLabel.lineBreakMode = .byWordWrapping
        adminMessageLabel.widthAnchor.constraint(equalToConstant: 620).isActive = true
        scheduleStack.addArrangedSubview(adminMessageLabel)
        scheduleStack.addArrangedSubview(section(L10n.tr("prefs.sectionEyeGate"), symbolName: "timer"))
        scheduleStack.addArrangedSubview(eyeEnabled)
        scheduleStack.addArrangedSubview(numberRow(L10n.tr("prefs.everyMinutes"), eyeInterval, unit: L10n.tr("prefs.unit.minutes"), min: 1, max: 240))
        scheduleStack.addArrangedSubview(numberRow(L10n.tr("prefs.durationSeconds"), eyeDuration, unit: L10n.tr("prefs.unit.seconds"), min: 1, max: 300))
        scheduleStack.addArrangedSubview(row(L10n.tr("prefs.overlayColor"), eyeColor))
        scheduleStack.addArrangedSubview(eyeNotify)
        scheduleStack.addArrangedSubview(numberRow(L10n.tr("prefs.notificationLead"), eyeLead, unit: L10n.tr("prefs.unit.seconds"), min: 0, max: 3600))
        scheduleStack.addArrangedSubview(eyeManualFinish)
        scheduleStack.addArrangedSubview(separator())
        scheduleStack.addArrangedSubview(section(L10n.tr("prefs.sectionBodyBreak"), symbolName: "figure.walk"))
        scheduleStack.addArrangedSubview(bodyEnabled)
        scheduleStack.addArrangedSubview(numberRow(L10n.tr("prefs.bodyIntervalMinutes"), bodyInterval, unit: L10n.tr("prefs.unit.minutes"), min: 1, max: 720))
        scheduleStack.addArrangedSubview(numberRow(L10n.tr("prefs.durationMinutes"), bodyDuration, unit: L10n.tr("prefs.unit.minutes"), min: 1, max: 180))
        scheduleStack.addArrangedSubview(numberRow(L10n.tr("prefs.afterEyeGates"), bodyAfterEyeGates, unit: L10n.tr("prefs.unit.eyeGates"), min: 1, max: 99))
        scheduleStack.addArrangedSubview(row(L10n.tr("prefs.overlayColor"), bodyColor))
        scheduleStack.addArrangedSubview(bodyNotify)
        scheduleStack.addArrangedSubview(numberRow(L10n.tr("prefs.notificationLead"), bodyLead, unit: L10n.tr("prefs.unit.seconds"), min: 0, max: 3600))
        scheduleStack.addArrangedSubview(numberRow(L10n.tr("prefs.postponeMinutes"), bodyPostponeMinutes, unit: L10n.tr("prefs.unit.minutes"), min: 1, max: 120))
        scheduleStack.addArrangedSubview(numberRow(L10n.tr("prefs.maxPostpones"), bodyPostponeLimit, unit: L10n.tr("prefs.unit.times"), min: 0, max: 20))
        scheduleStack.addArrangedSubview(numberRow(L10n.tr("prefs.postponeWindowPercent"), bodyPostponeWindowPercent, unit: L10n.tr("prefs.unit.percent"), min: 0, max: 100))
        scheduleStack.addArrangedSubview(bodyAllowSkip)
        scheduleStack.addArrangedSubview(bodyManualFinish)
        scheduleStack.addArrangedSubview(bodyCoversAllDisplays)
        scheduleStack.addArrangedSubview(row(L10n.tr("prefs.bodyCoveredDisplay"), bodyCoveredDisplay))
        scheduleStack.addArrangedSubview(row(L10n.tr("prefs.bodyContentDisplay"), bodyContentDisplay))
        scheduleStack.addArrangedSubview(bodyBlankSecondaryDisplays)
        scheduleStack.addArrangedSubview(numberRow(L10n.tr("prefs.configuredDisplayIndex"), bodyConfiguredDisplayIndex, unit: "", min: 0, max: 16))
        addTab(to: tabView, title: L10n.tr("prefs.tabSchedule"), stack: scheduleStack)

        let contextStack = contentStack()
        contextStack.addArrangedSubview(section(L10n.tr("prefs.sectionContext"), symbolName: "scope"))
        contextStack.addArrangedSubview(naturalBreaks)
        contextStack.addArrangedSubview(numberRow(L10n.tr("prefs.naturalIdleMinutes"), naturalIdleMinutes, unit: L10n.tr("prefs.unit.minutes"), min: 1, max: 120))
        contextStack.addArrangedSubview(focusMonitor)
        contextStack.addArrangedSubview(focusDefersBody)
        contextStack.addArrangedSubview(workingHoursEnabled)
        contextStack.addArrangedSubview(row(L10n.tr("prefs.workingStart"), workingStart))
        contextStack.addArrangedSubview(row(L10n.tr("prefs.workingEnd"), workingEnd))
        contextStack.addArrangedSubview(separator())
        contextStack.addArrangedSubview(section(L10n.tr("prefs.sectionExclusion"), symbolName: "app.badge"))
        contextStack.addArrangedSubview(appExclusionEnabled)
        contextStack.addArrangedSubview(row(L10n.tr("prefs.name"), appExclusionName))
        contextStack.addArrangedSubview(row(L10n.tr("prefs.matchTerms"), appExclusionTerms))
        contextStack.addArrangedSubview(row(L10n.tr("prefs.mode"), appExclusionMode))
        contextStack.addArrangedSubview(appExclusionAppliesEye)
        contextStack.addArrangedSubview(appExclusionAppliesBody)
        contextStack.addArrangedSubview(appExclusionsAdvancedButton)
        let appExclusionsJSONRow = row(L10n.tr("prefs.advancedRulesJSON"), appExclusionsJSON)
        self.appExclusionsJSONRow = appExclusionsJSONRow
        contextStack.addArrangedSubview(appExclusionsJSONRow)
        addTab(to: tabView, title: L10n.tr("prefs.tabContext"), stack: contextStack)

        let appearanceStack = contentStack()
        appearanceStack.addArrangedSubview(section(L10n.tr("prefs.sectionPresentation"), symbolName: "paintbrush"))
        appearanceStack.addArrangedSubview(row(L10n.tr("prefs.theme"), themeSource))
        appearanceStack.addArrangedSubview(row(L10n.tr("prefs.menuBarStyle"), trayStyle))
        appearanceStack.addArrangedSubview(showMenuBarItem)
        appearanceStack.addArrangedSubview(row(L10n.tr("prefs.language"), languageIdentifier))
        appearanceStack.addArrangedSubview(currentTimeInBodyBreak)
        appearanceStack.addArrangedSubview(breakHealth)
        appearanceStack.addArrangedSubview(silentNotifications)
        appearanceStack.addArrangedSubview(row(L10n.tr("prefs.eyeStartSound"), soundPickerRow(eyeStartSound, eyeStartSoundPreview)))
        appearanceStack.addArrangedSubview(row(L10n.tr("prefs.eyeFinishSound"), soundPickerRow(eyeFinishSound, eyeFinishSoundPreview)))
        appearanceStack.addArrangedSubview(row(L10n.tr("prefs.bodyStartSound"), soundPickerRow(bodyStartSound, bodyStartSoundPreview)))
        appearanceStack.addArrangedSubview(row(L10n.tr("prefs.bodyFinishSound"), soundPickerRow(bodyFinishSound, bodyFinishSoundPreview)))
        appearanceStack.addArrangedSubview(row(L10n.tr("prefs.volume"), soundVolume))
        appearanceStack.addArrangedSubview(separator())
        appearanceStack.addArrangedSubview(section(L10n.tr("prefs.sectionCustomIdea"), symbolName: "text.bubble"))
        appearanceStack.addArrangedSubview(useBuiltInIdeas)
        appearanceStack.addArrangedSubview(row(L10n.tr("prefs.title"), customBodyTitle))
        appearanceStack.addArrangedSubview(row(L10n.tr("prefs.text"), customBodyText))
        appearanceStack.addArrangedSubview(customBodyIdeasAdvancedButton)
        let customBodyIdeasJSONRow = row(L10n.tr("prefs.advancedIdeasJSON"), customBodyIdeasJSON)
        self.customBodyIdeasJSONRow = customBodyIdeasJSONRow
        appearanceStack.addArrangedSubview(customBodyIdeasJSONRow)
        appearanceStack.addArrangedSubview(row(L10n.tr("prefs.localImagePath"), localImagePickerRow()))
        addTab(to: tabView, title: L10n.tr("prefs.tabAppearance"), stack: appearanceStack)

        let shortcutsStack = contentStack()
        shortcutsStack.addArrangedSubview(section(L10n.tr("prefs.sectionShortcuts"), symbolName: "keyboard"))
        shortcutsStack.addArrangedSubview(row(L10n.tr("prefs.pauseToggle"), shortcutPauseToggle))
        shortcutsStack.addArrangedSubview(row(L10n.tr("prefs.pause30Shortcut"), shortcutPause30))
        shortcutsStack.addArrangedSubview(row(L10n.tr("prefs.pause1hShortcut"), shortcutPause1h))
        shortcutsStack.addArrangedSubview(row(L10n.tr("prefs.pause2hShortcut"), shortcutPause2h))
        shortcutsStack.addArrangedSubview(row(L10n.tr("prefs.pause5hShortcut"), shortcutPause5h))
        shortcutsStack.addArrangedSubview(row(L10n.tr("prefs.pauseUntilMorningShortcut"), shortcutPauseUntilMorning))
        shortcutsStack.addArrangedSubview(row(L10n.tr("prefs.nextScheduledRest"), shortcutNextScheduled))
        shortcutsStack.addArrangedSubview(row(L10n.tr("prefs.eyeGateNow"), shortcutEyeNow))
        shortcutsStack.addArrangedSubview(row(L10n.tr("prefs.bodyBreakNow"), shortcutBodyNow))
        shortcutsStack.addArrangedSubview(row(L10n.tr("prefs.skipToBodyBreak"), shortcutSkipBody))
        shortcutsStack.addArrangedSubview(row(L10n.tr("prefs.endBodyBreak"), shortcutEndBody))
        let shortcutEmergencyEyeRow = row(L10n.tr("prefs.emergencyEyeGate"), shortcutEmergencyEye)
        self.shortcutEmergencyEyeRow = shortcutEmergencyEyeRow
        shortcutsStack.addArrangedSubview(shortcutEmergencyEyeRow)
        shortcutsStack.addArrangedSubview(row(L10n.tr("prefs.reset"), shortcutReset))
        addTab(to: tabView, title: L10n.tr("prefs.tabShortcuts"), stack: shortcutsStack)

        let advancedStack = contentStack()
        advancedStack.addArrangedSubview(section(L10n.tr("prefs.sectionOperations"), symbolName: "gearshape"))
        advancedStack.addArrangedSubview(openAtLogin)
        advancedStack.addArrangedSubview(checkUpdates)
        advancedStack.addArrangedSubview(notifyNewVersion)
        advancedStack.addArrangedSubview(showOnboardingNextLaunch)
        advancedStack.addArrangedSubview(row(L10n.tr("prefs.pauseUntilMorningMode"), pauseUntilMorningMode))
        advancedStack.addArrangedSubview(numberRow(L10n.tr("prefs.pauseUntilMorningHour"), pauseUntilMorningHour, unit: L10n.tr("prefs.unit.hour"), min: 0, max: 23))
        advancedStack.addArrangedSubview(row(L10n.tr("prefs.pauseUntilMorningLatitude"), pauseUntilMorningLatitude))
        advancedStack.addArrangedSubview(row(L10n.tr("prefs.pauseUntilMorningLongitude"), pauseUntilMorningLongitude))
        advancedStack.addArrangedSubview(pauseForSuspendOrLock)
        let updateFeedURLRow = row(L10n.tr("prefs.updateFeedURL"), updateFeedURL)
        self.updateFeedURLRow = updateFeedURLRow
        advancedStack.addArrangedSubview(updateFeedURLRow)
        advancedStack.addArrangedSubview(disableUpdateFeatures)
        advancedStack.addArrangedSubview(hideSettingsPath)
        advancedStack.addArrangedSubview(hideStrictPreferences)
        advancedStack.addArrangedSubview(row(L10n.tr("prefs.preferencesMessage"), customPreferencesMessage))
        addTab(to: tabView, title: L10n.tr("prefs.tabAdvanced"), stack: advancedStack)

        let footer = footerBar()
        root.addArrangedSubview(footer)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            tabView.widthAnchor.constraint(equalTo: root.widthAnchor),
            footer.widthAnchor.constraint(equalTo: root.widthAnchor)
        ])
    }

    private func footerBar() -> NSStackView {
        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.spacing = 12
        footer.alignment = .centerY
        footer.edgeInsets = NSEdgeInsets(top: 10, left: 24, bottom: 14, right: 24)
        let restoreDefaultsButton = NSButton(title: L10n.tr("prefs.restoreDefaults"), target: self, action: #selector(restoreDefaultsPressed))
        restoreDefaultsButton.image = NSImage(systemSymbolName: "arrow.counterclockwise", accessibilityDescription: nil)
        restoreDefaultsButton.imagePosition = .imageLeading
        saveStatusLabel.textColor = .secondaryLabelColor
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        footer.addArrangedSubview(saveStatusLabel)
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

    private func addTab(to tabView: NSTabView, title: String, stack: NSStackView) {
        let item = NSTabViewItem(identifier: title)
        item.label = title
        item.view = scrollContainer(for: stack)
        tabView.addTabViewItem(item)
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
        configurePopup(trayStyle, options: [
            (TrayIconStyle.default.rawValue, L10n.tr("prefs.trayStyle.default")),
            (TrayIconStyle.appName.rawValue, L10n.tr("prefs.trayStyle.appName")),
            (TrayIconStyle.timeToBreak.rawValue, L10n.tr("prefs.trayStyle.timeToBreak")),
            (TrayIconStyle.progress.rawValue, L10n.tr("prefs.trayStyle.progress"))
        ])
        configurePopup(pauseUntilMorningMode, options: [
            (MorningPauseMode.hour.rawValue, L10n.tr("prefs.morningMode.hour")),
            (MorningPauseMode.sunrise.rawValue, L10n.tr("prefs.morningMode.sunrise"))
        ])
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
    }

    private func configureFieldWidths() {
        let compactFields = [
            eyeInterval, eyeDuration, bodyInterval, bodyDuration, bodyAfterEyeGates, eyeLead, bodyLead,
            bodyPostponeMinutes, bodyPostponeLimit, bodyPostponeWindowPercent, naturalIdleMinutes, workingStart,
            workingEnd, soundVolume, bodyConfiguredDisplayIndex, pauseUntilMorningHour,
            pauseUntilMorningLatitude, pauseUntilMorningLongitude
        ]
        compactFields.forEach { $0.widthAnchor.constraint(equalToConstant: 110).isActive = true }
        [eyeColor, bodyColor].forEach { colorWell in
            colorWell.widthAnchor.constraint(equalToConstant: 56).isActive = true
            colorWell.heightAnchor.constraint(equalToConstant: 28).isActive = true
        }

        let wideFields: [NSView] = [
            eyeStartSound, eyeFinishSound, bodyStartSound, bodyFinishSound, customBodyTitle,
            customBodyText, customBodyIdeasJSON, localImagePath, languageIdentifier, shortcutPauseToggle,
            shortcutPause30, shortcutPause1h, shortcutPause2h, shortcutPause5h, shortcutPauseUntilMorning,
            shortcutNextScheduled, shortcutEyeNow, shortcutBodyNow, shortcutSkipBody, shortcutEndBody,
            shortcutEmergencyEye, shortcutReset,
            appExclusionName, appExclusionTerms, updateFeedURL,
            customPreferencesMessage, appExclusionsJSON
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
        let isCustomIdeas = button.identifier?.rawValue == "customIdeas"
        button.title = expanded
            ? (isCustomIdeas ? L10n.tr("prefs.hideAdvancedIdeas") : L10n.tr("prefs.hideAdvancedRules"))
            : (isCustomIdeas ? L10n.tr("prefs.showAdvancedIdeas") : L10n.tr("prefs.showAdvancedRules"))
        button.image = NSImage(
            systemSymbolName: expanded ? "chevron.down" : "chevron.right",
            accessibilityDescription: nil
        )
    }

    private func configureImagePickerControls() {
        localImagePath.isEditable = false
        localImagePath.isSelectable = true
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
            workingStart, workingEnd, appExclusionName, appExclusionTerms, appExclusionsJSON, soundVolume,
            customBodyTitle, customBodyText, customBodyIdeasJSON, localImagePath, bodyConfiguredDisplayIndex,
            pauseUntilMorningHour, pauseUntilMorningLatitude, pauseUntilMorningLongitude, updateFeedURL,
            customPreferencesMessage
        ]
        textFields.forEach { field in
            field.delegate = self
            field.target = self
            field.action = #selector(controlChanged(_:))
        }

        let controls: [NSControl] = [
            eyeColor, bodyColor, eyeNotify, eyeManualFinish, bodyNotify, bodyAllowSkip, bodyManualFinish, bodyCoversAllDisplays,
            bodyBlankSecondaryDisplays, naturalBreaks, focusMonitor, focusDefersBody, workingHoursEnabled,
            appExclusionEnabled, appExclusionAppliesEye, appExclusionAppliesBody, themeSource, trayStyle,
            showMenuBarItem, languageIdentifier, currentTimeInBodyBreak, breakHealth, silentNotifications,
            eyeStartSound, eyeFinishSound, bodyStartSound, bodyFinishSound, useBuiltInIdeas, openAtLogin,
            checkUpdates, notifyNewVersion, showOnboardingNextLaunch, pauseUntilMorningMode, pauseForSuspendOrLock,
            disableUpdateFeatures, hideSettingsPath, hideStrictPreferences, bodyCoveredDisplay, bodyContentDisplay
        ]
        controls.forEach { control in
            control.target = self
            control.action = #selector(controlChanged(_:))
        }

        [
            shortcutPauseToggle, shortcutPause30, shortcutPause1h, shortcutPause2h, shortcutPause5h,
            shortcutPauseUntilMorning, shortcutNextScheduled, shortcutEyeNow, shortcutBodyNow, shortcutSkipBody,
            shortcutEndBody, shortcutEmergencyEye, shortcutReset
        ].forEach { recorder in
            recorder.onChange = { [weak self] in
                self?.scheduleAutosave()
            }
        }
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
        button.target = self
        button.action = #selector(previewSound(_:))
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
    }

    private func loadSettings() {
        isLoadingSettings = true
        defer {
            isLoadingSettings = false
            saveStatusLabel.stringValue = L10n.tr("prefs.autosaveReady")
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
        bodyConfiguredDisplayIndex.stringValue = String(settings.bodyBreak.enforcement.configuredDisplayIndex ?? 0)

        naturalBreaks.state = state(settings.naturalBreaks.isEnabled)
        naturalIdleMinutes.stringValue = String(Int(settings.naturalBreaks.inactivityResetTime / 60))
        focusMonitor.state = state(settings.focusMode.monitorFocusMode)
        focusDefersBody.state = state(settings.focusMode.deferBodyBreak)
        workingHoursEnabled.state = state(settings.workingHours.isEnabled)
        workingStart.stringValue = Self.timeString(minutes: settings.workingHours.startMinuteOfDay)
        workingEnd.stringValue = Self.timeString(minutes: settings.workingHours.endMinuteOfDay)

        let exclusion = settings.appExclusions.first
        appExclusionEnabled.state = state(exclusion?.isEnabled ?? false)
        appExclusionName.stringValue = exclusion?.name ?? ""
        appExclusionTerms.stringValue = exclusion?.matchTerms.joined(separator: ", ") ?? ""
        selectPopup(appExclusionMode, rawValue: (exclusion?.mode ?? .pauseWhenMatched).rawValue)
        appExclusionAppliesEye.state = state(exclusion?.appliesTo.contains(.eyeGate) ?? false)
        appExclusionAppliesBody.state = state(exclusion?.appliesTo.contains(.bodyBreak) ?? true)
        appExclusionsJSON.stringValue = encodedAppExclusions(settings.appExclusions)
        setAdvancedDisclosure(
            row: appExclusionsJSONRow,
            button: appExclusionsAdvancedButton,
            expanded: !appExclusionsJSON.stringValue.isEmpty
        )

        selectPopup(themeSource, rawValue: settings.presentation.themeSource.rawValue)
        selectPopup(trayStyle, rawValue: settings.presentation.trayIconStyle.rawValue)
        showMenuBarItem.state = state(settings.presentation.resolvedShowMenuBarItem)
        selectLanguageOption(LanguageOption(identifier: settings.presentation.languageIdentifier))
        currentTimeInBodyBreak.state = state(settings.presentation.showCurrentTimeDuringBodyBreak)
        breakHealth.state = state(settings.presentation.breakHealthMode)
        silentNotifications.state = state(settings.notifications.silentNotifications)
        selectSoundOption(SoundOption(name: soundName(settings.eyeGate.startSound)), in: eyeStartSound)
        selectSoundOption(SoundOption(name: soundName(settings.eyeGate.finishSound)), in: eyeFinishSound)
        selectSoundOption(SoundOption(name: soundName(settings.bodyBreak.startSound)), in: bodyStartSound)
        selectSoundOption(SoundOption(name: soundName(settings.bodyBreak.finishSound)), in: bodyFinishSound)
        soundVolume.stringValue = String(preferredSoundVolume())

        let custom = settings.contentLibrary.customBodyBreakIdeas.first
        useBuiltInIdeas.state = state(settings.contentLibrary.useBuiltInIdeas)
        customBodyTitle.stringValue = custom?.title ?? ""
        customBodyText.stringValue = custom?.body ?? ""
        customBodyIdeasJSON.stringValue = encodedCustomIdeas(settings.contentLibrary.customBodyBreakIdeas)
        setAdvancedDisclosure(
            row: customBodyIdeasJSONRow,
            button: customBodyIdeasAdvancedButton,
            expanded: !customBodyIdeasJSON.stringValue.isEmpty
        )
        localImagePath.stringValue = settings.contentLibrary.localImagePaths.first ?? ""

        shortcutPauseToggle.shortcutValue = settings.shortcuts.pauseToggle
        shortcutPause30.shortcutValue = settings.shortcuts.pauseFor30Minutes
        shortcutPause1h.shortcutValue = settings.shortcuts.pauseFor1Hour
        shortcutPause2h.shortcutValue = settings.shortcuts.pauseFor2Hours
        shortcutPause5h.shortcutValue = settings.shortcuts.pauseFor5Hours
        shortcutPauseUntilMorning.shortcutValue = settings.shortcuts.pauseUntilMorning
        shortcutNextScheduled.shortcutValue = settings.shortcuts.skipToNextScheduledRest ?? ""
        shortcutEyeNow.shortcutValue = settings.shortcuts.takeEyeGateNow
        shortcutBodyNow.shortcutValue = settings.shortcuts.takeBodyBreakNow
        shortcutSkipBody.shortcutValue = settings.shortcuts.skipToNextBodyBreak
        shortcutEndBody.shortcutValue = settings.shortcuts.resolvedEndBodyBreakShortcut
        shortcutEmergencyEye.shortcutValue = settings.shortcuts.emergencyEyeGateOverride ?? ""
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
        syncNumberSteppersFromFields()
        applyAdminVisibility()
    }

    @objc private func savePressed() {
        _ = saveCurrentSettings(showAlerts: true)
    }

    @discardableResult
    private func saveCurrentSettings(showAlerts: Bool) -> Bool {
        let advancedAppExclusions: [AppExclusionRule]?
        let advancedCustomIdeas: [RestIdea]?
        do {
            advancedAppExclusions = try decodedAdvancedAppExclusions()
            advancedCustomIdeas = try decodedAdvancedCustomIdeas()
        } catch {
            if showAlerts {
                showInvalidJSONAlert(error)
            } else {
                saveStatusLabel.stringValue = L10n.tr("prefs.autosaveInvalid")
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
        next.bodyBreak.enforcement.configuredDisplayIndex = max(0, intValue(bodyConfiguredDisplayIndex))

        next.naturalBreaks = NaturalBreakSettings(
            isEnabled: isOn(naturalBreaks),
            inactivityResetTime: TimeInterval(max(1, intValue(naturalIdleMinutes)) * 60)
        )
        next.focusMode.monitorFocusMode = isOn(focusMonitor)
        next.focusMode.deferBodyBreak = isOn(focusDefersBody)
        next.workingHours = WorkingHoursSettings(
            isEnabled: isOn(workingHoursEnabled),
            startMinuteOfDay: Self.minutes(fromTimeString: workingStart.stringValue, fallback: 9 * 60),
            endMinuteOfDay: Self.minutes(fromTimeString: workingEnd.stringValue, fallback: 18 * 60)
        )

        next.appExclusions = advancedAppExclusions ?? savedAppExclusions()
        next.presentation.themeSource = selected(ThemeSource.self, from: themeSource, fallback: .system)
        next.presentation.trayIconStyle = selected(TrayIconStyle.self, from: trayStyle, fallback: .default)
        next.presentation.showMenuBarItem = isOn(showMenuBarItem)
        next.presentation.languageIdentifier = selectedLanguageOption().identifier
        next.presentation.showCurrentTimeDuringBodyBreak = isOn(currentTimeInBodyBreak)
        next.presentation.breakHealthMode = isOn(breakHealth)
        next.notifications.silentNotifications = isOn(silentNotifications)
        let volume = min(1, max(0, doubleValue(soundVolume, fallback: 1)))
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
        next.shortcuts.skipToNextBodyBreak = shortcutSkipBody.shortcutValue
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

        if next.eyeGate.manualFinishEnabled,
           !next.presentation.resolvedShowMenuBarItem,
           next.shortcuts.resolvedEndBodyBreakShortcut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            next.presentation.showMenuBarItem = true
            showMenuBarItem.state = .on
        }

        settings = next
        applyAdminVisibility()
        onSave(next)
        saveStatusLabel.stringValue = L10n.tr("prefs.autosaveSaved")
        return true
    }

    private func applyAdminVisibility() {
        bodyAllowSkip.isHidden = settings.admin.hideStrictPreferences
        shortcutEmergencyEyeRow?.isHidden = settings.admin.hideStrictPreferences

        let hideUpdateControls = settings.admin.disableAppUpdateFeatures
        checkUpdates.isHidden = hideUpdateControls
        notifyNewVersion.isHidden = hideUpdateControls
        updateFeedURLRow?.isHidden = hideUpdateControls
    }

    @objc private func restoreDefaultsPressed() {
        guard confirmRestoreDefaults() else { return }
        settings = .restoredDefaults
        loadSettings()
        onSave(settings)
        saveStatusLabel.stringValue = L10n.tr("prefs.autosaveRestored")
    }

    private func confirmRestoreDefaults() -> Bool {
        let alert = NSAlert()
        alert.messageText = L10n.tr("prefs.restoreDefaults")
        alert.informativeText = L10n.tr("prefs.restoreDefaultsWarning")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.tr("prefs.restoreDefaultsContinue"))
        alert.addButton(withTitle: L10n.tr("prefs.restoreDefaultsCancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    @objc private func restEnablementChanged(_ sender: NSButton) {
        guard !isOn(eyeEnabled), !isOn(bodyEnabled) else {
            scheduleAutosave()
            return
        }
        sender.state = .on
        showCannotDisableBothRestsAlert()
        scheduleAutosave()
    }

    @objc private func controlChanged(_ sender: Any) {
        scheduleAutosave()
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
        default:
            break
        }
    }

    private func setAdvancedDisclosure(row: NSView?, button: NSButton, expanded: Bool) {
        row?.isHidden = !expanded
        updateDisclosureButton(button, expanded: expanded)
    }

    func controlTextDidChange(_ obj: Notification) {
        guard !isLoadingSettings else { return }
        saveStatusLabel.stringValue = L10n.tr("prefs.autosaveEditing")
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if let field = obj.object as? NSTextField {
            syncNumberStepper(for: field)
        }
        scheduleAutosave()
    }

    private func scheduleAutosave() {
        guard !isLoadingSettings else { return }
        autosaveTask?.cancel()
        saveStatusLabel.stringValue = L10n.tr("prefs.autosaveSaving")
        autosaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            self?.saveCurrentSettings(showAlerts: false)
        }
    }

    @objc private func previewSound(_ sender: NSButton) {
        guard let popup = soundPopup(for: sender.identifier?.rawValue) else { return }
        let volume = min(1, max(0, doubleValue(soundVolume, fallback: 1)))
        soundPlayer.play(soundPolicy(from: popup, volume: volume))
    }

    @objc private func chooseLocalImagePressed() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = L10n.tr("prefs.chooseFile")

        if panel.runModal() == .OK, let url = panel.url {
            localImagePath.stringValue = url.path
            scheduleAutosave()
        }
    }

    @objc private func clearLocalImagePressed() {
        localImagePath.stringValue = ""
        scheduleAutosave()
    }

    @objc private func numberStepperChanged(_ sender: NSStepper) {
        guard let input = numberInputs.first(where: { $0.stepper === sender }) else { return }
        input.field.stringValue = String(Int(sender.doubleValue.rounded()))
        scheduleAutosave()
    }

    private func showCannotDisableBothRestsAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.tr("prefs.cannotDisableBothRests")
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func savedAppExclusions() -> [AppExclusionRule] {
        let terms = appExclusionTerms.stringValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard isOn(appExclusionEnabled), !terms.isEmpty else { return [] }

        var appliesTo: Set<RestKind> = []
        if isOn(appExclusionAppliesEye) {
            appliesTo.insert(.eyeGate)
        }
        if isOn(appExclusionAppliesBody) {
            appliesTo.insert(.bodyBreak)
        }
        if appliesTo.isEmpty {
            appliesTo.insert(.bodyBreak)
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
        let raw = appExclusionsJSON.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return nil }
        do {
            return try JSONDecoder().decode([AppExclusionRule].self, from: data)
        } catch {
            throw InvalidAdvancedJSON(fieldName: L10n.tr("prefs.advancedRulesJSON"), underlying: error)
        }
    }

    private func encodedAppExclusions(_ rules: [AppExclusionRule]) -> String {
        guard rules.count > 1,
              let data = try? JSONEncoder().encode(rules),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    private func savedCustomIdeas() -> [RestIdea] {
        let title = customBodyTitle.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = ContentSanitizer.sanitizeRichText(customBodyText.stringValue)
        guard !title.isEmpty || !body.isEmpty else { return [] }
        return [
            RestIdea(
                id: settings.contentLibrary.customBodyBreakIdeas.first?.id ?? UUID().uuidString,
                kind: .bodyBreak,
                title: title.isEmpty ? "Custom Body Break" : title,
                body: body,
                isEnabled: true
            )
        ]
    }

    private func decodedAdvancedCustomIdeas() throws -> [RestIdea]? {
        let raw = customBodyIdeasJSON.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
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
        guard bodyIdeas.count > 1,
              let data = try? JSONEncoder().encode(bodyIdeas),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    private func savedLocalImagePaths() -> [String] {
        let path = localImagePath.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, URL(string: path)?.scheme == nil else { return [] }
        return [path]
    }

    private func section(_ title: String, symbolName: String) -> NSStackView {
        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        imageView.contentTintColor = .secondaryLabelColor
        imageView.symbolConfiguration = .init(pointSize: 16, weight: .semibold)
        imageView.widthAnchor.constraint(equalToConstant: 22).isActive = true

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 15, weight: .semibold)

        let stack = NSStackView(views: [imageView, label])
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

    private func numberRow(
        _ title: String,
        _ field: NSTextField,
        unit: String,
        min: Double,
        max: Double
    ) -> NSStackView {
        field.alignment = .right

        let stepper = NSStepper()
        stepper.minValue = min
        stepper.maxValue = max
        stepper.increment = 1
        stepper.target = self
        stepper.action = #selector(numberStepperChanged(_:))

        numberInputs.append(NumberInput(field: field, stepper: stepper, min: min, max: max))

        let unitLabel = NSTextField(labelWithString: unit)
        unitLabel.textColor = .secondaryLabelColor
        unitLabel.widthAnchor.constraint(equalToConstant: unit.isEmpty ? 0 : 58).isActive = true

        let inputStack = NSStackView(views: [field, stepper, unitLabel])
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

    private func localImagePickerRow() -> NSStackView {
        let stack = NSStackView(views: [localImagePath, localImageChooseButton, localImageClearButton])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        return stack
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

    private func syncNumberSteppersFromFields() {
        numberInputs.forEach { syncNumberStepper(for: $0.field) }
    }

    private func syncNumberStepper(for field: NSTextField) {
        guard let input = numberInputs.first(where: { $0.field === field }) else { return }
        let value = min(input.max, max(input.min, Double(intValue(field))))
        input.stepper.doubleValue = value
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
        image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
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
        title = L10n.tr("shortcut.recording")
        toolTip = L10n.tr("shortcut.recordingHelp")
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
            shortcutValue = ""
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
            title = L10n.tr("shortcut.record")
            toolTip = L10n.tr("shortcut.recordHelp")
        } else {
            title = Self.displayString(shortcutValue)
            toolTip = L10n.tr("shortcut.clearHelp")
        }
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

    private static func displayString(_ shortcut: String) -> String {
        shortcut
            .split(separator: "+")
            .map { part in
                switch part.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "cmd", "command", "cmdorctrl":
                    return "⌘"
                case "ctrl", "control":
                    return "⌃"
                case "alt", "option", "opt":
                    return "⌥"
                case "shift":
                    return "⇧"
                case "space":
                    return "Space"
                default:
                    return part.uppercased()
                }
            }
            .joined()
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

import AppKit
import Foundation
import ShouldRestCore

@MainActor
final class PreferencesWindowController: NSWindowController {
    private var settings: RestSettings
    private let onSave: (RestSettings) -> Void
    private let adminMessageLabel = NSTextField(labelWithString: "")

    private let eyeEnabled = NSButton(checkboxWithTitle: L10n.tr("prefs.enableEyeGate"), target: nil, action: nil)
    private let eyeInterval = NSTextField()
    private let eyeDuration = NSTextField()
    private let eyeColor = NSTextField()
    private let eyeNotify = NSButton(checkboxWithTitle: L10n.tr("prefs.notifyEyeGate"), target: nil, action: nil)
    private let eyeLead = NSTextField()

    private let bodyEnabled = NSButton(checkboxWithTitle: L10n.tr("prefs.enableBodyBreak"), target: nil, action: nil)
    private let bodyInterval = NSTextField()
    private let bodyDuration = NSTextField()
    private let bodyAfterEyeGates = NSTextField()
    private let bodyColor = NSTextField()
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

    private let themeSource = NSPopUpButton()
    private let trayStyle = NSPopUpButton()
    private let showMenuBarItem = NSButton(checkboxWithTitle: L10n.tr("prefs.showMenuBarItem"), target: nil, action: nil)
    private let languageIdentifier = NSTextField()
    private let currentTimeInBodyBreak = NSButton(checkboxWithTitle: L10n.tr("prefs.currentTimeBody"), target: nil, action: nil)
    private let breakHealth = NSButton(checkboxWithTitle: L10n.tr("prefs.breakHealth"), target: nil, action: nil)
    private let silentNotifications = NSButton(checkboxWithTitle: L10n.tr("prefs.silentNotifications"), target: nil, action: nil)
    private let eyeStartSound = NSTextField()
    private let eyeFinishSound = NSTextField()
    private let bodyStartSound = NSTextField()
    private let bodyFinishSound = NSTextField()
    private let soundVolume = NSTextField()

    private let customBodyTitle = NSTextField()
    private let customBodyText = NSTextField()
    private let customBodyIdeasJSON = NSTextField()
    private let localImagePath = NSTextField()
    private let useBuiltInIdeas = NSButton(checkboxWithTitle: L10n.tr("prefs.useBuiltInIdeas"), target: nil, action: nil)

    private let shortcutPauseToggle = NSTextField()
    private let shortcutPause30 = NSTextField()
    private let shortcutPause1h = NSTextField()
    private let shortcutPause2h = NSTextField()
    private let shortcutPause5h = NSTextField()
    private let shortcutPauseUntilMorning = NSTextField()
    private let shortcutNextScheduled = NSTextField()
    private let shortcutEyeNow = NSTextField()
    private let shortcutBodyNow = NSTextField()
    private let shortcutSkipBody = NSTextField()
    private let shortcutEndBody = NSTextField()
    private let shortcutEmergencyEye = NSTextField()
    private let shortcutReset = NSTextField()

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
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 760),
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

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor)
        ])

        configurePopups()
        configureFieldWidths()
        configureEnablementGuards()

        adminMessageLabel.lineBreakMode = .byWordWrapping
        adminMessageLabel.widthAnchor.constraint(equalToConstant: 620).isActive = true
        stack.addArrangedSubview(adminMessageLabel)

        stack.addArrangedSubview(section(L10n.tr("prefs.sectionEyeGate")))
        stack.addArrangedSubview(eyeEnabled)
        stack.addArrangedSubview(row(L10n.tr("prefs.everyMinutes"), eyeInterval))
        stack.addArrangedSubview(row(L10n.tr("prefs.durationSeconds"), eyeDuration))
        stack.addArrangedSubview(row(L10n.tr("prefs.overlayColor"), eyeColor))
        stack.addArrangedSubview(eyeNotify)
        stack.addArrangedSubview(row(L10n.tr("prefs.notificationLead"), eyeLead))

        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(section(L10n.tr("prefs.sectionBodyBreak")))
        stack.addArrangedSubview(bodyEnabled)
        stack.addArrangedSubview(row(L10n.tr("prefs.bodyIntervalMinutes"), bodyInterval))
        stack.addArrangedSubview(row(L10n.tr("prefs.durationMinutes"), bodyDuration))
        stack.addArrangedSubview(row(L10n.tr("prefs.afterEyeGates"), bodyAfterEyeGates))
        stack.addArrangedSubview(row(L10n.tr("prefs.overlayColor"), bodyColor))
        stack.addArrangedSubview(bodyNotify)
        stack.addArrangedSubview(row(L10n.tr("prefs.notificationLead"), bodyLead))
        stack.addArrangedSubview(row(L10n.tr("prefs.postponeMinutes"), bodyPostponeMinutes))
        stack.addArrangedSubview(row(L10n.tr("prefs.maxPostpones"), bodyPostponeLimit))
        stack.addArrangedSubview(row(L10n.tr("prefs.postponeWindowPercent"), bodyPostponeWindowPercent))
        stack.addArrangedSubview(bodyAllowSkip)
        stack.addArrangedSubview(bodyManualFinish)
        stack.addArrangedSubview(bodyCoversAllDisplays)
        stack.addArrangedSubview(row(L10n.tr("prefs.bodyCoveredDisplay"), bodyCoveredDisplay))
        stack.addArrangedSubview(row(L10n.tr("prefs.bodyContentDisplay"), bodyContentDisplay))
        stack.addArrangedSubview(bodyBlankSecondaryDisplays)
        stack.addArrangedSubview(row(L10n.tr("prefs.configuredDisplayIndex"), bodyConfiguredDisplayIndex))

        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(section(L10n.tr("prefs.sectionContext")))
        stack.addArrangedSubview(naturalBreaks)
        stack.addArrangedSubview(row(L10n.tr("prefs.naturalIdleMinutes"), naturalIdleMinutes))
        stack.addArrangedSubview(focusMonitor)
        stack.addArrangedSubview(focusDefersBody)
        stack.addArrangedSubview(workingHoursEnabled)
        stack.addArrangedSubview(row(L10n.tr("prefs.workingStart"), workingStart))
        stack.addArrangedSubview(row(L10n.tr("prefs.workingEnd"), workingEnd))

        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(section(L10n.tr("prefs.sectionExclusion")))
        stack.addArrangedSubview(appExclusionEnabled)
        stack.addArrangedSubview(row(L10n.tr("prefs.name"), appExclusionName))
        stack.addArrangedSubview(row(L10n.tr("prefs.matchTerms"), appExclusionTerms))
        stack.addArrangedSubview(row(L10n.tr("prefs.mode"), appExclusionMode))
        stack.addArrangedSubview(appExclusionAppliesEye)
        stack.addArrangedSubview(appExclusionAppliesBody)
        stack.addArrangedSubview(row(L10n.tr("prefs.advancedRulesJSON"), appExclusionsJSON))

        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(section(L10n.tr("prefs.sectionPresentation")))
        stack.addArrangedSubview(row(L10n.tr("prefs.theme"), themeSource))
        stack.addArrangedSubview(row(L10n.tr("prefs.menuBarStyle"), trayStyle))
        stack.addArrangedSubview(showMenuBarItem)
        stack.addArrangedSubview(row(L10n.tr("prefs.language"), languageIdentifier))
        stack.addArrangedSubview(currentTimeInBodyBreak)
        stack.addArrangedSubview(breakHealth)
        stack.addArrangedSubview(silentNotifications)
        stack.addArrangedSubview(row(L10n.tr("prefs.eyeStartSound"), eyeStartSound))
        stack.addArrangedSubview(row(L10n.tr("prefs.eyeFinishSound"), eyeFinishSound))
        stack.addArrangedSubview(row(L10n.tr("prefs.bodyStartSound"), bodyStartSound))
        stack.addArrangedSubview(row(L10n.tr("prefs.bodyFinishSound"), bodyFinishSound))
        stack.addArrangedSubview(row(L10n.tr("prefs.volume"), soundVolume))

        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(section(L10n.tr("prefs.sectionCustomIdea")))
        stack.addArrangedSubview(useBuiltInIdeas)
        stack.addArrangedSubview(row(L10n.tr("prefs.title"), customBodyTitle))
        stack.addArrangedSubview(row(L10n.tr("prefs.text"), customBodyText))
        stack.addArrangedSubview(row(L10n.tr("prefs.advancedIdeasJSON"), customBodyIdeasJSON))
        stack.addArrangedSubview(row(L10n.tr("prefs.localImagePath"), localImagePath))

        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(section(L10n.tr("prefs.sectionShortcuts")))
        stack.addArrangedSubview(row(L10n.tr("prefs.pauseToggle"), shortcutPauseToggle))
        stack.addArrangedSubview(row(L10n.tr("prefs.pause30Shortcut"), shortcutPause30))
        stack.addArrangedSubview(row(L10n.tr("prefs.pause1hShortcut"), shortcutPause1h))
        stack.addArrangedSubview(row(L10n.tr("prefs.pause2hShortcut"), shortcutPause2h))
        stack.addArrangedSubview(row(L10n.tr("prefs.pause5hShortcut"), shortcutPause5h))
        stack.addArrangedSubview(row(L10n.tr("prefs.pauseUntilMorningShortcut"), shortcutPauseUntilMorning))
        stack.addArrangedSubview(row(L10n.tr("prefs.nextScheduledRest"), shortcutNextScheduled))
        stack.addArrangedSubview(row(L10n.tr("prefs.eyeGateNow"), shortcutEyeNow))
        stack.addArrangedSubview(row(L10n.tr("prefs.bodyBreakNow"), shortcutBodyNow))
        stack.addArrangedSubview(row(L10n.tr("prefs.skipToBodyBreak"), shortcutSkipBody))
        stack.addArrangedSubview(row(L10n.tr("prefs.endBodyBreak"), shortcutEndBody))
        stack.addArrangedSubview(row(L10n.tr("prefs.emergencyEyeGate"), shortcutEmergencyEye))
        stack.addArrangedSubview(row(L10n.tr("prefs.reset"), shortcutReset))

        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(section(L10n.tr("prefs.sectionOperations")))
        stack.addArrangedSubview(openAtLogin)
        stack.addArrangedSubview(checkUpdates)
        stack.addArrangedSubview(notifyNewVersion)
        stack.addArrangedSubview(showOnboardingNextLaunch)
        stack.addArrangedSubview(row(L10n.tr("prefs.pauseUntilMorningMode"), pauseUntilMorningMode))
        stack.addArrangedSubview(row(L10n.tr("prefs.pauseUntilMorningHour"), pauseUntilMorningHour))
        stack.addArrangedSubview(row(L10n.tr("prefs.pauseUntilMorningLatitude"), pauseUntilMorningLatitude))
        stack.addArrangedSubview(row(L10n.tr("prefs.pauseUntilMorningLongitude"), pauseUntilMorningLongitude))
        stack.addArrangedSubview(pauseForSuspendOrLock)
        let updateFeedURLRow = row(L10n.tr("prefs.updateFeedURL"), updateFeedURL)
        self.updateFeedURLRow = updateFeedURLRow
        stack.addArrangedSubview(updateFeedURLRow)
        stack.addArrangedSubview(disableUpdateFeatures)
        stack.addArrangedSubview(hideSettingsPath)
        stack.addArrangedSubview(hideStrictPreferences)
        stack.addArrangedSubview(row(L10n.tr("prefs.preferencesMessage"), customPreferencesMessage))

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 12
        buttons.alignment = .centerY
        buttons.addArrangedSubview(NSButton(title: L10n.tr("prefs.save"), target: self, action: #selector(savePressed)))
        buttons.addArrangedSubview(NSButton(title: L10n.tr("prefs.restoreDefaults"), target: self, action: #selector(restoreDefaultsPressed)))
        stack.addArrangedSubview(buttons)
    }

    private func configurePopups() {
        appExclusionMode.addItems(withTitles: AppExclusionRule.Mode.allCases.map(\.rawValue))
        themeSource.addItems(withTitles: ThemeSource.allCases.map(\.rawValue))
        trayStyle.addItems(withTitles: TrayIconStyle.allCases.map(\.rawValue))
        pauseUntilMorningMode.addItems(withTitles: MorningPauseMode.allCases.map(\.rawValue))
        bodyCoveredDisplay.addItems(withTitles: [
            DisplaySelection.primary.rawValue,
            DisplaySelection.cursor.rawValue,
            DisplaySelection.configured.rawValue
        ])
        bodyContentDisplay.addItems(withTitles: [
            DisplaySelection.all.rawValue,
            DisplaySelection.primary.rawValue,
            DisplaySelection.cursor.rawValue,
            DisplaySelection.configured.rawValue,
            DisplaySelection.none.rawValue
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

        let wideFields = [
            eyeColor, bodyColor, eyeStartSound, eyeFinishSound, bodyStartSound, bodyFinishSound, customBodyTitle,
            customBodyText, customBodyIdeasJSON, localImagePath, languageIdentifier, shortcutPauseToggle,
            shortcutPause30, shortcutPause1h, shortcutPause2h, shortcutPause5h, shortcutPauseUntilMorning,
            shortcutNextScheduled, shortcutEyeNow, shortcutBodyNow, shortcutSkipBody, shortcutEndBody,
            shortcutEmergencyEye, shortcutReset,
            appExclusionName, appExclusionTerms, updateFeedURL,
            customPreferencesMessage, appExclusionsJSON
        ]
        wideFields.forEach { $0.widthAnchor.constraint(equalToConstant: 320).isActive = true }
    }

    private func configureEnablementGuards() {
        eyeEnabled.target = self
        eyeEnabled.action = #selector(restEnablementChanged(_:))
        bodyEnabled.target = self
        bodyEnabled.action = #selector(restEnablementChanged(_:))
    }

    private func loadSettings() {
        adminMessageLabel.stringValue = settings.admin.customPreferencesMessage
        adminMessageLabel.isHidden = settings.admin.customPreferencesMessage.isEmpty

        eyeEnabled.state = state(settings.eyeGate.isEnabled)
        eyeInterval.stringValue = String(Int(settings.eyeGate.interval / 60))
        eyeDuration.stringValue = String(Int(settings.eyeGate.duration))
        eyeColor.stringValue = settings.eyeGate.colorHex
        eyeNotify.state = state(settings.notifications.eyeGateEnabled)
        eyeLead.stringValue = String(Int(settings.notifications.eyeGateLeadTime))

        bodyEnabled.state = state(settings.bodyBreak.isEnabled)
        bodyInterval.stringValue = String(Int(settings.bodyBreak.interval / 60))
        bodyDuration.stringValue = String(Int(settings.bodyBreak.duration / 60))
        bodyAfterEyeGates.stringValue = String(settings.bodyBreakAfterEyeGates)
        bodyColor.stringValue = settings.bodyBreak.colorHex
        bodyNotify.state = state(settings.notifications.bodyBreakEnabled)
        bodyLead.stringValue = String(Int(settings.notifications.bodyBreakLeadTime))
        bodyPostponeMinutes.stringValue = String(Int(settings.bodyBreak.postpone.duration / 60))
        bodyPostponeLimit.stringValue = String(settings.bodyBreak.postpone.maxCount)
        bodyPostponeWindowPercent.stringValue = String(Int(settings.bodyBreak.postpone.allowedDuringFirstPercent))
        bodyAllowSkip.state = state(settings.bodyBreak.ordinarySkipEnabled)
        bodyManualFinish.state = state(settings.bodyBreak.manualFinishEnabled)
        bodyCoversAllDisplays.state = state(settings.bodyBreak.enforcement.coversAllDisplays)
        bodyCoveredDisplay.selectItem(withTitle: (settings.bodyBreak.enforcement.coveredDisplay ?? .primary).rawValue)
        bodyContentDisplay.selectItem(withTitle: settings.bodyBreak.enforcement.contentDisplay.rawValue)
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
        appExclusionMode.selectItem(withTitle: (exclusion?.mode ?? .pauseWhenMatched).rawValue)
        appExclusionAppliesEye.state = state(exclusion?.appliesTo.contains(.eyeGate) ?? false)
        appExclusionAppliesBody.state = state(exclusion?.appliesTo.contains(.bodyBreak) ?? true)
        appExclusionsJSON.stringValue = encodedAppExclusions(settings.appExclusions)

        themeSource.selectItem(withTitle: settings.presentation.themeSource.rawValue)
        trayStyle.selectItem(withTitle: settings.presentation.trayIconStyle.rawValue)
        showMenuBarItem.state = state(settings.presentation.resolvedShowMenuBarItem)
        languageIdentifier.stringValue = settings.presentation.languageIdentifier ?? ""
        currentTimeInBodyBreak.state = state(settings.presentation.showCurrentTimeDuringBodyBreak)
        breakHealth.state = state(settings.presentation.breakHealthMode)
        silentNotifications.state = state(settings.notifications.silentNotifications)
        eyeStartSound.stringValue = soundName(settings.eyeGate.startSound)
        eyeFinishSound.stringValue = soundName(settings.eyeGate.finishSound)
        bodyStartSound.stringValue = soundName(settings.bodyBreak.startSound)
        bodyFinishSound.stringValue = soundName(settings.bodyBreak.finishSound)
        soundVolume.stringValue = String(preferredSoundVolume())

        let custom = settings.contentLibrary.customBodyBreakIdeas.first
        useBuiltInIdeas.state = state(settings.contentLibrary.useBuiltInIdeas)
        customBodyTitle.stringValue = custom?.title ?? ""
        customBodyText.stringValue = custom?.body ?? ""
        customBodyIdeasJSON.stringValue = encodedCustomIdeas(settings.contentLibrary.customBodyBreakIdeas)
        localImagePath.stringValue = settings.contentLibrary.localImagePaths.first ?? ""

        shortcutPauseToggle.stringValue = settings.shortcuts.pauseToggle
        shortcutPause30.stringValue = settings.shortcuts.pauseFor30Minutes
        shortcutPause1h.stringValue = settings.shortcuts.pauseFor1Hour
        shortcutPause2h.stringValue = settings.shortcuts.pauseFor2Hours
        shortcutPause5h.stringValue = settings.shortcuts.pauseFor5Hours
        shortcutPauseUntilMorning.stringValue = settings.shortcuts.pauseUntilMorning
        shortcutNextScheduled.stringValue = settings.shortcuts.skipToNextScheduledRest ?? ""
        shortcutEyeNow.stringValue = settings.shortcuts.takeEyeGateNow
        shortcutBodyNow.stringValue = settings.shortcuts.takeBodyBreakNow
        shortcutSkipBody.stringValue = settings.shortcuts.skipToNextBodyBreak
        shortcutEndBody.stringValue = settings.shortcuts.endBodyBreak ?? ""
        shortcutEmergencyEye.stringValue = settings.shortcuts.emergencyEyeGateOverride ?? ""
        shortcutReset.stringValue = settings.shortcuts.reset

        openAtLogin.state = state(settings.operations.openAtLogin)
        checkUpdates.state = state(settings.operations.checkForUpdates)
        notifyNewVersion.state = state(settings.operations.notifyNewVersion)
        showOnboardingNextLaunch.state = state(settings.operations.resolvedShowOnboardingOnNextLaunch)
        pauseUntilMorningMode.selectItem(withTitle: settings.operations.resolvedPauseUntilMorningMode.rawValue)
        pauseUntilMorningHour.stringValue = String(settings.operations.resolvedPauseUntilMorningHour)
        pauseUntilMorningLatitude.stringValue = String(settings.operations.pauseUntilMorningLatitude ?? 0)
        pauseUntilMorningLongitude.stringValue = String(settings.operations.pauseUntilMorningLongitude ?? 0)
        pauseForSuspendOrLock.state = state(settings.operations.resolvedPauseForSuspendOrLock)
        updateFeedURL.stringValue = settings.operations.updateFeedURL
        disableUpdateFeatures.state = state(settings.admin.disableAppUpdateFeatures)
        hideSettingsPath.state = state(settings.admin.hideSettingsFileLocation)
        hideStrictPreferences.state = state(settings.admin.hideStrictPreferences)
        customPreferencesMessage.stringValue = settings.admin.customPreferencesMessage
        applyAdminVisibility()
    }

    @objc private func savePressed() {
        var next = settings
        next.eyeGate.isEnabled = isOn(eyeEnabled)
        next.eyeGate.interval = TimeInterval(max(1, intValue(eyeInterval)) * 60)
        next.eyeGate.duration = TimeInterval(max(1, intValue(eyeDuration)))
        next.eyeGate.colorHex = normalizedHex(eyeColor.stringValue, fallback: RestSettings.defaults.eyeGate.colorHex)
        next.notifications.eyeGateEnabled = isOn(eyeNotify)
        next.notifications.eyeGateLeadTime = TimeInterval(max(0, intValue(eyeLead)))

        next.bodyBreak.isEnabled = isOn(bodyEnabled)
        if !next.eyeGate.isEnabled && !next.bodyBreak.isEnabled {
            next.eyeGate.isEnabled = true
            eyeEnabled.state = .on
            showCannotDisableBothRestsAlert()
        }
        next.bodyBreak.interval = TimeInterval(max(1, intValue(bodyInterval)) * 60)
        next.bodyBreak.duration = TimeInterval(max(1, intValue(bodyDuration)) * 60)
        next.bodyBreakAfterEyeGates = max(1, intValue(bodyAfterEyeGates))
        next.bodyBreak.colorHex = normalizedHex(bodyColor.stringValue, fallback: RestSettings.defaults.bodyBreak.colorHex)
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

        next.appExclusions = savedAdvancedAppExclusions() ?? savedAppExclusions()
        next.presentation.themeSource = selected(ThemeSource.self, from: themeSource, fallback: .system)
        next.presentation.trayIconStyle = selected(TrayIconStyle.self, from: trayStyle, fallback: .default)
        next.presentation.showMenuBarItem = isOn(showMenuBarItem)
        next.presentation.languageIdentifier = optionalString(languageIdentifier.stringValue)
        next.presentation.showCurrentTimeDuringBodyBreak = isOn(currentTimeInBodyBreak)
        next.presentation.breakHealthMode = isOn(breakHealth)
        next.notifications.silentNotifications = isOn(silentNotifications)
        let volume = min(1, max(0, doubleValue(soundVolume, fallback: 1)))
        next.eyeGate.startSound = soundPolicy(name: eyeStartSound.stringValue, volume: volume)
        next.eyeGate.finishSound = soundPolicy(name: eyeFinishSound.stringValue, volume: volume)
        next.bodyBreak.startSound = soundPolicy(name: bodyStartSound.stringValue, volume: volume)
        next.bodyBreak.finishSound = soundPolicy(name: bodyFinishSound.stringValue, volume: volume)

        next.contentLibrary.useBuiltInIdeas = isOn(useBuiltInIdeas)
        next.contentLibrary.customBodyBreakIdeas = savedAdvancedCustomIdeas() ?? savedCustomIdeas()
        next.contentLibrary.localImagePaths = savedLocalImagePaths()
        next.bodyBreak.content = next.contentLibrary.localImagePaths.isEmpty ? .richRestIdea : .localImage
        next.shortcuts.pauseToggle = shortcutPauseToggle.stringValue
        next.shortcuts.pauseFor30Minutes = shortcutPause30.stringValue
        next.shortcuts.pauseFor1Hour = shortcutPause1h.stringValue
        next.shortcuts.pauseFor2Hours = shortcutPause2h.stringValue
        next.shortcuts.pauseFor5Hours = shortcutPause5h.stringValue
        next.shortcuts.pauseUntilMorning = shortcutPauseUntilMorning.stringValue
        next.shortcuts.skipToNextScheduledRest = shortcutNextScheduled.stringValue
        next.shortcuts.takeEyeGateNow = shortcutEyeNow.stringValue
        next.shortcuts.takeBodyBreakNow = shortcutBodyNow.stringValue
        next.shortcuts.skipToNextBodyBreak = shortcutSkipBody.stringValue
        next.shortcuts.endBodyBreak = shortcutEndBody.stringValue
        next.shortcuts.emergencyEyeGateOverride = shortcutEmergencyEye.stringValue
        next.shortcuts.reset = shortcutReset.stringValue

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
    }

    private func applyAdminVisibility() {
        bodyAllowSkip.isHidden = settings.admin.hideStrictPreferences

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
        guard !isOn(eyeEnabled), !isOn(bodyEnabled) else { return }
        sender.state = .on
        showCannotDisableBothRestsAlert()
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

    private func savedAdvancedAppExclusions() -> [AppExclusionRule]? {
        let raw = appExclusionsJSON.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([AppExclusionRule].self, from: data)
    }

    private func encodedAppExclusions(_ rules: [AppExclusionRule]) -> String {
        guard !rules.isEmpty,
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

    private func savedAdvancedCustomIdeas() -> [RestIdea]? {
        let raw = customBodyIdeasJSON.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return nil }
        guard let decoded = try? JSONDecoder().decode([RestIdea].self, from: data) else { return nil }
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
    }

    private func encodedCustomIdeas(_ ideas: [RestIdea]) -> String {
        let bodyIdeas = ideas.filter { $0.kind == .bodyBreak }
        guard !bodyIdeas.isEmpty,
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

    private func section(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        return label
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

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
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

    private func doubleValue(_ field: NSTextField, fallback: Double) -> Double {
        Double(field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? fallback
    }

    private func optionalString(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
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
        guard let title = popup.selectedItem?.title, let value = T(rawValue: title) else {
            return fallback
        }
        return value
    }

    private func soundPolicy(name: String, volume: Double) -> SoundPolicy {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "silence" ? .silent : .named(trimmed, volume: volume)
    }

    private func soundName(_ policy: SoundPolicy) -> String {
        switch policy {
        case .silent:
            "silence"
        case .named(let name, _):
            name
        }
    }

    private func soundVolumeValue(_ policy: SoundPolicy) -> Double {
        switch policy {
        case .silent:
            1
        case .named(_, let volume):
            volume
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

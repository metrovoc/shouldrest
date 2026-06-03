import AppKit
import Carbon
import Foundation
import IOKit
import ShouldRestCore
import UserNotifications

@MainActor
final class ShouldRestAppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore: SettingsStore
    private let logger = AppLogger()
    private var settings: RestSettings
    private var engine: RestEngine
    private let overlayController = OverlayController()
    private let focusDetector = FocusModeDetector()
    private let soundPlayer = SoundPlayer()
    private let globalShortcuts = GlobalShortcutManager()
    private let updateChecker = UpdateChecker()
    private var preferencesWindowController: PreferencesWindowController?
    private var debugWindowController: DebugWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private var statusItem: NSStatusItem?
    private var tickTimer: Timer?
    private var lastFocusCheck = Date.distantPast
    private var focusModeActive = false
    private var suspendedAt: Date?
    private var pausedForSuspendOrLock = false
    private var manualAwaitingSessionID: UUID?
    private var latestReleaseURL: URL?
    private var pendingBodyBreakIdea: RestIdea?
    private var activeBodyBreakIdeas: [UUID: RestIdea] = [:]
    private var automationTasks: [UUID: Task<Void, Never>] = [:]

    override init() {
        let store = SettingsStore(fileURL: AppPaths.settingsURL)
        self.settingsStore = store
        self.settings = (try? store.load()) ?? .defaults
        self.engine = RestEngine(settings: settings)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        applyLanguageSetting()
        applyMenuBarVisibility()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleAutomation(_:)),
            name: .shouldRestAutomation,
            object: nil
        )
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        let workspaceNotifications = NSWorkspace.shared.notificationCenter
        workspaceNotifications.addObserver(self, selector: #selector(systemWillPause), name: NSWorkspace.willSleepNotification, object: nil)
        workspaceNotifications.addObserver(self, selector: #selector(systemDidResume), name: NSWorkspace.didWakeNotification, object: nil)
        workspaceNotifications.addObserver(self, selector: #selector(systemWillPause), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        workspaceNotifications.addObserver(self, selector: #selector(systemDidResume), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        logger.log("Application launched")
        applyAppearanceSetting()
        applyOpenAtLoginSetting()
        configureGlobalShortcuts()
        scheduleAutomaticUpdateCheck()
        tick()
        showOnboardingIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        tickTimer?.invalidate()
        overlayController.dismiss()
        logger.log("Application terminated")
    }

    @objc private func screenParametersChanged() {
        overlayController.reconcile()
    }

    private func createStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "ShouldRest"
        statusItem = item
        rebuildMenu()
    }

    private func applyMenuBarVisibility() {
        if settings.presentation.resolvedShowMenuBarItem {
            createStatusItem()
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func tick() {
        let now = Date()

        if now.timeIntervalSince(lastFocusCheck) > 5 {
            focusModeActive = focusDetector.isFocusModeActive()
            lastFocusCheck = now
        }

        if let active = engine.state.activeSession {
            let elapsed = now.timeIntervalSince(active.startedAt)
            let shouldAwaitManualFinish = elapsed >= active.duration && active.manualFinishEnabled
            overlayController.update(
                session: active,
                settings: overlaySettings(for: active),
                now: now,
                manualAwaiting: shouldAwaitManualFinish
            )
            if shouldAwaitManualFinish {
                if manualAwaitingSessionID != active.id {
                    manualAwaitingSessionID = active.id
                    soundPlayer.play(settings.rule(for: active.kind).finishSound)
                    logger.log("Entered manual finish phase for \(active.kind.rawValue)")
                }
                rebuildMenu()
                return
            }
            if elapsed >= active.duration {
                soundPlayer.play(settings.rule(for: active.kind).finishSound)
                _ = engine.completeActive(now: now, reason: .completed)
                overlayController.dismiss()
                manualAwaitingSessionID = nil
                clearActiveBodyBreakIdea(for: active)
                logger.log("Completed \(active.kind.rawValue)")
                rebuildMenu()
                return
            }
            rebuildMenu()
            return
        }

        let result = engine.evaluate(now: now, context: currentContext())
        handleEngineResult(result, now: now)
        rebuildMenu()
    }

    private func handleEngineResult(_ result: RestEngineResult, now: Date) {
        switch result {
        case .started(let session):
            bindPendingBodyBreakIdea(to: session)
            soundPlayer.play(settings.rule(for: session.kind).startSound)
            overlayController.present(session: session, settings: overlaySettings(for: session), now: now)
            logger.log("Started \(session.kind.rawValue)")
        case .notificationDue(let kind):
            showNotification(for: kind)
            logger.log("Notification due for \(kind.rawValue)")
        default:
            break
        }
    }

    private func currentContext() -> RestContext {
        let appExclusions = settings.appExclusions.map { rule in
            AppExclusionEvaluation(rule: rule, isMatched: RunningApplications.matches(rule: rule))
        }
        return RestContext(
            idleDuration: SystemIdleTime.seconds(),
            focusModeActive: focusModeActive,
            inWorkingHours: settings.workingHours.contains(Date()),
            appExclusions: appExclusions
        )
    }

    private func showNotification(for kind: RestKind) {
        showAppNotification(
            title: L10n.tr("app.name"),
            body: kind == .eyeGate ? L10n.tr("notification.eyeGateSoon") : L10n.tr("notification.bodyBreakSoon")
        )
    }

    private func rebuildMenu() {
        guard let item = statusItem else { return }
        item.button?.title = menuBarTitle()

        let menu = NSMenu()
        if !settings.admin.disableAppUpdateFeatures, latestReleaseURL != nil {
            menu.addItem(actionItem(L10n.tr("menu.downloadLatest"), #selector(openLatestRelease)))
            menu.addItem(.separator())
        }
        menu.addItem(disabledItem(statusText()))
        if settings.presentation.breakHealthMode {
            menu.addItem(disabledItem(L10n.format("status.health", engine.state.dangerScore)))
        }
        menu.addItem(.separator())

        if engine.state.activeSession == nil {
            menu.addItem(actionItem(L10n.tr("menu.takeEyeGateNow"), #selector(takeEyeGateNow)))
            menu.addItem(actionItem(L10n.tr("menu.takeBodyBreakNow"), #selector(takeBodyBreakNow)))
            if engine.state.scheduled != nil {
                menu.addItem(actionItem(L10n.tr("menu.takeNextScheduledRestNow"), #selector(takeNextScheduledRestNow)))
            }
            menu.addItem(.separator())
        }

        if let active = engine.state.activeSession,
           active.kind == .eyeGate,
           settings.eyeGate.emergencyOverride.isEnabled {
            menu.addItem(actionItem(L10n.tr("menu.emergencyOverride"), #selector(emergencyOverrideEyeGate)))
            menu.addItem(.separator())
        }

        if let active = engine.state.activeSession, active.kind == .bodyBreak {
            let now = Date()
            var addedBodyAction = false
            if canPostponeBodyBreak(active, now: now) {
                menu.addItem(actionItem(L10n.tr("menu.postponeBodyBreak"), #selector(postponeBodyBreak)))
                addedBodyAction = true
            }
            if now.timeIntervalSince(active.startedAt) >= active.duration {
                menu.addItem(actionItem(L10n.tr("menu.finishBodyBreak"), #selector(finishActiveBreak)))
                addedBodyAction = true
            }
            if canSkipBodyBreak(active, now: now) {
                menu.addItem(actionItem(L10n.tr("menu.skipBodyBreak"), #selector(skipBodyBreak)))
                addedBodyAction = true
            }
            if addedBodyAction {
                menu.addItem(.separator())
            }
        }

        if engine.state.pause != nil {
            menu.addItem(actionItem(L10n.tr("menu.resume"), #selector(resumeBreaks)))
        } else if engine.state.activeSession == nil {
            let pauseMenu = NSMenu()
            pauseMenu.addItem(actionItem(L10n.tr("menu.pause30"), #selector(pauseFor30Minutes)))
            pauseMenu.addItem(actionItem(L10n.tr("menu.pause1h"), #selector(pauseFor1Hour)))
            pauseMenu.addItem(actionItem(L10n.tr("menu.pause2h"), #selector(pauseFor2Hours)))
            pauseMenu.addItem(actionItem(L10n.tr("menu.pause5h"), #selector(pauseFor5Hours)))
            pauseMenu.addItem(actionItem(L10n.tr("menu.pauseUntilMorning"), #selector(pauseUntilMorning)))
            pauseMenu.addItem(.separator())
            pauseMenu.addItem(actionItem(L10n.tr("menu.pauseIndefinitely"), #selector(pauseIndefinitely)))
            let pauseItem = NSMenuItem(title: L10n.tr("menu.pause"), action: nil, keyEquivalent: "")
            pauseItem.submenu = pauseMenu
            menu.addItem(pauseItem)
        }

        menu.addItem(actionItem(L10n.tr("menu.reset"), #selector(resetBreaks)))
        menu.addItem(.separator())
        menu.addItem(actionItem(L10n.tr("menu.preferences"), #selector(openPreferences)))
        if !settings.admin.disableAppUpdateFeatures {
            menu.addItem(actionItem(L10n.tr("menu.checkUpdates"), #selector(checkForUpdatesNow)))
        }
        menu.addItem(actionItem(L10n.tr("menu.saveSettings"), #selector(saveSettings)))
        menu.addItem(actionItem(L10n.tr("menu.copyDebug"), #selector(copyDebugInfo)))
        menu.addItem(actionItem(L10n.tr("menu.debugPanel"), #selector(openDebugPanel)))

        if !settings.admin.hideSettingsFileLocation {
            let pathItem = disabledItem(settingsStore.fileURL.path)
            pathItem.toolTip = settingsStore.fileURL.path
            menu.addItem(pathItem)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L10n.tr("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
    }

    private func menuBarTitle() -> String {
        if engine.state.activeSession != nil {
            return "Rest"
        }
        if engine.state.pause != nil {
            return "Paused"
        }
        if engine.state.activeDeferral != nil {
            return L10n.tr("status.deferredShort")
        }
        guard let scheduled = engine.state.scheduled else {
            return L10n.tr("app.name")
        }
        let seconds = max(0, Int(scheduled.dueAt.timeIntervalSinceNow))
        switch settings.presentation.trayIconStyle {
        case .default:
            return L10n.tr("app.name")
        case .timeToBreak:
            return seconds >= 60 ? "\(seconds / 60)m" : "\(seconds)s"
        case .progress:
            return scheduled.kind == .eyeGate ? "Eye \(seconds / 60)m" : "Body \(seconds / 60)m"
        }
    }

    private func statusText() -> String {
        if let active = engine.state.activeSession {
            let remaining = max(0, Int(active.duration - Date().timeIntervalSince(active.startedAt)))
            return L10n.format("status.active", active.kind.rawValue, remaining)
        }
        if let pause = engine.state.pause {
            if let until = pause.until {
                return L10n.format("status.pausedUntil", until.formatted(date: .omitted, time: .shortened))
            }
            return L10n.tr("status.pausedIndefinitely")
        }
        if let deferral = engine.state.activeDeferral {
            return L10n.format(
                "status.deferred",
                deferral.kind.rawValue,
                deferralReasonText(deferral.reason)
            )
        }
        if let scheduled = engine.state.scheduled {
            return L10n.format("status.next", scheduled.kind.rawValue, scheduled.dueAt.formatted(date: .omitted, time: .shortened))
        }
        return L10n.tr("status.noRests")
    }

    private func deferralReasonText(_ reason: ContextDeferralReason) -> String {
        switch reason {
        case .outsideWorkingHours:
            return L10n.tr("deferral.outsideWorkingHours")
        case .focusMode:
            return L10n.tr("deferral.focusMode")
        case .appExclusion(let name):
            return L10n.format("deferral.appExclusion", name)
        }
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func canPostponeBodyBreak(_ session: RestSession, now: Date) -> Bool {
        guard session.kind == .bodyBreak else { return false }
        let policy = settings.bodyBreak.postpone
        return policy.isEnabled &&
            engine.state.postponesInCurrentCycle < policy.maxCount &&
            session.passedPercent(at: now) <= policy.allowedDuringFirstPercent
    }

    private func canSkipBodyBreak(_ session: RestSession, now: Date) -> Bool {
        guard session.kind == .bodyBreak,
              settings.bodyBreak.ordinarySkipEnabled else {
            return false
        }
        return !canPostponeBodyBreak(session, now: now)
    }

    @objc private func takeEyeGateNow() {
        if case .started(let session) = engine.takeNow(.eyeGate) {
            soundPlayer.play(settings.rule(for: session.kind).startSound)
            overlayController.present(session: session, settings: settings, now: Date())
            logger.log("Manual Eye Gate started")
        }
        rebuildMenu()
    }

    @objc private func takeBodyBreakNow() {
        startBodyBreakNow(idea: nil)
    }

    private func startBodyBreakNow(idea: RestIdea?) {
        let effectiveIdea = idea ?? pendingBodyBreakIdea
        pendingBodyBreakIdea = nil
        if case .started(let session) = engine.takeNow(.bodyBreak) {
            if let idea = effectiveIdea {
                activeBodyBreakIdeas[session.id] = idea
            }
            soundPlayer.play(settings.rule(for: session.kind).startSound)
            overlayController.present(session: session, settings: overlaySettings(for: session), now: Date())
            logger.log("Manual Body Break started")
        }
        rebuildMenu()
    }

    @objc private func takeNextScheduledRestNow() {
        guard let scheduled = engine.state.scheduled else { return }
        switch scheduled.kind {
        case .eyeGate:
            takeEyeGateNow()
        case .bodyBreak:
            takeBodyBreakNow()
        }
    }

    @objc private func postponeBodyBreak() {
        let active = engine.state.activeSession
        if case .postponed = engine.postponeActive() {
            overlayController.dismiss()
            if let active {
                clearActiveBodyBreakIdea(for: active)
            }
            logger.log("Body Break postponed")
        }
        rebuildMenu()
    }

    @objc private func finishActiveBreak() {
        guard let active = engine.state.activeSession else { return }
        if Date().timeIntervalSince(active.startedAt) < active.duration {
            logger.log("Ignored early finish for \(active.kind.rawValue)")
            return
        }
        if case .completed = engine.completeActive(reason: .manual) {
            soundPlayer.play(settings.rule(for: active.kind).finishSound)
            logger.log("Manually finished \(active.kind.rawValue)")
            clearActiveBodyBreakIdea(for: active)
            overlayController.dismiss()
            manualAwaitingSessionID = nil
        }
        rebuildMenu()
    }

    @objc private func skipBodyBreak() {
        guard let active = engine.state.activeSession else { return }
        guard canSkipBodyBreak(active, now: Date()) else {
            logger.log("Body Break skip denied by policy")
            rebuildMenu()
            return
        }
        if case .completed = engine.skipActive() {
            clearActiveBodyBreakIdea(for: active)
            overlayController.dismiss()
            manualAwaitingSessionID = nil
            logger.log("Body Break skipped")
        } else {
            logger.log("Body Break skip denied")
        }
        rebuildMenu()
    }

    @objc private func endBodyBreakFromShortcut() {
        let now = Date()
        guard let active = engine.state.activeSession, active.kind == .bodyBreak else { return }

        if now.timeIntervalSince(active.startedAt) >= active.duration {
            finishActiveBreak()
            return
        }

        if case .postponed = engine.postponeActive(now: now) {
            overlayController.dismiss()
            clearActiveBodyBreakIdea(for: active)
            logger.log("Body Break postponed by end shortcut")
        } else if case .completed = engine.skipActive(now: now) {
            overlayController.dismiss()
            manualAwaitingSessionID = nil
            clearActiveBodyBreakIdea(for: active)
            logger.log("Body Break skipped by end shortcut")
        }
        rebuildMenu()
    }

    @objc private func emergencyOverrideEyeGate() {
        guard let active = engine.state.activeSession, active.kind == .eyeGate else { return }

        let policy = settings.eyeGate.emergencyOverride
        let elapsed = Date().timeIntervalSince(active.startedAt)
        guard elapsed >= policy.minimumHoldDuration else {
            let remaining = Int(ceil(policy.minimumHoldDuration - elapsed))
            showAppNotification(
                title: L10n.tr("app.name"),
                body: L10n.format("notification.emergencyHold", remaining)
            )
            logger.log("Emergency override denied: hold incomplete")
            return
        }

        guard confirmEmergencyOverride(steps: policy.confirmationSteps) else {
            logger.log("Emergency override cancelled during confirmation")
            return
        }

        let result = engine.emergencyOverride(
            now: Date(),
            completedConfirmationSteps: policy.confirmationSteps,
            heldDuration: elapsed
        )
        if case .completed(let session, _) = result {
            soundPlayer.play(settings.rule(for: session.kind).finishSound)
            overlayController.dismiss()
            manualAwaitingSessionID = nil
            logger.log("Emergency override completed for \(session.kind.rawValue)")
        } else {
            logger.log("Emergency override denied result=\(result)")
        }
        rebuildMenu()
    }

    private func confirmEmergencyOverride(steps: Int) -> Bool {
        guard steps > 0 else { return true }
        for step in 1...steps {
            let alert = NSAlert()
            alert.messageText = L10n.format("emergency.confirmTitle", step, steps)
            alert.informativeText = L10n.tr("emergency.confirmBody")
            alert.addButton(withTitle: L10n.tr("emergency.continue"))
            alert.addButton(withTitle: L10n.tr("emergency.cancel"))
            alert.window.level = .screenSaver
            guard alert.runModal() == .alertFirstButtonReturn else {
                return false
            }
        }
        return true
    }

    @objc private func resumeBreaks() {
        _ = engine.resume()
        logger.log("Breaks resumed")
        rebuildMenu()
    }

    @objc private func pauseFor30Minutes() {
        pause(for: 30 * 60, reason: .user)
    }

    @objc private func pauseFor1Hour() {
        pause(for: 60 * 60, reason: .user)
    }

    @objc private func pauseFor2Hours() {
        pause(for: 2 * 60 * 60, reason: .user)
    }

    @objc private func pauseFor5Hours() {
        pause(for: 5 * 60 * 60, reason: .user)
    }

    @objc private func pauseUntilMorning() {
        pause(for: settings.operations.secondsUntilMorning(), reason: .untilMorning)
    }

    @objc private func pauseIndefinitely() {
        pause(for: nil, reason: .user)
    }

    private func pause(for duration: TimeInterval?, reason: PauseReason) {
        let active = engine.state.activeSession
        if case .paused = engine.pause(for: duration, reason: reason) {
            overlayController.dismiss()
            if let active {
                clearActiveBodyBreakIdea(for: active)
            }
            logger.log("Breaks paused reason=\(reason.rawValue) duration=\(String(describing: duration))")
        }
        rebuildMenu()
    }

    @objc private func resetBreaks() {
        _ = engine.reset()
        overlayController.dismiss()
        manualAwaitingSessionID = nil
        pendingBodyBreakIdea = nil
        activeBodyBreakIdeas.removeAll()
        cancelAutomationTasks()
        logger.log("Breaks reset")
        rebuildMenu()
    }

    @objc private func openPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(settings: settings) { [weak self] nextSettings in
                Task { @MainActor in
                    self?.applySettings(nextSettings)
                }
            }
        }
        preferencesWindowController?.update(settings: settings)
        preferencesWindowController?.showWindow(nil)
        preferencesWindowController?.window?.makeKeyAndOrderFront(nil)
        preferencesWindowController?.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showOnboardingIfNeeded() {
        guard !settings.operations.hasCompletedOnboarding ||
              settings.operations.resolvedShowOnboardingOnNextLaunch else {
            return
        }
        onboardingWindowController = OnboardingWindowController(
            onUseDefaults: { [weak self] in
                self?.completeOnboarding(openPreferences: false)
            },
            onOpenPreferences: { [weak self] in
                self?.completeOnboarding(openPreferences: true)
            }
        )
        onboardingWindowController?.show()
        NSApp.activate(ignoringOtherApps: true)
        logger.log("Onboarding shown")
    }

    private func completeOnboarding(openPreferences shouldOpenPreferences: Bool) {
        settings.operations.hasCompletedOnboarding = true
        settings.operations.showOnboardingOnNextLaunch = false
        applySettings(settings)
        logger.log("Onboarding completed")
        if shouldOpenPreferences {
            openPreferences()
        }
    }

    @objc private func checkForUpdatesNow() {
        Task { @MainActor in
            await runUpdateCheck(notifyWhenCurrent: true)
        }
    }

    @objc private func openLatestRelease() {
        guard let latestReleaseURL else { return }
        NSWorkspace.shared.open(latestReleaseURL)
    }

    @objc private func saveSettings() {
        do {
            try settingsStore.save(settings)
            logger.log("Settings saved")
        } catch {
            logger.log("Settings save failed: \(error.localizedDescription)")
        }
        rebuildMenu()
    }

    @objc private func copyDebugInfo() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(debugInfo(), forType: .string)
        logger.log("Debug info copied")
    }

    @objc private func openDebugPanel() {
        if debugWindowController == nil {
            debugWindowController = DebugWindowController()
        }
        debugWindowController?.update(text: debugInfo())
        debugWindowController?.showWindow(nil)
        debugWindowController?.window?.makeKeyAndOrderFront(nil)
        debugWindowController?.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        logger.log("Debug panel opened")
    }

    private func applySettings(_ nextSettings: RestSettings) {
        settings = nextSettings
        engine.updateSettings(nextSettings)
        applyLanguageSetting()
        applyAppearanceSetting()
        applyOpenAtLoginSetting()
        applyMenuBarVisibility()
        configureGlobalShortcuts()
        scheduleAutomaticUpdateCheck()
        do {
            try settingsStore.save(nextSettings)
            logger.log("Preferences saved")
        } catch {
            logger.log("Preferences save failed: \(error.localizedDescription)")
        }
        rebuildMenu()
    }

    @objc private func handleAutomation(_ notification: Notification) {
        guard let rawCommand = notification.object as? String,
              let command = AutomationCommand(rawValue: rawCommand) else {
            return
        }

        switch command {
        case .pause:
            pause(for: automationDuration(from: notification.userInfo), reason: .user)
        case .resume:
            resumeBreaks()
        case .toggle:
            if engine.state.pause == nil {
                pause(for: nil, reason: .user)
            } else {
                resumeBreaks()
            }
        case .reset:
            resetBreaks()
        case .eye:
            handleEyeGateAutomation(notification.userInfo)
        case .body:
            handleBodyBreakAutomation(notification.userInfo)
        case .preferences:
            openPreferences()
        case .debug:
            copyDebugInfo()
        }
        logger.log("Handled automation command \(command.rawValue)")
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              CommandLineAutomation.post(urlString: urlString) else {
            logger.log("Ignored invalid automation URL event")
            return
        }
        logger.log("Handled automation URL \(urlString)")
    }

    private func automationDuration(from userInfo: [AnyHashable: Any]?) -> TimeInterval? {
        if let duration = userInfo?["duration"] as? TimeInterval {
            return duration
        }
        if let duration = userInfo?["duration"] as? NSNumber {
            return duration.doubleValue
        }
        return nil
    }

    private func handleEyeGateAutomation(_ userInfo: [AnyHashable: Any]?) {
        let noSkip = automationNoSkip(from: userInfo)
        let wait = automationDuration(from: userInfo)

        if let wait, wait > 0 {
            scheduleEyeGateAutomation(after: wait)
        } else if noSkip {
            logger.log("Ignored Eye Gate content customization")
        } else {
            takeEyeGateNow()
        }
    }

    private func handleBodyBreakAutomation(_ userInfo: [AnyHashable: Any]?) {
        let idea = automationBodyBreakIdea(from: userInfo)
        let noSkip = automationNoSkip(from: userInfo)
        let wait = automationDuration(from: userInfo)

        if let wait, wait > 0 {
            scheduleBodyBreakAutomation(after: wait, idea: idea)
        } else if noSkip {
            pendingBodyBreakIdea = idea
            logger.log("Stored one-shot Body Break content")
        } else {
            startBodyBreakNow(idea: idea)
        }
    }

    private func automationNoSkip(from userInfo: [AnyHashable: Any]?) -> Bool {
        if let noSkip = userInfo?["noSkip"] as? Bool {
            return noSkip
        }
        if let noSkip = userInfo?["noSkip"] as? NSNumber {
            return noSkip.boolValue
        }
        return false
    }

    private func automationBodyBreakIdea(from userInfo: [AnyHashable: Any]?) -> RestIdea? {
        let title = (userInfo?["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rawText = (userInfo?["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let body = ContentSanitizer.sanitizeRichText(rawText)
        guard !title.isEmpty || !body.isEmpty else { return nil }
        return RestIdea(
            id: "automation-\(UUID().uuidString)",
            kind: .bodyBreak,
            title: title.isEmpty ? L10n.tr("overlay.bodyTitle") : title,
            body: body,
            isEnabled: true
        )
    }

    private func scheduleEyeGateAutomation(after delay: TimeInterval) {
        let id = UUID()
        let nanoseconds = UInt64(max(1, delay) * 1_000_000_000)
        let task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self?.runScheduledEyeGateAutomation(id: id)
            }
        }
        automationTasks[id] = task
        logger.log("Scheduled Eye Gate automation after \(delay) seconds")
    }

    private func runScheduledEyeGateAutomation(id: UUID) {
        automationTasks.removeValue(forKey: id)
        takeEyeGateNow()
    }

    private func scheduleBodyBreakAutomation(after delay: TimeInterval, idea: RestIdea?) {
        let id = UUID()
        let nanoseconds = UInt64(max(1, delay) * 1_000_000_000)
        let task = Task { [weak self, idea] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self?.runScheduledBodyBreakAutomation(id: id, idea: idea)
            }
        }
        automationTasks[id] = task
        logger.log("Scheduled Body Break automation after \(delay) seconds")
    }

    private func runScheduledBodyBreakAutomation(id: UUID, idea: RestIdea?) {
        automationTasks.removeValue(forKey: id)
        startBodyBreakNow(idea: idea)
    }

    private func cancelAutomationTasks() {
        for task in automationTasks.values {
            task.cancel()
        }
        automationTasks.removeAll()
    }

    private func bindPendingBodyBreakIdea(to session: RestSession) {
        guard session.kind == .bodyBreak, let idea = pendingBodyBreakIdea else { return }
        activeBodyBreakIdeas[session.id] = idea
        pendingBodyBreakIdea = nil
    }

    private func clearActiveBodyBreakIdea(for session: RestSession) {
        activeBodyBreakIdeas.removeValue(forKey: session.id)
    }

    private func overlaySettings(for session: RestSession) -> RestSettings {
        guard session.kind == .bodyBreak,
              let idea = activeBodyBreakIdeas[session.id] else {
            return settings
        }
        var copy = settings
        copy.contentLibrary.useBuiltInIdeas = false
        copy.contentLibrary.customBodyBreakIdeas = [idea]
        copy.contentLibrary.localImagePaths = []
        copy.bodyBreak.content = .richRestIdea
        return copy
    }

    @objc private func systemWillPause() {
        suspendedAt = Date()
        pausedForSuspendOrLock = false
        if settings.operations.resolvedPauseForSuspendOrLock {
            if engine.state.activeSession == nil,
               case .paused = engine.pause(for: nil, reason: .suspendOrLock) {
                pausedForSuspendOrLock = true
            }
            overlayController.dismiss()
            logger.log("System pause detected")
        } else {
            logger.log("System pause detected without scheduler pause")
        }
        rebuildMenu()
    }

    @objc private func systemDidResume() {
        let now = Date()
        let idleDuration = suspendedAt.map { now.timeIntervalSince($0) } ?? 0
        suspendedAt = nil
        if pausedForSuspendOrLock {
            _ = engine.resume(now: now)
            pausedForSuspendOrLock = false
        }
        let result = engine.evaluate(now: now, context: RestContext(idleDuration: idleDuration))
        handleEngineResult(result, now: now)
        logger.log("System resume detected idleDuration=\(idleDuration)")
        rebuildMenu()
    }

    private func applyOpenAtLoginSetting() {
        do {
            try LoginItemManager.apply(enabled: settings.operations.openAtLogin)
            logger.log("Open-at-login applied enabled=\(settings.operations.openAtLogin)")
        } catch {
            if settings.operations.openAtLogin {
                logger.log("Open-at-login unavailable: \(error.localizedDescription)")
            }
        }
    }

    private func applyAppearanceSetting() {
        switch settings.presentation.themeSource {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
        logger.log("Appearance applied source=\(settings.presentation.themeSource.rawValue)")
    }

    private func applyLanguageSetting() {
        L10n.languageOverride = settings.presentation.languageIdentifier
        logger.log("Language applied override=\(settings.presentation.languageIdentifier ?? "system")")
    }

    private func configureGlobalShortcuts() {
        globalShortcuts.unregisterAll()
        registerShortcut(settings.shortcuts.pauseToggle) { [weak self] in
            if self?.engine.state.pause == nil {
                self?.pause(for: nil, reason: .user)
            } else {
                self?.resumeBreaks()
            }
        }
        registerShortcut(settings.shortcuts.pauseFor30Minutes) { [weak self] in
            self?.pause(for: 30 * 60, reason: .user)
        }
        registerShortcut(settings.shortcuts.pauseFor1Hour) { [weak self] in
            self?.pause(for: 60 * 60, reason: .user)
        }
        registerShortcut(settings.shortcuts.pauseFor2Hours) { [weak self] in
            self?.pause(for: 2 * 60 * 60, reason: .user)
        }
        registerShortcut(settings.shortcuts.pauseFor5Hours) { [weak self] in
            self?.pause(for: 5 * 60 * 60, reason: .user)
        }
        registerShortcut(settings.shortcuts.pauseUntilMorning) { [weak self] in
            self?.pauseUntilMorning()
        }
        registerShortcut(settings.shortcuts.skipToNextScheduledRest ?? "") { [weak self] in
            self?.takeNextScheduledRestNow()
        }
        registerShortcut(settings.shortcuts.takeEyeGateNow) { [weak self] in
            self?.takeEyeGateNow()
        }
        registerShortcut(settings.shortcuts.takeBodyBreakNow) { [weak self] in
            self?.takeBodyBreakNow()
        }
        registerShortcut(settings.shortcuts.skipToNextBodyBreak) { [weak self] in
            self?.takeBodyBreakNow()
        }
        registerShortcut(settings.shortcuts.endBodyBreak ?? "") { [weak self] in
            self?.endBodyBreakFromShortcut()
        }
        registerShortcut(settings.shortcuts.emergencyEyeGateOverride ?? "") { [weak self] in
            self?.emergencyOverrideEyeGate()
        }
        registerShortcut(settings.shortcuts.reset) { [weak self] in
            self?.resetBreaks()
        }
        logger.log("Global shortcuts configured")
    }

    private func scheduleAutomaticUpdateCheck() {
        guard settings.operations.checkForUpdates,
              !settings.admin.disableAppUpdateFeatures else {
            return
        }
        Task { @MainActor in
            await runUpdateCheck(notifyWhenCurrent: false)
        }
    }

    private func runUpdateCheck(notifyWhenCurrent: Bool) async {
        let result = await updateChecker.check(
            feedURL: settings.operations.updateFeedURL,
            currentVersion: AppVersion.current
        )

        switch result.status {
        case .newerVersion(let version):
            latestReleaseURL = result.releaseURL
            logger.log("Update available version=\(version) url=\(String(describing: result.releaseURL))")
            if settings.operations.notifyNewVersion {
                showAppNotification(title: L10n.tr("notification.updateTitle"), body: L10n.format("notification.updateAvailable", version))
            }
        case .upToDate:
            latestReleaseURL = result.releaseURL
            logger.log("Update check: up to date")
            if notifyWhenCurrent {
                showAppNotification(title: L10n.tr("notification.updateTitle"), body: L10n.tr("notification.updateCurrent"))
            }
        case .notConfigured:
            logger.log("Update check skipped: no feed URL")
            if notifyWhenCurrent {
                showAppNotification(title: L10n.tr("notification.updateTitle"), body: L10n.tr("notification.updateNoFeed"))
            }
        case .failed(let message):
            logger.log("Update check failed: \(message)")
            if notifyWhenCurrent {
                showAppNotification(title: L10n.tr("notification.updateTitle"), body: L10n.format("notification.updateFailed", message))
            }
        }
        rebuildMenu()
    }

    private func showAppNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if !settings.notifications.silentNotifications {
            content.sound = .default
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func registerShortcut(_ shortcut: String, action: @MainActor @escaping () -> Void) {
        guard !shortcut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        globalShortcuts.register(shortcut: shortcut) {
            Task { @MainActor in
                action()
            }
        }
    }

    private func debugInfo() -> String {
        var lines = [
            "logPath=\(logger.fileURL.path)",
            "scheduled=\(String(describing: engine.state.scheduled))",
            "activeSession=\(String(describing: engine.state.activeSession))",
            "pause=\(String(describing: engine.state.pause))",
            "activeDeferral=\(String(describing: engine.state.activeDeferral))",
            "dangerScore=\(engine.state.dangerScore)",
            "statistics=\(engine.state.statistics)",
            "focusModeActive=\(focusModeActive)",
            "idleSeconds=\(SystemIdleTime.seconds())",
            "openAtLogin=\(settings.operations.openAtLogin)",
            "loginItemAvailable=\(LoginItemManager.isAvailable)"
        ]

        if !settings.admin.hideSettingsFileLocation {
            lines.insert("bodyBreakImagePaths=\(settings.contentLibrary.localImagePaths)", at: 1)
            lines.insert("supportPath=\(AppPaths.supportDirectory.path)", at: 1)
            lines.insert("settingsPath=\(settingsStore.fileURL.path)", at: 1)
        }

        return lines.joined(separator: "\n")
    }
}

@MainActor
final class OverlayController {
    private var windows: [CGDirectDisplayID: OverlayWindow] = [:]
    private var session: RestSession?
    private var settings: RestSettings?

    func present(session: RestSession, settings: RestSettings, now: Date) {
        self.session = session
        self.settings = settings
        reconcile()
        update(session: session, settings: settings, now: now)
    }

    func update(session: RestSession, settings: RestSettings, now: Date) {
        update(session: session, settings: settings, now: now, manualAwaiting: false)
    }

    func update(session: RestSession, settings: RestSettings, now: Date, manualAwaiting: Bool) {
        self.session = session
        self.settings = settings
        let remaining = max(0, Int(session.duration - now.timeIntervalSince(session.startedAt)))
        let contentScreen = selectedContentScreen(for: session, settings: settings)
        let screens = coveredScreens(for: session, settings: settings, contentScreen: contentScreen)

        for screen in screens {
            let id = screen.displayID
            let isContentScreen = shouldShowContent(on: screen, contentScreen: contentScreen, session: session, settings: settings)
            windows[id]?.setFrame(screen.frame, display: true)
            windows[id]?.overlayView.configure(
                session: session,
                remainingSeconds: remaining,
                settings: settings,
                showsContent: isContentScreen,
                manualAwaiting: manualAwaiting
            )
            windows[id]?.level = manualAwaiting ? .modalPanel : windowLevel(for: session, settings: settings)
            windows[id]?.orderFrontRegardless()
        }
    }

    func reconcile() {
        guard let session, let settings else { return }

        let contentScreen = selectedContentScreen(for: session, settings: settings)
        let screens = coveredScreens(for: session, settings: settings, contentScreen: contentScreen)
        let targetIDs = Set(screens.map(\.displayID))
        for (id, window) in windows where !targetIDs.contains(id) {
            window.close()
        }
        windows = windows.filter { targetIDs.contains($0.key) }

        for screen in screens {
            let id = screen.displayID
            if windows[id] == nil {
                let window = OverlayWindow(screen: screen, session: session, settings: settings)
                windows[id] = window
            }
            windows[id]?.setFrame(screen.frame, display: true)
            windows[id]?.orderFrontRegardless()
        }
    }

    func dismiss() {
        for window in windows.values {
            window.close()
        }
        windows.removeAll()
        session = nil
        settings = nil
    }

    private func selectedContentScreen(for session: RestSession, settings: RestSettings) -> NSScreen? {
        let enforcement = settings.rule(for: session.kind).enforcement
        return screen(for: enforcement.contentDisplay, enforcement: enforcement)
    }

    private func coveredScreens(
        for session: RestSession,
        settings: RestSettings,
        contentScreen: NSScreen?
    ) -> [NSScreen] {
        let allScreens = NSScreen.screens
        guard !allScreens.isEmpty else { return [] }

        let enforcement = settings.rule(for: session.kind).enforcement
        if session.kind == .eyeGate || enforcement.coversAllDisplays {
            return allScreens
        }

        let fallbackSelection = contentScreen == nil ? DisplaySelection.primary : enforcement.contentDisplay
        let selection = enforcement.coveredDisplay ?? fallbackSelection
        return [screen(for: selection, enforcement: enforcement) ?? allScreens.first!]
    }

    private func shouldShowContent(
        on screen: NSScreen,
        contentScreen: NSScreen?,
        session: RestSession,
        settings: RestSettings
    ) -> Bool {
        let enforcement = settings.rule(for: session.kind).enforcement
        if enforcement.contentDisplay == .none {
            return false
        }
        if enforcement.contentDisplay == .all {
            return true
        }
        if !enforcement.blankSecondaryDisplays {
            return true
        }
        guard let contentScreen else {
            return false
        }
        return screen.displayID == contentScreen.displayID
    }

    private func screen(for selection: DisplaySelection, enforcement: EnforcementProfile) -> NSScreen? {
        switch selection {
        case .none, .all:
            return nil
        case .primary:
            return NSScreen.screens.first
        case .cursor:
            return NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.screens.first
        case .configured:
            if let index = enforcement.configuredDisplayIndex,
               NSScreen.screens.indices.contains(index) {
                return NSScreen.screens[index]
            }
            return NSScreen.screens.first
        }
    }

    private func windowLevel(for session: RestSession, settings: RestSettings) -> NSWindow.Level {
        settings.rule(for: session.kind).enforcement.usesScreenSaverLevel ? .screenSaver : .modalPanel
    }
}

@MainActor
final class OverlayWindow: NSWindow {
    let overlayView: RestOverlayView

    init(screen: NSScreen, session: RestSession, settings: RestSettings) {
        self.overlayView = RestOverlayView(frame: screen.frame)
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        contentView = overlayView
        level = settings.rule(for: session.kind).enforcement.usesScreenSaverLevel ? .screenSaver : .modalPanel
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        canHide = false
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

@MainActor
final class RestOverlayView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let countdownLabel = NSTextField(labelWithString: "")
    private let imageView = NSImageView()
    private var detailCacheKey: String?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.isHidden = true
        addSubview(imageView)

        [titleLabel, detailLabel, countdownLabel].forEach { label in
            label.translatesAutoresizingMaskIntoConstraints = false
            label.alignment = .center
            label.textColor = .white
            label.lineBreakMode = .byWordWrapping
            addSubview(label)
        }

        titleLabel.font = .systemFont(ofSize: 34, weight: .semibold)
        detailLabel.font = .systemFont(ofSize: 18, weight: .regular)
        countdownLabel.font = .monospacedDigitSystemFont(ofSize: 28, weight: .medium)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -24),
            imageView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.38),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, multiplier: 0.32),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -34),
            titleLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.7),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            detailLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            detailLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.7),
            countdownLabel.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 20),
            countdownLabel.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        session: RestSession,
        remainingSeconds: Int,
        settings: RestSettings,
        showsContent: Bool,
        manualAwaiting: Bool
    ) {
        let rule = settings.rule(for: session.kind)
        layer?.backgroundColor = NSColor(hex: rule.colorHex).withAlphaComponent(rule.enforcement.opacity).cgColor

        titleLabel.isHidden = !showsContent
        detailLabel.isHidden = !showsContent
        countdownLabel.isHidden = !showsContent
        imageView.isHidden = true
        imageView.image = nil

        guard showsContent else { return }

        if manualAwaiting {
            titleLabel.stringValue = L10n.tr("overlay.completeTitle")
            setDetailText(L10n.tr("overlay.completeBody"), allowsRichText: false)
            countdownLabel.stringValue = L10n.tr("overlay.ready")
            return
        }

        switch session.kind {
        case .eyeGate:
            let idea = settings.contentLibrary.ideas(for: .eyeGate).first
            titleLabel.stringValue = idea?.title ?? L10n.tr("overlay.eyeTitle")
            setDetailText(idea?.body ?? L10n.tr("overlay.eyeBody"), allowsRichText: false)
        case .bodyBreak:
            let ideas = settings.contentLibrary.ideas(for: .bodyBreak)
            let index = Int(session.startedAt.timeIntervalSinceReferenceDate) % max(1, ideas.count)
            let idea = ideas[safe: index]
            titleLabel.stringValue = idea?.title ?? L10n.tr("overlay.bodyTitle")
            setDetailText(idea?.body ?? L10n.tr("overlay.bodyBody"), allowsRichText: true)
            if let image = localBodyBreakImage(settings: settings) {
                imageView.image = image
                imageView.isHidden = false
            }
        }
        if session.kind == .bodyBreak, settings.presentation.showCurrentTimeDuringBodyBreak {
            countdownLabel.stringValue = "\(remainingSeconds)s · \(Date().formatted(date: .omitted, time: .shortened))"
        } else {
            countdownLabel.stringValue = "\(remainingSeconds)s"
        }
    }

    private func localBodyBreakImage(settings: RestSettings) -> NSImage? {
        guard settings.bodyBreak.content == .localImage,
              let path = settings.contentLibrary.localImagePaths.first,
              URL(string: path)?.scheme == nil else {
            return nil
        }
        return NSImage(contentsOfFile: path)
    }

    private func setDetailText(_ text: String, allowsRichText: Bool) {
        let key = "\(allowsRichText):\(text)"
        guard detailCacheKey != key else { return }
        detailCacheKey = key

        guard allowsRichText,
              let attributed = attributedHTML(from: ContentSanitizer.sanitizeRichText(text)) else {
            detailLabel.stringValue = text
            return
        }

        detailLabel.attributedStringValue = attributed
    }

    private func attributedHTML(from sanitized: String) -> NSAttributedString? {
        let html = """
        <html>
        <head>
        <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, sans-serif;
          font-size: 18px;
          color: white;
          text-align: center;
        }
        a { color: #b7ecff; }
        </style>
        </head>
        <body>\(sanitized)</body>
        </html>
        """
        guard let data = html.data(using: .utf8) else { return nil }
        return try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )
    }
}

final class SoundPlayer {
    func play(_ policy: SoundPolicy) {
        switch policy {
        case .silent:
            return
        case .named(let name, let volume):
            guard let sound = NSSound(named: NSSound.Name(name)) ?? NSSound(named: .init("Glass")) else {
                return
            }
            sound.volume = Float(min(1, max(0, volume)))
            sound.play()
        }
    }
}

enum SystemIdleTime {
    static func seconds() -> TimeInterval {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOHIDSystem")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return 0
        }
        defer { IOObjectRelease(iterator) }

        let entry = IOIteratorNext(iterator)
        guard entry != 0 else { return 0 }
        defer { IOObjectRelease(entry) }

        var unmanagedProperties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &unmanagedProperties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let properties = unmanagedProperties?.takeRetainedValue() as? [String: Any],
              let idleNanoseconds = properties["HIDIdleTime"] as? UInt64 else {
            return 0
        }

        return TimeInterval(idleNanoseconds) / 1_000_000_000
    }
}

enum RunningApplications {
    static func matches(rule: AppExclusionRule) -> Bool {
        guard rule.isEnabled else { return false }
        let running = NSWorkspace.shared.runningApplications
        return running.contains { app in
            let candidates = [
                app.localizedName,
                app.bundleIdentifier,
                app.executableURL?.lastPathComponent,
                app.executableURL?.path
            ].compactMap { $0?.lowercased() }

            return rule.matchTerms.contains { term in
                let needle = term.lowercased()
                return candidates.contains { $0.contains(needle) }
            }
        }
    }
}

final class FocusModeDetector {
    func isFocusModeActive() -> Bool {
        let keys = [
            "NSStatusItem VisibleCC FocusModes",
            "NSStatusItem Visible FocusModes"
        ]

        for key in keys where defaultsReadControlCenter(key) == "1" {
            return true
        }
        return false
    }

    private func defaultsReadControlCenter(_ key: String) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", "com.apple.controlcenter", key]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { $0.isNumber }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? 0
    }
}

extension NSColor {
    convenience init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: trimmed)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)

        let red = CGFloat((value & 0xFF0000) >> 16) / 255
        let green = CGFloat((value & 0x00FF00) >> 8) / 255
        let blue = CGFloat(value & 0x0000FF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

if !CommandLineAutomation.handle(arguments: CommandLine.arguments) {
    let app = NSApplication.shared
    let delegate = ShouldRestAppDelegate()
    app.delegate = delegate
    app.run()
}

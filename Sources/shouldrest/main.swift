import AppKit
import Carbon
import Foundation
import IOKit
import ShouldRestCore
import UserNotifications

enum AppNotificationUserInfo {
    static let openURL = "openURL"

    static func payload(openURL: URL?) -> [AnyHashable: Any] {
        guard let openURL else { return [:] }
        return [Self.openURL: openURL.absoluteString]
    }

    static func url(from userInfo: [AnyHashable: Any]) -> URL? {
        guard let urlString = userInfo[Self.openURL] as? String,
              let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }
        return url
    }
}

enum TerminationPolicy {
    enum RequestAction: Equatable {
        case terminateNow
        case armEyeGateEmergencyInOverlay
        case notifyBlocked(RestKind)
    }

    static func strictActiveRestKind(state: RestEngineState, settings: RestSettings) -> RestKind? {
        guard let active = state.activeSession else { return nil }
        switch active.kind {
        case .eyeGate:
            return .eyeGate
        case .bodyBreak:
            return settings.bodyBreak.ordinarySkipEnabled ? nil : .bodyBreak
        }
    }

    static func canTerminate(state: RestEngineState, settings: RestSettings) -> Bool {
        strictActiveRestKind(state: state, settings: settings) == nil
    }

    static func requestAction(
        state: RestEngineState,
        settings: RestSettings,
        now: Date = Date()
    ) -> RequestAction {
        guard let feedback = StrictRestBlockedActionPolicy.feedback(
            state: state,
            settings: settings,
            now: now
        ) else {
            return .terminateNow
        }

        switch feedback {
        case .armEyeGateEmergencyInOverlay:
            return .armEyeGateEmergencyInOverlay
        case .notifyBlocked(let kind):
            return .notifyBlocked(kind)
        }
    }
}

enum StrictRestBlockedActionPolicy {
    enum Feedback: Equatable {
        case armEyeGateEmergencyInOverlay
        case notifyBlocked(RestKind)
    }

    static func feedback(
        state: RestEngineState,
        settings: RestSettings,
        now: Date = Date()
    ) -> Feedback? {
        guard let kind = TerminationPolicy.strictActiveRestKind(state: state, settings: settings) else {
            return nil
        }

        if let active = state.activeSession,
           active.kind == .eyeGate,
           EmergencyOverrideCoordinator.isAvailable(
               session: active,
               policy: settings.eyeGate.emergencyOverride,
               now: now
           ) {
            return .armEyeGateEmergencyInOverlay
        }

        return .notifyBlocked(kind)
    }
}

enum BlockedActionCopy {
    static func quitMessage(for kind: RestKind) -> String {
        L10n.format("notification.quitBlocked", MenuStatusPresenter.restKindName(kind))
    }

    static func quitMessage(state: RestEngineState, settings: RestSettings) -> String? {
        guard let kind = TerminationPolicy.strictActiveRestKind(state: state, settings: settings) else {
            return nil
        }
        return quitMessage(for: kind)
    }

    static func resetScheduleMessage(for kind: RestKind) -> String {
        L10n.format("notification.resetBlocked", MenuStatusPresenter.restKindName(kind))
    }

    static func resetScheduleMessage(state: RestEngineState, settings: RestSettings) -> String? {
        guard let kind = TerminationPolicy.strictActiveRestKind(state: state, settings: settings) else {
            return nil
        }
        return resetScheduleMessage(for: kind)
    }

    static func pauseMessage(for kind: RestKind) -> String {
        L10n.format("notification.pauseBlocked", MenuStatusPresenter.restKindName(kind))
    }
}

enum ResetScheduleConfirmation {
    @MainActor
    static func makeAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = L10n.tr("reset.confirmTitle")
        alert.informativeText = L10n.tr("reset.confirmBody")
        alert.alertStyle = .warning
        let cancelButton = alert.addButton(withTitle: L10n.tr("reset.confirmCancel"))
        let resetButton = alert.addButton(withTitle: L10n.tr("reset.confirmAction"))
        cancelButton.keyEquivalent = "\r"
        resetButton.keyEquivalent = ""
        if #available(macOS 11.0, *) {
            cancelButton.hasDestructiveAction = false
            resetButton.hasDestructiveAction = true
        }
        return alert
    }

    @MainActor
    static func confirmed() -> Bool {
        makeAlert().runModal() == .alertSecondButtonReturn
    }
}

enum PauseIndefinitelyConfirmation {
    @MainActor
    static func makeAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = L10n.tr("pause.indefiniteConfirmTitle")
        alert.informativeText = L10n.tr("pause.indefiniteConfirmBody")
        alert.alertStyle = .warning
        let cancelButton = alert.addButton(withTitle: L10n.tr("pause.indefiniteConfirmCancel"))
        let pauseButton = alert.addButton(withTitle: L10n.tr("pause.indefiniteConfirmAction"))
        cancelButton.keyEquivalent = "\r"
        pauseButton.keyEquivalent = ""
        if #available(macOS 11.0, *) {
            cancelButton.hasDestructiveAction = false
            pauseButton.hasDestructiveAction = true
        }
        return alert
    }

    @MainActor
    static func confirmed() -> Bool {
        makeAlert().runModal() == .alertSecondButtonReturn
    }
}

enum PauseMenuCopy {
    static func untilMorningTitle(settings: RestSettings, now: Date = Date()) -> String {
        let target = now.addingTimeInterval(settings.operations.secondsUntilMorning(from: now))
        return L10n.format("menu.pauseUntilMorningWithTime", target.formatted(date: .omitted, time: .shortened))
    }

    static func indefiniteTitle(confirmsBeforePausing: Bool) -> String {
        L10n.tr(confirmsBeforePausing ? "menu.pauseIndefinitelyConfirming" : "menu.pauseIndefinitely")
    }
}

enum StatusMenuActionCopy {
    static func nextScheduledRestTitle(kind: RestKind) -> String {
        L10n.format("menu.takeNextScheduledRestNowWithKind", MenuStatusPresenter.restKindName(kind))
    }
}

enum ActiveRestShortcutCopy {
    static func title(for kind: RestKind) -> String {
        switch kind {
        case .eyeGate:
            return L10n.tr("prefs.activeRestShortcut.eye")
        case .bodyBreak:
            return L10n.tr("prefs.activeRestShortcut.body")
        }
    }
}

enum StatusMenuPolicy {
    static func showsOrdinaryControls(state: RestEngineState) -> Bool {
        state.activeSession?.kind != .eyeGate
    }

    static func routesEmergencyExitThroughOverlay(state: RestEngineState) -> Bool {
        state.activeSession?.kind == .eyeGate
    }

    static func showsOverlayOnlyNotice(state: RestEngineState, canEmergencyExit: Bool) -> Bool {
        state.activeSession?.kind == .eyeGate && canEmergencyExit
    }
}

enum StatusMenuActionIcon {
    static func symbolName(forActionName actionName: String) -> String? {
        switch actionName.replacingOccurrences(of: ":", with: "") {
        case "openLatestRelease":
            return "arrow.down.circle"
        case "takeEyeGateNow":
            return "timer"
        case "takeBodyBreakNow":
            return "figure.walk"
        case "takeNextScheduledRestNow":
            return "forward.end"
        case "finishActiveBreak":
            return "checkmark.circle"
        case "emergencyOverrideEyeGate":
            return "exclamationmark.triangle"
        case "postponeBodyBreak":
            return "clock.arrow.circlepath"
        case "skipBodyBreak":
            return "forward.end"
        case "resumeBreaks":
            return "play.circle"
        case "pauseFor30Minutes", "pauseFor1Hour", "pauseFor2Hours", "pauseFor5Hours":
            return "pause.circle"
        case "pauseUntilMorning":
            return "sunrise"
        case "pauseIndefinitely":
            return "infinity.circle"
        case "resetBreaks":
            return "arrow.counterclockwise"
        case "openPreferences":
            return "gearshape"
        case "checkForUpdatesNow":
            return "arrow.triangle.2.circlepath"
        case "copyDebugInfo":
            return "doc.on.doc"
        case "openDebugPanel":
            return "stethoscope"
        case "showAboutPanel":
            return "info.circle"
        case "showSettingsFile":
            return "folder"
        case "copySettingsPath":
            return "doc.on.doc"
        default:
            return nil
        }
    }

    static func symbolName(for selector: Selector) -> String? {
        symbolName(forActionName: NSStringFromSelector(selector))
    }
}

enum DisabledStatusMenuItemFactory {
    static func make(title: String, toolTip: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.toolTip = toolTip
        item.setAccessibilityHelp(toolTip)
        return item
    }
}

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
    private let activeBreakShortcuts = GlobalShortcutManager(signature: GlobalShortcutManager.signature("SRAB"))
    private let updateChecker = UpdateChecker()
    private var emergencyOverrideCoordinator = EmergencyOverrideCoordinator()
    private var preferencesWindowController: PreferencesWindowController?
    private var debugWindowController: DebugWindowController?
    private var aboutWindowController: AboutWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private var statusItem: NSStatusItem?
    private var tickTimer: DispatchSourceTimer?
    private var updateCheckTimer: Timer?
    private var lastFocusCheck = Date.distantPast
    private var focusModeActive = false
    private var suspendedAt: Date?
    private var pausedForSuspendOrLock = false
    private var manualAwaitingSessionID: UUID?
    private var latestReleaseURL: URL?
    private var pendingBodyBreakIdea: RestIdea?
    private var activeBodyBreakIdeas: [UUID: RestIdea] = [:]
    private var activeBreakShortcutSessionID: UUID?
    private var activeBreakShortcutValue: String?
    private var activeBreakShortcutRegistered = false
    private var emergencyEscapeShortcutSessionID: UUID?
    private var menuBarImageCache: [String: NSImage] = [:]
    private var currentMenuBarImageKey: String?
    private var lastGlobalShortcutFailureKey: String?
    private var lastActiveBreakShortcutFailureKey: String?
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
        UNUserNotificationCenter.current().delegate = self
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
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.tick()
            }
        }
        timer.resume()
        tickTimer = timer
        logger.log("Application launched")
        applyAppearanceSetting()
        applyOpenAtLoginSetting()
        configureGlobalShortcuts()
        scheduleAutomaticUpdateCheck()
        tick()
        showOnboardingIfNeeded()
        runPendingLaunchAutomation()
    }

    func applicationWillTerminate(_ notification: Notification) {
        tickTimer?.cancel()
        updateCheckTimer?.invalidate()
        unregisterActiveBreakShortcut()
        unregisterEmergencyEscapeShortcut()
        overlayController.dismiss()
        logger.log("Application terminated")
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        switch TerminationPolicy.requestAction(state: engine.state, settings: settings) {
        case .terminateNow:
            return .terminateNow
        case .armEyeGateEmergencyInOverlay:
            armEyeGateEmergencyForBlockedAction(actionName: "termination")
            logger.log("Termination blocked during active Eye Gate; Emergency Exit armed inside overlay")
        case .notifyBlocked(let kind):
            showAppNotification(title: L10n.tr("app.name"), body: BlockedActionCopy.quitMessage(for: kind))
            logger.log("Termination blocked during strict \(kind.rawValue)")
        }
        rebuildMenu()
        return .terminateCancel
    }

    @objc private func screenParametersChanged() {
        overlayController.reconcile()
    }

    private func createStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
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

        if consumeEmergencyAutomationSignalIfNeeded() {
            return
        }

        if let active = engine.state.activeSession {
            if emergencyOverrideCoordinator.armedSessionID != active.id {
                emergencyOverrideCoordinator.clear()
            }
            if case .deferred(let kind, let reason) = engine.deferActiveForAppExclusion(now: now, context: currentContext()) {
                unregisterActiveBreakShortcut()
                unregisterEmergencyEscapeShortcut()
                overlayController.dismiss()
                emergencyOverrideCoordinator.clear(sessionID: active.id)
                manualAwaitingSessionID = nil
                if active.kind == .bodyBreak, let idea = activeBodyBreakIdeas[active.id] {
                    pendingBodyBreakIdea = idea
                }
                clearActiveBodyBreakIdea(for: active)
                logger.log("Active \(kind.rawValue) deferred: \(MenuStatusPresenter.deferralReasonText(reason))")
                rebuildMenu()
                return
            }
            refreshActiveBreakShortcut()
            refreshEmergencyEscapeShortcut()
            let elapsed = now.timeIntervalSince(active.startedAt)
            let shouldAwaitManualFinish = elapsed >= active.duration && active.manualFinishEnabled
            overlayController.update(
                session: active,
                settings: overlaySettings(for: active),
                now: now,
                manualAwaiting: shouldAwaitManualFinish,
                emergencyOverrideAction: overlayEmergencyOverrideAction(for: active, now: now),
                emergencyOverrideArmed: emergencyOverrideCoordinator.isArmed(for: active),
                bodyActions: overlayBodyActions(for: active, now: now)
            )
            if shouldAwaitManualFinish {
                if manualAwaitingSessionID != active.id {
                    manualAwaitingSessionID = active.id
                    playRestSound(settings.rule(for: active.kind).finishSound)
                    logger.log("Entered manual finish phase for \(active.kind.rawValue)")
                }
                rebuildMenu()
                return
            }
            if elapsed >= active.duration {
                _ = engine.completeActive(now: now, reason: .completed)
                releaseActiveRestSurface(for: active)
                logger.log("Completed \(active.kind.rawValue)")
                rebuildMenu()
                playRestSound(settings.rule(for: active.kind).finishSound)
                return
            }
            rebuildMenu()
            return
        }

        emergencyOverrideCoordinator.clear()
        unregisterActiveBreakShortcut()
        unregisterEmergencyEscapeShortcut()
        let expiredPause = engine.state.pause.flatMap { pause in
            pause.isActive(at: now) ? nil : pause
        }
        let result = engine.evaluate(now: now, context: currentContext())
        handleEngineResult(result, now: now)
        if let expiredPause, engine.state.pause == nil {
            notifyAutomaticResume(from: expiredPause)
        }
        rebuildMenu()
    }

    private func handleEngineResult(_ result: RestEngineResult, now: Date) {
        switch result {
        case .started(let session):
            bindPendingBodyBreakIdea(to: session)
            playRestSound(settings.rule(for: session.kind).startSound)
            overlayController.present(
                session: session,
                settings: overlaySettings(for: session),
                now: now,
                emergencyOverrideAction: overlayEmergencyOverrideAction(for: session, now: now),
                emergencyOverrideArmed: emergencyOverrideCoordinator.isArmed(for: session),
                bodyActions: overlayBodyActions(for: session, now: now)
            )
            refreshActiveBreakShortcut()
            refreshEmergencyEscapeShortcut()
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
        let now = Date()
        let accessibilityDescription = MenuStatusPresenter.menuBarAccessibilityDescription(
            state: engine.state,
            settings: settings,
            now: now
        )
        let tooltip = MenuStatusPresenter.tooltip(state: engine.state, settings: settings, now: now)
        item.length = NSStatusItem.squareLength
        updateMenuBarImage(on: item, accessibilityDescription: accessibilityDescription)
        item.button?.imagePosition = .imageOnly
        item.button?.title = ""
        item.button?.toolTip = tooltip
        item.button?.setAccessibilityLabel(accessibilityDescription)
        item.button?.setAccessibilityHelp(tooltip)
        let showsOrdinaryControls = StatusMenuPolicy.showsOrdinaryControls(state: engine.state)

        let menu = NSMenu()
        menu.addItem(statusHeaderMenuItem(now: now))
        menu.addItem(.separator())

        if showsOrdinaryControls, !settings.admin.disableAppUpdateFeatures, latestReleaseURL != nil {
            menu.addItem(actionItem(L10n.tr("menu.downloadLatest"), #selector(openLatestRelease)))
            menu.addItem(.separator())
        }

        if engine.state.activeSession == nil {
            var addedManualRestAction = false
            if settings.eyeGate.isEnabled {
                menu.addItem(actionItem(L10n.tr("menu.takeEyeGateNow"), #selector(takeEyeGateNow)))
                addedManualRestAction = true
            }
            if settings.bodyBreak.isEnabled {
                menu.addItem(actionItem(L10n.tr("menu.takeBodyBreakNow"), #selector(takeBodyBreakNow)))
                addedManualRestAction = true
            }
            if let scheduled = engine.state.scheduled {
                menu.addItem(actionItem(
                    StatusMenuActionCopy.nextScheduledRestTitle(kind: scheduled.kind),
                    #selector(takeNextScheduledRestNow)
                ))
                addedManualRestAction = true
            }
            if addedManualRestAction {
                menu.addItem(.separator())
            }
        }

        if let active = engine.state.activeSession, active.kind == .eyeGate {
            let canEmergencyExit = canEmergencyOverrideEyeGate(active, now: now)
            if StatusMenuPolicy.showsOverlayOnlyNotice(state: engine.state, canEmergencyExit: canEmergencyExit) {
                menu.addItem(disabledItem(
                    L10n.tr("menu.emergencyOverlayOnly"),
                    symbolName: "info.circle",
                    toolTip: L10n.tr("menu.emergencyOverlayOnlyHelp")
                ))
                menu.addItem(.separator())
            }
            if !showsOrdinaryControls {
                setStatusMenu(menu, on: item)
                return
            }
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
            pauseMenu.addItem(actionItem(PauseMenuCopy.untilMorningTitle(settings: settings, now: now), #selector(pauseUntilMorning)))
            pauseMenu.addItem(.separator())
            pauseMenu.addItem(actionItem(
                PauseMenuCopy.indefiniteTitle(confirmsBeforePausing: shouldConfirmIndefinitePause()),
                #selector(pauseIndefinitely)
            ))
            let pauseItem = NSMenuItem(title: L10n.tr("menu.pause"), action: nil, keyEquivalent: "")
            pauseItem.image = menuItemImage("pause.circle")
            pauseItem.submenu = pauseMenu
            menu.addItem(pauseItem)
        }

        let resetItem = actionItem(L10n.tr("menu.reset"), #selector(resetBreaks))
        if let message = BlockedActionCopy.resetScheduleMessage(state: engine.state, settings: settings) {
            resetItem.isEnabled = false
            resetItem.toolTip = message
        } else {
            resetItem.isEnabled = true
        }
        menu.addItem(resetItem)
        menu.addItem(.separator())
        menu.addItem(actionItem(L10n.tr("menu.preferences"), #selector(openPreferences)))
        menu.addItem(supportMenuItem())

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: L10n.tr("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        if let message = BlockedActionCopy.quitMessage(state: engine.state, settings: settings) {
            quitItem.isEnabled = false
            quitItem.toolTip = message
        } else {
            quitItem.isEnabled = true
        }
        quitItem.image = menuItemImage("power")
        menu.addItem(quitItem)
        setStatusMenu(menu, on: item)
    }

    private func setStatusMenu(_ menu: NSMenu, on item: NSStatusItem) {
        while menu.items.last?.isSeparatorItem == true {
            menu.removeItem(at: menu.items.count - 1)
        }
        item.menu = menu
    }

    private func statusHeaderMenuItem(now: Date) -> NSMenuItem {
        let item = NSMenuItem()
        item.isEnabled = false
        item.view = StatusMenuHeaderView(
            content: MenuStatusPresenter.headerContent(
                state: engine.state,
                settings: settings,
                now: now
            )
        )
        return item
    }

    private func updateMenuBarImage(on item: NSStatusItem, accessibilityDescription: String) {
        let icon = MenuStatusPresenter.menuBarIcon(state: engine.state)
        let key = menuBarImageKey(for: icon)
        if currentMenuBarImageKey != key || item.button?.image == nil {
            currentMenuBarImageKey = key
            item.button?.image = menuBarImage(
                for: icon,
                key: key,
                accessibilityDescription: accessibilityDescription
            )
        }
        item.button?.image?.accessibilityDescription = accessibilityDescription
    }

    private func menuBarImageKey(for icon: MenuStatusPresenter.MenuBarIcon) -> String {
        StatusMenuImageFactory.cacheKey(for: icon)
    }

    private func menuBarImage(
        for icon: MenuStatusPresenter.MenuBarIcon,
        key: String,
        accessibilityDescription: String
    ) -> NSImage? {
        if let cached = menuBarImageCache[key] {
            cached.accessibilityDescription = accessibilityDescription
            return cached
        }

        let image = StatusMenuImageFactory.image(for: icon, accessibilityDescription: accessibilityDescription)
        menuBarImageCache[key] = image
        return image
    }

    private func menuItemImage(_ symbolName: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }

    private func disabledItem(_ title: String, symbolName: String? = nil, toolTip: String? = nil) -> NSMenuItem {
        let item = DisabledStatusMenuItemFactory.make(title: title, toolTip: toolTip)
        if let symbolName {
            item.image = menuItemImage(symbolName)
        }
        return item
    }

    private func settingsFileMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L10n.tr("menu.settingsFile"), action: nil, keyEquivalent: "")
        item.image = menuItemImage("doc.text")
        item.toolTip = settingsStore.fileURL.path

        let submenu = NSMenu()
        let showItem = actionItem(L10n.tr("menu.showSettingsFile"), #selector(showSettingsFile))
        showItem.toolTip = settingsStore.fileURL.path
        submenu.addItem(showItem)

        let copyItem = actionItem(L10n.tr("menu.copySettingsPath"), #selector(copySettingsPath))
        copyItem.toolTip = settingsStore.fileURL.path
        submenu.addItem(copyItem)

        item.submenu = submenu
        return item
    }

    private func supportMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L10n.tr("menu.support"), action: nil, keyEquivalent: "")
        item.image = menuItemImage("questionmark.circle")

        let submenu = NSMenu()
        if !settings.admin.disableAppUpdateFeatures {
            submenu.addItem(actionItem(L10n.tr("menu.checkUpdates"), #selector(checkForUpdatesNow)))
        }
        submenu.addItem(actionItem(L10n.tr("menu.about"), #selector(showAboutPanel)))
        submenu.addItem(.separator())
        submenu.addItem(actionItem(L10n.tr("menu.copyDebug"), #selector(copyDebugInfo)))
        submenu.addItem(actionItem(L10n.tr("menu.debugPanel"), #selector(openDebugPanel)))
        if !settings.admin.hideSettingsFileLocation {
            submenu.addItem(settingsFileMenuItem())
        }

        item.submenu = submenu
        return item
    }

    private func actionItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if let symbolName = StatusMenuActionIcon.symbolName(for: action) {
            item.image = menuItemImage(symbolName)
        }
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

    private func canEmergencyOverrideEyeGate(_ session: RestSession, now: Date) -> Bool {
        EmergencyOverrideCoordinator.isAvailable(
            session: session,
            policy: settings.eyeGate.emergencyOverride,
            now: now
        )
    }

    private func overlayEmergencyOverrideAction(for session: RestSession, now: Date) -> (() -> Void)? {
        guard canEmergencyOverrideEyeGate(session, now: now) else { return nil }
        return { [weak self] in
            self?.performEmergencyOverrideEyeGate()
        }
    }

    private func overlayBodyActions(for session: RestSession, now: Date) -> BodyOverlayActions? {
        let availability = OverlayActionPolicy.availability(
            for: session,
            now: now,
            canPostponeBodyBreak: canPostponeBodyBreak(session, now: now),
            canSkipBodyBreak: canSkipBodyBreak(session, now: now)
        )

        switch session.kind {
        case .eyeGate:
            guard availability.canFinish else { return nil }
            return BodyOverlayActions(
                canPostpone: false,
                canFinish: true,
                canSkip: false,
                postpone: nil,
                finish: { [weak self] in self?.finishActiveBreak() },
                skip: nil
            )
        case .bodyBreak:
            return BodyOverlayActions(
                canPostpone: availability.canPostpone,
                canFinish: availability.canFinish,
                canSkip: availability.canSkip,
                postpone: { [weak self] in self?.postponeBodyBreak() },
                finish: { [weak self] in self?.finishActiveBreak() },
                skip: { [weak self] in self?.skipBodyBreak() }
            )
        }
    }

    @objc private func takeEyeGateNow() {
        if case .started(let session) = engine.takeNow(.eyeGate) {
            playRestSound(settings.rule(for: session.kind).startSound)
            let now = Date()
            overlayController.present(
                session: session,
                settings: settings,
                now: now,
                emergencyOverrideAction: overlayEmergencyOverrideAction(for: session, now: now),
                emergencyOverrideArmed: emergencyOverrideCoordinator.isArmed(for: session),
                bodyActions: nil
            )
            refreshActiveBreakShortcut()
            refreshEmergencyEscapeShortcut()
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
            playRestSound(settings.rule(for: session.kind).startSound)
            let now = Date()
            overlayController.present(
                session: session,
                settings: overlaySettings(for: session),
                now: now,
                emergencyOverrideAction: overlayEmergencyOverrideAction(for: session, now: now),
                emergencyOverrideArmed: emergencyOverrideCoordinator.isArmed(for: session),
                bodyActions: overlayBodyActions(for: session, now: now)
            )
            refreshActiveBreakShortcut()
            refreshEmergencyEscapeShortcut()
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
            unregisterActiveBreakShortcut()
            unregisterEmergencyEscapeShortcut()
            overlayController.dismiss()
            if let active {
                emergencyOverrideCoordinator.clear(sessionID: active.id)
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
            releaseActiveRestSurface(for: active)
            logger.log("Manually finished \(active.kind.rawValue)")
            playRestSound(settings.rule(for: active.kind).finishSound)
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
            unregisterActiveBreakShortcut()
            unregisterEmergencyEscapeShortcut()
            clearActiveBodyBreakIdea(for: active)
            overlayController.dismiss()
            emergencyOverrideCoordinator.clear(sessionID: active.id)
            manualAwaitingSessionID = nil
            logger.log("Body Break skipped")
        } else {
            logger.log("Body Break skip denied")
        }
        rebuildMenu()
    }

    @objc private func endActiveBreakFromShortcut() {
        let now = Date()
        guard let active = engine.state.activeSession else { return }

        if now.timeIntervalSince(active.startedAt) >= active.duration {
            if active.kind == .bodyBreak || active.manualFinishEnabled {
                finishActiveBreak()
            }
            return
        }

        guard active.kind == .bodyBreak else { return }

        if case .postponed = engine.postponeActive(now: now) {
            unregisterActiveBreakShortcut()
            unregisterEmergencyEscapeShortcut()
            overlayController.dismiss()
            emergencyOverrideCoordinator.clear(sessionID: active.id)
            clearActiveBodyBreakIdea(for: active)
            logger.log("Body Break postponed by end shortcut")
        } else if case .completed = engine.skipActive(now: now) {
            unregisterActiveBreakShortcut()
            unregisterEmergencyEscapeShortcut()
            overlayController.dismiss()
            emergencyOverrideCoordinator.clear(sessionID: active.id)
            manualAwaitingSessionID = nil
            clearActiveBodyBreakIdea(for: active)
            logger.log("Body Break skipped by end shortcut")
        }
        rebuildMenu()
    }

    @objc private func emergencyOverrideEyeGate() {
        armEyeGateEmergencyForBlockedAction(actionName: "shortcut")
    }

    private func handleEmergencyAutomation() {
        guard engine.state.activeSession?.kind == .eyeGate else {
            logger.log("Emergency automation queued until active Eye Gate")
            return
        }
        logger.log("Emergency automation request received during active Eye Gate")
        _ = EmergencyAutomationSignal.consume()
        armEyeGateEmergencyForBlockedAction(actionName: "automation")
    }

    private func consumeEmergencyAutomationSignalIfNeeded() -> Bool {
        guard EmergencyAutomationSignal.isPending() else { return false }
        guard engine.state.activeSession?.kind == .eyeGate else {
            return false
        }
        _ = EmergencyAutomationSignal.consume()
        logger.log("Emergency automation signal consumed as overlay arming request")
        armEyeGateEmergencyForBlockedAction(actionName: "automation")
        return true
    }

    private func performEmergencyOverrideEyeGate() {
        guard let active = engine.state.activeSession, active.kind == .eyeGate else { return }

        let now = Date()
        let decision = emergencyOverrideCoordinator.request(
            session: active,
            policy: settings.eyeGate.emergencyOverride,
            now: now
        )
        handleEmergencyOverrideDecision(decision, session: active, now: now)
    }

    private func armEyeGateEmergencyForBlockedAction(actionName: String) {
        guard let active = engine.state.activeSession, active.kind == .eyeGate else { return }
        let now = Date()

        let decision = emergencyOverrideCoordinator.arm(
            session: active,
            policy: settings.eyeGate.emergencyOverride,
            now: now
        )
        switch decision {
        case .armed:
            handleEmergencyOverrideDecision(decision, session: active, now: now)
            _ = overlayController.activateEmergencyOverrideIfAvailable()
        case .complete:
            logger.log("Ignored external \(actionName) request as Emergency Exit confirmation")
        case .unavailable:
            logger.log("Blocked \(actionName) request could not arm Emergency Exit")
        }
    }

    private func handleEmergencyOverrideDecision(
        _ decision: EmergencyOverrideDecision,
        session: RestSession,
        now: Date
    ) {
        switch decision {
        case .armed:
            overlayController.update(
                session: session,
                settings: overlaySettings(for: session),
                now: now,
                manualAwaiting: false,
                emergencyOverrideAction: overlayEmergencyOverrideAction(for: session, now: now),
                emergencyOverrideArmed: emergencyOverrideCoordinator.isArmed(for: session),
                bodyActions: nil
            )
            logger.log("Emergency override armed for \(session.kind.rawValue), awaiting second overlay confirmation")
            rebuildMenu()
        case .complete:
            completeEmergencyOverrideEyeGate(
                session: session,
                now: now,
                playSound: true
            )
        case .unavailable:
            logger.log("Emergency override unavailable for \(session.kind.rawValue)")
            rebuildMenu()
        }
    }

    private func completeEmergencyOverrideEyeGate(
        session: RestSession,
        now: Date,
        playSound shouldPlaySound: Bool
    ) {
        logger.log("Emergency override completing for \(session.kind.rawValue)")
        let result = engine.emergencyOverride(now: now)
        logger.log("Emergency override engine result=\(result)")
        if case .completed(let completedSession, _) = result {
            releaseActiveRestSurface(for: session)
            logger.log("Emergency override completed for \(completedSession.kind.rawValue)")
            if shouldPlaySound {
                playRestSound(settings.rule(for: completedSession.kind).finishSound)
            }
        } else {
            logger.log("Emergency override denied result=\(result)")
        }
        rebuildMenu()
    }

    private func releaseActiveRestSurface(for session: RestSession) {
        unregisterActiveBreakShortcut()
        unregisterEmergencyEscapeShortcut()
        overlayController.dismiss()
        emergencyOverrideCoordinator.clear(sessionID: session.id)
        manualAwaitingSessionID = nil
        clearActiveBodyBreakIdea(for: session)
    }

    private func playRestSound(_ policy: SoundPolicy) {
        guard !settings.notifications.silentNotifications else { return }
        soundPlayer.play(policy)
    }

    private func notifyAutomaticResume(from pause: PauseState) {
        guard pause.reason == .user || pause.reason == .untilMorning else { return }
        showAppNotification(title: L10n.tr("app.name"), body: L10n.tr("notification.resumingBreaks"))
    }

    private func refreshActiveBreakShortcut() {
        guard let active = engine.state.activeSession,
              active.kind == .bodyBreak || active.manualFinishEnabled else {
            unregisterActiveBreakShortcut()
            return
        }

        let shortcut = settings.shortcuts.resolvedEndBodyBreakShortcut.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !shortcut.isEmpty else {
            unregisterActiveBreakShortcut()
            return
        }

        guard activeBreakShortcutSessionID != active.id ||
              activeBreakShortcutValue != shortcut else {
            return
        }

        activeBreakShortcuts.unregisterAll()
        activeBreakShortcutSessionID = active.id
        activeBreakShortcutValue = shortcut
        activeBreakShortcutRegistered = activeBreakShortcuts.register(shortcut: shortcut) { [weak self] in
            Task { @MainActor in
                self?.endActiveBreakFromShortcut()
            }
        }
        if activeBreakShortcutRegistered {
            logger.log("Active rest end shortcut registered kind=\(active.kind.rawValue) shortcut=\(shortcut)")
            lastActiveBreakShortcutFailureKey = nil
        } else {
            logger.log("Active rest end shortcut unavailable kind=\(active.kind.rawValue) shortcut=\(shortcut)")
            reportShortcutRegistrationFailures(
                [(ActiveRestShortcutCopy.title(for: active.kind), shortcut)],
                rememberedKey: \.lastActiveBreakShortcutFailureKey,
                namespace: "active"
            )
        }
    }

    private func unregisterActiveBreakShortcut() {
        guard activeBreakShortcutSessionID != nil ||
              activeBreakShortcutValue != nil ||
              activeBreakShortcutRegistered else {
            return
        }
        let wasRegistered = activeBreakShortcutRegistered
        activeBreakShortcuts.unregisterAll()
        activeBreakShortcutSessionID = nil
        activeBreakShortcutValue = nil
        activeBreakShortcutRegistered = false
        if wasRegistered {
            logger.log("Active rest end shortcut unregistered")
        } else {
            logger.log("Active rest end shortcut state cleared")
        }
    }

    private func refreshEmergencyEscapeShortcut() {
        guard let active = engine.state.activeSession,
              active.kind == .eyeGate,
              canEmergencyOverrideEyeGate(active, now: Date()) else {
            unregisterEmergencyEscapeShortcut()
            return
        }

        guard emergencyEscapeShortcutSessionID != active.id else { return }
        emergencyEscapeShortcutSessionID = active.id
        logger.log("Emergency Escape is routed by the overlay for Eye Gate")
    }

    private func unregisterEmergencyEscapeShortcut() {
        guard emergencyEscapeShortcutSessionID != nil else { return }
        emergencyEscapeShortcutSessionID = nil
        logger.log("Emergency Escape overlay routing state cleared")
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
        if shouldConfirmIndefinitePause(), !PauseIndefinitelyConfirmation.confirmed() {
            logger.log("Indefinite pause canceled")
            return
        }
        pause(for: nil, reason: .user)
    }

    private func shouldConfirmIndefinitePause() -> Bool {
        engine.state.activeSession == nil
    }

    private func pause(for duration: TimeInterval?, reason: PauseReason) {
        let active = engine.state.activeSession
        let result = engine.pause(for: duration, reason: reason)
        if case .paused = result {
            unregisterActiveBreakShortcut()
            unregisterEmergencyEscapeShortcut()
            overlayController.dismiss()
            if let active {
                clearActiveBodyBreakIdea(for: active)
            }
            logger.log("Breaks paused reason=\(reason.rawValue) duration=\(String(describing: duration))")
        } else if case .denied = result {
            handleBlockedPauseRequest()
        }
        rebuildMenu()
    }

    private func handleBlockedPauseRequest() {
        guard let feedback = StrictRestBlockedActionPolicy.feedback(state: engine.state, settings: settings) else {
            logger.log("Pause request denied without strict active rest")
            return
        }

        switch feedback {
        case .armEyeGateEmergencyInOverlay:
            armEyeGateEmergencyForBlockedAction(actionName: "pause")
            logger.log("Pause blocked during active Eye Gate; Emergency Exit armed inside overlay")
        case .notifyBlocked(let kind):
            showAppNotification(title: L10n.tr("app.name"), body: BlockedActionCopy.pauseMessage(for: kind))
            logger.log("Pause blocked during strict \(kind.rawValue)")
        }
    }

    @objc private func resetBreaks() {
        requestScheduleReset(confirmBeforeReset: true)
    }

    private func resetBreaksFromAutomation() {
        requestScheduleReset(confirmBeforeReset: false)
    }

    private func requestScheduleReset(confirmBeforeReset: Bool) {
        if let feedback = StrictRestBlockedActionPolicy.feedback(state: engine.state, settings: settings) {
            switch feedback {
            case .armEyeGateEmergencyInOverlay:
                armEyeGateEmergencyForBlockedAction(actionName: "reset")
                logger.log("Reset blocked during active Eye Gate; Emergency Exit armed inside overlay")
            case .notifyBlocked(let kind):
                showAppNotification(
                    title: L10n.tr("app.name"),
                    body: BlockedActionCopy.resetScheduleMessage(for: kind)
                )
                logger.log("Reset blocked during strict \(kind.rawValue)")
            }
            rebuildMenu()
            return
        }
        if confirmBeforeReset, !ResetScheduleConfirmation.confirmed() {
            logger.log("Schedule reset canceled")
            return
        }
        performScheduleReset()
    }

    private func performScheduleReset() {
        _ = engine.reset()
        unregisterActiveBreakShortcut()
        unregisterEmergencyEscapeShortcut()
        overlayController.dismiss()
        manualAwaitingSessionID = nil
        pendingBodyBreakIdea = nil
        activeBodyBreakIdeas.removeAll()
        cancelAutomationTasks()
        logger.log("Schedule reset")
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
            onUsePreset: { [weak self] preset in
                self?.completeOnboarding(rhythmPreset: preset, openPreferences: false)
            },
            onOpenPreferences: { [weak self] preset in
                self?.completeOnboarding(rhythmPreset: preset, openPreferences: true)
            },
            onLearnMore: { [weak self] in
                self?.showAboutPanel()
            }
        )
        onboardingWindowController?.show()
        NSApp.activate(ignoringOtherApps: true)
        logger.log("Onboarding shown")
    }

    private func completeOnboarding(rhythmPreset: RestRhythmPreset, openPreferences shouldOpenPreferences: Bool) {
        rhythmPreset.apply(to: &settings)
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

    @objc private func copyDebugInfo() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(debugInfo(), forType: .string)
        logger.log("Diagnostics copied")
    }

    @objc private func showSettingsFile() {
        reveal(url: settingsStore.fileURL)
        logger.log("Settings file revealed")
    }

    @objc private func copySettingsPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(settingsStore.fileURL.path, forType: .string)
        logger.log("Settings path copied")
    }

    @objc private func openDebugPanel() {
        if debugWindowController == nil {
            debugWindowController = DebugWindowController(
                debugInfoProvider: { [weak self] in
                    self?.debugInfo() ?? ""
                },
                safetySummaryProvider: { [weak self] in
                    self?.debugSafetySummary() ?? .ready
                }
            )
        }
        debugWindowController?.update(
            text: debugInfo(),
            logURL: settings.admin.hideSettingsFileLocation ? nil : logger.fileURL,
            settingsURL: settings.admin.hideSettingsFileLocation ? nil : settingsStore.fileURL
        )
        debugWindowController?.showWindow(nil)
        debugWindowController?.window?.makeKeyAndOrderFront(nil)
        debugWindowController?.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        logger.log("Diagnostics window opened")
    }

    @objc private func showAboutPanel() {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController(
                version: AppVersion.current,
                projectURL: URL(string: "https://github.com/metrovoc/shouldrest")!,
                onOpenDebug: { [weak self] in
                    self?.openDebugPanel()
                }
            )
        }
        aboutWindowController?.showWindow(nil)
        aboutWindowController?.window?.makeKeyAndOrderFront(nil)
        aboutWindowController?.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        logger.log("About panel opened")
    }

    private func reveal(url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            let parentURL = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true)
            NSWorkspace.shared.open(parentURL)
        }
    }

    private func applySettings(_ nextSettings: RestSettings) {
        settings = nextSettings
        engine.updateSettings(nextSettings)
        applyLanguageSetting()
        applyAppearanceSetting()
        applyOpenAtLoginSetting()
        applyMenuBarVisibility()
        configureGlobalShortcuts()
        refreshActiveBreakShortcut()
        refreshEmergencyEscapeShortcut()
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
        performAutomation(command, userInfo: notification.userInfo)
        logger.log("Handled automation command \(command.rawValue)")
    }

    private func runPendingLaunchAutomation() {
        guard let request = CommandLineAutomation.consumeLaunchRequest() else { return }
        performAutomation(request.command, userInfo: request.userInfo)
        logger.log("Handled launch automation command \(request.command.rawValue)")
    }

    private func performAutomation(_ command: AutomationCommand, userInfo: [AnyHashable: Any]?) {
        switch command {
        case .pause:
            pause(for: automationDuration(from: userInfo), reason: .user)
        case .resume:
            resumeBreaks()
        case .toggle:
            if engine.state.pause == nil {
                pause(for: nil, reason: .user)
            } else {
                resumeBreaks()
            }
        case .reset:
            resetBreaksFromAutomation()
        case .eye:
            handleEyeGateAutomation(userInfo)
        case .body:
            handleBodyBreakAutomation(userInfo)
        case .emergency:
            handleEmergencyAutomation()
        case .preferences:
            openPreferences()
        case .debug:
            copyDebugInfo()
        case .debugPanel:
            openDebugPanel()
        case .about:
            showAboutPanel()
        }
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
        if automationHasReadableContent(userInfo) {
            logger.log("Ignored Eye Gate readable content customization")
        }

        if let wait, wait > 0 {
            scheduleEyeGateAutomation(after: wait)
        } else if noSkip {
            logger.log("Kept current Eye Gate schedule for noskip automation")
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

    private func automationHasReadableContent(_ userInfo: [AnyHashable: Any]?) -> Bool {
        let title = (userInfo?["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let text = (userInfo?["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !title.isEmpty || !text.isEmpty
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
            unregisterActiveBreakShortcut()
            unregisterEmergencyEscapeShortcut()
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
        refreshActiveBreakShortcut()
        refreshEmergencyEscapeShortcut()
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
        let languageOverride = LanguageOption(identifier: settings.presentation.languageIdentifier).identifier
        L10n.languageOverride = languageOverride
        logger.log("Language applied override=\(languageOverride ?? "system")")
    }

    private func configureGlobalShortcuts() {
        globalShortcuts.unregisterAll()
        var failures: [(title: String, shortcut: String)] = []

        func register(_ title: String, _ shortcut: String, action: @MainActor @escaping () -> Void) {
            if !registerShortcut(shortcut, action: action) {
                failures.append((title, shortcut))
            }
        }

        register(L10n.tr("prefs.pauseToggle"), settings.shortcuts.pauseToggle) { [weak self] in
            if self?.engine.state.pause == nil {
                self?.pause(for: nil, reason: .user)
            } else {
                self?.resumeBreaks()
            }
        }
        register(L10n.tr("prefs.pause30Shortcut"), settings.shortcuts.pauseFor30Minutes) { [weak self] in
            self?.pause(for: 30 * 60, reason: .user)
        }
        register(L10n.tr("prefs.pause1hShortcut"), settings.shortcuts.pauseFor1Hour) { [weak self] in
            self?.pause(for: 60 * 60, reason: .user)
        }
        register(L10n.tr("prefs.pause2hShortcut"), settings.shortcuts.pauseFor2Hours) { [weak self] in
            self?.pause(for: 2 * 60 * 60, reason: .user)
        }
        register(L10n.tr("prefs.pause5hShortcut"), settings.shortcuts.pauseFor5Hours) { [weak self] in
            self?.pause(for: 5 * 60 * 60, reason: .user)
        }
        register(L10n.tr("prefs.pauseUntilMorningShortcut"), settings.shortcuts.pauseUntilMorning) { [weak self] in
            self?.pauseUntilMorning()
        }
        register(L10n.tr("prefs.nextScheduledRest"), settings.shortcuts.skipToNextScheduledRest ?? "") { [weak self] in
            self?.takeNextScheduledRestNow()
        }
        if settings.eyeGate.isEnabled {
            register(L10n.tr("prefs.eyeGateNow"), settings.shortcuts.takeEyeGateNow) { [weak self] in
                self?.takeEyeGateNow()
            }
        }
        if settings.bodyBreak.isEnabled {
            register(L10n.tr("prefs.bodyBreakNow"), settings.shortcuts.resolvedTakeBodyBreakNowShortcut) { [weak self] in
                self?.takeBodyBreakNow()
            }
        }
        if settings.eyeGate.isEnabled && settings.eyeGate.emergencyOverride.isEnabled {
            register(L10n.tr("prefs.emergencyEyeGate"), settings.shortcuts.resolvedEmergencyEyeGateOverride) { [weak self] in
                self?.emergencyOverrideEyeGate()
            }
        }
        register(L10n.tr("prefs.reset"), settings.shortcuts.reset) { [weak self] in
            self?.resetBreaks()
        }
        if failures.isEmpty {
            lastGlobalShortcutFailureKey = nil
            logger.log("Global shortcuts configured")
        } else {
            reportShortcutRegistrationFailures(
                failures,
                rememberedKey: \.lastGlobalShortcutFailureKey,
                namespace: "global"
            )
            logger.log("Global shortcuts configured with unavailable shortcuts=\(shortcutFailureDescription(failures))")
        }
    }

    private func scheduleAutomaticUpdateCheck() {
        updateCheckTimer?.invalidate()
        updateCheckTimer = nil

        guard settings.operations.checkForUpdates,
              !settings.admin.disableAppUpdateFeatures else {
            latestReleaseURL = nil
            return
        }

        Task { @MainActor in
            await runUpdateCheck(notifyWhenCurrent: false)
        }
        updateCheckTimer = Timer.scheduledTimer(withTimeInterval: 48 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.runUpdateCheck(notifyWhenCurrent: false)
            }
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
            if settings.operations.notifyNewVersion || notifyWhenCurrent {
                showAppNotification(
                    title: L10n.tr("notification.updateTitle"),
                    body: L10n.format("notification.updateAvailable", version),
                    openURL: result.releaseURL
                )
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

    private func showAppNotification(title: String, body: String, openURL: URL? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = AppNotificationUserInfo.payload(openURL: openURL)
        if !settings.notifications.silentNotifications {
            content.sound = .default
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func registerShortcut(_ shortcut: String, action: @MainActor @escaping () -> Void) -> Bool {
        let trimmedShortcut = shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedShortcut.isEmpty else { return true }
        let didRegister = globalShortcuts.register(shortcut: trimmedShortcut) {
            Task { @MainActor in
                action()
            }
        }
        if !didRegister {
            logger.log("Global shortcut unavailable shortcut=\(trimmedShortcut)")
        }
        return didRegister
    }

    private func reportShortcutRegistrationFailures(
        _ failures: [(title: String, shortcut: String)],
        rememberedKey: ReferenceWritableKeyPath<ShouldRestAppDelegate, String?>,
        namespace: String
    ) {
        guard !failures.isEmpty else {
            self[keyPath: rememberedKey] = nil
            return
        }

        let key = "\(namespace):\(shortcutFailureDescription(failures))"
        guard self[keyPath: rememberedKey] != key else { return }
        self[keyPath: rememberedKey] = key
        showAppNotification(
            title: L10n.tr("app.name"),
            body: L10n.format("notification.shortcutsUnavailable", shortcutFailureSummary(failures))
        )
    }

    private func shortcutFailureSummary(_ failures: [(title: String, shortcut: String)]) -> String {
        failures
            .map { "\($0.title) (\(ShortcutDisplay.string($0.shortcut)))" }
            .joined(separator: ", ")
    }

    private func shortcutFailureDescription(_ failures: [(title: String, shortcut: String)]) -> String {
        failures
            .map { "\($0.title)=\($0.shortcut.trimmingCharacters(in: .whitespacesAndNewlines))" }
            .sorted()
            .joined(separator: "|")
    }

    private func debugInfo() -> String {
        var lines: [String] = []

        if !settings.admin.hideSettingsFileLocation {
            lines.append("logPath=\(logger.fileURL.path)")
            lines.append("settingsPath=\(settingsStore.fileURL.path)")
            lines.append("supportPath=\(AppPaths.supportDirectory.path)")
            lines.append("bodyBreakImagePaths=\(settings.contentLibrary.localImagePaths)")
        }

        lines.append(contentsOf: [
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
        ])

        return lines.joined(separator: "\n")
    }

    private func debugSafetySummary() -> DebugSafetySummary {
        let now = Date()

        if let active = engine.state.activeSession {
            switch active.kind {
            case .eyeGate:
                if active.manualFinishEnabled && now.timeIntervalSince(active.startedAt) >= active.duration {
                    return DebugSafetySummary(
                        title: L10n.tr("debug.summaryEyeReadyTitle"),
                        body: L10n.tr("debug.summaryEyeReadyBody"),
                        symbolName: "checkmark.circle",
                        severity: .warning
                    )
                }
                return DebugSafetySummary(
                    title: L10n.tr("debug.summaryEyeActiveTitle"),
                    body: L10n.tr("debug.summaryEyeActiveBody"),
                    symbolName: "exclamationmark.shield",
                    severity: .active
                )
            case .bodyBreak:
                return DebugSafetySummary(
                    title: L10n.tr("debug.summaryBodyActiveTitle"),
                    body: L10n.tr("debug.summaryBodyActiveBody"),
                    symbolName: "figure.walk.circle",
                    severity: .warning
                )
            }
        }

        if engine.state.pause != nil {
            return DebugSafetySummary(
                title: L10n.tr("debug.summaryPausedTitle"),
                body: L10n.tr("debug.summaryPausedBody"),
                symbolName: "pause.circle",
                severity: .warning
            )
        }

        if let deferral = engine.state.activeDeferral {
            return DebugSafetySummary(
                title: L10n.format("debug.summaryDeferredTitle", MenuStatusPresenter.restKindName(deferral.kind)),
                body: L10n.format("debug.summaryDeferredBody", MenuStatusPresenter.deferralReasonText(deferral.reason)),
                symbolName: "clock.badge.exclamationmark",
                severity: .warning
            )
        }

        if let scheduled = engine.state.scheduled {
            return DebugSafetySummary(
                title: L10n.tr("debug.summaryScheduledTitle"),
                body: L10n.format(
                    "debug.summaryScheduledBody",
                    MenuStatusPresenter.restKindName(scheduled.kind),
                    scheduled.dueAt.formatted(date: .omitted, time: .shortened)
                ),
                symbolName: "calendar.badge.clock",
                severity: .ready
            )
        }

        return .ready
    }
}

enum EmergencyOverlayActivationResult: Equatable {
    case unavailable
    case activated
}

struct BodyOverlayActions {
    var canPostpone: Bool
    var canFinish: Bool
    var canSkip: Bool
    var postpone: (() -> Void)?
    var finish: (() -> Void)?
    var skip: (() -> Void)?
}

struct OverlayActionAvailability: Equatable {
    var canPostpone: Bool
    var canFinish: Bool
    var canSkip: Bool
}

enum OverlayActionPolicy {
    static func availability(
        for session: RestSession,
        now: Date,
        canPostponeBodyBreak: Bool,
        canSkipBodyBreak: Bool
    ) -> OverlayActionAvailability {
        let canFinish = now.timeIntervalSince(session.startedAt) >= session.duration
        switch session.kind {
        case .eyeGate:
            return OverlayActionAvailability(
                canPostpone: false,
                canFinish: session.manualFinishEnabled && canFinish,
                canSkip: false
            )
        case .bodyBreak:
            return OverlayActionAvailability(
                canPostpone: !canFinish && canPostponeBodyBreak,
                canFinish: canFinish,
                canSkip: !canFinish && canSkipBodyBreak
            )
        }
    }
}

private func isEmergencyOverrideKey(_ event: NSEvent) -> Bool {
    switch Int(event.keyCode) {
    case kVK_Escape:
        return true
    default:
        return false
    }
}

@MainActor
final class OverlayController {
    private var windows: [CGDirectDisplayID: OverlayWindow] = [:]
    private var session: RestSession?
    private var settings: RestSettings?
    private var emergencyOverrideAction: (() -> Void)?
    private var bodyActions: BodyOverlayActions?

    func present(
        session: RestSession,
        settings: RestSettings,
        now: Date,
        emergencyOverrideAction: (() -> Void)? = nil,
        emergencyOverrideArmed: Bool = false,
        bodyActions: BodyOverlayActions? = nil
    ) {
        self.session = session
        self.settings = settings
        self.emergencyOverrideAction = emergencyOverrideAction
        self.bodyActions = bodyActions
        NSApp.activate(ignoringOtherApps: true)
        reconcile()
        update(
            session: session,
            settings: settings,
            now: now,
            manualAwaiting: false,
            emergencyOverrideAction: emergencyOverrideAction,
            emergencyOverrideArmed: emergencyOverrideArmed,
            bodyActions: bodyActions
        )
    }

    func update(session: RestSession, settings: RestSettings, now: Date) {
        update(session: session, settings: settings, now: now, manualAwaiting: false, bodyActions: nil)
    }

    func update(
        session: RestSession,
        settings: RestSettings,
        now: Date,
        manualAwaiting: Bool,
        emergencyOverrideAction: (() -> Void)? = nil,
        emergencyOverrideArmed: Bool = false,
        bodyActions: BodyOverlayActions? = nil
    ) {
        self.session = session
        self.settings = settings
        self.emergencyOverrideAction = emergencyOverrideAction
        self.bodyActions = bodyActions
        let remaining = max(0, Int(session.duration - now.timeIntervalSince(session.startedAt)))
        let contentScreen = selectedContentScreen(for: session, settings: settings)
        let screens = coveredScreens(for: session, settings: settings, contentScreen: contentScreen)
        let emergencyRemaining = emergencyOverrideRemainingSeconds(for: session, settings: settings, now: now)

        for screen in screens {
            let id = screen.displayID
            let isContentScreen = shouldShowContent(on: screen, contentScreen: contentScreen, session: session, settings: settings)
            windows[id]?.overlayView.onEmergencyOverrideRequested = emergencyOverrideAction
            windows[id]?.overlayView.bodyActions = bodyActions
            windows[id]?.setFrame(screen.frame, display: true)
            windows[id]?.overlayView.configure(
                session: session,
                remainingSeconds: remaining,
                settings: settings,
                showsContent: isContentScreen,
                manualAwaiting: manualAwaiting,
                emergencyOverrideRemainingSeconds: emergencyRemaining,
                emergencyOverrideArmed: emergencyOverrideArmed,
                bodyActions: bodyActions
            )
            let level: NSWindow.Level
            if manualAwaiting && session.kind == .bodyBreak {
                level = .modalPanel
            } else {
                level = windowLevel(for: session, settings: settings)
            }
            windows[id]?.level = level
            windows[id]?.makeKeyAndOrderFront(nil)
            windows[id]?.orderFrontRegardless()
            if let window = windows[id] {
                window.makeFirstResponder(window.overlayView)
            }
        }
    }

    fileprivate func activateEmergencyOverrideIfAvailable() -> EmergencyOverlayActivationResult {
        for window in windows.values {
            switch window.overlayView.activateEmergencyOverrideIfAvailable() {
            case .activated:
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                window.makeFirstResponder(window.overlayView)
                return .activated
            case .unavailable:
                break
            }
        }
        return .unavailable
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
            windows[id]?.makeKeyAndOrderFront(nil)
            windows[id]?.orderFrontRegardless()
            if let window = windows[id] {
                window.makeFirstResponder(window.overlayView)
            }
        }
    }

    func dismiss() {
        for window in windows.values {
            window.close()
        }
        windows.removeAll()
        session = nil
        settings = nil
        emergencyOverrideAction = nil
        bodyActions = nil
    }

    private func emergencyOverrideRemainingSeconds(for session: RestSession, settings: RestSettings, now: Date) -> Int? {
        guard EmergencyOverrideCoordinator.isAvailable(
            session: session,
            policy: settings.eyeGate.emergencyOverride,
            now: now
        ) else {
            return nil
        }
        return 0
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
        self.overlayView = RestOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
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
        syncOverlayViewFrame(to: screen.frame.size)
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func keyDown(with event: NSEvent) {
        if isEmergencyOverrideKey(event) {
            overlayView.performEmergencyOverrideKeyCommand()
        } else {
            super.keyDown(with: event)
        }
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        syncOverlayViewFrame(to: frameRect.size)
    }

    private func syncOverlayViewFrame(to size: NSSize) {
        overlayView.frame = NSRect(origin: .zero, size: size)
    }
}

final class OverlayActionButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

private struct EmergencyOverlayVisualStyle {
    var buttonAlpha: CGFloat
    var tintAlpha: CGFloat
    var titleAlpha: CGFloat
    var panelBackgroundAlpha: CGFloat
    var panelBorderAlpha: CGFloat

    static func style(remainingSeconds: Int, isArmed: Bool) -> EmergencyOverlayVisualStyle {
        if remainingSeconds == 0 {
            return EmergencyOverlayVisualStyle(
                buttonAlpha: 0.48,
                tintAlpha: 0.64,
                titleAlpha: 0.64,
                panelBackgroundAlpha: 0.022,
                panelBorderAlpha: 0.082
            )
        }

        if isArmed {
            return EmergencyOverlayVisualStyle(
                buttonAlpha: 0.44,
                tintAlpha: 0.58,
                titleAlpha: 0.58,
                panelBackgroundAlpha: 0.018,
                panelBorderAlpha: 0.070
            )
        }

        return EmergencyOverlayVisualStyle(
            buttonAlpha: 0.38,
            tintAlpha: 0.50,
            titleAlpha: 0.50,
            panelBackgroundAlpha: 0.012,
            panelBorderAlpha: 0.052
        )
    }
}

enum OverlayCountdownFormatter {
    static func remainingText(seconds: Int) -> String {
        let clampedSeconds = max(0, seconds)
        guard clampedSeconds >= 60 else {
            return "\(clampedSeconds)s"
        }

        let hours = clampedSeconds / 3_600
        let minutes = (clampedSeconds % 3_600) / 60
        let secondsPart = clampedSeconds % 60

        if hours > 0 {
            return "\(hours):\(twoDigit(minutes)):\(twoDigit(secondsPart))"
        }
        return "\(minutes):\(twoDigit(secondsPart))"
    }

    private static func twoDigit(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}

@MainActor
final class RestOverlayView: NSView {
    private enum EmergencyHitTarget {
        case emergency
    }

    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let countdownLabel = NSTextField(labelWithString: "")
    private let imageView = NSImageView()
    private let emergencyPanel = NSView()
    private let emergencyButton = OverlayActionButton()
    private let bodyActionPanel = NSView()
    private let bodyActionStack = NSStackView()
    private let bodyPostponeButton = OverlayActionButton()
    private let bodySkipButton = OverlayActionButton()
    private let bodyFinishButton = OverlayActionButton()
    private var detailCacheKey: String?
    private var emergencyRemainingSeconds: Int?
    private var emergencyOverrideArmed = false
    private var emergencySessionID: UUID?
    private var emergencyPanelWidthConstraint: NSLayoutConstraint?
    private var emergencyPanelHeightConstraint: NSLayoutConstraint?
    private var bodyActionRequestPending = false
    var onEmergencyOverrideRequested: (() -> Void)?
    var bodyActions: BodyOverlayActions? {
        didSet {
            bodyActionRequestPending = false
            updateBodyActionButtons()
        }
    }

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
            label.lineBreakMode = .byCharWrapping
            label.cell?.wraps = true
            label.cell?.isScrollable = false
            addSubview(label)
        }

        titleLabel.identifier = NSUserInterfaceItemIdentifier("overlay.title.label")
        titleLabel.maximumNumberOfLines = 3
        titleLabel.font = .systemFont(ofSize: 34, weight: .semibold)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        detailLabel.identifier = NSUserInterfaceItemIdentifier("overlay.detail.label")
        detailLabel.maximumNumberOfLines = 5
        detailLabel.font = .systemFont(ofSize: 18, weight: .regular)
        detailLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        countdownLabel.identifier = NSUserInterfaceItemIdentifier("overlay.countdown.label")
        countdownLabel.maximumNumberOfLines = 1
        countdownLabel.font = .monospacedDigitSystemFont(ofSize: 28, weight: .medium)

        emergencyPanel.identifier = NSUserInterfaceItemIdentifier("overlay.emergency.panel")
        emergencyPanel.translatesAutoresizingMaskIntoConstraints = false
        emergencyPanel.wantsLayer = true
        emergencyPanel.layer?.cornerRadius = 7
        emergencyPanel.layer?.borderWidth = 1
        emergencyPanel.alphaValue = 0.72
        emergencyPanel.isHidden = true
        addSubview(emergencyPanel)

        emergencyButton.identifier = NSUserInterfaceItemIdentifier("overlay.emergency.button")
        emergencyButton.translatesAutoresizingMaskIntoConstraints = false
        emergencyButton.bezelStyle = .inline
        emergencyButton.isBordered = false
        emergencyButton.image = NSImage(
            systemSymbolName: "exclamationmark.triangle",
            accessibilityDescription: L10n.tr("overlay.emergencyOverride")
        )
        emergencyButton.imagePosition = .imageLeading
        emergencyButton.target = self
        emergencyButton.action = #selector(emergencyOverridePressed)
        emergencyButton.isHidden = true
        addSubview(emergencyButton)

        configureBodyActionButton(
            bodyPostponeButton,
            identifier: "overlay.bodyPostpone.button",
            title: L10n.tr("overlay.bodyPostpone"),
            symbolName: "clock.arrow.circlepath",
            toolTip: L10n.tr("overlay.bodyPostponeHelp"),
            action: #selector(bodyPostponePressed)
        )
        configureBodyActionButton(
            bodySkipButton,
            identifier: "overlay.bodySkip.button",
            title: L10n.tr("overlay.bodySkip"),
            symbolName: "forward.end",
            toolTip: L10n.tr("overlay.bodySkipHelp"),
            action: #selector(bodySkipPressed)
        )
        configureBodyActionButton(
            bodyFinishButton,
            identifier: "overlay.bodyFinish.button",
            title: L10n.tr("overlay.bodyFinish"),
            symbolName: "checkmark.circle",
            toolTip: L10n.tr("overlay.bodyFinishHelp"),
            action: #selector(bodyFinishPressed)
        )
        bodyActionPanel.identifier = NSUserInterfaceItemIdentifier("overlay.bodyActions.panel")
        bodyActionPanel.translatesAutoresizingMaskIntoConstraints = false
        bodyActionPanel.wantsLayer = true
        bodyActionPanel.layer?.cornerRadius = 8
        bodyActionPanel.layer?.borderWidth = 1
        bodyActionPanel.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.075).cgColor
        bodyActionPanel.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        bodyActionPanel.isHidden = true
        addSubview(bodyActionPanel)

        bodyActionStack.translatesAutoresizingMaskIntoConstraints = false
        bodyActionStack.orientation = .horizontal
        bodyActionStack.spacing = 12
        bodyActionStack.alignment = .centerY
        bodyActionStack.addArrangedSubview(bodyPostponeButton)
        bodyActionStack.addArrangedSubview(bodySkipButton)
        bodyActionStack.addArrangedSubview(bodyFinishButton)
        bodyActionStack.isHidden = true
        bodyActionPanel.addSubview(bodyActionStack)

        let emergencyPanelWidthConstraint = emergencyPanel.widthAnchor.constraint(equalToConstant: 164)
        let emergencyPanelHeightConstraint = emergencyPanel.heightAnchor.constraint(equalToConstant: 44)
        self.emergencyPanelWidthConstraint = emergencyPanelWidthConstraint
        self.emergencyPanelHeightConstraint = emergencyPanelHeightConstraint

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
            countdownLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emergencyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),
            emergencyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
            emergencyButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 126),
            emergencyButton.heightAnchor.constraint(equalToConstant: 28),
            emergencyPanel.trailingAnchor.constraint(equalTo: emergencyButton.trailingAnchor, constant: 12),
            emergencyPanel.bottomAnchor.constraint(equalTo: emergencyButton.bottomAnchor, constant: 10),
            emergencyPanelWidthConstraint,
            emergencyPanelHeightConstraint,
            bodyActionPanel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            bodyActionPanel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            bodyActionStack.leadingAnchor.constraint(equalTo: bodyActionPanel.leadingAnchor, constant: 12),
            bodyActionStack.trailingAnchor.constraint(equalTo: bodyActionPanel.trailingAnchor, constant: -12),
            bodyActionStack.topAnchor.constraint(equalTo: bodyActionPanel.topAnchor, constant: 8),
            bodyActionStack.bottomAnchor.constraint(equalTo: bodyActionPanel.bottomAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func layout() {
        let readableWidth = max(160, bounds.width * 0.7)
        titleLabel.preferredMaxLayoutWidth = readableWidth
        detailLabel.preferredMaxLayoutWidth = readableWidth
        super.layout()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if emergencyHitTarget(at: point) != nil {
            return self
        }
        return super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        switch emergencyHitTarget(at: point) {
        case .emergency:
            requestEmergencyOverride()
        case nil:
            super.mouseDown(with: event)
        }
    }

    override func keyDown(with event: NSEvent) {
        if isEmergencyOverrideKey(event) {
            performEmergencyOverrideKeyCommand()
        } else {
            super.keyDown(with: event)
        }
    }

    private func emergencyHitTarget(at point: NSPoint) -> EmergencyHitTarget? {
        if !emergencyButton.isHidden,
           emergencyActivationFrame().contains(point) {
            return .emergency
        }
        return nil
    }

    private func emergencyActivationFrame() -> NSRect {
        var buttonFrame = emergencyButton.frame.insetBy(dx: -24, dy: -16)
        if !emergencyPanel.isHidden {
            buttonFrame = buttonFrame.union(emergencyPanel.frame.insetBy(dx: -10, dy: -10))
        }
        let safetyFrame = NSRect(
            x: max(bounds.minX, bounds.maxX - 360),
            y: bounds.minY,
            width: min(360, bounds.width),
            height: min(140, bounds.height)
        )
        return buttonFrame.union(safetyFrame)
    }

    func configure(
        session: RestSession,
        remainingSeconds: Int,
        settings: RestSettings,
        showsContent: Bool,
        manualAwaiting: Bool,
        emergencyOverrideRemainingSeconds: Int?,
        emergencyOverrideArmed: Bool = false,
        bodyActions: BodyOverlayActions? = nil
    ) {
        let rule = settings.rule(for: session.kind)
        layer?.backgroundColor = NSColor(hex: rule.colorHex).withAlphaComponent(rule.enforcement.opacity).cgColor
        self.bodyActions = bodyActions
        let visibleEmergencyRemaining: Int?
        if manualAwaiting && session.kind == .eyeGate {
            visibleEmergencyRemaining = nil
        } else {
            visibleEmergencyRemaining = emergencyOverrideRemainingSeconds
        }
        configureEmergencyButton(
            sessionID: session.id,
            remainingSeconds: visibleEmergencyRemaining,
            isArmed: emergencyOverrideArmed
        )

        titleLabel.isHidden = !showsContent
        detailLabel.isHidden = !showsContent
        countdownLabel.isHidden = !showsContent
        imageView.isHidden = true
        imageView.image = nil

        guard showsContent else { return }

        if manualAwaiting {
            switch session.kind {
            case .eyeGate:
                titleLabel.stringValue = L10n.tr("overlay.eyeCompleteTitle")
                setDetailText(L10n.tr("overlay.eyeCompleteBody"), allowsRichText: false)
            case .bodyBreak:
                titleLabel.stringValue = L10n.tr("overlay.bodyCompleteTitle")
                setDetailText(L10n.tr("overlay.bodyCompleteBody"), allowsRichText: false)
            }
            countdownLabel.stringValue = L10n.tr("overlay.ready")
            return
        }

        switch session.kind {
        case .eyeGate:
            titleLabel.stringValue = L10n.tr("overlay.eyeTitle")
            setDetailText(L10n.tr("overlay.eyeBody"), allowsRichText: false)
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
        let remainingText = OverlayCountdownFormatter.remainingText(seconds: remainingSeconds)
        if session.kind == .bodyBreak, settings.presentation.showCurrentTimeDuringBodyBreak {
            countdownLabel.stringValue = "\(remainingText) · \(Date().formatted(date: .omitted, time: .shortened))"
        } else {
            countdownLabel.stringValue = remainingText
        }
    }

    @objc private func emergencyOverridePressed() {
        requestEmergencyOverride()
    }

    private func requestEmergencyOverride() {
        let confirmsAlreadyArmedEmergency = emergencyOverrideArmed
        if case .activated = activateEmergencyOverrideIfAvailable() {
            armEmergencyOverrideLocallyIfNeeded()
            let request = onEmergencyOverrideRequested
            if confirmsAlreadyArmedEmergency {
                // Let AppKit unwind the click/key event before the handler closes overlay windows.
                DispatchQueue.main.async {
                    request?()
                }
            } else {
                request?()
            }
        }
    }

    @objc private func bodyPostponePressed() {
        requestBodyActionIfAvailable(bodyActions?.canPostpone == true, action: bodyActions?.postpone)
    }

    @objc private func bodySkipPressed() {
        requestBodyActionIfAvailable(bodyActions?.canSkip == true, action: bodyActions?.skip)
    }

    @objc private func bodyFinishPressed() {
        requestBodyActionIfAvailable(bodyActions?.canFinish == true, action: bodyActions?.finish)
    }

    private func requestBodyActionIfAvailable(_ isAvailable: Bool, action: (() -> Void)?) {
        guard isAvailable,
              let action,
              !bodyActionRequestPending else {
            return
        }
        bodyActionRequestPending = true
        updateBodyActionButtons()
        DispatchQueue.main.async {
            action()
        }
    }

    func performEmergencyOverrideKeyCommand() {
        requestEmergencyOverride()
    }

    func performBodyPostponeAction() {
        bodyPostponePressed()
    }

    func performBodySkipAction() {
        bodySkipPressed()
    }

    func performBodyFinishAction() {
        bodyFinishPressed()
    }

    func activateEmergencyOverrideIfAvailable() -> EmergencyOverlayActivationResult {
        guard !emergencyButton.isHidden,
              emergencyRemainingSeconds != nil else {
            return .unavailable
        }

        return .activated
    }

    private func armEmergencyOverrideLocallyIfNeeded() {
        guard emergencyRemainingSeconds != nil,
              !emergencyOverrideArmed else {
            return
        }
        emergencyRemainingSeconds = 0
        emergencyOverrideArmed = true
        updateEmergencyAffordanceUI()
    }

    private func configureEmergencyButton(
        sessionID: UUID,
        remainingSeconds: Int?,
        isArmed: Bool
    ) {
        if emergencySessionID != sessionID {
            emergencySessionID = sessionID
        }

        emergencyRemainingSeconds = remainingSeconds
        emergencyOverrideArmed = isArmed

        guard remainingSeconds != nil else {
            emergencyPanel.isHidden = true
            emergencyButton.isHidden = true
            return
        }

        emergencyButton.isHidden = false
        emergencyButton.isEnabled = true
        updateEmergencyAffordanceUI()
        emergencyButton.toolTip = L10n.tr("overlay.emergencyOverrideHelp")
    }

    private func updateEmergencyAffordanceUI() {
        guard let remainingSeconds = emergencyRemainingSeconds else { return }

        emergencyPanel.isHidden = false
        emergencyPanelWidthConstraint?.constant = 188
        emergencyPanelHeightConstraint?.constant = 44
        let style = EmergencyOverlayVisualStyle.style(
            remainingSeconds: emergencyOverrideArmed ? 0 : remainingSeconds,
            isArmed: emergencyOverrideArmed
        )
        emergencyPanel.layer?.backgroundColor = NSColor.systemRed
            .withAlphaComponent(style.panelBackgroundAlpha)
            .cgColor
        emergencyPanel.layer?.borderColor = NSColor.systemRed
            .withAlphaComponent(style.panelBorderAlpha)
            .cgColor
        emergencyButton.alphaValue = style.buttonAlpha
        emergencyButton.contentTintColor = NSColor.systemRed.withAlphaComponent(style.tintAlpha)

        let title: String
        if emergencyOverrideArmed {
            title = L10n.tr("overlay.emergencyOverrideConfirm")
        } else {
            title = L10n.tr("overlay.emergencyOverride")
        }
        setEmergencyButtonTitle(
            title,
            style: style
        )
    }

    private func setEmergencyButtonTitle(_ title: String, style: EmergencyOverlayVisualStyle) {
        emergencyButton.setAccessibilityLabel(title)
        emergencyButton.setAccessibilityHelp(L10n.tr("overlay.emergencyOverrideHelp"))
        emergencyButton.image?.accessibilityDescription = title
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.systemRed.withAlphaComponent(style.titleAlpha),
            .font: NSFont.systemFont(ofSize: 13, weight: .medium)
        ]
        emergencyButton.attributedTitle = NSAttributedString(string: title, attributes: attributes)
    }

    private func configureBodyActionButton(
        _ button: OverlayActionButton,
        identifier: String,
        title: String,
        symbolName: String,
        toolTip: String,
        action: Selector
    ) {
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .inline
        button.isBordered = false
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        button.contentTintColor = NSColor.white.withAlphaComponent(0.72)
        button.toolTip = toolTip
        button.setAccessibilityLabel(title)
        button.setAccessibilityHelp(toolTip)
        button.target = self
        button.action = action
        button.alphaValue = 0.78
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 112).isActive = true
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.82),
                .font: NSFont.systemFont(ofSize: 13, weight: .medium)
            ]
        )
    }

    private func updateBodyActionButtons() {
        let actions = bodyActions
        bodyPostponeButton.isHidden = !(actions?.canPostpone ?? false)
        bodySkipButton.isHidden = !(actions?.canSkip ?? false)
        bodyFinishButton.isHidden = !(actions?.canFinish ?? false)
        [bodyPostponeButton, bodySkipButton, bodyFinishButton].forEach { button in
            button.isEnabled = !button.isHidden && !bodyActionRequestPending
            button.alphaValue = bodyActionRequestPending ? 0.42 : 0.78
        }
        bodyActionStack.isHidden = bodyPostponeButton.isHidden && bodySkipButton.isHidden && bodyFinishButton.isHidden
        bodyActionPanel.isHidden = bodyActionStack.isHidden
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

final class SoundPlayer: NSObject, NSSoundDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.shouldrest.sound-player", qos: .utility)
    private var activeSounds: [NSSound] = []

    func play(_ policy: SoundPolicy) {
        queue.async { [weak self] in
            self?.playOnQueue(policy)
        }
    }

    private func playOnQueue(_ policy: SoundPolicy) {
        switch policy {
        case .silent:
            return
        case .named(let name, let volume):
            guard let sound = bundledSound(named: name) ?? NSSound(named: NSSound.Name(name)) ?? NSSound(named: .init("Glass")) else {
                return
            }
            sound.volume = Float(min(1, max(0, volume)))
            sound.delegate = self
            activeSounds.append(sound)
            if !sound.play() {
                activeSounds.removeAll { $0 === sound }
            }
        }
    }

    func sound(_ sound: NSSound, didFinishPlaying finishedPlaying: Bool) {
        queue.async { [weak self] in
            self?.activeSounds.removeAll { $0 === sound }
        }
    }

    private func bundledSound(named name: String) -> NSSound? {
        let option = SoundOption(name: name)
        guard let url = option.bundledResourceURL else {
            return nil
        }
        return NSSound(contentsOf: url, byReference: false)
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

extension ShouldRestAppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let url = AppNotificationUserInfo.url(from: response.notification.request.content.userInfo) else {
            return
        }
        Task { @MainActor in
            NSWorkspace.shared.open(url)
        }
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

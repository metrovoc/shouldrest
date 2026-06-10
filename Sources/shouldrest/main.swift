import AppKit
import Carbon
import Foundation
import IOKit
import QuartzCore
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

enum RestNotificationCopy {
    static func title(for kind: RestKind) -> String {
        MenuStatusPresenter.restKindName(kind)
    }

    static func body(for kind: RestKind) -> String {
        switch kind {
        case .eyeGate:
            return L10n.tr("notification.eyeGateSoon")
        case .bodyBreak:
            return L10n.tr("notification.bodyBreakSoon")
        }
    }
}

enum TerminationPolicy {
    enum RequestAction: Equatable {
        case terminateNow
        case focusEyeGateEmergencyInOverlay
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
        case .focusEyeGateEmergencyInOverlay:
            return .focusEyeGateEmergencyInOverlay
        case .notifyBlocked(let kind):
            return .notifyBlocked(kind)
        }
    }
}

enum ApplicationReopenPolicy {
    enum Action: Equatable {
        case allowSystemReopen
        case openPreferences
        case restoreActiveOverlay
    }

    static func action(state: RestEngineState, hasVisibleWindows: Bool) -> Action {
        if hasVisibleWindows {
            return .allowSystemReopen
        }
        if state.activeSession != nil {
            return .restoreActiveOverlay
        }
        return .openPreferences
    }
}

enum StrictRestBlockedActionPolicy {
    enum Feedback: Equatable {
        case focusEyeGateEmergencyInOverlay
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
            return .focusEyeGateEmergencyInOverlay
        }

        return .notifyBlocked(kind)
    }
}

enum BlockedActionCopy {
    static func quitMessageForAvailableEyeGateEmergency() -> String {
        L10n.tr("notification.quitBlockedEyeGateEmergency")
    }

    static func quitMessage(for kind: RestKind) -> String {
        L10n.format("notification.quitBlocked", MenuStatusPresenter.restKindName(kind))
    }

    static func quitMessage(state: RestEngineState, settings: RestSettings, now: Date = Date()) -> String? {
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
            return quitMessageForAvailableEyeGateEmergency()
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
    static func durationTitle(_ title: String, duration: TimeInterval, now: Date = Date()) -> String {
        let target = now.addingTimeInterval(duration)
        return L10n.format("menu.pauseDurationWithTime", title, target.formatted(date: .omitted, time: .shortened))
    }

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

    static func showsOverlayReturnAction(state: RestEngineState, canEmergencyExit: Bool) -> Bool {
        state.activeSession?.kind == .eyeGate && canEmergencyExit
    }
}

enum StrictRestStatusMenuPolicy {
    static func showsSafeSupportReportCopy(state: RestEngineState) -> Bool {
        state.activeSession?.kind == .eyeGate
    }

    static func showsDisabledQuitExplanation(state: RestEngineState, settings: RestSettings) -> Bool {
        BlockedActionCopy.quitMessage(state: state, settings: settings) != nil
    }
}

enum MenuBarVisibilityPolicy {
    static func showsStatusItem(settings: RestSettings) -> Bool {
        settings.presentation.resolvedShowMenuBarItem
    }
}

enum RestContextPolicy {
    static func make(
        settings: RestSettings,
        now: Date,
        idleDuration: TimeInterval,
        focusModeActive: Bool,
        appExclusions: [AppExclusionEvaluation]
    ) -> RestContext {
        RestContext(
            idleDuration: idleDuration,
            focusModeActive: focusModeActive,
            inWorkingHours: settings.workingHours.contains(now),
            appExclusions: appExclusions
        )
    }
}

enum SystemSuspendPausePolicy {
    static func shouldPauseScheduler(state: RestEngineState) -> Bool {
        state.activeSession == nil && state.pause == nil
    }

    static func hasSuspendOrLockPause(state: RestEngineState) -> Bool {
        state.activeSession == nil && state.pause?.reason == .suspendOrLock
    }
}

enum SystemResumeIdlePolicy {
    static func effectiveIdleDuration(
        preSuspendIdleDuration: TimeInterval = 0,
        suspendedIdleDuration: TimeInterval,
        didPauseScheduler _: Bool
    ) -> TimeInterval {
        max(0, preSuspendIdleDuration) + max(0, suspendedIdleDuration)
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
            return "play.circle"
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
        case "copySupportReport":
            return "doc.on.doc"
        case "openSupportReportPanel":
            return "doc.text.magnifyingglass"
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

enum StatusMenuActionHelp {
    static func help(forActionName actionName: String) -> String? {
        switch actionName.replacingOccurrences(of: ":", with: "") {
        case "openLatestRelease":
            return L10n.tr("menu.downloadLatestHelp")
        case "takeEyeGateNow":
            return L10n.tr("menu.takeEyeGateNowHelp")
        case "takeBodyBreakNow":
            return L10n.tr("menu.takeBodyBreakNowHelp")
        case "takeNextScheduledRestNow":
            return L10n.tr("menu.takeNextScheduledRestNowHelp")
        case "finishActiveBreak":
            return L10n.tr("menu.finishActiveBreakHelp")
        case "emergencyOverrideEyeGate":
            return L10n.tr("menu.emergencyOverrideHelp")
        case "postponeBodyBreak":
            return L10n.tr("menu.postponeBodyBreakHelp")
        case "skipBodyBreak":
            return L10n.tr("menu.skipBodyBreakHelp")
        case "resumeBreaks":
            return L10n.tr("menu.resumeHelp")
        case "pauseFor30Minutes", "pauseFor1Hour", "pauseFor2Hours", "pauseFor5Hours":
            return L10n.tr("menu.pauseDurationHelp")
        case "pauseUntilMorning":
            return L10n.tr("menu.pauseUntilMorningHelp")
        case "pauseIndefinitely":
            return L10n.tr("menu.pauseIndefinitelyHelp")
        case "resetBreaks":
            return L10n.tr("menu.resetHelp")
        case "openPreferences":
            return L10n.tr("menu.preferencesHelp")
        case "checkForUpdatesNow":
            return L10n.tr("menu.checkUpdatesHelp")
        case "copySupportReport":
            return L10n.tr("menu.copyDebugHelp")
        case "openSupportReportPanel":
            return L10n.tr("menu.debugPanelHelp")
        case "showAboutPanel":
            return L10n.tr("menu.aboutHelp")
        case "showSettingsFile":
            return L10n.tr("menu.showSettingsFileHelp")
        case "copySettingsPath":
            return L10n.tr("menu.copySettingsPathHelp")
        default:
            return nil
        }
    }

    static func help(for selector: Selector) -> String? {
        help(forActionName: NSStringFromSelector(selector))
    }
}

enum DisabledStatusMenuItemFactory {
    static func make(title: String, toolTip: String? = nil, symbolName: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        if let symbolName {
            item.image = image(symbolName, accessibilityDescription: title)
        }
        StatusMenuItemPresentation.apply(title: title, help: toolTip, to: item)
        return item
    }

    private static func image(_ symbolName: String, accessibilityDescription: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        image?.accessibilityDescription = accessibilityDescription
        return image
    }
}

enum StatusMenuItemPresentation {
    static func apply(title: String? = nil, help: String?, to item: NSMenuItem) {
        let accessibilityTitle = title ?? (item.title.isEmpty ? nil : item.title)
        item.toolTip = help
        item.setAccessibilityLabel(accessibilityTitle)
        item.setAccessibilityHelp(help)
        item.image?.accessibilityDescription = accessibilityTitle
    }
}

enum StatusMenuOverlayFocusItemFactory {
    static func make(
        target: AnyObject?,
        action: Selector,
        imageProvider: (String) -> NSImage? = { _ in nil }
    ) -> NSMenuItem {
        let item = NSMenuItem(title: L10n.tr("menu.emergencyOverlayOnly"), action: action, keyEquivalent: "")
        item.target = target
        item.image = imageProvider("exclamationmark.triangle")
        item.image?.isTemplate = true
        StatusMenuItemPresentation.apply(
            title: item.title,
            help: L10n.tr("menu.emergencyOverlayOnlyHelp"),
            to: item
        )
        return item
    }
}

enum StatusMenuClipboardFeedback {
    enum Kind {
        case supportReport
        case settingsPath

        var notificationBody: String {
            switch self {
            case .supportReport:
                return L10n.tr("menu.copyDebugDone")
            case .settingsPath:
                return L10n.tr("menu.copySettingsPathDone")
            }
        }
    }

    @discardableResult
    static func copy(_ string: String, kind: Kind, pasteboard: NSPasteboard = .general) -> String {
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        return kind.notificationBody
    }
}

enum StatusMenuSettingsLocationMenuItemFactory {
    static func make(
        target: AnyObject?,
        showAction: Selector,
        copyAction: Selector,
        imageProvider: (String) -> NSImage? = { _ in nil }
    ) -> NSMenuItem {
        let item = NSMenuItem(title: L10n.tr("menu.settingsFile"), action: nil, keyEquivalent: "")
        item.image = imageProvider("folder")
        item.image?.accessibilityDescription = item.title
        setHelp(L10n.tr("menu.settingsFileHelp"), on: item)

        let submenu = NSMenu()
        submenu.addItem(actionItem(
            title: L10n.tr("menu.showSettingsFile"),
            action: showAction,
            target: target,
            imageProvider: imageProvider
        ))
        submenu.addItem(actionItem(
            title: L10n.tr("menu.copySettingsPath"),
            action: copyAction,
            target: target,
            imageProvider: imageProvider
        ))

        item.submenu = submenu
        return item
    }

    private static func actionItem(
        title: String,
        action: Selector,
        target: AnyObject?,
        imageProvider: (String) -> NSImage?
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        if let symbolName = StatusMenuActionIcon.symbolName(for: action) {
            item.image = imageProvider(symbolName)
            item.image?.accessibilityDescription = title
        }
        setHelp(StatusMenuActionHelp.help(for: action), on: item)
        return item
    }

    private static func setHelp(_ help: String?, on item: NSMenuItem) {
        StatusMenuItemPresentation.apply(help: help, to: item)
    }
}

@MainActor
struct BodyBreakIdeaAssignments: Equatable {
    private(set) var pending: RestIdea?
    private(set) var active: [UUID: RestIdea] = [:]

    mutating func storePending(_ idea: RestIdea) {
        pending = idea
    }

    @discardableResult
    mutating func storePendingIfPresent(_ idea: RestIdea?) -> Bool {
        guard let idea else { return false }
        storePending(idea)
        return true
    }

    func ideaForStartAttempt(explicit idea: RestIdea?) -> RestIdea? {
        idea ?? pending
    }

    mutating func bindStartedIdea(_ idea: RestIdea?, to session: RestSession) {
        guard session.kind == .bodyBreak else { return }
        if let idea {
            active[session.id] = idea
        }
        pending = nil
    }

    mutating func bindPending(to session: RestSession) {
        guard session.kind == .bodyBreak, let pending else { return }
        active[session.id] = pending
        self.pending = nil
    }

    mutating func deferActiveIdeaToPending(for session: RestSession) {
        guard session.kind == .bodyBreak, let idea = active.removeValue(forKey: session.id) else { return }
        pending = idea
    }

    func activeIdea(for session: RestSession) -> RestIdea? {
        active[session.id]
    }

    mutating func clearActive(for session: RestSession) {
        active.removeValue(forKey: session.id)
    }

    mutating func clearAll() {
        pending = nil
        active.removeAll()
    }
}

@MainActor
final class ShouldRestAppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore: SettingsStore
    private let logger = AppLogger()
    private var settings: RestSettings
    private var engine: RestEngine
    private let overlayController = OverlayController()
    private let preRestCueController = PreRestCueController()
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
    private var suspendedIdleBeforePause: TimeInterval = 0
    private var pausedForSuspendOrLock = false
    private var manualAwaitingSessionID: UUID?
    private var latestReleaseURL: URL?
    private var bodyBreakIdeas = BodyBreakIdeaAssignments()
    private var activeBreakShortcutSessionID: UUID?
    private var activeBreakShortcutValue: String?
    private var activeBreakShortcutRegistered = false
    private var emergencyEscapeShortcutSessionID: UUID?
    private var menuBarImageCache: [String: NSImage] = [:]
    private var currentMenuBarImageKey: String?
    private var lastGlobalShortcutFailureKey: String?
    private var lastActiveBreakShortcutFailureKey: String?
    private var automationTasks: [UUID: Task<Void, Never>] = [:]
    private var pendingAutomationStarts = PendingAutomationStartRequests()

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
        preRestCueController.dismiss()
        overlayController.dismiss()
        logger.log("Application terminated")
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        switch TerminationPolicy.requestAction(state: engine.state, settings: settings) {
        case .terminateNow:
            return .terminateNow
        case .focusEyeGateEmergencyInOverlay:
            focusEyeGateEmergencyForBlockedAction(actionName: "termination")
            logger.log("Termination blocked during active Eye Gate; Emergency Exit focused inside overlay")
        case .notifyBlocked(let kind):
            showAppNotification(title: L10n.tr("app.name"), body: BlockedActionCopy.quitMessage(for: kind))
            logger.log("Termination blocked during strict \(kind.rawValue)")
        }
        rebuildMenu()
        return .terminateCancel
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        switch ApplicationReopenPolicy.action(state: engine.state, hasVisibleWindows: flag) {
        case .allowSystemReopen:
            return true
        case .openPreferences:
            openPreferences()
            logger.log("Application reopen opened Preferences")
            return false
        case .restoreActiveOverlay:
            restoreActiveOverlayForReopen()
            return false
        }
    }

    @objc private func screenParametersChanged() {
        overlayController.reconcile()
        preRestCueController.reconcile()
    }

    private func createStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        rebuildMenu()
    }

    private func applyMenuBarVisibility() {
        if MenuBarVisibilityPolicy.showsStatusItem(settings: settings) {
            createStatusItem()
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func tick() {
        let now = Date()

        refreshFocusMode(now: now)

        if consumeEmergencyAutomationSignalIfNeeded() {
            return
        }

        if engine.state.activeSession != nil {
            handleActiveRestLifecycle(
                now: now,
                context: currentContext(now: now)
            )
            return
        }

        emergencyOverrideCoordinator.clear()
        unregisterActiveBreakShortcut()
        unregisterEmergencyEscapeShortcut()
        let expiredPause = engine.state.pause.flatMap { pause in
            pause.isActive(at: now) ? nil : pause
        }
        let result = engine.evaluate(now: now, context: currentContext(now: now))
        handleEngineResult(result, now: now)
        if let expiredPause, engine.state.pause == nil {
            notifyAutomaticResume(from: expiredPause)
        }
        retryPendingAutomationStarts()
        rebuildMenu()
    }

    private func handleActiveRestLifecycle(
        now: Date,
        context: RestContext
    ) {
        guard let active = engine.state.activeSession else {
            rebuildMenu()
            return
        }

        if emergencyOverrideCoordinator.armedSessionID != active.id {
            emergencyOverrideCoordinator.clear()
        }

        switch ActiveRestLifecyclePolicy.decision(
            for: active,
            settings: settings,
            now: now,
            context: context
        ) {
        case .naturalCompletion:
            let result = engine.evaluate(now: now, context: context)
            if case .completed(let session, let reason) = result {
                releaseActiveRestSurface(for: session)
                logger.log("Completed \(session.kind.rawValue) after natural away reason=\(reason)")
                retryPendingAutomationStarts()
                rebuildMenu()
                return
            }
            handleActiveRestLifecycle(
                now: now,
                context: context
            )
        case .elapsedCompletion:
            if case .completed = engine.completeActive(
                now: now,
                reason: .completed,
                idleDuration: context.idleDuration,
                preserveAwayCandidate: context.idleDuration > 0
            ) {
                releaseActiveRestSurface(for: active)
                logger.log("Completed \(active.kind.rawValue)")
                playRestSound(settings.rule(for: active.kind).finishSound)
                retryPendingAutomationStarts()
            }
            rebuildMenu()
        case .present(let manualAwaiting):
            if case .deferred(let kind, let reason) = engine.deferActiveForAppExclusion(
                now: now,
                context: context
            ) {
                unregisterActiveBreakShortcut()
                unregisterEmergencyEscapeShortcut()
                preRestCueController.dismiss()
                overlayController.dismiss()
                emergencyOverrideCoordinator.clear(sessionID: active.id)
                manualAwaitingSessionID = nil
                bodyBreakIdeas.deferActiveIdeaToPending(for: active)
                logger.log("Active \(kind.rawValue) deferred: \(MenuStatusPresenter.deferralReasonText(reason))")
                rebuildMenu()
                return
            }
            refreshActiveBreakShortcut()
            refreshEmergencyEscapeShortcut()
            overlayController.update(
                session: active,
                settings: overlaySettings(for: active),
                now: now,
                manualAwaiting: manualAwaiting,
                emergencyOverrideAction: overlayEmergencyOverrideAction(for: active, now: now),
                emergencyOverrideArmed: emergencyOverrideCoordinator.isArmed(for: active, now: now),
                bodyActions: overlayBodyActions(for: active, now: now)
            )
            if manualAwaiting, manualAwaitingSessionID != active.id {
                manualAwaitingSessionID = active.id
                playRestSound(settings.rule(for: active.kind).finishSound)
                logger.log("Entered manual finish phase for \(active.kind.rawValue)")
            }
            rebuildMenu()
        }
    }

    private func handleEngineResult(_ result: RestEngineResult, now: Date) {
        switch result {
        case .started(let session):
            preRestCueController.dismiss()
            bindPendingBodyBreakIdea(to: session)
            playRestSound(settings.rule(for: session.kind).startSound)
            overlayController.present(
                session: session,
                settings: overlaySettings(for: session),
                now: now,
                emergencyOverrideAction: overlayEmergencyOverrideAction(for: session, now: now),
                emergencyOverrideArmed: emergencyOverrideCoordinator.isArmed(for: session, now: now),
                bodyActions: overlayBodyActions(for: session, now: now)
            )
            refreshActiveBreakShortcut()
            refreshEmergencyEscapeShortcut()
            logger.log("Started \(session.kind.rawValue)")
        case .notificationDue(let kind):
            showPreRestCue(for: kind, now: now)
            logger.log("Pre-rest cue due for \(kind.rawValue)")
        case .naturalRestsCredited(let kinds):
            preRestCueController.dismiss()
            let credited = kinds.map(\.rawValue).sorted().joined(separator: ",")
            logger.log("Natural rests credited kinds=\(credited)")
        default:
            break
        }
    }

    private func refreshFocusMode(now: Date, force: Bool = false) {
        guard force || now.timeIntervalSince(lastFocusCheck) > 5 else { return }
        focusModeActive = focusDetector.isFocusModeActive()
        lastFocusCheck = now
    }

    private func currentContext(
        now: Date,
        idleDuration: TimeInterval? = nil
    ) -> RestContext {
        let appExclusions = settings.appExclusions.map { rule in
            AppExclusionEvaluation(rule: rule, isMatched: RunningApplications.matches(rule: rule))
        }
        return RestContextPolicy.make(
            settings: settings,
            now: now,
            idleDuration: idleDuration ?? SystemIdleTime.seconds(),
            focusModeActive: focusModeActive,
            appExclusions: appExclusions
        )
    }

    private func showPreRestCue(for kind: RestKind, now: Date) {
        preRestCueController.present(
            kind: kind,
            settings: settings,
            dismissAt: engine.state.scheduled?.dueAt,
            now: now
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
            let startActions = StatusMenuStartActionPlanner.actions(
                state: engine.state,
                settings: settings
            )
            for startAction in startActions {
                menu.addItem(statusMenuStartActionItem(startAction))
            }
            if !startActions.isEmpty {
                menu.addItem(.separator())
            }
        }

        if let active = engine.state.activeSession, active.kind == .eyeGate {
            let canEmergencyExit = canEmergencyOverrideEyeGate(active, now: now)
            if StatusMenuPolicy.showsOverlayReturnAction(state: engine.state, canEmergencyExit: canEmergencyExit) {
                menu.addItem(overlayEmergencyFocusMenuItem())
                menu.addItem(.separator())
            }
            if !showsOrdinaryControls {
                appendStrictRestSupportItems(to: menu, now: now)
                setStatusMenu(menu, on: item)
                return
            }
        }

        if let active = engine.state.activeSession, active.kind == .bodyBreak {
            let now = Date()
            let availability = activeRestActionAvailability(for: active, now: now)
            var addedBodyAction = false
            if availability.canPostpone {
                menu.addItem(actionItem(L10n.tr("menu.postponeBodyBreak"), #selector(postponeBodyBreak)))
                addedBodyAction = true
            }
            if availability.canFinish {
                menu.addItem(actionItem(L10n.tr("menu.finishBodyBreak"), #selector(finishActiveBreak)))
                addedBodyAction = true
            }
            if availability.canSkip {
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
            pauseMenu.addItem(actionItem(PauseMenuCopy.durationTitle(L10n.tr("menu.pause30"), duration: 30 * 60, now: now), #selector(pauseFor30Minutes)))
            pauseMenu.addItem(actionItem(PauseMenuCopy.durationTitle(L10n.tr("menu.pause1h"), duration: 60 * 60, now: now), #selector(pauseFor1Hour)))
            pauseMenu.addItem(actionItem(PauseMenuCopy.durationTitle(L10n.tr("menu.pause2h"), duration: 2 * 60 * 60, now: now), #selector(pauseFor2Hours)))
            pauseMenu.addItem(actionItem(PauseMenuCopy.durationTitle(L10n.tr("menu.pause5h"), duration: 5 * 60 * 60, now: now), #selector(pauseFor5Hours)))
            pauseMenu.addItem(actionItem(PauseMenuCopy.untilMorningTitle(settings: settings, now: now), #selector(pauseUntilMorning)))
            pauseMenu.addItem(.separator())
            pauseMenu.addItem(actionItem(
                PauseMenuCopy.indefiniteTitle(confirmsBeforePausing: shouldConfirmIndefinitePause()),
                #selector(pauseIndefinitely)
            ))
            let pauseItem = NSMenuItem(title: L10n.tr("menu.pause"), action: nil, keyEquivalent: "")
            pauseItem.image = menuItemImage("pause.circle", accessibilityDescription: pauseItem.title)
            setMenuItemHelp(L10n.tr("menu.pauseHelp"), on: pauseItem)
            pauseItem.submenu = pauseMenu
            menu.addItem(pauseItem)
        }

        let resetItem = actionItem(L10n.tr("menu.reset"), #selector(resetBreaks))
        if let message = BlockedActionCopy.resetScheduleMessage(state: engine.state, settings: settings) {
            resetItem.isEnabled = false
            setMenuItemHelp(message, on: resetItem)
        } else {
            resetItem.isEnabled = true
            setMenuItemHelp(L10n.tr("menu.resetHelp"), on: resetItem)
        }
        menu.addItem(resetItem)
        menu.addItem(.separator())
        menu.addItem(actionItem(L10n.tr("menu.preferences"), #selector(openPreferences)))
        menu.addItem(supportMenuItem())

        menu.addItem(.separator())
        menu.addItem(quitMenuItem(now: now))
        setStatusMenu(menu, on: item)
    }

    private func appendStrictRestSupportItems(to menu: NSMenu, now: Date) {
        if StrictRestStatusMenuPolicy.showsSafeSupportReportCopy(state: engine.state) {
            menu.addItem(actionItem(L10n.tr("menu.copyDebug"), #selector(copySupportReport)))
            menu.addItem(.separator())
        }
        if StrictRestStatusMenuPolicy.showsDisabledQuitExplanation(state: engine.state, settings: settings) {
            menu.addItem(quitMenuItem(now: now))
        }
    }

    private func quitMenuItem(now: Date = Date()) -> NSMenuItem {
        let quitItem = NSMenuItem(title: L10n.tr("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        if let message = BlockedActionCopy.quitMessage(state: engine.state, settings: settings, now: now) {
            quitItem.isEnabled = false
            setMenuItemHelp(message, on: quitItem)
        } else {
            quitItem.isEnabled = true
            setMenuItemHelp(L10n.tr("menu.quitHelp"), on: quitItem)
        }
        quitItem.image = menuItemImage("power", accessibilityDescription: quitItem.title)
        return quitItem
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

    private func statusMenuStartActionItem(_ startAction: StatusMenuStartAction) -> NSMenuItem {
        switch startAction {
        case .nextScheduled:
            return actionItem(startAction.title, #selector(takeNextScheduledRestNow))
        case .eyeGate:
            return actionItem(startAction.title, #selector(takeEyeGateNow))
        case .bodyBreak:
            return actionItem(startAction.title, #selector(takeBodyBreakNow))
        }
    }

    private func updateMenuBarImage(on item: NSStatusItem, accessibilityDescription: String) {
        let icon = MenuStatusPresenter.menuBarIcon(state: engine.state, settings: settings)
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

    private func menuItemImage(_ symbolName: String, accessibilityDescription: String? = nil) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        image?.accessibilityDescription = accessibilityDescription
        return image
    }

    private func disabledItem(_ title: String, symbolName: String? = nil, toolTip: String? = nil) -> NSMenuItem {
        DisabledStatusMenuItemFactory.make(title: title, toolTip: toolTip, symbolName: symbolName)
    }

    private func settingsFileMenuItem() -> NSMenuItem {
        StatusMenuSettingsLocationMenuItemFactory.make(
            target: self,
            showAction: #selector(showSettingsFile),
            copyAction: #selector(copySettingsPath),
            imageProvider: { symbolName in
                self.menuItemImage(symbolName)
            }
        )
    }

    private func overlayEmergencyFocusMenuItem() -> NSMenuItem {
        StatusMenuOverlayFocusItemFactory.make(
            target: self,
            action: #selector(emergencyOverrideEyeGate),
            imageProvider: { symbolName in
                self.menuItemImage(symbolName)
            }
        )
    }

    private func supportMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L10n.tr("menu.support"), action: nil, keyEquivalent: "")
        item.image = menuItemImage("questionmark.circle", accessibilityDescription: item.title)
        setMenuItemHelp(L10n.tr("menu.supportHelp"), on: item)

        let submenu = NSMenu()
        if !settings.admin.disableAppUpdateFeatures {
            submenu.addItem(actionItem(L10n.tr("menu.checkUpdates"), #selector(checkForUpdatesNow)))
        }
        submenu.addItem(actionItem(L10n.tr("menu.about"), #selector(showAboutPanel)))
        submenu.addItem(.separator())
        submenu.addItem(actionItem(L10n.tr("menu.copyDebug"), #selector(copySupportReport)))
        submenu.addItem(actionItem(L10n.tr("menu.debugPanel"), #selector(openSupportReportPanel)))
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
            item.image = menuItemImage(symbolName, accessibilityDescription: title)
        }
        setMenuItemHelp(StatusMenuActionHelp.help(for: action), on: item)
        return item
    }

    private func setMenuItemHelp(_ help: String?, on item: NSMenuItem) {
        StatusMenuItemPresentation.apply(help: help, to: item)
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

    private func activeRestActionAvailability(for session: RestSession, now: Date) -> OverlayActionAvailability {
        ActiveRestActionPolicy.availability(
            for: session,
            now: now,
            canPostponeBodyBreak: canPostponeBodyBreak(session, now: now),
            canSkipBodyBreak: canSkipBodyBreak(session, now: now)
        )
    }

    private func canEmergencyOverrideEyeGate(_ session: RestSession, now: Date) -> Bool {
        EmergencyOverrideCoordinator.isAvailable(
            session: session,
            policy: settings.eyeGate.emergencyOverride,
            now: now
        )
    }

    private func overlayEmergencyOverrideAction(for session: RestSession, now: Date) -> (() -> EmergencyOverrideDecision)? {
        guard canEmergencyOverrideEyeGate(session, now: now) else { return nil }
        return { [weak self] in
            self?.performEmergencyOverrideEyeGate() ?? .unavailable
        }
    }

    private func overlayBodyActions(for session: RestSession, now: Date) -> BodyOverlayActions? {
        let availability = activeRestActionAvailability(for: session, now: now)

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
        _ = startEyeGateNow(source: "Manual")
    }

    @discardableResult
    private func startEyeGateNow(source: String) -> RestEngineResult {
        let now = Date()
        let context = currentContext(now: now)
        let result = engine.takeNow(
            .eyeGate,
            now: now,
            idleDuration: context.idleDuration,
            preserveAwayCandidate: context.idleDuration > 0
        )
        if case .started(let session) = result {
            preRestCueController.dismiss()
            playRestSound(settings.rule(for: session.kind).startSound)
            overlayController.present(
                session: session,
                settings: settings,
                now: now,
                emergencyOverrideAction: overlayEmergencyOverrideAction(for: session, now: now),
                emergencyOverrideArmed: emergencyOverrideCoordinator.isArmed(for: session, now: now),
                bodyActions: nil
            )
            refreshActiveBreakShortcut()
            refreshEmergencyEscapeShortcut()
            logger.log("\(source) Eye Gate started")
        } else if case .denied(let denial) = result {
            logger.log("\(source) Eye Gate start denied: \(denial)")
        }
        rebuildMenu()
        return result
    }

    @objc private func takeBodyBreakNow() {
        startBodyBreakNow(idea: nil)
    }

    @discardableResult
    private func startBodyBreakNow(idea: RestIdea?, source: String = "Manual") -> RestEngineResult {
        let effectiveIdea = bodyBreakIdeas.ideaForStartAttempt(explicit: idea)
        let now = Date()
        let context = currentContext(now: now)
        let result = engine.takeNow(
            .bodyBreak,
            now: now,
            idleDuration: context.idleDuration,
            preserveAwayCandidate: context.idleDuration > 0
        )
        if case .started(let session) = result {
            preRestCueController.dismiss()
            bodyBreakIdeas.bindStartedIdea(effectiveIdea, to: session)
            playRestSound(settings.rule(for: session.kind).startSound)
            overlayController.present(
                session: session,
                settings: overlaySettings(for: session),
                now: now,
                emergencyOverrideAction: overlayEmergencyOverrideAction(for: session, now: now),
                emergencyOverrideArmed: emergencyOverrideCoordinator.isArmed(for: session, now: now),
                bodyActions: overlayBodyActions(for: session, now: now)
            )
            refreshActiveBreakShortcut()
            refreshEmergencyEscapeShortcut()
            logger.log("\(source) Body Break started")
        } else if case .denied(let denial) = result {
            logger.log("\(source) Body Break start denied: \(denial)")
        }
        rebuildMenu()
        return result
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
        guard let active = engine.state.activeSession else { return }
        let now = Date()
        guard activeRestActionAvailability(for: active, now: now).canPostpone else {
            logger.log("Body Break postpone denied by policy")
            rebuildMenu()
            return
        }
        if case .postponed = engine.postponeActive(now: now) {
            unregisterActiveBreakShortcut()
            unregisterEmergencyEscapeShortcut()
            preRestCueController.dismiss()
            overlayController.dismiss()
            emergencyOverrideCoordinator.clear(sessionID: active.id)
            clearActiveBodyBreakIdea(for: active)
            logger.log("Body Break postponed")
            retryPendingAutomationStarts()
        }
        rebuildMenu()
    }

    @objc private func finishActiveBreak() {
        finishActiveBreakIfAvailable(now: Date())
    }

    private func finishActiveBreakIfAvailable(now: Date) {
        guard let active = engine.state.activeSession else { return }
        guard activeRestActionAvailability(for: active, now: now).canFinish else {
            logger.log("Ignored unavailable finish for \(active.kind.rawValue)")
            return
        }
        let context = currentContext(now: now)
        if case .completed = engine.completeActive(
            now: now,
            reason: .manual,
            idleDuration: context.idleDuration,
            preserveAwayCandidate: context.idleDuration > 0
        ) {
            releaseActiveRestSurface(for: active)
            logger.log("Manually finished \(active.kind.rawValue)")
            playRestSound(settings.rule(for: active.kind).finishSound)
            retryPendingAutomationStarts()
        }
        rebuildMenu()
    }

    @objc private func skipBodyBreak() {
        guard let active = engine.state.activeSession else { return }
        let now = Date()
        guard activeRestActionAvailability(for: active, now: now).canSkip else {
            logger.log("Body Break skip denied by policy")
            rebuildMenu()
            return
        }
        if case .completed = engine.skipActive(now: now) {
            unregisterActiveBreakShortcut()
            unregisterEmergencyEscapeShortcut()
            preRestCueController.dismiss()
            clearActiveBodyBreakIdea(for: active)
            overlayController.dismiss()
            emergencyOverrideCoordinator.clear(sessionID: active.id)
            manualAwaitingSessionID = nil
            logger.log("Body Break skipped")
            retryPendingAutomationStarts()
        } else {
            logger.log("Body Break skip denied")
        }
        rebuildMenu()
    }

    @objc private func endActiveBreakFromShortcut() {
        let now = Date()
        guard let active = engine.state.activeSession else { return }
        let availability = activeRestActionAvailability(for: active, now: now)

        if availability.canFinish {
            finishActiveBreakIfAvailable(now: now)
            return
        }

        guard active.kind == .bodyBreak else { return }

        if availability.canPostpone, case .postponed = engine.postponeActive(now: now) {
            unregisterActiveBreakShortcut()
            unregisterEmergencyEscapeShortcut()
            preRestCueController.dismiss()
            overlayController.dismiss()
            emergencyOverrideCoordinator.clear(sessionID: active.id)
            clearActiveBodyBreakIdea(for: active)
            logger.log("Body Break postponed by end shortcut")
            retryPendingAutomationStarts()
        } else if availability.canSkip, case .completed = engine.skipActive(now: now) {
            unregisterActiveBreakShortcut()
            unregisterEmergencyEscapeShortcut()
            preRestCueController.dismiss()
            overlayController.dismiss()
            emergencyOverrideCoordinator.clear(sessionID: active.id)
            manualAwaitingSessionID = nil
            clearActiveBodyBreakIdea(for: active)
            logger.log("Body Break skipped by end shortcut")
            retryPendingAutomationStarts()
        } else {
            logger.log("Active rest end shortcut ignored because no action is available")
        }
        rebuildMenu()
    }

    @objc private func emergencyOverrideEyeGate() {
        focusEyeGateEmergencyForBlockedAction(actionName: "shortcut")
    }

    private func handleEmergencyAutomation() {
        guard !EmergencyAutomationQueue.persistUntilActiveEyeGate(
            activeRestKind: engine.state.activeSession?.kind
        ) else {
            logger.log("Emergency automation queued until active Eye Gate")
            return
        }
        logger.log("Emergency automation request received during active Eye Gate")
        _ = EmergencyAutomationSignal.consume()
        focusEyeGateEmergencyForBlockedAction(actionName: "automation")
    }

    private func consumeEmergencyAutomationSignalIfNeeded() -> Bool {
        guard EmergencyAutomationSignal.isPending() else { return false }
        guard engine.state.activeSession?.kind == .eyeGate else {
            return false
        }
        _ = EmergencyAutomationSignal.consume()
        logger.log("Emergency automation signal consumed as overlay focus request")
        focusEyeGateEmergencyForBlockedAction(actionName: "automation")
        return true
    }

    @discardableResult
    private func performEmergencyOverrideEyeGate() -> EmergencyOverrideDecision {
        guard let active = engine.state.activeSession, active.kind == .eyeGate else {
            return .unavailable
        }

        let now = Date()
        let decision = emergencyOverrideCoordinator.request(
            session: active,
            policy: settings.eyeGate.emergencyOverride,
            now: now
        )
        handleEmergencyOverrideDecision(decision, session: active, now: now)
        return decision
    }

    private func focusEyeGateEmergencyForBlockedAction(actionName: String) {
        guard let active = engine.state.activeSession, active.kind == .eyeGate else { return }
        let now = Date()

        guard EmergencyOverrideCoordinator.isAvailable(
            session: active,
            policy: settings.eyeGate.emergencyOverride,
            now: now
        ) else {
            logger.log("Blocked \(actionName) request could not focus Emergency Exit")
            rebuildMenu()
            return
        }

        overlayController.update(
            session: active,
            settings: overlaySettings(for: active),
            now: now,
            manualAwaiting: false,
            emergencyOverrideAction: overlayEmergencyOverrideAction(for: active, now: now),
            emergencyOverrideArmed: emergencyOverrideCoordinator.isArmed(for: active, now: now),
            bodyActions: nil
        )
        let focusResult = overlayController.focusEmergencyOverrideAffordanceIfAvailable()
        switch focusResult {
        case .focused:
            logger.log("Blocked \(actionName) request focused Emergency Exit without counting as confirmation")
        case .unavailable:
            logger.log("Blocked \(actionName) request refreshed overlay but Emergency Exit focus was unavailable")
        }
        rebuildMenu()
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
                emergencyOverrideArmed: emergencyOverrideCoordinator.isArmed(for: session, now: now),
                bodyActions: nil
            )
            logger.log("Emergency override armed for \(session.kind.rawValue), awaiting second overlay confirmation")
            rebuildMenu()
        case .complete:
            logger.log("Emergency override confirmed for \(session.kind.rawValue), completing after overlay event dispatch")
            guard engine.state.activeSession?.id == session.id else {
                return
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.completeEmergencyOverrideEyeGate(
                    session: session,
                    now: now,
                    playSound: true
                )
            }
        case .unavailable:
            overlayController.update(
                session: session,
                settings: overlaySettings(for: session),
                now: now,
                manualAwaiting: false,
                emergencyOverrideAction: overlayEmergencyOverrideAction(for: session, now: now),
                emergencyOverrideArmed: false,
                bodyActions: nil
            )
            logger.log("Emergency override unavailable for \(session.kind.rawValue)")
            rebuildMenu()
        }
    }

    private func completeEmergencyOverrideEyeGate(
        session: RestSession,
        now: Date,
        playSound shouldPlaySound: Bool
    ) {
        guard engine.state.activeSession?.id == session.id else {
            logger.log("Emergency override completion skipped because active session changed")
            emergencyOverrideCoordinator.clear(sessionID: session.id)
            rebuildMenu()
            return
        }
        logger.log("Emergency override completing for \(session.kind.rawValue)")
        let result = engine.emergencyOverride(now: now)
        logger.log("Emergency override engine result=\(result)")
        if case .completed(let completedSession, _) = result {
            releaseActiveRestSurface(for: session)
            logger.log("Emergency override completed for \(completedSession.kind.rawValue)")
            if shouldPlaySound {
                playRestSound(settings.rule(for: completedSession.kind).finishSound)
            }
            retryPendingAutomationStarts()
        } else {
            logger.log("Emergency override denied result=\(result)")
        }
        rebuildMenu()
    }

    private func restoreActiveOverlayForReopen() {
        guard let active = engine.state.activeSession else {
            openPreferences()
            logger.log("Application reopen had no active overlay; opened Preferences")
            return
        }

        let now = Date()
        let manualAwaiting = now.timeIntervalSince(active.startedAt) >= active.duration && active.manualFinishEnabled
        overlayController.update(
            session: active,
            settings: overlaySettings(for: active),
            now: now,
            manualAwaiting: manualAwaiting,
            emergencyOverrideAction: overlayEmergencyOverrideAction(for: active, now: now),
            emergencyOverrideArmed: emergencyOverrideCoordinator.isArmed(for: active, now: now),
            bodyActions: overlayBodyActions(for: active, now: now)
        )
        if active.kind == .eyeGate,
           !manualAwaiting,
           EmergencyOverrideCoordinator.isAvailable(
               session: active,
               policy: settings.eyeGate.emergencyOverride,
               now: now
           ) {
            _ = overlayController.focusEmergencyOverrideAffordanceIfAvailable()
        }
        NSApp.activate(ignoringOtherApps: true)
        logger.log("Application reopen restored active \(active.kind.rawValue) overlay")
        rebuildMenu()
    }

    private func releaseActiveRestSurface(for session: RestSession) {
        unregisterActiveBreakShortcut()
        unregisterEmergencyEscapeShortcut()
        preRestCueController.dismiss()
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
              activeRestActionAvailability(for: active, now: Date()).hasAvailableAction else {
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
        let now = Date()
        let context = currentContext(now: now)
        _ = engine.resume(
            now: now,
            idleDuration: context.idleDuration,
            preserveAwayCandidate: context.idleDuration > 0
        )
        logger.log("Breaks resumed")
        retryPendingAutomationStarts()
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
        let now = Date()
        let context = currentContext(now: now)
        let active = engine.state.activeSession
        let result = engine.pause(
            for: duration,
            now: now,
            reason: reason,
            idleDuration: context.idleDuration,
            preserveAwayCandidate: context.idleDuration > 0
        )
        if case .paused = result {
            unregisterActiveBreakShortcut()
            unregisterEmergencyEscapeShortcut()
            preRestCueController.dismiss()
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
        case .focusEyeGateEmergencyInOverlay:
            focusEyeGateEmergencyForBlockedAction(actionName: "pause")
            logger.log("Pause blocked during active Eye Gate; Emergency Exit focused inside overlay")
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
            case .focusEyeGateEmergencyInOverlay:
                focusEyeGateEmergencyForBlockedAction(actionName: "reset")
                logger.log("Reset blocked during active Eye Gate; Emergency Exit focused inside overlay")
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
        preRestCueController.dismiss()
        overlayController.dismiss()
        manualAwaitingSessionID = nil
        bodyBreakIdeas.clearAll()
        pendingAutomationStarts.clearAll()
        cancelAutomationTasks()
        logger.log("Schedule reset")
        rebuildMenu()
    }

    @objc private func openPreferences() {
        presentPreferences(selecting: nil, restoringFrame: nil, showsLanguageRefreshStatus: false)
    }

    private func presentPreferences(
        selecting tab: PreferencesTabTarget?,
        restoringFrame frame: NSRect?,
        showsLanguageRefreshStatus: Bool
    ) {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(settings: settings) { [weak self] nextSettings in
                try self?.applySettings(nextSettings)
            }
        }
        preferencesWindowController?.update(settings: settings)
        if let frame {
            preferencesWindowController?.window?.setFrame(frame, display: false)
        }
        if let tab {
            preferencesWindowController?.selectTab(tab)
        }
        if showsLanguageRefreshStatus {
            preferencesWindowController?.showLanguageRefreshedStatus()
        }
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
            onStart: { [weak self] in
                self?.completeOnboarding(openPreferences: false)
            },
            onOpenPreferences: { [weak self] in
                self?.completeOnboarding(openPreferences: true)
            },
            onLearnMore: { [weak self] in
                self?.showAboutPanel()
            }
        )
        onboardingWindowController?.show()
        NSApp.activate(ignoringOtherApps: true)
        logger.log("Onboarding shown")
    }

    private func completeOnboarding(openPreferences shouldOpenPreferences: Bool) {
        var nextSettings = settings
        nextSettings.operations.hasCompletedOnboarding = true
        nextSettings.operations.showOnboardingOnNextLaunch = false
        do {
            try applySettings(nextSettings)
        } catch {
            logger.log("Onboarding preferences save failed: \(error.localizedDescription)")
            return
        }
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

    @objc private func copySupportReport() {
        let notificationBody = StatusMenuClipboardFeedback.copy(debugInfo(), kind: .supportReport)
        showAppNotification(title: L10n.tr("app.name"), body: notificationBody)
        logger.log("Support report copied")
    }

    @objc private func showSettingsFile() {
        reveal(url: settingsStore.fileURL)
        logger.log("Settings file revealed")
    }

    @objc private func copySettingsPath() {
        let notificationBody = StatusMenuClipboardFeedback.copy(settingsStore.fileURL.path, kind: .settingsPath)
        showAppNotification(title: L10n.tr("app.name"), body: notificationBody)
        logger.log("Settings path copied")
    }

    @objc private func openSupportReportPanel() {
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
        logger.log("Support report window opened")
    }

    @objc private func showAboutPanel() {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController(
                version: AppVersion.current,
                projectURL: URL(string: "https://github.com/metrovoc/shouldrest")!,
                onOpenDebug: { [weak self] in
                    self?.openSupportReportPanel()
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

    private func applySettings(_ nextSettings: RestSettings) throws {
        let normalizedSettings = nextSettings.normalizedForCurrentDesign()
        let shouldRefreshVisiblePreferences = PreferencesLanguageRefreshPolicy.shouldRefreshPreferences(
            previousSettings: settings,
            nextSettings: normalizedSettings,
            isPreferencesWindowVisible: preferencesWindowController?.window?.isVisible == true
        )
        let preferencesFrame = shouldRefreshVisiblePreferences ? preferencesWindowController?.window?.frame : nil
        try settingsStore.save(normalizedSettings)
        settings = normalizedSettings
        engine.updateSettings(normalizedSettings)
        preRestCueController.dismiss()
        applyLanguageSetting()
        applyAppearanceSetting()
        applyOpenAtLoginSetting()
        applyMenuBarVisibility()
        configureGlobalShortcuts()
        refreshActiveBreakShortcut()
        refreshEmergencyEscapeShortcut()
        scheduleAutomaticUpdateCheck()
        logger.log("Preferences saved")
        rebuildMenu()
        if shouldRefreshVisiblePreferences {
            refreshPreferencesWindowAfterLanguageChange(restoringFrame: preferencesFrame)
        }
    }

    private func refreshPreferencesWindowAfterLanguageChange(restoringFrame frame: NSRect?) {
        preferencesWindowController?.window?.orderOut(nil)
        preferencesWindowController = nil
        presentPreferences(
            selecting: .appearance,
            restoringFrame: frame,
            showsLanguageRefreshStatus: true
        )
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
            switch automationDuration(from: userInfo) {
            case .missing:
                pause(for: nil, reason: .user)
            case .valid(let duration):
                pause(for: duration, reason: .user)
            case .invalid:
                logger.log("Ignored pause automation with invalid duration")
            }
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
        case .supportReport:
            copySupportReport()
        case .supportReportPanel:
            openSupportReportPanel()
        case .about:
            showAboutPanel()
        }
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let request = CommandLineAutomation.request(fromURLString: urlString) else {
            logger.log("Ignored invalid automation URL event")
            return
        }
        if request.command == .emergency {
            try? EmergencyAutomationSignal.write()
        }
        performAutomation(request.command, userInfo: request.userInfo)
        logger.log("Handled automation URL \(urlString)")
    }

    private func automationDuration(from userInfo: [AnyHashable: Any]?) -> AutomationDurationPolicy.UserInfoDuration {
        AutomationDurationPolicy.duration(fromUserInfo: userInfo)
    }

    private func handleEyeGateAutomation(_ userInfo: [AnyHashable: Any]?) {
        let noSkip = automationNoSkip(from: userInfo)
        let wait: TimeInterval?
        switch automationDuration(from: userInfo) {
        case .missing:
            wait = nil
        case .valid(let duration):
            wait = duration
        case .invalid:
            logger.log("Ignored Eye Gate automation with invalid duration")
            return
        }
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
        let wait: TimeInterval?
        switch automationDuration(from: userInfo) {
        case .missing:
            wait = nil
        case .valid(let duration):
            wait = duration
        case .invalid:
            logger.log("Ignored Body Break automation with invalid duration")
            return
        }

        if let wait, wait > 0 {
            scheduleBodyBreakAutomation(after: wait, idea: idea)
        } else if noSkip {
            if bodyBreakIdeas.storePendingIfPresent(idea) {
                logger.log("Stored one-shot Body Break content")
            } else {
                logger.log("Kept current Body Break schedule for noskip automation without content")
            }
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
        guard let nanoseconds = AutomationDurationPolicy.sleepNanoseconds(for: delay) else {
            logger.log("Ignored Eye Gate automation with invalid delay \(delay)")
            return
        }
        let id = UUID()
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
        enqueuePendingAutomationStart(AutomationStartRequest(kind: .eyeGate))
    }

    private func scheduleBodyBreakAutomation(after delay: TimeInterval, idea: RestIdea?) {
        guard let nanoseconds = AutomationDurationPolicy.sleepNanoseconds(for: delay) else {
            logger.log("Ignored Body Break automation with invalid delay \(delay)")
            return
        }
        let id = UUID()
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
        enqueuePendingAutomationStart(AutomationStartRequest(kind: .bodyBreak, bodyBreakIdea: idea))
    }

    private func enqueuePendingAutomationStart(_ request: AutomationStartRequest) {
        pendingAutomationStarts.enqueue(request)
        logger.log("Queued delayed \(request.kind.rawValue) automation start")
        retryPendingAutomationStarts()
    }

    private func retryPendingAutomationStarts() {
        while engine.state.activeSession == nil,
              engine.state.pause == nil,
              let request = pendingAutomationStarts.next {
            let result: RestEngineResult
            switch request.kind {
            case .eyeGate:
                result = startEyeGateNow(source: "Delayed automation")
            case .bodyBreak:
                result = startBodyBreakNow(idea: request.bodyBreakIdea, source: "Delayed automation")
            }

            switch AutomationStartRetryPolicy.decision(for: result) {
            case .satisfied:
                pendingAutomationStarts.remove(request)
                return
            case .keepPending:
                logger.log("Delayed \(request.kind.rawValue) automation remains pending: \(result)")
                return
            case .discard:
                pendingAutomationStarts.remove(request)
                logger.log("Discarded delayed \(request.kind.rawValue) automation: \(result)")
            }
        }
    }

    private func cancelAutomationTasks() {
        for task in automationTasks.values {
            task.cancel()
        }
        automationTasks.removeAll()
    }

    private func bindPendingBodyBreakIdea(to session: RestSession) {
        bodyBreakIdeas.bindPending(to: session)
    }

    private func clearActiveBodyBreakIdea(for session: RestSession) {
        bodyBreakIdeas.clearActive(for: session)
    }

    private func overlaySettings(for session: RestSession) -> RestSettings {
        guard session.kind == .bodyBreak,
              let idea = bodyBreakIdeas.activeIdea(for: session) else {
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
        let now = Date()
        preRestCueController.dismiss()
        let alreadyPausedForSuspendOrLock = SystemSuspendPausePolicy.hasSuspendOrLockPause(state: engine.state)
        if !alreadyPausedForSuspendOrLock {
            suspendedAt = now
            suspendedIdleBeforePause = SystemIdleTime.seconds()
            pausedForSuspendOrLock = false
        }
        if settings.operations.resolvedPauseForSuspendOrLock || alreadyPausedForSuspendOrLock {
            if alreadyPausedForSuspendOrLock {
                pausedForSuspendOrLock = true
            } else if SystemSuspendPausePolicy.shouldPauseScheduler(state: engine.state),
               case .paused = engine.pause(
                    for: nil,
                    now: now,
                    reason: .suspendOrLock,
                    idleDuration: suspendedIdleBeforePause,
                    preserveAwayCandidate: suspendedIdleBeforePause > 0
               ) {
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
        let suspendedDuration = suspendedAt.map { now.timeIntervalSince($0) } ?? 0
        let preSuspendIdleDuration = suspendedIdleBeforePause
        suspendedAt = nil
        suspendedIdleBeforePause = 0
        let didPauseScheduler = pausedForSuspendOrLock ||
            SystemSuspendPausePolicy.hasSuspendOrLockPause(state: engine.state)
        refreshFocusMode(now: now, force: true)
        let restIdleDuration = SystemResumeIdlePolicy.effectiveIdleDuration(
            preSuspendIdleDuration: preSuspendIdleDuration,
            suspendedIdleDuration: suspendedDuration,
            didPauseScheduler: didPauseScheduler
        )
        if didPauseScheduler {
            _ = engine.resume(
                now: now,
                idleDuration: restIdleDuration,
                preserveAwayCandidate: restIdleDuration > 0
            )
            pausedForSuspendOrLock = false
        }
        let context = currentContext(now: now, idleDuration: restIdleDuration)
        if engine.state.activeSession != nil {
            handleActiveRestLifecycle(
                now: now,
                context: context
            )
            logger.log(
                "System resume detected suspendedDuration=\(suspendedDuration) " +
                    "preSuspendIdleDuration=\(preSuspendIdleDuration) restIdleDuration=\(restIdleDuration)"
            )
            return
        }
        let result = engine.evaluate(now: now, context: context)
        handleEngineResult(result, now: now)
        retryPendingAutomationStarts()
        refreshActiveBreakShortcut()
        refreshEmergencyEscapeShortcut()
        logger.log(
            "System resume detected suspendedDuration=\(suspendedDuration) " +
                "preSuspendIdleDuration=\(preSuspendIdleDuration) restIdleDuration=\(restIdleDuration)"
        )
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
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            guard let error else { return }
            Task { @MainActor in
                self?.logger.log("Notification delivery failed: \(error.localizedDescription)")
            }
        }
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
            "eyeDebt=\(engine.state.eyeDebt)",
            "bodyDebt=\(engine.state.bodyDebt)",
            "lastEvaluatedAt=\(String(describing: engine.state.lastEvaluatedAt))",
            "lastIdleDuration=\(engine.state.lastIdleDuration)",
            "awayCandidate=\(String(describing: engine.state.awayCandidate))",
            "bodySuppressedUntil=\(String(describing: engine.state.bodySuppressedUntil))",
            "postponesInCurrentCycle=\(engine.state.postponesInCurrentCycle)",
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
        DebugSafetySummaryPresenter.summary(
            state: engine.state,
            settings: settings,
            now: Date()
        )
    }
}

enum EmergencyOverlayFocusResult: Equatable {
    case unavailable
    case focused
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

    var hasAvailableAction: Bool {
        canPostpone || canFinish || canSkip
    }
}

enum ActiveRestActionPolicy {
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
                canFinish: session.manualFinishEnabled && canFinish,
                canSkip: !canFinish && canSkipBodyBreak
            )
        }
    }
}

enum ActiveRestLifecycleDecision: Equatable {
    case naturalCompletion
    case elapsedCompletion
    case present(manualAwaiting: Bool)
}

enum ActiveRestLifecyclePolicy {
    static func decision(
        for session: RestSession,
        settings: RestSettings,
        now: Date,
        context: RestContext
    ) -> ActiveRestLifecycleDecision {
        if settings.naturalBreaks.isEnabled,
           context.idleDuration >= max(session.duration, settings.naturalBreaks.inactivityResetTime) {
            return .naturalCompletion
        }

        let elapsed = now.timeIntervalSince(session.startedAt)
        guard elapsed >= session.duration else {
            return .present(manualAwaiting: false)
        }

        if session.manualFinishEnabled {
            return .present(manualAwaiting: true)
        }
        return .elapsedCompletion
    }
}

enum ActiveRestCountdown {
    static func remainingSeconds(duration: TimeInterval, elapsed: TimeInterval) -> Int {
        max(0, Int(ceil(duration - elapsed)))
    }

    static func remainingSeconds(for session: RestSession, now: Date) -> Int {
        remainingSeconds(duration: session.duration, elapsed: now.timeIntervalSince(session.startedAt))
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

private enum EmergencyOverrideKeyHandling {
    case trigger
    case consumeRepeat
    case passThrough
}

private func emergencyOverrideKeyHandling(for event: NSEvent) -> EmergencyOverrideKeyHandling {
    guard isEmergencyOverrideKey(event) else { return .passThrough }
    return event.isARepeat ? .consumeRepeat : .trigger
}

struct PreRestCueStyle {
    let accentColor: NSColor
    let edgeThickness: CGFloat
    let glowRadius: CGFloat
    let baseOpacity: Float
    let peakOpacity: Float
    let reducedMotionOpacity: Float
    let pulseDuration: CFTimeInterval

    static func make(kind: RestKind, settings: RestSettings) -> PreRestCueStyle {
        switch kind {
        case .eyeGate:
            return PreRestCueStyle(
                accentColor: NSColor(deviceRed: 0.47, green: 0.78, blue: 1, alpha: 1),
                edgeThickness: 56,
                glowRadius: 72,
                baseOpacity: 0.12,
                peakOpacity: 0.38,
                reducedMotionOpacity: 0.20,
                pulseDuration: 1.55
            )
        case .bodyBreak:
            return PreRestCueStyle(
                accentColor: NSColor(deviceRed: 0.38, green: 0.92, blue: 0.68, alpha: 1),
                edgeThickness: 56,
                glowRadius: 72,
                baseOpacity: 0.12,
                peakOpacity: 0.38,
                reducedMotionOpacity: 0.19,
                pulseDuration: 1.55
            )
        }
    }
}

@MainActor
final class PreRestCueController {
    private var windows: [CGDirectDisplayID: PreRestCueWindow] = [:]
    private var kind: RestKind?
    private var settings: RestSettings?
    private var dismissTimer: Timer?

    var windowsForTesting: [PreRestCueWindow] {
        Array(windows.values)
    }

    var isVisible: Bool {
        !windows.isEmpty
    }

    func present(kind: RestKind, settings: RestSettings, dismissAt: Date?, now: Date = Date()) {
        let effectiveSettings = settings.normalizedForCurrentDesign()
        self.kind = kind
        self.settings = effectiveSettings
        reconcileWindows(for: targetScreens(kind: kind, settings: effectiveSettings), kind: kind, settings: effectiveSettings)
        scheduleDismiss(at: dismissAt, now: now)
    }

    func reconcile() {
        guard let kind, let settings else { return }
        reconcileWindows(for: targetScreens(kind: kind, settings: settings), kind: kind, settings: settings)
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        for window in windows.values {
            window.close()
        }
        windows.removeAll()
        kind = nil
        settings = nil
    }

    private func scheduleDismiss(at dismissAt: Date?, now: Date) {
        dismissTimer?.invalidate()
        dismissTimer = nil

        guard let dismissAt else { return }
        let interval = dismissAt.timeIntervalSince(now)
        guard interval > 0 else {
            dismiss()
            return
        }

        dismissTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss()
            }
        }
    }

    private func reconcileWindows(for screens: [NSScreen], kind: RestKind, settings: RestSettings) {
        let targetIDs = Set(screens.map(\.displayID))
        for (id, window) in windows where !targetIDs.contains(id) {
            window.close()
        }
        windows = windows.filter { targetIDs.contains($0.key) }

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        for screen in screens {
            let id = screen.displayID
            if windows[id] == nil {
                windows[id] = PreRestCueWindow(
                    screen: screen,
                    kind: kind,
                    settings: settings,
                    reduceMotion: reduceMotion
                )
            }
            windows[id]?.setFrame(screen.frame, display: true)
            windows[id]?.configure(kind: kind, settings: settings, reduceMotion: reduceMotion)
            windows[id]?.orderFrontRegardless()
        }
    }

    private func targetScreens(kind: RestKind, settings: RestSettings) -> [NSScreen] {
        let allScreens = NSScreen.screens
        guard !allScreens.isEmpty else { return [] }

        let enforcement = settings.rule(for: kind).enforcement
        if kind == .eyeGate || enforcement.coversAllDisplays {
            return allScreens
        }

        let contentScreen = screen(for: enforcement.contentDisplay, enforcement: enforcement)
        let fallbackSelection = contentScreen == nil ? DisplaySelection.primary : enforcement.contentDisplay
        let selection = enforcement.coveredDisplay ?? fallbackSelection
        return [screen(for: selection, enforcement: enforcement) ?? allScreens.first!]
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
}

@MainActor
final class PreRestCueWindow: NSWindow {
    let cueView: PreRestCueView

    init(screen: NSScreen, kind: RestKind, settings: RestSettings, reduceMotion: Bool) {
        self.cueView = PreRestCueView(frame: NSRect(origin: .zero, size: screen.frame.size))
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        contentView = cueView
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        canHide = false
        configure(kind: kind, settings: settings, reduceMotion: reduceMotion)
        syncCueViewFrame(to: screen.frame.size)
    }

    func configure(kind: RestKind, settings: RestSettings, reduceMotion: Bool) {
        cueView.configure(style: PreRestCueStyle.make(kind: kind, settings: settings), reduceMotion: reduceMotion)
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        syncCueViewFrame(to: frameRect.size)
    }

    private func syncCueViewFrame(to size: NSSize) {
        cueView.frame = NSRect(origin: .zero, size: size)
    }
}

@MainActor
final class PreRestCueView: NSView {
    private let topLayer = CAGradientLayer()
    private let bottomLayer = CAGradientLayer()
    private let leftLayer = CAGradientLayer()
    private let rightLayer = CAGradientLayer()
    private var style = PreRestCueStyle.make(kind: .eyeGate, settings: .defaults)
    private var reduceMotion = false

    var edgeLayerCountForTesting: Int {
        edgeLayers.count
    }

    private var edgeLayers: [CAGradientLayer] {
        [topLayer, bottomLayer, leftLayer, rightLayer]
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false
        setAccessibilityElement(false)
        edgeLayers.forEach { layer?.addSublayer($0) }
        configure(style: style, reduceMotion: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(style: PreRestCueStyle, reduceMotion: Bool) {
        self.style = style
        self.reduceMotion = reduceMotion
        let solidColor = style.accentColor.withAlphaComponent(1).cgColor
        let middleColor = style.accentColor.withAlphaComponent(0.38).cgColor
        let transparentColor = style.accentColor.withAlphaComponent(0).cgColor

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for edgeLayer in edgeLayers {
            edgeLayer.colors = [solidColor, middleColor, transparentColor]
            edgeLayer.locations = [0, 0.34, 1]
            edgeLayer.shadowColor = solidColor
            edgeLayer.shadowOpacity = 0.78
            edgeLayer.shadowRadius = style.glowRadius
            edgeLayer.shadowOffset = .zero
            edgeLayer.removeAnimation(forKey: Self.pulseAnimationKey)
            edgeLayer.opacity = reduceMotion ? style.reducedMotionOpacity : style.baseOpacity
        }
        topLayer.startPoint = CGPoint(x: 0.5, y: 1)
        topLayer.endPoint = CGPoint(x: 0.5, y: 0)
        bottomLayer.startPoint = CGPoint(x: 0.5, y: 0)
        bottomLayer.endPoint = CGPoint(x: 0.5, y: 1)
        leftLayer.startPoint = CGPoint(x: 0, y: 0.5)
        leftLayer.endPoint = CGPoint(x: 1, y: 0.5)
        rightLayer.startPoint = CGPoint(x: 1, y: 0.5)
        rightLayer.endPoint = CGPoint(x: 0, y: 0.5)
        layoutEdgeLayers()
        CATransaction.commit()

        guard !reduceMotion else { return }
        for (index, edgeLayer) in edgeLayers.enumerated() {
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = style.baseOpacity
            animation.toValue = style.peakOpacity
            animation.duration = style.pulseDuration
            animation.beginTime = CACurrentMediaTime() + Double(index) * 0.08
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.isRemovedOnCompletion = false
            edgeLayer.add(animation, forKey: Self.pulseAnimationKey)
        }
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layoutEdgeLayers()
        CATransaction.commit()
    }

    private func layoutEdgeLayers() {
        let thickness = style.edgeThickness
        topLayer.frame = CGRect(x: 0, y: bounds.height - thickness, width: bounds.width, height: thickness)
        bottomLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: thickness)
        leftLayer.frame = CGRect(x: 0, y: 0, width: thickness, height: bounds.height)
        rightLayer.frame = CGRect(x: bounds.width - thickness, y: 0, width: thickness, height: bounds.height)
    }

    private static let pulseAnimationKey = "shouldrest.preRestCuePulse"
}

@MainActor
final class OverlayController {
    private var windows: [CGDirectDisplayID: OverlayWindow] = [:]
    private var session: RestSession?
    private var settings: RestSettings?
    private var emergencyOverrideAction: (() -> EmergencyOverrideDecision)?
    private var bodyActions: BodyOverlayActions?
    private var manualAwaiting = false
    private var emergencyOverrideArmed = false

    var windowsForTesting: [OverlayWindow] {
        Array(windows.values)
    }

    func present(
        session: RestSession,
        settings: RestSettings,
        now: Date,
        emergencyOverrideAction: (() -> EmergencyOverrideDecision)? = nil,
        emergencyOverrideArmed: Bool = false,
        bodyActions: BodyOverlayActions? = nil
    ) {
        let effectiveSettings = settings.normalizedForCurrentDesign()
        self.session = session
        self.settings = effectiveSettings
        self.emergencyOverrideAction = emergencyOverrideAction
        self.bodyActions = bodyActions
        NSApp.activate(ignoringOtherApps: true)
        update(
            session: session,
            settings: effectiveSettings,
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
        emergencyOverrideAction: (() -> EmergencyOverrideDecision)? = nil,
        emergencyOverrideArmed: Bool = false,
        bodyActions: BodyOverlayActions? = nil
    ) {
        let effectiveSettings = settings.normalizedForCurrentDesign()
        self.session = session
        self.settings = effectiveSettings
        self.emergencyOverrideAction = emergencyOverrideAction
        self.bodyActions = bodyActions
        self.manualAwaiting = manualAwaiting
        self.emergencyOverrideArmed = emergencyOverrideArmed
        let contentScreen = selectedContentScreen(for: session, settings: effectiveSettings)
        let screens = coveredScreens(for: session, settings: effectiveSettings, contentScreen: contentScreen)
        reconcileWindows(for: screens, session: session, settings: effectiveSettings)
        let remaining = ActiveRestCountdown.remainingSeconds(for: session, now: now)
        let canUseEmergencyOverride: Bool
        if emergencyOverrideAction == nil {
            canUseEmergencyOverride = false
        } else {
            canUseEmergencyOverride = emergencyOverrideIsAvailable(for: session, settings: effectiveSettings, now: now)
        }

        for screen in screens {
            let id = screen.displayID
            let isContentScreen = shouldShowContent(
                on: screen,
                contentScreen: contentScreen,
                session: session,
                settings: effectiveSettings
            )
            windows[id]?.overlayView.onEmergencyOverrideRequested = emergencyOverrideAction
            windows[id]?.overlayView.bodyActions = bodyActions
            windows[id]?.setFrame(screen.frame, display: true)
            windows[id]?.configureBackdrop(session: session, settings: effectiveSettings)
            windows[id]?.overlayView.configure(
                session: session,
                remainingSeconds: remaining,
                settings: effectiveSettings,
                showsContent: isContentScreen,
                manualAwaiting: manualAwaiting,
                isEmergencyOverrideAvailable: canUseEmergencyOverride,
                emergencyOverrideArmed: emergencyOverrideArmed,
                bodyActions: bodyActions
            )
            let level: NSWindow.Level
            if manualAwaiting && session.kind == .bodyBreak {
                level = .modalPanel
            } else {
                level = windowLevel(for: session, settings: effectiveSettings)
            }
            windows[id]?.level = level
            windows[id]?.makeKeyAndOrderFront(nil)
            windows[id]?.orderFrontRegardless()
            windows[id]?.overlayView.ensureOverlayKeyboardFocusIfNeeded()
        }
    }

    func focusEmergencyOverrideAffordanceIfAvailable() -> EmergencyOverlayFocusResult {
        for window in windows.values {
            switch window.overlayView.focusEmergencyOverrideAffordanceIfAvailable() {
            case .focused:
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                _ = window.overlayView.focusEmergencyOverrideAffordanceIfAvailable()
                return .focused
            case .unavailable:
                break
            }
        }
        return .unavailable
    }

    func reconcile() {
        guard let session, let settings else { return }

        update(
            session: session,
            settings: settings,
            now: Date(),
            manualAwaiting: manualAwaiting,
            emergencyOverrideAction: emergencyOverrideAction,
            emergencyOverrideArmed: emergencyOverrideArmed,
            bodyActions: bodyActions
        )
    }

    private func reconcileWindows(for screens: [NSScreen], session: RestSession, settings: RestSettings) {
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
            windows[id]?.overlayView.ensureOverlayKeyboardFocusIfNeeded()
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
        manualAwaiting = false
        emergencyOverrideArmed = false
    }

    private func emergencyOverrideIsAvailable(for session: RestSession, settings: RestSettings, now: Date) -> Bool {
        EmergencyOverrideCoordinator.isAvailable(
            session: session,
            policy: settings.eyeGate.emergencyOverride,
            now: now
        )
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
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        canHide = false
        configureBackdrop(session: session, settings: settings)
        syncOverlayViewFrame(to: screen.frame.size)
    }

    func configureBackdrop(session: RestSession, settings: RestSettings) {
        let rule = settings.rule(for: session.kind)
        let fallbackColor = RestSettings.defaults.rule(for: session.kind).colorHex
        let color = NSColor(hex: rule.colorHex, fallback: fallbackColor)
            .withAlphaComponent(rule.enforcement.opacity)
        backgroundColor = color
        isOpaque = rule.enforcement.isOpaque && rule.enforcement.opacity >= 1
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func keyDown(with event: NSEvent) {
        switch emergencyOverrideKeyHandling(for: event) {
        case .trigger:
            overlayView.performEmergencyOverrideKeyCommand(event: event)
        case .consumeRepeat:
            break
        case .passThrough:
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
    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    func applyBodyActionTileStyle(isPendingButton: Bool, isActionLocked: Bool) {
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.borderWidth = 1
        layer?.masksToBounds = true

        let backgroundAlpha: CGFloat
        let borderAlpha: CGFloat
        if isPendingButton {
            backgroundAlpha = 0.18
            borderAlpha = 0.34
        } else if isActionLocked {
            backgroundAlpha = 0.08
            borderAlpha = 0.16
        } else {
            backgroundAlpha = 0.14
            borderAlpha = 0.28
        }

        layer?.backgroundColor = NSColor.white.withAlphaComponent(backgroundAlpha).cgColor
        layer?.borderColor = NSColor.white.withAlphaComponent(borderAlpha).cgColor
    }

    func clearBodyActionTileStyle() {
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.borderColor = NSColor.clear.cgColor
        layer?.borderWidth = 0
    }
}

final class OverlayClickPanel: NSView {
    var onClick: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard let onClick else {
            super.mouseDown(with: event)
            return
        }
        onClick()
    }
}

private struct EmergencyOverlayVisualStyle {
    var buttonAlpha: CGFloat
    var tintAlpha: CGFloat
    var titleAlpha: CGFloat
    var panelBackgroundAlpha: CGFloat
    var panelBorderAlpha: CGFloat

    static func style(isArmed: Bool) -> EmergencyOverlayVisualStyle {
        if isArmed {
            return EmergencyOverlayVisualStyle(
                buttonAlpha: 0.48,
                tintAlpha: 0.64,
                titleAlpha: 0.64,
                panelBackgroundAlpha: 0.022,
                panelBorderAlpha: 0.082
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

private enum BodyOverlayActionKind {
    case postpone
    case skip
    case finish

    var title: String {
        switch self {
        case .postpone:
            return L10n.tr("overlay.bodyPostpone")
        case .skip:
            return L10n.tr("overlay.bodySkip")
        case .finish:
            return L10n.tr("overlay.bodyFinish")
        }
    }

    var help: String {
        switch self {
        case .postpone:
            return L10n.tr("overlay.bodyPostponeHelp")
        case .skip:
            return L10n.tr("overlay.bodySkipHelp")
        case .finish:
            return L10n.tr("overlay.bodyFinishHelp")
        }
    }

    var symbolName: String {
        switch self {
        case .postpone:
            return "clock.arrow.circlepath"
        case .skip:
            return "forward.end"
        case .finish:
            return "checkmark.circle"
        }
    }

    var pendingTitle: String {
        switch self {
        case .postpone:
            return L10n.tr("overlay.bodyPostponePending")
        case .skip:
            return L10n.tr("overlay.bodySkipPending")
        case .finish:
            return L10n.tr("overlay.bodyFinishPending")
        }
    }

    var pendingHelp: String {
        switch self {
        case .postpone:
            return L10n.tr("overlay.bodyPostponePendingHelp")
        case .skip:
            return L10n.tr("overlay.bodySkipPendingHelp")
        case .finish:
            return L10n.tr("overlay.bodyFinishPendingHelp")
        }
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
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let countdownLabel = NSTextField(labelWithString: "")
    private let imageView = NSImageView()
    private let emergencyPanel = OverlayClickPanel()
    private let emergencyButton = OverlayActionButton()
    private let bodyActionPanel = OverlayClickPanel()
    private let bodyActionStack = NSStackView()
    private let bodyPostponeButton = OverlayActionButton()
    private let bodySkipButton = OverlayActionButton()
    private let bodyFinishButton = OverlayActionButton()
    private var detailCacheKey: String?
    private var isEmergencyOverrideAvailable = false
    private var emergencyOverrideArmed = false
    private var emergencyOverrideRequestInFlight = false
    private var emergencySessionID: UUID?
    private var emergencyPanelWidthConstraint: NSLayoutConstraint?
    private var emergencyPanelHeightConstraint: NSLayoutConstraint?
    private var bodyActionRequestPending = false
    private var pendingBodyAction: BodyOverlayActionKind?
    var emergencyFocusAttemptForTesting: (() -> EmergencyOverlayFocusResult)?
    var onEmergencyOverrideRequested: (() -> EmergencyOverrideDecision)?
    var bodyActions: BodyOverlayActions? {
        didSet {
            bodyActionRequestPending = false
            pendingBodyAction = nil
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
            label.lineBreakMode = .byWordWrapping
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
        emergencyPanel.onClick = { [weak self] in
            self?.requestEmergencyOverride()
        }
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
            kind: .postpone,
            action: #selector(bodyPostponePressed)
        )
        configureBodyActionButton(
            bodySkipButton,
            identifier: "overlay.bodySkip.button",
            kind: .skip,
            action: #selector(bodySkipPressed)
        )
        configureBodyActionButton(
            bodyFinishButton,
            identifier: "overlay.bodyFinish.button",
            kind: .finish,
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
        bodyActionPanel.onClick = { [weak self] in
            self?.requestSingleVisibleBodyActionFromPanel()
        }
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
        updateReadableLabelWrapping(maxWidth: readableWidth)
        super.layout()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        switch emergencyOverrideKeyHandling(for: event) {
        case .trigger:
            performEmergencyOverrideKeyCommand(event: event)
        case .consumeRepeat:
            break
        case .passThrough:
            super.keyDown(with: event)
        }
    }

    func configure(
        session: RestSession,
        remainingSeconds: Int,
        settings: RestSettings,
        showsContent: Bool,
        manualAwaiting: Bool,
        isEmergencyOverrideAvailable: Bool,
        emergencyOverrideArmed: Bool = false,
        bodyActions: BodyOverlayActions? = nil
    ) {
        self.bodyActions = bodyActions
        let canUseEmergencyOverride = isEmergencyOverrideAvailable && !(manualAwaiting && session.kind == .eyeGate)
        configureEmergencyButton(
            sessionID: session.id,
            isAvailable: canUseEmergencyOverride,
            isArmed: emergencyOverrideArmed
        )

        titleLabel.isHidden = !showsContent
        detailLabel.isHidden = !showsContent
        countdownLabel.isHidden = !showsContent
        imageView.isHidden = true
        imageView.image = nil

        guard showsContent else {
            updateOverlayTextAccessibility()
            return
        }

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
            updateOverlayTextAccessibility()
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
            let copy = bodyBreakCopy(from: idea)
            titleLabel.stringValue = copy.title
            setDetailText(copy.body, allowsRichText: true)
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
        updateOverlayTextAccessibility()
    }

    @objc private func emergencyOverridePressed() {
        requestEmergencyOverride()
    }

    private func requestEmergencyOverride() {
        guard let request = onEmergencyOverrideRequested else {
            return
        }
        guard !emergencyOverrideRequestInFlight else {
            return
        }
        guard isEmergencyOverrideAvailable,
              !emergencyButton.isHidden else {
            return
        }
        _ = emergencyFocusAttemptForTesting?() ?? focusEmergencyOverrideAffordanceIfAvailable()

        emergencyOverrideRequestInFlight = true
        let decision = request()
        emergencyOverrideRequestInFlight = false
        applyEmergencyOverrideDecision(decision)
    }

    private func applyEmergencyOverrideDecision(_ decision: EmergencyOverrideDecision) {
        switch decision {
        case .armed:
            armEmergencyOverrideLocallyIfNeeded()
        case .complete:
            clearEmergencyOverrideLocally()
        case .unavailable:
            clearEmergencyOverrideLocally()
        }
    }

    @objc private func bodyPostponePressed() {
        requestBodyActionIfAvailable(.postpone, isAvailable: bodyActions?.canPostpone == true, action: bodyActions?.postpone)
    }

    @objc private func bodySkipPressed() {
        requestBodyActionIfAvailable(.skip, isAvailable: bodyActions?.canSkip == true, action: bodyActions?.skip)
    }

    @objc private func bodyFinishPressed() {
        requestBodyActionIfAvailable(.finish, isAvailable: bodyActions?.canFinish == true, action: bodyActions?.finish)
    }

    private func requestBodyActionIfAvailable(_ kind: BodyOverlayActionKind, isAvailable: Bool, action: (() -> Void)?) {
        guard isAvailable,
              let action,
              !bodyActionRequestPending else {
            return
        }
        bodyActionRequestPending = true
        pendingBodyAction = kind
        updateBodyActionButtons()
        DispatchQueue.main.async { [weak self] in
            action()
            self?.clearCompletedBodyActionRequest(kind)
        }
    }

    private func requestSingleVisibleBodyActionFromPanel() {
        guard let action = singleVisibleBodyActionKind() else {
            return
        }

        switch action {
        case .postpone:
            bodyPostponePressed()
        case .skip:
            bodySkipPressed()
        case .finish:
            bodyFinishPressed()
        }
    }

    private func clearCompletedBodyActionRequest(_ kind: BodyOverlayActionKind) {
        guard bodyActionRequestPending,
              pendingBodyAction == kind else {
            return
        }
        bodyActionRequestPending = false
        pendingBodyAction = nil
        updateBodyActionButtons()
    }

    func performEmergencyOverrideKeyCommand(event: NSEvent? = nil) {
        if let event {
            switch emergencyOverrideKeyHandling(for: event) {
            case .trigger:
                break
            case .consumeRepeat, .passThrough:
                return
            }
        }
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

    func focusEmergencyOverrideAffordanceIfAvailable() -> EmergencyOverlayFocusResult {
        guard !emergencyButton.isHidden,
              isEmergencyOverrideAvailable else {
            return .unavailable
        }

        if let window,
           !window.makeFirstResponder(emergencyButton) {
            return .unavailable
        }
        return .focused
    }

    func ensureOverlayKeyboardFocusIfNeeded() {
        guard let window else { return }
        if let focusedView = window.firstResponder as? NSView,
           (focusedView === self || focusedView.isDescendant(of: self)),
           !focusedView.isHidden {
            return
        }
        _ = window.makeFirstResponder(self)
    }

    private func armEmergencyOverrideLocallyIfNeeded() {
        guard isEmergencyOverrideAvailable else {
            return
        }
        emergencyOverrideArmed = true
        updateEmergencyAffordanceUI()
    }

    private func clearEmergencyOverrideLocally() {
        isEmergencyOverrideAvailable = false
        emergencyOverrideArmed = false
        emergencyOverrideRequestInFlight = false
        emergencyPanel.isHidden = true
        emergencyButton.isHidden = true
        clearEmergencyPanelPresentation()
        clearEmergencyButtonPresentation()
    }

    private func configureEmergencyButton(
        sessionID: UUID,
        isAvailable: Bool,
        isArmed: Bool
    ) {
        let isSameEmergencySession = emergencySessionID == sessionID
        if !isSameEmergencySession {
            emergencySessionID = sessionID
            emergencyOverrideRequestInFlight = false
            emergencyOverrideArmed = false
        }

        guard isAvailable else {
            isEmergencyOverrideAvailable = false
            emergencyOverrideArmed = false
            emergencyOverrideRequestInFlight = false
            emergencyPanel.isHidden = true
            emergencyButton.isHidden = true
            clearEmergencyPanelPresentation()
            clearEmergencyButtonPresentation()
            return
        }

        isEmergencyOverrideAvailable = true
        emergencyOverrideArmed = isArmed

        emergencyButton.isHidden = false
        emergencyButton.isEnabled = true
        updateEmergencyAffordanceUI()
    }

    private func updateEmergencyAffordanceUI() {
        guard isEmergencyOverrideAvailable else { return }

        emergencyPanel.isHidden = false
        emergencyPanelWidthConstraint?.constant = 188
        emergencyPanelHeightConstraint?.constant = 44
        let style = EmergencyOverlayVisualStyle.style(isArmed: emergencyOverrideArmed)
        emergencyPanel.layer?.backgroundColor = NSColor.systemRed
            .withAlphaComponent(style.panelBackgroundAlpha)
            .cgColor
        emergencyPanel.layer?.borderColor = NSColor.systemRed
            .withAlphaComponent(style.panelBorderAlpha)
            .cgColor
        emergencyButton.alphaValue = style.buttonAlpha
        emergencyButton.isEnabled = true
        emergencyButton.contentTintColor = NSColor.systemRed.withAlphaComponent(style.tintAlpha)

        let title: String
        if emergencyOverrideArmed {
            title = L10n.tr("overlay.emergencyOverrideConfirm")
        } else {
            title = L10n.tr("overlay.emergencyOverride")
        }
        let help: String
        if emergencyOverrideArmed {
            help = L10n.tr("overlay.emergencyOverrideConfirmHelp")
        } else {
            help = L10n.tr("overlay.emergencyOverrideHelp")
        }
        setEmergencyPanelAccessibility(title: title, help: help)
        setEmergencyButtonTitle(
            title,
            help: help,
            style: style
        )
    }

    private func setEmergencyPanelAccessibility(title: String, help: String) {
        emergencyPanel.toolTip = help
        emergencyPanel.setAccessibilityLabel(title)
        emergencyPanel.setAccessibilityHelp(help)
    }

    private func clearEmergencyPanelPresentation() {
        emergencyPanel.toolTip = nil
        emergencyPanel.setAccessibilityLabel(nil)
        emergencyPanel.setAccessibilityHelp(nil)
    }

    private func setEmergencyButtonTitle(_ title: String, help: String, style: EmergencyOverlayVisualStyle) {
        emergencyButton.image = NSImage(
            systemSymbolName: "exclamationmark.triangle",
            accessibilityDescription: title
        )
        emergencyButton.setAccessibilityLabel(title)
        emergencyButton.setAccessibilityHelp(help)
        emergencyButton.toolTip = help
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.systemRed.withAlphaComponent(style.titleAlpha),
            .font: NSFont.systemFont(ofSize: 13, weight: .medium)
        ]
        emergencyButton.attributedTitle = NSAttributedString(string: title, attributes: attributes)
    }

    private func clearEmergencyButtonPresentation() {
        emergencyButton.image = nil
        emergencyButton.toolTip = nil
        emergencyButton.setAccessibilityLabel(nil)
        emergencyButton.setAccessibilityHelp(nil)
        emergencyButton.title = ""
        emergencyButton.attributedTitle = NSAttributedString(string: "")
    }

    private func configureBodyActionButton(
        _ button: OverlayActionButton,
        identifier: String,
        kind: BodyOverlayActionKind,
        action: Selector
    ) {
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .inline
        button.isBordered = false
        button.imagePosition = .imageLeading
        button.contentTintColor = NSColor.white.withAlphaComponent(0.72)
        button.target = self
        button.action = action
        button.alphaValue = 0.78
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 112).isActive = true
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
        updateBodyActionButtonPresentation(button, kind: kind)
    }

    private func updateBodyActionButtons() {
        let actions = bodyActions
        bodyPostponeButton.isHidden = !(actions?.canPostpone ?? false)
        bodySkipButton.isHidden = !(actions?.canSkip ?? false)
        bodyFinishButton.isHidden = !(actions?.canFinish ?? false)
        [
            (bodyPostponeButton, BodyOverlayActionKind.postpone),
            (bodySkipButton, BodyOverlayActionKind.skip),
            (bodyFinishButton, BodyOverlayActionKind.finish)
        ].forEach { button, kind in
            button.isEnabled = !button.isHidden && !bodyActionRequestPending
            button.alphaValue = bodyActionRequestPending ? 0.42 : 0.78
            if button.isHidden {
                clearBodyActionButtonPresentation(button)
            } else {
                updateBodyActionButtonPresentation(button, kind: kind)
                button.applyBodyActionTileStyle(
                    isPendingButton: bodyActionRequestPending && pendingBodyAction == kind,
                    isActionLocked: bodyActionRequestPending && pendingBodyAction != kind
                )
            }
        }
        bodyActionStack.isHidden = bodyPostponeButton.isHidden && bodySkipButton.isHidden && bodyFinishButton.isHidden
        bodyActionPanel.isHidden = bodyActionStack.isHidden
        updateBodyActionPanelAffordance()
    }

    private func updateBodyActionPanelAffordance() {
        guard !bodyActionPanel.isHidden,
              let action = singleVisibleBodyActionKind() else {
            bodyActionPanel.toolTip = nil
            bodyActionPanel.setAccessibilityLabel(nil)
            bodyActionPanel.setAccessibilityHelp(nil)
            return
        }

        let isPendingAction = bodyActionRequestPending && pendingBodyAction == action
        let title = isPendingAction ? action.pendingTitle : action.title
        let help = isPendingAction ? action.pendingHelp : action.help
        bodyActionPanel.toolTip = help
        bodyActionPanel.setAccessibilityLabel(title)
        bodyActionPanel.setAccessibilityHelp(help)
    }

    private func singleVisibleBodyActionKind() -> BodyOverlayActionKind? {
        let visibleActions: [BodyOverlayActionKind] = [
            bodyPostponeButton.isHidden ? nil : .postpone,
            bodySkipButton.isHidden ? nil : .skip,
            bodyFinishButton.isHidden ? nil : .finish
        ].compactMap { $0 }
        return visibleActions.count == 1 ? visibleActions[0] : nil
    }

    private func clearBodyActionButtonPresentation(_ button: OverlayActionButton) {
        button.image = nil
        button.toolTip = nil
        button.setAccessibilityLabel(nil)
        button.setAccessibilityHelp(nil)
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.clearBodyActionTileStyle()
    }

    private func updateBodyActionButtonPresentation(_ button: OverlayActionButton, kind: BodyOverlayActionKind) {
        let isPendingButton = bodyActionRequestPending && pendingBodyAction == kind
        let title = isPendingButton ? kind.pendingTitle : kind.title
        let help: String
        if isPendingButton {
            help = kind.pendingHelp
        } else if bodyActionRequestPending {
            help = L10n.tr("overlay.bodyActionPendingHelp")
        } else {
            help = kind.help
        }
        let symbolName = isPendingButton ? "hourglass" : kind.symbolName

        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        button.toolTip = help
        button.setAccessibilityLabel(title)
        button.setAccessibilityHelp(help)
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.82),
                .font: NSFont.systemFont(ofSize: 13, weight: .medium)
            ]
        )
    }

    private func localBodyBreakImage(settings: RestSettings) -> NSImage? {
        guard settings.bodyBreak.content == .localImage,
              let path = settings.contentLibrary.localImagePaths.first,
              URL(string: path)?.scheme == nil else {
            return nil
        }
        return NSImage(contentsOfFile: path)
    }

    private func bodyBreakCopy(from idea: RestIdea?) -> (title: String, body: String) {
        let fallbackTitle = L10n.tr("overlay.bodyTitle")
        let fallbackBody = L10n.tr("overlay.bodyBody")
        let title = idea?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let body = idea.map { ContentSanitizer.sanitizeRichText($0.body) } ?? ""
        return (
            title: title.isEmpty ? fallbackTitle : title,
            body: body.isEmpty ? fallbackBody : body
        )
    }

    private func updateOverlayTextAccessibility() {
        [titleLabel, detailLabel, countdownLabel].forEach { label in
            let text = label.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isHidden, !text.isEmpty else {
                label.toolTip = nil
                label.setAccessibilityLabel(nil)
                label.setAccessibilityHelp(nil)
                return
            }
            label.toolTip = text
            label.setAccessibilityLabel(text)
            label.setAccessibilityHelp(text)
        }
    }

    private func updateReadableLabelWrapping(maxWidth: CGFloat) {
        [titleLabel, detailLabel].forEach { label in
            let mode: NSLineBreakMode = containsUnbrokenTokenWiderThanReadableArea(
                label.stringValue,
                font: label.font ?? .systemFont(ofSize: NSFont.systemFontSize),
                maxWidth: maxWidth
            ) ? .byCharWrapping : .byWordWrapping
            label.lineBreakMode = mode
            label.cell?.lineBreakMode = mode
        }
    }

    private func containsUnbrokenTokenWiderThanReadableArea(
        _ text: String,
        font: NSFont,
        maxWidth: CGFloat
    ) -> Bool {
        text
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .contains { token in
                let tokenWidth = String(token).size(withAttributes: [.font: font]).width
                return tokenWidth > maxWidth
            }
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
        guard rule.isActionable else { return false }
        let running = NSWorkspace.shared.runningApplications
        return running.contains { app in
            matches(
                rule: rule,
                candidates: [
                    app.localizedName,
                    app.bundleIdentifier,
                    app.executableURL?.lastPathComponent,
                    app.executableURL?.path
                ].compactMap { $0 }
            )
        }
    }

    static func matches(rule: AppExclusionRule, candidates: [String]) -> Bool {
        guard rule.isActionable else { return false }
        let normalizedTerms = rule.normalizedMatchTerms.map { $0.lowercased() }

        let normalizedCandidates = candidates.map { $0.lowercased() }
        return normalizedTerms.contains { term in
            normalizedCandidates.contains { $0.contains(term) }
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

enum DisplayIdentifier {
    static let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")

    static func value(from deviceDescription: [NSDeviceDescriptionKey: Any], fallbackFrame: NSRect) -> CGDirectDisplayID {
        directDisplayID(from: deviceDescription[screenNumberKey]) ?? syntheticDisplayID(for: fallbackFrame)
    }

    static func directDisplayID(from value: Any?) -> CGDirectDisplayID? {
        if let number = value as? NSNumber {
            guard CFGetTypeID(number) != CFBooleanGetTypeID(),
                  number.int64Value > 0,
                  number.uint64Value <= UInt64(CGDirectDisplayID.max) else {
                return nil
            }
            return CGDirectDisplayID(number.uint64Value)
        }

        if let id = value as? CGDirectDisplayID, id > 0 {
            return id
        }

        if let id = value as? Int,
           id > 0,
           id <= Int(CGDirectDisplayID.max) {
            return CGDirectDisplayID(id)
        }

        return nil
    }

    static func syntheticDisplayID(for frame: NSRect) -> CGDirectDisplayID {
        var hash: UInt64 = 0xcbf29ce484222325
        for component in frame.syntheticDisplayIDComponents {
            var value = UInt64(bitPattern: component)
            for _ in 0..<8 {
                hash ^= value & 0xff
                hash &*= 0x100000001b3
                value >>= 8
            }
        }

        let raw = CGDirectDisplayID(truncatingIfNeeded: hash)
        return (raw == 0 ? 1 : raw) | 0x8000_0000
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        DisplayIdentifier.value(from: deviceDescription, fallbackFrame: frame)
    }
}

private extension NSRect {
    var syntheticDisplayIDComponents: [Int64] {
        [minX, minY, width, height].map { coordinate in
            Int64((coordinate * 1_000).rounded())
        }
    }
}

extension ShouldRestAppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

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
    convenience init(hex: String, fallback: String = "#000000") {
        let normalized = RestRule.normalizedColorHex(
            hex,
            fallback: RestRule.normalizedColorHex(fallback, fallback: "#000000")
        )
        let body = String(normalized.dropFirst())
        let value = UInt64(body, radix: 16) ?? 0

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

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
    private var preferencesWindowController: PreferencesWindowController?
    private var debugWindowController: DebugWindowController?
    private var statusItem: NSStatusItem?
    private var tickTimer: Timer?
    private var lastFocusCheck = Date.distantPast
    private var focusModeActive = false
    private var suspendedAt: Date?
    private var manualAwaitingSessionID: UUID?

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
        createStatusItem()
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
        applyOpenAtLoginSetting()
        configureGlobalShortcuts()
        tick()
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
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "ShouldRest"
        statusItem = item
        rebuildMenu()
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
                settings: settings,
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
                logger.log("Completed \(active.kind.rawValue)")
                rebuildMenu()
                return
            }
            rebuildMenu()
            return
        }

        let result = engine.evaluate(now: now, context: currentContext())
        switch result {
        case .started(let session):
            soundPlayer.play(settings.rule(for: session.kind).startSound)
            overlayController.present(session: session, settings: settings, now: now)
            logger.log("Started \(session.kind.rawValue)")
        case .notificationDue(let kind):
            showNotification(for: kind)
            logger.log("Notification due for \(kind.rawValue)")
        default:
            break
        }
        rebuildMenu()
    }

    private func currentContext() -> RestContext {
        let appExclusions = settings.appExclusions.map { rule in
            AppExclusionEvaluation(rule: rule, isMatched: RunningApplications.matches(rule: rule))
        }
        return RestContext(
            idleDuration: SystemIdleTime.seconds(),
            focusModeActive: focusModeActive,
            inWorkingHours: true,
            appExclusions: appExclusions
        )
    }

    private func showNotification(for kind: RestKind) {
        let content = UNMutableNotificationContent()
        content.title = "ShouldRest"
        content.body = kind == .eyeGate ? "Eye Gate soon" : "Body Break soon"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func rebuildMenu() {
        guard let item = statusItem else { return }
        item.button?.title = menuBarTitle()

        let menu = NSMenu()
        menu.addItem(disabledItem(statusText()))
        menu.addItem(.separator())

        if engine.state.activeSession == nil {
            menu.addItem(actionItem("Take Eye Gate Now", #selector(takeEyeGateNow)))
            menu.addItem(actionItem("Take Body Break Now", #selector(takeBodyBreakNow)))
            menu.addItem(.separator())
        }

        if let active = engine.state.activeSession, active.kind == .bodyBreak {
            menu.addItem(actionItem("Postpone Body Break", #selector(postponeBodyBreak)))
            menu.addItem(actionItem("Finish Body Break", #selector(finishActiveBreak)))
            menu.addItem(actionItem("Skip Body Break", #selector(skipBodyBreak)))
            menu.addItem(.separator())
        }

        if engine.state.pause != nil {
            menu.addItem(actionItem("Resume", #selector(resumeBreaks)))
        } else if engine.state.activeSession == nil {
            let pauseMenu = NSMenu()
            pauseMenu.addItem(actionItem("30 Minutes", #selector(pauseFor30Minutes)))
            pauseMenu.addItem(actionItem("1 Hour", #selector(pauseFor1Hour)))
            pauseMenu.addItem(actionItem("2 Hours", #selector(pauseFor2Hours)))
            pauseMenu.addItem(actionItem("5 Hours", #selector(pauseFor5Hours)))
            pauseMenu.addItem(actionItem("Until Morning", #selector(pauseUntilMorning)))
            pauseMenu.addItem(.separator())
            pauseMenu.addItem(actionItem("Indefinitely", #selector(pauseIndefinitely)))
            let pauseItem = NSMenuItem(title: "Pause", action: nil, keyEquivalent: "")
            pauseItem.submenu = pauseMenu
            menu.addItem(pauseItem)
        }

        menu.addItem(actionItem("Reset", #selector(resetBreaks)))
        menu.addItem(.separator())
        menu.addItem(actionItem("Preferences...", #selector(openPreferences)))
        menu.addItem(actionItem("Save Settings", #selector(saveSettings)))
        menu.addItem(actionItem("Copy Debug Info", #selector(copyDebugInfo)))
        menu.addItem(actionItem("Debug Panel...", #selector(openDebugPanel)))

        if !settings.admin.hideSettingsFileLocation {
            let pathItem = disabledItem(settingsStore.fileURL.path)
            pathItem.toolTip = settingsStore.fileURL.path
            menu.addItem(pathItem)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit ShouldRest", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
    }

    private func menuBarTitle() -> String {
        if engine.state.activeSession != nil {
            return "Rest"
        }
        if engine.state.pause != nil {
            return "Paused"
        }
        guard let scheduled = engine.state.scheduled else {
            return "ShouldRest"
        }
        let seconds = max(0, Int(scheduled.dueAt.timeIntervalSinceNow))
        switch settings.presentation.trayIconStyle {
        case .default:
            return "ShouldRest"
        case .timeToBreak:
            return seconds >= 60 ? "\(seconds / 60)m" : "\(seconds)s"
        case .progress:
            return scheduled.kind == .eyeGate ? "Eye \(seconds / 60)m" : "Body \(seconds / 60)m"
        }
    }

    private func statusText() -> String {
        if let active = engine.state.activeSession {
            let remaining = max(0, Int(active.duration - Date().timeIntervalSince(active.startedAt)))
            return "\(active.kind.rawValue) active, \(remaining)s remaining"
        }
        if let pause = engine.state.pause {
            if let until = pause.until {
                return "Paused until \(until.formatted(date: .omitted, time: .shortened))"
            }
            return "Paused indefinitely"
        }
        if let scheduled = engine.state.scheduled {
            return "Next: \(scheduled.kind.rawValue) at \(scheduled.dueAt.formatted(date: .omitted, time: .shortened))"
        }
        return "No enabled rests"
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

    @objc private func takeEyeGateNow() {
        if case .started(let session) = engine.takeNow(.eyeGate) {
            soundPlayer.play(settings.rule(for: session.kind).startSound)
            overlayController.present(session: session, settings: settings, now: Date())
            logger.log("Manual Eye Gate started")
        }
        rebuildMenu()
    }

    @objc private func takeBodyBreakNow() {
        if case .started(let session) = engine.takeNow(.bodyBreak) {
            soundPlayer.play(settings.rule(for: session.kind).startSound)
            overlayController.present(session: session, settings: settings, now: Date())
            logger.log("Manual Body Break started")
        }
        rebuildMenu()
    }

    @objc private func postponeBodyBreak() {
        if case .postponed = engine.postponeActive() {
            overlayController.dismiss()
            logger.log("Body Break postponed")
        }
        rebuildMenu()
    }

    @objc private func finishActiveBreak() {
        if let active = engine.state.activeSession {
            soundPlayer.play(settings.rule(for: active.kind).finishSound)
            logger.log("Manually finished \(active.kind.rawValue)")
        }
        _ = engine.completeActive(reason: .manual)
        overlayController.dismiss()
        manualAwaitingSessionID = nil
        rebuildMenu()
    }

    @objc private func skipBodyBreak() {
        _ = engine.skipActive()
        overlayController.dismiss()
        manualAwaitingSessionID = nil
        logger.log("Body Break skipped")
        rebuildMenu()
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
        let calendar = Calendar.current
        let now = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(24 * 60 * 60)
        let morning = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        pause(for: morning.timeIntervalSince(now), reason: .untilMorning)
    }

    @objc private func pauseIndefinitely() {
        pause(for: nil, reason: .user)
    }

    private func pause(for duration: TimeInterval?, reason: PauseReason) {
        if case .paused = engine.pause(for: duration, reason: reason) {
            overlayController.dismiss()
            logger.log("Breaks paused reason=\(reason.rawValue) duration=\(String(describing: duration))")
        }
        rebuildMenu()
    }

    @objc private func resetBreaks() {
        _ = engine.reset()
        overlayController.dismiss()
        manualAwaitingSessionID = nil
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
        NSApp.activate(ignoringOtherApps: true)
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
        NSApp.activate(ignoringOtherApps: true)
        logger.log("Debug panel opened")
    }

    private func applySettings(_ nextSettings: RestSettings) {
        settings = nextSettings
        engine.updateSettings(nextSettings)
        applyOpenAtLoginSetting()
        configureGlobalShortcuts()
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
        case .reset:
            resetBreaks()
        case .eye:
            takeEyeGateNow()
        case .body:
            takeBodyBreakNow()
        case .preferences:
            openPreferences()
        case .debug:
            openDebugPanel()
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

    @objc private func systemWillPause() {
        suspendedAt = Date()
        if engine.state.activeSession == nil {
            _ = engine.pause(for: nil, reason: .suspendOrLock)
        }
        overlayController.dismiss()
        logger.log("System pause detected")
        rebuildMenu()
    }

    @objc private func systemDidResume() {
        let now = Date()
        let idleDuration = suspendedAt.map { now.timeIntervalSince($0) } ?? 0
        suspendedAt = nil
        _ = engine.resume(now: now)
        _ = engine.evaluate(now: now, context: RestContext(idleDuration: idleDuration))
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
        registerShortcut(settings.shortcuts.takeEyeGateNow) { [weak self] in
            self?.takeEyeGateNow()
        }
        registerShortcut(settings.shortcuts.takeBodyBreakNow) { [weak self] in
            self?.takeBodyBreakNow()
        }
        registerShortcut(settings.shortcuts.skipToNextBodyBreak) { [weak self] in
            self?.takeBodyBreakNow()
        }
        registerShortcut(settings.shortcuts.reset) { [weak self] in
            self?.resetBreaks()
        }
        logger.log("Global shortcuts configured")
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
        [
            "settingsPath=\(settingsStore.fileURL.path)",
            "logPath=\(logger.fileURL.path)",
            "scheduled=\(String(describing: engine.state.scheduled))",
            "activeSession=\(String(describing: engine.state.activeSession))",
            "pause=\(String(describing: engine.state.pause))",
            "dangerScore=\(engine.state.dangerScore)",
            "statistics=\(engine.state.statistics)",
            "focusModeActive=\(focusModeActive)",
            "idleSeconds=\(SystemIdleTime.seconds())",
            "openAtLogin=\(settings.operations.openAtLogin)",
            "loginItemAvailable=\(LoginItemManager.isAvailable)"
        ].joined(separator: "\n")
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

        for screen in NSScreen.screens {
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

        let currentIDs = Set(NSScreen.screens.map(\.displayID))
        for (id, window) in windows where !currentIDs.contains(id) {
            window.close()
        }
        windows = windows.filter { currentIDs.contains($0.key) }

        for screen in NSScreen.screens {
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
        let selection = settings.rule(for: session.kind).enforcement.contentDisplay
        switch selection {
        case .none:
            return nil
        case .all:
            return nil
        case .primary:
            return NSScreen.screens.first
        case .cursor:
            return NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.screens.first
        case .configured:
            return NSScreen.screens.first
        }
    }

    private func shouldShowContent(
        on screen: NSScreen,
        contentScreen: NSScreen?,
        session: RestSession,
        settings: RestSettings
    ) -> Bool {
        let enforcement = settings.rule(for: session.kind).enforcement
        if enforcement.contentDisplay == .all {
            return true
        }
        guard let contentScreen else {
            return false
        }
        return screen.displayID == contentScreen.displayID
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

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

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

        guard showsContent else { return }

        if manualAwaiting {
            titleLabel.stringValue = "Break complete"
            detailLabel.stringValue = "Use the menu to finish when ready"
            countdownLabel.stringValue = "ready"
            return
        }

        switch session.kind {
        case .eyeGate:
            let idea = settings.contentLibrary.ideas(for: .eyeGate).first
            titleLabel.stringValue = idea?.title ?? "Look away"
            detailLabel.stringValue = idea?.body ?? "Rest your eyes"
        case .bodyBreak:
            let ideas = settings.contentLibrary.ideas(for: .bodyBreak)
            let index = Int(session.startedAt.timeIntervalSinceReferenceDate) % max(1, ideas.count)
            let idea = ideas[safe: index]
            titleLabel.stringValue = idea?.title ?? "Body Break"
            detailLabel.stringValue = idea?.body ?? "Stand up, breathe, and move"
        }
        countdownLabel.stringValue = "\(remainingSeconds)s"
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

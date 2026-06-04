import AppKit
import Foundation
import ShouldRestCore

enum AppPaths {
    static let supportDirectory = supportDirectory(environment: ProcessInfo.processInfo.environment)

    static let settingsURL = supportDirectory.appendingPathComponent("settings.json")
    static let logURL = supportDirectory.appendingPathComponent("logs/shouldrest.log")
    static let emergencyRequestURL = supportDirectory.appendingPathComponent("emergency-request")

    static func supportDirectory(environment: [String: String]) -> URL {
        if let override = environment["SHOULDREST_SUPPORT_DIR"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true).standardizedFileURL
        }

        return FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShouldRest", isDirectory: true)
    }
}

enum EmergencyAutomationSignal {
    static let defaultMaxAge: TimeInterval = 10

    static func write(fileURL: URL = AppPaths.emergencyRequestURL, now: Date = Date()) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try ISO8601DateFormatter()
            .string(from: now)
            .write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
    }

    static func isPending(
        fileURL: URL = AppPaths.emergencyRequestURL,
        now: Date = Date(),
        maxAge: TimeInterval = defaultMaxAge
    ) -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let value = String(data: data, encoding: String.Encoding.utf8),
              let requestedAt = ISO8601DateFormatter().date(from: value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        if now.timeIntervalSince(requestedAt) > maxAge {
            _ = consume(fileURL: fileURL)
            return false
        }
        return true
    }

    static func consume(fileURL: URL = AppPaths.emergencyRequestURL) -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return false }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            return false
        }
        return true
    }
}

enum AppVersion {
    private static let fallback = "0.1.133"

    static var current: String {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }
        return version
    }
}

final class AppLogger {
    let fileURL: URL
    private let formatter = ISO8601DateFormatter()

    init(fileURL: URL = AppPaths.logURL) {
        self.fileURL = fileURL
    }

    func log(_ message: String) {
        let line = "\(formatter.string(from: Date())) \(message)\n"
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: fileURL.path),
               let handle = try? FileHandle(forWritingTo: fileURL) {
                try handle.seekToEnd()
                if let data = line.data(using: String.Encoding.utf8) {
                    try handle.write(contentsOf: data)
                }
                try handle.close()
            } else {
                try line.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
            }
        } catch {
            NSLog("ShouldRest log write failed: \(error.localizedDescription)")
        }
    }
}

extension Notification.Name {
    static let shouldRestAutomation = Notification.Name("dev.shouldrest.automation")
}

enum AutomationCommand: String {
    case pause
    case resume
    case toggle
    case reset
    case eye
    case body
    case emergency
    case preferences
    case supportReport = "debug"
    case supportReportPanel = "debugPanel"
    case about
}

struct AutomationRequest: Equatable {
    var command: AutomationCommand
    var duration: TimeInterval?
    var title: String?
    var text: String?
    var noSkip: Bool

    init(
        command: AutomationCommand,
        duration: TimeInterval? = nil,
        title: String? = nil,
        text: String? = nil,
        noSkip: Bool = false
    ) {
        self.command = command
        self.duration = duration
        self.title = title
        self.text = text
        self.noSkip = noSkip
    }

    var userInfo: [AnyHashable: Any] {
        var userInfo: [AnyHashable: Any] = [:]
        if let duration {
            userInfo["duration"] = duration
        }
        if let title, !title.isEmpty {
            userInfo["title"] = title
        }
        if let text, !text.isEmpty {
            userInfo["text"] = text
        }
        if noSkip {
            userInfo["noSkip"] = true
        }
        return userInfo
    }
}

struct EyeGateCommandPlan: Equatable {
    var request: AutomationRequest?
    var keepsCurrentSchedule: Bool
    var invalidWait: String?
    var ignoredReadableContent: Bool
}

@MainActor
enum CommandLineAutomation {
    private enum DurationParseResult {
        case valid(TimeInterval?)
        case invalid
    }

    private static let appBundleIdentifier = "dev.shouldrest.app"
    private static var pendingLaunchRequest: AutomationRequest?

    static func consumeLaunchRequest() -> AutomationRequest? {
        defer { pendingLaunchRequest = nil }
        return pendingLaunchRequest
    }

    static func handle(arguments: [String]) -> Bool {
        let args = Array(arguments.dropFirst())
        guard let command = args.first else {
            return false
        }

        if command.hasPrefix("shouldrest://") {
            guard let request = request(fromURLString: command) else {
                print(L10n.format("cli.invalidURL", command))
                return true
            }
            return dispatchOrQueue(request, message: L10n.format("cli.requestedAutomationURL", command))
        }

        switch command {
        case "help", "--help", "-h":
            print(helpText)
            return true
        case "version", "--version", "-v":
            print("ShouldRest \(AppVersion.current)")
            return true
        case "settings":
            if configuredSettings()?.admin.hideSettingsFileLocation == true {
                print(L10n.tr("cli.settingsPathHidden"))
            } else {
                print(AppPaths.settingsURL.path)
            }
            return true
        case "logs":
            if configuredSettings()?.admin.hideSettingsFileLocation == true {
                print(L10n.tr("cli.logsPathHidden"))
            } else {
                print(AppPaths.logURL.path)
            }
            return true
        case "support", "support-report", "report", "debug":
            return dispatchOrQueue(
                AutomationRequest(command: .supportReport),
                message: L10n.tr("cli.requestedDiagnostics")
            )
        case "support-panel", "support-report-panel", "report-panel", "debug-panel", "debugPanel":
            return dispatchOrQueue(
                AutomationRequest(command: .supportReportPanel),
                message: L10n.tr("cli.requestedDiagnosticsWindow")
            )
        case "about":
            return dispatchOrQueue(
                AutomationRequest(command: .about),
                message: L10n.tr("cli.requestedAbout")
            )
        case "url":
            guard args.indices.contains(1) else {
                print(L10n.tr("cli.urlUsage"))
                return true
            }
            guard let request = request(fromURLString: args[1]) else {
                print(L10n.format("cli.invalidURL", args[1]))
                return true
            }
            return dispatchOrQueue(request, message: L10n.format("cli.requestedAutomationURL", args[1]))
        case "pause":
            let request = durationArgument(args)
            if let invalid = request.invalid {
                print(L10n.format("cli.invalidPauseDuration", invalid))
                return true
            }
            return dispatchOrQueue(
                AutomationRequest(command: .pause, duration: request.duration),
                message: pauseRequestMessage(duration: request.duration)
            )
        case "resume":
            return dispatchOrQueue(AutomationRequest(command: .resume), message: L10n.tr("cli.requestedResume"))
        case "toggle":
            return dispatchOrQueue(AutomationRequest(command: .toggle), message: L10n.tr("cli.requestedToggle"))
        case "reset":
            return dispatchOrQueue(AutomationRequest(command: .reset), message: L10n.tr("cli.requestedReset"))
        case "eye", "mini":
            let plan = eyeGateCommandPlan(args)
            if let invalid = plan.invalidWait {
                print(L10n.format("cli.invalidWaitDuration", invalid))
                return true
            }
            if plan.ignoredReadableContent {
                print(L10n.tr("cli.eyeReadableContentIgnored"))
            }
            if plan.keepsCurrentSchedule {
                print(L10n.tr("cli.eyeNoSkipWithoutWait"))
                return true
            }
            guard let automationRequest = plan.request else { return true }
            return dispatchOrQueue(
                automationRequest,
                message: eyeGateRequestMessage(wait: automationRequest.duration)
            )
        case "body", "long":
            let request = restRequest(args)
            if let invalid = request.invalidWait {
                print(L10n.format("cli.invalidWaitDuration", invalid))
                return true
            }
            let automationRequest = AutomationRequest(
                command: .body,
                duration: request.wait,
                title: request.title,
                text: request.text,
                noSkip: request.noSkip
            )
            if request.noSkip, request.wait == nil {
                return dispatchOrQueue(automationRequest, message: L10n.tr("cli.requestedNextBodyContent"))
            } else {
                return dispatchOrQueue(
                    automationRequest,
                    message: bodyBreakRequestMessage(wait: request.wait)
                )
            }
        case "emergency", "emergency-exit", "emergencyExit":
            return dispatchOrQueue(
                AutomationRequest(command: .emergency),
                message: L10n.tr("cli.requestedEmergency")
            )
        case "preferences":
            return dispatchOrQueue(
                AutomationRequest(command: .preferences),
                message: L10n.tr("cli.requestedPreferences")
            )
        default:
            print(L10n.format("cli.unknownCommand", command, helpText))
            return true
        }
    }

    private static func dispatchOrQueue(_ request: AutomationRequest, message: String) -> Bool {
        if hasOtherRunningAppInstance() {
            post(request)
            print(message)
            return true
        }

        pendingLaunchRequest = request
        print(L10n.format("cli.startingShouldRest", message))
        return false
    }

    private static func pauseRequestMessage(duration: TimeInterval?) -> String {
        guard let duration else {
            return L10n.tr("cli.requestedPauseIndefinitely")
        }
        return L10n.format("cli.requestedPauseDuration", Int(duration))
    }

    private static func eyeGateRequestMessage(wait: TimeInterval?) -> String {
        guard let wait else {
            return L10n.tr("cli.requestedEyeNow")
        }
        return L10n.format("cli.requestedEyeAfter", Int(wait))
    }

    private static func bodyBreakRequestMessage(wait: TimeInterval?) -> String {
        guard let wait else {
            return L10n.tr("cli.requestedBodyNow")
        }
        return L10n.format("cli.requestedBodyAfter", Int(wait))
    }

    private static func post(_ request: AutomationRequest) {
        if request.command == .emergency {
            try? EmergencyAutomationSignal.write()
        }
        DistributedNotificationCenter.default().postNotificationName(
            .shouldRestAutomation,
            object: request.command.rawValue,
            userInfo: request.userInfo,
            deliverImmediately: true
        )
    }

    @discardableResult
    static func post(urlString: String) -> Bool {
        guard let request = request(fromURLString: urlString) else {
            return false
        }
        post(request)
        return true
    }

    private static func request(fromURLString urlString: String) -> AutomationRequest? {
        guard let url = URL(string: urlString), url.scheme == "shouldrest" else {
            return nil
        }
        return request(from: url)
    }

    static func request(from url: URL) -> AutomationRequest? {
        guard url.scheme == "shouldrest" else {
            return nil
        }
        let name = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let command: AutomationCommand
        switch name {
        case "pause":
            command = .pause
        case "resume":
            command = .resume
        case "toggle":
            command = .toggle
        case "reset":
            command = .reset
        case "eye", "mini":
            command = .eye
        case "body", "long":
            command = .body
        case "emergency", "emergency-exit", "emergencyExit":
            command = .emergency
        case "preferences":
            command = .preferences
        case "support", "support-report", "report", "debug":
            command = .supportReport
        case "support-panel", "support-report-panel", "report-panel", "debug-panel", "debugPanel":
            command = .supportReportPanel
        case "about":
            command = .about
        default:
            return nil
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let durationValue = components?.queryItems?.first(where: { $0.name == "duration" })?.value
        let waitValue = components?.queryItems?.first(where: { $0.name == "wait" })?.value
        let title = components?.queryItems?.first(where: { $0.name == "title" })?.value
        let text = components?.queryItems?.first(where: { $0.name == "text" })?.value
        let noSkip = components?.queryItems?.contains(where: { $0.name == "noskip" || $0.name == "noSkip" }) ?? false
        let duration: TimeInterval?
        if command == .pause {
            guard case .valid(let parsed) = automationDuration(from: durationValue, allowsIndefinitely: true) else {
                return nil
            }
            duration = parsed
        } else {
            guard case .valid(let parsed) = automationDuration(from: waitValue ?? durationValue, allowsIndefinitely: false) else {
                return nil
            }
            duration = parsed
        }
        return AutomationRequest(command: command, duration: duration, title: title, text: text, noSkip: noSkip)
    }

    static func eyeGateCommandPlan(_ args: [String]) -> EyeGateCommandPlan {
        let request = restRequest(args)
        if let invalidWait = request.invalidWait {
            return EyeGateCommandPlan(
                request: nil,
                keepsCurrentSchedule: false,
                invalidWait: invalidWait,
                ignoredReadableContent: false
            )
        }

        let ignoredReadableContent = hasReadableContent(request.title) || hasReadableContent(request.text)
        if request.noSkip, request.wait == nil {
            return EyeGateCommandPlan(
                request: nil,
                keepsCurrentSchedule: true,
                invalidWait: nil,
                ignoredReadableContent: ignoredReadableContent
            )
        }

        return EyeGateCommandPlan(
            request: AutomationRequest(command: .eye, duration: request.wait, noSkip: request.noSkip),
            keepsCurrentSchedule: false,
            invalidWait: nil,
            ignoredReadableContent: ignoredReadableContent
        )
    }

    private static func hasReadableContent(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private static func durationArgument(_ args: [String]) -> (duration: TimeInterval?, invalid: String?) {
        guard let value = optionValue(args, short: "-d", long: "--duration") else {
            return (nil, nil)
        }
        if value == "indefinitely" {
            return (nil, nil)
        }
        guard let duration = parseDuration(value, operations: configuredOperations()) else {
            return (nil, value)
        }
        return (duration, nil)
    }

    private static func restRequest(
        _ args: [String]
    ) -> (title: String?, text: String?, wait: TimeInterval?, noSkip: Bool, invalidWait: String?) {
        let waitValue = optionValue(args, short: "-w", long: "--wait")
        if let waitValue,
           let wait = parseDuration(waitValue, operations: configuredOperations()) {
            return (
                optionValue(args, short: "-T", long: "--title"),
                optionValue(args, short: "-t", long: "--text"),
                wait,
                hasFlag(args, short: "-n", long: "--noskip"),
                nil
            )
        }
        return (
            optionValue(args, short: "-T", long: "--title"),
            optionValue(args, short: "-t", long: "--text"),
            nil,
            hasFlag(args, short: "-n", long: "--noskip"),
            waitValue
        )
    }

    private static func optionValue(_ args: [String], short: String, long: String) -> String? {
        guard let index = args.firstIndex(where: { $0 == short || $0 == long }),
              args.indices.contains(index + 1) else {
            return nil
        }
        return args[index + 1]
    }

    private static func hasFlag(_ args: [String], short: String, long: String) -> Bool {
        args.contains(short) || args.contains(long)
    }

    private static func automationDuration(from value: String?, allowsIndefinitely: Bool) -> DurationParseResult {
        guard let value else {
            return .valid(nil)
        }
        if allowsIndefinitely, value == "indefinitely" {
            return .valid(nil)
        }
        guard let duration = parseDuration(value, operations: configuredOperations()) else {
            return .invalid
        }
        return .valid(duration)
    }

    static func parseDuration(
        _ input: String,
        operations: OperationsSettings? = nil,
        morningHour: Int? = nil
    ) -> TimeInterval? {
        if input == "indefinitely" {
            return nil
        }
        if input == "until-morning" {
            if let operations {
                return operations.secondsUntilMorning()
            }
            return OperationsSettings.secondsUntilMorning(morningHour: morningHour)
        }
        if let minutes = Int(input), minutes > 0 {
            return TimeInterval(minutes * 60)
        }

        let pattern = #"^(?:(\d+)h)?(?:(\d+)m)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
              match.range.location != NSNotFound,
              match.range.length > 0 else {
            return nil
        }

        func number(at index: Int) -> Int {
            guard let range = Range(match.range(at: index), in: input) else { return 0 }
            return Int(input[range]) ?? 0
        }

        let seconds = (number(at: 1) * 60 * 60) + (number(at: 2) * 60)
        return seconds > 0 ? TimeInterval(seconds) : nil
    }

    private static func configuredOperations() -> OperationsSettings? {
        configuredSettings()?.operations
    }

    private static func configuredSettings() -> RestSettings? {
        try? SettingsStore(fileURL: AppPaths.settingsURL).load()
    }

    private static func hasOtherRunningAppInstance() -> Bool {
        let currentProcessID = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication
            .runningApplications(withBundleIdentifier: appBundleIdentifier)
            .contains { app in
                app.processIdentifier != currentProcessID && !app.isTerminated
            }
    }

    private static var helpText: String {
        L10n.tr("cli.help")
    }
}

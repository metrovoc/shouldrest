import AppKit
import Foundation
import ShouldRestCore

enum AppPaths {
    static let supportDirectory = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("ShouldRest", isDirectory: true)

    static let settingsURL = supportDirectory.appendingPathComponent("settings.json")
    static let logURL = supportDirectory.appendingPathComponent("logs/shouldrest.log")
}

enum AppVersion {
    static let current = "0.1.0"
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
    case reset
    case eye
    case body
    case preferences
    case debug
}

enum CommandLineAutomation {
    static func handle(arguments: [String]) -> Bool {
        let args = Array(arguments.dropFirst())
        guard let command = args.first else {
            return false
        }

        if command.hasPrefix("shouldrest://") {
            guard post(urlString: command) else {
                print("Invalid ShouldRest URL: \(command)")
                return true
            }
            print("Requested automation URL: \(command)")
            return true
        }

        switch command {
        case "help", "--help", "-h":
            print(helpText)
            return true
        case "version", "--version", "-v":
            print("ShouldRest \(AppVersion.current)")
            return true
        case "settings":
            print(AppPaths.settingsURL.path)
            return true
        case "logs":
            print(AppPaths.logURL.path)
            return true
        case "debug":
            post(.debug)
            print("Requested debug info from running ShouldRest.")
            return true
        case "url":
            guard args.indices.contains(1), post(urlString: args[1]) else {
                print("Usage: shouldrest url shouldrest://pause?duration=30m")
                return true
            }
            print("Requested automation URL: \(args[1])")
            return true
        case "pause":
            let duration = durationArgument(args)
            post(.pause, duration: duration)
            print("Requested pause\(duration.map { " for \(Int($0)) seconds" } ?? " indefinitely").")
            return true
        case "resume":
            post(.resume)
            print("Requested resume.")
            return true
        case "reset":
            post(.reset)
            print("Requested reset.")
            return true
        case "eye":
            post(.eye)
            print("Requested Eye Gate now.")
            return true
        case "body":
            post(.body)
            print("Requested Body Break now.")
            return true
        case "preferences":
            post(.preferences)
            print("Requested preferences window.")
            return true
        default:
            print("Unknown command: \(command)\n\n\(helpText)")
            return true
        }
    }

    private static func post(_ command: AutomationCommand, duration: TimeInterval? = nil) {
        var userInfo: [String: Any] = [:]
        if let duration {
            userInfo["duration"] = duration
        }
        DistributedNotificationCenter.default().postNotificationName(
            .shouldRestAutomation,
            object: command.rawValue,
            userInfo: userInfo,
            deliverImmediately: true
        )
    }

    @discardableResult
    static func post(urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              url.scheme == "shouldrest",
              let command = command(from: url) else {
            return false
        }
        post(command.command, duration: command.duration)
        return true
    }

    static func command(from url: URL) -> (command: AutomationCommand, duration: TimeInterval?)? {
        let name = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let command: AutomationCommand
        switch name {
        case "pause":
            command = .pause
        case "resume":
            command = .resume
        case "reset":
            command = .reset
        case "eye":
            command = .eye
        case "body":
            command = .body
        case "preferences":
            command = .preferences
        case "debug":
            command = .debug
        default:
            return nil
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let durationValue = components?.queryItems?.first(where: { $0.name == "duration" })?.value
        let duration = durationValue.flatMap { parseDuration($0, morningHour: configuredMorningHour()) }
        return (command, duration)
    }

    private static func durationArgument(_ args: [String]) -> TimeInterval? {
        guard let index = args.firstIndex(where: { $0 == "-d" || $0 == "--duration" }),
              args.indices.contains(index + 1) else {
            return nil
        }
        return parseDuration(args[index + 1], morningHour: configuredMorningHour())
    }

    static func parseDuration(_ input: String, morningHour: Int? = nil) -> TimeInterval? {
        if input == "indefinitely" {
            return nil
        }
        if input == "until-morning" {
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

    private static func configuredMorningHour() -> Int? {
        (try? SettingsStore(fileURL: AppPaths.settingsURL).load())?.operations.pauseUntilMorningHour
    }

    private static var helpText: String {
        L10n.tr("cli.help")
    }
}

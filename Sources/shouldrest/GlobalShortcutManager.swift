import Carbon
import Foundation

final class GlobalShortcutManager {
    private var hotKeys: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: @Sendable () -> Void] = [:]
    private var eventHandler: EventHandlerRef?
    private var nextID: UInt32 = 1
    private let signature = OSType(
        UInt32(Character("S").asciiValue!) << 24 |
        UInt32(Character("R").asciiValue!) << 16 |
        UInt32(Character("S").asciiValue!) << 8 |
        UInt32(Character("T").asciiValue!)
    )

    init() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }
                let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                manager.invoke(id: hotKeyID.id)
                return noErr
            },
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    deinit {
        unregisterAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func register(shortcut: String, handler: @escaping @Sendable () -> Void) {
        guard let parsed = ParsedShortcut(shortcut) else { return }
        let id = nextID
        nextID += 1

        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            parsed.keyCode,
            parsed.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr, let hotKeyRef else { return }
        hotKeys[id] = hotKeyRef
        handlers[id] = handler
    }

    func unregisterAll() {
        for hotKey in hotKeys.values {
            UnregisterEventHotKey(hotKey)
        }
        hotKeys.removeAll()
        handlers.removeAll()
    }

    private func invoke(id: UInt32) {
        guard let handler = handlers[id] else { return }
        DispatchQueue.main.async(execute: handler)
    }
}

private struct ParsedShortcut {
    var keyCode: UInt32
    var modifiers: UInt32

    init?(_ raw: String) {
        let parts = raw
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        guard let key = parts.last, let code = Self.keyCodes[key] else {
            return nil
        }

        var modifiers: UInt32 = 0
        for part in parts.dropLast() {
            switch part {
            case "cmd", "command", "cmdorctrl":
                modifiers |= UInt32(cmdKey)
            case "ctrl", "control":
                modifiers |= UInt32(controlKey)
            case "alt", "option", "opt":
                modifiers |= UInt32(optionKey)
            case "shift":
                modifiers |= UInt32(shiftKey)
            default:
                return nil
            }
        }

        self.keyCode = UInt32(code)
        self.modifiers = modifiers
    }

    private static let keyCodes: [String: Int] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
        "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
        "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
        "n": 45, "m": 46, ".": 47, "`": 50, "space": 49
    ]
}

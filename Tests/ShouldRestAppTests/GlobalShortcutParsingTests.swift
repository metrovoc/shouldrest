import Carbon
import XCTest
@testable import shouldrest

final class GlobalShortcutParsingTests: XCTestCase {
    func testParsesStretchlyStyleCmdOrCtrlShortcut() throws {
        let shortcut = try XCTUnwrap(ParsedShortcut("CmdOrCtrl+X"))

        XCTAssertEqual(shortcut.keyCode, UInt32(kVK_ANSI_X))
        XCTAssertEqual(shortcut.modifiers, UInt32(cmdKey))
    }

    func testParsesMultipleModifierAliasesAndWhitespace() throws {
        let shortcut = try XCTUnwrap(ParsedShortcut(" command + option + shift + space "))

        XCTAssertEqual(shortcut.keyCode, UInt32(kVK_Space))
        XCTAssertEqual(shortcut.modifiers, UInt32(cmdKey | optionKey | shiftKey))
    }

    func testParsesControlAndAltAliases() throws {
        let shortcut = try XCTUnwrap(ParsedShortcut("Ctrl+Alt+M"))

        XCTAssertEqual(shortcut.keyCode, UInt32(kVK_ANSI_M))
        XCTAssertEqual(shortcut.modifiers, UInt32(controlKey | optionKey))
    }

    func testParsesEscapeForEmergencyOverlayFallback() throws {
        let shortcut = try XCTUnwrap(ParsedShortcut("Escape"))

        XCTAssertEqual(shortcut.keyCode, UInt32(kVK_Escape))
        XCTAssertEqual(shortcut.modifiers, 0)
        XCTAssertEqual(ShortcutDisplay.string("Escape"), "Esc")
    }

    func testRejectsUnknownKeysAndModifiers() {
        XCTAssertNil(ParsedShortcut(""))
        XCTAssertNil(ParsedShortcut("CmdOrCtrl"))
        XCTAssertNil(ParsedShortcut("CmdOrCtrl+F13"))
        XCTAssertNil(ParsedShortcut("Meta+X"))
    }

    func testDisplaysShortcutWithSystemModifierSymbols() {
        XCTAssertEqual(ShortcutDisplay.string("CmdOrCtrl+Option+Shift+Space"), "⌘⌥⇧Space")
    }

    func testDisplaysUnsupportedShortcutAsOriginalText() {
        XCTAssertEqual(ShortcutDisplay.string(" Meta+X "), "Meta+X")
        XCTAssertEqual(ShortcutDisplay.string("CmdOrCtrl+F13"), "CmdOrCtrl+F13")
        XCTAssertEqual(ShortcutDisplay.string(""), "")
    }
}

import AppKit
import ShouldRestCore
import XCTest
@testable import shouldrest

@MainActor
final class PreferencesWindowImagePreviewTests: XCTestCase {
    func testImagePreviewShowsEmptyStateByDefault() throws {
        let controller = PreferencesWindowController(settings: .defaults, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)

        let preview = try XCTUnwrap(view(withIdentifier: "localImagePreview", in: contentView) as? LocalImagePreviewView)
        let label = try XCTUnwrap(view(withIdentifier: "localImagePreviewLabel", in: contentView) as? NSTextField)
        let chooseButton = try XCTUnwrap(button(withTitle: L10n.tr("prefs.chooseFile"), in: contentView))
        let clearButton = try XCTUnwrap(button(withTitle: L10n.tr("prefs.clear"), in: contentView))

        XCTAssertNil(view(withIdentifier: "localImagePathField", in: contentView))
        XCTAssertEqual(preview.toolTip, L10n.tr("prefs.imageDropHelp"))
        XCTAssertEqual(preview.image?.accessibilityDescription, L10n.tr("prefs.imagePreviewEmpty"))
        XCTAssertEqual(label.stringValue, L10n.tr("prefs.imagePreviewEmpty"))
        XCTAssertEqual(label.toolTip, L10n.tr("prefs.imageDropHelp"))
        XCTAssertEqual(label.accessibilityHelp(), L10n.tr("prefs.imageDropHelp"))
        XCTAssertEqual(chooseButton.toolTip, L10n.tr("prefs.chooseBodyImageHelp"))
        XCTAssertEqual(chooseButton.accessibilityLabel(), L10n.tr("prefs.chooseFile"))
        XCTAssertEqual(chooseButton.accessibilityHelp(), L10n.tr("prefs.chooseBodyImageHelp"))
        XCTAssertEqual(chooseButton.image?.accessibilityDescription, chooseButton.title)
        XCTAssertEqual(clearButton.toolTip, L10n.tr("prefs.clearBodyImageDisabledEmptyHelp"))
        XCTAssertEqual(clearButton.accessibilityLabel(), L10n.tr("prefs.clear"))
        XCTAssertEqual(clearButton.accessibilityHelp(), L10n.tr("prefs.clearBodyImageDisabledEmptyHelp"))
        XCTAssertEqual(clearButton.image?.accessibilityDescription, clearButton.title)
        XCTAssertFalse(clearButton.isEnabled)
    }

    func testDisabledImageClearButtonExplainsBodyBreakPrerequisite() throws {
        let imageURL = try makeTemporaryPNG(named: "body-off-preview.png")
        var settings = RestSettings.defaults
        settings.bodyBreak.isEnabled = false
        settings.contentLibrary.localImagePaths = [imageURL.path]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)

        let clearButton = try XCTUnwrap(button(withTitle: L10n.tr("prefs.clear"), in: contentView))
        XCTAssertFalse(clearButton.isEnabled)
        XCTAssertEqual(clearButton.toolTip, L10n.tr("prefs.clearBodyImageDisabledBodyOffHelp"))
        XCTAssertEqual(clearButton.accessibilityHelp(), L10n.tr("prefs.clearBodyImageDisabledBodyOffHelp"))
    }

    func testImagePreviewShowsSelectedImageFileName() throws {
        let imageURL = try makeTemporaryPNG(named: "body-preview.png")
        var settings = RestSettings.defaults
        settings.contentLibrary.localImagePaths = [imageURL.path]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)

        let imageView = try XCTUnwrap(view(withIdentifier: "localImagePreview", in: contentView) as? NSImageView)
        let label = try XCTUnwrap(view(withIdentifier: "localImagePreviewLabel", in: contentView) as? NSTextField)
        let clearButton = try XCTUnwrap(button(withTitle: L10n.tr("prefs.clear"), in: contentView))
        XCTAssertNotNil(imageView.image)
        XCTAssertEqual(imageView.image?.accessibilityDescription, "body-preview.png")
        XCTAssertEqual(label.stringValue, "body-preview.png")
        XCTAssertEqual(label.toolTip, imageURL.path)
        XCTAssertEqual(label.accessibilityHelp(), imageURL.path)
        XCTAssertFalse(visibleTexts(in: contentView).contains(imageURL.path))
        XCTAssertTrue(clearButton.isEnabled)
        XCTAssertEqual(clearButton.toolTip, L10n.tr("prefs.clearBodyImageHelp"))
        XCTAssertEqual(clearButton.accessibilityHelp(), L10n.tr("prefs.clearBodyImageHelp"))
    }

    func testImagePreviewShowsUnavailableStateForMissingImage() throws {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        var settings = RestSettings.defaults
        settings.contentLibrary.localImagePaths = [missingURL.path]
        let controller = PreferencesWindowController(settings: settings, onSave: { _ in })
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)

        let label = try XCTUnwrap(view(withIdentifier: "localImagePreviewLabel", in: contentView) as? NSTextField)
        let imageView = try XCTUnwrap(view(withIdentifier: "localImagePreview", in: contentView) as? NSImageView)
        XCTAssertEqual(label.stringValue, L10n.format("prefs.imagePreviewUnavailable", missingURL.lastPathComponent))
        XCTAssertEqual(label.toolTip, missingURL.path)
        XCTAssertEqual(label.accessibilityHelp(), missingURL.path)
        XCTAssertEqual(imageView.image?.accessibilityDescription, label.stringValue)
    }

    func testDroppingImageIntoPreviewUpdatesPathPreviewAndAutosaves() throws {
        let imageURL = try makeTemporaryPNG(named: "dropped-body-preview.png")
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let preview = try XCTUnwrap(view(withIdentifier: "localImagePreview", in: contentView) as? LocalImagePreviewView)
        let label = try XCTUnwrap(view(withIdentifier: "localImagePreviewLabel", in: contentView) as? NSTextField)
        let clearButton = try XCTUnwrap(button(withTitle: L10n.tr("prefs.clear"), in: contentView))

        XCTAssertTrue(preview.acceptImageDrop(url: imageURL))
        waitUntilSavedSettingsArrive(savedSettings)

        XCTAssertEqual(label.stringValue, "dropped-body-preview.png")
        XCTAssertEqual(label.toolTip, imageURL.standardizedFileURL.path)
        XCTAssertEqual(label.accessibilityHelp(), imageURL.standardizedFileURL.path)
        XCTAssertEqual(preview.image?.accessibilityDescription, "dropped-body-preview.png")
        XCTAssertEqual(savedSettings.value?.contentLibrary.localImagePaths, [imageURL.standardizedFileURL.path])
        XCTAssertEqual(savedSettings.value?.bodyBreak.content, .localImage)
        XCTAssertTrue(clearButton.isEnabled)
    }

    func testClearingSelectedImageReturnsToEmptyPreviewAndAutosaves() throws {
        let imageURL = try makeTemporaryPNG(named: "clearable-body-preview.png")
        var settings = RestSettings.defaults
        settings.contentLibrary.localImagePaths = [imageURL.path]
        settings.bodyBreak.content = .localImage
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: settings) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let label = try XCTUnwrap(view(withIdentifier: "localImagePreviewLabel", in: contentView) as? NSTextField)
        let clearButton = try XCTUnwrap(button(withTitle: L10n.tr("prefs.clear"), in: contentView))

        XCTAssertEqual(label.stringValue, "clearable-body-preview.png")
        XCTAssertTrue(clearButton.isEnabled)

        XCTAssertTrue(sendAction(from: clearButton))

        waitUntilSavedSettingsArrive(savedSettings)
        XCTAssertEqual(label.stringValue, L10n.tr("prefs.imagePreviewEmpty"))
        let imageView = try XCTUnwrap(view(withIdentifier: "localImagePreview", in: contentView) as? NSImageView)
        XCTAssertEqual(imageView.image?.accessibilityDescription, L10n.tr("prefs.imagePreviewEmpty"))
        XCTAssertEqual(label.toolTip, L10n.tr("prefs.imageDropHelp"))
        XCTAssertEqual(label.accessibilityHelp(), L10n.tr("prefs.imageDropHelp"))
        XCTAssertFalse(clearButton.isEnabled)
        XCTAssertEqual(clearButton.toolTip, L10n.tr("prefs.clearBodyImageDisabledEmptyHelp"))
        XCTAssertEqual(clearButton.accessibilityHelp(), L10n.tr("prefs.clearBodyImageDisabledEmptyHelp"))
        XCTAssertEqual(savedSettings.value?.contentLibrary.localImagePaths, [])
        XCTAssertEqual(savedSettings.value?.bodyBreak.content, .richRestIdea)
    }

    func testDroppingNonImageIntoPreviewIsIgnored() throws {
        let textURL = try makeTemporaryTextFile(named: "not-an-image.txt")
        let savedSettings = SavedSettingsBox()
        let controller = PreferencesWindowController(settings: .defaults) { savedSettings.value = $0 }
        let contentView = try XCTUnwrap(controller.window?.contentView)

        try selectAppearanceTab(in: contentView)
        let preview = try XCTUnwrap(view(withIdentifier: "localImagePreview", in: contentView) as? LocalImagePreviewView)
        let label = try XCTUnwrap(view(withIdentifier: "localImagePreviewLabel", in: contentView) as? NSTextField)

        XCTAssertFalse(preview.acceptImageDrop(url: textURL))
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))

        XCTAssertNil(savedSettings.value)
        XCTAssertEqual(label.stringValue, L10n.tr("prefs.imagePreviewEmpty"))
        XCTAssertEqual(label.toolTip, L10n.tr("prefs.imageDropHelp"))
        XCTAssertEqual(label.accessibilityHelp(), L10n.tr("prefs.imageDropHelp"))
    }

    func testImagePreviewReadsImageFileURLFromDragPasteboard() throws {
        let imageURL = try makeTemporaryPNG(named: "pasteboard-body-preview.png")
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([imageURL as NSURL]))

        XCTAssertEqual(
            LocalImagePreviewView.imageFileURL(from: pasteboard)?.path,
            imageURL.standardizedFileURL.path
        )
    }

    private func selectAppearanceTab(in view: NSView) throws {
        let tabView = try XCTUnwrap(firstTabView(in: view))
        tabView.selectTabViewItem(withIdentifier: L10n.tr("prefs.tabAppearance"))
    }

    private func firstTabView(in view: NSView) -> NSTabView? {
        if let tabView = view as? NSTabView {
            return tabView
        }
        for subview in view.subviews {
            if let found = firstTabView(in: subview) {
                return found
            }
        }
        return nil
    }

    private func view(withIdentifier identifier: String, in view: NSView) -> NSView? {
        if view.identifier?.rawValue == identifier {
            return view
        }
        for subview in view.subviews {
            if let found = self.view(withIdentifier: identifier, in: subview) {
                return found
            }
        }
        return nil
    }

    private func button(withTitle title: String, in view: NSView) -> NSButton? {
        if let button = view as? NSButton, button.title == title {
            return button
        }
        for subview in view.subviews {
            if let found = button(withTitle: title, in: subview) {
                return found
            }
        }
        return nil
    }

    private func sendAction(from control: NSControl) -> Bool {
        guard let action = control.action else { return false }
        return NSApplication.shared.sendAction(action, to: control.target, from: control)
    }

    private func waitUntilSavedSettingsArrive(_ settings: SavedSettingsBox) {
        let deadline = Date().addingTimeInterval(2)
        while settings.value == nil && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private func visibleTexts(in view: NSView, ancestorHidden: Bool = false) -> [String] {
        let hidden = ancestorHidden || view.isHidden
        var texts: [String] = []
        if !hidden {
            if let popup = view as? NSPopUpButton, !popup.title.isEmpty {
                texts.append(popup.title)
            } else if let button = view as? NSButton, !button.title.isEmpty {
                texts.append(button.title)
            } else if let textField = view as? NSTextField, !textField.stringValue.isEmpty {
                texts.append(textField.stringValue)
            }
        }
        for subview in view.subviews {
            texts.append(contentsOf: visibleTexts(in: subview, ancestorHidden: hidden))
        }
        return texts
    }

    private func makeTemporaryPNG(named filename: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 8,
            pixelsHigh: 8,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw NSError(domain: "PreferencesWindowImagePreviewTests", code: 1)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.systemGreen.setFill()
        NSRect(x: 0, y: 0, width: 8, height: 8).fill()
        NSGraphicsContext.restoreGraphicsState()

        let url = directory.appendingPathComponent(filename)
        let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try data.write(to: url)
        return url
    }

    private func makeTemporaryTextFile(named filename: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }

        let url = directory.appendingPathComponent(filename)
        try "not an image".write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

private final class SavedSettingsBox {
    var value: RestSettings?
}

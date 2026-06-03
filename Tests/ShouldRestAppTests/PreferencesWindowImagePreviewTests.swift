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

        let label = try XCTUnwrap(view(withIdentifier: "localImagePreviewLabel", in: contentView) as? NSTextField)
        XCTAssertEqual(label.stringValue, L10n.tr("prefs.imagePreviewEmpty"))
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
        XCTAssertNotNil(imageView.image)
        XCTAssertEqual(label.stringValue, "body-preview.png")
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
        XCTAssertEqual(label.stringValue, L10n.format("prefs.imagePreviewUnavailable", missingURL.lastPathComponent))
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
}

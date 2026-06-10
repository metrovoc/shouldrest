import XCTest
@testable import shouldrest

final class SoundOptionTests: XCTestCase {
    func testMapsStretchlySoundNames() {
        XCTAssertEqual(SoundOption(name: "silence"), .silence)
        XCTAssertEqual(SoundOption(name: "crystal-glass"), .crystalGlass)
        XCTAssertEqual(SoundOption(name: "wind-chime"), .windChime)
        XCTAssertEqual(SoundOption(name: "tic-toc"), .ticToc)
        XCTAssertEqual(SoundOption(name: "reverie"), .reverie)
    }

    func testTrimsAndPreservesCustomSystemSoundNames() {
        XCTAssertEqual(SoundOption(name: ""), .silence)
        XCTAssertEqual(SoundOption(name: " Glass "), .custom("Glass"))
        XCTAssertEqual(SoundOption(name: "Submarine").name, "Submarine")
    }

    func testOnlyPlayableBundledSoundsExposeResourceNames() {
        XCTAssertNil(SoundOption.silence.bundledResourceName)
        XCTAssertNil(SoundOption.custom("Glass").bundledResourceName)
        XCTAssertEqual(SoundOption.crystalGlass.bundledResourceName, "crystal-glass")
    }

    func testBundledSoundResourcesAreAvailable() {
        XCTAssertNil(SoundOption.silence.bundledResourceURL)
        XCTAssertNotNil(SoundOption.crystalGlass.bundledResourceURL)
        XCTAssertNotNil(SoundOption.windChime.bundledResourceURL)
        XCTAssertNotNil(SoundOption.ticToc.bundledResourceURL)
        XCTAssertNotNil(SoundOption.reverie.bundledResourceURL)
    }

    func testInstalledSoundLookupUsesAppBundleResources() throws {
        let hostBundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        let resourcesURL = hostBundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
        let soundBundleURL = resourcesURL
            .appendingPathComponent(SoundResourceLocator.resourceBundleName, isDirectory: true)
        try FileManager.default.createDirectory(at: soundBundleURL, withIntermediateDirectories: true)
        let soundURL = soundBundleURL.appendingPathComponent("crystal-glass.wav")
        try Data("sound".utf8).write(to: soundURL)
        let infoPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict><key>CFBundleIdentifier</key><string>dev.shouldrest.testbundle</string></dict></plist>
        """
        try infoPlist.write(
            to: hostBundleURL.appendingPathComponent("Contents/Info.plist"),
            atomically: true,
            encoding: .utf8
        )
        defer { try? FileManager.default.removeItem(at: hostBundleURL) }
        let bundle = try XCTUnwrap(Bundle(url: hostBundleURL))

        let candidates = SoundResourceLocator.candidateURLs(named: "crystal-glass", bundle: bundle)
        let resolved = SoundResourceLocator.url(named: "crystal-glass", bundle: bundle)

        XCTAssertEqual(resolved, soundURL)
        XCTAssertTrue(candidates.contains(soundURL))
    }
}

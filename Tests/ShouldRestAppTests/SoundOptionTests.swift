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
}

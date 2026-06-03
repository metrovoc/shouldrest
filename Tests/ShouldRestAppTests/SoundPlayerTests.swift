import Foundation
import ShouldRestCore
import XCTest
@testable import shouldrest

final class SoundPlayerTests: XCTestCase {
    func testBundledSoundPlaybackDoesNotBlockCaller() {
        let player = SoundPlayer()
        let start = Date()

        player.play(.named("crystal-glass", volume: 1))

        XCTAssertLessThan(Date().timeIntervalSince(start), 0.05)
    }
}

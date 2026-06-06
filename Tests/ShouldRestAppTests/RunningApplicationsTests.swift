import ShouldRestCore
import XCTest
@testable import shouldrest

final class RunningApplicationsTests: XCTestCase {
    func testEmptyAppExclusionTermsDoNotMatchEveryCandidate() {
        let rule = AppExclusionRule(
            id: "empty",
            name: "Empty",
            matchTerms: ["", "   "],
            mode: .pauseWhenMatched,
            appliesTo: [.bodyBreak],
            isEnabled: true
        )

        XCTAssertFalse(RunningApplications.matches(rule: rule, candidates: ["Finder", "com.apple.finder"]))
    }

    func testAppExclusionTermsAreTrimmedBeforeMatching() {
        let rule = AppExclusionRule(
            id: "zoom",
            name: "Zoom",
            matchTerms: ["  zoom  "],
            mode: .pauseWhenMatched,
            appliesTo: [.bodyBreak],
            isEnabled: true
        )

        XCTAssertTrue(RunningApplications.matches(rule: rule, candidates: ["us.zoom.xos"]))
    }
}

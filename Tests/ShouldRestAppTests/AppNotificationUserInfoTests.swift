import XCTest
import ShouldRestCore
@testable import shouldrest

final class AppNotificationUserInfoTests: XCTestCase {
    func testBuildsAndParsesOpenURLPayload() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/releases/latest"))

        let payload = AppNotificationUserInfo.payload(openURL: url)

        XCTAssertEqual(payload[AppNotificationUserInfo.openURL] as? String, url.absoluteString)
        XCTAssertEqual(AppNotificationUserInfo.url(from: payload), url)
    }

    func testReturnsNoURLForEmptyOrInvalidPayload() {
        XCTAssertTrue(AppNotificationUserInfo.payload(openURL: nil).isEmpty)
        XCTAssertNil(AppNotificationUserInfo.url(from: [:]))
        XCTAssertNil(AppNotificationUserInfo.url(from: [AppNotificationUserInfo.openURL: "not a url"]))
    }

    func testRestNotificationCopyNamesRestAndActionInEnglish() {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "en"

        XCTAssertEqual(RestNotificationCopy.title(for: .eyeGate), "Eye Gate")
        XCTAssertEqual(
            RestNotificationCopy.body(for: .eyeGate),
            "Starts soon. Look away when the overlay appears."
        )
        XCTAssertEqual(RestNotificationCopy.title(for: .bodyBreak), "Body Break")
        XCTAssertEqual(
            RestNotificationCopy.body(for: .bodyBreak),
            "Starts soon. Prepare to stand up and move."
        )
        XCTAssertNotEqual(RestNotificationCopy.title(for: .eyeGate), L10n.tr("app.name"))
    }

    func testRestNotificationCopyNamesRestAndActionInSimplifiedChinese() {
        defer { L10n.languageOverride = nil }
        L10n.languageOverride = "zh-Hans"

        XCTAssertEqual(RestNotificationCopy.title(for: .eyeGate), "护眼休息")
        XCTAssertEqual(
            RestNotificationCopy.body(for: .eyeGate),
            "即将开始。覆盖层出现时请看向屏幕外。"
        )
        XCTAssertEqual(RestNotificationCopy.title(for: .bodyBreak), "活动休息")
        XCTAssertEqual(
            RestNotificationCopy.body(for: .bodyBreak),
            "即将开始。准备起身活动。"
        )
        XCTAssertNotEqual(RestNotificationCopy.title(for: .eyeGate), L10n.tr("app.name"))
    }
}

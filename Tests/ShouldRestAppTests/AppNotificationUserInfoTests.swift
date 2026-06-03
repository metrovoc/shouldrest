import XCTest
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
}

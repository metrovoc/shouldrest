import XCTest
@testable import shouldrest

final class LocalizationQualityTests: XCTestCase {
    func testSimplifiedChineseUsesNaturalCoreRestTerms() {
        L10n.languageOverride = "zh-Hans"
        defer { L10n.languageOverride = nil }

        XCTAssertEqual(L10n.tr("kind.eyeGate"), "护眼休息")
        XCTAssertEqual(L10n.tr("kind.bodyBreak"), "活动休息")
        XCTAssertEqual(L10n.tr("prefs.enableEyeGate"), "启用护眼休息")
        XCTAssertEqual(L10n.tr("prefs.enableBodyBreak"), "启用活动休息")
        XCTAssertEqual(L10n.tr("overlay.ready"), "就绪")
    }

    func testSimplifiedChineseVisibleValuesAvoidUntranslatedCoreTerms() throws {
        let values = try simplifiedChineseLocalizedValues().joined(separator: "\n")

        for forbiddenTerm in ["Eye Gate", "Body Break", "Focus /", "Mac-first", "skip/postpone"] {
            XCTAssertFalse(values.contains(forbiddenTerm), "Unexpected untranslated term: \(forbiddenTerm)")
        }
    }

    private func simplifiedChineseLocalizedValues() throws -> [String] {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let packageRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let stringsURL = packageRoot
            .appendingPathComponent("Sources/shouldrest/Resources/zh-Hans.lproj/Localizable.strings")
        let content = try String(contentsOf: stringsURL, encoding: .utf8)
        return content
            .components(separatedBy: .newlines)
            .compactMap { line in
                guard let separatorRange = line.range(of: "=") else { return nil }
                return String(line[separatorRange.upperBound...])
            }
    }
}

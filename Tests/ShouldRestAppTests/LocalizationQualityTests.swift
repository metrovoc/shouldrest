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
        XCTAssertEqual(L10n.tr("prefs.language"), "界面语言")
        XCTAssertEqual(L10n.tr("prefs.endBodyBreak"), "结束当前休息")
        XCTAssertEqual(L10n.tr("overlay.ready"), "就绪")
    }

    func testSimplifiedChineseVisibleValuesAvoidUntranslatedCoreTerms() throws {
        let values = try simplifiedChineseLocalizedValues().joined(separator: "\n")

        for forbiddenTerm in ["Eye Gate", "Body Break", "Focus /", "Mac-first", "skip/postpone"] {
            XCTAssertFalse(values.contains(forbiddenTerm), "Unexpected untranslated term: \(forbiddenTerm)")
        }
    }

    func testSimplifiedChineseEmergencyCopyUsesExitInsteadOfOverride() throws {
        let values = try simplifiedChineseLocalizedValues().joined(separator: "\n")

        XCTAssertTrue(values.contains("紧急退出"))
        XCTAssertFalse(values.contains("紧急覆盖"))
    }

    func testVisiblePreferenceCopyAvoidsImplementationTerms() throws {
        let simplifiedChineseValues = try localizedValues(language: "zh-Hans").joined(separator: "\n")
        let englishValues = try localizedValues(language: "en").joined(separator: "\n")

        XCTAssertFalse(simplifiedChineseValues.contains("语言覆盖"))
        XCTAssertFalse(simplifiedChineseValues.contains("结束当前活动休息"))
        XCTAssertFalse(simplifiedChineseValues.contains("可用等待"))
        XCTAssertFalse(englishValues.contains("Language override"))
        XCTAssertFalse(englishValues.contains("available after"))
        XCTAssertFalse(englishValues.contains("Body start sound"))
        XCTAssertFalse(englishValues.contains("Body finish sound"))
        XCTAssertFalse(englishValues.contains("Pause-until-morning mode"))
        XCTAssertFalse(englishValues.contains("Resume at hour"))
        XCTAssertFalse(simplifiedChineseValues.contains("恢复小时"))

        XCTAssertTrue(englishValues.contains("Body Break start sound"))
        XCTAssertTrue(englishValues.contains("Body Break finish sound"))
        XCTAssertTrue(englishValues.contains("Pause until morning"))
        XCTAssertTrue(englishValues.contains("Resume hour"))
        XCTAssertTrue(simplifiedChineseValues.contains("暂停到早晨方式"))
        XCTAssertTrue(simplifiedChineseValues.contains("恢复时间"))
    }

    func testEmergencyCopyDoesNotAdvertiseConfirmationOrCountdown() {
        defer { L10n.languageOverride = nil }

        L10n.languageOverride = "en"
        XCTAssertEqual(L10n.tr("overlay.emergencyOverride"), "Emergency Exit · Esc")
        XCTAssertTrue(L10n.tr("onboarding.emergencyFeatureBody").contains("configured shortcut"))
        XCTAssertFalse(L10n.tr("onboarding.emergencyFeatureBody").localizedCaseInsensitiveContains("countdown"))
        XCTAssertFalse(L10n.tr("onboarding.emergencyFeatureBody").localizedCaseInsensitiveContains("confirmation"))

        L10n.languageOverride = "zh-Hans"
        XCTAssertEqual(L10n.tr("overlay.emergencyOverride"), "紧急退出 · Esc")
        XCTAssertTrue(L10n.tr("onboarding.emergencyFeatureBody").contains("配置的快捷键"))
        XCTAssertFalse(L10n.tr("onboarding.emergencyFeatureBody").contains("倒计时"))
        XCTAssertFalse(L10n.tr("onboarding.emergencyFeatureBody").contains("确认"))
    }

    func testBlockedActionNotificationsUseUserActionLanguage() {
        defer { L10n.languageOverride = nil }

        L10n.languageOverride = "en"
        XCTAssertEqual(L10n.tr("menu.reset"), "Reset Schedule")
        XCTAssertEqual(L10n.tr("prefs.reset"), "Reset Schedule")
        XCTAssertEqual(L10n.format("notification.quitBlocked", "Eye Gate"), "Finish Eye Gate before quitting.")
        XCTAssertEqual(L10n.format("notification.resetBlocked", "Eye Gate"), "Finish Eye Gate before resetting the schedule.")
        XCTAssertFalse(L10n.tr("notification.quitBlocked").localizedCaseInsensitiveContains("strict"))
        XCTAssertFalse(L10n.tr("notification.resetBlocked").localizedCaseInsensitiveContains("strict"))
        XCTAssertFalse(L10n.tr("notification.resetBlocked").localizedCaseInsensitiveContains("breaks"))

        L10n.languageOverride = "zh-Hans"
        XCTAssertEqual(L10n.tr("menu.reset"), "重置计划")
        XCTAssertEqual(L10n.tr("prefs.reset"), "重置计划")
        XCTAssertEqual(L10n.format("notification.quitBlocked", "护眼休息"), "请先完成护眼休息，再退出。")
        XCTAssertEqual(L10n.format("notification.resetBlocked", "护眼休息"), "请先完成护眼休息，再重置计划。")
        XCTAssertFalse(L10n.tr("notification.quitBlocked").contains("严格"))
        XCTAssertFalse(L10n.tr("notification.resetBlocked").contains("严格"))
    }

    func testRestoreDefaultsConfirmationNamesTheDestructiveAction() {
        defer { L10n.languageOverride = nil }

        L10n.languageOverride = "en"
        XCTAssertEqual(L10n.tr("prefs.restoreDefaultsContinue"), "Restore Defaults")
        XCTAssertTrue(L10n.tr("prefs.restoreDefaultsWarning").contains("current preferences"))
        XCTAssertFalse(L10n.tr("prefs.restoreDefaultsContinue").localizedCaseInsensitiveContains("continue"))

        L10n.languageOverride = "zh-Hans"
        XCTAssertEqual(L10n.tr("prefs.restoreDefaultsContinue"), "恢复默认")
        XCTAssertTrue(L10n.tr("prefs.restoreDefaultsWarning").contains("当前偏好设置"))
        XCTAssertFalse(L10n.tr("prefs.restoreDefaultsContinue").contains("继续"))
    }

    private func simplifiedChineseLocalizedValues() throws -> [String] {
        try localizedValues(language: "zh-Hans")
    }

    private func localizedValues(language: String) throws -> [String] {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let packageRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let stringsURL = packageRoot
            .appendingPathComponent("Sources/shouldrest/Resources/\(language).lproj/Localizable.strings")
        let content = try String(contentsOf: stringsURL, encoding: .utf8)
        return content
            .components(separatedBy: .newlines)
            .compactMap { line in
                guard let separatorRange = line.range(of: "=") else { return nil }
                return String(line[separatorRange.upperBound...])
            }
    }
}

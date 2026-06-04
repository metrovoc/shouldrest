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
        defer { L10n.languageOverride = nil }

        let simplifiedChineseValues = try localizedValues(language: "zh-Hans").joined(separator: "\n")
        let englishValues = try localizedValues(language: "en").joined(separator: "\n")
        let simplifiedChineseLines = simplifiedChineseValues.components(separatedBy: "\n")
        let englishLines = englishValues.components(separatedBy: "\n")

        XCTAssertFalse(simplifiedChineseValues.contains("语言覆盖"))
        XCTAssertFalse(simplifiedChineseValues.contains("结束当前活动休息"))
        XCTAssertFalse(simplifiedChineseValues.contains("可用等待"))
        XCTAssertFalse(simplifiedChineseValues.contains("暂停切换"))
        XCTAssertFalse(simplifiedChineseLines.contains("模式"))
        XCTAssertFalse(simplifiedChineseLines.contains("添加规则"))
        XCTAssertFalse(simplifiedChineseLines.contains("更新规则"))
        XCTAssertFalse(simplifiedChineseLines.contains("当前规则"))
        XCTAssertFalse(simplifiedChineseValues.contains("加入轮换"))
        XCTAssertFalse(simplifiedChineseValues.contains("更新轮换"))
        XCTAssertFalse(simplifiedChineseValues.contains("当前轮换"))
        XCTAssertFalse(simplifiedChineseValues.contains("立即护眼休息"))
        XCTAssertFalse(simplifiedChineseValues.contains("立即活动休息"))
        XCTAssertFalse(englishValues.contains("Language override"))
        XCTAssertFalse(englishLines.contains("Mode"))
        XCTAssertFalse(englishLines.contains("Add Rule"))
        XCTAssertFalse(englishLines.contains("Update Rule"))
        XCTAssertFalse(englishLines.contains("Current rules"))
        XCTAssertFalse(englishValues.contains("available after"))
        XCTAssertFalse(englishValues.contains("Body start sound"))
        XCTAssertFalse(englishValues.contains("Body finish sound"))
        XCTAssertFalse(englishValues.contains("Pause toggle"))
        XCTAssertFalse(englishValues.contains("Add to Rotation"))
        XCTAssertFalse(englishValues.contains("Update Rotation"))
        XCTAssertFalse(englishValues.contains("Current rotation"))
        XCTAssertFalse(englishValues.contains("Take Eye Gate Now"))
        XCTAssertFalse(englishValues.contains("Take Body Break Now"))
        XCTAssertFalse(englishValues.contains("Take Next Scheduled Rest Now"))
        XCTAssertFalse(englishValues.contains("Pause-until-morning mode"))
        XCTAssertFalse(englishValues.contains("Resume at hour"))
        XCTAssertFalse(englishValues.localizedCaseInsensitiveContains("danger indicator"))
        XCTAssertFalse(englishValues.localizedCaseInsensitiveContains("danger score"))
        XCTAssertFalse(englishValues.contains("Eye Gate(s)"))
        XCTAssertFalse(englishValues.contains("%ds remaining"))
        XCTAssertFalse(englishValues.contains("Frequent Eyes"))
        XCTAssertFalse(englishValues.contains("Learn More"))
        XCTAssertFalse(englishValues.contains("Use Selected"))
        XCTAssertFalse(simplifiedChineseValues.contains("恢复小时"))
        XCTAssertFalse(simplifiedChineseValues.contains("危险值"))

        XCTAssertTrue(englishValues.contains("Body Break start sound"))
        XCTAssertTrue(englishValues.contains("Body Break finish sound"))
        XCTAssertTrue(englishValues.contains("Pause until morning"))
        XCTAssertTrue(englishValues.contains("Pause or resume"))
        XCTAssertTrue(englishValues.contains("Resume hour"))
        XCTAssertTrue(englishValues.contains("Show rest pressure indicator"))
        XCTAssertTrue(englishValues.contains("Pressure %d/10"))
        XCTAssertTrue(englishValues.contains("Next Body Break after %d Eye Gates"))
        XCTAssertTrue(englishValues.contains("%@ active, %@ remaining"))
        XCTAssertTrue(englishValues.contains("Balanced"))
        XCTAssertTrue(englishValues.contains("More Eye Rests"))
        XCTAssertTrue(englishValues.contains("About ShouldRest"))
        XCTAssertTrue(englishValues.contains("Start With This Rhythm"))
        XCTAssertTrue(englishValues.contains("Add Idea"))
        XCTAssertTrue(englishValues.contains("Update Idea"))
        XCTAssertTrue(englishValues.contains("Custom ideas"))
        XCTAssertTrue(englishValues.contains("Matched app behavior"))
        XCTAssertTrue(englishValues.contains("Add App Rule"))
        XCTAssertTrue(englishValues.contains("Update App Rule"))
        XCTAssertTrue(englishValues.contains("Saved app rules"))
        XCTAssertTrue(englishValues.contains("Start Eye Gate Now"))
        XCTAssertTrue(englishValues.contains("Start Body Break Now"))
        XCTAssertTrue(englishValues.contains("Start Next Rest Now"))
        XCTAssertTrue(englishValues.contains("Start Eye Gate"))
        XCTAssertTrue(englishValues.contains("Start Body Break"))
        XCTAssertTrue(simplifiedChineseValues.contains("暂停到早晨方式"))
        XCTAssertTrue(simplifiedChineseValues.contains("暂停或恢复"))
        XCTAssertTrue(simplifiedChineseValues.contains("恢复时间"))
        XCTAssertTrue(simplifiedChineseValues.contains("显示休息压力指示器"))
        XCTAssertTrue(simplifiedChineseValues.contains("压力 %d/10"))
        XCTAssertTrue(simplifiedChineseValues.contains("均衡"))
        XCTAssertTrue(simplifiedChineseValues.contains("更多护眼"))
        XCTAssertTrue(simplifiedChineseValues.contains("关于 ShouldRest"))
        XCTAssertTrue(simplifiedChineseValues.contains("使用这个节奏开始"))
        XCTAssertTrue(simplifiedChineseValues.contains("添加提示"))
        XCTAssertTrue(simplifiedChineseValues.contains("更新提示"))
        XCTAssertTrue(simplifiedChineseValues.contains("自定义提示"))
        XCTAssertTrue(simplifiedChineseValues.contains("匹配时行为"))
        XCTAssertTrue(simplifiedChineseValues.contains("添加应用规则"))
        XCTAssertTrue(simplifiedChineseValues.contains("更新应用规则"))
        XCTAssertTrue(simplifiedChineseValues.contains("已保存应用规则"))
        XCTAssertTrue(simplifiedChineseValues.contains("立即开始护眼休息"))
        XCTAssertTrue(simplifiedChineseValues.contains("立即开始活动休息"))

        L10n.languageOverride = "en"
        XCTAssertEqual(L10n.tr("prefs.eyeGateNow"), "Start Eye Gate")
        XCTAssertEqual(L10n.tr("prefs.bodyBreakNow"), "Start Body Break")
        XCTAssertEqual(L10n.tr("prefs.mode"), "Matched app behavior")
        XCTAssertEqual(L10n.tr("prefs.addAppExclusionRule"), "Add App Rule")
        XCTAssertEqual(L10n.tr("prefs.updateAppExclusionRule"), "Update App Rule")
        XCTAssertEqual(L10n.tr("prefs.appExclusionRules"), "Saved app rules")
        XCTAssertNotEqual(L10n.tr("prefs.eyeGateNow"), "Eye Gate now")
        XCTAssertNotEqual(L10n.tr("prefs.bodyBreakNow"), "Body Break now")

        L10n.languageOverride = "zh-Hans"
        XCTAssertEqual(L10n.tr("prefs.eyeGateNow"), "立即开始护眼休息")
        XCTAssertEqual(L10n.tr("prefs.bodyBreakNow"), "立即开始活动休息")
        XCTAssertEqual(L10n.tr("prefs.mode"), "匹配时行为")
        XCTAssertEqual(L10n.tr("prefs.addAppExclusionRule"), "添加应用规则")
        XCTAssertEqual(L10n.tr("prefs.updateAppExclusionRule"), "更新应用规则")
        XCTAssertEqual(L10n.tr("prefs.appExclusionRules"), "已保存应用规则")
        L10n.languageOverride = nil
    }

    func testEmergencyCopyUsesInternalConfirmationWithoutCountdownOrExternalWindow() {
        defer { L10n.languageOverride = nil }

        L10n.languageOverride = "en"
        XCTAssertEqual(L10n.tr("overlay.emergencyOverride"), "Emergency Exit · Esc")
        XCTAssertEqual(L10n.tr("overlay.emergencyOverrideConfirm"), "Click again to exit")
        XCTAssertEqual(L10n.tr("overlay.emergencyOverrideArmed"), "Click again to exit")
        XCTAssertTrue(L10n.tr("overlay.emergencyOverrideHelp").contains("inside the overlay"))
        XCTAssertTrue(L10n.tr("prefs.eyeEmergencyOverrideHelp").contains("inside the overlay"))
        XCTAssertTrue(L10n.tr("prefs.eyeEmergencyOverrideHelp").localizedCaseInsensitiveContains("second click"))
        XCTAssertFalse(L10n.tr("prefs.eyeEmergencyOverrideHelp").localizedCaseInsensitiveContains("hold"))
        XCTAssertFalse(L10n.tr("prefs.eyeEmergencyOverrideHelp").localizedCaseInsensitiveContains("another window"))
        XCTAssertTrue(L10n.tr("onboarding.emergencyFeatureBody").contains("configured shortcut"))
        XCTAssertTrue(L10n.tr("onboarding.emergencyFeatureBody").localizedCaseInsensitiveContains("second click"))
        XCTAssertFalse(L10n.tr("onboarding.emergencyFeatureBody").localizedCaseInsensitiveContains("countdown"))
        XCTAssertTrue(L10n.tr("onboarding.emergencyFeatureBody").localizedCaseInsensitiveContains("without asking you to click another window"))

        L10n.languageOverride = "zh-Hans"
        XCTAssertEqual(L10n.tr("overlay.emergencyOverride"), "紧急退出 · Esc")
        XCTAssertEqual(L10n.tr("overlay.emergencyOverrideConfirm"), "再次点击退出")
        XCTAssertEqual(L10n.tr("overlay.emergencyOverrideArmed"), "再次点击退出")
        XCTAssertTrue(L10n.tr("overlay.emergencyOverrideHelp").contains("覆盖层内"))
        XCTAssertTrue(L10n.tr("prefs.eyeEmergencyOverrideHelp").contains("覆盖层内"))
        XCTAssertTrue(L10n.tr("prefs.eyeEmergencyOverrideHelp").contains("第二次点击"))
        XCTAssertFalse(L10n.tr("prefs.eyeEmergencyOverrideHelp").contains("长按"))
        XCTAssertFalse(L10n.tr("prefs.eyeEmergencyOverrideHelp").contains("另一个窗口"))
        XCTAssertTrue(L10n.tr("onboarding.emergencyFeatureBody").contains("配置的快捷键"))
        XCTAssertTrue(L10n.tr("onboarding.emergencyFeatureBody").contains("第二次点击"))
        XCTAssertFalse(L10n.tr("onboarding.emergencyFeatureBody").contains("倒计时"))
        XCTAssertTrue(L10n.tr("onboarding.emergencyFeatureBody").contains("不再要求你点击另一个窗口"))
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

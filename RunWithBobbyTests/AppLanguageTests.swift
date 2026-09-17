import XCTest
@testable import RunWithBobby

final class AppLanguageTests: XCTestCase {
    override func tearDown() {
        AppLanguage.sync(from: .italian)
        super.tearDown()
    }

    func testExplicitEnglishOverride() {
        AppLanguage.sync(from: .english)
        XCTAssertEqual(AppLanguage.code, "en")
        XCTAssertTrue(AppLanguage.isEnglish)
        XCTAssertEqual(L10n.tr("Chiudi", english: "Close"), "Close")
        XCTAssertEqual(WorkoutType.easy.displayName, "Easy run")
        XCTAssertEqual(SessionStatus.completed.localizedLabel, "done")
    }

    func testExplicitItalianOverride() {
        AppLanguage.sync(from: .italian)
        XCTAssertEqual(AppLanguage.code, "it")
        XCTAssertFalse(AppLanguage.isEnglish)
        XCTAssertEqual(L10n.tr("Chiudi", english: "Close"), "Chiudi")
        XCTAssertEqual(WorkoutType.easy.displayName, "Corsa Facile")
        XCTAssertEqual(SessionStatus.completed.localizedLabel, "fatto")
    }

    func testEnglishChipMessagesMapToIntents() {
        XCTAssertEqual(
            CompactCoachIntent.detect("Create a new training plan for me"),
            .createTrainingPlan
        )
        XCTAssertEqual(
            CompactCoachIntent.detect("Create a nutrition plan based on my training"),
            .createNutritionPlan
        )
        XCTAssertEqual(CompactCoachIntent.detect("How am I?"), .healthStatus)
        XCTAssertEqual(CompactCoachIntent.detect("I'm tired"), .healthStatus)
        XCTAssertEqual(
            CompactCoachIntent.detect("What do I do today? Use the briefing and adherence."),
            .todayBriefing
        )
        XCTAssertEqual(
            CompactCoachIntent.detect("I'd like to optimize my current plan"),
            .proposeOptimize
        )
        XCTAssertEqual(
            CompactCoachIntent.detect("save", hasPendingTrainingPlan: true),
            .savePendingTraining
        )
        XCTAssertNil(CompactCoachIntent.detect("ok", hasPendingTrainingPlan: true))
    }

    func testEnglishReduceVolumeMapsToDecrease() {
        AppLanguage.sync(from: .english)
        XCTAssertEqual(
            CompactCoachIntent.detect("reduce the volume"),
            .proposeOptimize
        )
    }
}

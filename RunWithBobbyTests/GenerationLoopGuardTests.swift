import XCTest
@testable import RunWithBobby

final class GenerationLoopGuardTests: XCTestCase {
    func testScreenshotLoopIsDetected() {
        let fragment = "\"function\":\"new_piano\",\"args\":{\"name\":\"new_piano\","
        let dump = String(repeating: fragment, count: 6)

        XCTAssertTrue(GenerationLoopGuard.looksLikeLeakedToolJSON(dump))
        XCTAssertTrue(GenerationLoopGuard.isRepeating(dump))
        XCTAssertTrue(GenerationLoopGuard.shouldDiscardAsModelOutput(dump))
    }

    func testEnglishSchemaLoopIsDetected() {
        let sentence = "The function name is also specified using the name keyword, followed by the type of the argument and the name of the argument. "
        let dump = String(repeating: sentence, count: 4)

        XCTAssertTrue(GenerationLoopGuard.looksLikeEnglishSchemaDump(dump))
        XCTAssertTrue(GenerationLoopGuard.isRepeating(dump))
        XCTAssertTrue(GenerationLoopGuard.shouldHideFromStream(dump))
        XCTAssertTrue(GenerationLoopGuard.shouldDiscardAsModelOutput(dump))
    }

    func testItalianCoachTextIsKept() {
        let text = "Oggi fai una corsa facile di 6 km e poi stretching. Domani riposo completo."

        XCTAssertFalse(GenerationLoopGuard.looksLikeLeakedToolJSON(text))
        XCTAssertFalse(GenerationLoopGuard.looksLikeEnglishSchemaDump(text))
        XCTAssertFalse(GenerationLoopGuard.isRepeating(text))
        XCTAssertFalse(GenerationLoopGuard.shouldHideFromStream(text))
        XCTAssertFalse(GenerationLoopGuard.shouldDiscardAsModelOutput(text))
    }

    func testEmptyOutputIsDiscarded() {
        XCTAssertTrue(GenerationLoopGuard.shouldDiscardAsModelOutput("   \n"))
    }

    func testOnlyCompactQwenDisablesNativeTools() {
        let compact = LocalModelCatalog.find("mlx-community/Qwen2.5-0.5B-Instruct-4bit")
        XCTAssertEqual(compact?.supportsNativeToolCalling, false)

        let others = LocalModelCatalog.all.filter { $0.id != compact?.id }
        XCTAssertFalse(others.isEmpty)
        XCTAssertTrue(others.allSatisfy(\.supportsNativeToolCalling))
    }

    func testChipMessagesMapToCreateIntents() {
        XCTAssertEqual(
            CompactCoachIntent.detect("Crea un nuovo piano di allenamento per me"),
            .createTrainingPlan
        )
        XCTAssertEqual(
            CompactCoachIntent.detect("Crea un piano alimentare basato sul mio allenamento"),
            .createNutritionPlan
        )
        XCTAssertNil(CompactCoachIntent.detect("Come sto?"))
        XCTAssertNil(CompactCoachIntent.detect("ok"))
        XCTAssertEqual(
            CompactCoachIntent.detect("ok", hasPendingTrainingPlan: true),
            .savePendingTraining
        )
    }
}

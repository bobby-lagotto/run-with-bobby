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
        XCTAssertFalse(GenerationLoopGuard.looksLikeLegalPrivacyRefusal(text))
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
        XCTAssertNil(CompactCoachIntent.detect("ok"))
        XCTAssertEqual(
            CompactCoachIntent.detect("ok", hasPendingTrainingPlan: true),
            .savePendingTraining
        )
    }

    func testScreenshotLegalRefusalIsDiscarded() {
        let text = """
        In legge, in base il diritto alla privacy e la libertà di informazioni. In questo caso, non posso fornire un'opzione specifica per rispondere a questa domanda perché è una questione relativa alle regole legali e alle normative che governano le attività online come quella che stiamo tenendo.
        """

        XCTAssertTrue(GenerationLoopGuard.looksLikeLegalPrivacyRefusal(text))
        XCTAssertTrue(GenerationLoopGuard.shouldHideFromStream(text))
        XCTAssertTrue(GenerationLoopGuard.shouldDiscardAsModelOutput(text))
    }

    func testHealthChipMapsToHealthStatus() {
        XCTAssertEqual(CompactCoachIntent.detect("Come sto?"), .healthStatus)
        XCTAssertEqual(CompactCoachIntent.detect("Ciao come sto ?"), .healthStatus)
        XCTAssertEqual(
            CompactCoachIntent.detect("In base ai dati su salute mi dici come sto?"),
            .healthStatus
        )
        XCTAssertEqual(
            CompactCoachIntent.detect("Analizza i miei dati di salute e dimmi come sto. Sono affaticato? Fammi un riassunto completo."),
            .healthStatus
        )
        XCTAssertEqual(
            CompactCoachIntent.detect("Cosa faccio oggi? Usa il briefing e l'aderenza."),
            .todayBriefing
        )
        XCTAssertTrue(
            CompactCoachIntent.healthStatus.shouldGroundOnDevice(supportsNativeToolCalling: true)
        )
        XCTAssertFalse(
            CompactCoachIntent.createTrainingPlan.shouldGroundOnDevice(supportsNativeToolCalling: true)
        )
        XCTAssertTrue(
            CompactCoachIntent.createTrainingPlan.shouldGroundOnDevice(supportsNativeToolCalling: false)
        )
    }

    func testQwen15BDoesNotRotateKVAt2048() {
        let qwen = LocalModelCatalog.generationConfig(for: "mlx-community/Qwen2.5-1.5B-Instruct-4bit")
        XCTAssertNil(qwen.maxKVSize)
        XCTAssertEqual(qwen.maxTokens, 768)
        XCTAssertNil(qwen.kvBits)

        let compact = LocalModelCatalog.generationConfig(for: "mlx-community/Qwen2.5-0.5B-Instruct-4bit")
        XCTAssertNil(compact.maxKVSize)
        XCTAssertEqual(compact.maxTokens, 384)

        let flagship = LocalModelCatalog.generationConfig(for: "prism-ml/Bonsai-27B-mlx-1bit")
        XCTAssertEqual(flagship.maxKVSize, 4096)
        XCTAssertEqual(flagship.kvBits, 4)
    }

    func testHealthStatusFormatterCitesOnlyPresentNumbers() {
        let json = """
        {
          "periodo": "ultimi 7 giorni",
          "sonno_media_ore": 6.2,
          "variabilita_cardiaca_hrv_ms": 38,
          "frequenza_cardiaca_riposo_bpm": 70
        }
        """
        let briefing = """
        { "briefing": "Oggi tieni facile.", "raccomandazione": "easy" }
        """
        let text = CompactCoachPlanner.formatHealthStatus(healthJSON: json, briefingJSON: briefing)

        XCTAssertTrue(text.contains("6.2"))
        XCTAssertTrue(text.contains("38"))
        XCTAssertTrue(text.contains("70"))
        XCTAssertTrue(text.contains("Oggi tieni facile"))
        XCTAssertFalse(text.contains("diritto alla privacy"))
        XCTAssertFalse(GenerationLoopGuard.looksLikeLegalPrivacyRefusal(text))
    }

    func testHealthStatusFormatterDoesNotInventMissingData() {
        let json = """
        { "periodo": "ultimi 7 giorni" }
        """
        let text = CompactCoachPlanner.formatHealthStatus(healthJSON: json, briefingJSON: nil)

        XCTAssertTrue(text.contains("non li invento") || text.contains("non ci sono"))
        XCTAssertFalse(text.contains("HRV:"))
    }

    func testHistoryDropsDuplicatedCurrentUserMessage() {
        let history = [
            ChatMessage(content: "Ciao", isFromUser: false),
            ChatMessage(content: "Come sto?", isFromUser: true)
        ]
        let window = CompactCoachPlanner.messagesForPrompt(
            history,
            currentUserMessage: "Come sto?",
            limit: 8
        )
        XCTAssertEqual(window.count, 1)
        XCTAssertEqual(window.first?.content, "Ciao")
        XCTAssertFalse(window.contains(where: { $0.isFromUser && $0.content == "Come sto?" }))
    }
}

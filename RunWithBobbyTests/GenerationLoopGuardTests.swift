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
        XCTAssertNil(CompactCoachIntent.detect("ok", hasPendingTrainingPlan: true))
        XCTAssertEqual(
            CompactCoachIntent.detect("salva", hasPendingTrainingPlan: true),
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
        XCTAssertTrue(CompactCoachIntent.healthStatus.shouldGroundDeterministically())
        XCTAssertTrue(CompactCoachIntent.createTrainingPlan.shouldGroundDeterministically())
        XCTAssertEqual(CompactCoachIntent.detect("Come mi sento?"), .healthStatus)
        XCTAssertEqual(CompactCoachIntent.detect("Sono stanco?"), .healthStatus)
        XCTAssertEqual(CompactCoachIntent.detect("sono stanco"), .healthStatus)
        XCTAssertEqual(CompactCoachIntent.detect("I'm tired"), .healthStatus)
        XCTAssertEqual(CompactCoachIntent.detect("ho troppa fatica"), .healthStatus)
        XCTAssertEqual(CompactCoachIntent.detect("Cosa mi manca?"), .adherence)
        XCTAssertEqual(CompactCoachIntent.detect("Vorrei ottimizzare il mio piano attuale"), .proposeOptimize)
    }

    func testUnverifiedKilometersAreDiscarded() {
        let text = "Oggi corri 12 km a ritmo gara."
        XCTAssertTrue(GenerationLoopGuard.containsUnverifiedNumericClaims(text, allowed: .empty))
        XCTAssertTrue(GenerationLoopGuard.shouldDiscardAsModelOutput(text, allowedFacts: .empty))

        var facts = CoachFactBag.empty
        facts.kilometers.insert(12)
        XCTAssertFalse(GenerationLoopGuard.containsUnverifiedNumericClaims(text, allowed: facts))
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

    func testHealthStatusCopyKeepsSpacesWithoutMarkdown() {
        AppLanguage.sync(from: .italian)
        let json = """
        {
          "periodo": "ultimi 7 giorni",
          "sonno_media_ore": 5.9,
          "variabilita_cardiaca_hrv_ms": 63,
          "frequenza_cardiaca_riposo_bpm": 57
        }
        """
        let text = CompactCoachPlanner.formatHealthStatus(healthJSON: json, briefingJSON: nil)

        XCTAssertTrue(text.contains("Ecco come ti vedo dai dati"))
        XCTAssertFalse(ChatMarkdown.containsInlineMarkup(text))
        XCTAssertGreaterThan(ChatMarkdown.spaceCount(text), 10)

        let attributed = ChatMarkdown.attributedString(from: text)
        XCTAssertEqual(
            ChatMarkdown.spaceCount(String(attributed.characters)),
            ChatMarkdown.spaceCount(text)
        )
    }

    func testFallbackCopyKeepsSpacesWithoutMarkdown() {
        let text = """
        Non ho completato la risposta col modello. Ti do un consiglio conservativo sul dispositivo.

        Senza dati Health live in questa modalità, usa una regola conservativa: se sonno scarso, FC a riposo più alta del solito o gambe pesanti, trasforma la seduta in facile.
        """
        XCTAssertFalse(ChatMarkdown.containsInlineMarkup(text))
        let attributed = ChatMarkdown.attributedString(from: text)
        XCTAssertEqual(
            ChatMarkdown.spaceCount(String(attributed.characters)),
            ChatMarkdown.spaceCount(text)
        )
    }

    func testInlineMarkdownStillParsesBold() {
        let text = "Oggi fai **facile** e poi riposo completo."
        XCTAssertTrue(ChatMarkdown.containsInlineMarkup(text))
        let attributed = ChatMarkdown.attributedString(from: text)
        let rendered = String(attributed.characters)
        XCTAssertTrue(rendered.contains("facile"))
        XCTAssertGreaterThanOrEqual(
            ChatMarkdown.spaceCount(rendered) * 10,
            ChatMarkdown.spaceCount(text) * 8
        )
    }

    func testHealthCitationsHaveTappableDOILinks() {
        XCTAssertEqual(HealthCitations.all.count, 4)
        XCTAssertTrue(HealthCitations.all.allSatisfy { $0.url.scheme == "https" })
        XCTAssertTrue(HealthCitations.all.allSatisfy { $0.url.host?.contains("doi.org") == true })
    }

    func testHealthStatusIncludesCitationFooter() {
        AppLanguage.sync(from: .italian)
        let json = """
        {
          "periodo": "ultimi 7 giorni",
          "sonno_media_ore": 5.9,
          "variabilita_cardiaca_hrv_ms": 63
        }
        """
        let text = CompactCoachPlanner.formatHealthStatus(healthJSON: json, briefingJSON: nil)
        XCTAssertTrue(text.contains("Ecco come ti vedo dai dati"))
        XCTAssertTrue(text.contains(HealthCitations.chatFooter))
        XCTAssertTrue(text.contains("ISSN"))
    }

    func testEnglishNutritionPlanIncludesCitationFooter() {
        AppLanguage.sync(from: .english)
        let json = """
        {
          "piano_alimentare": [
            {
              "giorno": "LUNEDI",
              "intensita": "leggero",
              "proteine_g": 112,
              "carboidrati_g": 210,
              "verdure_frutta_g": 360
            }
          ]
        }
        """
        let text = CompactCoachPlanner.formatNutritionPlan(from: json)
        XCTAssertNotNil(text)
        XCTAssertTrue(text?.contains("Draft nutrition plan") == true)
        XCTAssertTrue(text?.contains("protein 112 g") == true)
        XCTAssertTrue(text?.contains(HealthCitations.chatFooter) == true)
        XCTAssertTrue(text?.contains("not medical advice") == true)
        XCTAssertFalse(text?.contains("Indicazione food-first") == true)
        AppLanguage.sync(from: .italian)
    }
}

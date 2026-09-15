import XCTest
@testable import RunWithBobby

final class ToolRouterIntegrationTests: XCTestCase {
    func testCalculateThenSaveTrainingPlan() async throws {
        let router = ToolRouter()
        let manager = HabitFixtures.isolatedManager()
        var profile = RunnerProfile()
        profile.weeklyKilometers = 30
        profile.workoutsPerWeek = 4
        profile.primaryGoal = .speed
        profile.experience = .intermediate

        let calculate = await router.execute(
            ToolCall(name: "calculate_training_plan", arguments: [
                "weekly_km": .number(30),
                "workouts_per_week": .int(4),
                "goal": .string("speed"),
                "experience": .string("intermediate")
            ]),
            userProfile: profile,
            planManager: manager
        )

        XCTAssertTrue(calculate.content.contains("piano_settimanale"), calculate.content)
        XCTAssertNil(manager.currentActivePlan)

        let save = await router.execute(
            ToolCall(name: "save_training_plan", arguments: ["title": .string("Piano Test")]),
            userProfile: profile,
            planManager: manager,
            userConfirmed: true
        )

        XCTAssertTrue(save.content.contains("salvato"), save.content)
        XCTAssertEqual(manager.currentActivePlan?.title, "Piano Test")
        XCTAssertEqual(manager.currentActivePlan?.weeklyPlan.count, 7)
        XCTAssertFalse(manager.savedPlans.isEmpty)
    }

    func testCompactPlannerCreatesUnsavedTrainingPlanFromChip() async {
        let router = ToolRouter()
        let planner = CompactCoachPlanner(toolRouter: router)
        let manager = HabitFixtures.isolatedManager()
        var profile = RunnerProfile()
        profile.weeklyKilometers = 30
        profile.workoutsPerWeek = 4
        profile.primaryGoal = .speed
        profile.experience = .intermediate

        let text = await planner.respond(
            to: "Crea un nuovo piano di allenamento per me",
            userProfile: profile,
            planManager: manager,
            nutritionManager: nil
        )

        XCTAssertNotNil(text)
        XCTAssertTrue(text?.contains("LUNEDÌ") == true || text?.contains("MARTEDÌ") == true, text ?? "")
        XCTAssertTrue(text?.contains("non salvata") == true, text ?? "")
        XCTAssertTrue(text?.contains("Confermi") == true, text ?? "")
        XCTAssertFalse(text?.contains("Modalità gratuita") == true, text ?? "")
        XCTAssertNil(manager.currentActivePlan)
        XCTAssertTrue(router.hasPendingTrainingPlan)

        let saved = await planner.respond(
            to: "salva",
            userProfile: profile,
            planManager: manager,
            nutritionManager: nil
        )

        XCTAssertTrue(saved?.contains("salvato") == true, saved ?? "")
        XCTAssertNotNil(manager.currentActivePlan)
        XCTAssertEqual(manager.currentActivePlan?.weeklyPlan.count, 7)
        XCTAssertFalse(router.hasPendingTrainingPlan)
    }

    func testHealthQuestionUsesDeterministicCoachNotLegalRefusal() async {
        let router = ToolRouter()
        let planner = CompactCoachPlanner(toolRouter: router)
        let manager = HabitFixtures.isolatedManager()
        var profile = RunnerProfile()
        profile.weeklyKilometers = 20

        let text = await planner.respond(
            to: "In base ai dati su salute mi dici come sto?",
            userProfile: profile,
            planManager: manager,
            nutritionManager: nil,
            healthManager: nil
        )

        XCTAssertNotNil(text)
        XCTAssertFalse(text?.contains("diritto alla privacy") == true, text ?? "")
        XCTAssertFalse(text?.contains("Modalità gratuita") == true, text ?? "")
        XCTAssertTrue(
            text?.contains("HealthKit") == true || text?.contains("Salute") == true,
            text ?? ""
        )
    }

    func testSaveInSameTurnAsCalculateIsRejected() async {
        let router = ToolRouter()
        let manager = HabitFixtures.isolatedManager()
        var profile = RunnerProfile()
        profile.weeklyKilometers = 30
        profile.workoutsPerWeek = 4

        _ = await router.execute(
            ToolCall(name: "calculate_training_plan", arguments: [
                "weekly_km": .number(30),
                "workouts_per_week": .int(4),
                "goal": .string("speed"),
                "experience": .string("intermediate")
            ]),
            userProfile: profile,
            planManager: manager
        )

        let save = await router.execute(
            ToolCall(name: "save_training_plan", arguments: ["title": .string("Too Soon")]),
            userProfile: profile,
            planManager: manager,
            userConfirmed: true,
            siblingToolNames: ["calculate_training_plan", "save_training_plan"]
        )

        XCTAssertTrue(save.content.contains("stesso turno") || save.content.contains("errore"), save.content)
        XCTAssertNil(manager.currentActivePlan)
        XCTAssertTrue(router.hasPendingTrainingPlan)
    }

    func testOptimizeWithoutConfirmationStaysPending() async {
        let router = ToolRouter()
        let manager = HabitFixtures.isolatedManager()
        var profile = RunnerProfile()
        profile.weeklyKilometers = 30
        profile.workoutsPerWeek = 4

        _ = await router.execute(
            ToolCall(name: "calculate_training_plan", arguments: [
                "weekly_km": .number(30),
                "workouts_per_week": .int(4),
                "goal": .string("speed"),
                "experience": .string("intermediate")
            ]),
            userProfile: profile,
            planManager: manager
        )
        _ = await router.execute(
            ToolCall(name: "save_training_plan", arguments: ["title": .string("Base")]),
            userProfile: profile,
            planManager: manager,
            userConfirmed: true
        )
        let originalTitle = manager.currentActivePlan?.title

        let proposal = await router.execute(
            ToolCall(name: "optimize_plan", arguments: [
                "modification": .string("increase_volume"),
                "percentage": .number(10)
            ]),
            userProfile: profile,
            planManager: manager,
            userConfirmed: false
        )

        XCTAssertTrue(proposal.content.contains("proposta") || proposal.content.contains("piano_settimanale"), proposal.content)
        XCTAssertEqual(manager.currentActivePlan?.title, originalTitle)
        XCTAssertTrue(router.hasPendingOptimization)

        let planner = CompactCoachPlanner(toolRouter: router)
        let applied = await planner.respond(
            to: "confermo",
            userProfile: profile,
            planManager: manager,
            nutritionManager: nil
        )
        XCTAssertTrue(applied?.contains("applicata") == true || applied?.contains("ottimizz") == true, applied ?? "")
        XCTAssertNotEqual(manager.currentActivePlan?.title, originalTitle)
        XCTAssertFalse(router.hasPendingOptimization)
    }

    func testFeelingAndMissingAreGrounded() async {
        let router = ToolRouter()
        let planner = CompactCoachPlanner(toolRouter: router)
        let manager = HabitFixtures.isolatedManager()
        var profile = RunnerProfile()
        profile.weeklyKilometers = 20

        let feeling = await planner.respond(
            to: "Come mi sento?",
            userProfile: profile,
            planManager: manager,
            nutritionManager: nil,
            healthManager: nil
        )
        XCTAssertNotNil(feeling)
        XCTAssertFalse(feeling?.contains("diritto alla privacy") == true, feeling ?? "")

        let missing = await planner.respond(
            to: "Cosa mi manca?",
            userProfile: profile,
            planManager: manager,
            nutritionManager: nil
        )
        XCTAssertNotNil(missing)
        XCTAssertTrue(missing?.contains("Nessun piano") == true || missing?.contains("Aderenza") == true, missing ?? "")
    }
}

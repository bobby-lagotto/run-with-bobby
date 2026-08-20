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
            planManager: manager
        )

        XCTAssertTrue(save.content.contains("salvato"), save.content)
        XCTAssertEqual(manager.currentActivePlan?.title, "Piano Test")
        XCTAssertEqual(manager.currentActivePlan?.weeklyPlan.count, 7)
        XCTAssertFalse(manager.savedPlans.isEmpty)
    }
}

import XCTest
@testable import RunWithBobby

final class AdherenceIntegrationTests: XCTestCase {
    func testWednesdayPartialFromHealthWorkout() async throws {
        let router = ToolRouter()
        let manager = HabitFixtures.isolatedManager()
        let plan = HabitFixtures.plan(wednesdayKm: 8)
        manager.savePlan(plan)
        manager.setActivePlan(plan)

        let workout = LoggedWorkout(
            startDate: HabitFixtures.wednesday,
            distanceKm: 7.4,
            durationMinutes: 42,
            activityType: "Corsa"
        )

        let result = await router.execute(
            ToolCall(name: "get_adherence", arguments: [:]),
            userProfile: RunnerProfile(),
            planManager: manager,
            loggedWorkouts: [workout]
        )

        let wednesday = manager.currentActivePlan.flatMap { AdherenceEngine.day(in: $0, on: HabitFixtures.wednesday, calendar: HabitFixtures.calendar) }
        XCTAssertEqual(wednesday?.sessionStatus, .partial)
        XCTAssertEqual(wednesday?.loggedDistance, 7.4)
        XCTAssertTrue(result.content.contains("percentuale"), result.content)
        XCTAssertTrue(result.content.contains("contesto_coach"), result.content)
    }

    func testNoWorkoutStaysPlanned() async throws {
        let router = ToolRouter()
        let manager = HabitFixtures.isolatedManager()
        manager.savePlan(HabitFixtures.plan(wednesdayKm: 8))
        manager.setActivePlan(manager.savedPlans[0])

        _ = await router.execute(
            ToolCall(name: "get_adherence", arguments: [:]),
            userProfile: RunnerProfile(),
            planManager: manager,
            loggedWorkouts: []
        )

        let wednesday = manager.currentActivePlan.flatMap { AdherenceEngine.day(in: $0, on: HabitFixtures.wednesday, calendar: HabitFixtures.calendar) }
        XCTAssertEqual(wednesday?.sessionStatus, .planned)
    }

    func testLegacyPlanJSONDecodesAsPlanned() throws {
        let day = DayTraining(dayOfWeek: "MERCOLEDÌ", workoutType: .easy, description: "x", distance: 8, estimatedDuration: 40)
        var data = try JSONEncoder().encode(day)
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        object.removeValue(forKey: "sessionStatus")
        object.removeValue(forKey: "loggedDistance")
        data = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(DayTraining.self, from: data)
        XCTAssertEqual(decoded.sessionStatus, .planned)
    }
}

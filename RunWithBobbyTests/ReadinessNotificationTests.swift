import XCTest
@testable import RunWithBobby

final class ReadinessNotificationTests: XCTestCase {
    func testPoorSleepAndLowHRVOnQualityDayIsRest() async throws {
        let router = ToolRouter()
        let manager = HabitFixtures.isolatedManager()
        var plan = HabitFixtures.plan()
        if let index = plan.weeklyPlan.firstIndex(where: { $0.dayOfWeek == "MERCOLEDÌ" }) {
            plan.weeklyPlan[index].workoutType = .intervals
        }
        manager.savePlan(plan)
        manager.setActivePlan(plan)

        let signals = HealthSignals(sleepHours: 5.0, hrvMs: 30, restingHeartRate: 72)
        let result = await router.execute(
            ToolCall(name: "get_today_briefing", arguments: [:]),
            userProfile: RunnerProfile(),
            planManager: manager,
            healthSignals: signals,
            referenceDate: HabitFixtures.wednesday
        )

        XCTAssertTrue(result.content.contains("\"raccomandazione\":\"rest\"") || result.content.contains("rest"), result.content)
        XCTAssertTrue(result.content.contains("briefing"), result.content)
    }

    func testGoodSignalsOnQualityDayIsGo() async throws {
        let today = DayTraining(dayOfWeek: "MERCOLEDÌ", workoutType: .tempo, description: "Tempo", distance: 8, estimatedDuration: 45)
        let recommendation = ReadinessEngine.recommend(
            signals: HealthSignals(sleepHours: 8.0, hrvMs: 70, restingHeartRate: 52),
            today: today,
            hasActivePlan: true
        )
        XCTAssertEqual(recommendation, .go)
    }

    func testNotificationDatesAreInTheFutureAndSkipRest() {
        let now = HabitFixtures.date(year: 2026, month: 8, day: 18, hour: 6)
        let notifications = NotificationPlanning.workoutReminders(
            for: HabitFixtures.plan(),
            from: now,
            calendar: HabitFixtures.calendar,
            hour: 7
        )

        XCTAssertFalse(notifications.contains { $0.body.contains("Riposo") })
        XCTAssertTrue(notifications.allSatisfy { $0.fireDate > now })
        XCTAssertTrue(notifications.contains { $0.body.contains("Mercoledì") || $0.id.contains("MERCOLED") })
    }
}

import XCTest
@testable import RunWithBobby

final class RunSessionLogicTests: XCTestCase {
    func testTenPointOneIsCompleted() {
        let comparison = RunSessionLogic.finish(plannedKm: 10, loggedKm: 10.1, durationMinutes: 50)
        XCTAssertEqual(comparison.status, .completed)
        XCTAssertFalse(comparison.shouldSuggestOptimize)
    }

    func testFourKmSuggestsOptimizeWithoutApplying() {
        let comparison = RunSessionLogic.finish(plannedKm: 10, loggedKm: 4, durationMinutes: 25)
        XCTAssertEqual(comparison.status, .partial)
        XCTAssertTrue(comparison.shouldSuggestOptimize)

        let plan = HabitFixtures.plan(wednesdayKm: 10)
        let updated = RunSessionLogic.apply(
            to: plan,
            dayOfWeek: "MERCOLEDÌ",
            comparison: comparison,
            durationMinutes: 25
        )
        XCTAssertEqual(AdherenceEngine.day(in: updated, on: HabitFixtures.wednesday, calendar: HabitFixtures.calendar)?.sessionStatus, .partial)
        XCTAssertEqual(updated.title, plan.title)
        XCTAssertEqual(updated.weeklyPlan.first { $0.dayOfWeek == "SABATO" }?.distance, plan.weeklyPlan.first { $0.dayOfWeek == "SABATO" }?.distance)
    }
}

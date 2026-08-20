import XCTest
@testable import RunWithBobby

final class TodayPresenterTests: XCTestCase {
    func testMissingPlan() {
        let state = TodayPresenter.make(plan: nil, now: HabitFixtures.wednesday, calendar: HabitFixtures.calendar)
        XCTAssertFalse(state.hasActivePlan)
        XCTAssertTrue(state.isRestDay)
        XCTAssertFalse(state.canLog)
        XCTAssertTrue(state.briefingLine.contains("Nessun piano"))
    }

    func testRestDay() {
        let monday = HabitFixtures.date(year: 2026, month: 8, day: 17)
        let state = TodayPresenter.make(
            plan: HabitFixtures.plan(),
            now: monday,
            calendar: HabitFixtures.calendar
        )
        XCTAssertTrue(state.isRestDay)
        XCTAssertEqual(state.recommendation, .rest)
        XCTAssertFalse(state.canLog)
    }

    func testWorkoutDayUsesAdherence() {
        var plan = HabitFixtures.plan(wednesdayKm: 8)
        plan = AdherenceEngine.log(plan: plan, dayOfWeek: "MERCOLEDÌ", status: .partial, loggedDistance: 7.4, loggedDurationMinutes: 40)
        let state = TodayPresenter.make(plan: plan, now: HabitFixtures.wednesday, calendar: HabitFixtures.calendar)
        XCTAssertTrue(state.hasActivePlan)
        XCTAssertFalse(state.isRestDay)
        XCTAssertEqual(state.sessionStatus, .partial)
        XCTAssertGreaterThan(state.weeklyAdherencePercent, 0)
        XCTAssertTrue(state.canLog)
    }
}

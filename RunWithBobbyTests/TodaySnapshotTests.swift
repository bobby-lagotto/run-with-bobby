import XCTest
@testable import RunWithBobby

final class TodaySnapshotTests: XCTestCase {
    func testSnapshotHasNoHealthPayload() throws {
        let state = TodayPresenter.make(
            plan: HabitFixtures.plan(),
            signals: HealthSignals(sleepHours: 5, hrvMs: 20, restingHeartRate: 80),
            now: HabitFixtures.wednesday,
            calendar: HabitFixtures.calendar
        )
        let snapshot = TodaySnapshot.from(state)
        let data = try TodaySnapshot.encode(snapshot)
        let json = String(data: data, encoding: .utf8) ?? ""

        XCTAssertFalse(json.contains("hrv"))
        XCTAssertFalse(json.contains("sleep"))
        XCTAssertFalse(json.contains("heart"))
        XCTAssertTrue(json.contains("briefingLine"))
        XCTAssertTrue(json.contains("workoutType"))

        let decoded = try TodaySnapshot.decode(from: data)
        XCTAssertEqual(decoded, snapshot)
    }

    func testWatchAndPhoneShareTheSameCodec() throws {
        let snapshot = TodaySnapshot(
            dayTitle: "Mercoledì",
            workoutType: "Corsa Facile",
            plannedKm: 8,
            sessionStatus: .partial,
            recommendation: .easy,
            briefingLine: "Tieni facile",
            weeklyAdherencePercent: 25,
            isRestDay: false,
            hasActivePlan: true
        )
        let data = try TodaySnapshot.encode(snapshot)
        XCTAssertEqual(try TodaySnapshot.decode(from: data), snapshot)
    }

    func testWriteToCustomDirectoryRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let snapshot = TodaySnapshot.empty
        try TodaySnapshotStore.write(snapshot, to: directory)
        let url = directory.appendingPathComponent(TodaySnapshotStore.filename)
        let decoded = try TodaySnapshot.decode(from: Data(contentsOf: url))
        XCTAssertEqual(decoded, snapshot)
    }
}

import Foundation
@testable import RunWithBobby

enum HabitFixtures {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome") ?? .current
        calendar.locale = Locale(identifier: "it_IT")
        calendar.firstWeekday = 2
        return calendar
    }

    static func date(year: Int, month: Int, day: Int, hour: Int = 8, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Wednesday 19 August 2026
    static let wednesday = date(year: 2026, month: 8, day: 19, hour: 8)

    static func weeklyPlan(wednesdayKm: Double, status: SessionStatus = .planned) -> [DayTraining] {
        [
            DayTraining(dayOfWeek: "LUNEDÌ", workoutType: .rest, description: "Riposo", distance: 0, estimatedDuration: 0),
            DayTraining(dayOfWeek: "MARTEDÌ", workoutType: .easy, description: "Facile", distance: 6, estimatedDuration: 40),
            DayTraining(dayOfWeek: "MERCOLEDÌ", workoutType: .easy, description: "Mercoledì", distance: wednesdayKm, estimatedDuration: 50, sessionStatus: status),
            DayTraining(dayOfWeek: "GIOVEDÌ", workoutType: .tempo, description: "Tempo", distance: 8, estimatedDuration: 45),
            DayTraining(dayOfWeek: "VENERDÌ", workoutType: .rest, description: "Riposo", distance: 0, estimatedDuration: 0),
            DayTraining(dayOfWeek: "SABATO", workoutType: .long, description: "Lungo", distance: 14, estimatedDuration: 90),
            DayTraining(dayOfWeek: "DOMENICA", workoutType: .easy, description: "Facile", distance: 7, estimatedDuration: 45)
        ]
    }

    static func plan(wednesdayKm: Double = 8) -> TrainingPlan {
        TrainingPlan(title: "Test", weeklyPlan: weeklyPlan(wednesdayKm: wednesdayKm), userProfile: RunnerProfile())
    }

    static func isolatedManager() -> TrainingPlanManager {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bobby-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return TrainingPlanManager(baseDirectory: url)
    }
}

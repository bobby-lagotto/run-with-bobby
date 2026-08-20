import Foundation

enum SessionStatus: String, Codable, CaseIterable {
    case planned
    case completed
    case skipped
    case partial

    var italianLabel: String {
        switch self {
        case .planned: return "previsto"
        case .completed: return "fatto"
        case .skipped: return "saltato"
        case .partial: return "parziale"
        }
    }
}

enum ReadinessRecommendation: String, Codable, CaseIterable {
    case go
    case easy
    case rest

    var italianLabel: String {
        switch self {
        case .go: return "vai"
        case .easy: return "facile"
        case .rest: return "riposo"
        }
    }
}

struct LoggedWorkout: Equatable, Sendable {
    var startDate: Date
    var distanceKm: Double
    var durationMinutes: Int
    var activityType: String

    var isRunningLike: Bool {
        let type = activityType.lowercased()
        return type.contains("corsa")
            || type.contains("cammin")
            || type.contains("run")
            || type.contains("walk")
            || type.contains("hiking")
            || type.contains("escursion")
    }
}

struct HealthSignals: Equatable, Sendable {
    var sleepHours: Double?
    var hrvMs: Double?
    var restingHeartRate: Double?
    var usualHrvMs: Double?
    var usualRestingHeartRate: Double?
}

struct AdherenceSummary: Equatable, Sendable {
    var plannedWorkouts: Int
    var completedWorkouts: Int
    var partialWorkouts: Int
    var skippedWorkouts: Int
    var remainingWorkouts: Int
    var percent: Int
    var coachContext: String
}

struct PlannedNotification: Equatable, Sendable {
    var id: String
    var fireDate: Date
    var title: String
    var body: String
}

struct RunLogComparison: Equatable, Sendable {
    var plannedKm: Double
    var loggedKm: Double
    var status: SessionStatus
    var shouldSuggestOptimize: Bool
}

enum WeekdayKey {
    static let italianNames = [
        1: "DOMENICA",
        2: "LUNEDÌ",
        3: "MARTEDÌ",
        4: "MERCOLEDÌ",
        5: "GIOVEDÌ",
        6: "VENERDÌ",
        7: "SABATO"
    ]

    static func italianName(for date: Date, calendar: Calendar = .current) -> String {
        let weekday = calendar.component(.weekday, from: date)
        return italianNames[weekday] ?? "LUNEDÌ"
    }

    static func normalized(_ value: String) -> String {
        value.folding(options: .diacriticInsensitive, locale: Locale(identifier: "it_IT"))
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func matches(_ dayOfWeek: String, date: Date, calendar: Calendar = .current) -> Bool {
        let expected = normalized(italianName(for: date, calendar: calendar))
        let actual = normalized(dayOfWeek)
        return actual == expected || actual.contains(expected) || expected.contains(actual)
    }
}

enum HabitThresholds {
    static let completionRatio = 0.95
    static let optimizeSuggestionRatio = 0.5
}

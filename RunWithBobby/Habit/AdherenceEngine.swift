import Foundation

enum AdherenceEngine {
    static func applyMatches(
        to plan: TrainingPlan,
        workouts: [LoggedWorkout],
        calendar: Calendar = .current
    ) -> TrainingPlan {
        var updated = plan
        for index in updated.weeklyPlan.indices {
            var day = updated.weeklyPlan[index]
            if day.sessionStatus == .skipped {
                continue
            }

            let matching = workouts.filter { workout in
                workout.isRunningLike && WeekdayKey.matches(day.dayOfWeek, date: workout.startDate, calendar: calendar)
            }
            guard !matching.isEmpty else { continue }
            guard day.workoutType != .rest else { continue }

            let totalKm = matching.reduce(0) { $0 + $1.distanceKm }
            let totalMinutes = matching.reduce(0) { $0 + $1.durationMinutes }
            day.loggedDistance = totalKm
            day.loggedDurationMinutes = totalMinutes
            day.sessionStatus = status(plannedKm: day.distance, loggedKm: totalKm)
            updated.weeklyPlan[index] = day
        }
        return updated
    }

    static func status(plannedKm: Double, loggedKm: Double) -> SessionStatus {
        if plannedKm <= 0 {
            return loggedKm > 0 ? .completed : .planned
        }
        if loggedKm <= 0 {
            return .planned
        }
        if loggedKm >= plannedKm * HabitThresholds.completionRatio {
            return .completed
        }
        return .partial
    }

    static func compare(plannedKm: Double, loggedKm: Double) -> RunLogComparison {
        let resolved = status(plannedKm: plannedKm, loggedKm: loggedKm)
        let shouldSuggest = plannedKm > 0 && loggedKm > 0 && loggedKm < plannedKm * HabitThresholds.optimizeSuggestionRatio
        return RunLogComparison(
            plannedKm: plannedKm,
            loggedKm: loggedKm,
            status: resolved,
            shouldSuggestOptimize: shouldSuggest
        )
    }

    static func log(
        plan: TrainingPlan,
        dayOfWeek: String,
        status: SessionStatus,
        loggedDistance: Double?,
        loggedDurationMinutes: Int?
    ) -> TrainingPlan {
        var updated = plan
        guard let index = updated.weeklyPlan.firstIndex(where: { WeekdayKey.normalized($0.dayOfWeek) == WeekdayKey.normalized(dayOfWeek) }) else {
            return updated
        }
        updated.weeklyPlan[index].sessionStatus = status
        if let loggedDistance {
            updated.weeklyPlan[index].loggedDistance = loggedDistance
        }
        if let loggedDurationMinutes {
            updated.weeklyPlan[index].loggedDurationMinutes = loggedDurationMinutes
        }
        updated.lastModified = Date()
        return updated
    }

    static func summary(for plan: TrainingPlan) -> AdherenceSummary {
        let workoutDays = plan.weeklyPlan.filter { $0.workoutType != .rest }
        let completed = workoutDays.filter { $0.sessionStatus == .completed }.count
        let partial = workoutDays.filter { $0.sessionStatus == .partial }.count
        let skipped = workoutDays.filter { $0.sessionStatus == .skipped }.count
        let remaining = workoutDays.filter { $0.sessionStatus == .planned }.count
        let credited = completed + partial
        let percent = workoutDays.isEmpty ? 0 : Int((Double(credited) / Double(workoutDays.count) * 100).rounded())

        let dayLines = plan.weeklyPlan.map { day in
            let logged = day.loggedDistance.map { String(format: " (%.1f km loggati)", $0) } ?? ""
            return "\(day.dayOfWeek): \(day.workoutType.rawValue) \(day.distance)km — \(day.sessionStatus.italianLabel)\(logged)"
        }.joined(separator: "; ")

        let context = "Aderenza \(percent)%: \(credited)/\(workoutDays.count) sedute avviate (fatte \(completed), parziali \(partial), saltate \(skipped), previste \(remaining)). \(dayLines)"

        return AdherenceSummary(
            plannedWorkouts: workoutDays.count,
            completedWorkouts: completed,
            partialWorkouts: partial,
            skippedWorkouts: skipped,
            remainingWorkouts: remaining,
            percent: percent,
            coachContext: context
        )
    }

    static func day(in plan: TrainingPlan, on date: Date, calendar: Calendar = .current) -> DayTraining? {
        plan.weeklyPlan.first { WeekdayKey.matches($0.dayOfWeek, date: date, calendar: calendar) }
    }
}

import Foundation

enum RunSessionLogic {
    static func finish(
        plannedKm: Double,
        loggedKm: Double,
        durationMinutes: Int
    ) -> RunLogComparison {
        _ = durationMinutes
        return AdherenceEngine.compare(plannedKm: plannedKm, loggedKm: loggedKm)
    }

    static func apply(
        to plan: TrainingPlan,
        dayOfWeek: String,
        comparison: RunLogComparison,
        durationMinutes: Int
    ) -> TrainingPlan {
        AdherenceEngine.log(
            plan: plan,
            dayOfWeek: dayOfWeek,
            status: comparison.status,
            loggedDistance: comparison.loggedKm,
            loggedDurationMinutes: durationMinutes
        )
    }
}

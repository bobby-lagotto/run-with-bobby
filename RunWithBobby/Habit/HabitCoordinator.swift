import Foundation
import Combine

@MainActor
final class HabitCoordinator: ObservableObject {
    @Published private(set) var today: TodayViewState
    @Published private(set) var lastOptimizeSuggestion: String?

    init() {
        today = TodayPresenter.make(plan: nil)
    }

    func refresh(
        plan: TrainingPlan?,
        workouts: [LoggedWorkout] = [],
        signals: HealthSignals = HealthSignals(),
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TrainingPlan? {
        var resolved = plan
        if let plan {
            resolved = AdherenceEngine.applyMatches(to: plan, workouts: workouts, calendar: calendar)
        }
        today = TodayPresenter.make(plan: resolved, signals: signals, now: now, calendar: calendar)
        persistSnapshot()
        return resolved
    }

    func logSession(
        plan: TrainingPlan,
        dayOfWeek: String,
        status: SessionStatus,
        loggedDistance: Double?,
        loggedDurationMinutes: Int?,
        signals: HealthSignals = HealthSignals(),
        now: Date = Date()
    ) -> TrainingPlan {
        let updated = AdherenceEngine.log(
            plan: plan,
            dayOfWeek: dayOfWeek,
            status: status,
            loggedDistance: loggedDistance,
            loggedDurationMinutes: loggedDurationMinutes
        )
        today = TodayPresenter.make(plan: updated, signals: signals, now: now)
        persistSnapshot()
        return updated
    }

    func finishRun(
        plan: TrainingPlan,
        dayOfWeek: String,
        loggedKm: Double,
        durationMinutes: Int,
        plannedKm: Double,
        signals: HealthSignals = HealthSignals(),
        now: Date = Date()
    ) -> TrainingPlan {
        let comparison = RunSessionLogic.finish(plannedKm: plannedKm, loggedKm: loggedKm, durationMinutes: durationMinutes)
        lastOptimizeSuggestion = comparison.shouldSuggestOptimize
            ? "Seduta molto sotto il previsto. Chiedi a Bobby di valutare optimize_plan, senza applicarlo da solo."
            : nil
        let updated = RunSessionLogic.apply(
            to: plan,
            dayOfWeek: dayOfWeek,
            comparison: comparison,
            durationMinutes: durationMinutes
        )
        today = TodayPresenter.make(plan: updated, signals: signals, now: now)
        persistSnapshot()
        return updated
    }

    func persistSnapshot() {
        try? TodaySnapshotStore.write(TodaySnapshot.from(today))
    }

    func consumeWatchAction(
        plan: TrainingPlan,
        dayOfWeek: String,
        signals: HealthSignals = HealthSignals(),
        now: Date = Date()
    ) -> TrainingPlan? {
        guard let action = TodaySnapshotStore.consumePendingAction() else { return nil }
        return logSession(
            plan: plan,
            dayOfWeek: dayOfWeek,
            status: action.status,
            loggedDistance: action.loggedDistance,
            loggedDurationMinutes: nil,
            signals: signals,
            now: now
        )
    }
}

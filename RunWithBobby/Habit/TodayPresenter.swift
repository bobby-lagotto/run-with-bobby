import Foundation

struct TodayViewState: Equatable {
    var hasActivePlan: Bool
    var isRestDay: Bool
    var dayTitle: String
    var workoutType: String
    var plannedKm: Double
    var sessionStatus: SessionStatus
    var recommendation: ReadinessRecommendation
    var briefingLine: String
    var weeklyAdherencePercent: Int
    var ctaTitle: String
    var canLog: Bool
}

extension TodaySnapshot {
    static func from(_ state: TodayViewState) -> TodaySnapshot {
        TodaySnapshot(
            dayTitle: state.dayTitle,
            workoutType: state.workoutType,
            plannedKm: state.plannedKm,
            sessionStatus: state.sessionStatus,
            recommendation: state.recommendation,
            briefingLine: state.briefingLine,
            weeklyAdherencePercent: state.weeklyAdherencePercent,
            isRestDay: state.isRestDay,
            hasActivePlan: state.hasActivePlan
        )
    }
}

enum TodayPresenter {
    static func make(
        plan: TrainingPlan?,
        signals: HealthSignals = HealthSignals(),
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TodayViewState {
        guard let plan else {
            return TodayViewState(
                hasActivePlan: false,
                isRestDay: true,
                dayTitle: WeekdayKey.italianName(for: now, calendar: calendar).capitalized,
                workoutType: "Nessun piano",
                plannedKm: 0,
                sessionStatus: .planned,
                recommendation: .easy,
                briefingLine: ReadinessEngine.briefingLine(recommendation: .easy, today: nil, hasActivePlan: false),
                weeklyAdherencePercent: 0,
                ctaTitle: "Parla con Bobby",
                canLog: false
            )
        }

        let today = AdherenceEngine.day(in: plan, on: now, calendar: calendar)
        let recommendation = ReadinessEngine.recommend(signals: signals, today: today, hasActivePlan: true)
        let adherence = AdherenceEngine.summary(for: plan)
        let isRest = today?.workoutType == .rest || today == nil
        let canLog = !isRest && today?.sessionStatus != .completed && today?.sessionStatus != .skipped

        let cta: String
        if isRest {
            cta = "Parla con Bobby"
        } else if today?.sessionStatus == .completed {
            cta = "Parla con Bobby"
        } else {
            cta = "Segna fatto"
        }

        return TodayViewState(
            hasActivePlan: true,
            isRestDay: isRest,
            dayTitle: today?.dayOfWeek.capitalized ?? WeekdayKey.italianName(for: now, calendar: calendar).capitalized,
            workoutType: today?.workoutType.rawValue ?? "Riposo",
            plannedKm: today?.distance ?? 0,
            sessionStatus: today?.sessionStatus ?? .planned,
            recommendation: recommendation,
            briefingLine: ReadinessEngine.briefingLine(recommendation: recommendation, today: today, hasActivePlan: true),
            weeklyAdherencePercent: adherence.percent,
            ctaTitle: cta,
            canLog: canLog
        )
    }
}

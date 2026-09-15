import Foundation

enum ReadinessEngine {
    static func recommend(
        signals: HealthSignals,
        today: DayTraining?,
        hasActivePlan: Bool
    ) -> ReadinessRecommendation {
        if !hasActivePlan {
            return .easy
        }
        if today?.workoutType == .rest || today == nil {
            return .rest
        }
        if today?.sessionStatus == .completed {
            return .easy
        }

        let poorSleep = (signals.sleepHours ?? .infinity) < 5.5
        let shortSleep = (signals.sleepHours ?? .infinity) < 6.5
        let lowHrv = isLowHrv(signals)
        let highResting = isHighRestingHeartRate(signals)
        let qualitySession = today?.workoutType == .intervals || today?.workoutType == .tempo

        if poorSleep && (lowHrv || highResting) {
            return .rest
        }
        if poorSleep {
            return qualitySession ? .rest : .easy
        }
        if (shortSleep && lowHrv) || (shortSleep && highResting) {
            return qualitySession ? .rest : .easy
        }
        if shortSleep || lowHrv || highResting {
            return qualitySession ? .easy : .go
        }
        return .go
    }

    static func briefingLine(
        recommendation: ReadinessRecommendation,
        today: DayTraining?,
        hasActivePlan: Bool
    ) -> String {
        if !hasActivePlan {
            return L10n.tr(
                "Nessun piano attivo. Chiedi a Bobby un piano prima di spingere.",
                english: "No active plan. Ask Bobby for a plan before you push."
            )
        }
        guard let today else {
            return L10n.tr("Oggi non c'è una seduta in calendario.", english: "There's no session on the calendar today.")
        }
        if today.workoutType == .rest {
            return L10n.tr("Giorno di riposo. Recupera, non inventare un doppio.", english: "Rest day. Recover, don't invent a double.")
        }
        switch recommendation {
        case .go:
            return L10n.format(
                "Oggi %@ · %@ km. I segnali vanno bene, vai.",
                english: "Today %@ · %@ km. Signals look good, go.",
                today.workoutType.displayName.lowercased(),
                formatted(today.distance)
            )
        case .easy:
            return L10n.format(
                "Oggi era %@ · %@ km. Con questi segnali tieni facile o accorcia.",
                english: "Today was %@ · %@ km. With these signals keep it easy or shorten.",
                today.workoutType.displayName.lowercased(),
                formatted(today.distance)
            )
        case .rest:
            return L10n.format(
                "I segnali dicono riposo. Se esci, cammina o jog molto blando al posto di %@.",
                english: "Signals say rest. If you go out, walk or very easy jog instead of %@.",
                today.workoutType.displayName.lowercased()
            )
        }
    }

    private static func isLowHrv(_ signals: HealthSignals) -> Bool {
        guard let hrv = signals.hrvMs else { return false }
        if let usual = signals.usualHrvMs, usual > 0 {
            return hrv < usual * 0.85
        }
        return hrv < 45
    }

    private static func isHighRestingHeartRate(_ signals: HealthSignals) -> Bool {
        guard let resting = signals.restingHeartRate else { return false }
        if let usual = signals.usualRestingHeartRate, usual > 0 {
            return resting > usual + 5
        }
        return resting >= 68
    }

    private static func formatted(_ km: Double) -> String {
        String(format: "%g", (km * 10).rounded() / 10)
    }
}

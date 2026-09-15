import SwiftUI

struct RunSessionView: View {
    @EnvironmentObject var planManager: TrainingPlanManager
    @EnvironmentObject var habitCoordinator: HabitCoordinator
    @EnvironmentObject var healthManager: HealthKitManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @StateObject private var session = RunSessionController()
    @State private var manualKm = ""
    @State private var resultNote: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text(session.isRunning ? L10n.tr("In corso", english: "In progress") : L10n.tr("Registra la corsa", english: "Log the run"))
                    .font(.title2.weight(.semibold))

                Text(String(format: "%.2f km", session.distanceKm))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(.bobbyRed)

                Text(timeLabel)
                    .font(.title3.monospacedDigit())
                    .foregroundColor(BobbyTheme.secondaryText(for: colorScheme))

                if session.authorizationDenied {
                    Text(L10n.tr("GPS non autorizzato. Puoi inserire i km a mano.", english: "GPS not authorised. You can enter km by hand."))
                        .font(.footnote)
                        .foregroundColor(.bobbyCaramel)
                }

                HStack {
                    if session.isRunning {
                        Button(L10n.tr("Termina", english: "Finish")) { finish(usingGPS: true) }
                            .buttonStyle(.borderedProminent)
                            .tint(.bobbyRed)
                    } else {
                        Button(L10n.tr("Avvia GPS", english: "Start GPS")) { session.start() }
                            .buttonStyle(.borderedProminent)
                            .tint(.bobbyRed)
                    }
                }

                HStack {
                    TextField(L10n.tr("Km manuali", english: "Manual km"), text: $manualKm)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    Button(L10n.tr("Salva", english: "Save")) { finish(usingGPS: false) }
                        .buttonStyle(.bordered)
                        .disabled(manualKm.isEmpty)
                }

                if let resultNote {
                    Text(resultNote)
                        .font(.footnote)
                        .foregroundColor(BobbyTheme.secondaryText(for: colorScheme))
                }

                Spacer()
            }
            .padding(24)
            .background(BobbyTheme.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle(L10n.tr("Sessione", english: "Session"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("Chiudi", english: "Close")) { dismiss() }
                }
            }
        }
    }

    private var timeLabel: String {
        let minutes = session.elapsedSeconds / 60
        let seconds = session.elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func finish(usingGPS: Bool) {
        guard var plan = planManager.currentActivePlan else { return }
        let today = AdherenceEngine.day(in: plan, on: Date())
        let planned = today?.distance ?? 0
        let dayName = today?.dayOfWeek ?? WeekdayKey.italianName(for: Date())

        let logged: Double
        let minutes: Int
        if usingGPS {
            let stopped = session.stop()
            logged = stopped.distanceKm
            minutes = stopped.durationMinutes
        } else {
            logged = Double(manualKm.replacingOccurrences(of: ",", with: ".")) ?? 0
            minutes = max(1, session.elapsedSeconds / 60)
            session.reset()
        }

        plan = habitCoordinator.finishRun(
            plan: plan,
            dayOfWeek: dayName,
            loggedKm: logged,
            durationMinutes: minutes,
            plannedKm: planned
        )
        planManager.savePlan(plan)
        planManager.setActivePlan(plan)

        Task {
            await healthManager.saveRunningWorkout(distanceKm: logged, durationMinutes: minutes)
        }

        if let suggestion = habitCoordinator.lastOptimizeSuggestion {
            resultNote = suggestion
        } else {
            resultNote = L10n.tr("Seduta registrata.", english: "Session logged.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                dismiss()
            }
        }
    }
}

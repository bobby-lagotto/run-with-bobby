import SwiftUI

struct TodayView: View {
    @EnvironmentObject var planManager: TrainingPlanManager
    @EnvironmentObject var healthManager: HealthKitManager
    @EnvironmentObject var habitCoordinator: HabitCoordinator
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    @Environment(\.dismiss) private var dismiss
    @State private var showingRun = false
    var onTalkToBobby: () -> Void = {}

    var body: some View {
        let state = habitCoordinator.today

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(state.dayTitle)
                        .font(.title2.weight(.bold))
                        .foregroundColor(BobbyTheme.primaryText(for: colorScheme))
                    Text(state.workoutType)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.bobbyRed)
                    if state.plannedKm > 0 {
                        Text(String(format: L10n.tr("%.1f km previsti", english: "%.1f km planned"), state.plannedKm))
                            .font(.headline)
                            .foregroundColor(BobbyTheme.secondaryText(for: colorScheme))
                    }
                }

                HStack(spacing: 12) {
                    StatPill(icon: "checkmark.circle", value: "\(state.sessionStatus.localizedLabel)")
                    StatPill(icon: "heart.text.square", value: state.recommendation.localizedLabel)
                    StatPill(icon: "percent", value: "\(state.weeklyAdherencePercent)%")
                }

                Text(state.briefingLine)
                    .font(.body)
                    .foregroundColor(BobbyTheme.primaryText(for: colorScheme))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BobbyTheme.cardBackground(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                if let suggestion = habitCoordinator.lastOptimizeSuggestion {
                    Text(suggestion)
                        .font(.footnote)
                        .foregroundColor(.bobbyCaramel)
                }

                VStack(spacing: 10) {
                    if state.canLog {
                        Button(state.ctaTitle) {
                            mark(.completed)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.bobbyRed)

                        Button(L10n.tr("Segna saltato", english: "Mark skipped")) {
                            mark(.skipped)
                        }
                        .buttonStyle(.bordered)

                        Button(L10n.tr("Registra corsa", english: "Log run")) {
                            showingRun = true
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(L10n.tr("Parla con Bobby", english: "Talk to Bobby")) {
                        onTalkToBobby()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .background(BobbyTheme.background(for: colorScheme).ignoresSafeArea())
        .navigationTitle(L10n.tr("Oggi", english: "Today"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !AppStoreScreenshotMode.isEnabled {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("Chiudi", english: "Close")) { dismiss() }
                }
            }
        }
        .task {
            if AppStoreScreenshotMode.isEnabled { return }
            await refreshFromHealth()
        }
        .sheet(isPresented: $showingRun) {
            RunSessionView()
        }
    }

    private func mark(_ status: SessionStatus) {
        guard var plan = planManager.currentActivePlan else { return }
        let day = WeekdayKey.italianName(for: Date())
        plan = habitCoordinator.logSession(
            plan: plan,
            dayOfWeek: day,
            status: status,
            loggedDistance: status == .completed ? AdherenceEngine.day(in: plan, on: Date())?.distance : nil,
            loggedDurationMinutes: nil
        )
        planManager.savePlan(plan)
        planManager.setActivePlan(plan)
        Task {
            await NotificationScheduler.apply(NotificationPlanning.workoutReminders(for: plan, from: Date()))
        }
    }

    private func refreshFromHealth() async {
        let workouts = healthManager.isAuthorized ? await healthManager.fetchLoggedWorkouts(days: 7) : []
        let signals = healthManager.isAuthorized ? await healthManager.fetchHealthSignals() : HealthSignals()
        if let updated = habitCoordinator.refresh(
            plan: planManager.currentActivePlan,
            workouts: workouts,
            signals: signals
        ) {
            planManager.savePlan(updated)
            planManager.setActivePlan(updated)
            await NotificationScheduler.requestAuthorization()
            await NotificationScheduler.apply(NotificationPlanning.workoutReminders(for: updated, from: Date()))
        } else {
            habitCoordinator.refresh(plan: nil)
        }

        if let plan = planManager.currentActivePlan,
           let fromWatch = habitCoordinator.consumeWatchAction(plan: plan, dayOfWeek: WeekdayKey.italianName(for: Date())) {
            planManager.savePlan(fromWatch)
            planManager.setActivePlan(fromWatch)
        }
    }
}

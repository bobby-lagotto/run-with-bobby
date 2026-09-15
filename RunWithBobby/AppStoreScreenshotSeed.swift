import Foundation
import SwiftUI

enum AppStoreScreenshotMode {
    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-AppStoreScreenshots")
        #else
        false
        #endif
    }

    static var screen: String {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-AppStoreScreenshotScreen"),
              arguments.indices.contains(index + 1) else {
            return "chat"
        }
        return arguments[index + 1]
        #else
        "chat"
        #endif
    }
}

#if DEBUG
enum AppStoreScreenshotSeed {
    @MainActor
    static func apply(
        appState: AppState,
        planManager: TrainingPlanManager,
        habitCoordinator: HabitCoordinator,
        aiSettings: AISettings
    ) {
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        aiSettings.providerType = .local

        var profile = RunnerProfile()
        profile.weeklyKilometers = 40
        profile.workoutsPerWeek = 5
        profile.primaryGoal = .speed
        profile.currentPace = "4:50"
        profile.raceDistance = .tenK
        profile.experience = .intermediate
        appState.userProfile = profile
        appState.saveUserProfile()

        let plan = makePlan(profile: profile)
        planManager.savePlan(plan)
        planManager.setActivePlan(plan)
        habitCoordinator.refresh(plan: plan)

        appState.replaceConversations([makeConversation()])
    }

    private static func makePlan(profile: RunnerProfile) -> TrainingPlan {
        TrainingPlan(
            title: "Focus velocità 10K",
            weeklyPlan: [
                DayTraining(
                    dayOfWeek: "LUNEDÌ",
                    workoutType: .intervals,
                    description: "Riscaldamento 2 km facili, poi 6 × 1000 m a 4:35-4:45/km con recupero 90s. Defaticamento 2 km.",
                    distance: 11,
                    estimatedDuration: 62
                ),
                DayTraining(
                    dayOfWeek: "MARTEDÌ",
                    workoutType: .easy,
                    description: "Corsa facile in zona 2, respiro nasale, niente fiato corto.",
                    distance: 8,
                    estimatedDuration: 48
                ),
                DayTraining(
                    dayOfWeek: "MERCOLEDÌ",
                    workoutType: .rest,
                    description: "Riposo attivo: camminata o mobilità 20 minuti.",
                    distance: 0,
                    estimatedDuration: 0
                ),
                DayTraining(
                    dayOfWeek: "GIOVEDÌ",
                    workoutType: .tempo,
                    description: "20 minuti a ritmo soglia dopo 2 km di riscaldamento.",
                    distance: 10,
                    estimatedDuration: 55
                ),
                DayTraining(
                    dayOfWeek: "VENERDÌ",
                    workoutType: .recovery,
                    description: "Recupero sciolto, cadenza alta, RPE 3.",
                    distance: 6,
                    estimatedDuration: 38
                ),
                DayTraining(
                    dayOfWeek: "SABATO",
                    workoutType: .long,
                    description: "Lungo aerobico. Ultimi 3 km un filo più svelti se le gambe sono buone.",
                    distance: 16,
                    estimatedDuration: 95
                ),
                DayTraining(
                    dayOfWeek: "DOMENICA",
                    workoutType: .easy,
                    description: "Facile di scarico, niente ripetute.",
                    distance: 7,
                    estimatedDuration: 42
                )
            ],
            userProfile: profile
        )
    }

    private static func makeConversation() -> Conversation {
        var conversation = Conversation(title: "Piano 10K")
        conversation.addMessage(ChatMessage(
            content: "Ciao Bobby, corro circa 40 km a settimana e voglio migliorare i 10K. Tieni tutto sul telefono.",
            isFromUser: true
        ))
        conversation.addMessage(ChatMessage(
            content: "Perfetto. Ho creato un piano focus velocità, 5 sedute, modello locale sul tuo iPhone.\n\nLUNEDÌ — Interval Training · 11 km\n6 × 1000 m a 4:35-4:45/km\n\nGIOVEDÌ — Tempo Run · 10 km\nSABATO — Lungo · 16 km\n\nOggi hai gli interval. I dati restano sul dispositivo finché resti in modalità Locale.",
            isFromUser: false
        ))
        return conversation
    }
}

struct AppStoreScreenshotRoot: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var planManager: TrainingPlanManager
    @EnvironmentObject var habitCoordinator: HabitCoordinator
    @EnvironmentObject var bobbyAI: BobbyAI
    @EnvironmentObject var aiSettings: AISettings

    var body: some View {
        Group {
            switch AppStoreScreenshotMode.screen {
            case "oggi":
                NavigationView {
                    TodayView()
                }
                .navigationViewStyle(.stack)
            case "piani":
                if let plan = planManager.currentActivePlan {
                    TrainingPlanDetailView(planId: plan.id, planManager: planManager)
                } else {
                    TrainingPlansArchiveView(planManager: planManager)
                }
            default:
                ChatView()
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            bobbyAI.configure(with: aiSettings, healthManager: nil)
        }
    }
}
#endif

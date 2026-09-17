import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var aiSettings: AISettings
    @State private var isFirstLaunch = true

    var body: some View {
        Group {
            if isFirstLaunch && !appState.isProfileComplete {
                WelcomeView(appState: appState, isFirstLaunch: $isFirstLaunch)
            } else {
                ChatView()
                    .id(aiSettings.languagePreference)
            }
        }
        .onAppear {
            checkFirstLaunch()
        }
    }

    private func checkFirstLaunch() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if hasLaunchedBefore {
            isFirstLaunch = false
        } else {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    @ObservedObject var appState: AppState
    @Binding var isFirstLaunch: Bool
    @EnvironmentObject var aiSettings: AISettings
    @State private var currentStep = 0

    private let languageStep = 0
    private let sourcesStep = 1
    private var introOffset: Int { 2 }

    private var welcomeSteps: [WelcomeStep] {
        [
        WelcomeStep(
            icon: "figure.run",
            title: L10n.tr("Benvenuto in Run with Bobby", english: "Welcome to Run with Bobby"),
            description: L10n.tr(
                "Il tuo personal trainer di corsa con intelligenza artificiale locale",
                english: "Your running coach with on-device AI"
            ),
            color: .bobbyRed
        ),
        WelcomeStep(
            icon: "lock.shield.fill",
            title: L10n.tr("Privacy sotto controllo", english: "Privacy under your control"),
            description: L10n.tr(
                "Puoi usare il modello locale sul tuo iPhone. I provider cloud sono opzionali e inviano solo il contesto necessario quando li attivi",
                english: "You can use the on-device model on your iPhone. Cloud providers are optional and only send the needed context when you turn them on"
            ),
            color: .bobbyCaramel
        ),
        WelcomeStep(
            icon: "list.clipboard.fill",
            title: L10n.tr("Piani Personalizzati", english: "Personalised plans"),
            description: L10n.tr(
                "Bobby crea piani di allenamento su misura per i tuoi obiettivi e livello",
                english: "Bobby builds training plans around your goals and level"
            ),
            color: .bobbyRed
        ),
        WelcomeStep(
            icon: "bubble.left.and.bubble.right.fill",
            title: L10n.tr("Conversazione Naturale", english: "Natural conversation"),
            description: L10n.tr(
                "Parla con Bobby come faresti con un vero coach. Chiedi consigli, ottimizza i piani",
                english: "Talk to Bobby like a real coach. Ask for advice, optimise plans"
            ),
            color: .bobbyCaramel
        )
        ]
    }

    private var totalStepCount: Int { introOffset + welcomeSteps.count }
    private var isLastStep: Bool { currentStep >= totalStepCount - 1 }

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 8) {
                ForEach(0..<totalStepCount, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentStep ? Color.bobbyRed : Color.bobbyWarmGray.opacity(0.3))
                        .frame(width: index == currentStep ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.4), value: currentStep)
                }
            }
            .padding(.top, 16)

            Group {
                if currentStep == languageStep {
                    languageStepContent
                } else if currentStep == sourcesStep {
                    sourcesStepContent
                } else {
                    introStepContent(welcomeSteps[currentStep - introOffset])
                }
            }
            .id(currentStep)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            HStack {
                if currentStep > 0 {
                    Button(L10n.tr("Indietro", english: "Back")) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep -= 1
                        }
                    }
                    .font(.body.weight(.medium))
                    .foregroundColor(.bobbyWarmGray)
                }

                Spacer()

                if currentStep != languageStep {
                    Button(isLastStep ? L10n.tr("Inizia a Correre!", english: "Start running!") : L10n.tr("Avanti", english: "Next")) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if isLastStep {
                                isFirstLaunch = false
                            } else {
                                currentStep += 1
                            }
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(height: 50)
                    .frame(maxWidth: isLastStep ? .infinity : 140)
                    .background(Color.bobbyRed)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.bobbyGroupedBackground, Color.bobbyBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var languageStepContent: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.bobbyRed.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: "globe")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(Color.bobbyRed)
            }

            Text("Lingua / Language")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundColor(.bobbyCharcoal)

            Text("Bobby parla italiano o inglese.\nBobby speaks Italian or English.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.bobbyWarmGray)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                languageButton(title: "Italiano", preference: .italian)
                languageButton(title: "English", preference: .english)
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    private func languageButton(title: String, preference: AppLanguagePreference) -> some View {
        Button {
            aiSettings.languagePreference = preference
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = sourcesStep
            }
        } label: {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.bobbyRed)
                .clipShape(Capsule())
        }
    }

    private var sourcesStepContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(L10n.tr("Fonti e sicurezza", english: "Sources and safety"))
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.bobbyCharcoal)

                SourcesList()
            }
            .padding(.horizontal, 8)
        }
    }

    private func introStepContent(_ step: WelcomeStep) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(step.color.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: step.icon)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(step.color)
            }

            Text(step.title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundColor(.bobbyCharcoal)

            Text(step.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.bobbyWarmGray)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

// MARK: - Welcome Step Model
struct WelcomeStep {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

// MARK: - Preview
#Preview {
    ContentView()
}

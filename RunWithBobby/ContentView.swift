import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var aiSettings: AISettings

    var body: some View {
        Group {
            if !appState.isProfileComplete {
                WelcomeView(appState: appState)
            } else {
                ChatView()
                    .id(aiSettings.languagePreference)
            }
        }
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    @ObservedObject var appState: AppState
    @EnvironmentObject var aiSettings: AISettings
    @EnvironmentObject var healthManager: HealthKitManager
    @State private var currentStep = 0
    @State private var healthDecisionMade = UserDefaults.standard.bool(forKey: "healthkit_connected")
    @State private var healthConnected = UserDefaults.standard.bool(forKey: "healthkit_connected")
    @State private var isConnectingHealth = false
    @State private var healthErrorMessage: String?

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

    private var healthStep: Int { introOffset + welcomeSteps.count }
    private var profileStep: Int { healthStep + 1 }
    private var totalStepCount: Int { profileStep + 1 }
    private var isLastStep: Bool { currentStep >= totalStepCount - 1 }
    private var showsPrimaryAction: Bool {
        currentStep != languageStep && (currentStep != healthStep || healthDecisionMade)
    }

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
                } else if currentStep == healthStep {
                    healthStepContent
                } else if currentStep == profileStep {
                    profileStepContent
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

                if showsPrimaryAction {
                    Button(isLastStep ? L10n.tr("Inizia a Correre!", english: "Start running!") : L10n.tr("Avanti", english: "Next")) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if isLastStep {
                                appState.saveUserProfile()
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

    private var healthLaterHint: String {
        L10n.tr(
            "Puoi collegare HealthKit in qualsiasi momento dal menu ··· > Apple Health (HealthKit), oppure Impostazioni AI > Salute (HealthKit).",
            english: "You can connect HealthKit anytime from the ··· menu > Apple Health (HealthKit), or AI Settings > Health (HealthKit)."
        )
    }

    private var healthStepContent: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.bobbyRed.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: healthConnected ? "heart.fill" : "heart.text.clipboard")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(Color.bobbyRed)
            }

            Text(L10n.tr("Apple Health (HealthKit)", english: "Apple Health (HealthKit)"))
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundColor(.bobbyCharcoal)

            Text(L10n.tr(
                "Bobby usa HealthKit per leggere sonno, HRV, frequenza cardiaca e allenamenti e personalizzare recupero e briefing. L'app non usa CareKit. I dati restano sul dispositivo salvo se attivi un provider cloud in chat.",
                english: "Bobby uses HealthKit to read sleep, HRV, heart rate and workouts to personalise recovery and briefings. The app does not use CareKit. Data stays on the device unless you use a cloud provider in chat."
            ))
            .font(.body)
            .multilineTextAlignment(.center)
            .foregroundColor(.bobbyWarmGray)
            .padding(.horizontal, 32)

            if !healthManager.isAvailable {
                Text(L10n.tr(
                    "Apple Health non è disponibile su questo dispositivo.",
                    english: "Apple Health is not available on this device."
                ))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.bobbyWarmGray)
                .padding(.horizontal, 32)
                Text(healthLaterHint)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.bobbyWarmGray)
                    .padding(.horizontal, 32)
            } else if healthConnected {
                Label(
                    L10n.tr("Salute collegata", english: "Health connected"),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.headline)
                .foregroundColor(.bobbyRed)
            } else {
                VStack(spacing: 12) {
                    Button(action: connectHealth) {
                        HStack(spacing: 8) {
                            if isConnectingHealth {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(L10n.tr("Collega Salute", english: "Connect Health"))
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.bobbyRed)
                        .clipShape(Capsule())
                    }
                    .disabled(isConnectingHealth)

                    Button(L10n.tr("Più tardi", english: "Later")) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            healthDecisionMade = true
                            healthConnected = false
                        }
                    }
                    .font(.body.weight(.medium))
                    .foregroundColor(.bobbyWarmGray)
                    .disabled(isConnectingHealth)
                }
                .padding(.horizontal, 24)
            }

            if let healthErrorMessage {
                Text(healthErrorMessage)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.bobbyRed)
                    .padding(.horizontal, 32)
            }

            if healthDecisionMade && !healthConnected && healthManager.isAvailable {
                Text(healthLaterHint)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.bobbyWarmGray)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .onAppear {
            if !healthManager.isAvailable {
                healthDecisionMade = true
            }
        }
    }

    private func connectHealth() {
        isConnectingHealth = true
        healthErrorMessage = nil
        Task {
            let authorized = await healthManager.requestAuthorization()
            await MainActor.run {
                isConnectingHealth = false
                if authorized {
                    healthConnected = true
                    healthDecisionMade = true
                    UserDefaults.standard.set(true, forKey: "healthkit_connected")
                } else {
                    healthConnected = false
                    healthDecisionMade = true
                    healthErrorMessage = L10n.tr(
                        "Autorizzazione Health non concessa.",
                        english: "Health authorization was not granted."
                    )
                }
            }
        }
    }

    private var profileStepContent: some View {
        VStack(spacing: 16) {
            Text(L10n.tr("Il tuo profilo runner", english: "Your runner profile"))
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundColor(.bobbyCharcoal)

            Text(L10n.tr(
                "Compila i dati di partenza: Bobby li usa per piani e consigli su misura.",
                english: "Fill in your starting data: Bobby uses it for tailored plans and advice."
            ))
            .font(.body)
            .multilineTextAlignment(.center)
            .foregroundColor(.bobbyWarmGray)
            .padding(.horizontal, 16)

            Form {
                RunnerProfileForm(profile: $appState.userProfile)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
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

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
    @State private var currentStep = 0

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

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<welcomeSteps.count, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentStep ? Color.bobbyRed : Color.bobbyWarmGray.opacity(0.3))
                        .frame(width: index == currentStep ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.4), value: currentStep)
                }
            }

            // Current step content
            let step = welcomeSteps[currentStep]

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(step.color.opacity(0.12))
                        .frame(width: 120, height: 120)
                    Image(systemName: step.icon)
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(step.color)
                }
                .scaleEffect(currentStep == 0 ? 1.1 : 1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: currentStep)

                Text(step.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.bobbyCharcoal)

                Text(step.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.bobbyWarmGray)
                    .padding(.horizontal, 32)
            }
            .id(currentStep)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            Spacer()

            // Navigation buttons
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

                Button(currentStep < welcomeSteps.count - 1 ? L10n.tr("Avanti", english: "Next") : L10n.tr("Inizia a Correre!", english: "Start running!")) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if currentStep < welcomeSteps.count - 1 {
                            currentStep += 1
                        } else {
                            isFirstLaunch = false
                        }
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(height: 50)
                .frame(maxWidth: currentStep < welcomeSteps.count - 1 ? 140 : .infinity)
                .background(Color.bobbyRed)
                .clipShape(Capsule())
                .animation(.spring(response: 0.4), value: currentStep)
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

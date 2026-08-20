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
                MainTabView()
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
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                TodayView(onTalkToBobby: { selectedTab = 1 })
            }
            .tabItem {
                Label("Oggi", systemImage: "sun.max.fill")
            }
            .tag(0)

            ChatView()
                .tabItem {
                    Label("Bobby", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(1)
        }
        .tint(.bobbyRed)
    }
}

struct WelcomeView: View {
    @ObservedObject var appState: AppState
    @Binding var isFirstLaunch: Bool
    @State private var currentStep = 0

    private let welcomeSteps = [
        WelcomeStep(
            icon: "figure.run",
            title: "Benvenuto in Run with Bobby",
            description: "Il tuo personal trainer di corsa con intelligenza artificiale locale",
            color: .bobbyRed
        ),
        WelcomeStep(
            icon: "lock.shield.fill",
            title: "Privacy sotto controllo",
            description: "Puoi usare il modello locale sul tuo iPhone. I provider cloud sono opzionali e inviano solo il contesto necessario quando li attivi",
            color: .bobbyCaramel
        ),
        WelcomeStep(
            icon: "list.clipboard.fill",
            title: "Piani Personalizzati",
            description: "Bobby crea piani di allenamento su misura per i tuoi obiettivi e livello",
            color: .bobbyRed
        ),
        WelcomeStep(
            icon: "bubble.left.and.bubble.right.fill",
            title: "Conversazione Naturale",
            description: "Parla con Bobby come faresti con un vero coach. Chiedi consigli, ottimizza i piani",
            color: .bobbyCaramel
        )
    ]

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
                    Button("Indietro") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep -= 1
                        }
                    }
                    .font(.body.weight(.medium))
                    .foregroundColor(.bobbyWarmGray)
                }

                Spacer()

                Button(currentStep < welcomeSteps.count - 1 ? "Avanti" : "Inizia a Correre!") {
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

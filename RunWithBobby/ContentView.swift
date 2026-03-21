import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @State private var isFirstLaunch = true
    
    var body: some View {
        Group {
            if isFirstLaunch && !appState.isProfileComplete {
                WelcomeView(appState: appState, isFirstLaunch: $isFirstLaunch)
            } else {
                ChatView()
                    .environmentObject(appState)
            }
        }
        .onAppear {
            // Controlla se è il primo avvio
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
    @State private var showingChat = false
    
    private let welcomeSteps = [
        WelcomeStep(
            icon: "🏃‍♂️",
            title: "Benvenuto in Run with Bobby",
            description: "Il tuo personal trainer di corsa con intelligenza artificiale locale",
            color: .blue
        ),
        WelcomeStep(
            icon: "🧠",
            title: "AI Completamente Locale",
            description: "Tutta l'intelligenza artificiale funziona sul tuo iPhone. I tuoi dati non lasciano mai il device",
            color: .green
        ),
        WelcomeStep(
            icon: "📋",
            title: "Piani Personalizzati",
            description: "Bobby crea piani di allenamento su misura per i tuoi obiettivi e livello",
            color: .orange
        ),
        WelcomeStep(
            icon: "💬",
            title: "Conversazione Naturale",
            description: "Parla con Bobby come faresti con un vero coach. Chiedi consigli, ottimizza i piani",
            color: .purple
        )
    ]
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Progress indicator
            HStack {
                ForEach(0..<welcomeSteps.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            // Current step content
            let step = welcomeSteps[currentStep]
            
            VStack(spacing: 24) {
                Text(step.icon)
                    .font(.system(size: 80))
                    .scaleEffect(currentStep == 0 ? 1.2 : 1.0)
                    .animation(.spring(response: 0.6), value: currentStep)
                
                Text(step.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(step.color)
                
                Text(step.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button("Indietro") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                if currentStep < welcomeSteps.count - 1 {
                    Button("Avanti") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Inizia a Correre! 🚀") {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            isFirstLaunch = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    welcomeSteps[currentStep].color.opacity(0.1),
                    Color.clear
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
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
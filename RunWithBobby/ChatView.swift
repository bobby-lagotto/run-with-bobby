import SwiftUI

struct ChatView: View {
    @StateObject private var appState = AppState()
    @StateObject private var bobbyAI = BobbyAI()
    @StateObject private var planManager = TrainingPlanManager()
    
    @State private var messageText = ""
    @State private var showingPlansArchive = false
    @State private var showingProfileSetup = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header con info attuale
                headerView
                
                // Area messaggi
                messagesList
                
                // Input area
                messageInputArea
            }
            .navigationTitle("Bobby Running Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("📋 Archivio Piani", action: { showingPlansArchive = true })
                        Button("👤 Profilo Runner", action: { showingProfileSetup = true })
                        Button("🗨️ Nuova Chat", action: { appState.startNewConversation() })
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingPlansArchive) {
                TrainingPlansArchiveView(planManager: planManager)
            }
            .sheet(isPresented: $showingProfileSetup) {
                RunnerProfileView(appState: appState)
            }
            .onAppear {
                if appState.conversations.isEmpty {
                    showWelcomeMessage()
                }
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("🏃‍♂️ Bobby")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if bobbyAI.isLoading {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Pensando...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Info profilo se disponibile
            if appState.isProfileComplete {
                HStack {
                    Label("\(Int(appState.userProfile.weeklyKilometers))km/sett", systemImage: "figure.run")
                    Spacer()
                    Label("\(appState.userProfile.workoutsPerWeek) allenamenti", systemImage: "calendar")
                    Spacer()
                    Label(appState.userProfile.primaryGoal.rawValue, systemImage: "target")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            if let activePlan = planManager.currentActivePlan {
                HStack {
                    Text("📋 Piano Attivo: \(activePlan.title)")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Messages List
    private var messagesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let conversation = appState.currentConversation {
                    ForEach(conversation.messages) { message in
                        MessageBubbleView(message: message)
                    }
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Message Input
    private var messageInputArea: some View {
        VStack(spacing: 8) {
            // Quick action buttons
            if !appState.isProfileComplete {
                quickSetupButtons
            } else {
                quickActionButtons
            }
            
            // Text input
            HStack {
                TextField("Scrivi a Bobby...", text: $messageText, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(1...4)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bobbyAI.isLoading)
            }
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Quick Setup Buttons (Prima configurazione)
    private var quickSetupButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                QuickButton("Sono un principiante") { sendQuickMessage("Sono un principiante, voglio iniziare a correre") }
                QuickButton("Corro già 20km/sett") { sendQuickMessage("Corro già circa 20km alla settimana") }
                QuickButton("Voglio correre una 10K") { sendQuickMessage("Il mio obiettivo è correre una 10K") }
                QuickButton("Voglio perdere peso") { sendQuickMessage("Voglio correre per perdere peso") }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Quick Action Buttons (Dopo setup)
    private var quickActionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                QuickButton("Nuovo piano") { sendQuickMessage("Crea un nuovo piano di allenamento per me") }
                QuickButton("Ottimizza piano") { sendQuickMessage("Vorrei ottimizzare il mio piano attuale") }
                QuickButton("Consigli recupero") { sendQuickMessage("Dammi consigli per il recupero") }
                QuickButton("Nutrizione runner") { sendQuickMessage("Consigli di nutrizione per runner") }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Methods
    private func showWelcomeMessage() {
        let welcomeMessage = """
        Ciao! Sono Bobby, il tuo personal trainer di corsa! 🏃‍♂️
        
        Sono qui per aiutarti a:
        • Creare piani di allenamento personalizzati
        • Migliorare le tue performance
        • Raggiungere i tuoi obiettivi di corsa
        
        Per iniziare, dimmi qualcosa sui tuoi allenamenti attuali!
        """
        
        appState.addMessage(welcomeMessage, isFromUser: false)
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        sendQuickMessage(text)
        messageText = ""
    }
    
    private func sendQuickMessage(_ text: String) {
        // Aggiungi messaggio utente
        appState.addMessage(text, isFromUser: true)
        
        // Genera risposta di Bobby
        Task {
            let response = await bobbyAI.generateResponse(
                to: text,
                userProfile: appState.userProfile,
                conversationHistory: appState.currentConversation?.messages ?? []
            )
            
            await MainActor.run {
                appState.addMessage(response, isFromUser: false)
                
                // Controlla se la risposta contiene un piano di allenamento
                if let trainingPlan = bobbyAI.extractTrainingPlan(from: response, userProfile: appState.userProfile) {
                    planManager.savePlan(trainingPlan)
                }
            }
        }
    }
}

// MARK: - Message Bubble View
struct MessageBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer(minLength: 50)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    
                    Text(timeString(from: message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("🏃‍♂️")
                        Text("Bobby")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    Text(message.content)
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .foregroundColor(.primary)
                        .cornerRadius(16)
                    
                    Text(timeString(from: message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer(minLength: 50)
            }
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Quick Button
struct QuickButton: View {
    let title: String
    let action: () -> Void
    
    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1))
                .foregroundColor(.accentColor)
                .cornerRadius(16)
        }
    }
}

// MARK: - Training Plans Archive View
struct TrainingPlansArchiveView: View {
    @ObservedObject var planManager: TrainingPlanManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if let activePlan = planManager.currentActivePlan {
                    Section("Piano Attivo") {
                        TrainingPlanRowView(plan: activePlan, planManager: planManager)
                    }
                }
                
                Section("Archivio Piani") {
                    ForEach(planManager.savedPlans.filter { $0.id != planManager.currentActivePlan?.id }) { plan in
                        TrainingPlanRowView(plan: plan, planManager: planManager)
                    }
                    .onDelete(perform: deletePlans)
                }
                
                if planManager.savedPlans.isEmpty {
                    Text("Nessun piano salvato")
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .navigationTitle("Archivio Piani")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
    
    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            let plan = planManager.savedPlans[index]
            planManager.deletePlan(plan)
        }
    }
}

// MARK: - Training Plan Row View
struct TrainingPlanRowView: View {
    let plan: TrainingPlan
    @ObservedObject var planManager: TrainingPlanManager
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(plan.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Spacer()
                
                if plan.id == planManager.currentActivePlan?.id {
                    Text("ATTIVO")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            let stats = planManager.getWeeklyStats(for: plan)
            HStack {
                Label("\(Int(stats.totalDistance))km", systemImage: "figure.run")
                Label("\(stats.workoutCount) allenamenti", systemImage: "calendar")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            HStack {
                Button("Visualizza") { showingDetails = true }
                    .buttonStyle(.bordered)
                
                if plan.id != planManager.currentActivePlan?.id {
                    Button("Attiva") {
                        planManager.setActivePlan(plan)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .sheet(isPresented: $showingDetails) {
            TrainingPlanDetailView(plan: plan, planManager: planManager)
        }
    }
}

// MARK: - Training Plan Detail View
struct TrainingPlanDetailView: View {
    let plan: TrainingPlan
    @ObservedObject var planManager: TrainingPlanManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Informazioni") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(plan.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        let stats = planManager.getWeeklyStats(for: plan)
                        HStack {
                            Label("\(Int(stats.totalDistance))km totali", systemImage: "figure.run")
                            Spacer()
                            Label("\(stats.workoutCount) allenamenti", systemImage: "calendar")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Piano Settimanale") {
                    ForEach(plan.weeklyPlan) { day in
                        DayTrainingRowView(dayTraining: day)
                    }
                }
            }
            .navigationTitle("Dettagli Piano")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Day Training Row View
struct DayTrainingRowView: View {
    let dayTraining: DayTraining
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dayTraining.dayOfWeek)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(dayTraining.workoutType.emoji)
                Text(dayTraining.workoutType.rawValue)
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(dayTraining.workoutType.color.opacity(0.2))
                    .foregroundColor(dayTraining.workoutType.color)
                    .cornerRadius(8)
            }
            
            if dayTraining.distance > 0 {
                HStack {
                    Label("\(dayTraining.distance, specifier: "%.1f")km", systemImage: "figure.run")
                    Label("\(dayTraining.estimatedDuration)min", systemImage: "clock")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            if !dayTraining.description.isEmpty {
                Text(dayTraining.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Runner Profile View
struct RunnerProfileView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Allenamento Attuale") {
                    HStack {
                        Text("Km alla settimana")
                        Spacer()
                        TextField("20", value: $appState.userProfile.weeklyKilometers, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    Stepper("Allenamenti/settimana: \(appState.userProfile.workoutsPerWeek)", value: $appState.userProfile.workoutsPerWeek, in: 1...7)
                    
                    HStack {
                        Text("Ritmo attuale")
                        Spacer()
                        TextField("5:30", text: $appState.userProfile.currentPace)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
                
                Section("Obiettivi") {
                    Picker("Obiettivo principale", selection: $appState.userProfile.primaryGoal) {
                        ForEach(TrainingGoal.allCases, id: \.self) { goal in
                            Text(goal.rawValue).tag(goal)
                        }
                    }
                    
                    Picker("Livello esperienza", selection: $appState.userProfile.experience) {
                        ForEach(ExperienceLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                }
                
                Section("Gara Obiettivo (opzionale)") {
                    Picker("Distanza gara", selection: $appState.userProfile.raceDistance) {
                        Text("Nessuna gara specifica").tag(nil as RaceDistance?)
                        ForEach(RaceDistance.allCases, id: \.self) { distance in
                            Text(distance.rawValue).tag(distance as RaceDistance?)
                        }
                    }
                }
            }
            .navigationTitle("Il Tuo Profilo Runner")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        appState.saveUserProfile()
                        dismiss()
                    }
                }
            }
        }
    }
}
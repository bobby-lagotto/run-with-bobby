import SwiftUI

struct ChatView: View {
    @StateObject private var appState = AppState()
    @StateObject private var bobbyAI = BobbyAI()
    @StateObject private var planManager = TrainingPlanManager()
    @StateObject private var healthManager = HealthKitManager()
    @StateObject private var nutritionManager = NutritionPlanManager()
    @EnvironmentObject var aiSettings: AISettings
    @Environment(\.colorScheme) var colorScheme

    @State private var messageText = ""
    @State private var showingPlansArchive = false
    @State private var showingProfileSetup = false
    @State private var showingSettings = false
    @State private var showingConversationHistory = false
    @State private var showingNutritionPlan = false
    @State private var planToDiscuss: TrainingPlan?
    @State private var healthConnected = UserDefaults.standard.bool(forKey: "healthkit_connected")

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView
                messagesList
                messageInputArea
            }
            .background(BobbyTheme.background(for: colorScheme).ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showingPlansArchive, onDismiss: {
                if let plan = planToDiscuss {
                    askBobbyAboutPlan(plan)
                    planToDiscuss = nil
                }
            }) {
                TrainingPlansArchiveView(planManager: planManager, onAskBobby: { plan in
                    planToDiscuss = plan
                    showingPlansArchive = false
                })
            }
            .sheet(isPresented: $showingProfileSetup) {
                RunnerProfileView(appState: appState)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(aiSettings: aiSettings, healthManager: healthManager, mlxProvider: bobbyAI.mlxProvider, onHealthChanged: {
                    healthConnected = UserDefaults.standard.bool(forKey: "healthkit_connected")
                    bobbyAI.configure(with: aiSettings, healthManager: healthConnected ? healthManager : nil)
                }, onProviderChanged: {
                    bobbyAI.updateProvider()
                })
            }
            .sheet(isPresented: $showingConversationHistory) {
                ConversationHistoryView(appState: appState)
            }
            .sheet(isPresented: $showingNutritionPlan) {
                NutritionPlanView(nutritionManager: nutritionManager, planManager: planManager, onAskBobby: {
                    showingNutritionPlan = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        sendQuickMessage("Vorrei modificare il mio piano alimentare")
                    }
                })
            }
            .onAppear {
                bobbyAI.configure(with: aiSettings, healthManager: healthConnected ? healthManager : nil)
                if appState.conversations.isEmpty {
                    showWelcomeMessage()
                }
            }
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // Bobby avatar
                Image("BobbyLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Bobby")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(BobbyTheme.primaryText(for: colorScheme))

                    if bobbyAI.isLoading {
                        Text(bobbyAI.streamingText.isEmpty ? "Sta pensando..." : "Sta scrivendo...")
                            .font(.caption)
                            .foregroundColor(.bobbyWarmGray)
                    } else {
                        HStack(spacing: 4) {
                            Text("Il tuo running coach")
                            if !bobbyAI.activeProviderName.isEmpty {
                                Text("·")
                                Image(systemName: aiSettings.providerType.icon)
                                    .font(.caption2)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.bobbyWarmGray)
                    }
                }

                Spacer()

                if bobbyAI.isLoading {
                    ProgressView()
                        .tint(.bobbyRed)
                        .scaleEffect(0.8)
                }

                Menu {
                    Button(action: { showingPlansArchive = true }) {
                        Label("Archivio Piani", systemImage: "list.clipboard")
                    }
                    Button(action: { showingNutritionPlan = true }) {
                        Label("Piano Alimentare", systemImage: "fork.knife")
                    }
                    Button(action: { showingConversationHistory = true }) {
                        Label("Storico Chat", systemImage: "clock.arrow.circlepath")
                    }
                    Button(action: { showingProfileSetup = true }) {
                        Label("Profilo Runner", systemImage: "person.crop.circle")
                    }
                    Button(action: { showingSettings = true }) {
                        Label("Impostazioni AI", systemImage: "gearshape")
                    }
                    Button(action: { appState.startNewConversation() }) {
                        Label("Nuova Chat", systemImage: "plus.bubble")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(BobbyTheme.accentColor(for: colorScheme))
                }
            }

            // Profile stats
            if appState.isProfileComplete {
                HStack(spacing: 16) {
                    StatPill(icon: "figure.run", value: "\(Int(appState.userProfile.weeklyKilometers))km/sett")
                    StatPill(icon: "calendar", value: "\(appState.userProfile.workoutsPerWeek) allenamenti")
                    StatPill(icon: "target", value: appState.userProfile.primaryGoal.rawValue)
                }
            }

            // Active plan pills
            HStack(spacing: 8) {
                if let activePlan = planManager.currentActivePlan {
                    HStack(spacing: 6) {
                        Image(systemName: "list.clipboard.fill")
                            .font(.caption)
                        Text(activePlan.title)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(.bobbyRed)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.bobbyRed.opacity(0.08))
                    .clipShape(Capsule())
                }

                if nutritionManager.currentNutritionPlan != nil {
                    HStack(spacing: 6) {
                        Image(systemName: "fork.knife")
                            .font(.caption)
                        Text("Alimentare")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(.bobbyCaramel)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.bobbyCaramel.opacity(0.08))
                    .clipShape(Capsule())
                    .onTapGesture { showingNutritionPlan = true }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Messages List
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let conversation = appState.currentConversation {
                        ForEach(conversation.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                    }

                    // Streaming response bubble
                    if !bobbyAI.streamingText.isEmpty {
                        MessageBubbleView(message: ChatMessage(content: bobbyAI.streamingText, isFromUser: false))
                            .id("streaming")
                    }

                    // Typing indicator while waiting for response
                    if bobbyAI.isLoading && bobbyAI.streamingText.isEmpty {
                        TypingIndicatorView()
                            .id("typing")
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .onChange(of: appState.currentConversation?.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("bottom")
                }
            }
            .onChange(of: bobbyAI.streamingText) { _, _ in
                proxy.scrollTo("bottom")
            }
            .onChange(of: bobbyAI.isLoading) { _, isLoading in
                if isLoading {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("bottom")
                    }
                }
            }
        }
    }

    // MARK: - Message Input
    private var messageInputArea: some View {
        VStack(spacing: 8) {
            if !appState.isProfileComplete {
                quickSetupButtons
            } else {
                quickActionButtons
            }

            HStack(spacing: 12) {
                HStack {
                    TextField("Scrivi a Bobby...", text: $messageText, axis: .vertical)
                        .lineLimit(1...4)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .background(BobbyTheme.cardBackground(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.bobbyWarmGray.opacity(0.2), lineWidth: 1)
                )

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(
                            messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? .bobbyWarmGray.opacity(0.4)
                                : .bobbyRed
                        )
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bobbyAI.isLoading)
                .animation(.easeInOut(duration: 0.2), value: messageText.isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    // MARK: - Quick Setup Buttons
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

    // MARK: - Quick Action Buttons
    private var quickActionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                QuickButton("Nuovo piano") { sendQuickMessage("Crea un nuovo piano di allenamento per me") }
                QuickButton("Piano alimentare") { sendQuickMessage("Crea un piano alimentare basato sul mio allenamento") }
                QuickButton("Come sto?") { sendQuickMessage("Analizza i miei dati di salute e dimmi come sto. Sono affaticato? Fammi un riassunto completo.") }
                QuickButton("Ottimizza piano") { sendQuickMessage("Vorrei ottimizzare il mio piano attuale") }
                QuickButton("Consigli recupero") { sendQuickMessage("Dammi consigli per il recupero") }
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
        appState.addMessage(text, isFromUser: true)

        Task {
            let response = await bobbyAI.generateResponse(
                to: text,
                userProfile: appState.userProfile,
                planManager: planManager,
                nutritionManager: nutritionManager,
                conversationHistory: appState.currentConversation?.messages ?? []
            )

            await MainActor.run {
                appState.addMessage(response, isFromUser: false)

                // Fallback: try to extract plan from text if tool didn't save it
                if planManager.currentActivePlan == nil,
                   let trainingPlan = bobbyAI.extractTrainingPlan(from: response, userProfile: appState.userProfile) {
                    planManager.savePlan(trainingPlan)
                }
            }
        }
    }

    private func askBobbyAboutPlan(_ plan: TrainingPlan) {
        var planText = "Cosa ne pensi di questo piano di allenamento?\n\n"
        planText += "\(plan.title)\n"
        for day in plan.weeklyPlan {
            if day.workoutType == .rest {
                planText += "\(day.dayOfWeek) — Riposo\n"
            } else {
                planText += "\(day.dayOfWeek) — \(day.workoutType.rawValue) · \(String(format: "%.1f", day.distance))km\n"
                if !day.description.isEmpty {
                    planText += "  \(day.description)\n"
                }
            }
        }
        sendQuickMessage(planText)
    }
}

// MARK: - Message Bubble View
struct MessageBubbleView: View {
    let message: ChatMessage
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 60)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .font(.body)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.bobbyRed)
                        .foregroundColor(.white)
                        .clipShape(BubbleShape(isFromUser: true))

                    Text(timeString(from: message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.bobbyWarmGray)
                        .padding(.trailing, 4)
                }
            } else {
                // Bobby avatar
                Image("BobbyLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(markdownAttributedString(from: message.content))
                        .font(.body)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(BobbyTheme.aiBubble(for: colorScheme))
                        .foregroundColor(BobbyTheme.primaryText(for: colorScheme))
                        .clipShape(BubbleShape(isFromUser: false))

                    Text(timeString(from: message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.bobbyWarmGray)
                        .padding(.leading, 4)
                }

                Spacer(minLength: 60)
            }
        }
    }

    private func markdownAttributedString(from text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let attributed = try? AttributedString(markdown: text, options: options) {
            return attributed
        }
        return AttributedString(text)
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Typing Indicator View
struct TypingIndicatorView: View {
    @State private var animating = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image("BobbyLogo")
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(Circle())

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.bobbyWarmGray)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animating ? 1.0 : 0.5)
                        .opacity(animating ? 1.0 : 0.4)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(BobbyTheme.aiBubble(for: colorScheme))
            .clipShape(BubbleShape(isFromUser: false))

            Spacer(minLength: 60)
        }
        .onAppear { animating = true }
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
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.bobbyRed.opacity(0.08))
                .foregroundColor(.bobbyRed)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.bobbyRed.opacity(0.15), lineWidth: 1)
                )
        }
    }
}

// MARK: - Training Plans Archive View
struct TrainingPlansArchiveView: View {
    @ObservedObject var planManager: TrainingPlanManager
    var onAskBobby: ((TrainingPlan) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let activePlan = planManager.currentActivePlan {
                        SectionHeader(title: "Piano Attivo")
                            .padding(.horizontal, 16)
                        TrainingPlanRowView(plan: activePlan, planManager: planManager, onAskBobby: onAskBobby)
                            .bobbyCard()
                            .padding(.horizontal, 16)
                    }

                    SectionHeader(title: "Archivio Piani")
                        .padding(.horizontal, 16)

                    let archivedPlans = planManager.savedPlans.filter { $0.id != planManager.currentActivePlan?.id }
                    if archivedPlans.isEmpty && planManager.currentActivePlan == nil {
                        VStack(spacing: 12) {
                            Image(systemName: "list.clipboard")
                                .font(.system(size: 40))
                                .foregroundColor(.bobbyWarmGray.opacity(0.5))
                            Text("Nessun piano salvato")
                                .font(.subheadline)
                                .foregroundColor(.bobbyWarmGray)
                        }
                        .padding(.top, 40)
                    } else {
                        ForEach(archivedPlans) { plan in
                            TrainingPlanRowView(plan: plan, planManager: planManager, onAskBobby: onAskBobby)
                                .bobbyCard()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .background(BobbyTheme.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Archivio Piani")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { dismiss() }
                        .foregroundColor(.bobbyRed)
                }
            }
        }
    }
}

// MARK: - Training Plan Row View
struct TrainingPlanRowView: View {
    let plan: TrainingPlan
    @ObservedObject var planManager: TrainingPlanManager
    var onAskBobby: ((TrainingPlan) -> Void)?
    @State private var showingDetails = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(plan.title)
                    .font(.headline)
                    .foregroundColor(.bobbyCharcoal)
                    .lineLimit(2)

                Spacer()

                if plan.id == planManager.currentActivePlan?.id {
                    Text("ATTIVO")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.bobbyRed.opacity(0.12))
                        .foregroundColor(.bobbyRed)
                        .clipShape(Capsule())
                }
            }

            let stats = planManager.getWeeklyStats(for: plan)
            HStack(spacing: 16) {
                Label("\(Int(stats.totalDistance))km", systemImage: "figure.run")
                Label("\(stats.workoutCount) allenamenti", systemImage: "calendar")
            }
            .font(.caption)
            .foregroundColor(.bobbyWarmGray)

            HStack(spacing: 8) {
                Button("Visualizza") { showingDetails = true }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.bobbyCaramel)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.bobbyCaramel.opacity(0.1))
                    .clipShape(Capsule())

                if plan.id != planManager.currentActivePlan?.id {
                    Button("Attiva") {
                        planManager.setActivePlan(plan)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.bobbyRed)
                    .clipShape(Capsule())
                }

                Spacer()

                Button { showingDeleteConfirm = true } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundColor(.bobbyWarmGray)
                        .padding(8)
                }
            }
        }
        .sheet(isPresented: $showingDetails) {
            TrainingPlanDetailView(planId: plan.id, planManager: planManager, onAskBobby: onAskBobby)
        }
        .alert("Eliminare questo piano?", isPresented: $showingDeleteConfirm) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) {
                planManager.deletePlan(plan)
            }
        } message: {
            Text("Questa azione non può essere annullata.")
        }
    }
}

// MARK: - Training Plan Detail View
struct TrainingPlanDetailView: View {
    let planId: UUID
    @ObservedObject var planManager: TrainingPlanManager
    var onAskBobby: ((TrainingPlan) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false

    private var plan: TrainingPlan? {
        planManager.savedPlans.first { $0.id == planId } ??
        (planManager.currentActivePlan?.id == planId ? planManager.currentActivePlan : nil)
    }

    var body: some View {
        NavigationView {
            Group {
                if let plan = plan {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Hero card
                            VStack(alignment: .leading, spacing: 10) {
                                Text(plan.title)
                                    .font(.title2.weight(.bold))
                                    .foregroundColor(.bobbyCharcoal)

                                let stats = planManager.getWeeklyStats(for: plan)
                                HStack(spacing: 20) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "figure.run")
                                            .foregroundColor(.bobbyRed)
                                        Text("\(Int(stats.totalDistance))km totali")
                                    }
                                    HStack(spacing: 6) {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.bobbyRed)
                                        Text("\(stats.workoutCount) allenamenti")
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.bobbyWarmGray)
                            }
                            .bobbyCard()
                            .padding(.horizontal, 16)

                            // Action buttons
                            HStack(spacing: 12) {
                                Button {
                                    onAskBobby?(plan)
                                } label: {
                                    Label("Chiedi a Bobby", systemImage: "bubble.left.fill")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.bobbyRed)
                                        .clipShape(RoundedRectangle(cornerRadius: BobbyTheme.cornerRadiusSmall))
                                }

                                Button { showingEdit = true } label: {
                                    Label("Modifica", systemImage: "pencil")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.bobbyCaramel)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.bobbyCaramel.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: BobbyTheme.cornerRadiusSmall))
                                }
                            }
                            .padding(.horizontal, 16)

                            // Weekly plan
                            SectionHeader(title: "Piano Settimanale")
                                .padding(.horizontal, 16)

                            ForEach(plan.weeklyPlan) { day in
                                DayTrainingRowView(dayTraining: day)
                                    .bobbyCard()
                                    .padding(.horizontal, 16)
                            }

                            // Delete button
                            Button { showingDeleteConfirm = true } label: {
                                Label("Elimina Piano", systemImage: "trash")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 16)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.questionmark")
                            .font(.system(size: 40))
                            .foregroundColor(.bobbyWarmGray.opacity(0.5))
                        Text("Piano non trovato")
                            .font(.subheadline)
                            .foregroundColor(.bobbyWarmGray)
                    }
                }
            }
            .background(BobbyTheme.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Dettagli Piano")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { dismiss() }
                        .foregroundColor(.bobbyRed)
                }
            }
            .sheet(isPresented: $showingEdit) {
                if let plan = plan {
                    TrainingPlanEditView(planManager: planManager, plan: plan)
                }
            }
            .alert("Eliminare questo piano?", isPresented: $showingDeleteConfirm) {
                Button("Annulla", role: .cancel) {}
                Button("Elimina", role: .destructive) {
                    if let plan = plan {
                        planManager.deletePlan(plan)
                    }
                    dismiss()
                }
            } message: {
                Text("Questa azione non può essere annullata.")
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
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.bobbyCharcoal)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: dayTraining.workoutType.sfSymbol)
                    Text(dayTraining.workoutType.rawValue)
                }
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(dayTraining.workoutType.color.opacity(0.12))
                .foregroundColor(dayTraining.workoutType.color)
                .clipShape(Capsule())
            }

            if dayTraining.distance > 0 {
                HStack(spacing: 12) {
                    Label("\(dayTraining.distance, specifier: "%.1f")km", systemImage: "figure.run")
                    Label("\(dayTraining.estimatedDuration)min", systemImage: "clock")
                }
                .font(.caption)
                .foregroundColor(.bobbyWarmGray)
            }

            if !dayTraining.description.isEmpty {
                Text(dayTraining.description)
                    .font(.caption)
                    .foregroundColor(.bobbyWarmGray)
                    .padding(.top, 2)
            }
        }
    }
}

// MARK: - Training Plan Edit View
struct TrainingPlanEditView: View {
    @ObservedObject var planManager: TrainingPlanManager
    @State var plan: TrainingPlan
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Titolo del piano", text: $plan.title)
                        .font(.headline)
                } header: {
                    Label("Titolo", systemImage: "pencil")
                        .foregroundColor(.bobbyRed)
                }

                ForEach($plan.weeklyPlan) { $day in
                    Section {
                        Picker("Tipo allenamento", selection: $day.workoutType) {
                            ForEach(WorkoutType.allCases, id: \.self) { type in
                                HStack {
                                    Image(systemName: type.sfSymbol)
                                    Text(type.rawValue)
                                }.tag(type)
                            }
                        }
                        .onChange(of: day.workoutType) { _, newValue in
                            if newValue == .rest {
                                day.distance = 0
                                day.estimatedDuration = 0
                                day.description = "Riposo completo."
                            }
                        }

                        if day.workoutType != .rest {
                            HStack {
                                Image(systemName: "figure.run")
                                    .foregroundColor(.bobbyCaramel)
                                    .frame(width: 28)
                                Text("Distanza (km)")
                                Spacer()
                                TextField("0", value: $day.distance, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .keyboardType(.decimalPad)
                            }

                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.bobbyCaramel)
                                    .frame(width: 28)
                                Text("Durata (min)")
                                Spacer()
                                TextField("0", value: $day.estimatedDuration, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .keyboardType(.numberPad)
                            }

                            TextField("Descrizione allenamento", text: $day.description, axis: .vertical)
                                .lineLimit(2...5)
                        }
                    } header: {
                        HStack {
                            Text(day.dayOfWeek)
                            Spacer()
                            if day.workoutType != .rest {
                                Text("\(String(format: "%.1f", day.distance))km")
                                    .font(.caption)
                                    .foregroundColor(.bobbyWarmGray)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BobbyTheme.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Modifica Piano")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") { dismiss() }
                        .foregroundColor(.bobbyWarmGray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        plan.lastModified = Date()
                        planManager.savePlan(plan)
                        if planManager.currentActivePlan?.id == plan.id {
                            planManager.setActivePlan(plan)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.bobbyRed)
                }
            }
        }
    }
}

// MARK: - Runner Profile View
struct RunnerProfileView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "road.lanes")
                            .foregroundColor(.bobbyCaramel)
                            .frame(width: 28)
                        Text("Km alla settimana")
                        Spacer()
                        TextField("20", value: $appState.userProfile.weeklyKilometers, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.bobbyCaramel)
                            .frame(width: 28)
                        Stepper("Allenamenti/sett: \(appState.userProfile.workoutsPerWeek)", value: $appState.userProfile.workoutsPerWeek, in: 1...7)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "speedometer")
                            .foregroundColor(.bobbyCaramel)
                            .frame(width: 28)
                        Text("Ritmo attuale")
                        Spacer()
                        TextField("5:30", text: $appState.userProfile.currentPace)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "scalemass.fill")
                            .foregroundColor(.bobbyCaramel)
                            .frame(width: 28)
                        Text("Peso (kg)")
                        Spacer()
                        TextField("70", value: $appState.userProfile.weight, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Label("Allenamento Attuale", systemImage: "figure.run")
                        .foregroundColor(.bobbyRed)
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "flag.fill")
                            .foregroundColor(.bobbyCaramel)
                            .frame(width: 28)
                        Picker("Obiettivo principale", selection: $appState.userProfile.primaryGoal) {
                            ForEach(TrainingGoal.allCases, id: \.self) { goal in
                                Text(goal.rawValue).tag(goal)
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.bobbyCaramel)
                            .frame(width: 28)
                        Picker("Livello esperienza", selection: $appState.userProfile.experience) {
                            ForEach(ExperienceLevel.allCases, id: \.self) { level in
                                Text(level.rawValue).tag(level)
                            }
                        }
                    }
                } header: {
                    Label("Obiettivi", systemImage: "target")
                        .foregroundColor(.bobbyRed)
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "flag.checkered")
                            .foregroundColor(.bobbyCaramel)
                            .frame(width: 28)
                        Picker("Distanza gara", selection: $appState.userProfile.raceDistance) {
                            Text("Nessuna gara specifica").tag(nil as RaceDistance?)
                            ForEach(RaceDistance.allCases, id: \.self) { distance in
                                Text(distance.rawValue).tag(distance as RaceDistance?)
                            }
                        }
                    }
                } header: {
                    Label("Gara Obiettivo", systemImage: "medal.fill")
                        .foregroundColor(.bobbyRed)
                }
            }
            .scrollContentBackground(.hidden)
            .background(BobbyTheme.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Il Tuo Profilo Runner")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") { dismiss() }
                        .foregroundColor(.bobbyWarmGray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        appState.saveUserProfile()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.bobbyRed)
                }
            }
        }
    }
}

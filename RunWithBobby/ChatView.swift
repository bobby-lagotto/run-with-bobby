import SwiftUI

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var bobbyAI: BobbyAI
    @EnvironmentObject var planManager: TrainingPlanManager
    @EnvironmentObject var healthManager: HealthKitManager
    @EnvironmentObject var nutritionManager: NutritionPlanManager
    @EnvironmentObject var habitCoordinator: HabitCoordinator
    @EnvironmentObject var aiSettings: AISettings
    @Environment(\.colorScheme) var colorScheme

    @State private var messageText = ""
    @State private var showingPlansArchive = false
    @State private var showingProfileSetup = false
    @State private var showingSettings = false
    @State private var showingConversationHistory = false
    @State private var showingNutritionPlan = false
    @State private var showingToday = false
    @State private var showingSources = false
    @State private var showingDeleteDataConfirm = false
    @State private var showingCloudHealthConfirm = false
    @State private var pendingCloudHealthMessage: String?
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
            .sheet(isPresented: $showingSources) {
                SourcesView()
            }
            .sheet(isPresented: $showingToday) {
                NavigationView {
                    TodayView(onTalkToBobby: { showingToday = false })
                }
            }
            .alert(L10n.tr("Cancellare i dati locali?", english: "Delete local data?"), isPresented: $showingDeleteDataConfirm) {
                Button(L10n.tr("Annulla", english: "Cancel"), role: .cancel) {}
                Button(L10n.tr("Cancella", english: "Delete"), role: .destructive) {
                    deleteLocalUserData()
                }
            } message: {
                Text(L10n.tr(
                    "Verranno rimossi chat, profilo runner, piani di allenamento e piani alimentari salvati su questo dispositivo. Le API key restano nel Keychain e puoi rimuoverle dalle impostazioni AI.",
                    english: "Chat, runner profile, training plans and nutrition plans saved on this device will be removed. API keys stay in the Keychain and you can remove them from AI Settings."
                ))
            }
            .alert(L10n.tr("Inviare riepilogo Health al provider cloud?", english: "Send Health summary to the cloud provider?"), isPresented: $showingCloudHealthConfirm) {
                Button(L10n.tr("Annulla", english: "Cancel"), role: .cancel) {
                    pendingCloudHealthMessage = nil
                }
                Button(L10n.tr("Continua", english: "Continue")) {
                    if let message = pendingCloudHealthMessage {
                        pendingCloudHealthMessage = nil
                        sendMessageToBobby(message)
                    }
                }
            } message: {
                Text(L10n.tr(
                    "Per questa richiesta Bobby potrebbe leggere un riepilogo Apple Health e inviarlo al provider cloud selezionato insieme al contesto della chat. Usa il provider Locale per restare on-device.",
                    english: "For this request Bobby may read an Apple Health summary and send it to the selected cloud provider with the chat context. Use the On-device provider to stay on-device."
                ))
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
                        Text(bobbyAI.streamingText.isEmpty ? L10n.tr("Sta pensando...", english: "Thinking...") : L10n.tr("Sta scrivendo...", english: "Writing..."))
                            .font(.caption)
                            .foregroundColor(.bobbyWarmGray)
                    } else {
                        HStack(spacing: 4) {
                            Text(L10n.tr("Il tuo running coach", english: "Your running coach"))
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
                        Label(L10n.tr("Archivio Piani", english: "Plan archive"), systemImage: "list.clipboard")
                    }
                    Button(action: { showingNutritionPlan = true }) {
                        Label(L10n.tr("Piano Alimentare", english: "Nutrition plan"), systemImage: "fork.knife")
                    }
                    Button(action: { showingSources = true }) {
                        Label(L10n.tr("Fonti", english: "Sources"), systemImage: "book.closed")
                    }
                    Button(action: { showingConversationHistory = true }) {
                        Label(L10n.tr("Storico Chat", english: "Chat history"), systemImage: "clock.arrow.circlepath")
                    }
                    Button(action: { showingProfileSetup = true }) {
                        Label(L10n.tr("Profilo Runner", english: "Runner profile"), systemImage: "person.crop.circle")
                    }
                    Button(action: { showingSettings = true }) {
                        Label(L10n.tr("Impostazioni AI", english: "AI Settings"), systemImage: "gearshape")
                    }
                    Button(action: { appState.startNewConversation() }) {
                        Label(L10n.tr("Nuova Chat", english: "New chat"), systemImage: "plus.bubble")
                    }
                    Button(role: .destructive, action: { showingDeleteDataConfirm = true }) {
                        Label(L10n.tr("Cancella dati locali", english: "Delete local data"), systemImage: "trash")
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
                    StatPill(icon: "calendar", value: L10n.format("%d allenamenti", english: "%d workouts", appState.userProfile.workoutsPerWeek))
                    StatPill(icon: "target", value: appState.userProfile.primaryGoal.displayName)
                }
            }

            if habitCoordinator.today.hasActivePlan {
                todayStrip
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
                    .onTapGesture { showingToday = true }
                }

                if nutritionManager.currentNutritionPlan != nil {
                    HStack(spacing: 6) {
                        Image(systemName: "fork.knife")
                            .font(.caption)
                        Text(L10n.tr("Alimentare", english: "Nutrition"))
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
                    TextField(L10n.tr("Scrivi a Bobby...", english: "Write to Bobby..."), text: $messageText, axis: .vertical)
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
                QuickButton(L10n.tr("Sono un principiante", english: "I'm a beginner")) {
                    sendQuickMessage(L10n.tr(
                        "Sono un principiante, voglio iniziare a correre",
                        english: "I'm a beginner, I want to start running"
                    ))
                }
                QuickButton(L10n.tr("Corro già 20km/sett", english: "I already run 20km/week")) {
                    sendQuickMessage(L10n.tr(
                        "Corro già circa 20km alla settimana",
                        english: "I already run about 20km a week"
                    ))
                }
                QuickButton(L10n.tr("Voglio correre una 10K", english: "I want to run a 10K")) {
                    sendQuickMessage(L10n.tr(
                        "Il mio obiettivo è correre una 10K",
                        english: "My goal is to run a 10K"
                    ))
                }
                QuickButton(L10n.tr("Voglio perdere peso", english: "I want to lose weight")) {
                    sendQuickMessage(L10n.tr(
                        "Voglio correre per perdere peso",
                        english: "I want to run to lose weight"
                    ))
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Quick Action Buttons
    private var quickActionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                QuickButton(L10n.tr("Nuovo piano", english: "New plan")) {
                    sendQuickMessage(L10n.tr(
                        "Crea un nuovo piano di allenamento per me",
                        english: "Create a new training plan for me"
                    ))
                }
                QuickButton(L10n.tr("Piano alimentare", english: "Nutrition plan")) {
                    sendQuickMessage(L10n.tr(
                        "Crea un piano alimentare basato sul mio allenamento",
                        english: "Create a nutrition plan based on my training"
                    ))
                }
                QuickButton(L10n.tr("Cosa faccio oggi?", english: "What do I do today?")) {
                    sendQuickMessage(L10n.tr(
                        "Cosa faccio oggi? Usa il briefing e l'aderenza.",
                        english: "What do I do today? Use the briefing and adherence."
                    ))
                }
                QuickButton(L10n.tr("Come sto?", english: "How am I?")) {
                    sendQuickMessage(L10n.tr(
                        "Analizza i miei dati di salute e dimmi come sto. Sono affaticato? Fammi un riassunto completo.",
                        english: "Analyze my health data and tell me how I am. Am I fatigued? Give me a full summary."
                    ))
                }
                QuickButton(L10n.tr("Ottimizza piano", english: "Optimize plan")) {
                    sendQuickMessage(L10n.tr(
                        "Vorrei ottimizzare il mio piano attuale",
                        english: "I'd like to optimize my current plan"
                    ))
                }
                QuickButton(L10n.tr("Consigli recupero", english: "Recovery tips")) {
                    sendQuickMessage(L10n.tr(
                        "Dammi consigli per il recupero",
                        english: "Give me recovery advice"
                    ))
                }
            }
            .padding(.horizontal)
        }
    }

    private var todayStrip: some View {
        let state = habitCoordinator.today
        return HStack(spacing: 8) {
            Image(systemName: "sun.max.fill")
                .foregroundColor(.bobbyCaramel)
            Text(state.workoutType)
                .font(.caption.weight(.semibold))
            Text("·")
            Text(state.sessionStatus.localizedLabel)
                .font(.caption)
            if state.plannedKm > 0 {
                Text(String(format: "· %.1f km", state.plannedKm))
                    .font(.caption)
            }
            Spacer()
            Text(state.recommendation.localizedLabel)
                .font(.caption.weight(.medium))
                .foregroundColor(.bobbyRed)
        }
        .foregroundColor(BobbyTheme.secondaryText(for: colorScheme))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(BobbyTheme.cardBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { showingToday = true }
    }

    // MARK: - Helper Methods
    private func showWelcomeMessage() {
        let welcomeMessage = L10n.tr(
            """
            Ciao, ho già il tuo profilo.
            Dimmi cosa ti serve: un piano, come stai, cosa fare oggi o cosa mangiare.
            """,
            english: """
            Hi — I already have your profile.
            Tell me what you need: a plan, how you're feeling, what to do today or what to eat.
            """
        )

        appState.addMessage(welcomeMessage, isFromUser: false)
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if shouldConfirmCloudHealthSend(for: text) {
            pendingCloudHealthMessage = text
            showingCloudHealthConfirm = true
            return
        }

        sendMessageToBobby(text)
        messageText = ""
    }

    private func sendQuickMessage(_ text: String) {
        if shouldConfirmCloudHealthSend(for: text) {
            pendingCloudHealthMessage = text
            showingCloudHealthConfirm = true
            return
        }

        sendMessageToBobby(text)
    }

    private func sendMessageToBobby(_ text: String) {
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
            }
        }
    }

    private func shouldConfirmCloudHealthSend(for text: String) -> Bool {
        guard healthConnected, isCloudProviderActive else { return false }
        let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
        return ["salute", "health", "come sto", "affatic", "recuper", "sonno", "hrv", "battit", "frequenza", "stress", "vo2", "spo2"].contains {
            normalized.contains($0)
        }
    }

    private var isCloudProviderActive: Bool {
        switch aiSettings.providerType {
        case .openai:
            return aiSettings.hasOpenAIKey
        case .anthropic:
            return aiSettings.hasAnthropicKey
        case .openrouter:
            return aiSettings.hasOpenRouterKey
        case .auto:
            return !aiSettings.isLocalAvailable && (aiSettings.hasAnthropicKey || aiSettings.hasOpenAIKey || aiSettings.hasOpenRouterKey)
        case .local:
            return false
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

    private func deleteLocalUserData() {
        appState.deleteLocalUserData()
        planManager.deleteAllPlans()
        nutritionManager.deleteAllPlans()
        UserDefaults.standard.set(false, forKey: "healthkit_connected")
        healthConnected = false
        bobbyAI.configure(with: aiSettings, healthManager: nil)
        habitCoordinator.refresh(plan: nil)
        showWelcomeMessage()
    }
}

// MARK: - Coach bubble markdown
/// Parses inline Markdown only when needed. Foundation's markdown renderer can
/// drop spaces on plain coach copy (health recap, fallback), so those stay as `Text`.
enum ChatMarkdown {
    static func containsInlineMarkup(_ text: String) -> Bool {
        if text.contains("**") || text.contains("`") { return true }
        if text.contains("*") { return true }
        return hasMarkdownLink(text)
    }

    static func attributedString(from text: String) -> AttributedString {
        guard containsInlineMarkup(text) else {
            return AttributedString(text)
        }
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        guard let attributed = try? AttributedString(markdown: text, options: options) else {
            return AttributedString(text)
        }
        let originalSpaces = spaceCount(text)
        let parsedSpaces = spaceCount(String(attributed.characters))
        if originalSpaces > 0 && parsedSpaces * 10 < originalSpaces * 8 {
            return AttributedString(text)
        }
        return attributed
    }

    static func spaceCount(_ text: String) -> Int {
        text.reduce(0) { $0 + ($1 == " " ? 1 : 0) }
    }

    private static func hasMarkdownLink(_ text: String) -> Bool {
        guard let bracket = text.range(of: "](") else { return false }
        return text[..<bracket.lowerBound].contains("[")
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
                    coachBubbleText(message.content)
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

    @ViewBuilder
    private func coachBubbleText(_ text: String) -> some View {
        if ChatMarkdown.containsInlineMarkup(text) {
            Text(ChatMarkdown.attributedString(from: text))
        } else {
            Text(text)
        }
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.locale
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
                            Text(L10n.tr("Nessun piano salvato", english: "No saved plans"))
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
            .navigationTitle(L10n.tr("Archivio Piani", english: "Plan archive"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.tr("Chiudi", english: "Close")) { dismiss() }
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
                    Text(L10n.tr("ATTIVO", english: "ACTIVE"))
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
                Button(L10n.tr("Visualizza", english: "View")) { showingDetails = true }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.bobbyCaramel)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.bobbyCaramel.opacity(0.1))
                    .clipShape(Capsule())

                if plan.id != planManager.currentActivePlan?.id {
                    Button(L10n.tr("Attiva", english: "Activate")) {
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
        .alert(L10n.tr("Eliminare questo piano?", english: "Delete this plan?"), isPresented: $showingDeleteConfirm) {
            Button(L10n.tr("Annulla", english: "Cancel"), role: .cancel) {}
            Button(L10n.tr("Elimina", english: "Delete"), role: .destructive) {
                planManager.deletePlan(plan)
            }
        } message: {
            Text(L10n.tr("Questa azione non può essere annullata.", english: "This action cannot be undone."))
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
                                    Label(L10n.tr("Chiedi a Bobby", english: "Ask Bobby"), systemImage: "bubble.left.fill")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.bobbyRed)
                                        .clipShape(RoundedRectangle(cornerRadius: BobbyTheme.cornerRadiusSmall))
                                }

                                Button { showingEdit = true } label: {
                                    Label(L10n.tr("Modifica", english: "Edit"), systemImage: "pencil")
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
                                Label(L10n.tr("Elimina Piano", english: "Delete plan"), systemImage: "trash")
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
            .navigationTitle(L10n.tr("Dettagli Piano", english: "Plan details"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !AppStoreScreenshotMode.isEnabled {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(L10n.tr("Chiudi", english: "Close")) { dismiss() }
                            .foregroundColor(.bobbyRed)
                    }
                }
            }
            .sheet(isPresented: $showingEdit) {
                if let plan = plan {
                    TrainingPlanEditView(planManager: planManager, plan: plan)
                }
            }
            .alert(L10n.tr("Eliminare questo piano?", english: "Delete this plan?"), isPresented: $showingDeleteConfirm) {
                Button(L10n.tr("Annulla", english: "Cancel"), role: .cancel) {}
                Button(L10n.tr("Elimina", english: "Delete"), role: .destructive) {
                    if let plan = plan {
                        planManager.deletePlan(plan)
                    }
                    dismiss()
                }
            } message: {
                Text(L10n.tr("Questa azione non può essere annullata.", english: "This action cannot be undone."))
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
                    Text(dayTraining.workoutType.displayName)
                    Text("·")
                    Text(dayTraining.sessionStatus.localizedLabel)
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
                                    Text(type.displayName)
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
            .navigationTitle(L10n.tr("Modifica Piano", english: "Edit plan"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.tr("Annulla", english: "Cancel")) { dismiss() }
                        .foregroundColor(.bobbyWarmGray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.tr("Salva", english: "Save")) {
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

// MARK: - Runner Profile Form
struct RunnerProfileForm: View {
    @Binding var profile: RunnerProfile

    var body: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "road.lanes")
                    .foregroundColor(.bobbyCaramel)
                    .frame(width: 28)
                Text(L10n.tr("Km alla settimana", english: "Km per week"))
                Spacer()
                TextField("20", value: $profile.weeklyKilometers, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }

            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.bobbyCaramel)
                    .frame(width: 28)
                Stepper(L10n.format("Allenamenti/sett: %d", english: "Workouts/week: %d", profile.workoutsPerWeek), value: $profile.workoutsPerWeek, in: 1...7)
            }

            HStack(spacing: 12) {
                Image(systemName: "speedometer")
                    .foregroundColor(.bobbyCaramel)
                    .frame(width: 28)
                Text(L10n.tr("Ritmo attuale", english: "Current pace"))
                Spacer()
                TextField("5:30", text: $profile.currentPace)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }

            HStack(spacing: 12) {
                Image(systemName: "scalemass.fill")
                    .foregroundColor(.bobbyCaramel)
                    .frame(width: 28)
                Text(L10n.tr("Peso (kg)", english: "Weight (kg)"))
                Spacer()
                TextField("70", value: $profile.weight, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
            }
        } header: {
            Label(L10n.tr("Allenamento Attuale", english: "Current training"), systemImage: "figure.run")
                .foregroundColor(.bobbyRed)
        }

        Section {
            HStack(spacing: 12) {
                Image(systemName: "flag.fill")
                    .foregroundColor(.bobbyCaramel)
                    .frame(width: 28)
                Picker(L10n.tr("Obiettivo principale", english: "Main goal"), selection: $profile.primaryGoal) {
                    ForEach(TrainingGoal.allCases, id: \.self) { goal in
                        Text(goal.displayName).tag(goal)
                    }
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.bobbyCaramel)
                    .frame(width: 28)
                Picker(L10n.tr("Livello esperienza", english: "Experience level"), selection: $profile.experience) {
                    ForEach(ExperienceLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
            }
        } header: {
            Label(L10n.tr("Obiettivi", english: "Goals"), systemImage: "target")
                .foregroundColor(.bobbyRed)
        }

        Section {
            HStack(spacing: 12) {
                Image(systemName: "flag.checkered")
                    .foregroundColor(.bobbyCaramel)
                    .frame(width: 28)
                Picker(L10n.tr("Distanza gara", english: "Race distance"), selection: $profile.raceDistance) {
                    Text(L10n.tr("Nessuna gara specifica", english: "No specific race")).tag(nil as RaceDistance?)
                    ForEach(RaceDistance.allCases, id: \.self) { distance in
                        Text(distance.rawValue).tag(distance as RaceDistance?)
                    }
                }
            }
        } header: {
            Label(L10n.tr("Gara Obiettivo", english: "Target race"), systemImage: "medal.fill")
                .foregroundColor(.bobbyRed)
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
                RunnerProfileForm(profile: $appState.userProfile)
            }
            .scrollContentBackground(.hidden)
            .background(BobbyTheme.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle(L10n.tr("Il Tuo Profilo Runner", english: "Your runner profile"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.tr("Annulla", english: "Cancel")) { dismiss() }
                        .foregroundColor(.bobbyWarmGray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.tr("Salva", english: "Save")) {
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

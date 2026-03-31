import Foundation

@MainActor
class BobbyAI: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var activeProviderName: String = ""
    @Published var streamingText: String = ""

    private var aiSettings: AISettings?
    private var openAIProvider: OpenAIProvider?
    private var anthropicProvider: AnthropicProvider?
    private(set) var mlxProvider: MLXProvider
    private var healthManager: HealthKitManager?

    private let toolRouter = ToolRouter()
    private let maxToolIterations = 3

    init() {
        self.mlxProvider = MLXProvider()
    }

    private let systemPrompt = """
    Sei Bobby, un coach di corsa esperto e motivante. Parli italiano. Sei specializzato nella creazione di piani di allenamento personalizzati per runner di ogni livello.

    Le tue caratteristiche:
    - Comunicazione diretta, concisa e motivante
    - Conoscenza approfondita dell'allenamento della corsa
    - Capacità di adattare i piani in base al livello e agli obiettivi
    - Attenzione alla progressione graduale e alla prevenzione infortuni

    REGOLE IMPORTANTI — SEGUI SEMPRE:

    == TOOL DI LETTURA (usa liberamente, senza chiedere) ==
    1. Usa "get_user_profile" per avere i dati aggiornati dell'utente prima di fare proposte.
    2. Usa "get_active_plan" per vedere il piano di allenamento attivo.
    3. Usa "get_health_summary" per leggere i dati di salute da Apple Health quando l'utente chiede informazioni su salute, affaticamento o recupero.
    4. Usa "get_nutrition_plan" per vedere il piano alimentare attivo.

    == CALCOLO E PROPOSTA (calcola, mostra, poi CHIEDI CONFERMA) ==
    5. Quando l'utente chiede di creare un piano di allenamento: chiama "get_user_profile", poi "calculate_training_plan" per calcolare una proposta. Presentala in formato chiaro (GIORNO — Tipo · Xkm + descrizione). Poi CHIEDI ALL'UTENTE: "Ti piace questo piano? Vuoi che lo salvi, o preferisci delle modifiche?"
    6. Quando l'utente chiede un piano alimentare: chiama "calculate_nutrition_plan" per calcolare una proposta. Presentala con grammi per macro per ogni giorno (GIORNO (intensità) — Proteine Xg · Carboidrati Xg · Verdure/Frutta Xg · Dolci Xg). Poi CHIEDI ALL'UTENTE: "Va bene così? Vuoi che lo salvi?"
    7. Per ottimizzare il piano attivo: descrivi cosa cambieresti e CHIEDI CONFERMA prima di chiamare "optimize_plan".

    == SALVATAGGIO (SOLO dopo conferma esplicita dell'utente) ==
    8. Chiama "save_training_plan" SOLO quando l'utente conferma esplicitamente (es: "sì", "salvalo", "ok", "perfetto", "va bene").
    9. Chiama "save_nutrition_plan" SOLO quando l'utente conferma esplicitamente.
    10. Chiama "optimize_plan" SOLO quando l'utente conferma la modifica proposta.
    11. NON salvare, ottimizzare o modificare nulla senza conferma esplicita dell'utente.

    == AGGIORNAMENTI COLLEGATI ==
    12. Quando salvi o ottimizzi un piano di allenamento e esiste un piano alimentare attivo, AVVISA l'utente: "Il piano di allenamento è cambiato. Vuoi che aggiorni anche il piano alimentare?" NON aggiornarlo automaticamente.

    == ANALISI SALUTE ==
    13. Quando analizzi i dati Health, sii specifico: cita i numeri reali e spiega cosa significano. Es: "La tua FC a riposo è 55bpm, ottimo indicatore di fitness cardiovascolare."
    14. Se i dati mostrano sovrallenamento (FC riposo alta, HRV basso, scarso sonno), suggerisci recupero e proponi di ridurre l'intensità — ma CHIEDI CONFERMA prima di modificare il piano.

    Rispondi SEMPRE in italiano. Sii conciso ma motivante. Ricorda: SEI UN COACH CHE PROPONE, NON CHE DECIDE. L'utente ha sempre l'ultima parola.
    """

    // MARK: - Setup

    func configure(with settings: AISettings, healthManager: HealthKitManager? = nil) {
        self.aiSettings = settings
        self.healthManager = healthManager
        updateProvider()
    }

    func updateProvider() {
        guard let settings = aiSettings else { return }

        // Setup OpenAI provider if API key available
        if let apiKey = settings.openAIAPIKey, !apiKey.isEmpty {
            openAIProvider = OpenAIProvider(apiKey: apiKey, model: settings.openAIModel)
        } else {
            openAIProvider = nil
        }

        // Setup Anthropic provider if API key available
        if let apiKey = settings.anthropicAPIKey, !apiKey.isEmpty {
            anthropicProvider = AnthropicProvider(apiKey: apiKey, model: settings.anthropicModel)
        } else {
            anthropicProvider = nil
        }

        // Update active provider name
        if let provider = resolveProvider() {
            activeProviderName = provider.providerName
        } else {
            activeProviderName = "Nessun provider"
        }
    }

    private func resolveProvider() -> LLMService? {
        guard let settings = aiSettings else { return openAIProvider ?? anthropicProvider }

        switch settings.providerType {
        case .local:
            return settings.isModelDownloaded ? mlxProvider : nil
        case .openai:
            return openAIProvider
        case .anthropic:
            return anthropicProvider
        case .auto:
            // Priority: local -> anthropic -> openai
            if settings.isModelDownloaded {
                return mlxProvider
            }
            if let anthropic = anthropicProvider, anthropic.isAvailable {
                return anthropic
            }
            return openAIProvider
        }
    }

    // MARK: - Generate Response (Agent Loop)

    func generateResponse(
        to userMessage: String,
        userProfile: RunnerProfile,
        planManager: TrainingPlanManager,
        nutritionManager: NutritionPlanManager? = nil,
        conversationHistory: [ChatMessage]
    ) async -> String {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
            streamingText = ""
        }

        guard let provider = resolveProvider() else {
            let error = LLMError.noProviderAvailable
            self.errorMessage = error.errorDescription
            return "⚙️ Per iniziare, configura il tuo assistente AI nelle impostazioni.\n\nPuoi:\n• Inserire la tua API key OpenAI o Anthropic\n• Scaricare un modello locale\n\nTocca il menu ⋯ in alto a destra → Impostazioni AI"
        }

        // Load local model into memory on-demand
        let usingLocalModel = provider is MLXProvider
        if usingLocalModel && !mlxProvider.isAvailable {
            await mlxProvider.loadIfAvailable()
            guard mlxProvider.isAvailable else {
                self.errorMessage = "Impossibile caricare il modello locale."
                return "❌ Non riesco a caricare il modello locale. Prova a riscaricarlo dalle impostazioni."
            }
        }

        defer {
            // Free memory after generation
            if usingLocalModel {
                mlxProvider.unloadModel()
            }
        }

        // Build conversation messages
        var messages = buildMessages(userMessage: userMessage, userProfile: userProfile, nutritionManager: nutritionManager, conversationHistory: conversationHistory)

        // Agent loop: generate (streaming) → tool calls → execute → re-generate
        for iteration in 0..<maxToolIterations {
            do {
                streamingText = ""

                var fullResponse: LLMResponse?
                for try await event in provider.generateStream(messages: messages, toolDefinitions: ToolRouter.toolDefinitions) {
                    switch event {
                    case .textDelta(let delta):
                        streamingText += delta
                    case .done(let response):
                        fullResponse = response
                    }
                }

                guard let response = fullResponse else {
                    return streamingText.isEmpty ? "Mi scuso, non ho ricevuto risposta." : streamingText
                }

                // If no tool calls, return the text response
                if response.toolCalls.isEmpty {
                    return response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                }

                // Tool calls detected — clear streaming text during tool processing
                streamingText = ""

                // Execute tool calls
                var toolResults: [ToolResult] = []
                for toolCall in response.toolCalls {
                    let result = await toolRouter.execute(toolCall, userProfile: userProfile, planManager: planManager, nutritionManager: nutritionManager, healthManager: healthManager)
                    toolResults.append(result)

                    #if DEBUG
                    print("🔧 Tool call: \(toolCall.name) → \(result.content.prefix(200))")
                    #endif
                }

                // Append assistant message WITH tool_calls (required by OpenAI API)
                let assistantContent = response.text
                messages.append(LLMMessage(
                    role: .assistant,
                    content: assistantContent,
                    toolCalls: response.toolCalls
                ))

                // Append tool results as tool messages with matching IDs
                for result in toolResults {
                    messages.append(LLMMessage(
                        role: .tool,
                        content: result.content,
                        toolCallId: result.toolCallId
                    ))
                }

                // Last iteration: force a final response
                if iteration == maxToolIterations - 1 {
                    messages.append(LLMMessage(
                        role: .system,
                        content: "Hai già usato gli strumenti. Ora rispondi all'utente con i risultati ottenuti. Non chiamare altri strumenti."
                    ))
                }

            } catch {
                #if DEBUG
                print("❌ LLM Error: \(error)")
                #endif

                streamingText = ""

                // Try fallback to cloud providers if we were using local
                if let settings = aiSettings, settings.providerType == .auto || settings.providerType == .local {
                    let candidates: [LLMService?] = [anthropicProvider, openAIProvider]
                    let fallbackProviders = candidates.compactMap { $0 }.filter { $0.isAvailable }
                    for fallback in fallbackProviders {
                        do {
                            for try await event in fallback.generateStream(messages: messages, toolDefinitions: ToolRouter.toolDefinitions) {
                                switch event {
                                case .textDelta(let delta):
                                    streamingText += delta
                                case .done(let response):
                                    if response.toolCalls.isEmpty {
                                        return response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                                    }
                                }
                            }
                        } catch {
                            streamingText = ""
                            continue // Try next fallback
                        }
                    }
                }

                self.errorMessage = error.localizedDescription
                return "Mi dispiace, ho avuto un problema tecnico. \(error.localizedDescription)"
            }
        }

        return "Mi scuso, non sono riuscito a completare la richiesta. Riprova!"
    }

    // MARK: - Message Building

    private func buildMessages(userMessage: String, userProfile: RunnerProfile, nutritionManager: NutritionPlanManager?, conversationHistory: [ChatMessage]) -> [LLMMessage] {
        var messages: [LLMMessage] = []

        // System prompt with tool descriptions and user profile context
        let profileContext = """

        PROFILO UTENTE ATTUALE:
        - Km settimanali: \(Int(userProfile.weeklyKilometers))
        - Allenamenti/settimana: \(userProfile.workoutsPerWeek)
        - Obiettivo: \(userProfile.primaryGoal.rawValue)
        - Ritmo attuale: \(userProfile.currentPace) min/km
        - Esperienza: \(userProfile.experience.rawValue)
        - Gara obiettivo: \(userProfile.raceDistance?.rawValue ?? "Nessuna")
        - Peso: \(userProfile.weight.map { "\(Int($0))kg" } ?? "non impostato (default 70kg)")
        """

        var healthContext = ""
        if let hm = healthManager, hm.isAvailable {
            healthContext = """

            APPLE HEALTH: Disponibile. Puoi usare il tool "get_health_summary" per leggere i dati reali di salute dell'utente (frequenza cardiaca, HRV, passi, sonno, allenamenti, VO2 Max). Usa questo tool quando l'utente chiede analisi della salute o dello stato fisico.
            """
        } else {
            healthContext = "\n\n    APPLE HEALTH: Non disponibile su questo dispositivo."
        }

        var nutritionContext = ""
        if let nm = nutritionManager, let plan = nm.currentNutritionPlan {
            nutritionContext = "\n\n    PIANO ALIMENTARE ATTIVO: \"\(plan.title)\" — collegato al piano di allenamento. Si aggiorna automaticamente quando il piano di allenamento cambia."
        } else {
            nutritionContext = "\n\n    PIANO ALIMENTARE: Nessun piano alimentare attivo. L'utente può chiedertene uno."
        }

        let fullSystemPrompt = systemPrompt + profileContext + healthContext + nutritionContext + "\n\n" + ToolRouter.toolDescriptionsForPrompt
        messages.append(LLMMessage(role: .system, content: fullSystemPrompt))

        // Conversation history (last 20 messages to stay within context)
        let recentHistory = conversationHistory.suffix(20)
        for msg in recentHistory {
            messages.append(LLMMessage(
                role: msg.isFromUser ? .user : .assistant,
                content: msg.content
            ))
        }

        // Current user message
        messages.append(LLMMessage(role: .user, content: userMessage))

        return messages
    }

    // MARK: - Text Plan Extraction (fallback parser for saving plans from LLM text output)

    func extractTrainingPlan(from response: String, userProfile: RunnerProfile) -> TrainingPlan? {
        let days = ["LUNEDÌ", "MARTEDÌ", "MERCOLEDÌ", "GIOVEDÌ", "VENERDÌ", "SABATO", "DOMENICA"]
        var weeklyPlan: [DayTraining] = []

        for day in days {
            if let dayInfo = extractDayInfo(from: response, dayName: day) {
                weeklyPlan.append(dayInfo)
            }
        }

        if weeklyPlan.count >= 3 {
            let title = extractPlanTitle(from: response)
            return TrainingPlan(title: title, weeklyPlan: weeklyPlan, userProfile: userProfile)
        }

        return nil
    }

    private func extractDayInfo(from text: String, dayName: String) -> DayTraining? {
        let lines = text.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            if line.contains(dayName) {
                let workoutLine = line.replacingOccurrences(of: "*", with: "")
                let components = workoutLine.components(separatedBy: "—")

                if components.count >= 2 {
                    let workoutInfo = components[1].trimmingCharacters(in: .whitespaces)
                    let workoutType = determineWorkoutType(from: workoutInfo)
                    let distance = extractDistance(from: workoutInfo)

                    var description = ""
                    for i in (index + 1)..<min(index + 5, lines.count) {
                        let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty && !trimmed.hasPrefix("**") && !trimmed.hasPrefix("LUNED")
                            && !trimmed.hasPrefix("MARTED") && !trimmed.hasPrefix("MERCOLED")
                            && !trimmed.hasPrefix("GIOVED") && !trimmed.hasPrefix("VENERD")
                            && !trimmed.hasPrefix("SABATO") && !trimmed.hasPrefix("DOMENIC") {
                            description += trimmed + "\n"
                        } else if trimmed.hasPrefix("**") || days.contains(where: { trimmed.contains($0) }) {
                            break
                        }
                    }

                    return DayTraining(
                        dayOfWeek: dayName,
                        workoutType: workoutType,
                        description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                        distance: distance,
                        estimatedDuration: distance > 0 ? Int(distance * 6) : 0,
                        paceZones: []
                    )
                }
            }
        }

        return nil
    }

    private let days = ["LUNEDÌ", "MARTEDÌ", "MERCOLEDÌ", "GIOVEDÌ", "VENERDÌ", "SABATO", "DOMENICA"]

    private func determineWorkoutType(from text: String) -> WorkoutType {
        let lowercased = text.lowercased()
        if lowercased.contains("riposo") { return .rest }
        if lowercased.contains("interval") || lowercased.contains("sprint") { return .intervals }
        if lowercased.contains("tempo") || lowercased.contains("medio") || lowercased.contains("soglia") { return .tempo }
        if lowercased.contains("lungo") || lowercased.contains("long") { return .long }
        if lowercased.contains("recupero") || lowercased.contains("recovery") || lowercased.contains("leggera") { return .recovery }
        return .easy
    }

    private func extractDistance(from text: String) -> Double {
        let regex = try? NSRegularExpression(pattern: #"(\d+(?:[.,]\d+)?)\s*km"#, options: .caseInsensitive)
        if let match = regex?.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
            if let range = Range(match.range(at: 1), in: text) {
                let numStr = text[range].replacingOccurrences(of: ",", with: ".")
                return Double(numStr) ?? 0.0
            }
        }
        return 0.0
    }

    private func extractPlanTitle(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let cleaned = line.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespaces)
            if (cleaned.contains("PIANO") || cleaned.contains("FOCUS")) && cleaned.count > 5 {
                return cleaned
            }
        }
        return "Piano Personalizzato - \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none))"
    }
}

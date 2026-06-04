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
    private var openRouterProvider: OpenRouterProvider?
    private(set) var mlxProvider: MLXProvider
    private var healthManager: HealthKitManager?

    private let toolRouter = ToolRouter()
    private let offlineFallback = OfflineCoachFallback()
    private let maxToolIterations = 3

    init() {
        self.mlxProvider = MLXProvider()
    }

    private let systemPrompt = """
    IDENTITÀ
    Sei Bobby, un running coach italiano specializzato in corsa, salute integrata, recupero e alimentazione sportiva. Dai coaching pratico e personalizzato, non diagnosi mediche o nutrizionali cliniche. Sei diretto, chiaro e motivante, ma la sicurezza viene prima della performance.

    PRIORITÀ
    1. Salute e sicurezza prima di velocità, volume, dimagrimento o gara.
    2. Personalizza su profilo runner, piano attivo, dati Apple Health disponibili e preferenze o limiti dichiarati.
    3. Progressione graduale, recupero, prevenzione infortuni e sostenibilità sono parte del piano, non optional.
    4. Alimentazione default: performance + salute, food-first, periodizzata sul carico. Non proporre dimagrimenti aggressivi.
    5. L'utente decide sempre: tu proponi, spieghi e chiedi conferma prima di salvare o modificare.

    METODO COACHING
    - Prima di creare o modificare un piano corsa, verifica se hai dati sufficienti: km/settimana, allenamenti/settimana, esperienza, ritmo attuale, obiettivo, gara/distanza se rilevante, disponibilità settimanale, infortuni o limiti.
    - Se mancano dati critici, fai 1-3 domande mirate. Non riempire buchi importanti con fantasia.
    - Se i dati sono sufficienti, usa i tool appropriati, poi traduci il risultato in indicazioni comprensibili: giorno, tipo, km, intensità/RPE, scopo della seduta e nota di recupero.
    - Per ottimizzare un piano attivo, prima descrivi la modifica proposta e chiedi conferma specifica; solo dopo conferma chiama il tool di modifica.

    USO TOOL
    - Usa "get_user_profile" prima di proposte di allenamento o nutrizione che dipendono dal profilo.
    - Usa "get_active_plan" quando l'utente parla del piano corrente, chiede ottimizzazioni o chiede alimentazione basata sull'allenamento.
    - Usa "calculate_training_plan" per creare piani di allenamento: non inventare distanze o distribuzioni settimanali.
    - Usa "get_nutrition_plan" quando devi commentare o modificare il piano alimentare attivo.
    - Usa "calculate_nutrition_plan" quando l'utente chiede un piano alimentare completo.
    - Usa "get_health_summary" quando la richiesta riguarda salute, recupero, sonno, affaticamento, stress, carico, performance recente, prontezza gara o domande sullo stato fisico come "come sto?". Non usarlo per consigli generici non sanitari.

    SALUTE E RED FLAG
    - Se l'utente riferisce dolore o pressione al petto, dolore che si irradia a collo/spalla/braccio, dispnea estrema, svenimento, capogiri importanti, nausea marcata, dolore acuto/progressivo, sospetto infortunio serio, sintomi neurologici, gravidanza con sintomi, patologie non controllate o farmaci rilevanti: consiglia di fermare l'allenamento e contattare un medico o assistenza urgente se necessario.
    - Non diagnosticare. Usa formule come "segnale da monitorare", "compatibile con", "da valutare con un professionista".
    - Quando analizzi Apple Health, cita solo numeri presenti nel tool. HRV e frequenza cardiaca a riposo vanno interpretate come trend individuali e segnali contestuali, non come verità assolute.
    - Se mancano dati (HRV, sonno, VO2 Max, allenamenti recenti), dillo esplicitamente e non inventare valori.
    - Se emergono segnali di sovraccarico (HRV in calo o bassa rispetto al solito, FC riposo alta rispetto al solito, sonno scarso, molti allenamenti intensi, fatica persistente), suggerisci recupero, riduzione temporanea del carico o seduta facile; chiedi conferma prima di modificare il piano.

    CORSA
    - Rispetta progressione graduale, distribuzione intensità equilibrata, giorni facili davvero facili e recupero.
    - Evita promesse di risultato garantito. Spiega sempre lo scopo delle sedute chiave.
    - Per principianti, privilegia continuità, cammino-corsa, tecnica semplice, recupero e costruzione aerobica.
    - Per runner intermedi/avanzati, collega volume, intensità, lunghi, qualità e taper all'obiettivo.
    - Se l'utente chiede una modifica rischiosa (troppo volume, troppa intensità, recupero insufficiente), proponi un'alternativa più sicura e spiega il motivo.

    NUTRIZIONE
    - La nutrizione serve a sostenere energia, recupero, salute e performance. Non proporre restrizioni estreme, eliminazioni non motivate o piani clinici.
    - Chiedi o segnala come dati mancanti: peso se non impostato, preferenze alimentari, allergie/intolleranze, stile alimentare, obiettivo peso solo se rilevante, orari allenamento.
    - Quando presenti un piano alimentare, includi: grammi giornalieri dal tool, timing pre/post allenamento, idratazione, esempi food-first e nota su personalizzazione per preferenze/allergie.
    - Per sedute lunghe o intense, aumenta attenzione a carboidrati, recupero post-allenamento e fluidi. Per riposo, riduci il carico energetico senza tagliare recupero o proteine.
    - Per dimagrimento, se richiesto, proponi solo deficit moderato e sostenibile. Proteggi proteine, carboidrati attorno agli allenamenti, sonno, recupero e segnali di bassa disponibilità energetica/REDs.
    - Se compaiono segnali REDs o disturbi alimentari (fatica persistente, calo performance, infortuni ricorrenti, amenorrea, libido molto bassa, paura del cibo, restrizione marcata, abbuffate, ossessione peso), suggerisci supporto di medico/nutrizionista sportivo.
    - Supplementi: food-first. Puoi parlarne in modo prudente, senza prescrivere e ricordando supervisione professionale quando necessario.

    CONFERME E SALVATAGGI
    - Chiama "save_training_plan" SOLO dopo conferma esplicita e specifica del piano di allenamento appena proposto.
    - Chiama "save_nutrition_plan" SOLO dopo conferma esplicita e specifica del piano alimentare appena proposto.
    - Chiama "optimize_plan" SOLO dopo conferma esplicita della modifica proposta.
    - "ok", "sì" o "va bene" valgono come conferma solo se la domanda immediatamente precedente chiedeva di salvare o applicare quello specifico piano/modifica.
    - Non salvare, ottimizzare o modificare nulla se la conferma è ambigua o se nella conversazione sono presenti più piani/modifiche. In quel caso chiedi: "Confermi che vuoi salvare/applicare questo specifico piano?"
    - Quando salvi o ottimizzi un piano di allenamento e c'è un piano alimentare attivo, avvisa: "Il piano di allenamento è cambiato. Vuoi che aggiorni anche il piano alimentare?" Non aggiornarlo automaticamente.

    STILE
    Rispondi sempre in italiano. Sii conciso, concreto e orientato all'azione. Usa tabelle o elenchi brevi quando migliorano la lettura. Non sommergere l'utente: dai il prossimo passo più utile.
    """

    // MARK: - Setup

    func configure(with settings: AISettings, healthManager: HealthKitManager? = nil) {
        self.aiSettings = settings
        self.healthManager = healthManager
        updateProvider()
    }

    func updateProvider() {
        guard let settings = aiSettings else { return }

        // Sync MLX model selection with settings
        if mlxProvider.modelId != settings.selectedModelId {
            mlxProvider.setModel(settings.selectedModelId)
        }

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

        // Setup OpenRouter provider if API key available
        if let apiKey = settings.openRouterAPIKey, !apiKey.isEmpty {
            openRouterProvider = OpenRouterProvider(apiKey: apiKey, model: settings.openRouterModel)
        } else {
            openRouterProvider = nil
        }

        // Update active provider name
        if let provider = resolveProvider() {
            activeProviderName = provider.providerName
        } else {
            activeProviderName = "Locale fallback gratuito"
        }
    }

    private func resolveProvider() -> LLMService? {
        guard let settings = aiSettings else { return openAIProvider ?? anthropicProvider ?? openRouterProvider }

        switch settings.providerType {
        case .local:
            return settings.isLocalAvailable ? mlxProvider : nil
        case .openai:
            return openAIProvider
        case .anthropic:
            return anthropicProvider
        case .openrouter:
            return openRouterProvider
        case .auto:
            // Priority: local -> anthropic -> openai -> openrouter
            if settings.isLocalAvailable {
                return mlxProvider
            }
            if let anthropic = anthropicProvider, anthropic.isAvailable {
                return anthropic
            }
            if let openAI = openAIProvider, openAI.isAvailable {
                return openAI
            }
            return openRouterProvider
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
            activeProviderName = "Locale fallback gratuito"
            return offlineFallback.response(
                to: userMessage,
                userProfile: userProfile,
                activePlan: planManager.currentActivePlan,
                nutritionPlan: nutritionManager?.currentNutritionPlan,
                reason: .noProviderConfigured
            )
        }

        // Load local model into memory on-demand
        let usingLocalModel = provider is MLXProvider
        if usingLocalModel && !mlxProvider.isAvailable {
            await mlxProvider.loadIfAvailable()
            guard mlxProvider.isAvailable else {
                activeProviderName = "Locale fallback gratuito"
                return offlineFallback.response(
                    to: userMessage,
                    userProfile: userProfile,
                    activePlan: planManager.currentActivePlan,
                    nutritionPlan: nutritionManager?.currentNutritionPlan,
                    reason: .localModelUnavailable
                )
            }
        }

        defer {
            // Free memory after generation
            if usingLocalModel {
                mlxProvider.unloadModel()
            }
        }

        // Build conversation messages
        var messages = buildMessages(userMessage: userMessage, userProfile: userProfile, nutritionManager: nutritionManager, conversationHistory: conversationHistory, usingMLX: usingLocalModel)

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
                    if !streamingText.isEmpty {
                        return streamingText
                    }
                    activeProviderName = "Locale fallback gratuito"
                    return offlineFallback.response(
                        to: userMessage,
                        userProfile: userProfile,
                        activePlan: planManager.currentActivePlan,
                        nutritionPlan: nutritionManager?.currentNutritionPlan,
                        reason: .providerDidNotAnswer
                    )
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

                    PrivacyLog.debug("Tool call completed: \(toolCall.name)")
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
                PrivacyLog.debug("LLM request failed: \(type(of: error))")

                streamingText = ""

                // Auto mode may fall back to configured cloud providers. Explicit local mode stays on-device.
                if let settings = aiSettings, settings.providerType == .auto {
                    let candidates: [LLMService?] = [anthropicProvider, openAIProvider, openRouterProvider]
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

                activeProviderName = "Locale fallback gratuito"
                return offlineFallback.response(
                    to: userMessage,
                    userProfile: userProfile,
                    activePlan: planManager.currentActivePlan,
                    nutritionPlan: nutritionManager?.currentNutritionPlan,
                    reason: .providerError
                )
            }
        }

        activeProviderName = "Locale fallback gratuito"
        return offlineFallback.response(
            to: userMessage,
            userProfile: userProfile,
            activePlan: planManager.currentActivePlan,
            nutritionPlan: nutritionManager?.currentNutritionPlan,
            reason: .providerDidNotAnswer
        )
    }

    // MARK: - Message Building

    private func buildMessages(userMessage: String, userProfile: RunnerProfile, nutritionManager: NutritionPlanManager?, conversationHistory: [ChatMessage], usingMLX: Bool = false) -> [LLMMessage] {
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

            APPLE HEALTH: Disponibile. Puoi usare il tool "get_health_summary" per leggere dati reali di salute e allenamento (frequenza cardiaca, HRV, passi, sonno, allenamenti, VO2 Max). Usalo per analisi di salute, recupero, carico, sonno, affaticamento, stress, performance recente o stato fisico; non usarlo per consigli generici non sanitari.
            """
        } else {
            healthContext = "\n\n    APPLE HEALTH: Non disponibile su questo dispositivo."
        }

        var nutritionContext = ""
        if let nm = nutritionManager, let plan = nm.currentNutritionPlan {
            nutritionContext = "\n\n    PIANO ALIMENTARE ATTIVO: \"\(plan.title)\" — è collegato al piano di allenamento; se il piano cambia, chiedi conferma prima di aggiornarlo."
        } else {
            nutritionContext = "\n\n    PIANO ALIMENTARE: Nessun piano alimentare attivo. L'utente può chiedertene uno."
        }

        // MLX provider injects tools natively via Qwen2.5 chat template (UserInput.tools);
        // appending toolDescriptionsForPrompt would duplicate them and confuse the model.
        let toolDescriptions = usingMLX ? "" : "\n\n" + ToolRouter.toolDescriptionsForPrompt
        let fullSystemPrompt = systemPrompt + profileContext + healthContext + nutritionContext + toolDescriptions
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

private struct OfflineCoachFallback {
    enum Reason {
        case noProviderConfigured
        case localModelUnavailable
        case providerDidNotAnswer
        case providerError

        var intro: String {
            switch self {
            case .noProviderConfigured:
                return "Modalità gratuita locale fallback: rispondo senza cloud perché non c'è un provider pronto."
            case .localModelUnavailable:
                return "Modalità gratuita locale fallback: il modello MLX non è pronto, quindi uso coaching deterministico sul dispositivo."
            case .providerDidNotAnswer:
                return "Modalità gratuita locale fallback: il provider selezionato non ha completato la risposta."
            case .providerError:
                return "Modalità gratuita locale fallback: il provider selezionato ha avuto un errore, quindi resto sul dispositivo."
            }
        }
    }

    func response(
        to userMessage: String,
        userProfile: RunnerProfile,
        activePlan: TrainingPlan?,
        nutritionPlan: NutritionPlan?,
        reason: Reason
    ) -> String {
        let normalized = normalize(userMessage)
        var sections: [String] = [reason.intro]

        if containsRedFlag(normalized) {
            sections.append(redFlagAdvice())
        } else if isNutritionRequest(normalized) {
            sections.append(nutritionAdvice(for: userProfile, activePlan: activePlan, nutritionPlan: nutritionPlan))
        } else if isRecoveryRequest(normalized) {
            sections.append(recoveryAdvice(for: userProfile, activePlan: activePlan))
        } else if isTrainingRequest(normalized) {
            sections.append(trainingAdvice(for: userProfile, activePlan: activePlan))
        } else {
            sections.append(defaultAdvice(for: userProfile, activePlan: activePlan))
        }

        sections.append("Non salvo e non modifico piani senza una tua conferma esplicita.")
        return sections.joined(separator: "\n\n")
    }

    private func trainingAdvice(for profile: RunnerProfile, activePlan: TrainingPlan?) -> String {
        if let activePlan {
            let totalKm = activePlan.weeklyPlan.reduce(0.0) { $0 + $1.distance }
            let workouts = activePlan.weeklyPlan.filter { $0.workoutType != .rest }.count
            let nextWorkout = activePlan.weeklyPlan.first { $0.workoutType != .rest }
            var text = "Hai un piano attivo: \(activePlan.title). Volume indicativo: \(formatKm(totalKm)) km su \(workouts) sedute."
            if let nextWorkout {
                text += "\nProssima seduta utile: \(nextWorkout.dayOfWeek) - \(nextWorkout.workoutType.rawValue), \(formatKm(nextWorkout.distance)) km. Tienila a RPE 3-4 se sei affaticato."
            }
            text += "\nSe vuoi cambiarlo, dimmi obiettivo, giorni disponibili e cosa vuoi modificare; ti propongo prima la modifica e poi chiedo conferma."
            return text
        }

        let weeklyKm = max(profile.weeklyKilometers, 6)
        let workouts = min(max(profile.workoutsPerWeek, 2), 5)
        let days = scheduleDays(for: workouts)
        let shares = distanceShares(for: workouts)
        let labels = workoutLabels(for: profile, workouts: workouts)

        var lines = [
            "Bozza minima sicura basata sul tuo profilo: \(Int(weeklyKm)) km/settimana, \(profile.experience.rawValue.lowercased()), obiettivo \(profile.primaryGoal.rawValue.lowercased())."
        ]

        for index in 0..<workouts {
            let km = max(2, weeklyKm * shares[index])
            lines.append("- \(days[index]): \(labels[index]) - \(formatKm(km)) km.")
        }

        lines.append("Mantieni almeno 1 giorno facile dopo qualità o lungo. Se dolore acuto o fatica insolita: riduci del 20-30% o riposa.")
        lines.append("Questa è una proposta non salvata; posso trasformarla in piano solo dopo tua conferma.")
        return lines.joined(separator: "\n")
    }

    private func nutritionAdvice(for profile: RunnerProfile, activePlan: TrainingPlan?, nutritionPlan: NutritionPlan?) -> String {
        let weight = profile.effectiveWeight
        let proteinMin = Int((weight * 1.6).rounded())
        let proteinMax = Int((weight * 1.8).rounded())
        let carbsEasy = Int((weight * 3.0).rounded())
        let carbsTraining = Int((weight * 5.0).rounded())

        var lines = [
            "Indicazione food-first non clinica, calcolata localmente su \(Int(weight)) kg.",
            "- Proteine: \(proteinMin)-\(proteinMax) g/die.",
            "- Carboidrati: circa \(carbsEasy) g nei giorni leggeri, fino a \(carbsTraining) g nei giorni con qualità o lungo.",
            "- Pre allenamento: carboidrati semplici/digeribili 1-3 ore prima. Post: 20-35 g proteine + carboidrati entro 2 ore.",
            "- Idratazione: acqua regolare; nelle sedute lunghe o calde aggiungi sali."
        ]

        if let activePlan {
            let totalKm = activePlan.weeklyPlan.reduce(0.0) { $0 + $1.distance }
            lines.append("Piano corsa attivo rilevato: \(activePlan.title), \(formatKm(totalKm)) km/settimana; concentra più carboidrati attorno a lungo e lavori intensi.")
        }

        if let nutritionPlan {
            lines.append("Piano alimentare attivo: \(nutritionPlan.title). Non lo aggiorno senza conferma.")
        } else {
            lines.append("Per un piano completo mi servono preferenze alimentari, allergie/intolleranze e orari degli allenamenti.")
        }

        return lines.joined(separator: "\n")
    }

    private func recoveryAdvice(for profile: RunnerProfile, activePlan: TrainingPlan?) -> String {
        var lines = [
            "Senza dati Health live in questa modalità, usa una regola conservativa: se sonno scarso, FC a riposo più alta del solito o gambe pesanti, trasforma la seduta in facile.",
            "Oggi scegli RPE 2-4, niente qualità, e chiudi con 5-10 minuti di mobilità leggera."
        ]

        if let activePlan {
            let hardDays = activePlan.weeklyPlan.filter { $0.workoutType == .tempo || $0.workoutType == .intervals || $0.workoutType == .long }.count
            lines.append("Nel piano attivo vedo \(hardDays) sedute impegnative: se la fatica dura oltre 48 ore, scala il prossimo lavoro del 20-30%.")
        } else {
            lines.append("Con il tuo profilo (\(profile.workoutsPerWeek) sedute/settimana), lascia almeno un giorno di recupero reale tra qualità e lungo.")
        }

        return lines.joined(separator: "\n")
    }

    private func defaultAdvice(for profile: RunnerProfile, activePlan: TrainingPlan?) -> String {
        if let activePlan {
            return "Posso aiutarti sul piano attivo \"\(activePlan.title)\". Prossimo passo utile: dimmi se vuoi analizzare una seduta, ridurre carico, preparare una gara o regolare nutrizione/recupero."
        }

        return "Per partire in modo sicuro: questa settimana resta su \(Int(max(profile.weeklyKilometers, 6))) km circa, \(min(max(profile.workoutsPerWeek, 2), 5)) sedute, ritmo facile nella maggior parte dei km. Dimmi obiettivo, giorni disponibili e eventuali dolori: ti preparo una proposta non salvata."
    }

    private func redFlagAdvice() -> String {
        """
        Prima la sicurezza: fermati e non forzare l'allenamento.
        Se hai dolore/pressione al petto, svenimento, dispnea forte, sintomi neurologici, dolore acuto progressivo o malessere marcato, contatta assistenza medica urgente.
        Se il sintomo è meno severo ma nuovo o ricorrente, sospendi qualità e lungo finché non lo valuti con un professionista.
        """
    }

    private func isTrainingRequest(_ text: String) -> Bool {
        containsAny(text, ["piano", "allenamento", "allenarmi", "corsa", "correre", "gara", "10k", "5k", "mezza", "maratona", "velocita", "resistenza", "lungo"])
    }

    private func isNutritionRequest(_ text: String) -> Bool {
        containsAny(text, ["nutriz", "aliment", "mangiare", "mangio", "dieta", "proteine", "carbo", "idrata", "colazione", "pranzo", "cena"])
    }

    private func isRecoveryRequest(_ text: String) -> Bool {
        containsAny(text, ["recuper", "stanco", "fatica", "sonno", "hrv", "battiti", "frequenza", "stress", "riposo", "dolori muscolari"])
    }

    private func containsRedFlag(_ text: String) -> Bool {
        containsAny(text, [
            "dolore al petto", "pressione al petto", "sven", "svengo", "dispnea", "fiato corto forte",
            "capogiri", "vertigini", "dolore acuto", "dolore forte", "neurolog", "nausea marcata"
        ])
    }

    private func scheduleDays(for workouts: Int) -> [String] {
        switch workouts {
        case 2:
            return ["Martedì", "Sabato"]
        case 3:
            return ["Martedì", "Giovedì", "Sabato"]
        case 4:
            return ["Lunedì", "Mercoledì", "Venerdì", "Domenica"]
        default:
            return ["Lunedì", "Martedì", "Giovedì", "Sabato", "Domenica"]
        }
    }

    private func distanceShares(for workouts: Int) -> [Double] {
        switch workouts {
        case 2:
            return [0.45, 0.55]
        case 3:
            return [0.30, 0.25, 0.45]
        case 4:
            return [0.20, 0.25, 0.20, 0.35]
        default:
            return [0.18, 0.22, 0.16, 0.18, 0.26]
        }
    }

    private func workoutLabels(for profile: RunnerProfile, workouts: Int) -> [String] {
        let quality = profile.experience == .beginner ? "Facile + 4 allunghi controllati" : "Qualità controllata RPE 6-7"
        switch workouts {
        case 2:
            return ["Facile RPE 3-4", "Lungo facile RPE 3-4"]
        case 3:
            return ["Facile RPE 3-4", quality, "Lungo facile RPE 3-4"]
        case 4:
            return ["Facile RPE 3-4", quality, "Recupero RPE 2-3", "Lungo facile RPE 3-4"]
        default:
            return ["Facile RPE 3-4", quality, "Recupero RPE 2-3", "Facile + tecnica", "Lungo facile RPE 3-4"]
        }
    }

    private func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
    }

    private func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains(normalize($0)) }
    }

    private func formatKm(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", rounded)
    }
}

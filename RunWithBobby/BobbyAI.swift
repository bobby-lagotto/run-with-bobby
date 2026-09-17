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
    private lazy var compactPlanner = CompactCoachPlanner(toolRouter: toolRouter)
    private let maxToolIterations = 3

    init() {
        self.mlxProvider = MLXProvider()
    }

    private var systemPrompt: String { CoachPrompts.cloud }

    /// Short prompt for on-device models. The full coach spec overflows a 1.5B
    /// context and, with a rotating KV, the identity was dropped entirely.
    private var localSystemPrompt: String { CoachPrompts.onDevice }


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
            activeProviderName = L10n.tr("Locale fallback gratuito", english: "Free on-device fallback")
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
            activeProviderName = L10n.tr("Locale fallback gratuito", english: "Free on-device fallback")
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
        let selectedLocalModel = usingLocalModel ? LocalModelCatalog.find(mlxProvider.modelId) : nil
        let supportsNativeTools = !usingLocalModel || (selectedLocalModel?.supportsNativeToolCalling ?? true)
        let toolDefinitions: [ToolDefinitionSchema]? = supportsNativeTools ? ToolRouter.toolDefinitions : nil

        let intent = CompactCoachIntent.detect(
            userMessage,
            hasPendingTrainingPlan: toolRouter.hasPendingTrainingPlan,
            hasPendingNutritionPlan: toolRouter.hasPendingNutritionPlan,
            hasPendingOptimization: toolRouter.hasPendingOptimization
        )
        if let intent, intent.shouldGroundDeterministically() {
            if let deterministic = await compactPlanner.respond(
                to: userMessage,
                userProfile: userProfile,
                planManager: planManager,
                nutritionManager: nutritionManager,
                healthManager: healthManager
            ) {
                return deterministic
            }
        }
        if usingLocalModel && !supportsNativeTools {
            return compactModelFallback(
                userMessage: userMessage,
                userProfile: userProfile,
                planManager: planManager,
                nutritionManager: nutritionManager
            )
        }

        if usingLocalModel && !mlxProvider.isAvailable {
            await mlxProvider.loadIfAvailable()
            guard mlxProvider.isAvailable else {
                activeProviderName = L10n.tr("Locale fallback gratuito", english: "Free on-device fallback")
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
        let userConfirmed = CompactCoachIntent.isExplicitConfirmation(userMessage)
        let allowedFacts = CoachFactBag.empty.allowingProfile(userProfile)

        // Agent loop: generate (streaming) → tool calls → execute → re-generate
        for iteration in 0..<maxToolIterations {
            do {
                streamingText = ""

                var fullResponse: LLMResponse?
                for try await event in provider.generateStream(messages: messages, toolDefinitions: toolDefinitions) {
                    switch event {
                    case .textDelta(let delta):
                        appendVisibleDelta(delta)
                    case .done(let response):
                        fullResponse = response
                    }
                }

                guard let response = fullResponse else {
                    if let visible = visibleStreamingText() {
                        if GenerationLoopGuard.shouldDiscardAsModelOutput(visible, allowedFacts: allowedFacts) {
                            return await groundedOrOfflineFallback(
                                userMessage: userMessage,
                                userProfile: userProfile,
                                planManager: planManager,
                                nutritionManager: nutritionManager,
                                reason: .providerDidNotAnswer
                            )
                        }
                        return visible
                    }
                    return await groundedOrOfflineFallback(
                        userMessage: userMessage,
                        userProfile: userProfile,
                        planManager: planManager,
                        nutritionManager: nutritionManager,
                        reason: .providerDidNotAnswer
                    )
                }

                // If no tool calls, return the text response
                if response.toolCalls.isEmpty {
                    let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if GenerationLoopGuard.shouldDiscardAsModelOutput(text, allowedFacts: allowedFacts) {
                        return await groundedOrOfflineFallback(
                            userMessage: userMessage,
                            userProfile: userProfile,
                            planManager: planManager,
                            nutritionManager: nutritionManager,
                            reason: .providerDidNotAnswer
                        )
                    }
                    return text
                }

                // Tool calls detected — clear streaming text during tool processing
                streamingText = ""

                let siblingNames = response.toolCalls.map(\.name)
                var toolResults: [ToolResult] = []
                for toolCall in response.toolCalls {
                    let result = await toolRouter.execute(
                        toolCall,
                        userProfile: userProfile,
                        planManager: planManager,
                        nutritionManager: nutritionManager,
                        healthManager: healthManager,
                        userConfirmed: userConfirmed,
                        siblingToolNames: siblingNames
                    )
                    toolResults.append(result)

                    PrivacyLog.debug("Tool call completed: \(toolCall.name)")
                }

                if let formatted = CompactCoachPlanner.formatToolResults(toolResults) {
                    return formatted
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
                        content: CoachPrompts.toolFollowup
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
                            var discarded = false
                            for try await event in fallback.generateStream(messages: messages, toolDefinitions: ToolRouter.toolDefinitions) {
                                switch event {
                                case .textDelta(let delta):
                                    appendVisibleDelta(delta)
                                case .done(let response):
                                    if response.toolCalls.isEmpty {
                                        let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                                        if GenerationLoopGuard.shouldDiscardAsModelOutput(text, allowedFacts: allowedFacts) {
                                            discarded = true
                                        } else {
                                            return text
                                        }
                                    }
                                }
                            }
                            if discarded {
                                streamingText = ""
                                continue
                            }
                        } catch {
                            streamingText = ""
                            continue // Try next fallback
                        }
                    }
                }

                return await groundedOrOfflineFallback(
                    userMessage: userMessage,
                    userProfile: userProfile,
                    planManager: planManager,
                    nutritionManager: nutritionManager,
                    reason: .providerError
                )
            }
        }

        return await groundedOrOfflineFallback(
            userMessage: userMessage,
            userProfile: userProfile,
            planManager: planManager,
            nutritionManager: nutritionManager,
            reason: .providerDidNotAnswer
        )
    }

    // MARK: - Message Building

    private func buildMessages(userMessage: String, userProfile: RunnerProfile, nutritionManager: NutritionPlanManager?, conversationHistory: [ChatMessage], usingMLX: Bool = false) -> [LLMMessage] {
        var messages: [LLMMessage] = []

        let profileContext = CoachPrompts.profileContext(for: userProfile)
        let healthAvailable = healthManager?.isAvailable == true
        let healthContext = CoachPrompts.healthContext(usingMLX: usingMLX, available: healthAvailable)
        let nutritionContext = CoachPrompts.nutritionContext(activeTitle: nutritionManager?.currentNutritionPlan?.title)

        // MLX provider injects tools natively via Qwen2.5 chat template (UserInput.tools);
        // appending toolDescriptionsForPrompt would duplicate them and confuse the model.
        let toolDescriptions = usingMLX ? "" : "\n\n" + ToolRouter.toolDescriptionsForPrompt
        let identityPrompt = usingMLX ? localSystemPrompt : systemPrompt
        let fullSystemPrompt = identityPrompt + profileContext + healthContext + nutritionContext + toolDescriptions
        messages.append(LLMMessage(role: .system, content: fullSystemPrompt))

        let historyLimit = usingMLX ? 8 : 20
        let recentHistory = CompactCoachPlanner.messagesForPrompt(
            conversationHistory,
            currentUserMessage: userMessage,
            limit: historyLimit
        )
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

    private func appendVisibleDelta(_ delta: String) {
        let candidate = streamingText + delta
        if GenerationLoopGuard.shouldHideFromStream(delta) || GenerationLoopGuard.shouldHideFromStream(candidate) {
            streamingText = ""
            return
        }
        streamingText = candidate
    }

    private func visibleStreamingText() -> String? {
        let text = streamingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !GenerationLoopGuard.shouldDiscardAsModelOutput(text) else { return nil }
        return text
    }

    private func compactModelFallback(
        userMessage: String,
        userProfile: RunnerProfile,
        planManager: TrainingPlanManager,
        nutritionManager: NutritionPlanManager?
    ) -> String {
        return offlineFallback.response(
            to: userMessage,
            userProfile: userProfile,
            activePlan: planManager.currentActivePlan,
            nutritionPlan: nutritionManager?.currentNutritionPlan,
            reason: .compactModel
        )
    }

    private func groundedOrOfflineFallback(
        userMessage: String,
        userProfile: RunnerProfile,
        planManager: TrainingPlanManager,
        nutritionManager: NutritionPlanManager?,
        reason: OfflineCoachFallback.Reason
    ) async -> String {
        if let grounded = await compactPlanner.respond(
            to: userMessage,
            userProfile: userProfile,
            planManager: planManager,
            nutritionManager: nutritionManager,
            healthManager: healthManager
        ) {
            return grounded
        }
        activeProviderName = L10n.tr("Locale fallback gratuito", english: "Free on-device fallback")
        return offlineFallback.response(
            to: userMessage,
            userProfile: userProfile,
            activePlan: planManager.currentActivePlan,
            nutritionPlan: nutritionManager?.currentNutritionPlan,
            reason: reason
        )
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
        case compactModel

        var intro: String {
            switch self {
            case .noProviderConfigured:
                return L10n.tr(
                    "Modalità gratuita locale fallback: rispondo senza cloud perché non c'è un provider pronto.",
                    english: "Free on-device fallback: I answer without cloud because no provider is ready."
                )
            case .localModelUnavailable:
                return L10n.tr(
                    "Modalità gratuita locale fallback: il modello MLX non è pronto, quindi uso coaching deterministico sul dispositivo.",
                    english: "Free on-device fallback: the MLX model isn't ready, so I use deterministic coaching on device."
                )
            case .providerDidNotAnswer:
                return L10n.tr(
                    "Non ho completato la risposta col modello. Ti do un consiglio conservativo sul dispositivo.",
                    english: "I didn't finish the model reply. Here's conservative on-device advice."
                )
            case .providerError:
                return L10n.tr(
                    "Modalità gratuita locale fallback: il provider selezionato ha avuto un errore, quindi resto sul dispositivo.",
                    english: "Free on-device fallback: the selected provider errored, so I stay on device."
                )
            case .compactModel:
                return L10n.tr(
                    "Questo modello è troppo piccolo per la chat libera: resto sul coaching deterministico sul dispositivo.",
                    english: "This model is too small for free chat: I stay on deterministic coaching on device."
                )
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
            sections.append(HealthCitations.chatFooter)
        } else if isHealthStatusRequest(normalized) {
            sections.append(healthStatusAdvice())
            sections.append(HealthCitations.chatFooter)
        } else if isNutritionRequest(normalized) {
            sections.append(nutritionAdvice(for: userProfile, activePlan: activePlan, nutritionPlan: nutritionPlan))
            sections.append(HealthCitations.chatFooter)
        } else if isRecoveryRequest(normalized) {
            sections.append(recoveryAdvice(for: userProfile, activePlan: activePlan))
            sections.append(HealthCitations.chatFooter)
        } else if isTrainingRequest(normalized) {
            sections.append(trainingAdvice(for: userProfile, activePlan: activePlan))
        } else {
            sections.append(defaultAdvice(for: userProfile, activePlan: activePlan))
        }

        sections.append(L10n.tr(
            "Non salvo e non modifico piani senza una tua conferma esplicita.",
            english: "I don't save or change plans without your explicit confirmation."
        ))
        return sections.joined(separator: "\n\n")
    }

    private func trainingAdvice(for profile: RunnerProfile, activePlan: TrainingPlan?) -> String {
        if let activePlan {
            let totalKm = activePlan.weeklyPlan.reduce(0.0) { $0 + $1.distance }
            let workouts = activePlan.weeklyPlan.filter { $0.workoutType != .rest }.count
            let nextWorkout = activePlan.weeklyPlan.first { $0.workoutType != .rest }
            var text = L10n.format(
                "Hai un piano attivo: %@. Volume indicativo: %@ km su %d sedute.",
                english: "You have an active plan: %@. Indicative volume: %@ km across %d sessions.",
                activePlan.title, formatKm(totalKm), workouts
            )
            if let nextWorkout {
                text += "\n" + L10n.format(
                    "Prossima seduta utile: %@ - %@, %@ km. Tienila a RPE 3-4 se sei affaticato.",
                    english: "Next useful session: %@ - %@, %@ km. Keep it at RPE 3-4 if you feel fatigued.",
                    nextWorkout.dayOfWeek, nextWorkout.workoutType.displayName, formatKm(nextWorkout.distance)
                )
            }
            text += "\n" + L10n.tr(
                "Se vuoi cambiarlo, dimmi obiettivo, giorni disponibili e cosa vuoi modificare; ti propongo prima la modifica e poi chiedo conferma.",
                english: "If you want to change it, tell me the goal, available days and what to modify; I'll propose the change first and then ask for confirmation."
            )
            return text
        }

        return L10n.tr(
            "Non ho un piano attivo e non invento i km. Dimmi «Crea un nuovo piano di allenamento» e ti calcolo una proposta da confermare.",
            english: "I don't have an active plan and I don't invent kilometres. Say “Create a new training plan” and I'll draft a proposal to confirm."
        )
    }

    private func nutritionAdvice(for profile: RunnerProfile, activePlan: TrainingPlan?, nutritionPlan: NutritionPlan?) -> String {
        let weight = profile.effectiveWeight
        let proteinMin = Int((weight * 1.6).rounded())
        let proteinMax = Int((weight * 1.8).rounded())
        let carbsEasy = Int((weight * 3.0).rounded())
        let carbsTraining = Int((weight * 5.0).rounded())

        var lines = [
            L10n.format(
                "Indicazione food-first non clinica, calcolata localmente su %d kg.",
                english: "Food-first, non-clinical guidance, calculated on-device for %d kg.",
                Int(weight)
            ),
            L10n.format(
                "- Proteine: %d-%d g/die.",
                english: "- Protein: %d-%d g/day.",
                proteinMin, proteinMax
            ),
            L10n.format(
                "- Carboidrati: circa %d g nei giorni leggeri, fino a %d g nei giorni con qualità o lungo.",
                english: "- Carbohydrates: about %d g on easy days, up to %d g on quality or long-run days.",
                carbsEasy, carbsTraining
            ),
            L10n.tr(
                "- Pre allenamento: carboidrati semplici/digeribili 1-3 ore prima. Post: 20-35 g proteine + carboidrati entro 2 ore.",
                english: "- Pre-run: simple/digestible carbs 1-3 hours before. Post: 20-35 g protein + carbs within 2 hours."
            ),
            L10n.tr(
                "- Idratazione: acqua regolare; nelle sedute lunghe o calde aggiungi sali.",
                english: "- Hydration: drink water regularly; add electrolytes on long or hot sessions."
            )
        ]

        if let activePlan {
            let totalKm = activePlan.weeklyPlan.reduce(0.0) { $0 + $1.distance }
            lines.append(L10n.format(
                "Piano corsa attivo rilevato: %@, %@ km/settimana; concentra più carboidrati attorno a lungo e lavori intensi.",
                english: "Active run plan detected: %@, %@ km/week; put more carbs around the long run and hard sessions.",
                activePlan.title, formatKm(totalKm)
            ))
        }

        if let nutritionPlan {
            lines.append(L10n.format(
                "Piano alimentare attivo: %@. Non lo aggiorno senza conferma.",
                english: "Active nutrition plan: %@. I won't update it without confirmation.",
                nutritionPlan.title
            ))
        } else {
            lines.append(L10n.tr(
                "Per un piano completo mi servono preferenze alimentari, allergie/intolleranze e orari degli allenamenti.",
                english: "For a full plan I need food preferences, allergies/intolerances and training times."
            ))
        }

        return lines.joined(separator: "\n")
    }

    private func recoveryAdvice(for profile: RunnerProfile, activePlan: TrainingPlan?) -> String {
        var lines = [
            L10n.tr(
                "Senza dati Health live in questa modalità, usa una regola conservativa: se sonno scarso, FC a riposo più alta del solito o gambe pesanti, trasforma la seduta in facile.",
                english: "Without live Health data in this mode, use a conservative rule: if sleep is poor, resting HR is higher than usual or legs feel heavy, turn the session easy."
            ),
            L10n.tr(
                "Oggi scegli RPE 2-4, niente qualità, e chiudi con 5-10 minuti di mobilità leggera.",
                english: "Today choose RPE 2-4, no quality work, and finish with 5-10 minutes of easy mobility."
            )
        ]

        if let activePlan {
            let hardDays = activePlan.weeklyPlan.filter { $0.workoutType == .tempo || $0.workoutType == .intervals || $0.workoutType == .long }.count
            lines.append(L10n.format(
                "Nel piano attivo vedo %d sedute impegnative: se la fatica dura oltre 48 ore, scala il prossimo lavoro del 20-30%%.",
                english: "In the active plan I see %d hard sessions: if fatigue lasts more than 48 hours, cut the next quality session by 20-30%%.",
                hardDays
            ))
        } else {
            lines.append(L10n.format(
                "Con il tuo profilo (%d sedute/settimana), lascia almeno un giorno di recupero reale tra qualità e lungo.",
                english: "With your profile (%d sessions/week), leave at least one true recovery day between quality and the long run.",
                profile.workoutsPerWeek
            ))
        }

        return lines.joined(separator: "\n")
    }

    private func defaultAdvice(for profile: RunnerProfile, activePlan: TrainingPlan?) -> String {
        if let activePlan {
            return L10n.format(
                "Posso aiutarti sul piano attivo \"%@\". Prossimo passo utile: dimmi se vuoi analizzare una seduta, ridurre carico, preparare una gara o regolare nutrizione/recupero.",
                english: "I can help with the active plan \"%@\". Useful next step: tell me if you want to review a session, cut load, prepare a race, or adjust nutrition/recovery.",
                activePlan.title
            )
        }

        return L10n.tr(
            "Non ho un piano attivo. Dimmi «Crea un nuovo piano di allenamento» e ti preparo una proposta non salvata.",
            english: "I don't have an active plan. Say “Create a new training plan” and I'll prepare an unsaved draft."
        )
    }

    private func redFlagAdvice() -> String {
        L10n.tr(
            """
            Prima la sicurezza: fermati e non forzare l'allenamento.
            Se hai dolore/pressione al petto, svenimento, dispnea forte, sintomi neurologici, dolore acuto progressivo o malessere marcato, contatta assistenza medica urgente.
            Se il sintomo è meno severo ma nuovo o ricorrente, sospendi qualità e lungo finché non lo valuti con un professionista.
            """,
            english: """
            Safety first: stop and don't force the workout.
            If you have chest pain/pressure, fainting, severe shortness of breath, neurological symptoms, progressive acute pain or marked malaise, contact urgent medical care.
            If the symptom is milder but new or recurring, skip quality and the long run until you check it with a professional.
            """
        )
    }

    private func healthStatusAdvice() -> String {
        L10n.tr(
            """
            Per dirti come stai mi servono sonno, HRV, FC a riposo e allenamenti recenti da Apple Health.
            In questa modalità non li ho letti: se l'accesso Salute non è attivo, aprilo da Impostazioni. Poi riprova «Come sto?».
            Nel dubbio resta facile oggi, niente qualità.
            """,
            english: """
            To tell you how you're doing I need sleep, HRV, resting HR and recent workouts from Apple Health.
            I didn't read them in this mode: if Health access isn't on, open it in Settings. Then try “How am I?” again.
            When in doubt keep today easy, no quality work.
            """
        )
    }

    private func isHealthStatusRequest(_ text: String) -> Bool {
        containsAny(text, ["come sto", "dati di salute", "dati su salute", "dati salute", "stato fisico", "affatic", "how am i", "health data", "fatigued"])
    }

    private func isTrainingRequest(_ text: String) -> Bool {
        containsAny(text, ["piano", "allenamento", "allenarmi", "corsa", "correre", "gara", "10k", "5k", "mezza", "maratona", "velocita", "resistenza", "lungo", "plan", "training", "run", "race", "speed", "endurance"])
    }

    private func isNutritionRequest(_ text: String) -> Bool {
        containsAny(text, ["nutriz", "aliment", "mangiare", "mangio", "dieta", "proteine", "carbo", "idrata", "colazione", "pranzo", "cena", "nutrition", "meal", "eat", "protein", "carbs", "breakfast", "lunch", "dinner"])
    }

    private func isRecoveryRequest(_ text: String) -> Bool {
        containsAny(text, ["recuper", "stanco", "fatica", "sonno", "hrv", "battiti", "frequenza", "stress", "riposo", "dolori muscolari", "recover", "tired", "fatigue", "sleep", "resting", "sore"])
    }

    private func containsRedFlag(_ text: String) -> Bool {
        containsAny(text, [
            "dolore al petto", "pressione al petto", "sven", "svengo", "dispnea", "fiato corto forte",
            "capogiri", "vertigini", "dolore acuto", "dolore forte", "neurolog", "nausea marcata",
            "chest pain", "chest pressure", "faint", "shortness of breath", "dizziness", "acute pain", "neurolog"
        ])
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

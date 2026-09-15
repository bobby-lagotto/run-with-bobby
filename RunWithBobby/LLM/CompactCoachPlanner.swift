import Foundation

enum CompactCoachIntent: Equatable {
    case createTrainingPlan
    case createNutritionPlan
    case savePendingTraining
    case savePendingNutrition
    case healthStatus
    case todayBriefing

    static func detect(
        _ raw: String,
        hasPendingTrainingPlan: Bool = false,
        hasPendingNutritionPlan: Bool = false
    ) -> CompactCoachIntent? {
        let text = normalize(raw)
        if isNutritionCreate(text) { return .createNutritionPlan }
        if isTrainingCreate(text) { return .createTrainingPlan }
        if isSaveConfirmation(text) {
            if hasPendingTrainingPlan { return .savePendingTraining }
            if hasPendingNutritionPlan { return .savePendingNutrition }
        }
        if isHealthStatus(text) { return .healthStatus }
        if isTodayBriefing(text) { return .todayBriefing }
        return nil
    }

    /// Health and today must not go through small local LLMs: they ignore the
    /// coach prompt and refuse with legal/privacy boilerplate.
    func shouldGroundOnDevice(supportsNativeToolCalling: Bool) -> Bool {
        switch self {
        case .healthStatus, .todayBriefing:
            return true
        case .createTrainingPlan, .createNutritionPlan, .savePendingTraining, .savePendingNutrition:
            return !supportsNativeToolCalling
        }
    }

    private static func isTrainingCreate(_ text: String) -> Bool {
        containsAny(text, [
            "nuovo piano",
            "crea un nuovo piano",
            "piano di allenamento",
            "crea un piano di allenamento"
        ])
    }

    private static func isNutritionCreate(_ text: String) -> Bool {
        containsAny(text, [
            "piano alimentare",
            "crea un piano alimentare"
        ])
    }

    private static func isSaveConfirmation(_ text: String) -> Bool {
        let compact = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let exact = ["salva", "confermo", "si", "ok", "va bene", "ok salva", "si salva", "salva il piano", "confermo il piano"]
        if exact.contains(compact) { return true }
        return compact.contains("salva") && compact.count < 40
    }

    private static func isHealthStatus(_ text: String) -> Bool {
        containsAny(text, [
            "come sto",
            "dati di salute",
            "dati su salute",
            "dati salute",
            "analizza i miei dati",
            "riassunto completo",
            "sono affatic",
            "stato fisico"
        ])
    }

    private static func isTodayBriefing(_ text: String) -> Bool {
        containsAny(text, [
            "cosa faccio oggi",
            "briefing",
            "prontezza"
        ])
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains(normalize($0)) }
    }
}

struct CompactCoachPlanner {
    let toolRouter: ToolRouter

    func respond(
        to userMessage: String,
        userProfile: RunnerProfile,
        planManager: TrainingPlanManager,
        nutritionManager: NutritionPlanManager?,
        healthManager: HealthKitManager? = nil
    ) async -> String? {
        guard let intent = CompactCoachIntent.detect(
            userMessage,
            hasPendingTrainingPlan: toolRouter.hasPendingTrainingPlan,
            hasPendingNutritionPlan: toolRouter.hasPendingNutritionPlan
        ) else {
            return nil
        }

        switch intent {
        case .createTrainingPlan:
            return await createTrainingPlan(userProfile: userProfile, planManager: planManager)
        case .createNutritionPlan:
            return await createNutritionPlan(userProfile: userProfile, planManager: planManager, nutritionManager: nutritionManager)
        case .savePendingTraining:
            return await saveTrainingPlan(userProfile: userProfile, planManager: planManager, nutritionManager: nutritionManager)
        case .savePendingNutrition:
            return await saveNutritionPlan(planManager: planManager, nutritionManager: nutritionManager)
        case .healthStatus:
            return await healthStatus(userProfile: userProfile, planManager: planManager, healthManager: healthManager)
        case .todayBriefing:
            return await todayBriefing(userProfile: userProfile, planManager: planManager, healthManager: healthManager)
        }
    }

    static func formatTrainingPlan(from json: String) -> String? {
        guard let root = parseObject(json),
              let days = root["piano_settimanale"] as? [[String: Any]] else {
            return nil
        }

        let summary = root["riepilogo"] as? [String: Any]
        let totalKm = intValue(summary?["km_totali"]) ?? 0
        let workouts = intValue(summary?["allenamenti"]) ?? days.filter { stringValue($0["tipo"]) != "Riposo" }.count

        var lines = [
            "Proposta di piano (non salvata), calcolata sul tuo profilo: \(totalKm) km/settimana, \(workouts) allenamenti."
        ]

        for day in days {
            let name = stringValue(day["giorno"]) ?? "Giorno"
            let type = stringValue(day["tipo"]) ?? ""
            let km = doubleValue(day["distanza_km"]) ?? 0
            let minutes = intValue(day["durata_min"]) ?? 0
            if type == "Riposo" || km == 0 {
                lines.append("- \(name): Riposo.")
            } else if minutes > 0 {
                lines.append("- \(name): \(type) — \(formatKm(km)) km (\(minutes) min).")
            } else {
                lines.append("- \(name): \(type) — \(formatKm(km)) km.")
            }
        }

        lines.append("Questa è una proposta non salvata. Confermi che vuoi salvare questo piano?")
        return lines.joined(separator: "\n")
    }

    static func formatNutritionPlan(from json: String) -> String? {
        if let root = parseObject(json), let error = stringValue(root["errore"]) {
            if error.contains("Nessun piano di allenamento") {
                return "Per un piano alimentare mi serve prima un piano di allenamento attivo. Crea o attiva un piano corsa, poi chiedimi di nuovo il piano alimentare."
            }
            return error
        }

        guard let root = parseObject(json),
              let days = root["piano_alimentare"] as? [[String: Any]] else {
            return nil
        }

        var lines = ["Proposta di piano alimentare (non salvata), calcolata sul piano di allenamento attivo."]

        for day in days {
            let name = stringValue(day["giorno"]) ?? "Giorno"
            let intensity = stringValue(day["intensita"]) ?? ""
            let protein = intValue(day["proteine_g"]) ?? 0
            let carbs = intValue(day["carboidrati_g"]) ?? 0
            let veg = intValue(day["verdure_frutta_g"]) ?? 0
            lines.append("- \(name) (\(intensity)): proteine \(protein) g, carboidrati \(carbs) g, verdure/frutta \(veg) g.")
        }

        lines.append("Food-first: carboidrati intorno agli allenamenti, proteine nel post, acqua regolare. Confermi che vuoi salvare questo piano alimentare?")
        return lines.joined(separator: "\n")
    }

    static func formatHealthStatus(healthJSON: String, briefingJSON: String?) -> String {
        guard let health = parseObject(healthJSON) else {
            return "Non riesco a leggere i dati Salute in questo momento. Controlla l'autorizzazione in Impostazioni > Salute."
        }
        if let error = stringValue(health["errore"]) {
            return error
        }
        if let message = stringValue(health["messaggio"]) {
            return message
        }

        var lines = ["Ecco come ti vedo dai dati Apple Health sul telefono. Non è una diagnosi."]
        var facts: [String] = []

        if let sleep = doubleValue(health["sonno_media_ore"]) {
            facts.append("Sonno medio: \(formatNumber(sleep)) ore/notte.")
        }
        if let hrv = intValue(health["variabilita_cardiaca_hrv_ms"]) {
            facts.append("HRV: \(hrv) ms.")
        }
        if let resting = intValue(health["frequenza_cardiaca_riposo_bpm"]) {
            facts.append("FC a riposo: \(resting) bpm.")
        }
        if let avgHR = intValue(health["frequenza_cardiaca_media_bpm"]) {
            facts.append("FC media: \(avgHR) bpm.")
        }
        if let vo2 = doubleValue(health["vo2max_ml_kg_min"]) {
            facts.append("VO2 max: \(formatNumber(vo2)) ml/kg/min.")
        }
        if let steps = intValue(health["passi_media_giornaliera"]) {
            facts.append("Passi medi: \(steps)/giorno.")
        }
        if let km = doubleValue(health["distanza_totale_km"]) {
            facts.append("Distanza ultimi giorni: \(formatKm(km)) km.")
        }
        if let workouts = intValue(health["numero_allenamenti"]) {
            facts.append("Allenamenti nel periodo: \(workouts).")
        }

        if facts.isEmpty {
            lines.append("I numeri di sonno, HRV, FC o allenamenti non ci sono in questi giorni: non li invento. Se non hai ancora dato l'accesso, aprilo da Impostazioni > Salute.")
        } else {
            lines.append(contentsOf: facts.map { "- \($0)" })
            lines.append(healthCoachingNote(health: health))
        }

        if let briefingJSON, let briefing = parseObject(briefingJSON), let line = stringValue(briefing["briefing"]) {
            lines.append("Oggi: \(line)")
        }

        return lines.joined(separator: "\n")
    }

    static func formatTodayBriefing(from json: String) -> String {
        guard let root = parseObject(json), let line = stringValue(root["briefing"]) else {
            return "Non ho un briefing affidabile. Dimmi se hai un piano attivo e come hai dormito."
        }
        var lines = [line]
        if let recommendation = stringValue(root["raccomandazione"]) {
            lines.append("Raccomandazione: \(recommendation).")
        }
        return lines.joined(separator: "\n")
    }

    static func messagesForPrompt(
        _ conversationHistory: [ChatMessage],
        currentUserMessage: String,
        limit: Int
    ) -> [ChatMessage] {
        var history = Array(conversationHistory.suffix(limit))
        if let last = history.last, last.isFromUser, last.content == currentUserMessage {
            history.removeLast()
        }
        return history
    }

    private func createTrainingPlan(userProfile: RunnerProfile, planManager: TrainingPlanManager) async -> String {
        let result = await toolRouter.execute(
            ToolCall(name: "calculate_training_plan", arguments: [
                "weekly_km": .number(userProfile.weeklyKilometers),
                "workouts_per_week": .int(userProfile.workoutsPerWeek),
                "goal": .string(Self.toolGoal(for: userProfile.primaryGoal)),
                "experience": .string(Self.toolExperience(for: userProfile.experience))
            ]),
            userProfile: userProfile,
            planManager: planManager
        )
        return Self.formatTrainingPlan(from: result.content)
            ?? "Non sono riuscito a calcolare il piano. Riprova o dimmi km/settimana e giorni disponibili."
    }

    private func createNutritionPlan(
        userProfile: RunnerProfile,
        planManager: TrainingPlanManager,
        nutritionManager: NutritionPlanManager?
    ) async -> String {
        let result = await toolRouter.execute(
            ToolCall(name: "calculate_nutrition_plan", arguments: [:]),
            userProfile: userProfile,
            planManager: planManager,
            nutritionManager: nutritionManager
        )
        return Self.formatNutritionPlan(from: result.content)
            ?? "Non sono riuscito a calcolare il piano alimentare. Serve un piano di allenamento attivo."
    }

    private func saveTrainingPlan(
        userProfile: RunnerProfile,
        planManager: TrainingPlanManager,
        nutritionManager: NutritionPlanManager?
    ) async -> String {
        let result = await toolRouter.execute(
            ToolCall(name: "save_training_plan", arguments: [:]),
            userProfile: userProfile,
            planManager: planManager,
            nutritionManager: nutritionManager
        )
        if let root = Self.parseObject(result.content), let error = Self.stringValue(root["errore"]) {
            return error
        }
        return "Piano salvato e attivato. Dimmi se vuoi anche un piano alimentare collegato."
    }

    private func saveNutritionPlan(planManager: TrainingPlanManager, nutritionManager: NutritionPlanManager?) async -> String {
        let result = await toolRouter.execute(
            ToolCall(name: "save_nutrition_plan", arguments: [:]),
            userProfile: RunnerProfile(),
            planManager: planManager,
            nutritionManager: nutritionManager
        )
        if let root = Self.parseObject(result.content), let error = Self.stringValue(root["errore"]) {
            return error
        }
        return "Piano alimentare salvato e attivato."
    }

    private func healthStatus(
        userProfile: RunnerProfile,
        planManager: TrainingPlanManager,
        healthManager: HealthKitManager?
    ) async -> String {
        let health = await toolRouter.execute(
            ToolCall(name: "get_health_summary", arguments: ["days": .int(7)]),
            userProfile: userProfile,
            planManager: planManager,
            healthManager: healthManager
        )
        let briefing = await toolRouter.execute(
            ToolCall(name: "get_today_briefing", arguments: [:]),
            userProfile: userProfile,
            planManager: planManager,
            healthManager: healthManager
        )
        return Self.formatHealthStatus(healthJSON: health.content, briefingJSON: briefing.content)
    }

    private func todayBriefing(
        userProfile: RunnerProfile,
        planManager: TrainingPlanManager,
        healthManager: HealthKitManager?
    ) async -> String {
        let briefing = await toolRouter.execute(
            ToolCall(name: "get_today_briefing", arguments: [:]),
            userProfile: userProfile,
            planManager: planManager,
            healthManager: healthManager
        )
        return Self.formatTodayBriefing(from: briefing.content)
    }

    private static func healthCoachingNote(health: [String: Any]) -> String {
        let sleep = doubleValue(health["sonno_media_ore"])
        let hrv = intValue(health["variabilita_cardiaca_hrv_ms"])
        let resting = intValue(health["frequenza_cardiaca_riposo_bpm"])
        let tired = (sleep ?? 8) < 6.5 || (hrv ?? 80) < 45 || (resting ?? 50) >= 68
        if tired {
            return "Segnale da monitorare: oggi tieni facile o riposa, niente qualità. Se il quadro resta così 48 ore, scala il carico."
        }
        return "I segnali disponibili non gridano allarme: puoi seguire il piano, con i giorni facili davvero facili."
    }

    private static func formatNumber(_ value: Double) -> String {
        formatKm(value)
    }

    private static func toolGoal(for goal: TrainingGoal) -> String {
        switch goal {
        case .speed: return "speed"
        case .endurance: return "endurance"
        case .fitness: return "fitness"
        case .weightLoss: return "weight_loss"
        case .racePrep: return "race_prep"
        }
    }

    private static func toolExperience(for experience: ExperienceLevel) -> String {
        switch experience {
        case .beginner: return "beginner"
        case .intermediate: return "intermediate"
        case .advanced: return "advanced"
        case .elite: return "elite"
        }
    }

    private static func parseObject(_ json: String) -> [String: Any]? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    private static func stringValue(_ value: Any?) -> String? {
        value as? String
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }

    private static func formatKm(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", rounded)
    }
}

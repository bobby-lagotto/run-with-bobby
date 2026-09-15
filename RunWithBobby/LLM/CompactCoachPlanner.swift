import Foundation

enum CompactCoachIntent: Equatable {
    case createTrainingPlan
    case createNutritionPlan
    case savePendingTraining
    case savePendingNutrition
    case savePendingOptimize
    case healthStatus
    case todayBriefing
    case adherence
    case activePlan
    case proposeOptimize

    static func detect(
        _ raw: String,
        hasPendingTrainingPlan: Bool = false,
        hasPendingNutritionPlan: Bool = false,
        hasPendingOptimization: Bool = false
    ) -> CompactCoachIntent? {
        let text = normalize(raw)
        if isNutritionCreate(text) { return .createNutritionPlan }
        if isTrainingCreate(text) { return .createTrainingPlan }
        if isSaveConfirmation(text) {
            if hasPendingTrainingPlan { return .savePendingTraining }
            if hasPendingNutritionPlan { return .savePendingNutrition }
            if hasPendingOptimization { return .savePendingOptimize }
        }
        if isProposeOptimize(text) { return .proposeOptimize }
        if isHealthStatus(text) { return .healthStatus }
        if isTodayBriefing(text) { return .todayBriefing }
        if isAdherence(text) { return .adherence }
        if isActivePlan(text) { return .activePlan }
        return nil
    }

    func shouldGroundDeterministically() -> Bool {
        true
    }

    static func isExplicitConfirmation(_ raw: String) -> Bool {
        isSaveConfirmation(normalize(raw))
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
        let exact = [
            "salva",
            "confermo",
            "salva il piano",
            "confermo il piano",
            "ok salva",
            "si salva",
            "confermo la modifica",
            "applica",
            "applica la modifica"
        ]
        if exact.contains(compact) { return true }
        return compact.contains("salva") && compact.contains("piano") && compact.count < 50
    }

    private static func isHealthStatus(_ text: String) -> Bool {
        containsAny(text, [
            "come sto",
            "come mi sento",
            "ho dormito",
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
            "devo correre oggi",
            "seduta di oggi",
            "pronto per allenarmi",
            "briefing",
            "prontezza"
        ])
    }

    private static func isAdherence(_ text: String) -> Bool {
        containsAny(text, [
            "ho corso",
            "cosa mi manca",
            "aderenza",
            "come sta andando la settimana",
            "settimana come sta andando"
        ])
    }

    private static func isActivePlan(_ text: String) -> Bool {
        containsAny(text, [
            "piano attivo",
            "mostrami il piano",
            "che piano ho"
        ])
    }

    private static func isProposeOptimize(_ text: String) -> Bool {
        containsAny(text, [
            "ottimizza",
            "ottimizzare",
            "aumenta il volume",
            "riduci il volume",
            "ridurre il carico"
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
            hasPendingNutritionPlan: toolRouter.hasPendingNutritionPlan,
            hasPendingOptimization: toolRouter.hasPendingOptimization
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
        case .savePendingOptimize:
            return await applyOptimize(userProfile: userProfile, planManager: planManager, nutritionManager: nutritionManager)
        case .healthStatus:
            return await healthStatus(userProfile: userProfile, planManager: planManager, healthManager: healthManager)
        case .todayBriefing:
            return await todayBriefing(userProfile: userProfile, planManager: planManager, healthManager: healthManager)
        case .adherence:
            return await adherence(userProfile: userProfile, planManager: planManager, healthManager: healthManager)
        case .activePlan:
            return await activePlan(userProfile: userProfile, planManager: planManager)
        case .proposeOptimize:
            return await proposeOptimize(userMessage: userMessage, userProfile: userProfile, planManager: planManager, nutritionManager: nutritionManager)
        }
    }

    static func formatToolResults(_ results: [ToolResult]) -> String? {
        guard !results.isEmpty else { return nil }
        var parts: [String] = []
        let health = results.first { $0.name == "get_health_summary" }?.content
        let briefing = results.first { $0.name == "get_today_briefing" }?.content

        for result in results {
            switch result.name {
            case "calculate_training_plan":
                if let text = formatTrainingPlan(from: result.content) { parts.append(text) }
            case "calculate_nutrition_plan":
                if let text = formatNutritionPlan(from: result.content) { parts.append(text) }
            case "get_health_summary":
                parts.append(formatHealthStatus(healthJSON: result.content, briefingJSON: briefing))
            case "get_today_briefing":
                if health == nil {
                    parts.append(formatTodayBriefing(from: result.content))
                }
            case "get_adherence":
                parts.append(formatAdherence(from: result.content))
            case "get_active_plan":
                parts.append(formatActivePlan(from: result.content))
            case "optimize_plan":
                parts.append(formatOptimize(from: result.content))
            case "save_training_plan", "save_nutrition_plan", "log_session":
                if let root = parseObject(result.content), let error = stringValue(root["errore"]) {
                    parts.append(error)
                } else if let root = parseObject(result.content), let message = stringValue(root["messaggio"]) {
                    parts.append(message)
                }
            default:
                if let root = parseObject(result.content), let error = stringValue(root["errore"]) {
                    parts.append(error)
                }
            }
        }

        let unique = parts.filter { !$0.isEmpty }
        guard !unique.isEmpty else { return nil }
        return unique.joined(separator: "\n\n")
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
        lines.append(contentsOf: dayLines(days))
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
            if let note = healthCoachingNote(health: health) {
                lines.append(note)
            }
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

    static func formatAdherence(from json: String) -> String {
        guard let root = parseObject(json) else {
            return "Non riesco a leggere l'aderenza della settimana."
        }
        if let message = stringValue(root["messaggio"]) {
            return message
        }
        let percent = intValue(root["percentuale"]) ?? 0
        let planned = intValue(root["sedute_previste"]) ?? 0
        let done = intValue(root["fatte"]) ?? 0
        let remaining = intValue(root["rimaste"]) ?? 0
        let context = stringValue(root["contesto_coach"]) ?? ""
        var lines = [
            "Aderenza settimana: \(percent)% (\(done)/\(planned) sedute fatte, \(remaining) rimaste)."
        ]
        if !context.isEmpty {
            lines.append(context)
        }
        return lines.joined(separator: "\n")
    }

    static func formatActivePlan(from json: String) -> String {
        if let root = parseObject(json), let message = stringValue(root["messaggio"]) {
            return message
        }
        guard let root = parseObject(json),
              let days = root["piano_settimanale"] as? [[String: Any]] else {
            return "Nessun piano attivo al momento. Dimmi «Crea un nuovo piano di allenamento» per una proposta da confermare."
        }
        let title = stringValue(root["titolo"]) ?? "Piano attivo"
        var lines = ["Piano attivo: \(title)."]
        lines.append(contentsOf: dayLines(days))
        return lines.joined(separator: "\n")
    }

    static func formatOptimize(from json: String) -> String {
        if let root = parseObject(json), let error = stringValue(root["errore"]) {
            return error
        }
        if let formatted = formatTrainingPlan(from: json) {
            return formatted
                .replacingOccurrences(
                    of: "Proposta di piano (non salvata), calcolata sul tuo profilo",
                    with: "Proposta di ottimizzazione (non applicata)"
                )
                .replacingOccurrences(
                    of: "Questa è una proposta non salvata. Confermi che vuoi salvare questo piano?",
                    with: "Questa è una proposta non applicata. Confermi che vuoi applicare questa ottimizzazione?"
                )
        }
        if let root = parseObject(json), let message = stringValue(root["messaggio"]) {
            return message
        }
        return "Non ho potuto ottimizzare il piano. Serve un piano attivo."
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
            nutritionManager: nutritionManager,
            userConfirmed: true
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
            nutritionManager: nutritionManager,
            userConfirmed: true
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

    private func adherence(
        userProfile: RunnerProfile,
        planManager: TrainingPlanManager,
        healthManager: HealthKitManager?
    ) async -> String {
        let result = await toolRouter.execute(
            ToolCall(name: "get_adherence", arguments: [:]),
            userProfile: userProfile,
            planManager: planManager,
            healthManager: healthManager
        )
        return Self.formatAdherence(from: result.content)
    }

    private func activePlan(userProfile: RunnerProfile, planManager: TrainingPlanManager) async -> String {
        let result = await toolRouter.execute(
            ToolCall(name: "get_active_plan", arguments: [:]),
            userProfile: userProfile,
            planManager: planManager
        )
        return Self.formatActivePlan(from: result.content)
    }

    private func proposeOptimize(
        userMessage: String,
        userProfile: RunnerProfile,
        planManager: TrainingPlanManager,
        nutritionManager: NutritionPlanManager?
    ) async -> String {
        let modification = Self.optimizeModification(from: userMessage)
        let result = await toolRouter.execute(
            ToolCall(name: "optimize_plan", arguments: [
                "modification": .string(modification),
                "percentage": .number(10)
            ]),
            userProfile: userProfile,
            planManager: planManager,
            nutritionManager: nutritionManager,
            userConfirmed: false
        )
        return Self.formatOptimize(from: result.content)
    }

    private func applyOptimize(
        userProfile: RunnerProfile,
        planManager: TrainingPlanManager,
        nutritionManager: NutritionPlanManager?
    ) async -> String {
        let result = await toolRouter.execute(
            ToolCall(name: "optimize_plan", arguments: [:]),
            userProfile: userProfile,
            planManager: planManager,
            nutritionManager: nutritionManager,
            userConfirmed: true
        )
        if let root = Self.parseObject(result.content), let error = Self.stringValue(root["errore"]) {
            return error
        }
        return "Ottimizzazione applicata al piano attivo. Non cambio altro senza una nuova conferma."
    }

    private static func optimizeModification(from raw: String) -> String {
        let text = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
        if text.contains("riduci") || text.contains("ridurre") || text.contains("diminu") {
            return "decrease_volume"
        }
        if text.contains("veloc") || text.contains("interval") {
            return "add_speed"
        }
        if text.contains("resistenz") || text.contains("lungo") {
            return "add_endurance"
        }
        return "increase_volume"
    }

    private static func dayLines(_ days: [[String: Any]]) -> [String] {
        days.map { day in
            let name = stringValue(day["giorno"]) ?? "Giorno"
            let type = stringValue(day["tipo"]) ?? ""
            let km = doubleValue(day["distanza_km"]) ?? 0
            let minutes = intValue(day["durata_min"]) ?? 0
            if type == "Riposo" || km == 0 {
                return "- \(name): Riposo."
            }
            if minutes > 0 {
                return "- \(name): \(type) — \(formatKm(km)) km (\(minutes) min)."
            }
            return "- \(name): \(type) — \(formatKm(km)) km."
        }
    }

    private static func healthCoachingNote(health: [String: Any]) -> String? {
        let sleep = doubleValue(health["sonno_media_ore"])
        let hrv = intValue(health["variabilita_cardiaca_hrv_ms"])
        let resting = intValue(health["frequenza_cardiaca_riposo_bpm"])
        guard sleep != nil || hrv != nil || resting != nil else { return nil }

        var tired = false
        if let sleep, sleep < 6.5 { tired = true }
        if let hrv, hrv < 45 { tired = true }
        if let resting, resting >= 68 { tired = true }

        if tired {
            return "Segnale da monitorare sui dati presenti: oggi tieni facile o riposa, niente qualità. Se il quadro resta così 48 ore, scala il carico."
        }
        return "Sui dati presenti non c'è un allarme: puoi seguire il piano, con i giorni facili davvero facili."
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

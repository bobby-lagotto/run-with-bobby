import Foundation

enum CompactCoachIntent: Equatable {
    case createTrainingPlan
    case createNutritionPlan
    case savePendingTraining
    case savePendingNutrition

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
        return nil
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
        nutritionManager: NutritionPlanManager?
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

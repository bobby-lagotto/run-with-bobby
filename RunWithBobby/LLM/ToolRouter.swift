import Foundation

// MARK: - Tool Router

class ToolRouter {

    // MARK: - Tool Definitions (for system prompt and OpenAI function calling)

    static let toolDefinitions: [ToolDefinitionSchema] = [
        ToolDefinitionSchema(
            name: "calculate_training_plan",
            description: "Calcola una distribuzione settimanale di allenamento con distanze specifiche per ogni giorno, basata sul profilo del runner e obiettivi. Usa SEMPRE questo tool per creare piani — non inventare distanze.",
            parameters: ToolParametersSchema(
                type: "object",
                properties: [
                    "weekly_km": ToolPropertySchema(type: "number", description: "Chilometri totali settimanali"),
                    "workouts_per_week": ToolPropertySchema(type: "integer", description: "Numero sessioni di allenamento per settimana (3-6)"),
                    "goal": ToolPropertySchema(type: "string", description: "Obiettivo principale", enumValues: ["speed", "endurance", "fitness", "weight_loss", "race_prep"]),
                    "experience": ToolPropertySchema(type: "string", description: "Livello esperienza", enumValues: ["beginner", "intermediate", "advanced", "elite"]),
                ],
                required: ["weekly_km", "workouts_per_week", "goal", "experience"]
            )
        ),
        ToolDefinitionSchema(
            name: "get_user_profile",
            description: "Ottieni il profilo completo del runner: km settimanali, allenamenti, obiettivi, ritmo attuale e livello esperienza.",
            parameters: ToolParametersSchema(type: "object", properties: [:], required: [])
        ),
        ToolDefinitionSchema(
            name: "get_active_plan",
            description: "Ottieni il piano di allenamento attivo corrente con tutti gli allenamenti giornalieri.",
            parameters: ToolParametersSchema(type: "object", properties: [:], required: [])
        ),
        ToolDefinitionSchema(
            name: "optimize_plan",
            description: "Modifica il piano di allenamento attivo in base al feedback dell'utente.",
            parameters: ToolParametersSchema(
                type: "object",
                properties: [
                    "modification": ToolPropertySchema(type: "string", description: "Tipo di modifica", enumValues: ["increase_volume", "decrease_volume", "add_speed", "add_endurance"]),
                    "percentage": ToolPropertySchema(type: "number", description: "Percentuale di aggiustamento (es. 10 per 10%). Default: 10"),
                ],
                required: ["modification"]
            )
        ),
        ToolDefinitionSchema(
            name: "save_training_plan",
            description: "Salva un piano di allenamento e impostalo come attivo. Chiama questo dopo calculate_training_plan per salvare il risultato.",
            parameters: ToolParametersSchema(
                type: "object",
                properties: [
                    "title": ToolPropertySchema(type: "string", description: "Titolo del piano"),
                ],
                required: ["title"]
            )
        ),
        ToolDefinitionSchema(
            name: "get_health_summary",
            description: "Ottieni un riepilogo completo dei dati di salute da Apple Health: frequenza cardiaca (media, riposo, min, max), variabilità cardiaca HRV, passi, distanza, calorie, VO2 Max, SpO2, allenamenti recenti e sonno. Usa questo tool quando l'utente chiede informazioni sulla salute, affaticamento, recupero, o per personalizzare il piano con dati reali.",
            parameters: ToolParametersSchema(
                type: "object",
                properties: [
                    "days": ToolPropertySchema(type: "integer", description: "Numero di giorni da analizzare (default: 7)"),
                ],
                required: []
            )
        ),
    ]

    // MARK: - Tool descriptions for system prompt (used by local models that don't support native function calling)

    static var toolDescriptionsForPrompt: String {
        var desc = "Strumenti disponibili:\n\n"
        for tool in toolDefinitions {
            desc += "- **\(tool.name)**: \(tool.description)\n"
            if !tool.parameters.properties.isEmpty {
                desc += "  Parametri: "
                let params = tool.parameters.properties.map { key, prop in
                    "\(key) (\(prop.type)): \(prop.description)"
                }
                desc += params.joined(separator: ", ")
                desc += "\n"
            }
        }
        return desc
    }

    // MARK: - State for multi-turn tool execution

    private var lastCalculatedPlan: [DayTraining]?

    // MARK: - Execute Tool Call

    func execute(
        _ toolCall: ToolCall,
        userProfile: RunnerProfile,
        planManager: TrainingPlanManager,
        healthManager: HealthKitManager? = nil
    ) async -> ToolResult {
        switch toolCall.name {
        case "calculate_training_plan":
            return calculateTrainingPlan(arguments: toolCall.arguments, userProfile: userProfile, toolCallId: toolCall.id)
        case "get_user_profile":
            return getUserProfile(userProfile: userProfile, toolCallId: toolCall.id)
        case "get_active_plan":
            return getActivePlan(planManager: planManager, toolCallId: toolCall.id)
        case "optimize_plan":
            return optimizePlan(arguments: toolCall.arguments, planManager: planManager, toolCallId: toolCall.id)
        case "save_training_plan":
            return saveTrainingPlan(arguments: toolCall.arguments, userProfile: userProfile, planManager: planManager, toolCallId: toolCall.id)
        case "get_health_summary":
            return await getHealthSummary(arguments: toolCall.arguments, healthManager: healthManager, toolCallId: toolCall.id)
        default:
            return ToolResult(toolCallId: toolCall.id, name: toolCall.name, content: "{\"error\": \"Tool sconosciuto: \(toolCall.name)\"}")
        }
    }

    // MARK: - Tool Implementations

    private func calculateTrainingPlan(arguments: [String: JSONValue], userProfile: RunnerProfile, toolCallId: String) -> ToolResult {
        let weeklyKm = arguments["weekly_km"]?.doubleValue ?? Double(userProfile.weeklyKilometers)
        let workoutsPerWeek = arguments["workouts_per_week"]?.intValue ?? userProfile.workoutsPerWeek
        let goalStr = arguments["goal"]?.stringValue ?? "fitness"
        let experienceStr = arguments["experience"]?.stringValue ?? "intermediate"

        let goal = mapGoal(goalStr)
        let experience = mapExperience(experienceStr)

        // Generate plan using distribution logic
        let plan = generateDistribution(weeklyKm: weeklyKm, workoutsPerWeek: workoutsPerWeek, goal: goal, experience: experience)
        self.lastCalculatedPlan = plan

        // Serialize to JSON
        let planData = plan.map { day -> [String: Any] in
            [
                "giorno": day.dayOfWeek,
                "tipo": day.workoutType.rawValue,
                "distanza_km": day.distance,
                "durata_min": day.estimatedDuration,
                "descrizione": day.description
            ]
        }

        let totalKm = plan.reduce(0) { $0 + $1.distance }
        let totalWorkouts = plan.filter { $0.workoutType != .rest }.count

        let result: [String: Any] = [
            "piano_settimanale": planData,
            "riepilogo": [
                "km_totali": Int(totalKm),
                "allenamenti": totalWorkouts,
                "obiettivo": goal.rawValue,
                "esperienza": experience.rawValue
            ]
        ]

        let jsonString = serializeJSON(result)
        return ToolResult(toolCallId: toolCallId, name: "calculate_training_plan", content: jsonString)
    }

    private func getUserProfile(userProfile: RunnerProfile, toolCallId: String) -> ToolResult {
        let profile: [String: Any] = [
            "km_settimanali": userProfile.weeklyKilometers,
            "allenamenti_settimana": userProfile.workoutsPerWeek,
            "obiettivo_principale": userProfile.primaryGoal.rawValue,
            "ritmo_attuale": userProfile.currentPace,
            "esperienza": userProfile.experience.rawValue,
            "distanza_gara": userProfile.raceDistance?.rawValue ?? "Nessuna"
        ]
        return ToolResult(toolCallId: toolCallId, name: "get_user_profile", content: serializeJSON(profile))
    }

    private func getActivePlan(planManager: TrainingPlanManager, toolCallId: String) -> ToolResult {
        guard let plan = planManager.currentActivePlan else {
            return ToolResult(toolCallId: toolCallId, name: "get_active_plan", content: "{\"messaggio\": \"Nessun piano attivo al momento.\"}")
        }

        let planData = plan.weeklyPlan.map { day -> [String: Any] in
            [
                "giorno": day.dayOfWeek,
                "tipo": day.workoutType.rawValue,
                "distanza_km": day.distance,
                "durata_min": day.estimatedDuration,
                "descrizione": day.description
            ]
        }

        let result: [String: Any] = [
            "titolo": plan.title,
            "piano_settimanale": planData
        ]
        return ToolResult(toolCallId: toolCallId, name: "get_active_plan", content: serializeJSON(result))
    }

    private func optimizePlan(arguments: [String: JSONValue], planManager: TrainingPlanManager, toolCallId: String) -> ToolResult {
        guard let plan = planManager.currentActivePlan else {
            return ToolResult(toolCallId: toolCallId, name: "optimize_plan", content: "{\"errore\": \"Nessun piano attivo da ottimizzare.\"}")
        }

        let modification = arguments["modification"]?.stringValue ?? "increase_volume"
        let percentage = arguments["percentage"]?.doubleValue ?? 10.0
        let factor = percentage / 100.0

        var optimized = plan
        optimized.lastModified = Date()

        switch modification {
        case "increase_volume":
            for i in 0..<optimized.weeklyPlan.count where optimized.weeklyPlan[i].workoutType != .rest {
                optimized.weeklyPlan[i].distance *= (1.0 + factor)
                optimized.weeklyPlan[i].estimatedDuration = Int(optimized.weeklyPlan[i].distance * 6)
            }
            optimized.title += " (Volume +\(Int(percentage))%)"

        case "decrease_volume":
            for i in 0..<optimized.weeklyPlan.count where optimized.weeklyPlan[i].workoutType != .rest {
                optimized.weeklyPlan[i].distance *= (1.0 - factor)
                optimized.weeklyPlan[i].estimatedDuration = Int(optimized.weeklyPlan[i].distance * 6)
            }
            optimized.title += " (Volume -\(Int(percentage))%)"

        case "add_speed":
            for i in 0..<optimized.weeklyPlan.count {
                if optimized.weeklyPlan[i].workoutType == .easy {
                    optimized.weeklyPlan[i].workoutType = .intervals
                    optimized.weeklyPlan[i].description = "Interval training: 6 × 800m a ritmo gara con 90\" recupero"
                    break
                }
            }
            optimized.title += " (Focus Velocità)"

        case "add_endurance":
            for i in 0..<optimized.weeklyPlan.count {
                if optimized.weeklyPlan[i].workoutType == .long {
                    optimized.weeklyPlan[i].distance *= 1.2
                    optimized.weeklyPlan[i].estimatedDuration = Int(optimized.weeklyPlan[i].distance * 6)
                    break
                }
            }
            optimized.title += " (Focus Resistenza)"

        default:
            break
        }

        planManager.savePlan(optimized)
        planManager.setActivePlan(optimized)

        let stats = planManager.getWeeklyStats(for: optimized)
        let result: [String: Any] = [
            "titolo": optimized.title,
            "km_totali": Int(stats.totalDistance),
            "allenamenti": stats.workoutCount,
            "messaggio": "Piano ottimizzato con successo!"
        ]
        return ToolResult(toolCallId: toolCallId, name: "optimize_plan", content: serializeJSON(result))
    }

    private func saveTrainingPlan(arguments: [String: JSONValue], userProfile: RunnerProfile, planManager: TrainingPlanManager, toolCallId: String) -> ToolResult {
        guard let weeklyPlan = lastCalculatedPlan else {
            return ToolResult(toolCallId: toolCallId, name: "save_training_plan", content: "{\"errore\": \"Nessun piano calcolato da salvare. Chiama prima calculate_training_plan.\"}")
        }

        let title = arguments["title"]?.stringValue ?? "Piano Personalizzato - \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none))"

        let plan = TrainingPlan(title: title, weeklyPlan: weeklyPlan, userProfile: userProfile)
        planManager.savePlan(plan)
        planManager.setActivePlan(plan)
        lastCalculatedPlan = nil

        let result: [String: Any] = [
            "messaggio": "Piano '\(title)' salvato e attivato con successo!",
            "id": plan.id.uuidString
        ]
        return ToolResult(toolCallId: toolCallId, name: "save_training_plan", content: serializeJSON(result))
    }

    // MARK: - Training Plan Distribution Logic

    private func generateDistribution(weeklyKm: Double, workoutsPerWeek: Int, goal: TrainingGoal, experience: ExperienceLevel) -> [DayTraining] {
        // Distribution percentages per goal type
        let distribution: [(dayOfWeek: String, type: WorkoutType, pct: Double, desc: String)]

        switch goal {
        case .speed:
            distribution = [
                ("LUNEDÌ", .rest, 0, "Riposo completo. Stretching dinamico + core stability."),
                ("MARTEDÌ", .intervals, 0.17, "Riscaldamento 3km progressivi. Lavoro: 8 × 200m veloci con 200m recupero + 4 × 400m a 95% con 2min recupero. Defaticamento 2km facili."),
                ("MERCOLEDÌ", .easy, 0.13, "Corsa a ritmo conversazionale per recupero attivo."),
                ("GIOVEDÌ", .tempo, 0.18, "Riscaldamento 2km facili. Lavoro: 400-800-1200-1600-1200-800-400m (recupero = metà distanza). Defaticamento 2km."),
                ("VENERDÌ", .rest, 0, "Riposo completo."),
                ("SABATO", .tempo, 0.20, "Ritmo soglia + 6 × 100m strides a fine seduta."),
                ("DOMENICA", .long, 0.32, "Lungo a ritmo aerobico per mantenere la base di resistenza."),
            ]

        case .endurance:
            distribution = [
                ("LUNEDÌ", .rest, 0, "Riposo completo."),
                ("MARTEDÌ", .easy, 0.15, "Zona 1-2, completamente aerobico."),
                ("MERCOLEDÌ", .tempo, 0.20, "Riscaldamento 3km + 20min di fartlek naturale (accelerazioni quando ti senti bene) + 3km facili."),
                ("GIOVEDÌ", .tempo, 0.18, "3km riscaldamento + corsa a ritmo medio + defaticamento facile."),
                ("VENERDÌ", .recovery, 0.12, "Recupero attivo, ritmo molto comodo."),
                ("SABATO", .long, 0.35, "Primi 60% a ritmo aerobico, poi progressivo fino a ritmo medio."),
                ("DOMENICA", .rest, 0, "Riposo attivo: bici, nuoto o camminata in natura."),
            ]

        case .fitness:
            distribution = [
                ("LUNEDÌ", .rest, 0, "Riposo completo."),
                ("MARTEDÌ", .intervals, 0.15, "Riscaldamento 2km. Lavoro: 6 × 800m a ritmo gara con 90\" recupero. Defaticamento 1km."),
                ("MERCOLEDÌ", .easy, 0.18, "Tutto a ritmo conversazionale. Non guardare l'orologio!"),
                ("GIOVEDÌ", .tempo, 0.17, "Riscaldamento 2km facili. Lavoro: 20-25min a ritmo soglia. Defaticamento 2km lenti."),
                ("VENERDÌ", .recovery, 0.15, "Corsetta leggera, solo per muovere le gambe."),
                ("SABATO", .long, 0.35, "I primi 70% a ritmo facile, ultimi 30% progressivi."),
                ("DOMENICA", .rest, 0, "Giorno di riposo attivo: stretching, camminata o altre attività."),
            ]

        case .weightLoss:
            distribution = [
                ("LUNEDÌ", .easy, 0.14, "Camminata veloce + corsa alternata."),
                ("MARTEDÌ", .intervals, 0.12, "HIIT: 10 × 1min veloce / 1min recupero."),
                ("MERCOLEDÌ", .easy, 0.16, "Corsa aerobica a ritmo costante."),
                ("GIOVEDÌ", .recovery, 0.10, "Recupero attivo leggero."),
                ("VENERDÌ", .intervals, 0.13, "Circuit training: corsa + bodyweight."),
                ("SABATO", .long, 0.35, "Lungo a bassa intensità, zona brucia grassi."),
                ("DOMENICA", .rest, 0, "Riposo completo."),
            ]

        case .racePrep:
            distribution = [
                ("LUNEDÌ", .rest, 0, "Riposo pre-ciclo."),
                ("MARTEDÌ", .easy, 0.12, "Shakeout run leggero."),
                ("MERCOLEDÌ", .intervals, 0.16, "Ripetute a ritmo gara specifico."),
                ("GIOVEDÌ", .easy, 0.14, "Corsa facile."),
                ("VENERDÌ", .rest, 0, "Riposo completo."),
                ("SABATO", .tempo, 0.23, "Simulazione gara: ritmo obiettivo."),
                ("DOMENICA", .long, 0.35, "Lungo progressivo verso ritmo gara."),
            ]
        }

        // Adjust for number of workouts: if fewer workouts requested, convert some sessions to rest
        var plan = distribution.map { item -> DayTraining in
            let km = item.pct * weeklyKm
            let duration = item.type == .rest ? 0 : Int(km * estimatedPaceMinPerKm(for: item.type, experience: experience))
            return DayTraining(
                dayOfWeek: item.dayOfWeek,
                workoutType: item.type,
                description: item.desc,
                distance: round(km * 10) / 10, // 1 decimal
                estimatedDuration: duration
            )
        }

        // Count active workouts and reduce if needed
        let activeWorkouts = plan.filter { $0.workoutType != .rest }.count
        if workoutsPerWeek < activeWorkouts {
            let toRemove = activeWorkouts - workoutsPerWeek
            // Remove lowest priority workouts (recovery first, then easy)
            var removed = 0
            let priorityOrder: [WorkoutType] = [.recovery, .easy, .tempo]
            for type in priorityOrder {
                for i in 0..<plan.count where removed < toRemove {
                    if plan[i].workoutType == type {
                        plan[i] = DayTraining(
                            dayOfWeek: plan[i].dayOfWeek,
                            workoutType: .rest,
                            description: "Riposo.",
                            distance: 0,
                            estimatedDuration: 0
                        )
                        removed += 1
                    }
                }
                if removed >= toRemove { break }
            }

            // Redistribute removed km to remaining active workouts
            let removedKm = weeklyKm - plan.reduce(0) { $0 + $1.distance }
            let remainingActive = plan.filter { $0.workoutType != .rest }
            if !remainingActive.isEmpty {
                let extraPerWorkout = removedKm / Double(remainingActive.count)
                for i in 0..<plan.count where plan[i].workoutType != .rest {
                    plan[i].distance += round(extraPerWorkout * 10) / 10
                    plan[i].estimatedDuration = Int(plan[i].distance * estimatedPaceMinPerKm(for: plan[i].workoutType, experience: experience))
                }
            }
        }

        return plan
    }

    private func estimatedPaceMinPerKm(for type: WorkoutType, experience: ExperienceLevel) -> Double {
        let basePace: Double
        switch experience {
        case .beginner: basePace = 7.0
        case .intermediate: basePace = 6.0
        case .advanced: basePace = 5.5
        case .elite: basePace = 5.0
        }

        switch type {
        case .rest: return 0
        case .recovery: return basePace + 1.0
        case .easy: return basePace + 0.5
        case .long: return basePace + 0.3
        case .tempo: return basePace - 0.3
        case .intervals: return basePace - 0.5
        }
    }

    // MARK: - Helpers

    private func mapGoal(_ str: String) -> TrainingGoal {
        switch str.lowercased() {
        case "speed", "velocità": return .speed
        case "endurance", "resistenza": return .endurance
        case "fitness", "mantenersi in forma": return .fitness
        case "weight_loss", "perdere peso": return .weightLoss
        case "race_prep", "preparazione gara": return .racePrep
        default: return .fitness
        }
    }

    private func mapExperience(_ str: String) -> ExperienceLevel {
        switch str.lowercased() {
        case "beginner", "principiante": return .beginner
        case "intermediate", "intermedio": return .intermediate
        case "advanced", "avanzato": return .advanced
        case "elite": return .elite
        default: return .intermediate
        }
    }

    // MARK: - Health Summary Tool

    private func getHealthSummary(arguments: [String: JSONValue], healthManager: HealthKitManager?, toolCallId: String) async -> ToolResult {
        guard let manager = healthManager else {
            return ToolResult(
                toolCallId: toolCallId,
                name: "get_health_summary",
                content: "{\"errore\": \"HealthKit non configurato.\"}"
            )
        }

        guard manager.isAvailable else {
            return ToolResult(
                toolCallId: toolCallId,
                name: "get_health_summary",
                content: "{\"errore\": \"HealthKit non disponibile su questo dispositivo.\"}"
            )
        }

        // Request authorization if needed (shows system dialog)
        if !manager.isAuthorized {
            let authorized = await manager.requestAuthorization()
            if !authorized {
                return ToolResult(
                    toolCallId: toolCallId,
                    name: "get_health_summary",
                    content: "{\"messaggio\": \"L'utente non ha ancora autorizzato l'accesso ai dati Salute. Suggerisci di aprire Impostazioni > Salute > Accesso Dati per autorizzare Run with Bobby.\"}"
                )
            }
        }

        let days = arguments["days"]?.intValue ?? 7
        let summary = await manager.fetchHealthSummary(days: days)
        return ToolResult(toolCallId: toolCallId, name: "get_health_summary", content: serializeJSON(summary))
    }

    private func serializeJSON(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }
}

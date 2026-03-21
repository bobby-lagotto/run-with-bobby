import Foundation
import MLX
import MLXNN

class BobbyAI: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var model: MLXModel?
    private let systemPrompt = """
    Sei Bobby, un coach di corsa esperto e motivante. Sei specializzato nella creazione di piani di allenamento personalizzati per runner di ogni livello.
    
    Le tue caratteristiche:
    - Comunicazione diretta e motivante
    - Conoscenza approfondita dell'allenamento della corsa
    - Capacità di adattare i piani in base al livello e agli obiettivi
    - Attenzione alla progressione graduale e alla prevenzione infortuni
    
    Quando generi un piano di allenamento, includi sempre:
    - Giorni specifici della settimana
    - Tipo di allenamento
    - Distanza e ritmo
    - Descrizione dettagliata di riscaldamento, lavoro e defaticamento
    - Note motivazionali e tecniche
    
    Formato esempio:
    LUNEDÌ — Riposo
    Recupero completo. Al massimo una passeggiata.
    
    MARTEDÌ — Interval Training · 11 km
    Riscaldamento: 2 km a 5:40/km...
    
    Adatta sempre il piano alle caratteristiche specifiche dell'utente.
    """
    
    init() {
        loadModel()
    }
    
    private func loadModel() {
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            do {
                // Carica un modello locale leggero (es. phi-3-mini o llama-3.2-1b)
                // Per ora simuliamo il caricamento - in produzione caricheresti il modello MLX
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 secondo
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Errore nel caricamento del modello: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func generateResponse(to userMessage: String, userProfile: RunnerProfile, conversationHistory: [ChatMessage]) async -> String {
        await MainActor.run {
            isLoading = true
        }
        
        defer {
            Task {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
        
        // Per ora usiamo una logica simulata - in produzione useresti MLX
        return await generateSimulatedResponse(userMessage: userMessage, userProfile: userProfile)
    }
    
    private func generateSimulatedResponse(userMessage: String, userProfile: RunnerProfile) async -> String {
        // Simula processing time
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        let message = userMessage.lowercased()
        
        // Logica di risposta basata su pattern
        if message.contains("ciao") || message.contains("salve") || message.contains("buongiorno") {
            return "Ciao! Sono Bobby, il tuo personal trainer di corsa! 🏃‍♂️\n\nPer creare il piano perfetto per te, dimmi:\n• Quanti km corri alla settimana?\n• Quanti allenamenti fai?\n• Qual è il tuo obiettivo principale?"
        }
        
        if message.contains("km") && (message.contains("settimana") || message.contains("settimanali")) {
            return "Perfetto! E quanti allenamenti riesci a fare alla settimana? Generalmente sono consigliabili 3-5 sessioni per un buon equilibrio tra progresso e recupero."
        }
        
        if message.contains("allenamenti") || message.contains("sessioni") {
            return "Ottimo! Ora dimmi qual è il tuo obiettivo principale:\n\n🚀 Migliorare la velocità\n💪 Aumentare la resistenza\n🏃‍♂️ Mantenersi in forma\n⚖️ Perdere peso\n🏆 Preparazione gara\n\nE qual è il tuo ritmo attuale per km?"
        }
        
        if message.contains("velocità") || message.contains("speed") {
            return generateSpeedFocusedPlan(userProfile: userProfile)
        }
        
        if message.contains("resistenza") || message.contains("endurance") {
            return generateEndurancePlan(userProfile: userProfile)
        }
        
        if message.contains("piano") || message.contains("programma") || message.contains("allenamento") {
            return generateBasicTrainingPlan(userProfile: userProfile)
        }
        
        if message.contains("modifica") || message.contains("cambia") || message.contains("ottimizza") {
            return "Perfetto! Posso ottimizzare il tuo piano. Dimmi cosa vorresti modificare:\n\n• Aumentare o diminuire il volume?\n• Cambiare il focus (velocità/resistenza)?\n• Modificare i giorni di allenamento?\n• Altro?"
        }
        
        // Risposta generica motivante
        return "Ottima domanda! Come Bobby, sono qui per aiutarti a raggiungere i tuoi obiettivi di corsa. Condividi più dettagli sui tuoi allenamenti attuali e posso darti consigli specifici o creare un piano personalizzato! 🏃‍♂️💪"
    }
    
    private func generateBasicTrainingPlan(userProfile: RunnerProfile) -> String {
        let weeklyKm = Int(userProfile.weeklyKilometers)
        let workouts = userProfile.workoutsPerWeek
        
        return """
        🏃‍♂️ **PIANO SETTIMANALE PERSONALIZZATO**
        *Basato su \(weeklyKm)km/settimana, \(workouts) allenamenti*
        
        **LUNEDÌ** — Riposo
        Recupero completo. Al massimo una passeggiata tranquilla.
        
        **MARTEDÌ** — Interval Training · \(Int(Double(weeklyKm) * 0.25))km
        Riscaldamento: 2km a ritmo facile
        Lavoro: 6 × 800m a ritmo gara con 90" recupero
        Defaticamento: 1km lento
        
        **MERCOLEDÌ** — Corsa Facile · \(Int(Double(weeklyKm) * 0.3))km
        Tutto a ritmo conversazionale. Non guardare l'orologio!
        
        **GIOVEDÌ** — Tempo Run · \(Int(Double(weeklyKm) * 0.35))km
        Riscaldamento: 2km facili
        Lavoro: 20-25min a ritmo soglia
        Defaticamento: 2km lenti
        
        **VENERDÌ** — Recupero · \(Int(Double(weeklyKm) * 0.2))km
        Corsetta leggera, solo per muovere le gambe.
        
        **SABATO** — Lungo · \(Int(Double(weeklyKm) * 0.45))km ⭐
        I primi 70% a ritmo facile, ultimi 30% progressivi.
        
        **DOMENICA** — Riposo
        Giorno di riposo attivo: stretching, camminata o altre attività.
        
        💡 **Nota**: Ascolta sempre il tuo corpo. Se senti fatica eccessiva, non esitare a prendere un giorno extra di riposo!
        """
    }
    
    private func generateSpeedFocusedPlan(userProfile: RunnerProfile) -> String {
        return """
        ⚡ **PIANO FOCUS VELOCITÀ**
        *Piano specifico per migliorare la tua velocità di corsa*
        
        **LUNEDÌ** — Riposo Attivo
        Stretching dinamico + core stability (15-20 min)
        
        **MARTEDÌ** — Sprint Intervals · 10km
        Riscaldamento: 3km progressivi
        Lavoro: 8 × 200m all-out con 200m recupero camminando
        + 4 × 400m a 95% con 2min recupero
        Defaticamento: 2km facili
        
        **MERCOLEDÌ** — Corsa Facile · 8km
        Ritmo conversazionale per recupero attivo
        
        **GIOVEDÌ** — Pyramid Training · 11km
        Riscaldamento: 2km facili
        Lavoro: 400-800-1200-1600-1200-800-400m
        (recupero = metà della distanza percorsa)
        Defaticamento: 2km
        
        **VENERDÌ** — Riposo
        
        **SABATO** — Tempo Run + Strides · 12km
        6km a ritmo soglia + 6 × 100m strides
        
        **DOMENICA** — Lungo Facile · 16km
        Ritmo aerobico per mantenere la base
        
        🎯 **Focus**: Questo piano sviluppa potenza anaerobica e velocità neuromuscolari. Fondamentale rispettare i recuperi!
        """
    }
    
    private func generateEndurancePlan(userProfile: RunnerProfile) -> String {
        return """
        💪 **PIANO FOCUS RESISTENZA**
        *Costruiamo la tua base aerobica*
        
        **LUNEDÌ** — Riposo
        
        **MARTEDÌ** — Corsa Facile · 10km
        Zona 1-2, completamente aerobico
        
        **MERCOLEDÌ** — Fartlek · 12km
        Riscaldamento 3km + 20min di fartlek naturale
        (accelerazioni quando ti senti bene) + 3km facili
        
        **GIOVEDÌ** — Medio · 13km
        3km riscaldamento + 6km a ritmo medio + 4km facili
        
        **VENERDÌ** — Corsa Facile · 8km
        Recupero attivo, ritmo molto comodo
        
        **SABATO** — Lungo Progressivo · 22km ⭐
        Km 1-12: ritmo aerobico
        Km 13-18: ritmo medio
        Km 19-22: ritmo sostenuto
        
        **DOMENICA** — Cross Training
        Bici, nuoto o camminata in natura (45-60min)
        
        🔋 **Obiettivo**: Aumentare la capacità del sistema cardiovascolare e l'efficienza metabolica. La pazienza è la chiave!
        """
    }
    
    func extractTrainingPlan(from response: String, userProfile: RunnerProfile) -> TrainingPlan? {
        // Estrai il piano di allenamento dalla risposta e convertilo in TrainingPlan
        let days = ["LUNEDÌ", "MARTEDÌ", "MERCOLEDÌ", "GIOVEDÌ", "VENERDÌ", "SABATO", "DOMENICA"]
        var weeklyPlan: [DayTraining] = []
        
        for day in days {
            if let dayInfo = extractDayInfo(from: response, dayName: day) {
                weeklyPlan.append(dayInfo)
            }
        }
        
        if !weeklyPlan.isEmpty {
            let title = extractPlanTitle(from: response)
            return TrainingPlan(title: title, weeklyPlan: weeklyPlan, userProfile: userProfile)
        }
        
        return nil
    }
    
    private func extractDayInfo(from text: String, dayName: String) -> DayTraining? {
        // Semplificata - in produzione useresti regex più sofisticati
        let lines = text.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            if line.contains(dayName) {
                let workoutLine = line.replacingOccurrences(of: "*", with: "")
                let components = workoutLine.components(separatedBy: "—")
                
                if components.count >= 2 {
                    let workoutInfo = components[1].trimmingCharacters(in: .whitespaces)
                    let workoutType = determineWorkoutType(from: workoutInfo)
                    let distance = extractDistance(from: workoutInfo)
                    
                    // Cerca la descrizione nelle righe successive
                    var description = ""
                    for i in (index + 1)..<min(index + 4, lines.count) {
                        if !lines[i].trimmingCharacters(in: .whitespaces).isEmpty &&
                           !lines[i].contains("**") {
                            description += lines[i].trimmingCharacters(in: .whitespaces) + "\n"
                        }
                    }
                    
                    return DayTraining(
                        dayOfWeek: dayName,
                        workoutType: workoutType,
                        description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                        distance: distance,
                        estimatedDuration: Int(distance * 6), // stima 6 min/km
                        paceZones: []
                    )
                }
            }
        }
        
        return nil
    }
    
    private func determineWorkoutType(from text: String) -> WorkoutType {
        let lowercased = text.lowercased()
        
        if lowercased.contains("riposo") { return .rest }
        if lowercased.contains("interval") || lowercased.contains("sprint") { return .intervals }
        if lowercased.contains("tempo") || lowercased.contains("medio") { return .tempo }
        if lowercased.contains("lungo") { return .long }
        if lowercased.contains("recupero") || lowercased.contains("leggera") { return .recovery }
        
        return .easy
    }
    
    private func extractDistance(from text: String) -> Double {
        // Cerca pattern come "10km" o "10 km"
        let regex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*km"#, options: .caseInsensitive)
        if let match = regex?.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
            if let range = Range(match.range(at: 1), in: text) {
                return Double(text[range]) ?? 5.0
            }
        }
        return 5.0 // default
    }
    
    private func extractPlanTitle(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("**") && (line.contains("PIANO") || line.contains("FOCUS")) {
                return line.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return "Piano Personalizzato - \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none))"
    }
}

// Estensione per il supporto MLX (placeholder per integrazione futura)
extension BobbyAI {
    private class MLXModel {
        // Placeholder per il modello MLX
        // In produzione caricheresti qui il modello locale
    }
    
    private func loadMLXModel() async throws -> MLXModel {
        // Implementazione del caricamento del modello MLX
        // Es: phi-3-mini, llama-3.2-1b, o altri modelli ottimizzati per mobile
        throw NSError(domain: "MLXModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Modello non ancora implementato"])
    }
}
import Foundation
import SwiftUI

class TrainingPlanManager: ObservableObject {
    @Published var savedPlans: [TrainingPlan] = []
    @Published var currentActivePlan: TrainingPlan?
    @Published var isLoading = false
    
    private let plansDirectory: URL
    private let activePlanURL: URL
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        plansDirectory = documentsPath.appendingPathComponent("TrainingPlans")
        activePlanURL = documentsPath.appendingPathComponent("active_plan.json")
        
        createDirectoryIfNeeded()
        loadAllPlans()
        loadActivePlan()
    }
    
    // MARK: - Directory Setup
    private func createDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: plansDirectory.path) {
            try? FileManager.default.createDirectory(at: plansDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Plan Management
    func savePlan(_ plan: TrainingPlan) {
        let filename = "\(plan.id.uuidString).json"
        let fileURL = plansDirectory.appendingPathComponent(filename)
        
        do {
            let data = try JSONEncoder().encode(plan)
            try data.write(to: fileURL)
            
            // Aggiorna la lista locale
            if let existingIndex = savedPlans.firstIndex(where: { $0.id == plan.id }) {
                savedPlans[existingIndex] = plan
            } else {
                savedPlans.append(plan)
            }
            
            // Ordina per data più recente
            savedPlans.sort { $0.lastModified > $1.lastModified }
            
        } catch {
            print("Errore nel salvataggio del piano: \(error)")
        }
    }
    
    func loadAllPlans() {
        isLoading = true
        defer { isLoading = false }
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: plansDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        var plans: [TrainingPlan] = []
        
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let plan = try? JSONDecoder().decode(TrainingPlan.self, from: data) {
                plans.append(plan)
            }
        }
        
        // Ordina per data di modifica più recente
        savedPlans = plans.sorted { $0.lastModified > $1.lastModified }
    }
    
    func deletePlan(_ plan: TrainingPlan) {
        let filename = "\(plan.id.uuidString).json"
        let fileURL = plansDirectory.appendingPathComponent(filename)
        
        try? FileManager.default.removeItem(at: fileURL)
        savedPlans.removeAll { $0.id == plan.id }
        
        // Se era il piano attivo, rimuovilo
        if currentActivePlan?.id == plan.id {
            currentActivePlan = nil
            try? FileManager.default.removeItem(at: activePlanURL)
        }
    }
    
    func setActivePlan(_ plan: TrainingPlan) {
        currentActivePlan = plan
        saveActivePlan()
    }
    
    private func saveActivePlan() {
        guard let plan = currentActivePlan else {
            try? FileManager.default.removeItem(at: activePlanURL)
            return
        }
        
        do {
            let data = try JSONEncoder().encode(plan)
            try data.write(to: activePlanURL)
        } catch {
            print("Errore nel salvataggio del piano attivo: \(error)")
        }
    }
    
    private func loadActivePlan() {
        guard let data = try? Data(contentsOf: activePlanURL),
              let plan = try? JSONDecoder().decode(TrainingPlan.self, from: data) else {
            return
        }
        
        currentActivePlan = plan
    }
    
    // MARK: - Plan Optimization
    func optimizePlan(_ plan: TrainingPlan, with feedback: String) -> TrainingPlan {
        var optimizedPlan = plan
        optimizedPlan.lastModified = Date()
        
        // Logica di ottimizzazione basata sul feedback
        if feedback.lowercased().contains("troppo") && feedback.lowercased().contains("km") {
            // Riduci il volume totale del 10%
            for i in 0..<optimizedPlan.weeklyPlan.count {
                optimizedPlan.weeklyPlan[i].distance *= 0.9
                optimizedPlan.weeklyPlan[i].estimatedDuration = Int(optimizedPlan.weeklyPlan[i].distance * 6)
            }
            optimizedPlan.title += " (Volume Ridotto)"
        }
        
        if feedback.lowercased().contains("poco") || feedback.lowercased().contains("aumenta") {
            // Aumenta il volume del 15%
            for i in 0..<optimizedPlan.weeklyPlan.count {
                if optimizedPlan.weeklyPlan[i].workoutType != .rest {
                    optimizedPlan.weeklyPlan[i].distance *= 1.15
                    optimizedPlan.weeklyPlan[i].estimatedDuration = Int(optimizedPlan.weeklyPlan[i].distance * 6)
                }
            }
            optimizedPlan.title += " (Volume Aumentato)"
        }
        
        if feedback.lowercased().contains("velocità") {
            // Aggiungi più allenamenti di velocità
            for i in 0..<optimizedPlan.weeklyPlan.count {
                if optimizedPlan.weeklyPlan[i].workoutType == .easy && i < optimizedPlan.weeklyPlan.count - 1 {
                    optimizedPlan.weeklyPlan[i].workoutType = .intervals
                    optimizedPlan.weeklyPlan[i].description = "Interval training aggiunto - 6 × 800m a ritmo gara"
                    break
                }
            }
            optimizedPlan.title += " (Focus Velocità)"
        }
        
        if feedback.lowercased().contains("resistenza") {
            // Aumenta il lungo del sabato
            for i in 0..<optimizedPlan.weeklyPlan.count {
                if optimizedPlan.weeklyPlan[i].workoutType == .long {
                    optimizedPlan.weeklyPlan[i].distance *= 1.2
                    optimizedPlan.weeklyPlan[i].estimatedDuration = Int(optimizedPlan.weeklyPlan[i].distance * 6)
                    break
                }
            }
            optimizedPlan.title += " (Focus Resistenza)"
        }
        
        return optimizedPlan
    }
    
    // MARK: - Statistics
    func getWeeklyStats(for plan: TrainingPlan) -> WeeklyStats {
        var totalDistance: Double = 0
        var totalDuration: Int = 0
        var workoutCount = 0
        var workoutTypes: [WorkoutType: Int] = [:]
        
        for day in plan.weeklyPlan {
            totalDistance += day.distance
            totalDuration += day.estimatedDuration
            
            if day.workoutType != .rest {
                workoutCount += 1
            }
            
            workoutTypes[day.workoutType, default: 0] += 1
        }
        
        return WeeklyStats(
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            workoutCount: workoutCount,
            workoutDistribution: workoutTypes
        )
    }
    
    func getPlanTrends() -> [PlanTrend] {
        let sortedPlans = savedPlans.sorted { $0.createdAt < $1.createdAt }
        var trends: [PlanTrend] = []
        
        for plan in sortedPlans {
            let stats = getWeeklyStats(for: plan)
            trends.append(PlanTrend(
                date: plan.createdAt,
                weeklyDistance: stats.totalDistance,
                workoutCount: stats.workoutCount
            ))
        }
        
        return trends
    }
    
    // MARK: - Export/Import
    func exportPlan(_ plan: TrainingPlan) -> URL? {
        let fileName = "\(plan.title)_\(DateFormatter.shortDate.string(from: plan.createdAt)).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            let data = try JSONEncoder().encode(plan)
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("Errore nell'export: \(error)")
            return nil
        }
    }
    
    func importPlan(from url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let plan = try JSONDecoder().decode(TrainingPlan.self, from: data)
            savePlan(plan)
            return true
        } catch {
            print("Errore nell'import: \(error)")
            return false
        }
    }
    
    // MARK: - Plan Templates
    func getTemplateNamesForGoal(_ goal: TrainingGoal) -> [String] {
        switch goal {
        case .speed:
            return ["Piano Velocità Base", "Piano Sprint Avanzato", "Piano 5K/10K"]
        case .endurance:
            return ["Piano Resistenza Base", "Piano Maratona", "Piano Ultra"]
        case .fitness:
            return ["Piano Benessere", "Piano Principianti", "Piano Mantenimento"]
        case .weightLoss:
            return ["Piano Dimagrimento", "Piano Brucia Grassi", "Piano Cardio"]
        case .racePrep:
            return ["Piano Pre-Gara", "Piano Tapering", "Piano Peak"]
        }
    }
    
    func createTemplateForGoal(_ goal: TrainingGoal, userProfile: RunnerProfile) -> TrainingPlan {
        // Crea un piano template basato sull'obiettivo
        var weeklyPlan: [DayTraining] = []
        let baseDistance = userProfile.weeklyKilometers / Double(userProfile.workoutsPerWeek)
        
        switch goal {
        case .speed:
            weeklyPlan = createSpeedTemplate(baseDistance: baseDistance)
        case .endurance:
            weeklyPlan = createEnduranceTemplate(baseDistance: baseDistance)
        case .fitness:
            weeklyPlan = createFitnessTemplate(baseDistance: baseDistance)
        case .weightLoss:
            weeklyPlan = createWeightLossTemplate(baseDistance: baseDistance)
        case .racePrep:
            weeklyPlan = createRacePrepTemplate(baseDistance: baseDistance)
        }
        
        return TrainingPlan(
            title: "Template \(goal.rawValue)",
            weeklyPlan: weeklyPlan,
            userProfile: userProfile
        )
    }
    
    private func createSpeedTemplate(baseDistance: Double) -> [DayTraining] {
        return [
            DayTraining(dayOfWeek: "LUNEDÌ", workoutType: .rest, description: "Riposo completo", distance: 0, estimatedDuration: 0),
            DayTraining(dayOfWeek: "MARTEDÌ", workoutType: .intervals, description: "6 × 800m a ritmo gara", distance: baseDistance * 1.2, estimatedDuration: Int(baseDistance * 1.2 * 6)),
            DayTraining(dayOfWeek: "MERCOLEDÌ", workoutType: .easy, description: "Corsa facile di recupero", distance: baseDistance * 0.8, estimatedDuration: Int(baseDistance * 0.8 * 6)),
            DayTraining(dayOfWeek: "GIOVEDÌ", workoutType: .tempo, description: "Tempo run 20 minuti", distance: baseDistance, estimatedDuration: Int(baseDistance * 6)),
            DayTraining(dayOfWeek: "VENERDÌ", workoutType: .rest, description: "Riposo", distance: 0, estimatedDuration: 0),
            DayTraining(dayOfWeek: "SABATO", workoutType: .intervals, description: "Sprint 100m + strides", distance: baseDistance * 0.7, estimatedDuration: Int(baseDistance * 0.7 * 6)),
            DayTraining(dayOfWeek: "DOMENICA", workoutType: .long, description: "Lungo aerobico", distance: baseDistance * 1.8, estimatedDuration: Int(baseDistance * 1.8 * 6))
        ]
    }
    
    private func createEnduranceTemplate(baseDistance: Double) -> [DayTraining] {
        return [
            DayTraining(dayOfWeek: "LUNEDÌ", workoutType: .rest, description: "Riposo", distance: 0, estimatedDuration: 0),
            DayTraining(dayOfWeek: "MARTEDÌ", workoutType: .easy, description: "Corsa aerobica", distance: baseDistance, estimatedDuration: Int(baseDistance * 6)),
            DayTraining(dayOfWeek: "MERCOLEDÌ", workoutType: .tempo, description: "Medio 30 minuti", distance: baseDistance * 1.2, estimatedDuration: Int(baseDistance * 1.2 * 6)),
            DayTraining(dayOfWeek: "GIOVEDÌ", workoutType: .easy, description: "Corsa facile", distance: baseDistance * 0.9, estimatedDuration: Int(baseDistance * 0.9 * 6)),
            DayTraining(dayOfWeek: "VENERDÌ", workoutType: .recovery, description: "Recupero attivo", distance: baseDistance * 0.6, estimatedDuration: Int(baseDistance * 0.6 * 6)),
            DayTraining(dayOfWeek: "SABATO", workoutType: .long, description: "Lungo progressivo", distance: baseDistance * 2.2, estimatedDuration: Int(baseDistance * 2.2 * 6)),
            DayTraining(dayOfWeek: "DOMENICA", workoutType: .easy, description: "Cross training", distance: 0, estimatedDuration: 45)
        ]
    }
    
    private func createFitnessTemplate(baseDistance: Double) -> [DayTraining] {
        return [
            DayTraining(dayOfWeek: "LUNEDÌ", workoutType: .easy, description: "Corsa leggera", distance: baseDistance * 0.8, estimatedDuration: Int(baseDistance * 0.8 * 6)),
            DayTraining(dayOfWeek: "MARTEDÌ", workoutType: .rest, description: "Riposo", distance: 0, estimatedDuration: 0),
            DayTraining(dayOfWeek: "MERCOLEDÌ", workoutType: .easy, description: "Corsa moderata", distance: baseDistance, estimatedDuration: Int(baseDistance * 6)),
            DayTraining(dayOfWeek: "GIOVEDÌ", workoutType: .rest, description: "Riposo", distance: 0, estimatedDuration: 0),
            DayTraining(dayOfWeek: "VENERDÌ", workoutType: .tempo, description: "Fartlek naturale", distance: baseDistance * 1.1, estimatedDuration: Int(baseDistance * 1.1 * 6)),
            DayTraining(dayOfWeek: "SABATO", workoutType: .rest, description: "Riposo", distance: 0, estimatedDuration: 0),
            DayTraining(dayOfWeek: "DOMENICA", workoutType: .long, description: "Lungo tranquillo", distance: baseDistance * 1.5, estimatedDuration: Int(baseDistance * 1.5 * 6))
        ]
    }
    
    private func createWeightLossTemplate(baseDistance: Double) -> [DayTraining] {
        return [
            DayTraining(dayOfWeek: "LUNEDÌ", workoutType: .easy, description: "Camminata veloce + corsa", distance: baseDistance * 0.9, estimatedDuration: Int(baseDistance * 0.9 * 7)),
            DayTraining(dayOfWeek: "MARTEDÌ", workoutType: .intervals, description: "HIIT 15 minuti", distance: baseDistance * 0.6, estimatedDuration: 30),
            DayTraining(dayOfWeek: "MERCOLEDÌ", workoutType: .easy, description: "Corsa aerobica", distance: baseDistance, estimatedDuration: Int(baseDistance * 6)),
            DayTraining(dayOfWeek: "GIOVEDÌ", workoutType: .recovery, description: "Recupero attivo", distance: baseDistance * 0.7, estimatedDuration: Int(baseDistance * 0.7 * 7)),
            DayTraining(dayOfWeek: "VENERDÌ", workoutType: .intervals, description: "Circuit training", distance: baseDistance * 0.5, estimatedDuration: 35),
            DayTraining(dayOfWeek: "SABATO", workoutType: .rest, description: "Riposo", distance: 0, estimatedDuration: 0),
            DayTraining(dayOfWeek: "DOMENICA", workoutType: .long, description: "Lungo a bassa intensità", distance: baseDistance * 1.8, estimatedDuration: Int(baseDistance * 1.8 * 6.5))
        ]
    }
    
    private func createRacePrepTemplate(baseDistance: Double) -> [DayTraining] {
        return [
            DayTraining(dayOfWeek: "LUNEDÌ", workoutType: .rest, description: "Riposo pre-gara", distance: 0, estimatedDuration: 0),
            DayTraining(dayOfWeek: "MARTEDÌ", workoutType: .easy, description: "Shakeout run", distance: baseDistance * 0.6, estimatedDuration: Int(baseDistance * 0.6 * 6)),
            DayTraining(dayOfWeek: "MERCOLEDÌ", workoutType: .intervals, description: "4 × 400m a ritmo gara", distance: baseDistance * 0.8, estimatedDuration: Int(baseDistance * 0.8 * 6)),
            DayTraining(dayOfWeek: "GIOVEDÌ", workoutType: .easy, description: "Corsa facile", distance: baseDistance * 0.7, estimatedDuration: Int(baseDistance * 0.7 * 6)),
            DayTraining(dayOfWeek: "VENERDÌ", workoutType: .rest, description: "Riposo completo", distance: 0, estimatedDuration: 0),
            DayTraining(dayOfWeek: "SABATO", workoutType: .easy, description: "Attivazione + strides", distance: baseDistance * 0.4, estimatedDuration: Int(baseDistance * 0.4 * 6)),
            DayTraining(dayOfWeek: "DOMENICA", workoutType: .tempo, description: "GIORNO GARA! 🏁", distance: 0, estimatedDuration: 0)
        ]
    }
}

// MARK: - Supporting Types
struct WeeklyStats {
    let totalDistance: Double
    let totalDuration: Int
    let workoutCount: Int
    let workoutDistribution: [WorkoutType: Int]
    
    var averageDistance: Double {
        workoutCount > 0 ? totalDistance / Double(workoutCount) : 0
    }
    
    var averageDuration: Int {
        workoutCount > 0 ? totalDuration / workoutCount : 0
    }
}

struct PlanTrend {
    let date: Date
    let weeklyDistance: Double
    let workoutCount: Int
}

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}
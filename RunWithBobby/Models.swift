import Foundation
import SwiftUI

// MARK: - Chat Models
struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    var content: String
    var isFromUser: Bool
    var timestamp: Date
    
    init(content: String, isFromUser: Bool) {
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = Date()
    }
}

struct Conversation: Identifiable, Codable {
    var id = UUID()
    var title: String
    var messages: [ChatMessage]
    var createdAt: Date
    var lastMessageAt: Date
    
    init(title: String = "Nuova Conversazione") {
        self.title = title
        self.messages = []
        self.createdAt = Date()
        self.lastMessageAt = Date()
    }
    
    mutating func addMessage(_ message: ChatMessage) {
        messages.append(message)
        lastMessageAt = message.timestamp
        
        // Auto-aggiorna il titolo se è ancora quello di default
        if title == "Nuova Conversazione" && !messages.isEmpty {
            title = messages.first?.content.prefix(30).description ?? "Chat"
        }
    }
}

// MARK: - Training Plan Models
struct TrainingPlan: Identifiable, Codable {
    var id = UUID()
    var title: String
    var weeklyPlan: [DayTraining]
    var userProfile: RunnerProfile
    var createdAt: Date
    var lastModified: Date
    
    init(title: String, weeklyPlan: [DayTraining], userProfile: RunnerProfile) {
        self.title = title
        self.weeklyPlan = weeklyPlan
        self.userProfile = userProfile
        self.createdAt = Date()
        self.lastModified = Date()
    }
}

struct DayTraining: Identifiable, Codable {
    var id = UUID()
    var dayOfWeek: String
    var workoutType: WorkoutType
    var description: String
    var distance: Double // km
    var estimatedDuration: Int // minuti
    var paceZones: [PaceZone]
    
    init(dayOfWeek: String, workoutType: WorkoutType, description: String, distance: Double, estimatedDuration: Int, paceZones: [PaceZone] = []) {
        self.dayOfWeek = dayOfWeek
        self.workoutType = workoutType
        self.description = description
        self.distance = distance
        self.estimatedDuration = estimatedDuration
        self.paceZones = paceZones
    }
}

enum WorkoutType: String, CaseIterable, Codable {
    case rest = "Riposo"
    case easy = "Corsa Facile"
    case tempo = "Tempo Run"
    case intervals = "Interval Training"
    case long = "Lungo"
    case recovery = "Recupero"
    
    var emoji: String {
        switch self {
        case .rest: return "🛌"
        case .easy: return "🚶‍♂️"
        case .tempo: return "🏃‍♂️"
        case .intervals: return "⚡"
        case .long: return "🏃‍♂️💪"
        case .recovery: return "🌱"
        }
    }
    
    var color: Color {
        switch self {
        case .rest: return .workoutRest
        case .easy: return .workoutEasy
        case .tempo: return .workoutTempo
        case .intervals: return .workoutIntervals
        case .long: return .workoutLong
        case .recovery: return .workoutRecovery
        }
    }

    var sfSymbol: String {
        switch self {
        case .rest: return "bed.double.fill"
        case .easy: return "figure.walk"
        case .tempo: return "figure.run"
        case .intervals: return "bolt.fill"
        case .long: return "figure.run.circle.fill"
        case .recovery: return "leaf.fill"
        }
    }
}

struct PaceZone: Codable {
    var zoneName: String
    var distance: Double // km
    var paceMin: String // formato "4:30"
    var paceMax: String // formato "4:45"
    var description: String
}

// MARK: - Nutrition Plan Models
struct NutritionPlan: Identifiable, Codable {
    var id = UUID()
    var title: String
    var linkedTrainingPlanId: UUID?
    var weeklyNutrition: [DayNutrition]
    var createdAt: Date
    var lastModified: Date

    init(title: String, linkedTrainingPlanId: UUID?, weeklyNutrition: [DayNutrition]) {
        self.title = title
        self.linkedTrainingPlanId = linkedTrainingPlanId
        self.weeklyNutrition = weeklyNutrition
        self.createdAt = Date()
        self.lastModified = Date()
    }
}

struct DayNutrition: Identifiable, Codable {
    var id = UUID()
    var dayOfWeek: String
    var trainingIntensity: String // "riposo", "leggero", "moderato", "intenso"
    var proteine_g: Int
    var carboidrati_g: Int
    var verdure_frutta_g: Int
    var dolci_g: Int
    var note: String
    var foodExamples: [FoodExample]

    init(dayOfWeek: String, trainingIntensity: String, proteine_g: Int, carboidrati_g: Int, verdure_frutta_g: Int, dolci_g: Int, note: String = "", foodExamples: [FoodExample] = []) {
        self.dayOfWeek = dayOfWeek
        self.trainingIntensity = trainingIntensity
        self.proteine_g = proteine_g
        self.carboidrati_g = carboidrati_g
        self.verdure_frutta_g = verdure_frutta_g
        self.dolci_g = dolci_g
        self.note = note
        self.foodExamples = foodExamples
    }
}

struct FoodExample: Identifiable, Codable {
    var id = UUID()
    var macroCategory: String // "proteine", "carboidrati", "verdure_frutta", "dolci"
    var foodName: String
    var grams: Int
}

// MARK: - Runner Profile
struct RunnerProfile: Codable {
    var weeklyKilometers: Double
    var workoutsPerWeek: Int
    var primaryGoal: TrainingGoal
    var secondaryGoals: [TrainingGoal]
    var currentPace: String // formato "5:00" (min/km)
    var raceDistance: RaceDistance?
    var experience: ExperienceLevel
    var weight: Double? // kg, opzionale

    init() {
        self.weeklyKilometers = 20
        self.workoutsPerWeek = 3
        self.primaryGoal = .fitness
        self.secondaryGoals = []
        self.currentPace = "5:30"
        self.raceDistance = nil
        self.experience = .beginner
        self.weight = nil
    }

    var effectiveWeight: Double {
        weight ?? 70.0
    }
}

enum TrainingGoal: String, CaseIterable, Codable {
    case speed = "Migliorare Velocità"
    case endurance = "Aumentare Resistenza"
    case fitness = "Mantenersi in Forma"
    case weightLoss = "Perdere Peso"
    case racePrep = "Preparazione Gara"
    
    var description: String {
        switch self {
        case .speed: return "Focus su allenamenti di velocità e interval training"
        case .endurance: return "Costruire la base aerobica con corse lunghe"
        case .fitness: return "Mantenere salute generale e benessere"
        case .weightLoss: return "Bruciare calorie con volume moderato-alto"
        case .racePrep: return "Preparazione specifica per una gara"
        }
    }
}

enum RaceDistance: String, CaseIterable, Codable {
    case fiveK = "5K"
    case tenK = "10K"
    case halfMarathon = "21K"
    case marathon = "42K"
    case ultraMarathon = "50K+"
}

enum ExperienceLevel: String, CaseIterable, Codable {
    case beginner = "Principiante"
    case intermediate = "Intermedio"
    case advanced = "Avanzato"
    case elite = "Elite"
}

// MARK: - App State Models
class AppState: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var trainingPlans: [TrainingPlan] = []
    @Published var currentConversation: Conversation?
    @Published var userProfile = RunnerProfile()
    @Published var isProfileComplete = false
    
    // Percorsi di salvataggio
    private let conversationsURL: URL
    private let trainingPlansURL: URL
    private let userProfileURL: URL
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        conversationsURL = documentsPath.appendingPathComponent("conversations.json")
        trainingPlansURL = documentsPath.appendingPathComponent("training_plans.json")
        userProfileURL = documentsPath.appendingPathComponent("user_profile.json")
        
        loadData()
    }
    
    func addMessage(_ content: String, isFromUser: Bool) {
        if currentConversation == nil {
            currentConversation = Conversation()
            conversations.insert(currentConversation!, at: 0)
        }
        
        let message = ChatMessage(content: content, isFromUser: isFromUser)
        currentConversation?.addMessage(message)
        
        // Aggiorna nell'array principale
        if let index = conversations.firstIndex(where: { $0.id == currentConversation?.id }) {
            conversations[index] = currentConversation!
        }
        
        saveConversations()
    }
    
    func startNewConversation() {
        currentConversation = Conversation()
        conversations.insert(currentConversation!, at: 0)
    }
    
    func switchToConversation(_ conversation: Conversation) {
        currentConversation = conversation
    }

    func deleteConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        if currentConversation?.id == conversation.id {
            currentConversation = conversations.first
        }
        saveConversations()
    }

    func addTrainingPlan(_ plan: TrainingPlan) {
        trainingPlans.append(plan)
        saveTrainingPlans()
    }
    
    // MARK: - Persistence
    private func loadData() {
        loadConversations()
        loadTrainingPlans()
        loadUserProfile()
    }
    
    private func loadConversations() {
        if let data = try? Data(contentsOf: conversationsURL),
           let conversations = try? JSONDecoder().decode([Conversation].self, from: data) {
            self.conversations = conversations
        }
    }
    
    private func saveConversations() {
        if let data = try? JSONEncoder().encode(conversations) {
            try? data.write(to: conversationsURL)
        }
    }
    
    private func loadTrainingPlans() {
        if let data = try? Data(contentsOf: trainingPlansURL),
           let plans = try? JSONDecoder().decode([TrainingPlan].self, from: data) {
            self.trainingPlans = plans
        }
    }
    
    private func saveTrainingPlans() {
        if let data = try? JSONEncoder().encode(trainingPlans) {
            try? data.write(to: trainingPlansURL)
        }
    }
    
    private func loadUserProfile() {
        if let data = try? Data(contentsOf: userProfileURL),
           let profile = try? JSONDecoder().decode(RunnerProfile.self, from: data) {
            self.userProfile = profile
            self.isProfileComplete = true
        }
    }
    
    func saveUserProfile() {
        if let data = try? JSONEncoder().encode(userProfile) {
            try? data.write(to: userProfileURL)
            isProfileComplete = true
        }
    }
}
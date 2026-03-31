import Foundation
import SwiftUI

class NutritionPlanManager: ObservableObject {
    @Published var savedPlans: [NutritionPlan] = []
    @Published var currentNutritionPlan: NutritionPlan?

    private let plansDirectory: URL
    private let activePlanURL: URL

    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        plansDirectory = documentsPath.appendingPathComponent("NutritionPlans")
        activePlanURL = documentsPath.appendingPathComponent("active_nutrition_plan.json")

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
    func savePlan(_ plan: NutritionPlan) {
        let filename = "\(plan.id.uuidString).json"
        let fileURL = plansDirectory.appendingPathComponent(filename)

        do {
            let data = try JSONEncoder().encode(plan)
            try data.write(to: fileURL)

            if let existingIndex = savedPlans.firstIndex(where: { $0.id == plan.id }) {
                savedPlans[existingIndex] = plan
            } else {
                savedPlans.append(plan)
            }

            savedPlans.sort { $0.lastModified > $1.lastModified }
        } catch {
            print("Errore nel salvataggio del piano alimentare: \(error)")
        }
    }

    func loadAllPlans() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: plansDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        var plans: [NutritionPlan] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let plan = try? JSONDecoder().decode(NutritionPlan.self, from: data) {
                plans.append(plan)
            }
        }

        savedPlans = plans.sorted { $0.lastModified > $1.lastModified }
    }

    func deletePlan(_ plan: NutritionPlan) {
        let filename = "\(plan.id.uuidString).json"
        let fileURL = plansDirectory.appendingPathComponent(filename)

        try? FileManager.default.removeItem(at: fileURL)
        savedPlans.removeAll { $0.id == plan.id }

        if currentNutritionPlan?.id == plan.id {
            currentNutritionPlan = nil
            try? FileManager.default.removeItem(at: activePlanURL)
        }
    }

    func setActivePlan(_ plan: NutritionPlan) {
        currentNutritionPlan = plan
        saveActivePlan()
    }

    private func saveActivePlan() {
        guard let plan = currentNutritionPlan else {
            try? FileManager.default.removeItem(at: activePlanURL)
            return
        }

        do {
            let data = try JSONEncoder().encode(plan)
            try data.write(to: activePlanURL)
        } catch {
            print("Errore nel salvataggio del piano alimentare attivo: \(error)")
        }
    }

    private func loadActivePlan() {
        guard let data = try? Data(contentsOf: activePlanURL),
              let plan = try? JSONDecoder().decode(NutritionPlan.self, from: data) else {
            return
        }
        currentNutritionPlan = plan
    }
}

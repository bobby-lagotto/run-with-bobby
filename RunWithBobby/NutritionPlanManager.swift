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
        SensitiveDataStore.createDirectoryIfNeeded(at: plansDirectory)
    }

    // MARK: - Plan Management
    func savePlan(_ plan: NutritionPlan) {
        let filename = "\(plan.id.uuidString).json"
        let fileURL = plansDirectory.appendingPathComponent(filename)

        do {
            let data = try JSONEncoder().encode(plan)
            try SensitiveDataStore.write(data, to: fileURL)

            if let existingIndex = savedPlans.firstIndex(where: { $0.id == plan.id }) {
                savedPlans[existingIndex] = plan
            } else {
                savedPlans.append(plan)
            }

            savedPlans.sort { $0.lastModified > $1.lastModified }
        } catch {
            PrivacyLog.storageError("Save nutrition plan", error: error)
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

        SensitiveDataStore.remove(fileURL)
        savedPlans.removeAll { $0.id == plan.id }

        if currentNutritionPlan?.id == plan.id {
            currentNutritionPlan = nil
            SensitiveDataStore.remove(activePlanURL)
        }
    }

    func deleteAllPlans() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: plansDirectory, includingPropertiesForKeys: nil) else {
            savedPlans = []
            currentNutritionPlan = nil
            SensitiveDataStore.remove(activePlanURL)
            return
        }

        for file in files where file.pathExtension == "json" {
            SensitiveDataStore.remove(file)
        }

        savedPlans = []
        currentNutritionPlan = nil
        SensitiveDataStore.remove(activePlanURL)
    }

    func setActivePlan(_ plan: NutritionPlan) {
        currentNutritionPlan = plan
        saveActivePlan()
    }

    private func saveActivePlan() {
        guard let plan = currentNutritionPlan else {
            SensitiveDataStore.remove(activePlanURL)
            return
        }

        do {
            let data = try JSONEncoder().encode(plan)
            try SensitiveDataStore.write(data, to: activePlanURL)
        } catch {
            PrivacyLog.storageError("Save active nutrition plan", error: error)
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

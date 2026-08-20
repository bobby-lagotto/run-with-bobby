import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private let bpmUnit = HKUnit.count().unitDivided(by: .minute())
    private let msUnit = HKUnit.secondUnit(with: .milli)
    private let vo2MaxUnit: HKUnit = {
        HKUnit.literUnit(with: .milli)
            .unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
    }()

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        let quantityIds: [HKQuantityTypeIdentifier] = [
            .heartRate, .restingHeartRate, .heartRateVariabilitySDNN,
            .stepCount, .distanceWalkingRunning, .activeEnergyBurned,
            .vo2Max, .oxygenSaturation
        ]
        for id in quantityIds {
            if let t = HKQuantityType.quantityType(forIdentifier: id) {
                types.insert(t)
            }
        }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }()

    private let shareTypes: Set<HKSampleType> = {
        [HKObjectType.workoutType()]
    }()

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
            await MainActor.run { self.isAuthorized = true }
            return true
        } catch {
            PrivacyLog.storageError("HealthKit authorization", error: error)
            return false
        }
    }

    // MARK: - Health Summary

    func fetchHealthSummary(days: Int = 7) async -> [String: Any] {
        guard isAvailable else {
            return ["errore": "HealthKit non disponibile su questo dispositivo"]
        }

        let now = Date()
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: now) else {
            return ["errore": "Errore nel calcolo delle date"]
        }

        var summary: [String: Any] = [
            "periodo": "ultimi \(days) giorni"
        ]

        // Heart rate
        if let hr = await fetchStatistic(.heartRate, unit: bpmUnit, option: .discreteAverage, start: startDate, end: now) {
            summary["frequenza_cardiaca_media_bpm"] = Int(hr)
        }
        if let hrMin = await fetchStatistic(.heartRate, unit: bpmUnit, option: .discreteMin, start: startDate, end: now) {
            summary["frequenza_cardiaca_minima_bpm"] = Int(hrMin)
        }
        if let hrMax = await fetchStatistic(.heartRate, unit: bpmUnit, option: .discreteMax, start: startDate, end: now) {
            summary["frequenza_cardiaca_massima_bpm"] = Int(hrMax)
        }
        if let rhr = await fetchStatistic(.restingHeartRate, unit: bpmUnit, option: .discreteAverage, start: startDate, end: now) {
            summary["frequenza_cardiaca_riposo_bpm"] = Int(rhr)
        }
        if let hrv = await fetchStatistic(.heartRateVariabilitySDNN, unit: msUnit, option: .discreteAverage, start: startDate, end: now) {
            summary["variabilita_cardiaca_hrv_ms"] = Int(hrv)
        }

        // Activity
        if let steps = await fetchStatistic(.stepCount, unit: .count(), option: .cumulativeSum, start: startDate, end: now) {
            summary["passi_totali"] = Int(steps)
            summary["passi_media_giornaliera"] = Int(steps / Double(days))
        }
        if let dist = await fetchStatistic(.distanceWalkingRunning, unit: .meterUnit(with: .kilo), option: .cumulativeSum, start: startDate, end: now) {
            summary["distanza_totale_km"] = round(dist * 10) / 10
        }
        if let cal = await fetchStatistic(.activeEnergyBurned, unit: .kilocalorie(), option: .cumulativeSum, start: startDate, end: now) {
            summary["calorie_attive_totali_kcal"] = Int(cal)
            summary["calorie_media_giornaliera"] = Int(cal / Double(days))
        }

        // VO2 Max (latest reading)
        if let vo2 = await fetchLatestQuantity(.vo2Max, unit: vo2MaxUnit) {
            summary["vo2max_ml_kg_min"] = round(vo2 * 10) / 10
        }

        // SpO2
        if let spo2 = await fetchStatistic(.oxygenSaturation, unit: .percent(), option: .discreteAverage, start: startDate, end: now) {
            summary["saturazione_ossigeno_percent"] = round(spo2 * 1000) / 10
        }

        // Workouts
        let workouts = await fetchRecentWorkouts(limit: 10, start: startDate, end: now)
        if !workouts.isEmpty {
            summary["allenamenti_recenti"] = workouts
            summary["numero_allenamenti"] = workouts.count
        }

        // Sleep
        let sleepData = await fetchSleepData(start: startDate, end: now)
        if !sleepData.isEmpty {
            summary["sonno"] = sleepData
            let totalHours = sleepData.compactMap { $0["ore_sonno"] as? Double }.reduce(0, +)
            let nights = sleepData.count
            if nights > 0 {
                summary["sonno_media_ore"] = round(totalHours / Double(nights) * 10) / 10
            }
        }

        return summary
    }

    func fetchLoggedWorkouts(days: Int = 7) async -> [LoggedWorkout] {
        guard isAvailable else { return [] }
        let now = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -days, to: now) else { return [] }
        return await fetchWorkoutRecords(limit: 20, start: startDate, end: now)
    }

    func fetchHealthSignals(days: Int = 7) async -> HealthSignals {
        let summary = await fetchHealthSummary(days: days)
        let sleepHours = summary["sonno_media_ore"] as? Double
        let hrv = (summary["variabilita_cardiaca_hrv_ms"] as? Int).map(Double.init)
        let resting = (summary["frequenza_cardiaca_riposo_bpm"] as? Int).map(Double.init)
        return HealthSignals(sleepHours: sleepHours, hrvMs: hrv, restingHeartRate: resting)
    }

    func saveRunningWorkout(distanceKm: Double, durationMinutes: Int, endedAt: Date = Date()) async {
        guard isAvailable, distanceKm > 0 else { return }
        if !isAuthorized {
            _ = await requestAuthorization()
        }
        let duration = TimeInterval(max(1, durationMinutes) * 60)
        let start = endedAt.addingTimeInterval(-duration)
        let workout = HKWorkout(
            activityType: .running,
            start: start,
            end: endedAt,
            duration: duration,
            totalEnergyBurned: nil,
            totalDistance: HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: distanceKm),
            metadata: [HKMetadataKeyIndoorWorkout: false]
        )
        do {
            try await healthStore.save(workout)
        } catch {
            PrivacyLog.storageError("Save HealthKit workout", error: error)
        }
    }

    // MARK: - Query Helpers

    private func fetchStatistic(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        option: HKStatisticsOptions,
        start: Date,
        end: Date
    ) async -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: option
            ) { _, statistics, _ in
                let value: Double?
                switch option {
                case .discreteAverage:
                    value = statistics?.averageQuantity()?.doubleValue(for: unit)
                case .discreteMin:
                    value = statistics?.minimumQuantity()?.doubleValue(for: unit)
                case .discreteMax:
                    value = statistics?.maximumQuantity()?.doubleValue(for: unit)
                case .cumulativeSum:
                    value = statistics?.sumQuantity()?.doubleValue(for: unit)
                default:
                    value = nil
                }
                continuation.resume(returning: value)
            }
            self.healthStore.execute(query)
        }
    }

    private func fetchLatestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            self.healthStore.execute(query)
        }
    }

    // MARK: - Workouts

    private func fetchWorkoutRecords(limit: Int = 10, start: Date, end: Date) async -> [LoggedWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }
                let records = workouts.map { workout in
                    LoggedWorkout(
                        startDate: workout.startDate,
                        distanceKm: workout.totalDistance?.doubleValue(for: .meterUnit(with: .kilo)) ?? 0,
                        durationMinutes: Int(workout.duration / 60),
                        activityType: workout.workoutActivityType.displayName
                    )
                }
                continuation.resume(returning: records)
            }
            self.healthStore.execute(query)
        }
    }

    private func fetchRecentWorkouts(limit: Int = 10, start: Date, end: Date) async -> [[String: Any]] {
        let records = await fetchWorkoutRecords(limit: limit, start: start, end: end)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale(identifier: "it_IT")

        return records.map { workout in
            [
                "tipo": workout.activityType,
                "durata_minuti": workout.durationMinutes,
                "data": dateFormatter.string(from: workout.startDate),
                "distanza_km": round(workout.distanceKm * 10) / 10
            ]
        }
    }

    // MARK: - Sleep

    private func fetchSleepData(start: Date, end: Date) async -> [[String: Any]] {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let sleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        ]

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sleepSamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }

                var nightSleep: [String: Double] = [:]
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"

                for sample in sleepSamples {
                    guard sleepValues.contains(sample.value) else { continue }
                    let nightKey = dateFormatter.string(from: sample.startDate)
                    let hours = sample.endDate.timeIntervalSince(sample.startDate) / 3600
                    nightSleep[nightKey, default: 0] += hours
                }

                let results: [[String: Any]] = nightSleep
                    .sorted { $0.key > $1.key }
                    .prefix(7)
                    .map { (date, hours) in
                        ["data": date, "ore_sonno": round(hours * 10) / 10]
                    }

                continuation.resume(returning: results)
            }
            self.healthStore.execute(query)
        }
    }
}

// MARK: - Workout Activity Type Display Names
extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running: return "Corsa"
        case .walking: return "Camminata"
        case .cycling: return "Ciclismo"
        case .swimming: return "Nuoto"
        case .hiking: return "Escursionismo"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Allenamento Funzionale"
        case .traditionalStrengthTraining: return "Pesi"
        case .crossTraining: return "Cross Training"
        case .elliptical: return "Ellittica"
        case .rowing: return "Canottaggio"
        case .highIntensityIntervalTraining: return "HIIT"
        case .dance: return "Danza"
        case .cooldown: return "Defaticamento"
        case .coreTraining: return "Core Training"
        case .pilates: return "Pilates"
        case .stairClimbing: return "Scale"
        case .soccer: return "Calcio"
        case .tennis: return "Tennis"
        case .basketball: return "Basket"
        default: return "Altro"
        }
    }
}

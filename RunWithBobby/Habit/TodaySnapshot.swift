import Foundation

struct TodaySnapshot: Codable, Equatable {
    var dayTitle: String
    var workoutType: String
    var plannedKm: Double
    var sessionStatus: SessionStatus
    var recommendation: ReadinessRecommendation
    var briefingLine: String
    var weeklyAdherencePercent: Int
    var isRestDay: Bool
    var hasActivePlan: Bool

    static let empty = TodaySnapshot(
        dayTitle: "Oggi",
        workoutType: "Nessun piano",
        plannedKm: 0,
        sessionStatus: .planned,
        recommendation: .easy,
        briefingLine: "Nessun piano attivo. Chiedi a Bobby un piano prima di spingere.",
        weeklyAdherencePercent: 0,
        isRestDay: true,
        hasActivePlan: false
    )

    static func encode(_ snapshot: TodaySnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(snapshot)
    }

    static func decode(from data: Data) throws -> TodaySnapshot {
        try JSONDecoder().decode(TodaySnapshot.self, from: data)
    }
}

enum TodaySnapshotStore {
    static let appGroupId = "group.com.runwithbobby.app"
    static let filename = "today_snapshot.json"
    static let pendingActionFilename = "pending_habit_action.json"

    static func containerURL(fileManager: FileManager = .default) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
    }

    static func write(_ snapshot: TodaySnapshot, to directory: URL) throws {
        let url = directory.appendingPathComponent(filename)
        let data = try TodaySnapshot.encode(snapshot)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    static func write(_ snapshot: TodaySnapshot, fileManager: FileManager = .default) throws {
        guard let directory = containerURL(fileManager: fileManager) else { return }
        try write(snapshot, to: directory)
    }

    static func read(fileManager: FileManager = .default) -> TodaySnapshot? {
        guard let directory = containerURL(fileManager: fileManager) else { return nil }
        let url = directory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? TodaySnapshot.decode(from: data)
    }

    static func writePendingAction(_ action: PendingHabitAction, fileManager: FileManager = .default) throws {
        guard let directory = containerURL(fileManager: fileManager) else { return }
        let url = directory.appendingPathComponent(pendingActionFilename)
        let data = try JSONEncoder().encode(action)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    static func consumePendingAction(fileManager: FileManager = .default) -> PendingHabitAction? {
        guard let directory = containerURL(fileManager: fileManager) else { return nil }
        let url = directory.appendingPathComponent(pendingActionFilename)
        guard let data = try? Data(contentsOf: url),
              let action = try? JSONDecoder().decode(PendingHabitAction.self, from: data) else {
            return nil
        }
        try? fileManager.removeItem(at: url)
        return action
    }
}

struct PendingHabitAction: Codable, Equatable {
    var status: SessionStatus
    var loggedDistance: Double?
}

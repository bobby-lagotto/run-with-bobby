import SwiftUI

@main
struct BobbyWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchTodayView()
        }
    }
}

struct WatchTodayView: View {
    @State private var snapshot = TodaySnapshotStore.read() ?? .empty
    @State private var note: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.dayTitle)
                    .font(.headline)
                Text(snapshot.workoutType)
                if snapshot.plannedKm > 0 {
                    Text(String(format: "%.1f km", snapshot.plannedKm))
                }
                Text(snapshot.sessionStatus.localizedLabel)
                    .foregroundStyle(.secondary)
                Text(snapshot.briefingLine)
                    .font(.footnote)

                if snapshot.canMark {
                    Button(L10n.tr("Fatto", english: "Done")) { mark(.completed) }
                    Button(L10n.tr("Salta", english: "Skip")) { mark(.skipped) }
                }

                if let note {
                    Text(note)
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            snapshot = TodaySnapshotStore.read() ?? .empty
        }
    }

    private func mark(_ status: SessionStatus) {
        try? TodaySnapshotStore.writePendingAction(
            PendingHabitAction(status: status, loggedDistance: status == .completed ? snapshot.plannedKm : nil)
        )
        snapshot.sessionStatus = status
        note = status == .skipped
            ? L10n.tr("Saltato. Si sincronizza con iPhone.", english: "Skipped. Syncs with iPhone.")
            : L10n.tr("Fatto. Si sincronizza con iPhone.", english: "Done. Syncs with iPhone.")
    }
}

private extension TodaySnapshot {
    var canMark: Bool {
        hasActivePlan && !isRestDay && sessionStatus != .completed && sessionStatus != .skipped
    }
}

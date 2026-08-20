import SwiftUI
import WidgetKit

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: TodaySnapshot
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: Date(), snapshot: TodaySnapshotStore.read() ?? .empty))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = TodayEntry(date: Date(), snapshot: TodaySnapshotStore.read() ?? .empty)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct BobbyTodayWidgetView: View {
    var entry: TodayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.snapshot.dayTitle)
                .font(.caption.weight(.semibold))
            Text(entry.snapshot.workoutType)
                .font(.headline)
            if entry.snapshot.plannedKm > 0 {
                Text(String(format: "%.1f km", entry.snapshot.plannedKm))
                    .font(.subheadline)
            }
            Text(entry.snapshot.sessionStatus.italianLabel.capitalized)
                .font(.caption)
            Text(entry.snapshot.briefingLine)
                .font(.caption2)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

@main
struct BobbyTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BobbyTodayWidget", provider: TodayProvider()) { entry in
            if #available(iOS 17.0, *) {
                BobbyTodayWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                BobbyTodayWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Oggi con Bobby")
        .description("La seduta di oggi, senza dati extra.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

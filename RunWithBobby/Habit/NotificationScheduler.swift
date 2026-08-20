import Foundation
import UserNotifications

enum NotificationScheduler {
    static func apply(
        _ notifications: [PlannedNotification],
        center: UNUserNotificationCenter = .current()
    ) async {
        center.removePendingNotificationRequests(withIdentifiers: notifications.map(\.id) + leftoverIdentifiers(from: notifications))

        for item in notifications {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    static func requestAuthorization(center: UNUserNotificationCenter = .current()) async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    private static func leftoverIdentifiers(from notifications: [PlannedNotification]) -> [String] {
        let known = Set(notifications.map(\.id))
        let allDays = WeekdayKey.italianNames.values.map { "bobby.today.\(WeekdayKey.normalized($0))" }
        return allDays.filter { !known.contains($0) }
    }
}

import Foundation

enum NotificationPlanning {
    static func workoutReminders(
        for plan: TrainingPlan,
        from now: Date,
        calendar: Calendar = .current,
        hour: Int = 7,
        minute: Int = 0
    ) -> [PlannedNotification] {
        let weekStart = startOfWeek(containing: now, calendar: calendar)
        return plan.weeklyPlan.compactMap { day in
            guard day.workoutType != .rest else { return nil }
            guard day.sessionStatus == .planned else { return nil }
            guard let fireDate = dateForDay(day.dayOfWeek, weekStart: weekStart, hour: hour, minute: minute, calendar: calendar) else {
                return nil
            }
            guard fireDate > now else { return nil }

            return PlannedNotification(
                id: "bobby.today.\(WeekdayKey.normalized(day.dayOfWeek))",
                fireDate: fireDate,
                title: "Oggi con Bobby",
                body: "\(day.workoutType.rawValue) · \(formatted(day.distance)) km"
            )
        }
    }

    static func startOfWeek(containing date: Date, calendar: Calendar = .current) -> Date {
        var cal = calendar
        cal.firstWeekday = 2
        let weekday = cal.component(.weekday, from: date)
        let daysFromMonday = (weekday + 5) % 7
        let start = cal.date(byAdding: .day, value: -daysFromMonday, to: cal.startOfDay(for: date))
        return start ?? cal.startOfDay(for: date)
    }

    static func dateForDay(
        _ dayOfWeek: String,
        weekStart: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar = .current
    ) -> Date? {
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
            if WeekdayKey.matches(dayOfWeek, date: date, calendar: calendar) {
                return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)
            }
        }
        return nil
    }

    private static func formatted(_ km: Double) -> String {
        String(format: "%g", (km * 10).rounded() / 10)
    }
}

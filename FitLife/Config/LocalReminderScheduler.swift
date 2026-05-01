import Foundation
import SwiftData
import UserNotifications

enum LocalReminderScheduler {
    static let waterPrefix = "water-"
    static let mealReminderPrefix = "meal-reminder-"
    static let workoutReminderPrefix = "workout-reminder-"
    static let unfinishedWorkoutReminderPrefix = "unfinished-workout-reminder-"
    static let checkInReminderPrefix = "checkin-reminder-"

    static let mealRemindersEnabledKey = "notifications.mealReminders.enabled"

    @MainActor
    static func rescheduleMealRemindersIfEnabled(
        modelContext: ModelContext,
        ownerId: String,
        gender: Gender
    ) {
        guard UserDefaults.standard.bool(forKey: mealRemindersEnabledKey) else { return }
        rescheduleMealReminders(modelContext: modelContext, ownerId: ownerId, gender: gender)
    }

    @MainActor
    static func rescheduleMealReminders(
        modelContext: ModelContext,
        ownerId: String,
        gender: Gender
    ) {
        let loggedMeals = loggedMealsForToday(modelContext: modelContext, ownerId: ownerId, gender: gender)

        cancelNotifications(prefix: mealReminderPrefix) {
            for reminder in mealReminders {
                let date = nextReminderDate(
                    hour: reminder.hour,
                    minute: reminder.minute,
                    alreadyLoggedToday: loggedMeals.contains(reminder.mealType)
                )
                scheduleOneTimeReminder(
                    id: "\(mealReminderPrefix)\(reminder.id)",
                    date: date,
                    title: AppLocalizer.string(reminder.titleKey),
                    body: AppLocalizer.string(reminder.bodyKey)
                )
            }
        }
    }

    static func cancelNotifications(prefix: String, completion: (() -> Void)? = nil) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            center.removeDeliveredNotifications(withIdentifiers: ids)
            DispatchQueue.main.async { completion?() }
        }
    }

    private struct MealReminder {
        let id: String
        let mealType: MealType
        let hour: Int
        let minute: Int
        let titleKey: String
        let bodyKey: String
    }

    private static let mealReminders: [MealReminder] = [
        MealReminder(
            id: "breakfast",
            mealType: .breakfast,
            hour: 9,
            minute: 30,
            titleKey: "notifications.meal.breakfast.title",
            bodyKey: "notifications.meal.breakfast.body"
        ),
        MealReminder(
            id: "lunch",
            mealType: .lunch,
            hour: 14,
            minute: 0,
            titleKey: "notifications.meal.lunch.title",
            bodyKey: "notifications.meal.lunch.body"
        ),
        MealReminder(
            id: "dinner",
            mealType: .dinner,
            hour: 20,
            minute: 0,
            titleKey: "notifications.meal.dinner.title",
            bodyKey: "notifications.meal.dinner.body"
        )
    ]

    @MainActor
    private static func loggedMealsForToday(
        modelContext: ModelContext,
        ownerId: String,
        gender: Gender
    ) -> Set<MealType> {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: .now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        let predicate = #Predicate<FoodEntry> {
            $0.date >= dayStart &&
            $0.date < dayEnd &&
            $0.ownerId == ownerId
        }

        let descriptor = FetchDescriptor<FoodEntry>(predicate: predicate)
        let entries = (try? modelContext.fetch(descriptor)) ?? []

        return Set(
            entries
                .filter { $0.gender == gender }
                .compactMap { MealType(rawValue: $0.mealType) }
                .filter { $0 != .snacks }
        )
    }

    private static func nextReminderDate(hour: Int, minute: Int, alreadyLoggedToday: Bool) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let todayReminder = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? now

        if alreadyLoggedToday || todayReminder <= now {
            return calendar.date(byAdding: .day, value: 1, to: todayReminder) ?? todayReminder
        }

        return todayReminder
    }

    private static func scheduleOneTimeReminder(id: String, date: Date, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

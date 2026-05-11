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
    static let workoutReminderEnabledKey = "notifications.workoutReminder.enabled"
    static let unfinishedWorkoutReminderEnabledKey = "notifications.unfinishedWorkoutReminder.enabled"

    private static let reminderRollingDays = 7

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
    static func rescheduleWorkoutRemindersIfEnabled(
        modelContext: ModelContext,
        ownerId: String,
        gender: Gender
    ) {
        if UserDefaults.standard.bool(forKey: workoutReminderEnabledKey) {
            rescheduleWorkoutReminder(modelContext: modelContext, ownerId: ownerId, gender: gender)
        }

        if UserDefaults.standard.bool(forKey: unfinishedWorkoutReminderEnabledKey) {
            rescheduleUnfinishedWorkoutReminder(modelContext: modelContext, ownerId: ownerId, gender: gender)
        }
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
                for timeSlot in reminder.timeSlots {
                    let dates = reminderDates(
                        hour: timeSlot.hour,
                        minute: timeSlot.minute,
                        alreadyLoggedToday: loggedMeals.contains(reminder.mealType)
                    )

                    for date in dates {
                        scheduleOneTimeReminder(
                            id: "\(mealReminderPrefix)\(reminder.id)-\(timeSlot.id)-\(notificationDateId(date))",
                            date: date,
                            title: AppLocalizer.string(reminder.titleKey),
                            body: AppLocalizer.string(reminder.bodyKey)
                        )
                    }
                }
            }
        }
    }

    @MainActor
    static func rescheduleWorkoutReminder(
        modelContext: ModelContext,
        ownerId: String,
        gender: Gender
    ) {
        let completedToday = hasCompletedWorkoutToday(modelContext: modelContext, ownerId: ownerId, gender: gender)

        cancelNotifications(prefix: workoutReminderPrefix) {
            let dates = reminderDates(hour: 18, minute: 30, skipToday: completedToday)
            for date in dates {
                scheduleOneTimeReminder(
                    id: "\(workoutReminderPrefix)daily-\(notificationDateId(date))",
                    date: date,
                    title: AppLocalizer.string("notifications.workout.title"),
                    body: AppLocalizer.string("notifications.workout.body")
                )
            }
        }
    }

    @MainActor
    static func rescheduleUnfinishedWorkoutReminder(
        modelContext: ModelContext,
        ownerId: String,
        gender: Gender
    ) {
        let hasUnfinishedWorkout = hasUnfinishedWorkout(modelContext: modelContext, ownerId: ownerId, gender: gender)

        cancelNotifications(prefix: unfinishedWorkoutReminderPrefix) {
            guard hasUnfinishedWorkout else { return }

            let dates = reminderDates(hour: 21, minute: 30, skipToday: false)
            for date in dates {
                scheduleOneTimeReminder(
                    id: "\(unfinishedWorkoutReminderPrefix)evening-\(notificationDateId(date))",
                    date: date,
                    title: AppLocalizer.string("notifications.unfinished_workout.title"),
                    body: AppLocalizer.string("notifications.unfinished_workout.body")
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
        struct TimeSlot {
            let id: String
            let hour: Int
            let minute: Int
        }

        let id: String
        let mealType: MealType
        let timeSlots: [TimeSlot]
        let titleKey: String
        let bodyKey: String
    }

    private static let mealReminders: [MealReminder] = [
        MealReminder(
            id: "breakfast",
            mealType: .breakfast,
            timeSlots: [
                MealReminder.TimeSlot(id: "main", hour: 9, minute: 30),
                MealReminder.TimeSlot(id: "followup", hour: 10, minute: 30)
            ],
            titleKey: "notifications.meal.breakfast.title",
            bodyKey: "notifications.meal.breakfast.body"
        ),
        MealReminder(
            id: "lunch",
            mealType: .lunch,
            timeSlots: [
                MealReminder.TimeSlot(id: "main", hour: 14, minute: 0),
                MealReminder.TimeSlot(id: "followup-1", hour: 15, minute: 0),
                MealReminder.TimeSlot(id: "followup-2", hour: 16, minute: 0)
            ],
            titleKey: "notifications.meal.lunch.title",
            bodyKey: "notifications.meal.lunch.body"
        ),
        MealReminder(
            id: "dinner",
            mealType: .dinner,
            timeSlots: [
                MealReminder.TimeSlot(id: "main", hour: 20, minute: 0),
                MealReminder.TimeSlot(id: "followup", hour: 21, minute: 0)
            ],
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

    private static func reminderDates(hour: Int, minute: Int, alreadyLoggedToday: Bool) -> [Date] {
        reminderDates(hour: hour, minute: minute, skipToday: alreadyLoggedToday)
    }

    private static func reminderDates(hour: Int, minute: Int, skipToday: Bool) -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        return (0..<reminderRollingDays).compactMap { dayOffset in
            if dayOffset == 0, skipToday {
                return nil
            }

            guard
                let day = calendar.date(byAdding: .day, value: dayOffset, to: todayStart),
                let reminderDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                reminderDate > now
            else {
                return nil
            }

            return reminderDate
        }
    }

    @MainActor
    private static func hasCompletedWorkoutToday(
        modelContext: ModelContext,
        ownerId: String,
        gender: Gender
    ) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: .now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }

        return workouts(modelContext: modelContext, ownerId: ownerId, gender: gender).contains { workout in
            guard let endedAt = workout.endedAt else { return false }
            return endedAt >= dayStart && endedAt < dayEnd
        }
    }

    @MainActor
    private static func hasUnfinishedWorkout(
        modelContext: ModelContext,
        ownerId: String,
        gender: Gender
    ) -> Bool {
        workouts(modelContext: modelContext, ownerId: ownerId, gender: gender)
            .contains { $0.endedAt == nil }
    }

    @MainActor
    private static func workouts(
        modelContext: ModelContext,
        ownerId: String,
        gender: Gender
    ) -> [WorkoutSession] {
        let predicate = #Predicate<WorkoutSession> {
            $0.ownerId == ownerId
        }

        let descriptor = FetchDescriptor<WorkoutSession>(predicate: predicate)
        let workouts = (try? modelContext.fetch(descriptor)) ?? []
        return workouts.filter { $0.gender == gender }
    }

    private static func scheduleOneTimeReminder(id: String, date: Date, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            #if DEBUG
            if let error {
                print("Failed to schedule local notification \(id):", error.localizedDescription)
            }
            #endif
        }
    }

    private static func notificationDateId(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter.string(from: date)
    }
}

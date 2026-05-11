import SwiftUI
import SwiftData
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionStore: AppSessionStore
    @AppStorage(Gender.appStorageKey) private var activeGenderRaw = Gender.male.rawValue

    @AppStorage(LocalReminderScheduler.mealRemindersEnabledKey) private var mealRemindersEnabled = false
    @AppStorage(LocalReminderScheduler.workoutReminderEnabledKey) private var workoutReminderEnabled = false
    @AppStorage(LocalReminderScheduler.unfinishedWorkoutReminderEnabledKey) private var unfinishedWorkoutReminderEnabled = false
    @AppStorage("notifications.weeklyCheckInReminder.enabled") private var weeklyCheckInReminderEnabled = false

    @State private var isNotificationEnabled = false
    @State private var selectedStartTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
    @State private var selectedEndTime   = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: .now)!
    @State private var selectedIntervalSec: Int = 1800 // 30 минут
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showInvalidRangeAlert = false

    private var selectedInterval: TimeInterval { TimeInterval(selectedIntervalSec) }

    let intervalOptionsSec: [Int] = [1800, 3600, 5400, 7200, 9000, 10800]

    private var intervalLabels: [Int: String] {
        [
            1800: AppLocalizer.string("notifications.interval.30m"),
            3600: AppLocalizer.string("notifications.interval.1h"),
            5400: AppLocalizer.string("notifications.interval.1_5h"),
            7200: AppLocalizer.string("notifications.interval.2h"),
            9000: AppLocalizer.string("notifications.interval.2_5h"),
            10800: AppLocalizer.string("notifications.interval.3h")
        ]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(AppLocalizer.string("notifications.water.enable"), isOn: $isNotificationEnabled)
                        .onChange(of: isNotificationEnabled) { _, isEnabled in
                            if isEnabled {
                                requestPermissionAndSchedule()
                            } else {
                                cancelWaterNotifications()
                            }
                        }

                    if authorizationStatus == .denied {
                        Text(AppLocalizer.string("notifications.denied"))
                            .foregroundStyle(.red)
                        Button(AppLocalizer.string("notifications.open_settings")) { openSystemSettings() }
                    }
                }

                if isNotificationEnabled {
                    Section(AppLocalizer.string("notifications.schedule")) {
                        DatePicker(AppLocalizer.string("notifications.start"), selection: $selectedStartTime, displayedComponents: .hourAndMinute)
                        DatePicker(AppLocalizer.string("notifications.end"), selection: $selectedEndTime, displayedComponents: .hourAndMinute)
                        Picker(AppLocalizer.string("notifications.interval"), selection: $selectedIntervalSec) {
                            ForEach(intervalOptionsSec, id: \.self) { v in
                                Text(intervalLabels[v] ?? "\(v/60) мин").tag(v)
                            }
                        }
                        .pickerStyle(.menu)

                        Text(nextTimesPreview())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section(AppLocalizer.string("notifications.actions")) {
                        Button(AppLocalizer.string("notifications.update")) { reschedule() }
                        Button(AppLocalizer.string("notifications.disable_all"), role: .destructive) {
                            disableAllReminders()
                        }
                    }
                }

                Section(AppLocalizer.string("notifications.smart.title")) {
                    Toggle(AppLocalizer.string("notifications.meal.enable"), isOn: $mealRemindersEnabled)
                        .onChange(of: mealRemindersEnabled) { _, isEnabled in
                            handleReminderToggle(isEnabled: isEnabled, prefix: LocalReminderScheduler.mealReminderPrefix) {
                                scheduleMealReminders()
                            }
                        }

                    Toggle(AppLocalizer.string("notifications.workout.enable"), isOn: $workoutReminderEnabled)
                        .onChange(of: workoutReminderEnabled) { _, isEnabled in
                            handleReminderToggle(isEnabled: isEnabled, prefix: LocalReminderScheduler.workoutReminderPrefix) {
                                scheduleWorkoutReminders()
                            }
                        }

                    Toggle(AppLocalizer.string("notifications.unfinished_workout.enable"), isOn: $unfinishedWorkoutReminderEnabled)
                        .onChange(of: unfinishedWorkoutReminderEnabled) { _, isEnabled in
                            handleReminderToggle(isEnabled: isEnabled, prefix: LocalReminderScheduler.unfinishedWorkoutReminderPrefix) {
                                scheduleUnfinishedWorkoutReminders()
                            }
                        }

                    Toggle(AppLocalizer.string("notifications.checkin.enable"), isOn: $weeklyCheckInReminderEnabled)
                        .onChange(of: weeklyCheckInReminderEnabled) { _, isEnabled in
                            handleReminderToggle(isEnabled: isEnabled, prefix: LocalReminderScheduler.checkInReminderPrefix) {
                                scheduleWeeklyReminder(
                                    id: "\(LocalReminderScheduler.checkInReminderPrefix)weekly",
                                    weekday: 2,
                                    hour: 10,
                                    minute: 0,
                                    title: AppLocalizer.string("notifications.checkin.title"),
                                    body: AppLocalizer.string("notifications.checkin.body")
                                )
                            }
                        }

                    Text(AppLocalizer.string("notifications.smart.footer"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(AppLocalizer.string("notifications.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppLocalizer.string("common.close")) { dismiss() }
                }
            }
            .tint(.blue)
            .onAppear {
                refreshAuthorization()
                if mealRemindersEnabled {
                    scheduleMealReminders()
                }
                if workoutReminderEnabled {
                    scheduleWorkoutReminders()
                }
                if unfinishedWorkoutReminderEnabled {
                    scheduleUnfinishedWorkoutReminders()
                }
                UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
                    let anyWater = reqs.contains { $0.identifier.hasPrefix(LocalReminderScheduler.waterPrefix) }
                    DispatchQueue.main.async { self.isNotificationEnabled = anyWater }
                }
            }
            .onChange(of: selectedStartTime) { _, _ in
                if isNotificationEnabled { reschedule() }
            }
            .onChange(of: selectedEndTime) { _, _ in
                if isNotificationEnabled { reschedule() }
            }
            .onChange(of: selectedIntervalSec) { _, _ in
                if isNotificationEnabled { reschedule() }
            }
            .alert(AppLocalizer.string("notifications.invalid_range"), isPresented: $showInvalidRangeAlert) { Button(AppLocalizer.string("common.ok"), role: .cancel) {} }
        }
    }

    // MARK: - Permission
    private func requestPermissionAndSchedule() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.authorizationStatus = granted ? .authorized : .denied
                if granted { self.reschedule() } else { self.isNotificationEnabled = false }
            }
        }
    }

    private func refreshAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { st in
            DispatchQueue.main.async { self.authorizationStatus = st.authorizationStatus }
        }
    }

    // MARK: - Scheduling
    private func reschedule() {
        guard selectedStartTime < selectedEndTime else {
            showInvalidRangeAlert = true
            return
        }
        cancelWaterNotifications {
            self.scheduleNotifications(from: selectedStartTime, to: selectedEndTime, interval: selectedInterval)
        }
    }

    private func scheduleNotifications(from start: Date, to end: Date, interval: TimeInterval) {
        let center = UNUserNotificationCenter.current()
        let cal = Calendar.current
        var t = start

        while t <= end {
            let comps = cal.dateComponents([.hour, .minute], from: t)
            let id = makeId(comps)

            let content = UNMutableNotificationContent()
            content.title = AppLocalizer.string("notifications.reminder_title")
            content.body = AppLocalizer.string("notifications.reminder_body")
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(request)

            guard let next = cal.date(byAdding: .second, value: selectedIntervalSec, to: t) else { break }
            t = next
        }
    }

    private func handleReminderToggle(isEnabled: Bool, prefix: String, schedule: @escaping () -> Void) {
        if isEnabled {
            requestPermission {
                LocalReminderScheduler.cancelNotifications(prefix: prefix, completion: schedule)
            }
        } else {
            LocalReminderScheduler.cancelNotifications(prefix: prefix)
        }
    }

    private func requestPermission(onGranted: @escaping () -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.authorizationStatus = granted ? .authorized : .denied
                if granted {
                    onGranted()
                } else {
                    self.mealRemindersEnabled = false
                    self.workoutReminderEnabled = false
                    self.unfinishedWorkoutReminderEnabled = false
                    self.weeklyCheckInReminderEnabled = false
                }
            }
        }
    }

    private func scheduleMealReminders() {
        LocalReminderScheduler.rescheduleMealReminders(
            modelContext: modelContext,
            ownerId: sessionStore.firebaseUser?.uid ?? "",
            gender: Gender(rawValue: activeGenderRaw) ?? .male
        )
    }

    private func scheduleWorkoutReminders() {
        LocalReminderScheduler.rescheduleWorkoutReminder(
            modelContext: modelContext,
            ownerId: sessionStore.firebaseUser?.uid ?? "",
            gender: Gender(rawValue: activeGenderRaw) ?? .male
        )
    }

    private func scheduleUnfinishedWorkoutReminders() {
        LocalReminderScheduler.rescheduleUnfinishedWorkoutReminder(
            modelContext: modelContext,
            ownerId: sessionStore.firebaseUser?.uid ?? "",
            gender: Gender(rawValue: activeGenderRaw) ?? .male
        )
    }

    private func scheduleDailyReminder(id: String, hour: Int, minute: Int, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: hour, minute: minute),
            repeats: true
        )
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func scheduleWeeklyReminder(id: String, weekday: Int, hour: Int, minute: Int, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: hour, minute: minute, weekday: weekday),
            repeats: true
        )
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func makeId(_ comps: DateComponents) -> String {
        let h = comps.hour ?? 0, m = comps.minute ?? 0
        return "\(LocalReminderScheduler.waterPrefix)\(String(format: "%02d-%02d", h, m))"
    }

    private func cancelWaterNotifications(_ completion: (() -> Void)? = nil) {
        LocalReminderScheduler.cancelNotifications(prefix: LocalReminderScheduler.waterPrefix, completion: completion)
    }

    private func disableAllReminders() {
        isNotificationEnabled = false
        mealRemindersEnabled = false
        workoutReminderEnabled = false
        unfinishedWorkoutReminderEnabled = false
        weeklyCheckInReminderEnabled = false

        let prefixes = [
            LocalReminderScheduler.waterPrefix,
            LocalReminderScheduler.mealReminderPrefix,
            LocalReminderScheduler.workoutReminderPrefix,
            LocalReminderScheduler.unfinishedWorkoutReminderPrefix,
            LocalReminderScheduler.checkInReminderPrefix
        ]

        UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
            let ids = reqs
                .map(\.identifier)
                .filter { id in prefixes.contains { id.hasPrefix($0) } }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // Превью ближайших времен (первые 3)
    private func nextTimesPreview() -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        var t = selectedStartTime
        var arr: [String] = []
        var count = 0
        while t <= selectedEndTime && count < 3 {
            arr.append(f.string(from: t))
            t = Calendar.current.date(byAdding: .second, value: selectedIntervalSec, to: t) ?? t
            count += 1
        }
        return arr.isEmpty ? "" : AppLocalizer.string("notifications.today") + ": " + arr.joined(separator: " • ")
    }
}

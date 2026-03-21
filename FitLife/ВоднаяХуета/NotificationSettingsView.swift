import SwiftUI
import UserNotifications

private let waterPrefix = "water-" // префикс для наших уведомлений

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss

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
                    Toggle("Включить уведомления", isOn: $isNotificationEnabled)
                        .onChange(of: isNotificationEnabled) { on in
                            if on {
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
                            isNotificationEnabled = false
                            cancelWaterNotifications()
                        }
                    }
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
                UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
                    let anyWater = reqs.contains { $0.identifier.hasPrefix(waterPrefix) }
                    DispatchQueue.main.async { self.isNotificationEnabled = anyWater }
                }
            }
            // авто-перепланирование при изменениях
            .onChange(of: selectedStartTime) { if isNotificationEnabled { reschedule() } }
            .onChange(of: selectedEndTime)   { if isNotificationEnabled { reschedule() } }
            .onChange(of: selectedIntervalSec) { if isNotificationEnabled { reschedule() } }
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

    private func makeId(_ comps: DateComponents) -> String {
        let h = comps.hour ?? 0, m = comps.minute ?? 0
        return "\(waterPrefix)\(String(format: "%02d-%02d", h, m))"
    }

    private func cancelWaterNotifications(_ completion: (() -> Void)? = nil) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            let ids = reqs.map(\.identifier).filter { $0.hasPrefix(waterPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            center.removeDeliveredNotifications(withIdentifiers: ids)
            DispatchQueue.main.async { completion?() }
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

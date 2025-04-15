
import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss // Среда для закрытия представления
    @State private var isNotificationEnabled = false
    @State private var selectedStartTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date() // Начало 9:00
    @State private var selectedEndTime: Date = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date() // Конец 18:00
    @State private var selectedInterval: TimeInterval = 1800 // 30 минут
    @State private var showStartTimePicker = false
    @State private var showEndTimePicker = false
    @State private var showIntervalPicker = false

    let intervalOptions: [TimeInterval] = [1800, 3600, 5400, 7200, 9000, 10800] // От 30 минут до 3 часов
    let intervalLabels: [TimeInterval: String] = [
        1800: "30 минут",
        3600: "Час",
        5400: "Полтора часа",
        7200: "Два часа",
        9000: "Два с половиной часа",
        10800: "Три часа"
    ]

    var body: some View {
        VStack(spacing: 20) {
            // Верхняя кнопка закрытия
            HStack {
                Spacer()
                Button(action: {
                    dismiss() // Закрыть представление
                }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            Text("Уведомления")
                .font(.headline)
                .padding(.top)

            Toggle(isOn: $isNotificationEnabled) {
                Text("Включить уведомления")
            }
            .padding(.horizontal)
            .onChange(of: isNotificationEnabled) {
                if isNotificationEnabled {
                    requestNotificationPermission()
                }
            }

            if isNotificationEnabled {
                VStack(alignment: .leading, spacing: 20) {
                    // Время начала
                    HStack {
                        Text("Начало:")
                        Spacer()
                        Button(action: {
                            showStartTimePicker = true
                        }) {
                            Text("\(formattedTime(selectedStartTime))")
                                .foregroundColor(.blue)
                        }
                    }
                    .sheet(isPresented: $showStartTimePicker) {
                        TimePickerView(selectedTime: $selectedStartTime)
                    }

                    // Время окончания
                    HStack {
                        Text("Конец:")
                        Spacer()
                        Button(action: {
                            showEndTimePicker = true
                        }) {
                            Text("\(formattedTime(selectedEndTime))")
                                .foregroundColor(.blue)
                        }
                    }
                    .sheet(isPresented: $showEndTimePicker) {
                        TimePickerView(selectedTime: $selectedEndTime)
                    }

                    // Интервал
                    HStack {
                        Text("Интервал:")
                        Spacer()
                        Button(action: {
                            showIntervalPicker = true
                        }) {
                            Text(intervalLabels[selectedInterval] ?? "Выберите интервал")
                                .foregroundColor(.blue)
                        }
                    }
                    .sheet(isPresented: $showIntervalPicker) {
                        IntervalPickerView(selectedInterval: $selectedInterval, intervalOptions: intervalOptions, intervalLabels: intervalLabels)
                    }

                    // Кнопка "Запланировать уведомления"
                    Button(action: {
                        scheduleNotifications(from: selectedStartTime, to: selectedEndTime, interval: selectedInterval)
                    }) {
                        Text("Запланировать уведомления")
                            .font(.title3)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.top)
                }
                .padding(.horizontal)
            }
            Spacer()
        }
        .padding()
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Ошибка запроса разрешения: \(error)")
            } else if granted {
                print("Разрешение получено")
            } else {
                print("Разрешение отклонено")
            }
        }
    }

    private func scheduleNotifications(from startDate: Date, to endDate: Date, interval: TimeInterval) {
        let calendar = Calendar.current
        var currentDate = startDate

        while currentDate <= endDate {
            // Создание контента уведомления
            let content = UNMutableNotificationContent()
            content.title = "Напоминание"
            content.body = "Пора выпить воды!"
            content.sound = .default

            // Расчёт времени следующего уведомления
            let triggerDateComponents = calendar.dateComponents([.hour, .minute], from: currentDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)

            // Создание и добавление запроса
            let request = UNNotificationRequest(identifier: "\(UUID().uuidString)", content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Ошибка добавления уведомления: \(error)")
                } else {
                    print("Уведомление запланировано на \(formattedTime(currentDate))")
                }
            }

            // Увеличиваем текущее время на указанный интервал
            guard let nextDate = calendar.date(byAdding: .second, value: Int(interval), to: currentDate) else {
                break
            }
            currentDate = nextDate
        }
    }
}

struct TimePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTime: Date

    var body: some View {
        VStack {
            DatePicker("Выберите время", selection: $selectedTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(WheelDatePickerStyle())
                .padding()

            HStack {
                Button("Отмена") {
                    dismiss()
                }
                Spacer()
                Button("Ок") {
                    dismiss()
                }
            }
            .padding()
        }
    }
}
struct IntervalPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedInterval: TimeInterval
    let intervalOptions: [TimeInterval]
    let intervalLabels: [TimeInterval: String]

    var body: some View {
        VStack {
            Picker("Выберите интервал", selection: $selectedInterval) {
                ForEach(intervalOptions, id: \.self) { option in
                    Text(intervalLabels[option] ?? "").tag(option)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .padding()

            HStack {
                Button("Отмена") {
                    dismiss()
                }
                Spacer()
                Button("Ок") {
                    dismiss()
                }
            }
            .padding()
        }
    }
}


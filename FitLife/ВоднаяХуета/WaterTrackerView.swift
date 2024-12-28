//
//  WaterTrackerView.swift
//  FitLife
import SwiftUI
import SwiftData

// Представление для трекера воды
struct WaterTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showNotificationSettings = false
    @Environment(\.dismiss) private var dismiss
    @Bindable var userData: UserData // Данные пользователя, с привязкой

    @State private var selectedTemperature: WaterTemperature = .warm // Выбранная температура воды
    @State private var waterIntake: Double = 0.0 // Текущее количество выпитой воды

    var body: some View {
        VStack(spacing: 20) {
            // Заголовок
            Text("Трекер воды")
                .font(.headline)
                .padding(.top, 20)

            // Пикер температуры воды
            temperaturePicker
     //       Spacer()
            // Отображение прогресса по воде
            waterProgressView

            // Кнопки для управления
            actionButtons

            // Кнопка подтверждения
            confirmButton
        }
        .padding()
        .onAppear {
            recalculateDailyGoal() // Пересчёт цели при загрузке экрана
            loadWaterIntake()
        }
        .onChange(of: userData.weight) {
            recalculateDailyGoal() // Пересчёт цели при изменении веса пользователя
        }
    }

    // Пикер температуры воды
    private var temperaturePicker: some View {
        Picker("Температура воды", selection: $selectedTemperature) {
            ForEach(WaterTemperature.allCases, id: \.self) { temp in
                Text(temp.rawValue).tag(temp)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
        .onChange(of: selectedTemperature) {
            recalculateDailyGoal() // Пересчёт цели при изменении температуры
        }
    }
    // Отображение прогресса по воде
    private var waterProgressView: some View {
        VStack() { // Добавлен spacing для увеличения отступа
            // Процент воды
            Text("\(Int(waterPercentage))%")
                .font(.system(size: 30, weight: .medium)) // Увеличен размер шрифта и добавлен жирный стиль
                .foregroundColor(.blue)
                .padding(.bottom, 30) // Отступ снизу для текста

        //    Spacer() // Добавлен дополнительный Spacer для увеличения разрыва

            // Количество выпитой воды
            Text("\(waterIntake, specifier: "%.2f") л из \(dailyGoal, specifier: "%.2f") л")
                .font(.title3)
                .foregroundColor(.gray)
        }
    }

    // Кнопки для добавления воды и напоминания
    private var actionButtons: some View {
        HStack {
            Button(action: { addWater(amount: 0.25) }) {
                VStack {
                    Image(systemName: "plus")
                    Text("Добавить воду")
                }.font(.title3)
            }.foregroundStyle(.black)

            Spacer()

            Button(action: { showNotificationSettings = true }) {
                VStack {
                    Image(systemName: "bell")
                    Text("Напомнить")
                }.font(.title3)
            }.foregroundStyle(.black)
            .fullScreenCover(isPresented: $showNotificationSettings) {
                NotificationSettingsView()
            }
        }
        .padding()
    }

    // Кнопка подтверждения
    private var confirmButton: some View {
        Button(action: {
            dismiss() // Закрыть представление
        }) {
            Text("Ок")
                .font(.title3)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding(.horizontal)
    }

    // Расчёт дневной цели воды
    private var dailyGoal: Double {
        let multiplier: Double
        switch selectedTemperature {
        case .cold: multiplier = 30.0
        case .warm: multiplier = 35.0
        case .hot: multiplier = 40.0
        }
        return (userData.weight * multiplier) / 1000.0 // В литры
    }

    // Процент выпитой воды относительно цели
    private var waterPercentage: Double {
        guard dailyGoal > 0 else { return 0 }
        return min((waterIntake / dailyGoal) * 100, 100)
    }

    // Функция пересчёта цели воды
    private func recalculateDailyGoal() {
        print("Новая цель воды: \(dailyGoal) л")
    }

    // Добавление воды
    private func addWater(amount: Double) {
        waterIntake += amount
        saveWaterIntake()
    }
    // Сохранение данных в модель
    private func saveWaterIntake() {
        let today = Calendar.current.startOfDay(for: Date()) // Начало текущего дня
        if let existingEntry = try? modelContext.fetch(FetchDescriptor<WaterIntake>()).first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            existingEntry.intake = waterIntake // Обновление записи
        } else {
            let newEntry = WaterIntake(date: today, intake: waterIntake)
            modelContext.insert(newEntry)
        }
        try? modelContext.save()
    }
    // Загрузка данных
    private func loadWaterIntake() {
        let today = Calendar.current.startOfDay(for: Date())
        if let existingEntry = try? modelContext.fetch(FetchDescriptor<WaterIntake>()).first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            waterIntake = existingEntry.intake
        } else {
            waterIntake = 0.0 // Начальное значение
        }
    }
}

// Перечисление для температуры воды
enum WaterTemperature: String, CaseIterable {
    case cold = "Холодно"
    case warm = "Тепло"
    case hot = "Жарко"
}

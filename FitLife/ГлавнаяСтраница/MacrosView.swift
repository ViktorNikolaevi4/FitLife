
import SwiftUI
import SwiftData

enum WeightGoal: String, CaseIterable, Codable {
    case loseWeight = "Снизить вес"
    case currentWeight = "Текущий вес"
    case gainWeight = "Набрать вес"
}

struct MacrosView: View {
    @Bindable var userData: UserData

    // Привязка к выбранной дате (та же, что и в HeaderView)
    @Binding var selectedDate: Date

    @State private var callories: Int = 0
    @State private var selectedGoal: WeightGoal = .currentWeight
    @State private var dailyConsumedCalories: Int = 0

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 20) {
                VStack {
                    Text("Энергия:")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(userData.calories)")
                        .font(.title)
                        .fontWeight(.bold)
                }.foregroundStyle(.white)
                // Круговая диаграмма
                PieChartView(userData: userData)
            }
            .padding()
            HStack(spacing: 60) {
                VStack {
                    Text("Белки")
                    Text("\(userData.macros.proteins) г")
                }
                VStack {
                    Text("Жиры")
                    Text("\(userData.macros.fats) г")
                }
                VStack {
                    Text("Углеводы")
                    Text("\(userData.macros.carbs) г")
                }
            }
            .font(.headline)
            // -- Добавляем наш новый блок: "Сегодня съедено" и "Осталось" --
               let remainingCalories = userData.calories - dailyConsumedCalories
            VStack(spacing: 8) {
                Text("Сегодня уже ввели: \(dailyConsumedCalories) ккал")
                    .font(.subheadline)
                    .foregroundStyle(.white)

                Text("Осталось: \(remainingCalories > 0 ? remainingCalories : 0) ккал")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
//            VStack {
//                Text("Осталось съесть за день")
//                Text("калорий: \(userData.calories)")
//                HStack(spacing: 60) {
//                    VStack {
//                        Text("Белки")
//                        Text("\(userData.macros.proteins) г")
//                    }
//                    VStack {
//                        Text("Жиры")
//                        Text("\(userData.macros.fats) г")
//                    }
//                    VStack {
//                        Text("Углеводы")
//                        Text("\(userData.macros.carbs) г")
//                    }
//                }
//            }
            // Пикер для выбора цели
            VStack(spacing: 10) {
                Text("Цель")
                    .font(.headline)

                Picker("Цель", selection: $userData.goal) {
                    ForEach(WeightGoal.allCases, id: \.self) { goal in
                        Text(goal.rawValue)
                    }
                }
                .pickerStyle(SegmentedPickerStyle()) // Используем стиль сегментированного пикера
                .padding()
                .onChange(of: userData.goal) {
                    // При смене цели пересчитываем и сохраняем
                    recalcAndSave()
                }
            }
        }
        .onAppear {
            loadDailyConsumedCalories(for: Date(), gender: userData.gender)
        }
        .onChange(of: selectedDate) {
            loadDailyConsumedCalories(for: selectedDate, gender: userData.gender)
        }
    }
    @Environment(\.modelContext) private var modelContext

    private func recalcAndSave() {
        let newCalories = MacrosCalculator.calculateCaloriesMifflin(
            gender: userData.gender,
            weight: userData.weight,
            height: userData.height,
            age: userData.age,
            activityLevel: userData.activityLevel,
            goal: userData.goal
        )
        let newMacros = MacrosCalculator.calculateMacros(
            calories: newCalories,
            goal: userData.goal
        )
        userData.calories = newCalories
        userData.macros = newMacros

        try? modelContext.save()
    }
    private func loadDailyConsumedCalories(for date: Date, gender: Gender) {
        let fetchDescriptor = FetchDescriptor<FoodEntry>()
        do {
            let entries = try modelContext.fetch(fetchDescriptor)
            let filtered = entries.filter {
                Calendar.current.isDate($0.date, inSameDayAs: date) &&
                $0.gender == gender
            }
            let total = filtered.reduce(0) { sum, entry in
                sum + entry.product.calories
            }
            dailyConsumedCalories = total
        } catch {
            print("Ошибка при загрузке FoodEntry: \(error)")
            dailyConsumedCalories = 0
        }
    }
}


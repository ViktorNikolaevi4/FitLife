
import SwiftUI
import SwiftData

enum WeightGoal: String, CaseIterable, Codable {
    case loseWeight = "Снизить вес"
    case currentWeight = "Текущий вес"
    case gainWeight = "Набрать вес"

    var displayName: String {
        switch self {
        case .loseWeight:
            return AppLocalizer.string("goal.lose")
        case .currentWeight:
            return AppLocalizer.string("goal.maintain")
        case .gainWeight:
            return AppLocalizer.string("goal.gain")
        }
    }
}

struct MacrosView: View {
    @Bindable var userData: UserData

    // Привязка к выбранной дате (та же, что и в HeaderView)
    @Binding var selectedDate: Date

    // Привязка к общей переменной «Сколько калорий уже съедено»
    @Binding var dailyConsumedCalories: Int

    // Функция для пересчёта, которую мы зовём когда надо
    let loadDailyConsumedCalories: (Date, Gender) -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var callories: Int = 0
    @State private var selectedGoal: WeightGoal = .currentWeight

    var body: some View {
        let remainingCalories = userData.calories - dailyConsumedCalories
        VStack(spacing: 5) {
            HStack(spacing: 20) {
                VStack {
                    Text(AppLocalizer.string("macros.energy"))
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("\(userData.calories)")
                        .font(.title3)
                        .fontWeight(.bold)
                    VStack {
                        Text(AppLocalizer.string("macros.remaining"))
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("\(remainingCalories > 0 ? remainingCalories : 0)")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
                .foregroundStyle(.white)
                // Круговая диаграмма
                PieChartView(userData: userData)
            }
            .padding()
            HStack(spacing: 60) {
                VStack {
                    Text(AppLocalizer.string("macro.protein"))
                    Text(AppLocalizer.format("unit.grams.value", userData.macros.proteins))
                }
                VStack {
                    Text(AppLocalizer.string("macro.fat"))
                    Text(AppLocalizer.format("unit.grams.value", userData.macros.fats))
                }
                VStack {
                    Text(AppLocalizer.string("macro.carbs"))
                    Text(AppLocalizer.format("unit.grams.value", userData.macros.carbs))
                }
            }
            .font(.headline)
            HStack {
                Text(AppLocalizer.string("macros.entered_today"))
                    .foregroundStyle(.primary)
                Text(AppLocalizer.format("unit.kcal.value", dailyConsumedCalories))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
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
                Text(AppLocalizer.string("goal.title"))
                    .font(.headline)

                Picker(AppLocalizer.string("goal.title"), selection: $userData.goal) {
                    ForEach(WeightGoal.allCases, id: \.self) { goal in
                        Text(goal.displayName)
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
            loadDailyConsumedCalories(Date(), userData.gender)
        }
        .onChange(of: selectedDate) {
            loadDailyConsumedCalories(selectedDate, userData.gender)
        }
    }
  //  @Environment(\.modelContext) private var modelContext

    private func recalcAndSave() {
        guard userData.nutritionGoalMode == .automatic else {
            try? modelContext.save()
            return
        }

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
}

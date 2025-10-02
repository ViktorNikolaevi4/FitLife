
import SwiftUI
import SwiftData

struct UserStatsView: View {
    @Bindable var userData: UserData
    @Environment(\.modelContext) private var modelContext
    

    // Состояния для управления отображением барабанов
    @State private var isWeightPickerVisible = false
    @State private var isHeightPickerVisible = false
    @State private var isAgePickerVisible = false

    var body: some View {
        ZStack {
            // Основной интерфейс
            VStack(spacing: 10) {
                HStack {
                    Image(userData.gender.imageName)
                        .resizable()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())

                    HStack(spacing: 20) {
                        Button {
                            togglePicker(&isWeightPickerVisible)
                        } label: {
                            VStack {
                                Text("ВЕС, КГ")
                                Text("\(Int(userData.weight))")
                            }
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        Button {
                            togglePicker(&isHeightPickerVisible)
                        } label: {
                            VStack {
                                Text("РОСТ, СМ")
                                Text("\(Int(userData.height))")
                            }
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        Button {
                            togglePicker(&isAgePickerVisible)
                        } label: {
                            VStack {
                                Text("ВОЗРАСТ")
                                Text("\(userData.age)")
                            }
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.headline)
                }
                .padding()

                ActivitySelectorView(userData: userData)
            }
            .zIndex(0) // Основной интерфейс на заднем плане

            // Отображение PickerView
            if isWeightPickerVisible {
                PickerView(title: "Выберите вес",
                           range: 30...200,
                           selectedValue: Binding(
                            get: { Int(userData.weight) },
                            set: { newValue in
                                // При реальном изменении веса сохраняем
                                updateUserData(weight: Double(newValue))
                            }
                        ),
                        isVisible: $isWeightPickerVisible
                    )
                    .zIndex(1) // PickerView отображается над
                    .frame(maxWidth: .infinity, maxHeight: 150)
            }

            if isHeightPickerVisible {
                PickerView(title: "Выберите рост",
                           range: 100...250,
                           selectedValue: Binding(
                            get: { Int(userData.height) },
                            set: { newValue in
                                updateUserData(height: Double(newValue))
                            }
                        ),
                        isVisible: $isHeightPickerVisible
                    )
                    .zIndex(1)
                    .frame(maxWidth: .infinity, maxHeight: 150)

            }

            // Отображение PickerView — возраст
            if isAgePickerVisible {
                PickerView(
                    title: "Выберите возраст",
                    range: 1...120,
                    selectedValue: Binding(
                        get: { userData.age },
                        set: { newValue in
                            updateUserData(age: newValue)
                        }
                    ),
                    isVisible: $isAgePickerVisible
                )
                    .zIndex(1)
                    .frame(maxWidth: .infinity, maxHeight: 150)
            }
        }
    }

    /// Обновляем данные только при реальном изменении
    private func updateUserData(weight: Double? = nil,
                                height: Double? = nil,
                                age: Int? = nil) {
        var dataChanged = false

        if let newWeight = weight, userData.weight != newWeight {
            userData.weight = newWeight
            dataChanged = true
        }
        if let newHeight = height, userData.height != newHeight {
            userData.height = newHeight
            dataChanged = true
        }
        if let newAge = age, userData.age != newAge {
            userData.age = newAge
            dataChanged = true
        }

        // Если что-то реально поменялось, пересчитаем и сохраним
        if dataChanged {
            // Пересчёт калорий и БЖУ
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

            // Сохраняем изменения в контексте
            try? modelContext.save()
        }
    }

    private func togglePicker(_ visibility: inout Bool) {
        isWeightPickerVisible = false
        isHeightPickerVisible = false
        isAgePickerVisible = false
        visibility = true // Включаем только нужный барабан
    }
}

struct PickerView: View {
    let title: String
    let range: ClosedRange<Int>
    @Binding var selectedValue: Int
    @Binding var isVisible: Bool

    var body: some View {
        ZStack {
            // Основной контент Picker
            VStack(spacing: 10) {
                // Заголовок барабана
                Text(title)
                    .font(.headline)
                    .padding(.top, 10)
                // Сам барабан
                Picker("", selection: $selectedValue) {
                    ForEach(range, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 150, height: 150) // Размер Picker
                .clipped() // Обрезка лишнего
                // Кнопка "Готово"
                Button("Готово") {
                    isVisible = false // Закрываем Picker
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding()
            .background(Color.white) // Непрозрачный фон для Picker
            .cornerRadius(15)
            .shadow(radius: 10) // Тень для эффекта объема
        }
    }
}


enum ActivityLevel: String, CaseIterable, Codable {
    case none = "Нет"
    case light = "1-3 раза"
    case moderate = "4-5 раза"
    case pro = "PRO"

    var message: String {
        switch self {
        case .none:
            return "Ваша суточная потребность при сидячем образе жизни"
        case .light:
            return "Ваша суточная потребность при тренировках 1-2 раза в неделю"
        case .moderate:
            return "Ваша суточная потребность при тренировках 3-5 раза в неделю"
        case .pro:
            return "Ваша суточная потребность при PRO тренировках"
        }
    }
}

struct ActivitySelectorView: View {
    @Bindable var userData: UserData
   // @State private var selectedActivity: ActivityLevel // Уровень активности по умолчанию
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack {
            Picker("Физическая активность", selection: $userData.activityLevel) {
                ForEach(ActivityLevel.allCases, id: \.self) { activity in
                    Text(activity.rawValue)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: userData.activityLevel) {
                // При смене активности пересчитаем данные
                recalcAndSave()
            }

            Text(userData.activityLevel.message) // Сообщение для текущего уровня активности
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.top, 5)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.white)
        }
    }
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
}

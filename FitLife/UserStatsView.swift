
import SwiftUI

// Модель пользователя
struct User: Identifiable {
    var id = UUID()
    var weight: Double
    var height: Double
    var age: Int
}

struct UserStatsView: View {
    @ObservedObject var userData: UserData

//    var selectedGender: Gender // Пол пользователя
//
//    // Состояния для выбранных значений
//    @State private var weight: Int = 0
//    @State private var height: Int = 0
//    @State private var age: Int = 0
    

    // Состояния для управления отображением барабанов
    @State private var isWeightPickerVisible = false
    @State private var isHeightPickerVisible = false
    @State private var isAgePickerVisible = false

    var body: some View {
        ZStack {
            // Основной интерфейс
            VStack(spacing: 10) {
                HStack {
                    Image(userData.selectedGender.imageName)
                        .resizable()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())

                    HStack(spacing: 20) {
                        VStack {
                            Text("ВЕС, КГ")
                            Text("\(Int(userData.weight))")
                                .foregroundColor(.blue)
                                .onTapGesture {
                                    togglePicker(&isWeightPickerVisible)
                                }
                        }
                        VStack {
                            Text("РОСТ, СМ")
                            Text("\(Int(userData.height))")
                                .foregroundColor(.blue)
                                .onTapGesture {
                                    togglePicker(&isHeightPickerVisible)
                                }
                        }
                        VStack {
                            Text("ВОЗРАСТ")
                            Text("\(userData.age)")
                                .foregroundColor(.blue)
                                .onTapGesture {
                                    togglePicker(&isAgePickerVisible)
                                }
                        }
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
                               set: { userData.weight = Double($0) } ),
                           isVisible: $isWeightPickerVisible)
                    .zIndex(1) // PickerView отображается над
            }

            if isHeightPickerVisible {
                PickerView(title: "Выберите рост",
                           range: 100...250,
                           selectedValue: Binding(
                               get: { Int(userData.height) },
                               set: { userData.height = Double($0) } ),
                           isVisible: $isHeightPickerVisible)
                    .zIndex(1)

            }

            if isAgePickerVisible {
                PickerView(title: "Выберите возраст",
                           range: 1...120,
                           selectedValue: $userData.age,
                           isVisible: $isAgePickerVisible)
                    .zIndex(1)
            }
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


enum ActivityLevel: String, CaseIterable {
    case none = "Нет"
    case light = "1-2 раза"
    case moderate = "3-5 раза"
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
    @ObservedObject var userData: UserData
   // @State private var selectedActivity: ActivityLevel // Уровень активности по умолчанию

    var body: some View {
        VStack {
            Picker("Физическая активность", selection: $userData.activityLevel) {
                ForEach(ActivityLevel.allCases, id: \.self) { activity in
                    Text(activity.rawValue)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            Text(userData.activityLevel.message) // Сообщение для текущего уровня активности
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
        }
    }
}

//
//#Preview {
//    Group {
//        UserStatsView(selectedGender: .male)
//        UserStatsView(selectedGender: .female)
//    }
//}

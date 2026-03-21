
import SwiftUI
import SwiftData

    struct MainView: View {
        @State private var selectedDate = Date()
        @Query private var userData: [UserData]
        @Environment(\.modelContext) private var modelContext
        @Environment(\.dismiss) private var dismiss

        var selectedGender: Gender // Получаем выбранный пол

        @State private var dailyConsumedCalories: Int = 0

        // Фильтрованные данные для выбранного пола
        var filteredUserData: UserData? {
            userData.first(where: { $0.gender == selectedGender }) // Ищем данные для текущего пола
        }

        var body: some View {
            ZStack {
                GradientView()
                    .ignoresSafeArea()
                VStack() {
                    if let userData = filteredUserData { // Проверяем, есть ли пользователь
                        // Заголовок с датой
                        HeaderView(selectedDate: $selectedDate)
                            .padding(.top, 5) // Учет безопасной зоны сверху

                        UserStatsView(userData: userData)
                        MacrosView(userData: userData,
                                   selectedDate: $selectedDate,
                                   dailyConsumedCalories: $dailyConsumedCalories,
                                   loadDailyConsumedCalories: loadDailyConsumedCalories

                        )
                        Spacer() // Выталкиваем оставшиеся элементы вниз
                        BottomNavigationView(selectedDate: $selectedDate,
                                             userData: userData,
                                             dailyConsumedCalories: $dailyConsumedCalories,
                                            loadDailyConsumedCalories: loadDailyConsumedCalories)

                    } else {
                        Text(AppLocalizer.string("data.not_found"))
                            .font(.headline)

                    }
                }
                .onAppear {
                    if userData.isEmpty {
                        createNewUser(for: selectedGender)
                    } else if filteredUserData == nil { // Если данных для выбранного пола нет
                        createNewUser(for: selectedGender)
                    }
                    // При первом появлении посчитаем калории на сегодняшнюю дату
                    loadDailyConsumedCalories(selectedDate, selectedGender)
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                 ToolbarItem(placement: .topBarLeading) {
                     Button {
                         dismiss()
                     } label: {
                         Image(systemName: "chevron.left")  // только стрелка, без текста
                             .font(.system(size: 17, weight: .semibold))
                     }
                     .tint(.white)                         // цвет стрелки (любая Tint)
                 }
             }

        }
        func loadDailyConsumedCalories(_ date: Date, _ gender: Gender) {
            let fetchDescriptor = FetchDescriptor<FoodEntry>()
            do {
                let entries = try modelContext.fetch(fetchDescriptor)
                let filtered = entries.filter {
                    Calendar.current.isDate($0.date, inSameDayAs: date) &&
                    $0.gender == gender
                }
                let total = filtered.reduce(0) { sum, entry in
                    sum + (entry.product?.calories ?? 0)
                }
                dailyConsumedCalories = total
            } catch {
                print("Ошибка при загрузке FoodEntry: \(error)")
                dailyConsumedCalories = 0
            }
        }
        // Функция для получения верхней безопасной зоны
        private func safeAreaTopInset() -> CGFloat {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return 0
            }
            return window.safeAreaInsets.top
        }

        private func createNewUser(for gender: Gender) {
            // Проверяем, существует ли уже пользователь с данным полом
            if userData.contains(where: { $0.gender == gender }) {
                return // Если пользователь с таким полом уже есть, выходим из функции
            }
            // Создаём нового пользователя
            let newUser = UserData(
                weight: 0,
                height: 0,
                age: 0,
                activityLevel: .none,
                goal: .currentWeight,
                gender: gender // Указываем пол
            )

            modelContext.insert(newUser) // Вставляем нового пользователя в контекст
            try? modelContext.save() // Сохраняем изменения
        }
    }

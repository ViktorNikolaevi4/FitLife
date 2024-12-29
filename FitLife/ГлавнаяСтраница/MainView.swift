//
//  MainView.swift
//  FitLife
//
//  Created by Виктор Корольков on 07.12.2024.
//

import SwiftUI
import SwiftData

    struct MainView: View {
        @State private var selectedDate = Date()
        @Query private var userData: [UserData]
        @Environment(\.modelContext) private var modelContext

        var selectedGender: Gender // Получаем выбранный пол

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
                     //   Spacer()
                        // Статистика пользователя
                        UserStatsView(userData: userData)
                        MacrosView(userData: userData)
                        Spacer() // Выталкиваем оставшиеся элементы вниз
                        BottomNavigationView(selectedDate: $selectedDate, userData: userData)

                    } else {
                        Text("Данные не найдены")
                            .font(.headline)
                            .onAppear {
                                createNewUser(for: selectedGender) // Создаем нового пользователя, если данных нет
                            }
                    }
                }
                .onAppear {
                    if userData.isEmpty {
                        createNewUser(for: selectedGender)
                    } else if filteredUserData == nil { // Если данных для выбранного пола нет
                        createNewUser(for: selectedGender)
                    }
                }
//
//                .ignoresSafeArea(edges: [.top, .bottom])
//                .background(GradientView())
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
            let newUser = UserData(
                weight: 0,
                height: 0,
                age: 0,
                activityLevel: .none,
                goal: .currentWeight,
          //      selectedGender: selectedGender,
                gender: gender // Указываем пол
            )
            modelContext.insert(newUser) // Вставляем нового пользователя в контекст
            try? modelContext.save() // Сохраняем изменения
        }
//        private func showRationPopup() {
//            let popup = RationPopupView(selectedDate: $selectedDate, selectedGender: selectedGender)
//            // Логика для показа popup (например, через .sheet)
//        }
    }

#Preview {
    Group {
        MainView(selectedGender: .male)
        MainView(selectedGender: .female)
    }
}
//
//            BottomNavigationView()

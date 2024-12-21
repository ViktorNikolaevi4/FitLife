//
//  MainView.swift
//  FitLife
//
//  Created by Виктор Корольков on 07.12.2024.
//

import SwiftUI
import SwiftData

    struct MainView: View {
        @Query private var userData: [UserData]
        @Environment(\.modelContext) private var modelContext

        var selectedGender: Gender // Получаем выбранный пол

        var body: some View {
            VStack() {
                if let userData = userData.first { // Проверяем, есть ли пользователь
                    // Заголовок с датой
                    HeaderView()
                        .padding(.top, safeAreaTopInset()) // Учет безопасной зоны сверху
                    // Статистика пользователя
                    UserStatsView(userData: userData)
                    MacrosView(userData: userData)
                    //   Spacer() // Выталкиваем оставшиеся элементы вниз
                    BottomNavigationView(userData: userData)

                } else {
                    Text("Данные пользователя не найдены")
                        .font(.headline)
                }
            }
            .onAppear {
                // Если данных нет, создаём нового пользователя
                if userData.isEmpty {
                    createNewUser()
                } else {
                    print("Selected Gender: \(selectedGender.rawValue)")
                    userData.first?.selectedGender = selectedGender
                }
            }
            .background(GradientView())
            .ignoresSafeArea()
        }
        // Функция для получения верхней безопасной зоны
        private func safeAreaTopInset() -> CGFloat {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return 0
            }
            return window.safeAreaInsets.top
        }
        private func createNewUser() {
            let newUser = UserData(
                weight: 0,
                height: 0,
                age: 0,
                activityLevel: .none,
                goal: .currentWeight,
                selectedGender: selectedGender
            )
            modelContext.insert(newUser) // Вставляем нового пользователя в контекст
            try? modelContext.save() // Сохраняем изменения
        }
    }

#Preview {
    Group {
        MainView(selectedGender: .male)
        MainView(selectedGender: .female)
    }
}
//
//            BottomNavigationView()

//
//  MainView.swift
//  FitLife
//
//  Created by Виктор Корольков on 07.12.2024.
//

import SwiftUI


    struct MainView: View {
        var selectedGender: Gender // Получаем выбранный пол

        // Состояния для управления калориями и макронутриентами
        @State private var callories: Int = 0
        @State private var proteins: Int = 0
        @State private var fats: Int = 0
        @State private var carbs: Int = 0

        // Состояния для уровня активности и цели
        @State private var activityLevel: ActivityLevel = .none
        @State private var goal: WeightGoal = .currentWeight

        var body: some View {
            VStack() { // Управляем отступами между элементами
                // Заголовок с датой
                HeaderView()
                    .padding(.top, safeAreaTopInset()) // Учет безопасной зоны сверху

                // Статистика пользователя
                UserStatsView(
                    selectedGender: selectedGender,
                    callories: $callories,
                    proteins: $proteins,
                    fats: $fats,
                    carbs: $carbs,
                    activityLevel: $activityLevel,
                    goal: $goal
                )

                MacrosView(
                    callories: $callories,
                    proteins: $proteins,
                    fats: $fats,
                    carbs: $carbs,
                    goal: $goal
                )
             //   Spacer() // Выталкиваем оставшиеся элементы вниз
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
    }

#Preview {
    Group {
        MainView(selectedGender: .male)
        MainView(selectedGender: .female)
    }
}
//
//            BottomNavigationView()

//
//  MainView.swift
//  FitLife
//
//  Created by Виктор Корольков on 07.12.2024.
//

import SwiftUI


    struct MainView: View {
        @StateObject private var userData = UserData()

        var selectedGender: Gender // Получаем выбранный пол

        var body: some View {
            VStack() { // Управляем отступами между элементами
                // Заголовок с датой
                HeaderView()
                    .padding(.top, safeAreaTopInset()) // Учет безопасной зоны сверху
                // Статистика пользователя
                UserStatsView(userData: userData)
                MacrosView(userData: userData)
             //   Spacer() // Выталкиваем оставшиеся элементы вниз
                BottomNavigationView()
            }
            .onAppear {
                print("Selected Gender: \(selectedGender.rawValue)")
                userData.selectedGender = selectedGender
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

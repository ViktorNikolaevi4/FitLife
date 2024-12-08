//
//  MainView.swift
//  FitLife
//
//  Created by Виктор Корольков on 07.12.2024.
//

import SwiftUI

struct MainView: View {
    var selectedGender: Gender // Получаем выбранный пол

    var body: some View {
        VStack {

            HeaderView()
                .padding(.top, safeAreaTopInset()) // Учет безопасной зоны сверху
            UserStatsView(selectedGender: selectedGender)


        //            MacrosView()
        //            Spacer()
        //            BottomNavigationView()
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

//
//  MacrosView.swift
//  FitLife
//
//  Created by Виктор Корольков on 08.12.2024.
//

import SwiftUI

enum WeightGoal: String, CaseIterable, Codable {
    case loseWeight = "Снизить вес"
    case currentWeight = "Текущий вес"
    case gainWeight = "Набрать вес"
}

struct MacrosView: View {
    @Bindable var userData: UserData

    @State private var callories: Int = 0
    @State private var selectedGoal: WeightGoal = .currentWeight

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
            VStack {
                Text("Осталось съесть за день")
                Text("калорий: \(userData.calories)")
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
            }
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
                      // Перерисовка при изменении цели
                      userData.goal = userData.goal
                  }
            }
        }
    }
}

//
//#Preview {
//    MacrosView()
//}

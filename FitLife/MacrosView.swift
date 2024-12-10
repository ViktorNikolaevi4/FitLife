//
//  MacrosView.swift
//  FitLife
//
//  Created by Виктор Корольков on 08.12.2024.
//

import SwiftUI

enum WeightGoal: String, CaseIterable {
    case loseWeight = "Снизить вес"
    case currentWeight = "Текущий вес"
    case gainWeight = "Набрать вес"
}

struct MacrosView: View {
    @ObservedObject var userData: UserData

    @State private var callories: Int = 0
    @State private var selectedGoal: WeightGoal = .currentWeight

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 20) {
                Text("Энергия: \(userData.calories)")
                    .font(.title2)
                    .fontWeight(.bold)

                // Круговая диаграмма
                PieChartView()
            }  .padding()
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
            }
        }
    }
}

//
//#Preview {
//    MacrosView()
//}

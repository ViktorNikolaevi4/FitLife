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

    @State private var calories: Int = 0
    @State private var macros: (proteins: Int, fats: Int, carbs: Int) = (0, 0, 0)

    var body: some View {
        VStack(spacing: 5) {
            // Блок с калориями и круговой диаграммой
            HStack(spacing: 20) {
                VStack {
                    Text("Энергия:")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(calories)")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)

                // Круговая диаграмма
                PieChartView(userData: userData, macros: $macros)
            }
            .padding()

            // Блок с БЖУ
            HStack(spacing: 60) {
                VStack {
                    Text("Белки")
                    Text("\(macros.proteins) г")
                }
                VStack {
                    Text("Жиры")
                    Text("\(macros.fats) г")
                }
                VStack {
                    Text("Углеводы")
                    Text("\(macros.carbs) г")
                }
            }
            .font(.headline)

            // Пикер для выбора цели
            VStack(spacing: 10) {
                Text("Цель")
                    .font(.headline)

                Picker("Цель", selection: $userData.goal) {
                    ForEach(WeightGoal.allCases, id: \.self) { goal in
                        Text(goal.rawValue)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
            }
        }
        .onAppear {
            Task {
                await updateData()
            }
        }
        .onChange(of: userData.goal) {
            Task {
                await updateData()
            }
        }
        .onChange(of: userData.activityLevel) {
            Task {
                await updateData()
            }
        }
    }

    // Асинхронное обновление данных
    @MainActor
    private func updateData() async {
        calories = await userData.calculateCalories()
        macros = await userData.calculateMacros()
    }
}



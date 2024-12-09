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
    @Binding var callories: Int
    @Binding var proteins: Int
    @Binding var fats: Int
    @Binding var carbs: Int
    
    @Binding var goal: WeightGoal


    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 20) {
                Text("Энергия: \(callories)")
                    .font(.title2)
                    .fontWeight(.bold)

                // Круговая диаграмма
                PieChartView(proteins: proteins, fats: fats, carbs: carbs)
            }  .padding()
            HStack(spacing: 60) {
                VStack {
                    Text("Белки")
                    Text("\(proteins) г")
                }
                VStack {
                    Text("Жиры")
                    Text("\(fats) г")
                }
                VStack {
                    Text("Углеводы")
                    Text("\(carbs) г")
                }
            }
            .font(.headline)
            VStack {
                Text("Осталось съесть за день")
                Text("калорий: \(callories)")
                HStack(spacing: 60) {
                    VStack {
                        Text("Белки")
                        Text("\(proteins) г")
                    }
                    VStack {
                        Text("Жиры")
                        Text("\(fats) г")
                    }
                    VStack {
                        Text("Углеводы")
                        Text("\(carbs) г")
                    }
                }
            }
            // Пикер для выбора цели
            VStack(spacing: 10) {
                Text("Цель")
                    .font(.headline)

                Picker("Цель", selection: $goal) {
                    ForEach(WeightGoal.allCases, id: \.self) { goal in
                        Text(goal.rawValue)
                    }
                }
                .pickerStyle(SegmentedPickerStyle()) // Используем стиль сегментированного пикера
                .padding()
                .onChange(of: goal) {
                    recalculateMacros()
                }
            }
        }
    }
    private func recalculateMacros() {
        // Здесь вы должны использовать привязанные данные (передайте их из родительского представления)
        let activityLevel: ActivityLevel = .moderate // Пример уровня активности
        let gender: Gender = .male // Пример пола
        let weight: Double = 70 // Пример веса
        let height: Double = 170 // Пример роста
        let age: Int = 25 // Пример возраста

        // Вызываем метод для расчёта калорий
        let calories = MacrosCalculator.calculateCaloriesMifflin(
            gender: gender,
            weight: weight,
            height: height,
            age: age,
            activityLevel: activityLevel,
            goal: goal
        )

        // Обновляем калории
        callories = calories

        // Пересчитываем макросы
        let macros = MacrosCalculator.calculateMacros(calories: calories, goal: goal)

        // Обновляем значения макронутриентов
        proteins = macros.proteins
        fats = macros.fats
        carbs = macros.carbs
    }
}


//#Preview {
//    MacrosView()
//}

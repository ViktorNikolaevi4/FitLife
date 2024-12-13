//
//  RationPopupView.swift
//  FitLife
//
//  Created by Виктор Корольков on 12.12.2024.
//

import SwiftUI

struct RationPopupView: View {
    var breakfastCalories: Int
    var lunchCalories: Int
    var dinnerCalories: Int
    var snacksCalories: Int
    @Environment(\.dismiss) private var dismiss // Для закрытия окна

    var body: some View {
        VStack(spacing: 16) {
            Text("Рацион на день")
                .font(.title2)
                .fontWeight(.bold)

            Divider()

            VStack(spacing: 8) {
                HStack {
                    Text("Завтрак:")
                    Spacer()
                    Text("\(breakfastCalories) ккал")
                        .foregroundColor(.blue)
                    Button("+ добавить еду") {
                        // Логика добавления еды для завтрака
                    }
                    .font(.caption)
                }
                Divider()

                HStack {
                    Text("Обед:")
                    Spacer()
                    Text("\(lunchCalories) ккал")
                        .foregroundColor(.blue)
                    Button("+ добавить еду") {
                        // Логика добавления еды для обеда
                    }
                    .font(.caption)
                }
                Divider()

                HStack {
                    Text("Ужин:")
                    Spacer()
                    Text("\(dinnerCalories) ккал")
                        .foregroundColor(.blue)
                    Button("+ добавить еду") {
                        // Логика добавления еды для ужина
                    }
                    .font(.caption)
                }
                Divider()

                HStack {
                    Text("Перекусы:")
                    Spacer()
                    Text("\(snacksCalories) ккал")
                        .foregroundColor(.blue)
                    Button("+ добавить еду") {
                        // Логика добавления еды для перекусов
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal)

            Spacer()

            Button("OK") {
                dismiss() // Закрыть окно
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .presentationDetents([.medium])
    }
}


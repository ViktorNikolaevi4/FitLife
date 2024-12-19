//
//  RationPopupView.swift
//  FitLife
//
//  Created by Виктор Корольков on 12.12.2024.
//

import SwiftUI

enum MealType: String, CaseIterable {
    case breakfast = "Завтрак"
    case lunch = "Обед"
    case dinner = "Ужин"
    case snacks = "Перекусы"

    var displayName: String {
        self.rawValue
    }
}


struct RationPopupView: View {
    @State var breakfastCalories: Int
    @State var lunchCalories: Int
    @State var dinnerCalories: Int
    @State var snacksCalories: Int

    @State private var showProductSelection = false
    @State private var selectedMeal: MealType? = nil
    @Environment(\.dismiss) private var dismiss // Для закрытия окна

    var body: some View {
        VStack(spacing: 16) {
            Text("Рацион на день")
                .font(.title2)
                .fontWeight(.bold)

            Divider()

            VStack(spacing: 8) {
                mealRow(for: .breakfast, calories: breakfastCalories)
                Divider()
                mealRow(for: .lunch, calories: lunchCalories)
                Divider()
                mealRow(for: .dinner, calories: dinnerCalories)
                Divider()
                mealRow(for: .snacks, calories: snacksCalories)
            }
            .padding(.horizontal)

            Spacer()

            Button("OK") {
                dismiss()
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
        .sheet(isPresented: Binding(
            get: { showProductSelection && selectedMeal != nil },
            set: { showProductSelection = $0 }
        )) {
            if let selectedMeal = selectedMeal {
                ProductSelectionView(
                    mealType: selectedMeal,
                    date: Date(),
                    onProductSelected: { selectedProduct in
                        addProductToMeal(selectedProduct)
                    }
                )
            }
        }
    }

    // Вспомогательный метод для создания строки приёма пищи
    private func mealRow(for mealType: MealType, calories: Int) -> some View {
        HStack {
            Text(mealType.displayName) // Используем displayName из enum
            Spacer()
            Text("\(calories) ккал")
                .foregroundColor(.blue)
            Button("+ добавить еду") {
                selectedMeal = mealType
                showProductSelection = true
            }
            .font(.caption)
            .foregroundStyle(.blue)
        }
    }

    // Обновляем калории в зависимости от выбранного приёма пищи
    private func addProductToMeal(_ product: Product) {
        switch selectedMeal {
        case .breakfast:
            breakfastCalories += product.calories
        case .lunch:
            lunchCalories += product.calories
        case .dinner:
            dinnerCalories += product.calories
        case .snacks:
            snacksCalories += product.calories
        default:
            break
        }
    }
}

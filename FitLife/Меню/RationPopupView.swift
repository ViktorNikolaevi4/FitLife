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
    @State private var breakfastProducts: [Product]
    @State private var lunchProducts: [Product]
    @State private var dinnerProducts: [Product]
    @State private var snacksProducts: [Product]

    @State private var showProductSelection = false
    @State private var selectedMeal: MealType? = nil
    @Environment(\.dismiss) private var dismiss

    init(breakfastProducts: [Product] = [],
         lunchProducts: [Product] = [],
         dinnerProducts: [Product] = [],
         snacksProducts: [Product] = []) {
        _breakfastProducts = State(initialValue: breakfastProducts)
        _lunchProducts = State(initialValue: lunchProducts)
        _dinnerProducts = State(initialValue: dinnerProducts)
        _snacksProducts = State(initialValue: snacksProducts)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Рацион на день")
                .font(.title2)
                .fontWeight(.bold)

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    mealRow(for: .breakfast, products: breakfastProducts)
                    Divider()
                    mealRow(for: .lunch, products: lunchProducts)
                    Divider()
                    mealRow(for: .dinner, products: dinnerProducts)
                    Divider()
                    mealRow(for: .snacks, products: snacksProducts)
                }
                .padding(.horizontal)
            }
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
    private func mealRow(for mealType: MealType, products: [Product]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(mealType.displayName)
                Spacer()
                Text("\(products.reduce(0) { $0 + $1.calories }) ккал")
                    .foregroundColor(.blue)
                Button("+ добавить еду") {
                    selectedMeal = mealType
                    showProductSelection = true
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }

            if !products.isEmpty {
                ForEach(products) { product in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name)
                            .font(.headline)
                        Text("Калории: \(product.calories) ккал, Б: \(String(format: "%.1f", product.protein)) г., Ж: \(String(format: "%.1f", product.fat)) г., У: \(String(format: "%.1f", product.carbs)) г.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // Обновляем продукты для выбранного приема пищи
    private func addProductToMeal(_ product: Product) {
        switch selectedMeal {
        case .breakfast:
            breakfastProducts.append(product)
        case .lunch:
            lunchProducts.append(product)
        case .dinner:
            dinnerProducts.append(product)
        case .snacks:
            snacksProducts.append(product)
        default:
            break
        }
    }
}

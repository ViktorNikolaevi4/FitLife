//
//  ProductSelectionView.swift
//  FitLife
//
//  Created by Виктор Корольков on 18.12.2024.
//

import SwiftUI

struct ProductSelectionView: View {
    let mealType: MealType // Тип приема пищи (Завтрак, Обед и т.д.)
    let date: Date           // Текущая дата
    @State var productLoader = ProductLoader()
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    var onProductSelected: (Product) -> Void

    var filteredProducts: [Product] {
        if searchText.isEmpty {
            return productLoader.products
        } else {
            return productLoader.products.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                VStack {
                    Text("Таблица калорийности продуктов питания")
                    Text("(данные указаны на 100 г продукта)")
                }.foregroundStyle(.black)
                TextField("Поиск еды...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                List(filteredProducts) { product in
                    Button(action: {
                        onProductSelected(product) // Передаём выбранный продукт
                        dismiss()
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            // Название продукта
                            Text(product.name)
                                .font(.headline)
                            // Дополнительная информация
                            Text("На 100 г: \(product.calories) ккал, Б \(String(format: "%.1f", product.protein)) г., Ж \(String(format: "%.1f", product.fat)) г., У \(String(format: "%.1f", product.carbs)) г.")
                                .font(.caption)
                        }
                        .padding(.vertical, 4)  // Отступы сверху и снизу для читаемости
                        .foregroundColor(.black)
                    }
                }
            }
            // Навигационный заголовок с приемом пищи и датой
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Кнопка "Создать" слева
                ToolbarItem(placement: .topBarLeading) {
                    Button("Создать") {
                        // Логика для кнопки "Создать"
                        print("Создать нажато")
                    }
                    .foregroundColor(.blue)
                }
                // Кастомный заголовок с VStack
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text(mealType.displayName) // Название приема пищи
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(formattedDate) // Отформатированная дата
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Кнопка "Закрыть" в правом углу
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    // Форматирование даты
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}

//
//#Preview {
//    ProductSelectionView()
//}

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
    @State private var selectedFilter: FilterType = .all // Управление текущим фильтром
    @State private var isCreatingProduct: Bool = false // Управление формой создания продукта
    @State private var customProductName: String = ""
    @State private var customProductCalories: String = ""
    @State private var customProductProtein: String = ""
    @State private var customProductFat: String = ""
    @State private var customProductCarbs: String = ""
    var onProductSelected: (Product) -> Void

    enum FilterType: String, CaseIterable {
        case all = "Общие"
        case favorites = "Любимые"
        case custom = "Свои"
    }

    var filteredProducts: [Product] {
        let baseList: [Product]
        switch selectedFilter {
        case .all:
            baseList = productLoader.products
        case .favorites:
            baseList = productLoader.products.filter { $0.isFavorite }
        case .custom:
            baseList = productLoader.products.filter { $0.isCustom }
        }

        if searchText.isEmpty {
            return baseList
        } else {
            return baseList.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                VStack {
                    Text("Таблица калорийности продуктов питания")
                    Text("(данные указаны на 100 г продукта)")
                }.foregroundStyle(.black)

                // Picker для фильтров
                Picker("Выберите категорию", selection: $selectedFilter) {
                    ForEach(FilterType.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle()) // Сегментированный стиль
                .padding(.horizontal)

                TextField("Поиск еды...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                List(filteredProducts, id: \.id) { product in
                    Button(action: {
                   //     self.selectedProduct = product
                   //     self.portionSize = "100" // Установить начальное значение порции при выборе продукта
                    //    self.showProductDetails = true
                        onProductSelected(product) // Передаём выбранный продукт
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                // Название продукта
                                Text(product.name)
                                    .font(.headline)
                                // Дополнительная информация
                                Text("На 100 г: \(product.calories) ккал, Б \(String(format: "%.1f", product.protein)) г., Ж \(String(format: "%.1f", product.fat)) г., У \(String(format: "%.1f", product.carbs)) г.")
                                    .font(.caption)
                            }.foregroundColor(.black)
                            Spacer()
                            // Кнопка "звезда" для добавления в избранное
                            Button(action: {
                                if let index = productLoader.products.firstIndex(where: { $0.id == product.id }) {
                                    productLoader.products[index].isFavorite.toggle() // Переключение избранного
                                }
                            }) {
                                Image(systemName: product.isFavorite ? "star.fill" : "star")
                                    .foregroundColor(product.isFavorite ? .yellow : .gray)
                            }
                            .buttonStyle(BorderlessButtonStyle())

                            .padding(.vertical, 4)  // Отступы сверху и снизу для читаемости
                        }
                    }
                }

                if isCreatingProduct {
                    ZStack {
                        Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)

                        VStack(spacing: 16) {
                            Text("Новый продукт")
                                .font(.headline)
                            Text("(БЖУ указывайте на 100 г продукта)")
                                .font(.caption)

                            TextField("Наименование", text: $customProductName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)

                            TextField("Энергия, ккал", text: $customProductCalories)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)

                            HStack(spacing: 16) {
                                TextField("Белки, г.", text: $customProductProtein)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                TextField("Жиры, г.", text: $customProductFat)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                TextField("Углеводы, г.", text: $customProductCarbs)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            .padding(.horizontal)

                            HStack {
                                Button("Создать") {
                                    createCustomProduct()
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)

                                Button("Отмена") {
                                    isCreatingProduct = false
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 10)
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
                        isCreatingProduct = true
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
    private func createCustomProduct() {
        guard
            let calories = Double(customProductCalories),
            let protein = Double(customProductProtein),
            let fat = Double(customProductFat),
            let carbs = Double(customProductCarbs),
            !customProductName.isEmpty
        else {
            return
        }

        let newProduct = Product(
            name: customProductName,
            protein: protein,
            fat: fat,
            carbs: carbs,
            calories: Int(calories),
            isFavorite: false,
            isCustom: true
        )

        productLoader.products.append(newProduct)
        isCreatingProduct = false
        clearCustomProductFields()
    }

    private func clearCustomProductFields() {
        customProductName = ""
        customProductCalories = ""
        customProductProtein = ""
        customProductFat = ""
        customProductCarbs = ""
    }
}

//
//#Preview {
//    ProductSelectionView()
//}

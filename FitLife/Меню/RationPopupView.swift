//
//  RationPopupView.swift
//  FitLife
//
//  Created by Виктор Корольков on 12.12.2024.
//

import SwiftUI
import SwiftData

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
    @State private var breakfastProducts: [Product] = []
    @State private var lunchProducts: [Product] = []
    @State private var dinnerProducts: [Product] = []
    @State private var snacksProducts: [Product] = []

    @State private var showProductSelection = false
    @State private var selectedMeal: MealType? = nil
    @State private var showProductDetails = false
    @State private var selectedProduct: Product? = nil
    @State private var portionSize: String = "100" // Размер порции в граммах



    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let selectedGender: Gender

    init(breakfastProducts: [Product] = [],
         lunchProducts: [Product] = [],
         dinnerProducts: [Product] = [],
         snacksProducts: [Product] = [],
         gender: Gender) {
        _breakfastProducts = State(initialValue: breakfastProducts)
        _lunchProducts = State(initialValue: lunchProducts)
        _dinnerProducts = State(initialValue: dinnerProducts)
        _snacksProducts = State(initialValue: snacksProducts)
        self.selectedGender = gender
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
        .presentationDetents([.medium, .large])
        .onAppear {
            loadData(for: Date(), gender: selectedGender) // Загружаем данные для текущей даты и выбранного гендера
        }
        .sheet(isPresented: Binding(
            get: { showProductSelection && selectedMeal != nil },
            set: { showProductSelection = $0 }
        )) {
            if let selectedMeal = selectedMeal {
                ProductSelectionView(
                    mealType: selectedMeal,
                    date: Date(),
                    onProductSelected: { selectedProduct in
                        self.selectedProduct = selectedProduct // Сохраняем выбранный продукт
                        self.portionSize = "100"               // Устанавливаем порцию на значение 100
                        self.showProductDetails = true         // Переходим на экран деталей продукта
                        self.showProductSelection = false      // Закрываем окно выбора продукта

                        // Передача выбранного продукта вместе с гендером
                         addProductToMeal(selectedProduct, portion: Double(portionSize) ?? 100, gender: selectedGender)
                    }
                )
            }
        }
        // Экран настройки продукта
        if showProductDetails, let selectedProduct = selectedProduct {
            ZStack {
                Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
                VStack(spacing: 16) {
                    Text(selectedProduct.name)
                        .font(.headline)
                    Text("Энергия, ккал")
                    Text("\(calculateCalories(for: selectedProduct)) ккал")
                        .font(.largeTitle)

                        .font(.subheadline)
                    TextField("Порция, г", text: $portionSize)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .onChange(of: portionSize) {
                            // Удаляем все символы, кроме цифр
                            portionSize = portionSize.filter { $0.isNumber }
                        }
                    Text("Порция в граммах")

                    HStack {
                        Button("Добавить") {
                            addProductToMeal(selectedProduct, portion: Double(portionSize) ?? 100, gender: selectedGender)
                            showProductDetails = false
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)

                        Button("Отмена") {
                            showProductDetails = false
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(radius: 10)
            }
        }
    }

    private func loadData(for date: Date, gender: Gender) {
        // Фильтруем записи по дате и гендеру
        let fetchDescriptor = FetchDescriptor<FoodEntry>()
        do {
            let foodEntries = try modelContext.fetch(fetchDescriptor)
            let filteredEntries = foodEntries.filter {
                Calendar.current.isDate($0.date, inSameDayAs: date) && $0.gender == gender
            }

            // Обновляем локальные списки продуктов
            breakfastProducts = filteredEntries
                .filter { $0.mealType == MealType.breakfast.rawValue }
                .map { productFromEntry($0) }
            lunchProducts = filteredEntries
                .filter { $0.mealType == MealType.lunch.rawValue }
                .map { productFromEntry($0) }
            dinnerProducts = filteredEntries
                .filter { $0.mealType == MealType.dinner.rawValue }
                .map { productFromEntry($0) }
            snacksProducts = filteredEntries
                .filter { $0.mealType == MealType.snacks.rawValue }
                .map { productFromEntry($0) }
        } catch {
            print("Ошибка загрузки данных: \(error)")
        }
    }

    // Преобразуем FoodEntry в Product
    private func productFromEntry(_ entry: FoodEntry) -> Product {
        return Product(
            name: entry.productName,
            protein: entry.protein,
            fat: entry.fat,
            carbs: entry.carbs,
            calories: entry.calories,
            isFavorite: false, // По умолчанию
            isCustom: false // Или true, если это пользовательский продукт
        )
    }

    // Когда пользователь выбирает продукт для добавления
    private func showProductDetails(for product: Product) {
        selectedProduct = product
        portionSize = "100" // Устанавливаем начальное значение
        showProductDetails = true
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
    private func addProductToMeal(_ product: Product, portion: Double, gender: Gender) {
        let factor = portion / 100
        let adjustedProduct = Product(
            name: product.name,
            protein: product.protein * factor,
            fat: product.fat * factor,
            carbs: product.carbs * factor,
            calories: Int(Double(product.calories) * factor),
            isFavorite: product.isFavorite,
            isCustom: product.isCustom
        )

        // Проверяем, есть ли уже такой продукт в текущем списке, и обновляем его порцию
        switch selectedMeal {
        case .breakfast:
            if let index = breakfastProducts.firstIndex(where: { $0.name == product.name }) {
                // Увеличиваем порцию, если продукт уже существует
                breakfastProducts[index].protein += adjustedProduct.protein
                breakfastProducts[index].fat += adjustedProduct.fat
                breakfastProducts[index].carbs += adjustedProduct.carbs
                breakfastProducts[index].calories += adjustedProduct.calories
            } else {
                // Если продукта нет, добавляем его
                breakfastProducts.append(adjustedProduct)
            }
        case .lunch:
            if let index = lunchProducts.firstIndex(where: { $0.name == product.name }) {
                lunchProducts[index].protein += adjustedProduct.protein
                lunchProducts[index].fat += adjustedProduct.fat
                lunchProducts[index].carbs += adjustedProduct.carbs
                lunchProducts[index].calories += adjustedProduct.calories
            } else {
                lunchProducts.append(adjustedProduct)
            }
        case .dinner:
            if let index = dinnerProducts.firstIndex(where: { $0.name == product.name }) {
                dinnerProducts[index].protein += adjustedProduct.protein
                dinnerProducts[index].fat += adjustedProduct.fat
                dinnerProducts[index].carbs += adjustedProduct.carbs
                dinnerProducts[index].calories += adjustedProduct.calories
            } else {
                dinnerProducts.append(adjustedProduct)
            }
        case .snacks:
            if let index = snacksProducts.firstIndex(where: { $0.name == product.name }) {
                snacksProducts[index].protein += adjustedProduct.protein
                snacksProducts[index].fat += adjustedProduct.fat
                snacksProducts[index].carbs += adjustedProduct.carbs
                snacksProducts[index].calories += adjustedProduct.calories
            } else {
                snacksProducts.append(adjustedProduct)
            }
        default:
            break
        }

        // Сохраняем данные в базу
        let foodEntry = FoodEntry(
            date: Date(),
            mealType: selectedMeal ?? .breakfast,
            product: adjustedProduct,
            portion: portion,
            gender: gender,
            isFavorite: product.isFavorite
        )
        do {
            modelContext.insert(foodEntry)
            try modelContext.save()
            print("Продукт успешно сохранен!")
        } catch {
            print("Ошибка при сохранении продукта: \(error)")
        }
    }




private func calculateCalories(for product: Product) -> Int {
    let portion = Double(portionSize) ?? 100
    return Int((Double(product.calories) * portion) / 100)
 }
}

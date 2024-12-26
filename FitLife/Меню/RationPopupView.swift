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
                    onProductSelected: { product in
                        self.selectedProduct = product
                        self.showProductDetails = true // Показываем экран ввода порции
                        self.showProductSelection = false
                    },
                    onCustomProductSelected: { customProduct in
                        let genericProduct = Product(
                            name: customProduct.name,
                            protein: customProduct.protein,
                            fat: customProduct.fat,
                            carbs: customProduct.carbs,
                            calories: customProduct.calories,
                            isFavorite: customProduct.isFavorite,
                            isCustom: true
                        )
                        self.selectedProduct = genericProduct
                        self.showProductDetails = true // Показываем экран ввода порции
                        self.showProductSelection = false
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
        let fetchDescriptor = FetchDescriptor<FoodEntry>()
        do {
            let foodEntries = try modelContext.fetch(fetchDescriptor)
            let filteredEntries = foodEntries.filter {
                Calendar.current.isDate($0.date, inSameDayAs: date) && $0.gender == gender
            }

            // Обновляем локальные списки продуктов
            breakfastProducts = filteredEntries
                .filter { $0.mealType == MealType.breakfast.rawValue }
                .compactMap { $0.product } // Получаем продукты через связь
            lunchProducts = filteredEntries
                .filter { $0.mealType == MealType.lunch.rawValue }
                .compactMap { $0.product }
            dinnerProducts = filteredEntries
                .filter { $0.mealType == MealType.dinner.rawValue }
                .compactMap { $0.product }
            snacksProducts = filteredEntries
                .filter { $0.mealType == MealType.snacks.rawValue }
                .compactMap { $0.product }
        } catch {
            print("Ошибка загрузки данных: \(error)")
        }
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
        addGenericProductToMeal(product, portion: portion, gender: gender)
    }

    private func addCustomProductToMeal(_ customProduct: CustomProduct, portion: Double, gender: Gender) {
        let genericProduct = Product(
            name: customProduct.name,
            protein: customProduct.protein,
            fat: customProduct.fat,
            carbs: customProduct.carbs,
            calories: customProduct.calories,
            isFavorite: customProduct.isFavorite,
            isCustom: true
        )
        addGenericProductToMeal(genericProduct, portion: portion, gender: gender)
    }

    private func addGenericProductToMeal(_ product: Product, portion: Double, gender: Gender) {
        guard let selectedMeal = selectedMeal else {
            print("Ошибка: Не выбран тип приема пищи!")
            return
        }

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

        // Добавляем продукт в соответствующий список
        switch selectedMeal {
        case .breakfast:
            appendOrUpdateProduct(&breakfastProducts, with: adjustedProduct)
        case .lunch:
            appendOrUpdateProduct(&lunchProducts, with: adjustedProduct)
        case .dinner:
            appendOrUpdateProduct(&dinnerProducts, with: adjustedProduct)
        case .snacks:
            appendOrUpdateProduct(&snacksProducts, with: adjustedProduct)
        }

        // Сохраняем в базу
        let foodEntry = FoodEntry(
            date: Date(),
            mealType: selectedMeal.rawValue,
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

    private func appendOrUpdateProduct(_ products: inout [Product], with newProduct: Product) {
        if let index = products.firstIndex(where: { $0.name == newProduct.name }) {
            products[index].protein += newProduct.protein
            products[index].fat += newProduct.fat
            products[index].carbs += newProduct.carbs
            products[index].calories += newProduct.calories
        } else {
            products.append(newProduct)
        }
    }



private func calculateCalories(for product: Product) -> Int {
    let portion = Double(portionSize) ?? 100
    return Int((Double(product.calories) * portion) / 100)
 }
}

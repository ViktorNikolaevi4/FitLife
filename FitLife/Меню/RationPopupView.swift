import SwiftUI
import SwiftData

enum MealType: String, CaseIterable {
    case breakfast = "Завтрак"
    case lunch = "Обед"
    case dinner = "Ужин"
    case snacks = "Перекусы"

    var displayName: String { rawValue }
}

struct RationPopupView: View {
    @Environment(\.dismiss) private var dismissRation
    @Environment(\.modelContext) private var modelContext

    // MARK: – данные по приёмам пищи
    @State private var breakfastProducts: [Product] = []
    @State private var lunchProducts: [Product] = []
    @State private var dinnerProducts: [Product] = []
    @State private var snacksProducts: [Product] = []

    // MARK: – управление показом модалов
    @State private var showProductSelection = false
    @State private var showProductDetails = false

    // MARK: – выбранный приём и продукт
    @State private var selectedMeal: MealType? = nil
    @State private var selectedProduct: Product? = nil
    @State private var defaultPortion: String = "100"

    @Binding var selectedDate: Date
    let selectedGender: Gender
    let onMealAdded: () -> Void

    init(
        breakfastProducts: [Product] = [],
        lunchProducts: [Product] = [],
        dinnerProducts: [Product] = [],
        snacksProducts: [Product] = [],
        gender: Gender,
        selectedDate: Binding<Date>,
        onMealAdded: @escaping () -> Void
    ) {
        _breakfastProducts = State(initialValue: breakfastProducts)
        _lunchProducts     = State(initialValue: lunchProducts)
        _dinnerProducts    = State(initialValue: dinnerProducts)
        _snacksProducts    = State(initialValue: snacksProducts)
        self.selectedGender = gender
        self._selectedDate  = selectedDate
        self.onMealAdded    = onMealAdded
    }

    var body: some View {
        VStack(spacing: 16) {
            // Заголовок
            Text("Рацион на день")
                .font(.title2)
                .bold()
                .padding(.top)

            // Итоговые данные за день
            VStack {
                Text("Итого за день:")
                    .font(.headline)
                Text("Калорий: \(totalCalories) ккал")
                HStack(spacing: 20) {
                    Text("Белки: \(totalProteins) г")
                    Text("Жиры: \(totalFats) г")
                    Text("Углеводы: \(totalCarbs) г")
                }
                .font(.subheadline)
                .foregroundColor(.gray)
            }

            Divider()

            // Список приёмов пищи
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

            // Закрыть
            Button("OK") {
                dismissRation()
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            loadData(for: selectedDate, gender: selectedGender)
        }
        .onChange(of: selectedDate) { _ in
            loadData(for: selectedDate, gender: selectedGender)
        }
        // MARK: – sheet для выбора продукта
        .sheet(isPresented: $showProductSelection) {
            if let meal = selectedMeal {
                ProductSelectionView(
                    mealType: meal,
                    date: selectedDate,
                    onProductSelected: { product in
                        self.selectedProduct = product
                        self.defaultPortion = "100"
                        self.showProductSelection = false
                        self.showProductDetails    = true
                    },
                    onCustomProductSelected: { custom in
                        let generic = Product(
                            name: custom.name,
                            protein: custom.protein,
                            fat: custom.fat,
                            carbs: custom.carbs,
                            calories: custom.calories,
                            isFavorite: custom.isFavorite,
                            isCustom: true
                        )
                        self.selectedProduct = generic
                        self.defaultPortion = "100"
                        self.showProductSelection = false
                        self.showProductDetails    = true
                    }
                )
            }
        }
        // MARK: – sheet для ввода порции (модальное окно)
        .sheet(isPresented: $showProductDetails) {
            if let meal = selectedMeal, let product = selectedProduct {
                VStack(spacing: 20) {
                    Text(product.name)
                        .font(.headline)
                        .padding(.top, 20)

                    Text("Энергия, ккал")
                        .font(.subheadline)
                    Text("\(product.calories) ккал")
                        .font(.largeTitle)
                        .bold()

                    TextField("Порция в граммах", text: $defaultPortion)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    Spacer()

                    HStack(spacing: 16) {
                        Button("Отмена") {
                            showProductDetails = false
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color(.systemGray4))
                        .foregroundColor(.white)
                        .cornerRadius(12)

                        Button("Добавить") {
                            let grams = Int(defaultPortion) ?? 100
                            addGenericProduct(meal: meal, product: product, portion: Double(grams))
                            showProductDetails = false
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
                .presentationDetents([.medium, .fraction(0.9)])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: – вспомогательные
    private var totalCalories: Int {
        (breakfastProducts + lunchProducts + dinnerProducts + snacksProducts)
            .reduce(0) { $0 + $1.calories }
    }

    private var totalProteins: Int {
        (breakfastProducts + lunchProducts + dinnerProducts + snacksProducts)
            .reduce(0) { $0 + Int($1.protein) }
    }

    private var totalFats: Int {
        (breakfastProducts + lunchProducts + dinnerProducts + snacksProducts)
            .reduce(0) { $0 + Int($1.fat) }
    }

    private var totalCarbs: Int {
        (breakfastProducts + lunchProducts + dinnerProducts + snacksProducts)
            .reduce(0) { $0 + Int($1.carbs) }
    }

    private func loadData(for date: Date, gender: Gender) {
        let fetchDescriptor = FetchDescriptor<FoodEntry>()
        do {
            let entries = try modelContext.fetch(fetchDescriptor)
            let filtered = entries.filter {
                Calendar.current.isDate($0.date, inSameDayAs: date) &&
                $0.gender == gender
            }

            breakfastProducts = filtered
                .filter { $0.mealType == MealType.breakfast.rawValue }
                .map { $0.product }
            lunchProducts = filtered
                .filter { $0.mealType == MealType.lunch.rawValue }
                .map { $0.product }
            dinnerProducts = filtered
                .filter { $0.mealType == MealType.dinner.rawValue }
                .map { $0.product }
            snacksProducts = filtered
                .filter { $0.mealType == MealType.snacks.rawValue }
                .map { $0.product }

        } catch {
            print("Ошибка при загрузке FoodEntry: \(error)")
        }
    }

    private func mealRow(for mealType: MealType, products: [Product]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(mealType.displayName)
                Spacer()
                Text("\(products.reduce(0) { $0 + $1.calories }) ккал")
                    .foregroundColor(.blue)
                Button("+ добавить еду") {
                    selectedMeal = mealType
                    showProductSelection = true
                }
                .foregroundColor(.blue)
                .font(.caption)
            }

            ForEach(products) { product in
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                        .font(.subheadline)

                    HStack(spacing: 4) {
                        Text("Калории: \(product.calories) ккал,")
                        Text("Б: \(String(format: "%.1f", product.protein)) г,")
                        Text("Ж: \(String(format: "%.1f", product.fat)) г,")
                        Text("У: \(String(format: "%.1f", product.carbs)) г")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
    }

    private func addGenericProduct(meal: MealType, product: Product, portion: Double) {
        let factor = portion / 100
        let adjusted = Product(
            name: product.name,
            protein: product.protein * factor,
            fat: product.fat * factor,
            carbs: product.carbs * factor,
            calories: Int(Double(product.calories) * factor),
            isFavorite: product.isFavorite,
            isCustom: product.isCustom
        )

        // обновляем локально
        switch meal {
        case .breakfast: breakfastProducts.append(adjusted)
        case .lunch:     lunchProducts.append(adjusted)
        case .dinner:    dinnerProducts.append(adjusted)
        case .snacks:    snacksProducts.append(adjusted)
        }

        // сохраняем FoodEntry
        let entry = FoodEntry(
            date: selectedDate,
            mealType: meal.rawValue,
            product: adjusted,
            portion: portion,
            gender: selectedGender,
            isFavorite: adjusted.isFavorite
        )
        modelContext.insert(entry)
        try? modelContext.save()
        onMealAdded()
    }
}


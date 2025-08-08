import SwiftUI
import SwiftData

// MARK: — Тип приёма пищи
enum MealType: String, CaseIterable, Identifiable {
    case breakfast = "Завтрак"
    case lunch     = "Обед"
    case dinner    = "Ужин"
    case snacks    = "Перекусы"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

struct RationPopupView: View {
    // MARK: — Состояние для продуктов
    @State private var breakfastProducts: [Product] = []
    @State private var lunchProducts:    [Product] = []
    @State private var dinnerProducts:   [Product] = []
    @State private var snacksProducts:   [Product] = []

    // MARK: — Управление состоянием показа
    @State private var selectedMeal: MealType? = nil
    @State private var selectedProduct: Product? = nil
    @State private var showProductDetails = false
    @State private var portionSize: String = "100"
    @State private var activeMeal: MealType? = nil

    // MARK: — Внешние параметры
    @Binding var selectedDate: Date
    let selectedGender: Gender
    let onMealAdded: () -> Void

    // MARK: — Окружение
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: — Инициализатор
    init(
        breakfastProducts: [Product] = [],
        lunchProducts:    [Product] = [],
        dinnerProducts:   [Product] = [],
        snacksProducts:   [Product] = [],
        gender:           Gender,
        selectedDate:     Binding<Date>,
        onMealAdded:      @escaping () -> Void
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

            // Если нужно вводить порцию — показываем только этот экран
            if showProductDetails, let prod = selectedProduct {
                Text(prod.name)
                    .font(.headline)
                Text("Энергия, ккал")
                Text("\(calculateCalories(for: prod)) ккал")
                    .font(.largeTitle)

                TextField("Порция, г", text: $portionSize)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .onChange(of: portionSize) {
                        portionSize = portionSize.filter { $0.isNumber }
                    }

                Text("Порция в граммах")
                    .padding(.bottom, 8)

                HStack(spacing: 16) {
                    Button("Добавить") {
                        if let p = Double(portionSize) {
                            addGenericProductToMeal(prod, portion: p, gender: selectedGender)
                        }
                        // закрываем весь popup
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)

                    Button("Отмена") {
                        // просто возвращаемся к списку приёмов пищи
                        showProductDetails = false
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

            } else {
                // Основной экран: итоги и список приёмов пищи
                Text("Рацион на день")
                    .font(.title2).fontWeight(.bold)

                VStack {
                    Text("Итого за день:").font(.headline)
                    Text("Калорий: \(totalCalories) ккал")
                    HStack(spacing: 20) {
                        Text("Белки: \(totalProteins) г")
                        Text("Жиры: \(totalFats) г")
                        Text("Углеводы: \(totalCarbs) г")
                    }
                    .font(.subheadline).foregroundColor(.gray)
                }

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
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }

        } // VStack
        .padding()
        .presentationDetents([.medium, .large])
        .onAppear {
            loadData(for: selectedDate, gender: selectedGender)
        }
        .onChange(of: selectedDate) { _ in
            loadData(for: selectedDate, gender: selectedGender)
        }
        // Лист выбора продукта (всегда поверх текущего экрана)
                .sheet(item: $selectedMeal) { meal in
                   ProductSelectionView(
                        mealType: meal,
                        date: selectedDate,
                        onProductSelected: { product in
                            selectedProduct = product
                            activeMeal     = meal       // ← запоминаем, куда добавлять
                           selectedMeal   = nil
                    // небольшой лаг, чтобы закрылась карта выбора
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showProductDetails = true
                        portionSize = "100"
                    }
                },
                onCustomProductSelected: { custom in
                    let generic = Product(
                        name:       custom.name,
                        protein:    custom.protein,
                        fat:        custom.fat,
                        carbs:      custom.carbs,
                        calories:   custom.calories,
                        isFavorite: custom.isFavorite,
                        isCustom:   true
                    )
                    selectedProduct = generic
                    activeMeal     = meal
                    selectedMeal = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showProductDetails = true
                        portionSize = "100"
                    }
                }
            )
        }
    }

    // MARK: — Подсчёты
    private var totalCalories: Int {
        [breakfastProducts, lunchProducts, dinnerProducts, snacksProducts]
            .flatMap { $0 }.reduce(0) { $0 + $1.calories }
    }
    private var totalProteins: Int {
        [breakfastProducts, lunchProducts, dinnerProducts, snacksProducts]
            .flatMap { $0 }.reduce(0) { $0 + Int($1.protein) }
    }
    private var totalFats: Int {
        [breakfastProducts, lunchProducts, dinnerProducts, snacksProducts]
            .flatMap { $0 }.reduce(0) { $0 + Int($1.fat) }
    }
    private var totalCarbs: Int {
        [breakfastProducts, lunchProducts, dinnerProducts, snacksProducts]
            .flatMap { $0 }.reduce(0) { $0 + Int($1.carbs) }
    }

    // MARK: — Загрузка из SwiftData
    private func loadData(for date: Date, gender: Gender) {
        let req = FetchDescriptor<FoodEntry>()
        do {
            let all = try modelContext.fetch(req)
            let filtered = all.filter {
                Calendar.current.isDate($0.date, inSameDayAs: date) && $0.gender == gender
            }
            breakfastProducts = filtered
                .filter { $0.mealType == MealType.breakfast.rawValue }
                .compactMap { $0.product }
            lunchProducts = filtered
                .filter { $0.mealType == MealType.lunch.rawValue }
                .compactMap { $0.product }
            dinnerProducts = filtered
                .filter { $0.mealType == MealType.dinner.rawValue }
                .compactMap { $0.product }
            snacksProducts = filtered
                .filter { $0.mealType == MealType.snacks.rawValue }
                .compactMap { $0.product }
        } catch {
            print("Ошибка загрузки данных: \(error)")
        }
    }

    // MARK: — Отображение строки приема пищи
    private func mealRow(for mealType: MealType, products: [Product]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(mealType.displayName)
                Spacer()
                Text("\(products.reduce(0) { $0 + $1.calories }) ккал")
                    .foregroundColor(.blue)
                Button("+ добавить еду") {
                    selectedMeal = mealType
                }
                .font(.caption).foregroundStyle(.blue)
            }

            ForEach(products) { p in
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.name).font(.headline)
                    Text("Калории: \(p.calories) ккал, Б: \(String(format: "%.1f", p.protein)) г, Ж: \(String(format: "%.1f", p.fat)) г, У: \(String(format: "%.1f", p.carbs)) г")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: — Сохранение продукта
    private func addGenericProductToMeal(_ product: Product, portion: Double, gender: Gender) {
        guard let meal = activeMeal else { return }
        let factor = portion / 100
        let adjusted = Product(
            name:     product.name,
            protein:  product.protein * factor,
            fat:      product.fat * factor,
            carbs:    product.carbs * factor,
            calories: Int(Double(product.calories) * factor),
            isFavorite: product.isFavorite,
            isCustom:   product.isCustom
        )

        switch meal {
        case .breakfast: appendOrUpdate(&breakfastProducts, with: adjusted)
        case .lunch:     appendOrUpdate(&lunchProducts,    with: adjusted)
        case .dinner:    appendOrUpdate(&dinnerProducts,   with: adjusted)
        case .snacks:    appendOrUpdate(&snacksProducts,   with: adjusted)
        }

        let entry = FoodEntry(
            date:      selectedDate,
            mealType:  meal.rawValue,
            product:   adjusted,
            portion:   portion,
            gender:    gender,
            isFavorite: product.isFavorite
        )
        do {
            modelContext.insert(entry)
            try modelContext.save()
            onMealAdded()
            activeMeal = nil 
        } catch {
            print("Ошибка при сохранении продукта: \(error)")
        }
    }

    private func appendOrUpdate(_ array: inout [Product], with newP: Product) {
        if let idx = array.firstIndex(where: { $0.name == newP.name }) {
            array[idx].protein  += newP.protein
            array[idx].fat      += newP.fat
            array[idx].carbs    += newP.carbs
            array[idx].calories += newP.calories
        } else {
            array.append(newP)
        }
    }

    private func calculateCalories(for product: Product) -> Int {
        let p = Double(portionSize) ?? 100
        return Int(Double(product.calories) * p / 100)
    }
}


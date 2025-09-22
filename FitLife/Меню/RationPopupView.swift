//HStack(spacing: 20) {
//    Text("Б: \(String(format: "%.1f", macros.protein)) г")
//    Text("Ж: \(String(format: "%.1f", macros.fat)) г")
//    Text("У: \(String(format: "%.1f", macros.carbs)) г")
//}

//VStack(alignment: .leading, spacing: 4) {
//    Text(entry.product.name)
//        .font(.headline)
//    Text("Калории: \(entry.product.calories) ккал, " +
//         "Б: \(String(format: "%.1f", entry.product.protein)) г, " +
//         "Ж: \(String(format: "%.1f", entry.product.fat)) г, " +
//         "У: \(String(format: "%.1f", entry.product.carbs)) г")
//        .font(.caption)
//        .foregroundColor(.secondary)
//}

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
    // MARK: — Храним записи FoodEntry
    @State private var breakfastEntries: [FoodEntry] = []
    @State private var lunchEntries:    [FoodEntry] = []
    @State private var dinnerEntries:   [FoodEntry] = []
    @State private var snacksEntries:   [FoodEntry] = []

    // MARK: — Состояние
    @State private var selectedMeal: MealType? = nil
    @State private var selectedProduct: Product? = nil
    @State private var showProductDetails = false
    @State private var portionSize: String = "100"
    @State private var activeMeal: MealType? = nil

    // MARK: — Параметры
    @Binding var selectedDate: Date
    let selectedGender: Gender
    let onMealAdded: () -> Void
    let preselectedMeal: MealType?

    // MARK: — Окружение
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    init(
        breakfastProducts: [Product] = [],
        lunchProducts:    [Product] = [],
        dinnerProducts:   [Product] = [],
        snacksProducts:   [Product] = [],
        gender:           Gender,
        selectedDate:     Binding<Date>,
        onMealAdded:      @escaping () -> Void,
        preselectedMeal: MealType? = nil
    ) {
        self._selectedDate  = selectedDate
        self.selectedGender = gender
        self.onMealAdded    = onMealAdded
        self.preselectedMeal = preselectedMeal
        self._selectedMeal = State(initialValue: preselectedMeal) // авто-старт списка
    }

    var body: some View {
        ZStack {
            if preselectedMeal == nil {
            // Основной контент (не рисуем при быстром запуске)
            mainContent
                // Прячем, когда открыт список продуктов ИЛИ открыт оверлей граммов
                .opacity((selectedMeal == nil && !showProductDetails) ? 1 : 0)
                .allowsHitTesting(selectedMeal == nil && !showProductDetails)
                .padding() // пернесли padding сюда, чтобы он касался только mainContent
        }
            // Список продуктов как часть ЭТОГО ЖЕ листа
            if let meal = selectedMeal {
                ProductSelectionView(
                    mealType: meal,
                    date: selectedDate,
                    onProductSelected: { product in
                        selectedProduct = product
                        activeMeal = meal
                        withAnimation {
                            showProductDetails = true
                            portionSize = "100"
                        }
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
                        selectedProduct = generic
                        activeMeal = meal
                        withAnimation {
                            showProductDetails = true
                            portionSize = "100"
                        }
                    },
                    onClose: {
                        // Если открыто в «быстром» режиме — закрываем весь лист, иначе сворачиваем список
                        if preselectedMeal != nil { dismiss() } else { selectedMeal = nil }
                    }
                )
                .opacity(showProductDetails ? 0.2 : 1)          // слегка затемняем под оверлеем
                .allowsHitTesting(!showProductDetails)          // блокируем клики по списку под оверлеем
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(0)
            }

            // Полупрозрачный фон под карточкой граммов
            if showProductDetails {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(1)
                    .onTapGesture {
                        withAnimation {
                            showProductDetails = false
                            activeMeal = nil
                            selectedProduct = nil
                        }
                    }
            }

            // Оверлей граммов
            if showProductDetails, let prod = selectedProduct {
                gramsContent(prod)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }
        }
  //      .padding()
        .presentationDetents([.large])
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: showProductDetails)
        .onAppear { loadData(for: selectedDate, gender: selectedGender) }
        .onChange(of: selectedDate) { _ in loadData(for: selectedDate, gender: selectedGender) }
    }

    // MARK: — Основной контент
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 16) {
            Text("Рацион на день").font(.title2).fontWeight(.bold)

            VStack {
                Text("Итого за день:").font(.headline)
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

            List {
                mealSection(.breakfast, entries: breakfastEntries)
                mealSection(.lunch,     entries: lunchEntries)
                mealSection(.dinner,    entries: dinnerEntries)
                mealSection(.snacks,    entries: snacksEntries)
            }
            .listStyle(.insetGrouped)

            Spacer(minLength: 8)

            Button("OK") { dismiss() }
                .font(.headline)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
    }

    // MARK: — Секция приёма пищи
    @ViewBuilder
    private func mealSection(_ meal: MealType, entries: [FoodEntry]) -> some View {
        Section {
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.product.name)
                        .font(.headline)
                    Text("Калории: \(entry.product.calories) ккал, " +
                         "Б: \(String(format: "%.1f", entry.product.protein)) г, " +
                         "Ж: \(String(format: "%.1f", entry.product.fat)) г, " +
                         "У: \(String(format: "%.1f", entry.product.carbs)) г")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        deleteEntry(entry, for: meal)
                    } label: { Label("Удалить", systemImage: "trash") }
                }
            }
        } header: {
            HStack {
                Text(meal.displayName)
                Spacer()
                Text("\(entries.reduce(0) { $0 + $1.product.calories }) ккал")
                    .foregroundColor(.blue)
                Button("+ добавить еду") { selectedMeal = meal }
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
    }

    // MARK: — Оверлей ввода граммов
    @ViewBuilder
    private func gramsContent(_ prod: Product) -> some View {
        VStack(spacing: 16) {
            Text(prod.name).font(.headline)

            Text("Энергия, ккал")
            Text("\(calculateCalories(for: prod)) ккал").font(.largeTitle)

            let macros = calculateMacros(for: prod)
            HStack(spacing: 20) {
                Text("Б: \(String(format: "%.1f", macros.protein)) г")
                Text("Ж: \(String(format: "%.1f", macros.fat)) г")
                Text("У: \(String(format: "%.1f", macros.carbs)) г")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            TextField("Порция, г", text: $portionSize)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .onChange(of: portionSize) { portionSize = portionSize.filter { $0.isNumber } }

            Text("Порция в граммах").padding(.bottom, 8)

            HStack(spacing: 16) {
                Button("Добавить") {
                    if let p = Double(portionSize) {
                        addGenericProductToMeal(prod, portion: p, gender: selectedGender)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)

                Button("Отмена") {
                    withAnimation {
                        showProductDetails = false
                        activeMeal = nil
                        selectedProduct = nil
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))   // непрозрачный фон карточки
        )
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: — Подсчёты
    private var totalCalories: Int {
        [breakfastEntries, lunchEntries, dinnerEntries, snacksEntries]
            .flatMap { $0 }
            .reduce(0) { $0 + $1.product.calories }
    }
    private var totalProteins: Int {
        [breakfastEntries, lunchEntries, dinnerEntries, snacksEntries]
            .flatMap { $0 }
            .reduce(0) { $0 + Int($1.product.protein) }
    }
    private var totalFats: Int {
        [breakfastEntries, lunchEntries, dinnerEntries, snacksEntries]
            .flatMap { $0 }
            .reduce(0) { $0 + Int($1.product.fat) }
    }
    private var totalCarbs: Int {
        [breakfastEntries, lunchEntries, dinnerEntries, snacksEntries]
            .flatMap { $0 }
            .reduce(0) { $0 + Int($1.product.carbs) }
    }

    private func calculateMacros(for product: Product) -> (protein: Double, fat: Double, carbs: Double) {
        let portion = Double(portionSize) ?? 100
        let factor = portion / 100
        return (product.protein * factor, product.fat * factor, product.carbs * factor)
    }

    private func calculateCalories(for product: Product) -> Int {
        let p = Double(portionSize) ?? 100
        return Int(Double(product.calories) * p / 100)
    }

    // MARK: — Загрузка из SwiftData
    private func loadData(for date: Date, gender: Gender) {
        let req = FetchDescriptor<FoodEntry>()
        do {
            let all = try modelContext.fetch(req).filter {
                Calendar.current.isDate($0.date, inSameDayAs: date) && $0.gender == gender
            }
            breakfastEntries = all.filter { $0.mealType == MealType.breakfast.rawValue }
            lunchEntries     = all.filter { $0.mealType == MealType.lunch.rawValue }
            dinnerEntries    = all.filter { $0.mealType == MealType.dinner.rawValue }
            snacksEntries    = all.filter { $0.mealType == MealType.snacks.rawValue }
        } catch {
            print("Ошибка загрузки данных: \(error)")
        }
    }

    // MARK: — Добавление
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

            switch meal {
            case .breakfast: breakfastEntries.append(entry)
            case .lunch:     lunchEntries.append(entry)
            case .dinner:    dinnerEntries.append(entry)
            case .snacks:    snacksEntries.append(entry)
            }

            onMealAdded()
            activeMeal = nil
            withAnimation { showProductDetails = false }
        } catch {
            print("Ошибка при сохранении продукта: \(error)")
        }
    }

    // MARK: — Удаление
    private func deleteEntry(_ entry: FoodEntry, for meal: MealType) {
        modelContext.delete(entry)
        do {
            try modelContext.save()
            switch meal {
            case .breakfast: breakfastEntries.removeAll { $0.id == entry.id }
            case .lunch:     lunchEntries.removeAll     { $0.id == entry.id }
            case .dinner:    dinnerEntries.removeAll    { $0.id == entry.id }
            case .snacks:    snacksEntries.removeAll    { $0.id == entry.id }
            }
            onMealAdded()
        } catch {
            print("Ошибка удаления: \(error)")
        }
    }
}

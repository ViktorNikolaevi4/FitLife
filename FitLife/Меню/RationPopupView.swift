
import SwiftUI
import SwiftData

private let maxFoodPortionGrams = 10_000.0

// MARK: — Тип приёма пищи
enum MealType: String, CaseIterable, Identifiable {
    case breakfast = "Завтрак"
    case lunch     = "Обед"
    case dinner    = "Ужин"
    case snacks    = "Перекусы"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .breakfast:
            return AppLocalizer.string("meal.breakfast")
        case .lunch:
            return AppLocalizer.string("meal.lunch")
        case .dinner:
            return AppLocalizer.string("meal.dinner")
        case .snacks:
            return AppLocalizer.string("meal.snacks")
        }
    }
}

private struct RationMacroCard: View {
    let title: String
    let current: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption2.weight(.semibold))
            Text(AppLocalizer.format("unit.grams.value", current))
                .font(.caption.weight(.semibold))
            ThickProgressBar(
                fraction: current > 0 ? 1 : 0,
                fill: tint,
                track: tint.opacity(0.16),
                height: 4
            )
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
    }
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
    @State private var selectedCustomProduct: CustomProduct? = nil
    @State private var showProductDetails = false
    @State private var portionSize: String = "100"
    @State private var activeMeal: MealType? = nil
    @State private var expandedMeals: Set<MealType> = []

    // MARK: — Параметры
    @Binding var selectedDate: Date
    let selectedGender: Gender
    let onMealAdded: () -> Void
    let preselectedMeal: MealType?

    // MARK: — Окружение
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var sessionStore: AppSessionStore

    private var theme: AppTheme { AppTheme(colorScheme) }

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
                    selectedGender: selectedGender,
                    onProductSelected: { product in
                        selectedProduct = product
                        selectedCustomProduct = nil
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
                        selectedCustomProduct = custom
                        activeMeal = meal
                        withAnimation {
                            showProductDetails = true
                            portionSize = "100"
                        }
                    },
                    onRecognizedMealSaved: {
                        loadData(for: selectedDate, gender: selectedGender)
                        onMealAdded()
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
                            selectedCustomProduct = nil
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
        .onChange(of: selectedDate) { _, newDate in loadData(for: newDate, gender: selectedGender) }
        .overlay(alignment: .topTrailing) {
            if preselectedMeal == nil && selectedMeal == nil && !showProductDetails {
                Button(AppLocalizer.string("common.close")) { dismiss() }
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .padding(.trailing, 16)
                    .accessibilityLabel(AppLocalizer.string("common.close"))
            }
        }
    }

    // MARK: — Основной контент
    @ViewBuilder
    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Text(AppLocalizer.string("ration.day_title"))
                    .font(.title2.weight(.bold))

                rationSummaryCard

                VStack(spacing: 12) {
                    mealBlock(.breakfast, entries: breakfastEntries, systemImage: "sunrise.fill", badgeFill: .pinkovo)
                    mealBlock(.lunch, entries: lunchEntries, systemImage: "fork.knife", badgeFill: .zeleneko)
                    mealBlock(.dinner, entries: dinnerEntries, systemImage: "moon.stars.fill", badgeFill: .sinenko)
                    mealBlock(.snacks, entries: snacksEntries, systemImage: "takeoutbag.and.cup.and.straw.fill", badgeFill: .zheltenko)
                }
            }
            .padding(.bottom, 20)
        }
    }

    private var rationSummaryCard: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text(totalCalories.formatted(.number.grouping(.automatic)))
                    .font(.system(size: 32, weight: .bold))
                Text(AppLocalizer.string("nutrition.calories"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                RationMacroCard(
                    title: AppLocalizer.string("macro.protein"),
                    current: totalProteins,
                    tint: theme.protein
                )
                RationMacroCard(
                    title: AppLocalizer.string("macro.fat"),
                    current: totalFats,
                    tint: theme.fat
                )
                RationMacroCard(
                    title: AppLocalizer.string("macro.carbs"),
                    current: totalCarbs,
                    tint: theme.carb
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 24).fill(theme.card))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(theme.border))
    }

    private func isExpanded(_ meal: MealType) -> Bool {
        expandedMeals.contains(meal)
    }

    private func toggleMeal(_ meal: MealType) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedMeals.contains(meal) {
                expandedMeals.remove(meal)
            } else {
                expandedMeals.insert(meal)
            }
        }
    }

    @ViewBuilder
    private func mealBlock(_ meal: MealType, entries: [FoodEntry], systemImage: String, badgeFill: Color) -> some View {
        let kcal = entries.reduce(0) { $0 + ($1.product?.calories ?? 0) }
        let protein = Int(entries.reduce(0.0) { $0 + ($1.product?.protein ?? 0) })
        let fat = Int(entries.reduce(0.0) { $0 + ($1.product?.fat ?? 0) })
        let carb = Int(entries.reduce(0.0) { $0 + ($1.product?.carbs ?? 0) })

        MealRow(
            title: meal == .snacks ? AppLocalizer.string("meal.snack") : meal.displayName,
            systemImage: systemImage,
            kcal: kcal > 0 ? kcal : nil,
            macros: kcal > 0 ? (protein: protein, fat: fat, carb: carb) : nil,
            theme: theme,
            badgeFill: badgeFill,
            showChevron: !entries.isEmpty,
            chevronExpanded: isExpanded(meal),
            onChevronTap: { toggleMeal(meal) }
        )
        .contentShape(Rectangle())
        .onTapGesture { selectedMeal = meal }

        if !entries.isEmpty && isExpanded(meal) {
            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.product?.name ?? "—")
                            .font(.subheadline.weight(.semibold))

                        HStack(spacing: 8) {
                            if entry.portion > 0 {
                                Text(AppLocalizer.format("unit.grams.value", Int(entry.portion)))
                            }
                            Text(AppLocalizer.format("unit.kcal.value", entry.product?.calories ?? 0))
                            Text(
                                AppLocalizer.format(
                                    "meal.macros.summary",
                                    Int(entry.product?.protein ?? 0),
                                    Int(entry.product?.fat ?? 0),
                                    Int(entry.product?.carbs ?? 0)
                                )
                            )
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) { Divider().opacity(0.35) }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteEntry(entry, for: meal)
                        } label: {
                            Label(AppLocalizer.string("common.delete"), systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.leading, 52)
            .padding(.trailing, 2)
        }
    }

    // MARK: — Оверлей ввода граммов
    @ViewBuilder
    private func gramsContent(_ prod: Product) -> some View {
        VStack(spacing: 16) {
            Text(prod.name).font(.headline)

            Text(AppLocalizer.string("macros.energy"))
            Text(AppLocalizer.format("unit.kcal.value", calculateCalories(for: prod))).font(.largeTitle)

            let macros = calculateMacros(for: prod)
            HStack(spacing: 20) {
                Text(AppLocalizer.format("macro.protein.value", String(format: "%.1f", macros.protein)))
                Text(AppLocalizer.format("macro.fat.value", String(format: "%.1f", macros.fat)))
                Text(AppLocalizer.format("macro.carbs.value", String(format: "%.1f", macros.carbs)))
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            TextField(AppLocalizer.string("portion.grams"), text: $portionSize)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .onChange(of: portionSize) { portionSize = sanitizedPortionText($0) }

            Text(AppLocalizer.string("portion.in_grams")).padding(.bottom, 8)

            HStack(spacing: 16) {
                Button(AppLocalizer.string("common.add")) {
                    addGenericProductToMeal(prod, portion: currentPortionValue, gender: selectedGender)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)

                Button(AppLocalizer.string("common.cancel")) {
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
            .reduce(0) { $0 + ( $1.product?.calories ?? 0 ) }
    }

    private var totalProteins: Int {
        [breakfastEntries, lunchEntries, dinnerEntries, snacksEntries]
            .flatMap { $0 }
            .reduce(0) { $0 + Int(max(($1.product?.protein ?? 0).safeFinite, 0)) }
    }

    private var totalFats: Int {
        [breakfastEntries, lunchEntries, dinnerEntries, snacksEntries]
            .flatMap { $0 }
            .reduce(0) { $0 + Int(max(($1.product?.fat ?? 0).safeFinite, 0)) }
    }

    private var totalCarbs: Int {
        [breakfastEntries, lunchEntries, dinnerEntries, snacksEntries]
            .flatMap { $0 }
            .reduce(0) { $0 + Int(max(($1.product?.carbs ?? 0).safeFinite, 0)) }
    }

    private func calculateMacros(for product: Product) -> (protein: Double, fat: Double, carbs: Double) {
        let portion = currentPortionValue
        let factor = (portion / 100).safeFinite
        return (
            max(product.protein.safeFinite * factor, 0),
            max(product.fat.safeFinite * factor, 0),
            max(product.carbs.safeFinite * factor, 0)
        )
    }

    private func calculateCalories(for product: Product) -> Int {
        let p = currentPortionValue
        return max(Int((Double(product.calories).safeFinite * p.safeFinite / 100).rounded()), 0)
    }

    private var currentPortionValue: Double {
        clampedPortion(Double(portionSize) ?? 100)
    }

    private func sanitizedPortionText(_ text: String) -> String {
        let digits = text.filter(\.isNumber)
        guard let value = Double(digits), value > 0 else { return digits }
        return String(Int(clampedPortion(value)))
    }

    private func clampedPortion(_ value: Double) -> Double {
        min(max(value.safeFinite, 1), maxFoodPortionGrams)
    }

    // MARK: — Загрузка из SwiftData
    private func loadData(for date: Date, gender: Gender) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }
        let ownerId = sessionStore.firebaseUser?.uid ?? ""
        let predicate = #Predicate<FoodEntry> {
            $0.date >= dayStart &&
            $0.date < dayEnd &&
            $0.ownerId == ownerId
        }
        let req = FetchDescriptor<FoodEntry>(predicate: predicate)

        do {
            let all = try modelContext.fetch(req).filter { $0.gender == gender }
            breakfastEntries = all.filter { $0.mealType == MealType.breakfast.rawValue }
            lunchEntries     = all.filter { $0.mealType == MealType.lunch.rawValue }
            dinnerEntries    = all.filter { $0.mealType == MealType.dinner.rawValue }
            snacksEntries    = all.filter { $0.mealType == MealType.snacks.rawValue }
        } catch {}
    }

    // MARK: — Добавление
    private func addGenericProductToMeal(_ product: Product, portion: Double, gender: Gender) {
        guard let meal = activeMeal else { return }
        let safePortion = clampedPortion(portion)
        let factor = (safePortion / 100).safeFinite
        let adjusted = Product(
            name:     product.name,
            protein:  max(product.protein.safeFinite * factor, 0),
            fat:      max(product.fat.safeFinite * factor, 0),
            carbs:    max(product.carbs.safeFinite * factor, 0),
            calories: max(Int((Double(product.calories).safeFinite * factor).rounded()), 0),
            isFavorite: product.isFavorite,
            isCustom:   product.isCustom
        )

        let entry = FoodEntry(
            date:      selectedDate,
            mealType:  meal.rawValue,
            product:   adjusted,
            portion:   safePortion,
            gender:    gender,
            ownerId:   sessionStore.firebaseUser?.uid ?? "",
            isFavorite: product.isFavorite,
            customProductID: selectedCustomProduct?.id
        )

        do {
            modelContext.insert(entry)
            try modelContext.save()

            let ownerId = sessionStore.firebaseUser?.uid ?? ""
            if !ownerId.isEmpty {
                Task {
                    await ProductUsageCache.shared.increment(productName: product.name, for: ownerId)
                }
            }

            switch meal {
            case .breakfast: breakfastEntries.append(entry)
            case .lunch:     lunchEntries.append(entry)
            case .dinner:    dinnerEntries.append(entry)
            case .snacks:    snacksEntries.append(entry)
            }

            LocalReminderScheduler.rescheduleMealRemindersIfEnabled(
                modelContext: modelContext,
                ownerId: entry.ownerId,
                gender: gender
            )
            onMealAdded()
            activeMeal = nil
            selectedCustomProduct = nil
            withAnimation { showProductDetails = false }
        } catch {}
    }

    // MARK: — Удаление
    private func deleteEntry(_ entry: FoodEntry, for meal: MealType) {
        let removedProductName = entry.product?.name ?? ""
        modelContext.delete(entry)
        do {
            try modelContext.save()
            switch meal {
            case .breakfast: breakfastEntries.removeAll { $0.id == entry.id }
            case .lunch:     lunchEntries.removeAll     { $0.id == entry.id }
            case .dinner:    dinnerEntries.removeAll    { $0.id == entry.id }
            case .snacks:    snacksEntries.removeAll    { $0.id == entry.id }
            }
            let ownerId = sessionStore.firebaseUser?.uid ?? ""
            if !ownerId.isEmpty && !removedProductName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Task {
                    await ProductUsageCache.shared.decrement(productName: removedProductName, for: ownerId)
                }
            }
            LocalReminderScheduler.rescheduleMealRemindersIfEnabled(
                modelContext: modelContext,
                ownerId: entry.ownerId,
                gender: entry.gender
            )
            onMealAdded()
        } catch {}
    }
}

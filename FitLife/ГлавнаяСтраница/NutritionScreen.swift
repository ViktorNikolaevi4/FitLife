import SwiftUI
import SwiftData

private let nutritionCardBackground = Color(.secondarySystemBackground)
private let nutritionCardBorder = Color(.separator).opacity(0.40)

struct NutritionScreen: View {
    @Binding var selectedDate: Date

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionStore: AppSessionStore
    @Query private var users: [UserData]
    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue
    @Environment(\.colorScheme) private var colorScheme

    @State private var consumedCalories = 0
    @State private var consumedProteins = 0
    @State private var consumedFats = 0
    @State private var consumedCarbs = 0
    @State private var breakfastKcal = 0
    @State private var lunchKcal = 0
    @State private var dinnerKcal = 0
    @State private var snacksKcal = 0
    @State private var breakfastMacros = (protein: 0, fat: 0, carb: 0)
    @State private var lunchMacros = (protein: 0, fat: 0, carb: 0)
    @State private var dinnerMacros = (protein: 0, fat: 0, carb: 0)
    @State private var snacksMacros = (protein: 0, fat: 0, carb: 0)
    @State private var breakfastItems: [FoodEntry] = []
    @State private var lunchItems: [FoodEntry] = []
    @State private var dinnerItems: [FoodEntry] = []
    @State private var snacksItems: [FoodEntry] = []
    @State private var yesterdayBreakfastItems: [FoodEntry] = []
    @State private var yesterdayLunchItems: [FoodEntry] = []
    @State private var yesterdayDinnerItems: [FoodEntry] = []
    @State private var yesterdaySnacksItems: [FoodEntry] = []
    @State private var expandedMeals: Set<MealType> = []
    @State private var sheet: RationSheet? = nil
    @State private var selectedMacroDetail: MacroDetailKind?
    @State private var repeatYesterdayMeal: RepeatYesterdayMealSelection?
    @State private var isShowingAIMealRecognition = false

    private var selectedGender: Gender { Gender(rawValue: activeGenderRaw) ?? .male }
    private var theme: AppTheme { AppTheme(colorScheme) }
    private var nutritionCardShadow: Color { colorScheme == .dark ? .clear : .black.opacity(0.08) }
    private var currentOwnerId: String? { sessionStore.firebaseUser?.uid }
    private var userData: UserData? {
        guard let currentOwnerId else { return nil }
        return users.first(where: { $0.gender == selectedGender && $0.ownerId == currentOwnerId })
    }

    private var progress: Double {
        guard let target = userData?.calories, target > 0 else { return 0 }
        return min(Double(consumedCalories) / Double(target), 1)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text(AppLocalizer.string("nutrition.title"))
                    .font(.largeTitle.bold())
                    .padding(.horizontal)

                caloriesCard

                Button {
                    isShowingAIMealRecognition = true
                } label: {
                    Label(AppLocalizer.string("ai.meal.action"), systemImage: "camera.viewfinder")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                VStack(spacing: 12) {
                    MealsSection(
                        theme: theme,
                        calories: (breakfastKcal, lunchKcal, dinnerKcal, snacksKcal),
                        macros: (breakfastMacros, lunchMacros, dinnerMacros, snacksMacros),
                        entries: (breakfastItems, lunchItems, dinnerItems, snacksItems),
                        yesterdayEntries: (yesterdayBreakfastItems, yesterdayLunchItems, yesterdayDinnerItems, yesterdaySnacksItems),
                        expanded: $expandedMeals,
                        onTapMeal: { meal in sheet = .quick(meal) },
                        onRepeatYesterday: { meal in openRepeatYesterdayEditor(for: meal) },
                        onDeleteEntry: { entry in deleteEntry(entry) },
                        onDeleteEntries: { entries in deleteEntries(entries) },
                        onUpdateEntry: { _ in refreshDerivedState() }
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 16)
        }
        .background(theme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { recalcFor(selectedDate) }
        .onChange(of: selectedDate) { _, newDate in recalcFor(newDate) }
        .onChange(of: activeGenderRaw) { recalcFor(selectedDate) }
        .sheet(item: $sheet) { key in
            let preset: MealType? = { if case let .quick(m) = key { m } else { nil } }()
            RationPopupView(
                gender: selectedGender,
                selectedDate: $selectedDate,
                onMealAdded: { loadEntries(for: selectedDate) },
                preselectedMeal: preset
            )
        }
        .sheet(item: $selectedMacroDetail) { macro in
            MacroNutrientDetailScreen(
                macro: macro,
                entriesByMeal: [
                    .breakfast: breakfastItems,
                    .lunch: lunchItems,
                    .dinner: dinnerItems,
                    .snacks: snacksItems
                ],
                current: macro.currentValue(
                    protein: consumedProteins,
                    fat: consumedFats,
                    carbs: consumedCarbs
                ),
                target: macro.targetValue(
                    protein: userData?.proteins ?? 0,
                    fat: userData?.fats ?? 0,
                    carbs: userData?.carbs ?? 0
                ),
                selectedDate: selectedDate
            )
        }
        .sheet(item: $repeatYesterdayMeal) { selection in
            RepeatYesterdayMealEditorScreen(
                meal: selection.meal,
                sourceEntries: selection.entries,
                onSave: { drafts in
                    saveRepeatedYesterdayMeal(selection.meal, drafts: drafts)
                }
            )
        }
        .sheet(isPresented: $isShowingAIMealRecognition) {
            AIMealRecognitionFlowView(
                selectedDate: selectedDate,
                selectedGender: selectedGender,
                onSaved: { loadEntries(for: selectedDate) }
            )
        }
    }

    private var caloriesCard: some View {
        VStack(spacing: 14) {
            Donut(progress: progress, lineWidth: 12, track: theme.ringTrack, gradient: theme.ringGradient)
                .frame(width: 126, height: 126)
                .overlay {
                    VStack(spacing: 2) {
                        Text(consumedCalories.formatted(.number.grouping(.automatic)))
                            .font(.system(size: 20, weight: .bold))
                        Text(AppLocalizer.format("nutrition.goal.value", userData?.calories ?? 0))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(AppLocalizer.format("nutrition.remaining.value", max((userData?.calories ?? 0) - consumedCalories, 0)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

            HStack(spacing: 8) {
                Button(action: { selectedMacroDetail = .protein }) {
                    NutritionMacroCard(
                        title: AppLocalizer.string("macro.protein"),
                        current: consumedProteins,
                        target: userData?.proteins ?? 0,
                        tint: theme.protein
                    )
                }
                .buttonStyle(.plain)

                Button(action: { selectedMacroDetail = .fat }) {
                    NutritionMacroCard(
                        title: AppLocalizer.string("macro.fat"),
                        current: consumedFats,
                        target: userData?.fats ?? 0,
                        tint: theme.fat
                    )
                }
                .buttonStyle(.plain)

                Button(action: { selectedMacroDetail = .carbs }) {
                    NutritionMacroCard(
                        title: AppLocalizer.string("macro.carbs"),
                        current: consumedCarbs,
                        target: userData?.carbs ?? 0,
                        tint: theme.carb
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 24).fill(theme.card))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(theme.border))
        .shadow(color: nutritionCardShadow, radius: 16, x: 0, y: 6)
        .padding(.horizontal)
    }

    private func recalcFor(_ date: Date) {
        loadEntries(for: date)
        loadYesterdayEntries(for: date)
    }

    private func loadEntries(for date: Date) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            resetState()
            return
        }

        guard let currentOwnerId else {
            resetState()
            return
        }

        let predicate = #Predicate<FoodEntry> {
            $0.date >= dayStart &&
            $0.date < dayEnd &&
            $0.ownerId == currentOwnerId
        }

        do {
            let descriptor = FetchDescriptor<FoodEntry>(predicate: predicate)
            let items = try modelContext.fetch(descriptor).filter { $0.gender == selectedGender }
            apply(snapshot: FoodDaySnapshot.from(entries: items))
        } catch {
            resetState()
        }
    }

    private func deleteEntry(_ entry: FoodEntry) {
        modelContext.delete(entry)
        do { try modelContext.save() } catch {}
        switch MealType(rawValue: entry.mealType) {
        case .breakfast:
            breakfastItems.removeAll { $0.id == entry.id }
        case .lunch:
            lunchItems.removeAll { $0.id == entry.id }
        case .dinner:
            dinnerItems.removeAll { $0.id == entry.id }
        case .snacks:
            snacksItems.removeAll { $0.id == entry.id }
        case nil:
            break
        }

        refreshDerivedState()

        if let meal = MealType(rawValue: entry.mealType) {
            let isEmpty: Bool
            switch meal {
            case .breakfast: isEmpty = breakfastItems.isEmpty
            case .lunch: isEmpty = lunchItems.isEmpty
            case .dinner: isEmpty = dinnerItems.isEmpty
            case .snacks: isEmpty = snacksItems.isEmpty
            }
            if isEmpty { expandedMeals.remove(meal) }
        }
    }

    private func deleteEntries(_ entries: [FoodEntry]) {
        guard !entries.isEmpty else { return }

        for entry in entries {
            modelContext.delete(entry)
            switch MealType(rawValue: entry.mealType) {
            case .breakfast:
                breakfastItems.removeAll { $0.id == entry.id }
            case .lunch:
                lunchItems.removeAll { $0.id == entry.id }
            case .dinner:
                dinnerItems.removeAll { $0.id == entry.id }
            case .snacks:
                snacksItems.removeAll { $0.id == entry.id }
            case nil:
                break
            }
        }

        do { try modelContext.save() } catch {}
        refreshDerivedState()

        for meal in MealType.allCases {
            let isEmpty: Bool
            switch meal {
            case .breakfast: isEmpty = breakfastItems.isEmpty
            case .lunch: isEmpty = lunchItems.isEmpty
            case .dinner: isEmpty = dinnerItems.isEmpty
            case .snacks: isEmpty = snacksItems.isEmpty
            }
            if isEmpty {
                expandedMeals.remove(meal)
            }
        }
    }

    private func refreshDerivedState() {
        apply(snapshot: FoodDaySnapshot.from(entries: breakfastItems + lunchItems + dinnerItems + snacksItems))
    }

    private func apply(snapshot: FoodDaySnapshot) {
        breakfastItems = snapshot.breakfast
        lunchItems = snapshot.lunch
        dinnerItems = snapshot.dinner
        snacksItems = snapshot.snacks

        let calories = snapshot.mealCalories
        breakfastKcal = calories.breakfast
        lunchKcal = calories.lunch
        dinnerKcal = calories.dinner
        snacksKcal = calories.snacks

        let macros = snapshot.mealMacros
        breakfastMacros = macros.breakfast
        lunchMacros = macros.lunch
        dinnerMacros = macros.dinner
        snacksMacros = macros.snacks

        consumedCalories = snapshot.totalCalories
        let totalMacros = snapshot.totalMacros
        consumedProteins = totalMacros.protein
        consumedFats = totalMacros.fat
        consumedCarbs = totalMacros.carb
    }

    private func resetState() {
        apply(snapshot: FoodDaySnapshot.from(entries: []))
    }

    private func loadYesterdayEntries(for date: Date) {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date) else {
            applyYesterday(snapshot: FoodDaySnapshot.from(entries: []))
            return
        }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: yesterday)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart),
              let currentOwnerId else {
            applyYesterday(snapshot: FoodDaySnapshot.from(entries: []))
            return
        }

        let predicate = #Predicate<FoodEntry> {
            $0.date >= dayStart &&
            $0.date < dayEnd &&
            $0.ownerId == currentOwnerId
        }

        do {
            let descriptor = FetchDescriptor<FoodEntry>(predicate: predicate)
            let items = try modelContext.fetch(descriptor).filter { $0.gender == selectedGender }
            applyYesterday(snapshot: FoodDaySnapshot.from(entries: items))
        } catch {
            applyYesterday(snapshot: FoodDaySnapshot.from(entries: []))
        }
    }

    private func applyYesterday(snapshot: FoodDaySnapshot) {
        yesterdayBreakfastItems = snapshot.breakfast
        yesterdayLunchItems = snapshot.lunch
        yesterdayDinnerItems = snapshot.dinner
        yesterdaySnacksItems = snapshot.snacks
    }

    private func openRepeatYesterdayEditor(for meal: MealType) {
        let entries: [FoodEntry]
        switch meal {
        case .breakfast:
            entries = yesterdayBreakfastItems
        case .lunch:
            entries = yesterdayLunchItems
        case .dinner:
            entries = yesterdayDinnerItems
        case .snacks:
            entries = []
        }

        guard !entries.isEmpty else { return }
        repeatYesterdayMeal = RepeatYesterdayMealSelection(meal: meal, entries: entries)
    }

    private func saveRepeatedYesterdayMeal(_ meal: MealType, drafts: [RepeatYesterdayMealDraftItem]) {
        guard !drafts.isEmpty else { return }

        var copiedEntries: [FoodEntry] = []
        var copiedGroupIDs: [String: String] = [:]

        for draft in drafts {
            guard let sourceProduct = draft.sourceEntry.product else { continue }
            let sourcePortion = max(1.0, draft.sourceEntry.portion)
            let scale = draft.grams / sourcePortion
            let copiedProduct = Product(
                name: sourceProduct.name,
                nameEN: sourceProduct.nameEN,
                protein: sourceProduct.protein * scale,
                fat: sourceProduct.fat * scale,
                carbs: sourceProduct.carbs * scale,
                calories: Int((Double(sourceProduct.calories) * scale).rounded()),
                isFavorite: sourceProduct.isFavorite,
                isCustom: sourceProduct.isCustom,
                barcode: sourceProduct.barcode,
                source: sourceProduct.source
            )

            let copiedGroupID: String?
            if let sourceGroupID = draft.sourceEntry.aiMealGroupID, !sourceGroupID.isEmpty {
                copiedGroupID = copiedGroupIDs[sourceGroupID, default: UUID().uuidString]
            } else {
                copiedGroupID = nil
            }

            if let sourceGroupID = draft.sourceEntry.aiMealGroupID, let copiedGroupID {
                copiedGroupIDs[sourceGroupID] = copiedGroupID
            }

            let copiedEntry = FoodEntry(
                date: selectedDate,
                mealType: meal.rawValue,
                product: copiedProduct,
                portion: draft.grams,
                gender: selectedGender,
                ownerId: currentOwnerId ?? "",
                isFavorite: draft.sourceEntry.isFavorite,
                aiMealGroupID: copiedGroupID,
                aiMealName: draft.sourceEntry.aiMealName,
                customProductID: draft.sourceEntry.customProductID
            )

            modelContext.insert(copiedEntry)
            copiedEntries.append(copiedEntry)
        }

        do {
            try modelContext.save()
            switch meal {
            case .breakfast:
                breakfastItems.append(contentsOf: copiedEntries)
            case .lunch:
                lunchItems.append(contentsOf: copiedEntries)
            case .dinner:
                dinnerItems.append(contentsOf: copiedEntries)
            case .snacks:
                snacksItems.append(contentsOf: copiedEntries)
            }
            expandedMeals.insert(meal)
            refreshDerivedState()
            LocalReminderScheduler.rescheduleMealRemindersIfEnabled(
                modelContext: modelContext,
                ownerId: currentOwnerId ?? "",
                gender: selectedGender
            )
        } catch {}
    }
}

struct RepeatYesterdayMealSelection: Identifiable {
    let id = UUID()
    let meal: MealType
    let entries: [FoodEntry]
}

private struct NutritionMacroCard: View {
    let title: String
    let current: Int
    let target: Int
    let tint: Color

    private var fraction: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1)
    }

    private var isOverTarget: Bool {
        target > 0 && current > target
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption2.weight(.semibold))

                if isOverTarget {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                        .accessibilityLabel(AppLocalizer.string("nutrition.macro.over_target"))
                }
            }
            Text(AppLocalizer.format("nutrition.macro.value", current, target))
                .font(.caption.weight(.semibold))
                .foregroundStyle(isOverTarget ? .red : .primary)
            ThickProgressBar(
                fraction: fraction,
                fill: isOverTarget ? .red : tint,
                track: (isOverTarget ? Color.red : tint).opacity(0.16),
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

enum MacroDetailKind: String, Identifiable {
    case protein
    case fat
    case carbs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .protein:
            return AppLocalizer.string("macro.protein")
        case .fat:
            return AppLocalizer.string("macro.fat")
        case .carbs:
            return AppLocalizer.string("macro.carbs")
        }
    }

    func tint(theme: AppTheme) -> Color {
        switch self {
        case .protein:
            return theme.protein
        case .fat:
            return theme.fat
        case .carbs:
            return theme.carb
        }
    }

    func value(for entry: FoodEntry) -> Double {
        switch self {
        case .protein:
            return entry.proteinSafe
        case .fat:
            return entry.fatSafe
        case .carbs:
            return entry.carbsSafe
        }
    }

    func currentValue(protein: Int, fat: Int, carbs: Int) -> Int {
        switch self {
        case .protein: return protein
        case .fat: return fat
        case .carbs: return carbs
        }
    }

    func targetValue(protein: Int, fat: Int, carbs: Int) -> Int {
        switch self {
        case .protein: return protein
        case .fat: return fat
        case .carbs: return carbs
        }
    }
}

struct MacroNutrientDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let macro: MacroDetailKind
    let entriesByMeal: [MealType: [FoodEntry]]
    let current: Int
    let target: Int
    let selectedDate: Date

    private var theme: AppTheme { AppTheme(colorScheme) }
    private var nutritionCardShadow: Color { colorScheme == .dark ? .clear : .black.opacity(0.08) }

    private var filteredMeals: [(MealType, [FoodEntry])] {
        MealType.allCases.compactMap { meal in
            let entries = (entriesByMeal[meal] ?? []).filter { displayedMacroValue(for: $0) > 0 }
            return entries.isEmpty ? nil : (meal, entries)
        }
    }

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1)
    }

    private var statusText: String {
        let delta = target - current
        if delta >= 0 {
            return AppLocalizer.format("nutrition.macro.detail.remaining", delta)
        }
        return AppLocalizer.format("nutrition.macro.detail.exceeded", abs(delta))
    }

    private var statusColor: Color {
        current > target && target > 0 ? .red : macro.tint(theme: theme)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        return formatter.string(from: selectedDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard

                    if filteredMeals.isEmpty {
                        ContentUnavailableView(
                            AppLocalizer.string("nutrition.macro.detail.empty.title"),
                            systemImage: "fork.knife.circle",
                            description: Text(AppLocalizer.string("nutrition.macro.detail.empty.subtitle"))
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                    } else {
                        ForEach(filteredMeals, id: \.0) { meal, entries in
                            mealSection(meal: meal, entries: entries)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(macro.title)
                        .font(.headline.weight(.semibold))
                }
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(macro.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text("\(current) / \(target) \(AppLocalizer.string("unit.grams.short"))")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Text(statusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statusColor)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(macro.tint(theme: theme).opacity(0.18), lineWidth: 9)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        macro.tint(theme: theme),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 58, height: 58)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24).fill(nutritionCardBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(macro.tint(theme: theme).opacity(0.18))
        )
        .shadow(color: nutritionCardShadow, radius: 16, x: 0, y: 6)
    }

    private func mealSection(meal: MealType, entries: [FoodEntry]) -> some View {
        let total = Int(entries.reduce(0.0) { $0 + macro.value(for: $1) })

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(meal.displayName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(total) \(AppLocalizer.string("unit.grams.short"))")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(macro.tint(theme: theme))
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(entries, id: \.id) { entry in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(macro.tint(theme: theme).opacity(0.7))
                            .frame(width: 6, height: 6)

                        Text(entry.product?.name ?? AppLocalizer.string("common.zero"))
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer()

                        Text("\(displayedMacroValue(for: entry)) \(AppLocalizer.string("unit.grams.short"))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 20).fill(nutritionCardBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(nutritionCardBorder)
            )
            .shadow(color: nutritionCardShadow.opacity(0.9), radius: 12, x: 0, y: 4)
        }
    }

    private func displayedMacroValue(for entry: FoodEntry) -> Int {
        Int(macro.value(for: entry))
    }
}

import SwiftUI
import SwiftData

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
    @State private var expandedMeals: Set<MealType> = []
    @State private var sheet: RationSheet? = nil

    private var selectedGender: Gender { Gender(rawValue: activeGenderRaw) ?? .male }
    private var theme: AppTheme { AppTheme(colorScheme) }
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

                VStack(spacing: 12) {
                    MealsSection(
                        theme: theme,
                        calories: (breakfastKcal, lunchKcal, dinnerKcal, snacksKcal),
                        macros: (breakfastMacros, lunchMacros, dinnerMacros, snacksMacros),
                        entries: (breakfastItems, lunchItems, dinnerItems, snacksItems),
                        expanded: $expandedMeals,
                        onTapMeal: { meal in sheet = .quick(meal) },
                        onDeleteEntry: { entry in deleteEntry(entry) },
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
                NutritionMacroCard(
                    title: AppLocalizer.string("macro.protein"),
                    current: consumedProteins,
                    target: userData?.proteins ?? 0,
                    tint: theme.protein
                )
                NutritionMacroCard(
                    title: AppLocalizer.string("macro.fat"),
                    current: consumedFats,
                    target: userData?.fats ?? 0,
                    tint: theme.fat
                )
                NutritionMacroCard(
                    title: AppLocalizer.string("macro.carbs"),
                    current: consumedCarbs,
                    target: userData?.carbs ?? 0,
                    tint: theme.carb
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 24).fill(theme.card))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(theme.border))
        .padding(.horizontal)
    }

    private func recalcFor(_ date: Date) {
        loadEntries(for: date)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption2.weight(.semibold))
            Text(AppLocalizer.format("nutrition.macro.value", current, target))
                .font(.caption.weight(.semibold))
            ThickProgressBar(
                fraction: fraction,
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

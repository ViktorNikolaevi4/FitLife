import SwiftUI
import SwiftData

struct DashboardScreen: View {
    // Дата
    @Binding var selectedDate: Date
    @Binding var showsFloatingAddButton: Bool
    let onOpenWorkouts: () -> Void

    // Данные
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionStore: AppSessionStore
    @Query private var users: [UserData]

    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue
    @AppStorage(WaterPortionPreference.appStorageKey) private var waterQuickAddML: Int = WaterPortionPreference.defaultML
    private var selectedGender: Gender { Gender(rawValue: activeGenderRaw) ?? .male }

    @Environment(\.colorScheme) private var colorScheme

    // Итоги дня
    @State private var dailyConsumedCalories = 0
    @State private var consumedProteins = 0
    @State private var consumedFats = 0
    @State private var consumedCarbs = 0
    @State private var waterIntake = 0.0

    // Калории по приемам
    @State private var breakfastKcal = 0
    @State private var lunchKcal = 0
    @State private var dinnerKcal = 0
    @State private var snacksKcal = 0

    // Макросы по приемам
    @State private var breakfastMacros = (protein: 0, fat: 0, carb: 0)
    @State private var lunchMacros     = (protein: 0, fat: 0, carb: 0)
    @State private var dinnerMacros    = (protein: 0, fat: 0, carb: 0)
    @State private var snacksMacros    = (protein: 0, fat: 0, carb: 0)

    // Шиты / календарь
    @State private var sheet: RationSheet? = nil
    @State private var showCalendar = false

    // Состояние разворота
    @State private var expandedMeals: Set<MealType> = []
    @State private var selectedMacroDetail: MacroDetailKind?

    // Элементы по приёмам
    @State private var breakfastItems: [FoodEntry] = []
    @State private var lunchItems: [FoodEntry] = []
    @State private var dinnerItems: [FoodEntry] = []
    @State private var snacksItems: [FoodEntry] = []

    private var userData: UserData? {
        guard let currentOwnerId = sessionStore.firebaseUser?.uid else { return nil }
        return users.first(where: { $0.gender == selectedGender && $0.ownerId == currentOwnerId })
    }

    init(selectedDate: Binding<Date>, showsFloatingAddButton: Binding<Bool>, onOpenWorkouts: @escaping () -> Void) {
        _selectedDate = selectedDate
        _showsFloatingAddButton = showsFloatingAddButton
        self.onOpenWorkouts = onOpenWorkouts
    }

    var body: some View {
        let theme = AppTheme(colorScheme)

        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header(theme)

                    if let user = userData {
                        BalanceCard(
                            consumed: dailyConsumedCalories,
                            target: user.calories,
                            proteins: (consumedProteins, user.proteins),
                            fats:     (consumedFats,     user.fats),
                            carbs:    (consumedCarbs,    user.carbs),
                            theme: theme,
                            onTapProtein: { selectedMacroDetail = .protein },
                            onTapFat: { selectedMacroDetail = .fat },
                            onTapCarbs: { selectedMacroDetail = .carbs }
                        )

                        WaterSummaryCard(
                            intake: waterIntake,
                            goal: dailyWaterGoal(for: user),
                            quickAddML: waterQuickAddML,
                            theme: theme,
                            onSubtract: { subtractWater(amount: Double(waterQuickAddML) / 1000.0) },
                            onAdd: { addWater(amount: Double(waterQuickAddML) / 1000.0) }
                        )

                        TrainingDiaryCard(
                            theme: theme,
                            title: AppLocalizer.string("training.diary"),
                            onOpen: onOpenWorkouts
                        )
                    } else {
                        ContentUnavailableView(
                            AppLocalizer.string("dashboard.no_user_data"),
                            systemImage: "person.crop.circle.badge.questionmark",
                            description: Text(AppLocalizer.string("dashboard.profile_auto_created"))
                        )
                        .frame(maxWidth: .infinity, minHeight: 280)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(theme.bg.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .onAppear { ensureUserIfNeeded(); recalcFor(selectedDate) }
        .onChange(of: selectedDate) { _, newDate in
            recalcFor(newDate)
            loadWaterIntake(for: newDate)
        }
        .onChange(of: activeGenderRaw) {
            recalcFor(selectedDate)
            loadWaterIntake(for: selectedDate)
        }
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
            if let user = userData {
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
                        protein: user.proteins,
                        fat: user.fats,
                        carbs: user.carbs
                    ),
                    selectedDate: selectedDate
                )
            }
        }
        .sheet(isPresented: $showCalendar) {
            NavigationStack {
                VStack {
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .environment(\.locale, AppLocalizer.currentLanguage.locale)
                }
                .padding()
                .navigationTitle(AppLocalizer.string("common.select_date"))
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(AppLocalizer.string("common.today")) { selectedDate = Date(); showCalendar = false }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(AppLocalizer.string("common.done")) { showCalendar = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: Header

    private func header(_ theme: AppTheme) -> some View {
        return HStack(alignment: .center) {
            Button { showCalendar = true } label: {
                HStack(spacing: 8) {
                    Text(formattedToday(selectedDate))
                        .font(.largeTitle).fontWeight(.bold)
                        .lineLimit(1).minimumScaleFactor(0.8)

                    Image(systemName: "chevron.down")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            NavigationLink(destination: SettingsScreenContainer(showsFloatingAddButton: $showsFloatingAddButton)) {
                ZStack {
                    Circle()
                        .fill(theme.card)
                        .frame(width: 40, height: 40)

                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
            .simultaneousGesture(TapGesture().onEnded {
                showsFloatingAddButton = false
            })
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }


    private func formattedToday(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = AppLocalizer.currentLanguage.locale
        df.setLocalizedDateFormatFromTemplate("d MMMM")
        return df.string(from: date)
    }

    // MARK: Data

    private func ensureUserIfNeeded() {
        if userData == nil {
            let newUser = UserData(
                weight: 0, height: 0, age: 0,
                ownerId: sessionStore.firebaseUser?.uid ?? "",
                activityLevel: .none, goal: .currentWeight,
                gender: selectedGender
            )
            modelContext.insert(newUser)
            try? modelContext.save()
        }
        loadWaterIntake(for: selectedDate)
    }

    private func recalcFor(_ date: Date) {
        loadEntries(for: date)
    }

    private func loadEntries(for date: Date) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            resetFoodState()
            return
        }

        guard let currentOwnerId = sessionStore.firebaseUser?.uid else {
            resetFoodState()
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
            resetFoodState()
        }
    }

    private func dailyWaterGoal(for user: UserData) -> Double {
        (user.weight * 35) / 1000.0
    }

    private func addWater(amount: Double) {
        waterIntake += amount
        saveWaterIntake(for: selectedDate)
    }

    private func subtractWater(amount: Double) {
        waterIntake = max(0, waterIntake - amount)
        saveWaterIntake(for: selectedDate)
    }

    private func saveWaterIntake(for date: Date) {
        guard let user = userData else { return }
        let day = Calendar.current.startOfDay(for: date)
        do {
            let all = try modelContext.fetch(FetchDescriptor<WaterIntake>())
            if let existing = all.first(where: {
                Calendar.current.isDate($0.date, inSameDayAs: day) && $0.user?.id == user.id
            }) {
                existing.intake = waterIntake
            } else {
                let entry = WaterIntake(date: day, intake: waterIntake, gender: user.gender, ownerId: user.ownerId)
                entry.user = user
                modelContext.insert(entry)
            }
            try? modelContext.save()
        } catch {}
    }

    private func loadWaterIntake(for date: Date) {
        guard let user = userData else {
            waterIntake = 0
            return
        }
        let day = Calendar.current.startOfDay(for: date)
        do {
            let all = try modelContext.fetch(FetchDescriptor<WaterIntake>())
            if let existing = all.first(where: {
                Calendar.current.isDate($0.date, inSameDayAs: day) && $0.user?.id == user.id && $0.ownerId == user.ownerId
            }) {
                waterIntake = existing.intake
            } else {
                waterIntake = 0
            }
        } catch {
            waterIntake = 0
        }
    }

    // Удаление записи (со сворачиванием пустого списка)
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
        refreshDerivedFoodState()

        if let meal = MealType(rawValue: entry.mealType) {
            let isEmpty: Bool
            switch meal {
            case .breakfast: isEmpty = breakfastItems.isEmpty
            case .lunch:     isEmpty = lunchItems.isEmpty
            case .dinner:    isEmpty = dinnerItems.isEmpty
            case .snacks:    isEmpty = snacksItems.isEmpty
            }
            if isEmpty { expandedMeals.remove(meal) }
        }
    }

    private func refreshDerivedFoodState() {
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

        dailyConsumedCalories = snapshot.totalCalories
        let totalMacros = snapshot.totalMacros
        consumedProteins = totalMacros.protein
        consumedFats = totalMacros.fat
        consumedCarbs = totalMacros.carb
    }

    private func resetFoodState() {
        apply(snapshot: FoodDaySnapshot.from(entries: []))
    }
}

private struct SettingsScreenContainer: View {
    @Binding var showsFloatingAddButton: Bool

    var body: some View {
        SettingsScreen()
            .onAppear { showsFloatingAddButton = false }
            .onDisappear { showsFloatingAddButton = true }
    }
}

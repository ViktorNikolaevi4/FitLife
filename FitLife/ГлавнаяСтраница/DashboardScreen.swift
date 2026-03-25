import SwiftUI
import SwiftData

struct DashboardScreen: View {
    // Дата
    @Binding var selectedDate: Date
    let onOpenWorkouts: () -> Void

    // Данные
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [UserData]

    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue
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

    // Элементы по приёмам
    @State private var breakfastItems: [FoodEntry] = []
    @State private var lunchItems: [FoodEntry] = []
    @State private var dinnerItems: [FoodEntry] = []
    @State private var snacksItems: [FoodEntry] = []

    private var userData: UserData? {
        users.first(where: { $0.gender == selectedGender })
    }

    init(selectedDate: Binding<Date>, onOpenWorkouts: @escaping () -> Void) {
        _selectedDate = selectedDate
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
                            theme: theme
                        )

                        WaterSummaryCard(
                            intake: waterIntake,
                            goal: dailyWaterGoal(for: user),
                            theme: theme,
                            onAdd: { addWater(amount: 0.25) }
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
                onMealAdded: { recalcFor(selectedDate) },
                preselectedMeal: preset
            )
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

            NavigationLink(destination: SettingsScreen()) {
                ZStack {
                    Circle()
                        .fill(theme.card)
                        .frame(width: 40, height: 40)

                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
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
                activityLevel: .none, goal: .currentWeight,
                gender: selectedGender
            )
            modelContext.insert(newUser)
            try? modelContext.save()
        }
        loadWaterIntake(for: selectedDate)
    }

    private func recalcFor(_ date: Date) {
        func sumCalories(_ entries: [FoodEntry]) -> Int {
            entries.reduce(0) { $0 + ($1.product?.calories ?? 0) }
        }
        func sumMacros(_ entries: [FoodEntry]) -> (Int, Int, Int) {
            let p = entries.reduce(0.0) { $0 + ($1.product?.protein ?? 0) }
            let f = entries.reduce(0.0) { $0 + ($1.product?.fat ?? 0) }
            let c = entries.reduce(0.0) { $0 + ($1.product?.carbs ?? 0) }
            return (Int(p), Int(f), Int(c))
        }

        let descriptor = FetchDescriptor<FoodEntry>()

        do {
            let all = try modelContext.fetch(descriptor)
            let items = all.filter {
                Calendar.current.isDate($0.date, inSameDayAs: date) &&
                $0.gender == selectedGender
            }

            let b = items.filter { $0.mealType == MealType.breakfast.rawValue }
            let l = items.filter { $0.mealType == MealType.lunch.rawValue }
            let d = items.filter { $0.mealType == MealType.dinner.rawValue }
            let s = items.filter { $0.mealType == MealType.snacks.rawValue }

            breakfastItems = b
            lunchItems     = l
            dinnerItems    = d
            snacksItems    = s

            breakfastKcal = sumCalories(b)
            lunchKcal     = sumCalories(l)
            dinnerKcal    = sumCalories(d)
            snacksKcal    = sumCalories(s)

            let bm = sumMacros(b); breakfastMacros = (bm.0, bm.1, bm.2)
            let lm = sumMacros(l); lunchMacros     = (lm.0, lm.1, lm.2)
            let dm = sumMacros(d); dinnerMacros    = (dm.0, dm.1, dm.2)
            let sm = sumMacros(s); snacksMacros    = (sm.0, sm.1, sm.2)

            dailyConsumedCalories = sumCalories(items)
            let total = sumMacros(items)
            consumedProteins = total.0
            consumedFats     = total.1
            consumedCarbs    = total.2

        } catch {
            dailyConsumedCalories = 0
            consumedProteins = 0
            consumedFats = 0
            consumedCarbs = 0
            breakfastKcal = 0; lunchKcal = 0; dinnerKcal = 0; snacksKcal = 0
        }
    }

    private func dailyWaterGoal(for user: UserData) -> Double {
        (user.weight * 35) / 1000.0
    }

    private func addWater(amount: Double) {
        waterIntake += amount
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
                let entry = WaterIntake(date: day, intake: waterIntake, gender: user.gender)
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
                Calendar.current.isDate($0.date, inSameDayAs: day) && $0.user?.id == user.id
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
        recalcFor(selectedDate)

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
}

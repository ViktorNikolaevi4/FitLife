import SwiftUI
import SwiftData

// MARK: - Хелперы

extension Gender {
    static let appStorageKey = "activeGender"
}

// MARK: - Табы (для контекста)

struct MainTabView: View {
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue
    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue
    @State private var selectedDate: Date = Date()
    @State private var sheet: RationSheet? = nil
    @State private var refreshID = UUID()

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
    }

    private var selectedGender: Gender {
        Gender(rawValue: activeGenderRaw) ?? .male
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView {
                DashboardScreen(selectedDate: $selectedDate)
                    .id(refreshID)
                    .tabItem { Label(appLanguage.localized("tab.home"), systemImage: "house.fill") }

                ProfileScreen()
                    .tabItem { Label(appLanguage.localized("tab.profile"), systemImage: "person.fill") }

                WaterTrackerViewOne()
                    .tabItem { Label(appLanguage.localized("tab.water"), systemImage: "drop.fill") }

                SettingsScreen()
                    .tabItem { Label(appLanguage.localized("tab.settings"), systemImage: "gearshape.fill") }
            }

            Button(action: { sheet = .ration }) {
                ZStack {
                    Circle()
                        .fill(.black)
                        .frame(width: 58, height: 58)
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 5)

                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 74)
        }
        .sheet(item: $sheet) { key in
            let preset: MealType? = { if case let .quick(m) = key { m } else { nil } }()
            RationPopupView(
                gender: selectedGender,
                selectedDate: $selectedDate,
                onMealAdded: { refreshID = UUID() },
                preselectedMeal: preset
            )
        }
    }
}

// MARK: - Тема

struct AppTheme {
    let bg: Color, card: Color, border: Color, subtleFill: Color, ringTrack: Color
    let protein: Color, fat: Color, carb: Color
    let ringGradient: Gradient

    init(_ scheme: ColorScheme) {
        if scheme == .dark {
            bg = Color(UIColor.systemGroupedBackground)
            card = Color(UIColor.secondarySystemBackground)
            border = Color.white.opacity(0.06)
            subtleFill = Color.white.opacity(0.07)
            ringTrack = Color.white.opacity(0.10)
            protein = .blue; fat = .red.opacity(0.8); carb = .green
            ringGradient = .init(colors: [.blue.opacity(0.95), .cyan.opacity(0.9), .blue.opacity(0.95)])
        } else {
            bg = Color(UIColor.systemGray5)
            card = Color(UIColor.secondarySystemBackground)
            border = Color.black.opacity(0.06)
            subtleFill = Color.black.opacity(0.06)
            ringTrack = Color.black.opacity(0.10)
            protein = .blue; fat = .red.opacity(0.8); carb = .green
            ringGradient = .init(colors: [.blue, .cyan, .blue])
        }
    }
}

// MARK: - Шиты

private enum RationSheet: Identifiable {
    case ration
    case quick(MealType)

    var id: String {
        switch self {
        case .ration: return "ration"
        case .quick(let m): return "quick-\(m.rawValue)"
        }
    }
}

// MARK: - Главный экран

struct DashboardScreen: View {
    // Дата
    @Binding var selectedDate: Date

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

    init(selectedDate: Binding<Date>) {
        _selectedDate = selectedDate
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

                        MealsSection(
                            theme: theme,
                            calories: (breakfastKcal, lunchKcal, dinnerKcal, snacksKcal),
                            macros: (breakfastMacros, lunchMacros, dinnerMacros, snacksMacros),
                            entries: (breakfastItems, lunchItems, dinnerItems, snacksItems),
                            expanded: $expandedMeals,
                            onTapMeal: { meal in sheet = .quick(meal) },
                            onDeleteEntry: { entry in deleteEntry(entry) },
                            onUpdateEntry: { _ in recalcFor(selectedDate) }
                        )
                        .padding(.horizontal)
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
        .onChange(of: selectedDate) { _, newDate in recalcFor(newDate) }
        .onChange(of: activeGenderRaw) { recalcFor(selectedDate) }
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

// MARK: - Карточка «Баланс»

private enum RingDisplayMode { case target, consumed, remaining }

struct BalanceCard: View {
    var consumed: Int
    var target: Int
    var proteins: (current: Int, target: Int)
    var fats:     (current: Int, target: Int)
    var carbs:    (current: Int, target: Int)
    let theme: AppTheme

    @State private var mode: RingDisplayMode = .target

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(consumed) / Double(target), 1)
    }

    private var ringNumber: Int {
        switch mode {
        case .target:    return target
        case .consumed:  return consumed
        case .remaining: return max(target - consumed, 0)
        }
    }

    private var ringCaption: String {
        switch mode {
        case .target:    return "ккал"
        case .consumed:  return "съедено"
        case .remaining: return "осталось"
        }
    }

    // Текст для правого верхнего переключателя
    private var modeTitle: String {
        switch mode {
        case .target:    return AppLocalizer.string("balance.target")
        case .consumed:  return AppLocalizer.string("balance.consumed")
        case .remaining: return AppLocalizer.string("balance.remaining")
        }
    }
    private var modeValueText: String {
        AppLocalizer.format("unit.kcal.value", ringNumber)
    }
    private func cycleMode() {
        switch mode {
        case .target:    mode = .consumed
        case .consumed:  mode = .remaining
        case .remaining: mode = .target
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(AppLocalizer.string("balance.title")).font(.headline)
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { cycleMode() }
                }) {
                    HStack(spacing: 8) {
                        VStack(alignment: .trailing, spacing: 2) {
                               Text(modeTitle)
                                   .font(.subheadline.weight(.semibold))
                                   .foregroundStyle(.secondary)
                               Text(modeValueText)
                                   .font(.subheadline.weight(.semibold))
                                   .foregroundStyle(.secondary)
                                   .lineLimit(1)
                           }
                           .multilineTextAlignment(.trailing)
                          .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 1)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            HStack(alignment: .center, spacing: 14) {
                Donut(progress: progress, track: theme.ringTrack, gradient: theme.ringGradient)
                    .frame(width: 124, height: 124)
                    .overlay(
                        VStack(spacing: 2) {
                            Text(ringNumber.formatted(.number.grouping(.automatic)))
                                .font(.title).fontWeight(.bold)
                                .contentTransition(.numericText())
                            Text(ringCaption)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            cycleMode()
                        }
                    }
                    .onLongPressGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            mode = .remaining
                        }
                    }

                VStack(spacing: 10) {
                    MacroProgressRow(title: AppLocalizer.string("macro.protein"),
                                     current: proteins.current, target: proteins.target,
                                     tint: theme.protein, theme: theme, height: 8, horizontalPadding: 0, compactTitle: true)
                    MacroProgressRow(title: AppLocalizer.string("macro.fat"),
                                     current: fats.current, target: fats.target,
                                     tint: theme.fat, theme: theme, height: 8, horizontalPadding: 0, compactTitle: true)
                    MacroProgressRow(title: AppLocalizer.string("macro.carbs"),
                                     current: carbs.current, target: carbs.target,
                                     tint: theme.carb, theme: theme, height: 8, horizontalPadding: 0, compactTitle: true)
                }
                .frame(maxWidth: 165)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.border))
        .padding(.horizontal)
    }
}


struct Donut: View {
    var progress: Double
    var lineWidth: CGFloat = 12
    var track: Color
    var gradient: Gradient
    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AngularGradient(gradient: gradient, center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct MacroProgressRow: View {
    let title: String
    let current: Int
    let target: Int
    let tint: Color
    let theme: AppTheme
    var height: CGFloat = 8
    var warnEnabled: Bool = true
    var horizontalPadding: CGFloat = 12
    var compactTitle: Bool = false

    private var isOver: Bool {
        warnEnabled && target > 0 && current > target
    }
    private var fraction: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1)
    }
    private var fillColor: Color  { isOver ? .red : tint }
    private var trackColor: Color { isOver ? Color.red.opacity(0.25) : theme.ringTrack }
    private var valueColor: Color { isOver ? .red : .secondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if isOver {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                Text(title)
                    .font(compactTitle ? .subheadline.weight(.semibold) : .body)
                Spacer()
                Text(AppLocalizer.format("macro.progress.value", current, target))
                    .font(.subheadline)
                    .fontWeight(isOver ? .semibold : .regular)
                    .foregroundStyle(valueColor)
            }
            ThickProgressBar(fraction: fraction, fill: fillColor, track: trackColor, height: height)
                .animation(.easeInOut(duration: 0.25), value: fraction)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, 8)
    }
}

struct ThickProgressBar: View {
    var fraction: Double
    var fill: Color
    var track: Color
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height/2).fill(track)
                RoundedRectangle(cornerRadius: height/2)
                    .fill(fill)
                    .frame(width: max(0, geo.size.width * fraction))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Приёмы пищи

struct MealsSection: View {
    let theme: AppTheme
    let calories: (breakfast: Int, lunch: Int, dinner: Int, snacks: Int)
    let macros: (
        breakfast: (protein: Int, fat: Int, carb: Int),
        lunch:     (protein: Int, fat: Int, carb: Int),
        dinner:    (protein: Int, fat: Int, carb: Int),
        snacks:    (protein: Int, fat: Int, carb: Int)
    )
    let entries: (
        breakfast: [FoodEntry],
        lunch:     [FoodEntry],
        dinner:    [FoodEntry],
        snacks:    [FoodEntry]
    )

    @Binding var expanded: Set<MealType>
    var onTapMeal: (MealType) -> Void
    var onDeleteEntry: (FoodEntry) -> Void
    var onUpdateEntry: (FoodEntry) -> Void

    private func isExpanded(_ m: MealType) -> Bool { expanded.contains(m) }
    private func toggle(_ m: MealType) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expanded.remove(m) == nil { expanded.insert(m) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Завтрак
            MealRow(
                title: AppLocalizer.string("meal.breakfast"),
                systemImage: "sunrise.fill",
                kcal: calories.breakfast > 0 ? calories.breakfast : nil,
                macros: calories.breakfast > 0 ? macros.breakfast : nil,
                theme: theme,
                badgeFill: .pinkovo,
                showChevron: !entries.breakfast.isEmpty,
                chevronExpanded: isExpanded(.breakfast),
                onChevronTap: { toggle(.breakfast) }
            )
            .contentShape(Rectangle())
            .onTapGesture { onTapMeal(.breakfast) }

            if isExpanded(.breakfast) {
                ProductsList(entries.breakfast, theme: theme, onDelete: onDeleteEntry, onUpdate: onUpdateEntry)
            }

            // Обед
            MealRow(
                title: AppLocalizer.string("meal.lunch"),
                systemImage: "fork.knife",
                kcal: calories.lunch > 0 ? calories.lunch : nil,
                macros: calories.lunch > 0 ? macros.lunch : nil,
                theme: theme,
                badgeFill: .zeleneko,
                showChevron: !entries.lunch.isEmpty,
                chevronExpanded: isExpanded(.lunch),
                onChevronTap: { toggle(.lunch) }
            )
            .contentShape(Rectangle())
            .onTapGesture { onTapMeal(.lunch) }

            if isExpanded(.lunch) {
                ProductsList(entries.lunch, theme: theme, onDelete: onDeleteEntry, onUpdate: onUpdateEntry)
            }

            // Ужин
            MealRow(
                title: AppLocalizer.string("meal.dinner"),
                systemImage: "moon.stars.fill",
                kcal: calories.dinner > 0 ? calories.dinner : nil,
                macros: calories.dinner > 0 ? macros.dinner : nil,
                theme: theme,
                badgeFill: .sinenko,
                showChevron: !entries.dinner.isEmpty,
                chevronExpanded: isExpanded(.dinner),
                onChevronTap: { toggle(.dinner) }
            )
            .contentShape(Rectangle())
            .onTapGesture { onTapMeal(.dinner) }

            if isExpanded(.dinner) {
                ProductsList(entries.dinner, theme: theme, onDelete: onDeleteEntry, onUpdate: onUpdateEntry)
            }

            // Перекус
            MealRow(
                title: AppLocalizer.string("meal.snack"),
                systemImage: "takeoutbag.and.cup.and.straw.fill",
                kcal: calories.snacks > 0 ? calories.snacks : nil,
                macros: calories.snacks > 0 ? macros.snacks : nil,
                theme: theme,
                badgeFill: .zheltenko,
                showChevron: !entries.snacks.isEmpty,
                chevronExpanded: isExpanded(.snacks),
                onChevronTap: { toggle(.snacks) }
            )
            .contentShape(Rectangle())
            .onTapGesture { onTapMeal(.snacks) }

            if isExpanded(.snacks) {
                ProductsList(entries.snacks, theme: theme, onDelete: onDeleteEntry, onUpdate: onUpdateEntry)
            }
        }
    }
}

// MARK: - Ряд приёма

struct MealRow: View {
    let title: String
    let systemImage: String
    let kcal: Int?
    let macros: (protein: Int, fat: Int, carb: Int)?
    let theme: AppTheme
    var badgeFill: Color = .accentColor

    var showChevron: Bool = false
    var chevronExpanded: Bool = false
    var onChevronTap: (() -> Void)? = nil

    var macrosTopInset: CGFloat = 4

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(badgeFill)
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.headline)
                if let m = macros {
                    Text(AppLocalizer.format("meal.macros.summary", m.protein, m.fat, m.carb))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, macrosTopInset)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Text(kcal.map { AppLocalizer.format("unit.kcal.nbsp", $0) } ?? AppLocalizer.string("common.add"))
                    .foregroundStyle(.secondary)

                if showChevron {
                    Button(action: { onChevronTap?() }) {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(chevronExpanded ? 90 : 0))
                            .foregroundStyle(.secondary)
                            .font(.system(size: 15, weight: .semibold))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.border))
    }
}

// MARK: - Список продуктов (раскрытие + редактор по тапу)

private struct ProductsList: View {
    let items: [FoodEntry]
    let theme: AppTheme
    var onDelete: (FoodEntry) -> Void
    var onUpdate: (FoodEntry) -> Void

    @State private var pendingDelete: FoodEntry?
    @State private var editing: FoodEntry?
    @State private var gramsText: String = ""

    @Environment(\.modelContext) private var modelContext

    init(_ items: [FoodEntry], theme: AppTheme, onDelete: @escaping (FoodEntry) -> Void, onUpdate: @escaping (FoodEntry) -> Void) {
        self.items = items
        self.theme = theme
        self.onDelete = onDelete
        self.onUpdate = onUpdate
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { entry in
                HStack {
                    Text(entry.product?.name ?? AppLocalizer.string("product.default"))
                        .lineLimit(1)
                    Spacer()
                    HStack(spacing: 8) {
                        if entry.portion > 0 {
                            Text(AppLocalizer.format("unit.grams.value", Int(entry.portion)))
                                .foregroundStyle(.secondary)
                        }
                        Text(AppLocalizer.format("unit.kcal.value", entry.product?.calories ?? 0))
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) { Divider().opacity(0.35) }
                .contentShape(Rectangle())
                .onTapGesture {
                    editing = entry
                    gramsText = String(Int(max(1, entry.portion)))
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        pendingDelete = entry
                    } label: {
                        Label(AppLocalizer.string("common.delete"), systemImage: "trash")
                    }
                }
            }
        }
        .padding(.leading, 52)
        .padding(.trailing, 2)
        .sheet(item: $editing) { entry in
            EditEntrySheet(
                entry: entry,
                gramsText: $gramsText,
                onSave: { newPortion in
                    applyNewPortion(entry, newPortion: newPortion)
                    onUpdate(entry)
                    editing = nil
                },
                onDelete: {
                    let e = entry
                    editing = nil
                    onDelete(e)
                }
            )
            .presentationDetents([.height(320), .medium])
        }
        .alert(AppLocalizer.string("product.delete.confirm"),
               isPresented: Binding(
                   get: { pendingDelete != nil },
                   set: { if !$0 { pendingDelete = nil } }
               )
        ) {
            Button(AppLocalizer.string("common.delete"), role: .destructive) {
                if let e = pendingDelete { onDelete(e) }
                pendingDelete = nil
            }
            Button(AppLocalizer.string("common.cancel"), role: .cancel) { pendingDelete = nil }
        } message: {
            Text(AppLocalizer.string("common.cannot_undo"))
        }
    }

    /// Масштабируем хранимые в `entry.product` значения ккал/БЖУ по отношению new/old.
    private func applyNewPortion(_ entry: FoodEntry, newPortion: Double) {
        guard let product = entry.product, newPortion > 0 else { return }
        let old = max(1.0, entry.portion)
        let k = newPortion / old
        product.protein *= k
        product.fat     *= k
        product.carbs   *= k
        product.calories = Int(Double(product.calories) * k)
        entry.portion = newPortion
        do { try modelContext.save() } catch {}
    }
}

// MARK: - Малый лист редактирования продукта

private struct EditEntrySheet: View {
    let entry: FoodEntry
    @Binding var gramsText: String
    var onSave: (Double) -> Void
    var onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 2)
                .frame(width: 36, height: 4)
                .opacity(0.2)
                .padding(.top, 8)

            Text(entry.product?.name ?? AppLocalizer.string("product.default"))
                .font(.headline)

            TextField(AppLocalizer.string("portion.grams"), text: $gramsText)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .onChange(of: gramsText) { gramsText = gramsText.filter(\.isNumber) }

            if let p = Double(gramsText), let pr = entry.product {
                // коэффициент пересчёта относительно текущей порции
                let k = max(1.0, p) / max(1.0, entry.portion)
                VStack(spacing: 6) {
                    Text(AppLocalizer.format("entry.will_be_kcal", Int(Double(pr.calories) * k)))
                        .font(.title3).bold()
                    HStack(spacing: 16) {
                        Text(AppLocalizer.format("macro.protein.value", String(format: "%.1f", pr.protein * k)))
                        Text(AppLocalizer.format("macro.fat.value", String(format: "%.1f", pr.fat * k)))
                        Text(AppLocalizer.format("macro.carbs.value", String(format: "%.1f", pr.carbs * k)))
                    }
                    .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Button(AppLocalizer.string("common.delete"), role: .destructive) { onDelete() }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .frame(maxWidth: .infinity)

                Button(AppLocalizer.string("common.save")) {
                    if let v = Double(gramsText), v > 0 { onSave(v) }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)

            Spacer(minLength: 8)
        }
        // ← overlay ДОЛЖЕН быть модификатором у возвращаемого VStack
        .overlay(alignment: .topTrailing) {
                        Button(AppLocalizer.string("common.close")) { dismiss() }
                            .buttonStyle(.plain)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.secondary) 
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(8)
                            .accessibilityLabel(AppLocalizer.string("common.close"))
                    }
    }
}

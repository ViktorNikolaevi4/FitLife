import SwiftUI
import SwiftData

// MARK: - Хелперы

extension Gender {
    static let appStorageKey = "activeGender"
}

// MARK: - Табы

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardScreen()
                .tabItem { Label("Главная", systemImage: "house.fill") }

            ProfileScreen()
                .tabItem { Label("Профиль", systemImage: "person.fill") }

            WaterTrackerViewOne()
                .tabItem { Label("Вода", systemImage: "drop.fill") }

            SettingsScreen()
                .tabItem { Label("Настройки", systemImage: "gearshape.fill") }
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
            protein = .orange; fat = .mint; carb = .blue
            ringGradient = .init(colors: [.blue.opacity(0.95), .cyan.opacity(0.9), .blue.opacity(0.95)])
        } else {
            bg = Color(UIColor.systemGray5)
            card = Color(UIColor.secondarySystemBackground)
            border = Color.black.opacity(0.06)
            subtleFill = Color.black.opacity(0.06)
            ringTrack = Color.black.opacity(0.10)
            protein = .orange; fat = .green; carb = .blue
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
    // Выбор даты
    @State private var selectedDate: Date = Date()

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

    // Калории по приёмам
    @State private var breakfastKcal = 0
    @State private var lunchKcal = 0
    @State private var dinnerKcal = 0
    @State private var snacksKcal = 0

    // Макросы по приёмам
    @State private var breakfastMacros = (protein: 0, fat: 0, carb: 0)
    @State private var lunchMacros     = (protein: 0, fat: 0, carb: 0)
    @State private var dinnerMacros    = (protein: 0, fat: 0, carb: 0)
    @State private var snacksMacros    = (protein: 0, fat: 0, carb: 0)

    // Шиты и календарь
    @State private var sheet: RationSheet? = nil
    @State private var showCalendar = false

    // Состояния разворота списков
    @State private var expandedMeals: Set<MealType> = []

    // Списки продуктов по приёмам
    @State private var breakfastItems: [FoodEntry] = []
    @State private var lunchItems: [FoodEntry] = []
    @State private var dinnerItems: [FoodEntry] = []
    @State private var snacksItems: [FoodEntry] = []

    private var userData: UserData? {
        users.first(where: { $0.gender == selectedGender })
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
                            onTapMeal: { meal in sheet = .quick(meal) }
                        )
                        .padding(.horizontal)
                    } else {
                        ContentUnavailableView(
                            "Нет данных пользователя",
                            systemImage: "person.crop.circle.badge.questionmark",
                            description: Text("Профиль будет создан автоматически при первом запуске.")
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
        .onChange(of: selectedDate) { recalcFor($0) }
        .onChange(of: activeGenderRaw) { _ in recalcFor(selectedDate) }
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
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                }
                .padding()
                .navigationTitle("Выберите дату")
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Сегодня") { selectedDate = Date(); showCalendar = false }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Готово") { showCalendar = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Вью-шапка

    private func header(_ theme: AppTheme) -> some View {
        HStack(alignment: .center) {
            Button { showCalendar = true } label: {
                Text(formattedToday(selectedDate))
                    .font(.largeTitle).fontWeight(.bold)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: { sheet = .ration }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .tint(theme.carb)
        }
        .padding(.horizontal)
    }

    private func formattedToday(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.setLocalizedDateFormatFromTemplate("d MMMM")
        return df.string(from: date)
    }

    // MARK: - Данные

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

            // Списки для раскрытия
            breakfastItems = b
            lunchItems     = l
            dinnerItems    = d
            snacksItems    = s

            // Калории
            breakfastKcal = sumCalories(b)
            lunchKcal     = sumCalories(l)
            dinnerKcal    = sumCalories(d)
            snacksKcal    = sumCalories(s)

            // Макросы
            let bm = sumMacros(b); breakfastMacros = (bm.0, bm.1, bm.2)
            let lm = sumMacros(l); lunchMacros     = (lm.0, lm.1, lm.2)
            let dm = sumMacros(d); dinnerMacros    = (dm.0, dm.1, dm.2)
            let sm = sumMacros(s); snacksMacros    = (sm.0, sm.1, sm.2)

            // Итоги дня
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
            #if DEBUG
            print("Recalc error:", error)
            #endif
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Баланс").font(.headline)
                .padding(.horizontal).padding(.top, 12)

            HStack {
                Spacer()
                Donut(progress: progress, track: theme.ringTrack, gradient: theme.ringGradient)
                    .frame(width: 120, height: 120)
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
                            mode = (mode == .target ? .consumed : .target)
                        }
                    }
                    .onLongPressGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            mode = .remaining
                        }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Калорийное кольцо")
                    .accessibilityValue("\(ringNumber) \(ringCaption)")
                Spacer()
            }

            VStack(spacing: 10) {
                MacroProgressRow(title: "Белки", current: proteins.current, target: proteins.target,
                                 tint: theme.protein, theme: theme, height: 8)
                MacroProgressRow(title: "Жиры", current: fats.current, target: fats.target,
                                 tint: theme.fat, theme: theme, height: 8)
                MacroProgressRow(title: "Углеводы", current: carbs.current, target: carbs.target,
                                 tint: theme.carb, theme: theme, height: 8)
            }
            .padding(.horizontal, 8)
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
    var height: CGFloat = 8            // толщина прогресс-бара
    var warnEnabled: Bool = true       // можно отключить, если надо

    private var isOver: Bool {
        warnEnabled && target > 0 && current > target
    }

    private var fraction: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1)
    }

    private var fillColor: Color { isOver ? .red : tint }
    private var trackColor: Color { isOver ? Color.red.opacity(0.25) : theme.ringTrack }
    private var valueColor: Color { isOver ? .red : .secondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if isOver {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)
                }
                Text(title)

                Spacer()
                Text("\(current) / \(target) г")
                    .font(.subheadline)
                    .fontWeight(isOver ? .semibold : .regular)
                    .foregroundStyle(valueColor)
            }

            ThickProgressBar(
                fraction: fraction,
                fill: fillColor,
                track: trackColor,
                height: height
            )
            .animation(.easeInOut(duration: 0.25), value: fraction)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .accessibilityLabel(Text("\(title). \(current) из \(target) грамм"))
        .accessibilityHint(isOver ? Text("Перебор по \(title.lowercased())") : Text(""))
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

// MARK: - Приёмы пищи + раскрывающиеся списки

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

    private func isExpanded(_ m: MealType) -> Bool { expanded.contains(m) }
    private func toggle(_ m: MealType) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expanded.remove(m) == nil { expanded.insert(m) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Завтрак
            Button { onTapMeal(.breakfast) } label: {
                MealRow(
                    title: "Завтрак",
                    systemImage: "sunrise.fill",
                    kcal: calories.breakfast > 0 ? calories.breakfast : nil,
                    macros: calories.breakfast > 0 ? macros.breakfast : nil,
                    theme: theme,
                    badgeFill: .pinkovo,
                    showChevron: !entries.breakfast.isEmpty,
                    chevronExpanded: isExpanded(.breakfast),
                    onChevronTap: { toggle(.breakfast) }
                )
            }
            .buttonStyle(.plain)

            if isExpanded(.breakfast) {
                ProductsList(entries.breakfast, theme: theme)
            }

            // Обед
            Button { onTapMeal(.lunch) } label: {
                MealRow(
                    title: "Обед",
                    systemImage: "fork.knife",
                    kcal: calories.lunch > 0 ? calories.lunch : nil,
                    macros: calories.lunch > 0 ? macros.lunch : nil,
                    theme: theme,
                    badgeFill: .zeleneko,
                    showChevron: !entries.lunch.isEmpty,
                    chevronExpanded: isExpanded(.lunch),
                    onChevronTap: { toggle(.lunch) }
                )
            }
            .buttonStyle(.plain)

            if isExpanded(.lunch) {
                ProductsList(entries.lunch, theme: theme)
            }

            // Ужин
            Button { onTapMeal(.dinner) } label: {
                MealRow(
                    title: "Ужин",
                    systemImage: "moon.stars.fill",
                    kcal: calories.dinner > 0 ? calories.dinner : nil,
                    macros: calories.dinner > 0 ? macros.dinner : nil,
                    theme: theme,
                    badgeFill: .sinenko,
                    showChevron: !entries.dinner.isEmpty,
                    chevronExpanded: isExpanded(.dinner),
                    onChevronTap: { toggle(.dinner) }
                )
            }
            .buttonStyle(.plain)

            if isExpanded(.dinner) {
                ProductsList(entries.dinner, theme: theme)
            }

            // Перекус
            Button { onTapMeal(.snacks) } label: {
                MealRow(
                    title: "Перекус",
                    systemImage: "takeoutbag.and.cup.and.straw.fill",
                    kcal: calories.snacks > 0 ? calories.snacks : nil,
                    macros: calories.snacks > 0 ? macros.snacks : nil,
                    theme: theme,
                    badgeFill: .zheltenko,
                    showChevron: !entries.snacks.isEmpty,
                    chevronExpanded: isExpanded(.snacks),
                    onChevronTap: { toggle(.snacks) }
                )
            }
            .buttonStyle(.plain)

            if isExpanded(.snacks) {
                ProductsList(entries.snacks, theme: theme)
            }
        }
    }
}

// MARK: - Ряд приёма пищи

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
            ZstackIcon

            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.headline)
                if let m = macros {
                    Text("Б \(m.protein) • Ж \(m.fat) • У \(m.carb) г")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, macrosTopInset)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Text(kcal.map { "\($0)\u{00A0}ккал" } ?? "Добавить")
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

    private var ZstackIcon: some View {
        ZStack {
            Circle().fill(badgeFill)
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.white)
        }
        .frame(width: 40, height: 40)
    }
}

// MARK: - Список продуктов внутри раскрытия

private struct ProductsList: View {
    let items: [FoodEntry]
    let theme: AppTheme

    init(_ items: [FoodEntry], theme: AppTheme) {
        self.items = items
        self.theme = theme
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                let entry = items[i]

                HStack {
                    Text(entry.product?.name ?? "Продукт")
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: 8) {
                        if entry.portion > 0 {
                            Text("\(Int(entry.portion)) г")
                        }
                        Text("\(entry.product?.calories ?? 0) ккал")
                    }
                    .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // разделитель под строкой (кроме последней)
                if i != items.indices.last {
                    Rectangle()
                        .fill(Color(UIColor.separator))   // системный цвет разделителя
                        .frame(height: 0.5)
                        .padding(.leading, 16)            // чтобы линия начиналась под текстом
                }
            }
        }
        .padding(.leading, 52)  // чтобы визуально «заходило» под круглую иконку
        .padding(.trailing, 2)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

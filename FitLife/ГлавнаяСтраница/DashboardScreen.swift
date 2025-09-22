import SwiftUI
import SwiftData

extension Gender {
    static let appStorageKey = "activeGender"
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardScreen()
                .tabItem { Label("Главная", systemImage: "house.fill") }

            ProfileScreen()
                .tabItem { Label("Профиль", systemImage: "person.fill") }

            WaterTrackerViewOne()          // ← Вода
                .tabItem { Label("Вода", systemImage: "drop.fill") }

            SettingsScreen()            // ← Настройки
                .tabItem { Label("Настройки", systemImage: "gearshape.fill") }
        }
    }
}

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
            ringGradient = Gradient(colors: [.blue.opacity(0.95), .cyan.opacity(0.9), .blue.opacity(0.95)])
        } else {
            bg = Color(UIColor.systemGray5)
            card = Color(UIColor.secondarySystemBackground)
            border = Color.black.opacity(0.06)
            subtleFill = Color.black.opacity(0.06)
            ringTrack = Color.black.opacity(0.10)
            protein = .orange; fat = .green; carb = .blue
            ringGradient = Gradient(colors: [.blue, .cyan, .blue])
        }
    }
}

// ЕДИНЫЙ ключ показа нижнего листа
private enum RationSheet: Identifiable {
    case ration            // открыть «Рацион на день»
    case quick(MealType)   // сразу открыть список продуктов для конкретного приема

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

    // Калории по приемам
    @State private var breakfastKcal = 0
    @State private var lunchKcal = 0
    @State private var dinnerKcal = 0
    @State private var snacksKcal = 0

    // Макросы по приемам (округляем до целых граммов)
    @State private var breakfastMacros = (protein: 0, fat: 0, carb: 0)
    @State private var lunchMacros     = (protein: 0, fat: 0, carb: 0)
    @State private var dinnerMacros    = (protein: 0, fat: 0, carb: 0)
    @State private var snacksMacros    = (protein: 0, fat: 0, carb: 0)

    // ЕДИНЫЙ ключ шита
    @State private var sheet: RationSheet? = nil
    @State private var showCalendar = false

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
                            onTapMeal: { meal in sheet = .quick(meal) }  // ← ОТКРЫВАЕМ СРАЗУ СПИСОК
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
            let preset: MealType? = {
                if case let .quick(m) = key { return m } else { return nil }
            }()
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
                    DatePicker(
                        "",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)   // календарь
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ru_RU"))
                }
                .padding()
                .navigationTitle("Выберите дату")
                .toolbarTitleDisplayMode(.inline)  
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Сегодня") {
                            selectedDate = Date()
                            showCalendar = false
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Готово") { showCalendar = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    // Шапка + кнопка «+»
    private func header(_ theme: AppTheme) -> some View {
        HStack(alignment: .center) {
            Button {
                showCalendar = true
            } label: {
                Text(formattedToday(selectedDate))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentShape(Rectangle())   // удобная зона тапа
            }
            .buttonStyle(.plain)
            Spacer()
            Button(action: { sheet = .ration }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
            }
            .buttonStyle(.plain)
            .tint(.blue)
        }
        .padding(.horizontal)
    }

    // «21 сентября»
    private func formattedToday(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.setLocalizedDateFormatFromTemplate("d MMMM")
        return df.string(from: date)
    }

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
        let descriptor = FetchDescriptor<FoodEntry>()
        do {
            let all = try modelContext.fetch(descriptor)
            let items = all.filter {
                Calendar.current.isDate($0.date, inSameDayAs: date) && $0.gender == selectedGender
            }

            // Разбивка по приемам
            let b = items.filter { $0.mealType == MealType.breakfast.rawValue }
            let l = items.filter { $0.mealType == MealType.lunch.rawValue }
            let d = items.filter { $0.mealType == MealType.dinner.rawValue }
            let s = items.filter { $0.mealType == MealType.snacks.rawValue }

            // Калории по приемам
            breakfastKcal = b.reduce(0) { $0 + $1.product.calories }
            lunchKcal     = l.reduce(0) { $0 + $1.product.calories }
            dinnerKcal    = d.reduce(0) { $0 + $1.product.calories }
            snacksKcal    = s.reduce(0) { $0 + $1.product.calories }

            // Макросы по приемам (округление до целых)
            func sumMacros(_ arr: [FoodEntry]) -> (Int, Int, Int) {
                (Int(arr.reduce(0.0) { $0 + $1.product.protein }),
                 Int(arr.reduce(0.0) { $0 + $1.product.fat }),
                 Int(arr.reduce(0.0) { $0 + $1.product.carbs }))
            }
            let bm = sumMacros(b); breakfastMacros = (bm.0, bm.1, bm.2)
            let lm = sumMacros(l); lunchMacros     = (lm.0, lm.1, lm.2)
            let dm = sumMacros(d); dinnerMacros    = (dm.0, dm.1, dm.2)
            let sm = sumMacros(s); snacksMacros    = (sm.0, sm.1, sm.2)

            // Итоги дня
            dailyConsumedCalories = items.reduce(0) { $0 + $1.product.calories }
            consumedProteins = Int(items.reduce(0.0) { $0 + $1.product.protein })
            consumedFats     = Int(items.reduce(0.0) { $0 + $1.product.fat })
            consumedCarbs    = Int(items.reduce(0.0) { $0 + $1.product.carbs })
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
struct BalanceCard: View {
    var consumed: Int
    var target: Int
    var proteins: (current: Int, target: Int)
    var fats:     (current: Int, target: Int)
    var carbs:    (current: Int, target: Int)
    let theme: AppTheme

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(consumed) / Double(target), 1)
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
                            Text("\(target)").font(.title).fontWeight(.bold)
                            Text("ккал").font(.footnote).foregroundStyle(.secondary)
                        }
                    )
                Spacer()
            }

            VStack(spacing: 10) {
                MacroProgressRow(title: "Белки",
                                 current: proteins.current,
                                 target: proteins.target,
                                 tint: theme.protein,
                                 theme: theme,
                                 height: 8)

                MacroProgressRow(title: "Жиры",
                                 current: fats.current,
                                 target: fats.target,
                                 tint: theme.fat,
                                 theme: theme,
                                 height: 8)

                MacroProgressRow(title: "Углеводы",
                                 current: carbs.current,
                                 target: carbs.target,
                                 tint: theme.carb,
                                 theme: theme,
                                 height: 8)
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
    var height: CGFloat = 8 // толщина

    private var fraction: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(current) / \(target) г")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ThickProgressBar(fraction: fraction, fill: tint, track: theme.ringTrack, height: height)
                .animation(.easeInOut(duration: 0.25), value: fraction)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

struct ThickProgressBar: View {
    var fraction: Double      // 0...1
    var fill: Color           // цвет заполнения
    var track: Color          // цвет трека
    var height: CGFloat = 10  // толщина

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

// MARK: - Блок «Приемы пищи»
struct MealsSection: View {
    let theme: AppTheme
    let calories: (breakfast: Int, lunch: Int, dinner: Int, snacks: Int)
    let macros: (
        breakfast: (protein: Int, fat: Int, carb: Int),
        lunch:     (protein: Int, fat: Int, carb: Int),
        dinner:    (protein: Int, fat: Int, carb: Int),
        snacks:    (protein: Int, fat: Int, carb: Int)
    )
    var onTapMeal: (MealType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { onTapMeal(.breakfast) } label: {
                MealRow(
                    title: "Завтрак",
                    systemImage: "sunrise.fill",
                    kcal: calories.breakfast > 0 ? calories.breakfast : nil,
                    macros: calories.breakfast > 0 ? macros.breakfast : nil,
                    theme: theme,
                    badgeFill: .pinkovo
                )
            }.buttonStyle(.plain)

            Button { onTapMeal(.lunch) } label: {
                MealRow(
                    title: "Обед",
                    systemImage: "fork.knife",
                    kcal: calories.lunch > 0 ? calories.lunch : nil,
                    macros: calories.lunch > 0 ? macros.lunch : nil,
                    theme: theme,
                    badgeFill: .zeleneko
                )
            }.buttonStyle(.plain)

            Button { onTapMeal(.dinner) } label: {
                MealRow(
                    title: "Ужин",
                    systemImage: "moon.stars.fill",
                    kcal: calories.dinner > 0 ? calories.dinner : nil,
                    macros: calories.dinner > 0 ? macros.dinner : nil,
                    theme: theme,
                    badgeFill: .sinenko
                )
            }.buttonStyle(.plain)

            Button { onTapMeal(.snacks) } label: {
                MealRow(
                    title: "Перекус",
                    systemImage: "takeoutbag.and.cup.and.straw.fill",
                    kcal: calories.snacks > 0 ? calories.snacks : nil,
                    macros: calories.snacks > 0 ? macros.snacks : nil,
                    theme: theme,
                    badgeFill: .zheltenko
                )
            }.buttonStyle(.plain)
        }
    }
}

struct MealRow: View {
    let title: String
    let systemImage: String
    let kcal: Int?
    let macros: (protein: Int, fat: Int, carb: Int)?
    let theme: AppTheme
    var badgeFill: Color = .accentColor
    var macrosTopInset: CGFloat = 4

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(badgeFill)
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.white) // белая иконка
            }
            .frame(width: 40, height: 40)

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
            Text(kcal.map { "\($0) kcal" } ?? "Добавить")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.border))
    }
}

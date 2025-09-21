import SwiftUI
import SwiftData

extension Gender {
    static let appStorageKey = "activeGender"
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardScreen()
                .tabItem { Image(systemName: "house.fill"); Text("Главная") }

            Text("Дневник")
                .tabItem { Image(systemName: "book"); Text("Дневник") }

            Text("Статистика")
                .tabItem { Image(systemName: "chart.bar.fill"); Text("Статистика") }

            ProfileScreen()
                .tabItem { Image(systemName: "person.fill"); Text("Профиль") }
        }
    }
}

// MARK: - Theme
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

// MARK: - Sheet key
private enum RationSheet: Identifiable {
    case ration                 // общий экран «Рацион на день»
    case quick(MealType)        // сразу список продуктов

    var id: String {
        switch self {
        case .ration: return "ration"
        case .quick(let m): return "quick-\(m.rawValue)"
        }
    }
}

// MARK: - Dashboard
struct DashboardScreen: View {
    @State private var selectedDate: Date = Date()

    @Environment(\.modelContext) private var modelContext
    @Query private var users: [UserData]

    @AppStorage(Gender.appStorageKey) private var activeGenderRaw: String = Gender.male.rawValue
    private var selectedGender: Gender { Gender(rawValue: activeGenderRaw) ?? .male }

    @Environment(\.colorScheme) private var colorScheme

    @State private var dailyConsumedCalories: Int = 0
    @State private var consumedProteins: Int = 0
    @State private var consumedFats: Int = 0
    @State private var consumedCarbs: Int = 0

    @State private var breakfastKcal: Int = 0
    @State private var lunchKcal: Int = 0
    @State private var dinnerKcal: Int = 0
    @State private var snacksKcal: Int = 0

    // ЕДИНЫЙ ключ для показа шита
    @State private var sheet: RationSheet? = nil

    private var userData: UserData? { users.first(where: { $0.gender == selectedGender }) }

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
                            calories: (breakfast: breakfastKcal, lunch: lunchKcal, dinner: dinnerKcal, snacks: snacksKcal),
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
    }

    // MARK: Header
    private func header(_ theme: AppTheme) -> some View {
        HStack(alignment: .center) {
            Text(formattedToday(selectedDate))
                .font(.largeTitle).fontWeight(.bold)
                .lineLimit(1).minimumScaleFactor(0.8)

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

    // MARK: Helpers
    private func formattedToday(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.setLocalizedDateFormatFromTemplate("Сегодня, d MMM")
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
            dailyConsumedCalories = items.reduce(0) { $0 + $1.product.calories }
            consumedProteins = Int(items.reduce(0.0) { $0 + $1.product.protein })
            consumedFats     = Int(items.reduce(0.0) { $0 + $1.product.fat })
            consumedCarbs    = Int(items.reduce(0.0) { $0 + $1.product.carbs })

            breakfastKcal = items.filter { $0.mealType == MealType.breakfast.rawValue }.reduce(0) { $0 + $1.product.calories }
            lunchKcal     = items.filter { $0.mealType == MealType.lunch.rawValue     }.reduce(0) { $0 + $1.product.calories }
            dinnerKcal    = items.filter { $0.mealType == MealType.dinner.rawValue    }.reduce(0) { $0 + $1.product.calories }
            snacksKcal    = items.filter { $0.mealType == MealType.snacks.rawValue    }.reduce(0) { $0 + $1.product.calories }
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

// MARK: - UI кусочки
struct BalanceCard: View {
    var consumed: Int
    var target: Int
    var proteins: (current: Int, target: Int)
    var fats:     (current: Int, target: Int)
    var carbs:    (current: Int, target: Int)
    let theme: AppTheme

    private var progress: Double { guard target > 0 else { return 0 }
        return min(Double(consumed) / Double(target), 1) }

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
                MacroProgressRow(title: "Белки", current: proteins.current, target: proteins.target,
                                 systemImage: "bolt.fill", tint: theme.protein, theme: theme)
                MacroProgressRow(title: "Жиры", current: fats.current, target: fats.target,
                                 systemImage: "drop.fill", tint: theme.fat, theme: theme)
                MacroProgressRow(title: "Углеводы", current: carbs.current, target: carbs.target,
                                 systemImage: "leaf.fill", tint: theme.carb, theme: theme)
            }
            .padding(.horizontal, 8).padding(.bottom, 8)
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
    let systemImage: String
    let tint: Color
    let theme: AppTheme

    private var fraction: Double { guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text("\(current) / \(target) г")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .tint(tint)
                .animation(.easeInOut(duration: 0.25), value: fraction)
        }
        .padding(.horizontal, 12).padding(.bottom, 8)
    }
}

struct MealsSection: View {
    let theme: AppTheme
    let calories: (breakfast: Int, lunch: Int, dinner: Int, snacks: Int)
    var onTapMeal: (MealType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { onTapMeal(.breakfast) } label: {
                MealRow(title: "Завтрак", systemImage: "sunrise.fill",
                        kcal: calories.breakfast > 0 ? calories.breakfast : nil, theme: theme)
            }.buttonStyle(.plain)

            Button { onTapMeal(.lunch) } label: {
                MealRow(title: "Обед", systemImage: "fork.knife",
                        kcal: calories.lunch > 0 ? calories.lunch : nil, theme: theme)
            }.buttonStyle(.plain)

            Button { onTapMeal(.dinner) } label: {
                MealRow(title: "Ужин", systemImage: "moon.stars.fill",
                        kcal: calories.dinner > 0 ? calories.dinner : nil, theme: theme)
            }.buttonStyle(.plain)

            Button { onTapMeal(.snacks) } label: {
                MealRow(title: "Перекус", systemImage: "takeoutbag.and.cup.and.straw.fill",
                        kcal: calories.snacks > 0 ? calories.snacks : nil, theme: theme)
            }.buttonStyle(.plain)
        }
    }
}

struct MealRow: View {
    let title: String, systemImage: String, kcal: Int?, theme: AppTheme
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3).frame(width: 24, height: 24)
                .padding(8).background(Circle().fill(theme.subtleFill))
            Text(title).font(.headline)
            Spacer()
            Text(kcal.map { "\($0) kcal" } ?? "Добавить")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.border))
    }
}

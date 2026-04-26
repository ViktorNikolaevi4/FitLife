import SwiftUI
import SwiftData

struct AppTheme {
    let bg: Color, card: Color, border: Color, subtleFill: Color, ringTrack: Color
    let protein: Color, fat: Color, carb: Color
    let ringGradient: Gradient
    let cardShadow: Color
    let cardShadowRadius: CGFloat
    let cardShadowY: CGFloat

    init(_ scheme: ColorScheme) {
        if scheme == .dark {
            bg = Color(UIColor.systemGroupedBackground)
            card = Color(UIColor.secondarySystemBackground)
            border = Color(.separator).opacity(0.28)
            subtleFill = Color(UIColor.tertiarySystemBackground)
            ringTrack = Color(.separator).opacity(0.22)
            protein = .blue; fat = .red.opacity(0.8); carb = .green
            ringGradient = .init(colors: [.blue.opacity(0.95), .cyan.opacity(0.9), .blue.opacity(0.95)])
            cardShadow = .clear
            cardShadowRadius = 0
            cardShadowY = 0
        } else {
            bg = Color(UIColor.systemGroupedBackground)
            card = Color(UIColor.secondarySystemBackground)
            border = Color(.separator).opacity(0.42)
            subtleFill = Color(UIColor.tertiarySystemBackground)
            ringTrack = Color(.separator).opacity(0.24)
            protein = .blue; fat = .red.opacity(0.8); carb = .green
            ringGradient = .init(colors: [.blue, .cyan, .blue])
            cardShadow = .black.opacity(0.08)
            cardShadowRadius = 16
            cardShadowY = 6
        }
    }
}

// MARK: - Шиты

enum RationSheet: Identifiable {
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

struct WaterSummaryCard: View {
    let intake: Double
    let goal: Double
    let quickAddML: Int
    let theme: AppTheme
    let onSubtract: () -> Void
    let onAdd: () -> Void

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(intake / goal, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.blue)
                    Text(AppLocalizer.string("tab.water"))
                        .font(.headline)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button(action: onSubtract) {
                        Image(systemName: "minus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(theme.subtleFill))
                    }
                    .buttonStyle(.plain)

                    Text(AppLocalizer.format("unit.ml.value", quickAddML))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 56)

                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(theme.subtleFill))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(AppLocalizer.format("water.progress.liters", intake, goal))
                .font(.system(size: 24, weight: .bold))

            ThickProgressBar(
                fraction: progress,
                fill: .blue,
                track: theme.ringTrack,
                height: 8
            )
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.border))
        .shadow(color: theme.cardShadow, radius: theme.cardShadowRadius, x: 0, y: theme.cardShadowY)
        .padding(.horizontal)
    }
}

struct TrainingDiaryCard: View {
    let theme: AppTheme
    let title: String
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.16),
                                    Color.cyan.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                .frame(width: 84, height: 84)

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(AppLocalizer.string("workouts.new.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(RoundedRectangle(cornerRadius: 16).fill(theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.border))
        .shadow(color: theme.cardShadow, radius: theme.cardShadowRadius, x: 0, y: theme.cardShadowY)
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
    var onTapProtein: () -> Void = {}
    var onTapFat: () -> Void = {}
    var onTapCarbs: () -> Void = {}

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
                    Button(action: onTapProtein) {
                        MacroProgressRow(title: AppLocalizer.string("macro.protein"),
                                         current: proteins.current, target: proteins.target,
                                         tint: theme.protein, theme: theme, height: 8, horizontalPadding: 0, compactTitle: true)
                    }
                    .buttonStyle(.plain)
                    Button(action: onTapFat) {
                        MacroProgressRow(title: AppLocalizer.string("macro.fat"),
                                         current: fats.current, target: fats.target,
                                         tint: theme.fat, theme: theme, height: 8, horizontalPadding: 0, compactTitle: true)
                    }
                    .buttonStyle(.plain)
                    Button(action: onTapCarbs) {
                        MacroProgressRow(title: AppLocalizer.string("macro.carbs"),
                                         current: carbs.current, target: carbs.target,
                                         tint: theme.carb, theme: theme, height: 8, horizontalPadding: 0, compactTitle: true)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: 165)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.border))
        .shadow(color: theme.cardShadow, radius: theme.cardShadowRadius, x: 0, y: theme.cardShadowY)
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

struct FoodDaySnapshot {
    let breakfast: [FoodEntry]
    let lunch: [FoodEntry]
    let dinner: [FoodEntry]
    let snacks: [FoodEntry]

    var allEntries: [FoodEntry] {
        breakfast + lunch + dinner + snacks
    }

    var mealCalories: (breakfast: Int, lunch: Int, dinner: Int, snacks: Int) {
        (
            calories(for: breakfast),
            calories(for: lunch),
            calories(for: dinner),
            calories(for: snacks)
        )
    }

    var mealMacros: (
        breakfast: (protein: Int, fat: Int, carb: Int),
        lunch: (protein: Int, fat: Int, carb: Int),
        dinner: (protein: Int, fat: Int, carb: Int),
        snacks: (protein: Int, fat: Int, carb: Int)
    ) {
        (
            macros(for: breakfast),
            macros(for: lunch),
            macros(for: dinner),
            macros(for: snacks)
        )
    }

    var totalCalories: Int {
        calories(for: allEntries)
    }

    var totalMacros: (protein: Int, fat: Int, carb: Int) {
        macros(for: allEntries)
    }

    static func from(entries: [FoodEntry]) -> FoodDaySnapshot {
        FoodDaySnapshot(
            breakfast: entries.filter { $0.mealType == MealType.breakfast.rawValue },
            lunch: entries.filter { $0.mealType == MealType.lunch.rawValue },
            dinner: entries.filter { $0.mealType == MealType.dinner.rawValue },
            snacks: entries.filter { $0.mealType == MealType.snacks.rawValue }
        )
    }

    private func calories(for entries: [FoodEntry]) -> Int {
        entries.reduce(0) { $0 + ($1.product?.calories ?? 0) }
    }

    private func macros(for entries: [FoodEntry]) -> (protein: Int, fat: Int, carb: Int) {
        let protein = entries.reduce(0.0) { $0 + ($1.product?.protein ?? 0) }
        let fat = entries.reduce(0.0) { $0 + ($1.product?.fat ?? 0) }
        let carbs = entries.reduce(0.0) { $0 + ($1.product?.carbs ?? 0) }
        return (Int(protein), Int(fat), Int(carbs))
    }
}

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
    var onDeleteEntries: ([FoodEntry]) -> Void
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
                ProductsList(
                    entries.breakfast,
                    theme: theme,
                    onDelete: onDeleteEntry,
                    onDeleteMany: onDeleteEntries,
                    onUpdate: onUpdateEntry
                )
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
                ProductsList(
                    entries.lunch,
                    theme: theme,
                    onDelete: onDeleteEntry,
                    onDeleteMany: onDeleteEntries,
                    onUpdate: onUpdateEntry
                )
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
                ProductsList(
                    entries.dinner,
                    theme: theme,
                    onDelete: onDeleteEntry,
                    onDeleteMany: onDeleteEntries,
                    onUpdate: onUpdateEntry
                )
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
                ProductsList(
                    entries.snacks,
                    theme: theme,
                    onDelete: onDeleteEntry,
                    onDeleteMany: onDeleteEntries,
                    onUpdate: onUpdateEntry
                )
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
        .shadow(color: theme.cardShadow.opacity(0.9), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Список продуктов (раскрытие + редактор по тапу)

private struct ProductsList: View {
    private struct DisplayItem: Identifiable {
        let id: String
        let title: String
        let grams: Int
        let calories: Int
        let entries: [FoodEntry]
        let isGroupedAIMeal: Bool
    }

    let items: [FoodEntry]
    let theme: AppTheme
    var onDelete: (FoodEntry) -> Void
    var onDeleteMany: ([FoodEntry]) -> Void
    var onUpdate: (FoodEntry) -> Void

    @State private var pendingDelete: FoodEntry?
    @State private var pendingDeleteGroup: [FoodEntry] = []
    @State private var editingSelection: FoodEntryEditorSelection?
    @State private var editingGroupedMealSelection: GroupedAIMealEditorSelection?

    @Environment(\.modelContext) private var modelContext

    private var displayItems: [DisplayItem] {
        var groupedByKey: [String: [FoodEntry]] = [:]
        var order: [String] = []

        for entry in items {
            let trimmedMealName = entry.aiMealName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let key: String

            if let aiMealGroupID = entry.aiMealGroupID, !trimmedMealName.isEmpty {
                key = "ai-\(aiMealGroupID)"
            } else {
                key = "entry-\(entry.id.uuidString)"
            }

            if groupedByKey[key] == nil {
                order.append(key)
                groupedByKey[key] = []
            }
            groupedByKey[key]?.append(entry)
        }

        return order.compactMap { key in
            guard let entries = groupedByKey[key], let first = entries.first else { return nil }
            let isGroupedAIMeal = entries.count > 1 && key.hasPrefix("ai-")
            let title = isGroupedAIMeal
                ? (first.aiMealName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? first.aiMealName!.trimmingCharacters(in: .whitespacesAndNewlines)
                    : (first.product?.name ?? AppLocalizer.string("product.default")))
                : (first.product?.name ?? AppLocalizer.string("product.default"))

            return DisplayItem(
                id: key,
                title: title,
                grams: Int(entries.reduce(0.0) { $0 + $1.portion }),
                calories: entries.reduce(0) { $0 + ($1.product?.calories ?? 0) },
                entries: entries,
                isGroupedAIMeal: isGroupedAIMeal
            )
        }
    }

    init(
        _ items: [FoodEntry],
        theme: AppTheme,
        onDelete: @escaping (FoodEntry) -> Void,
        onDeleteMany: @escaping ([FoodEntry]) -> Void,
        onUpdate: @escaping (FoodEntry) -> Void
    ) {
        self.items = items
        self.theme = theme
        self.onDelete = onDelete
        self.onDeleteMany = onDeleteMany
        self.onUpdate = onUpdate
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(displayItems) { item in
                VStack(spacing: 0) {
                    HStack {
                        Text(item.title)
                            .lineLimit(2)
                        Spacer()
                        HStack(spacing: 8) {
                            if item.grams > 0 {
                                Text(AppLocalizer.format("unit.grams.value", item.grams))
                                    .foregroundStyle(.secondary)
                            }
                            Text(AppLocalizer.format("unit.kcal.value", item.calories))
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard let first = item.entries.first else { return }
                        if item.isGroupedAIMeal {
                            editingGroupedMealSelection = GroupedAIMealEditorSelection(
                                id: item.id,
                                title: item.title,
                                entries: item.entries
                            )
                        } else {
                            editingSelection = FoodEntryEditorSelection(entry: first)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            if item.isGroupedAIMeal {
                                pendingDeleteGroup = item.entries
                            } else {
                                pendingDelete = item.entries.first
                            }
                        } label: {
                            Label(AppLocalizer.string("common.delete"), systemImage: "trash")
                        }
                    }
                }
                .overlay(alignment: .bottom) { Divider().opacity(0.35) }
            }
        }
        .padding(.leading, 52)
        .padding(.trailing, 2)
        .navigationDestination(item: $editingSelection) { selection in
            PortionEditorScreen(
                entry: selection.entry,
                onSave: { newPortion in
                    applyNewPortion(selection.entry, newPortion: newPortion)
                    onUpdate(selection.entry)
                },
                onDelete: {
                    onDelete(selection.entry)
                }
            )
        }
        .navigationDestination(item: $editingGroupedMealSelection) { selection in
            GroupedAIMealPortionEditorScreen(
                title: selection.title,
                entries: selection.entries,
                onSave: { newPortion in
                    applyNewPortion(selection.entries, newTotalPortion: newPortion)
                    selection.entries.forEach(onUpdate)
                },
                onDelete: {
                    onDeleteMany(selection.entries)
                }
            )
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
        .alert(
            AppLocalizer.string("product.delete.confirm"),
            isPresented: Binding(
                get: { pendingDeleteGroup.isEmpty == false },
                set: { if !$0 { pendingDeleteGroup = [] } }
            )
        ) {
            Button(AppLocalizer.string("common.delete"), role: .destructive) {
                onDeleteMany(pendingDeleteGroup)
                pendingDeleteGroup = []
            }
            Button(AppLocalizer.string("common.cancel"), role: .cancel) {
                pendingDeleteGroup = []
            }
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

    private func applyNewPortion(_ entries: [FoodEntry], newTotalPortion: Double) {
        let oldTotal = max(1.0, entries.reduce(0.0) { $0 + $1.portion })
        let k = newTotalPortion / oldTotal

        for entry in entries {
            if let product = entry.product {
                product.protein *= k
                product.fat *= k
                product.carbs *= k
                product.calories = Int((Double(product.calories) * k).rounded())
            }
            entry.portion = max(1.0, entry.portion * k)
        }

        do { try modelContext.save() } catch {}
    }
}

private struct FoodEntryEditorSelection: Identifiable, Hashable {
    let entry: FoodEntry
    var id: UUID { entry.id }

    static func == (lhs: FoodEntryEditorSelection, rhs: FoodEntryEditorSelection) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct GroupedAIMealEditorSelection: Identifiable, Hashable {
    let id: String
    let title: String
    let entries: [FoodEntry]

    static func == (lhs: GroupedAIMealEditorSelection, rhs: GroupedAIMealEditorSelection) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Portion Editor

private struct PortionEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let entry: FoodEntry
    var onSave: (Double) -> Void
    var onDelete: () -> Void

    @State private var gramsText: String
    @State private var editingCustomProductSelection: CustomProductPortionEditorSelection?

    init(entry: FoodEntry, onSave: @escaping (Double) -> Void, onDelete: @escaping () -> Void) {
        self.entry = entry
        self.onSave = onSave
        self.onDelete = onDelete
        _gramsText = State(initialValue: String(Int(max(1, entry.portion))))
    }

    private var previewScale: Double {
        guard entry.portion > 0 else { return 1 }
        return gramsValue / max(1.0, entry.portion)
    }

    private var gramsValue: Double {
        max(1, Double(gramsText) ?? entry.portion)
    }

    private struct CustomProductPortionEditorSelection: Identifiable {
        let product: CustomProduct
        var id: UUID { product.id }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.product?.name ?? AppLocalizer.string("product.default"))
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Text(AppLocalizer.string("search.per_100g"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    HStack(spacing: 14) {
                        stepperButton(systemImage: "minus") {
                            updateGrams(by: -10)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            TextField("100", text: $gramsText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .onChange(of: gramsText) { gramsText = gramsText.filter(\.isNumber) }

                            Text(AppLocalizer.string("unit.grams.short"))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        stepperButton(systemImage: "plus") {
                            updateGrams(by: 10)
                        }
                    }
                }
                .padding(18)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24))

                if let pr = entry.product {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(AppLocalizer.format("entry.will_be_kcal", Int(Double(pr.calories) * previewScale)))
                            .font(.system(size: 30, weight: .bold))

                        VStack(spacing: 10) {
                            PortionMetricRow(title: AppLocalizer.string("macro.protein"), value: pr.protein * previewScale)
                            PortionMetricRow(title: AppLocalizer.string("macro.fat"), value: pr.fat * previewScale)
                            PortionMetricRow(title: AppLocalizer.string("macro.carbs"), value: pr.carbs * previewScale)
                        }
                    }
                    .padding(18)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color(.separator).opacity(0.22))
                    )
                }

                if let customProduct = linkedCustomProduct {
                    Button(AppLocalizer.string("custom_product.edit")) {
                        editingCustomProductSelection = CustomProductPortionEditorSelection(product: customProduct)
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.blue.opacity(0.12))
                    )
                }

                Button(AppLocalizer.string("common.save")) {
                    onSave(gramsValue)
                    dismiss()
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.primary))

                Button(AppLocalizer.string("common.delete"), role: .destructive) {
                    onDelete()
                    dismiss()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(AppLocalizer.string("entry.portion.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingCustomProductSelection) { selection in
            CustomProductEditorScreen(
                product: selection.product,
                allowsDelete: false,
                onSaved: {
                    applyUpdatedCustomProduct(selection.product)
                }
            )
        }
    }

    private func updateGrams(by delta: Int) {
        let next = max(1, Int(gramsValue) + delta)
        gramsText = String(next)
    }

    private func stepperButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .frame(width: 42, height: 42)
                .background(Color(.secondarySystemBackground), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var linkedCustomProduct: CustomProduct? {
        guard let customProductID = entry.customProductID else { return nil }
        let predicate = #Predicate<CustomProduct> { product in
            product.id == customProductID
        }
        let descriptor = FetchDescriptor<CustomProduct>(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }

    private func applyUpdatedCustomProduct(_ customProduct: CustomProduct) {
        guard let product = entry.product else { return }
        let factor = max(1.0, entry.portion) / 100
        product.name = customProduct.name
        product.calories = Int((Double(customProduct.calories) * factor).rounded())
        product.protein = customProduct.protein * factor
        product.fat = customProduct.fat * factor
        product.carbs = customProduct.carbs * factor
        do {
            try modelContext.save()
        } catch {}
    }
}

private struct PortionMetricRow: View {
    let title: String
    let value: Double

    var body: some View {
        HStack {
            Text(title)
                .font(.body.weight(.medium))
            Spacer()
            Text(String(format: "%.1f %@", value, AppLocalizer.string("unit.grams.short")))
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct GroupedAIMealPortionEditorScreen: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let entries: [FoodEntry]
    var onSave: (Double) -> Void
    var onDelete: () -> Void

    @State private var gramsText: String

    init(title: String, entries: [FoodEntry], onSave: @escaping (Double) -> Void, onDelete: @escaping () -> Void) {
        self.title = title
        self.entries = entries
        self.onSave = onSave
        self.onDelete = onDelete
        let initialGrams = max(1, Int(entries.reduce(0.0) { $0 + $1.portion }))
        _gramsText = State(initialValue: String(initialGrams))
    }

    private var totalPortion: Double {
        max(1.0, entries.reduce(0.0) { $0 + $1.portion })
    }

    private var gramsValue: Double {
        max(1, Double(gramsText) ?? totalPortion)
    }

    private var previewScale: Double {
        gramsValue / totalPortion
    }

    private var totalCalories: Int {
        entries.reduce(0) { $0 + ($1.product?.calories ?? 0) }
    }

    private var totalProtein: Double {
        entries.reduce(0.0) { $0 + ($1.product?.protein ?? 0) }
    }

    private var totalFat: Double {
        entries.reduce(0.0) { $0 + ($1.product?.fat ?? 0) }
    }

    private var totalCarbs: Double {
        entries.reduce(0.0) { $0 + ($1.product?.carbs ?? 0) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Text(AppLocalizer.string("search.per_100g"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    HStack(spacing: 14) {
                        stepperButton(systemImage: "minus") {
                            updateGrams(by: -10)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            TextField("100", text: $gramsText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .onChange(of: gramsText) { gramsText = gramsText.filter(\.isNumber) }

                            Text(AppLocalizer.string("unit.grams.short"))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        stepperButton(systemImage: "plus") {
                            updateGrams(by: 10)
                        }
                    }
                }
                .padding(18)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24))

                VStack(alignment: .leading, spacing: 14) {
                    Text(AppLocalizer.format("entry.will_be_kcal", Int(Double(totalCalories) * previewScale)))
                        .font(.system(size: 30, weight: .bold))

                    VStack(spacing: 10) {
                        PortionMetricRow(title: AppLocalizer.string("macro.protein"), value: totalProtein * previewScale)
                        PortionMetricRow(title: AppLocalizer.string("macro.fat"), value: totalFat * previewScale)
                        PortionMetricRow(title: AppLocalizer.string("macro.carbs"), value: totalCarbs * previewScale)
                    }
                }
                .padding(18)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color(.separator).opacity(0.22))
                )

                Button(AppLocalizer.string("common.save")) {
                    onSave(gramsValue)
                    dismiss()
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.primary))

                Button(AppLocalizer.string("common.delete"), role: .destructive) {
                    onDelete()
                    dismiss()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(AppLocalizer.string("entry.portion.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func updateGrams(by delta: Int) {
        let next = max(1, Int(gramsValue) + delta)
        gramsText = String(next)
    }

    private func stepperButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .frame(width: 42, height: 42)
                .background(Color(.secondarySystemBackground), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

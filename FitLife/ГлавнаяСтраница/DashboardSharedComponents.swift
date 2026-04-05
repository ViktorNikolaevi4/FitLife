import SwiftUI
import SwiftData

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
    let theme: AppTheme
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

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 54, height: 54)
                        .background(Circle().fill(theme.subtleFill))
                }
                .buttonStyle(.plain)
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
                    RoundedRectangle(cornerRadius: 14)
                        .fill(theme.subtleFill)

                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 96, height: 96)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(RoundedRectangle(cornerRadius: 16).fill(theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.border))
        .padding(.horizontal)
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
    @State private var editingSelection: FoodEntryEditorSelection?

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
                VStack(spacing: 0) {
                    HStack {
                        Text(entry.product?.name ?? AppLocalizer.string("product.default"))
                            .lineLimit(2)
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingSelection = FoodEntryEditorSelection(entry: entry)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            pendingDelete = entry
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

// MARK: - Portion Editor

private struct PortionEditorScreen: View {
    @Environment(\.dismiss) private var dismiss

    let entry: FoodEntry
    var onSave: (Double) -> Void
    var onDelete: () -> Void

    @State private var gramsText: String

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
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.black.opacity(0.06))
                    )
                }

                Button(AppLocalizer.string("common.save")) {
                    onSave(gramsValue)
                    dismiss()
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(RoundedRectangle(cornerRadius: 20).fill(.black))

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

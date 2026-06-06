import SwiftUI
import SwiftData

private let maxFoodPortionGrams = 10_000.0

extension Double {
    var safeFinite: Double {
        isFinite ? self : 0
    }

    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(safeFinite, range.lowerBound), range.upperBound)
    }
}

extension CGFloat {
    var safeFinite: CGFloat {
        isFinite ? self : 0
    }

    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(safeFinite, range.lowerBound), range.upperBound)
    }
}

func safeProgress(current: Double, goal: Double) -> Double {
    let safeCurrent = current.safeFinite
    let safeGoal = goal.safeFinite
    guard safeGoal > 0 else { return 0 }
    return (safeCurrent / safeGoal).clamped(to: 0...1)
}

func safeProgress(current: Int, goal: Int) -> Double {
    safeProgress(current: Double(current), goal: Double(goal))
}

func safeDimension(_ value: CGFloat, minimum: CGFloat = 0) -> CGFloat {
    Swift.max(value.safeFinite, minimum)
}

struct AppTheme {
    let bg: Color, card: Color, border: Color, subtleFill: Color, ringTrack: Color
    let protein: Color, fat: Color, carb: Color
    let ringGradient: Gradient
    let cardShadow: Color
    let cardShadowRadius: CGFloat
    let cardShadowY: CGFloat
    let isDark: Bool
    let primaryText: Color
    let secondaryText: Color
    let tertiaryText: Color
    let accent: Color
    let accentDeep: Color
    let divider: Color
    let orange: Color

    init(_ scheme: ColorScheme) {
        if scheme == .dark {
            bg = Color(UIColor.systemGroupedBackground)
            card = Color(UIColor.secondarySystemBackground)
            border = Color(.separator).opacity(0.28)
            subtleFill = Color(UIColor.tertiarySystemBackground)
            ringTrack = Color(.separator).opacity(0.22)
            protein = HomeDarkColors.blue; fat = HomeDarkColors.red; carb = HomeDarkColors.green
            ringGradient = .init(colors: [HomeDarkColors.blue.opacity(0.95), HomeDarkColors.blueDeep.opacity(0.9), HomeDarkColors.blue.opacity(0.95)])
            cardShadow = .clear
            cardShadowRadius = 0
            cardShadowY = 0
            isDark = true
            primaryText = HomeDarkColors.primaryText
            secondaryText = HomeDarkColors.secondaryText
            tertiaryText = HomeDarkColors.tertiaryText
            accent = HomeDarkColors.blue
            accentDeep = HomeDarkColors.blueDeep
            divider = HomeDarkColors.divider
            orange = HomeDarkColors.orange
        } else {
            bg = HomeColors.background
            card = HomeColors.card
            border = HomeColors.border
            subtleFill = HomeColors.subtleFill
            ringTrack = HomeColors.accent.opacity(0.16)
            protein = HomeColors.accent; fat = HomeDarkColors.red; carb = HomeDarkColors.green
            ringGradient = .init(colors: [HomeColors.accent, HomeDarkColors.blueDeep, HomeColors.accent])
            cardShadow = HomeColors.shadow
            cardShadowRadius = HomeMetrics.cardShadowRadius
            cardShadowY = HomeMetrics.cardShadowY
            isDark = false
            primaryText = HomeColors.primaryText
            secondaryText = HomeColors.secondaryText
            tertiaryText = HomeColors.tertiaryText
            accent = HomeColors.accent
            accentDeep = HomeDarkColors.blueDeep
            divider = Color.black.opacity(0.08)
            orange = HomeDarkColors.orange
        }
    }
}

struct AdaptiveHomeCardModifier: ViewModifier {
    let theme: AppTheme
    var cornerRadius: CGFloat = HomeDarkMetrics.cardCornerRadius

    @ViewBuilder
    func body(content: Content) -> some View {
        if theme.isDark {
            content.darkPremiumCard(cornerRadius: cornerRadius)
        } else {
            content.homePremiumLightCard(cornerRadius: cornerRadius, background: theme.card)
        }
    }
}

struct LightweightAdaptiveHomeCardModifier: ViewModifier {
    let theme: AppTheme
    var cornerRadius: CGFloat = HomeDarkMetrics.cardCornerRadius

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(theme.isDark ? Color.white.opacity(0.055) : theme.card)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(theme.border, lineWidth: HomeDarkMetrics.strokeWidth)
            }
            .shadow(
                color: theme.isDark ? .clear : .black.opacity(0.05),
                radius: theme.isDark ? 0 : 12,
                x: 0,
                y: theme.isDark ? 0 : 7
            )
    }
}

extension View {
    func adaptiveHomeCard(theme: AppTheme, cornerRadius: CGFloat = HomeDarkMetrics.cardCornerRadius) -> some View {
        modifier(AdaptiveHomeCardModifier(theme: theme, cornerRadius: cornerRadius))
    }

    func lightweightAdaptiveHomeCard(theme: AppTheme, cornerRadius: CGFloat = HomeDarkMetrics.cardCornerRadius) -> some View {
        modifier(LightweightAdaptiveHomeCardModifier(theme: theme, cornerRadius: cornerRadius))
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

struct TodayFocusCard: View {
    let focus: TodayFocus
    let theme: AppTheme
    let onAction: () -> Void

    private var eyebrow: String {
        AppLocalizer.currentLanguage == .russian ? "Фокус дня" : "Today focus"
    }

    var body: some View {
        Button(action: onAction) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    focus.tint.opacity(theme.isDark ? 0.92 : 0.18),
                                    theme.accentDeep.opacity(theme.isDark ? 0.44 : 0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(focus.tint.opacity(theme.isDark ? 0.18 : 0.12), lineWidth: HomeDarkMetrics.strokeWidth)
                        }

                    Image(systemName: focus.systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(theme.isDark ? Color.white : focus.tint)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 5) {
                    Text(eyebrow)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.tertiaryText)
                        .textCase(.uppercase)

                    Text(focus.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)

                    Text(focus.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Text(focus.actionTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [theme.accent, theme.accentDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .shadow(color: theme.accent.opacity(theme.isDark ? 0.22 : 0.16), radius: 12, x: 0, y: 6)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(16)
        .adaptiveHomeCard(theme: theme, cornerRadius: HomeDarkMetrics.cardCornerRadius)
        .padding(.horizontal)
    }
}

struct WeekRhythmCard: View {
    let snapshot: WeekRhythmSnapshot
    let theme: AppTheme
    var includesHorizontalPadding = true

    private var legendText: String {
        AppLocalizer.currentLanguage == .russian ? "Еда • вода • тренировки" : "Nutrition • water • workouts"
    }

    private var calendar: Calendar {
        Calendar.current
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.accent.opacity(theme.isDark ? 0.16 : 0.12))

                    Image(systemName: "flame.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 5) {
                    Text(snapshot.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)

                    Text(snapshot.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text(snapshot.progressText)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(theme.accent)
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                ForEach(snapshot.days) { day in
                    VStack(spacing: 7) {
                        ZStack {
                            Circle()
                                .fill(dotFill(for: day))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    Circle()
                                        .stroke(dotStroke(for: day), lineWidth: HomeDarkMetrics.strokeWidth)
                                }

                            if day.score >= 3 {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.white)
                            } else if day.score > 0 {
                                Text("\(day.score)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(theme.isDark ? Color.white.opacity(0.92) : theme.accent)
                            }
                        }

                        Text(weekdayText(for: day.date))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(calendar.isDateInToday(day.date) ? theme.accent : theme.tertiaryText)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Text(legendText)
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.tertiaryText)
        }
        .padding(18)
        .adaptiveHomeCard(theme: theme, cornerRadius: HomeDarkMetrics.cardCornerRadius)
        .padding(.horizontal, includesHorizontalPadding ? 16 : 0)
    }

    private func dotFill(for day: WeekRhythmDay) -> Color {
        switch day.score {
        case 3:
            return theme.accent
        case 2:
            return theme.accent.opacity(theme.isDark ? 0.48 : 0.26)
        case 1:
            return theme.accent.opacity(theme.isDark ? 0.22 : 0.14)
        default:
            return theme.isDark ? Color.white.opacity(0.055) : Color.black.opacity(0.045)
        }
    }

    private func dotStroke(for day: WeekRhythmDay) -> Color {
        day.score > 0 ? theme.accent.opacity(0.26) : theme.border
    }

    private func weekdayText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalizer.currentLanguage.locale
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return formatter.string(from: date).uppercased()
    }
}

struct WaterSummaryCard: View {
    let intake: Double
    let goal: Double
    let quickAddML: Int
    let theme: AppTheme
    let onSubtract: () -> Void
    let onAdd: () -> Void

    private var progress: Double {
        safeProgress(current: intake, goal: goal)
    }

    private func waterControlButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.isDark ? Color.white.opacity(0.12) : Color.white.opacity(0.98),
                                    theme.isDark ? Color.white.opacity(0.045) : Color.white.opacity(0.90)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    Circle()
                        .stroke(theme.isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.07), lineWidth: HomeDarkMetrics.strokeWidth)
                }
                .shadow(color: theme.isDark ? .black.opacity(0.28) : .black.opacity(0.08), radius: 12, x: 0, y: 7)
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.accent)

                    Text(AppLocalizer.string("tab.water"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                }

                Spacer()

                HStack(spacing: 12) {
                    waterControlButton(systemImage: "minus", action: onSubtract)

                    Text(AppLocalizer.format("unit.ml.value", quickAddML))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.tertiaryText)
                        .frame(minWidth: 56)

                    waterControlButton(systemImage: "plus", action: onAdd)
                }
            }

            Text(AppLocalizer.format("water.progress.liters", intake, goal))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(theme.primaryText)
                .contentTransition(.numericText())

            ThickProgressBar(
                fraction: progress,
                fill: theme.accent,
                track: theme.accent.opacity(0.16),
                height: 5
            )
        }
        .padding(20)
        .adaptiveHomeCard(theme: theme, cornerRadius: HomeDarkMetrics.cardCornerRadius)
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
                    RoundedRectangle(cornerRadius: HomeDarkMetrics.iconTileCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.accent.opacity(0.92),
                                    theme.accentDeep.opacity(0.48)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: HomeDarkMetrics.iconTileCornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: HomeDarkMetrics.strokeWidth)
                        }
                        .shadow(color: theme.accent.opacity(0.28), radius: 18, x: 0, y: 8)

                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    .white,
                                    Color.white.opacity(0.76)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(2)

                    Text(AppLocalizer.string("workouts.new.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.tertiaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .adaptiveHomeCard(theme: theme, cornerRadius: HomeDarkMetrics.cardCornerRadius)
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
    var onTapProtein: () -> Void = {}
    var onTapFat: () -> Void = {}
    var onTapCarbs: () -> Void = {}

    @State private var mode: RingDisplayMode = .target

    private var progress: Double {
        safeProgress(current: consumed, goal: target)
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
        case .target:    return AppLocalizer.string("unit.kcal")
        case .consumed:  return AppLocalizer.string("balance.consumed")
        case .remaining: return AppLocalizer.string("balance.remaining")
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

    private func balanceMacroRow(
        title: String,
        current: Int,
        target: Int,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)

                    Spacer(minLength: 8)

                    Text(AppLocalizer.format("macro.progress.value", current, target))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                }

                ThickProgressBar(
                    fraction: safeProgress(current: current, goal: target),
                    fill: tint,
                    track: tint.opacity(theme.isDark ? 0.16 : 0.14),
                    height: 5
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Text(AppLocalizer.string("balance.title"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)

            HStack(alignment: .center, spacing: 22) {
                Donut(
                    progress: progress,
                    lineWidth: 13,
                    track: theme.accent.opacity(0.16),
                    gradient: Gradient(colors: [
                        theme.accent,
                        theme.accentDeep,
                        theme.accent
                    ])
                )
                    .frame(width: 126, height: 126)
                    .overlay(
                        VStack(spacing: 2) {
                            Text(ringNumber.formatted(.number.grouping(.automatic)))
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(theme.primaryText)
                                .minimumScaleFactor(0.75)
                                .lineLimit(1)
                                .contentTransition(.numericText())

                            Text(ringCaption)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(theme.tertiaryText)
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

                VStack(alignment: .leading, spacing: 13) {
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { cycleMode() }
                    }) {
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(modeTitle)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(theme.tertiaryText)

                                Text(modeValueText)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(theme.secondaryText)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 4)

                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.tertiaryText)
                                .padding(.top, 2)
                        }
                    }
                    .buttonStyle(.plain)

                    balanceMacroRow(
                        title: AppLocalizer.string("macro.protein"),
                        current: proteins.current,
                        target: proteins.target,
                        tint: theme.protein,
                        action: onTapProtein
                    )

                    balanceMacroRow(
                        title: AppLocalizer.string("macro.fat"),
                        current: fats.current,
                        target: fats.target,
                        tint: theme.fat,
                        action: onTapFat
                    )

                    balanceMacroRow(
                        title: AppLocalizer.string("macro.carbs"),
                        current: carbs.current,
                        target: carbs.target,
                        tint: theme.carb,
                        action: onTapCarbs
                    )
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .padding(.bottom, 14)
        }
        .adaptiveHomeCard(theme: theme, cornerRadius: HomeDarkMetrics.cardCornerRadius)
        .padding(.horizontal)
    }
}


struct Donut: View {
    var progress: Double
    var lineWidth: CGFloat = 12
    var track: Color
    var gradient: Gradient
    private var safeProgressValue: Double { progress.clamped(to: 0...1) }
    private var safeLineWidth: CGFloat { safeDimension(lineWidth, minimum: 0.5) }

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: safeLineWidth)
            Circle()
                .trim(from: 0, to: safeProgressValue)
                .stroke(AngularGradient(gradient: gradient, center: .center),
                        style: StrokeStyle(lineWidth: safeLineWidth, lineCap: .round))
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
        safeProgress(current: current, goal: target)
    }
    private var fillColor: Color  { isOver ? HomeDarkColors.red : tint }
    private var trackColor: Color { isOver ? HomeDarkColors.red.opacity(0.25) : theme.ringTrack }
    private var valueColor: Color { isOver ? HomeDarkColors.red : theme.secondaryText }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if isOver {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(HomeDarkColors.red)
                }
                Text(title)
                    .font(compactTitle ? .subheadline.weight(.semibold) : .body)
                    .foregroundStyle(theme.primaryText)
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
    private var safeFraction: Double { fraction.clamped(to: 0...1) }
    private var safeHeight: CGFloat { safeDimension(height, minimum: 1) }

    var body: some View {
        GeometryReader { geo in
            let width = safeDimension(geo.size.width, minimum: 1)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: safeHeight / 2).fill(track)
                RoundedRectangle(cornerRadius: safeHeight / 2)
                    .fill(fill)
                    .frame(width: safeDimension(width * CGFloat(safeFraction), minimum: 0))
            }
        }
        .frame(height: safeHeight)
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
    var yesterdayEntries: (
        breakfast: [FoodEntry],
        lunch:     [FoodEntry],
        dinner:    [FoodEntry],
        snacks:    [FoodEntry]
    ) = ([], [], [], [])

    @Binding var expanded: Set<MealType>
    var onTapMeal: (MealType) -> Void
    var onRepeatYesterday: ((MealType) -> Void)? = nil
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

            repeatYesterdayButton(
                meal: .breakfast,
                todayEntries: entries.breakfast,
                yesterdayEntries: yesterdayEntries.breakfast
            )

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

            repeatYesterdayButton(
                meal: .lunch,
                todayEntries: entries.lunch,
                yesterdayEntries: yesterdayEntries.lunch
            )

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

            repeatYesterdayButton(
                meal: .dinner,
                todayEntries: entries.dinner,
                yesterdayEntries: yesterdayEntries.dinner
            )

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

    @ViewBuilder
    private func repeatYesterdayButton(
        meal: MealType,
        todayEntries: [FoodEntry],
        yesterdayEntries: [FoodEntry]
    ) -> some View {
        if todayEntries.isEmpty, !yesterdayEntries.isEmpty, onRepeatYesterday != nil {
            Button {
                onRepeatYesterday?(meal)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.12))

                        Image(systemName: "arrow.uturn.backward")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.blue)
                    }
                    .frame(width: 30, height: 30)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(AppLocalizer.string("repeat_yesterday.suggestion_title"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(repeatYesterdayPreview(for: yesterdayEntries))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(AppLocalizer.string("repeat_yesterday.action_short"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.10), in: Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.tertiarySystemBackground)))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color(.separator).opacity(0.16), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, -4)
            .padding(.horizontal, 8)
        }
    }

    private func repeatYesterdayPreview(for entries: [FoodEntry]) -> String {
        let names = entries
            .prefix(2)
            .compactMap { $0.product?.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        let calories = entries.reduce(0) { $0 + ($1.product?.calories ?? 0) }

        if names.isEmpty {
            return AppLocalizer.format("repeat_yesterday.preview_short", calories)
        }

        if entries.count > 2 {
            return AppLocalizer.format("repeat_yesterday.preview_more", names, entries.count - 2, calories)
        }

        return AppLocalizer.format("repeat_yesterday.preview", names, calories)
    }
}

struct RepeatYesterdayMealDraftItem: Identifiable, Hashable {
    let id = UUID()
    let sourceEntry: FoodEntry
    var gramsText: String

    init(sourceEntry: FoodEntry) {
        self.sourceEntry = sourceEntry
        self.gramsText = String(Int(max(1, sourceEntry.portionSafe)))
    }

    var grams: Double {
        min(max(1, (Double(gramsText) ?? sourceEntry.portionSafe).safeFinite), maxFoodPortionGrams)
    }

    private var scale: Double {
        (grams / max(1.0, sourceEntry.portionSafe)).safeFinite
    }

    var name: String {
        sourceEntry.product?.name ?? AppLocalizer.string("product.default")
    }

    var calories: Int {
        max(Int((Double(sourceEntry.product?.calories ?? 0).safeFinite * scale).rounded()), 0)
    }

    var macros: (protein: Double, fat: Double, carbs: Double) {
        (
            max((sourceEntry.product?.protein ?? 0).safeFinite * scale, 0),
            max((sourceEntry.product?.fat ?? 0).safeFinite * scale, 0),
            max((sourceEntry.product?.carbs ?? 0).safeFinite * scale, 0)
        )
    }

    static func == (lhs: RepeatYesterdayMealDraftItem, rhs: RepeatYesterdayMealDraftItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct RepeatYesterdayMealEditorScreen: View {
    @Environment(\.dismiss) private var dismiss

    let meal: MealType
    let sourceEntries: [FoodEntry]
    var onSave: ([RepeatYesterdayMealDraftItem]) -> Void

    @State private var drafts: [RepeatYesterdayMealDraftItem]

    init(
        meal: MealType,
        sourceEntries: [FoodEntry],
        onSave: @escaping ([RepeatYesterdayMealDraftItem]) -> Void
    ) {
        self.meal = meal
        self.sourceEntries = sourceEntries
        self.onSave = onSave
        _drafts = State(initialValue: sourceEntries.map(RepeatYesterdayMealDraftItem.init))
    }

    private var totalCalories: Int {
        drafts.reduce(0) { $0 + $1.calories }
    }

    private var totalMacros: (protein: Int, fat: Int, carbs: Int) {
        let protein = drafts.reduce(0.0) { $0 + $1.macros.protein }
        let fat = drafts.reduce(0.0) { $0 + $1.macros.fat }
        let carbs = drafts.reduce(0.0) { $0 + $1.macros.carbs }
        return (Int(protein), Int(fat), Int(carbs))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    headerCard

                    VStack(spacing: 1) {
                        ForEach($drafts) { $draft in
                            RepeatYesterdayDraftRow(draft: $draft) {
                                drafts.removeAll { $0.id == draft.id }
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.separator).opacity(0.16), lineWidth: 0.5)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 96)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(AppLocalizer.format("repeat_yesterday.title", meal.displayName))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider().opacity(0.25)

                    Button {
                        onSave(drafts)
                        dismiss()
                    } label: {
                        Text(AppLocalizer.string("repeat_yesterday.save"))
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(Color(.systemBackground))
                            .background(
                                Capsule()
                                    .fill(drafts.isEmpty ? Color.secondary.opacity(0.45) : Color.primary)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(drafts.isEmpty)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .background(.regularMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppLocalizer.string("common.cancel")) { dismiss() }
                }
            }
        }
    }

    private var headerCard: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))

                Image(systemName: "arrow.uturn.backward")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(AppLocalizer.string("repeat_yesterday.subtitle"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(AppLocalizer.format("unit.kcal.value", totalCalories))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    Text(AppLocalizer.format("meal.macros.summary", totalMacros.protein, totalMacros.fat, totalMacros.carbs))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct RepeatYesterdayDraftRow: View {
    @Binding var draft: RepeatYesterdayMealDraftItem
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(draft.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)

                    Spacer(minLength: 6)

                    Text(AppLocalizer.format("unit.kcal.value", draft.calories))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    gramsStepperButton(systemImage: "minus") {
                        updateGrams(by: -10)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        TextField("100", text: $draft.gramsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.headline.weight(.semibold))
                            .frame(width: 52)
                            .onChange(of: draft.gramsText) {
                                draft.gramsText = sanitizeFoodPortionText(draft.gramsText)
                            }

                        Text(AppLocalizer.string("unit.grams.short"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 80, height: 34)
                    .background(Color(.tertiarySystemGroupedBackground), in: Capsule())

                    gramsStepperButton(systemImage: "plus") {
                        updateGrams(by: 10)
                    }

                    Spacer()

                    let macros = draft.macros
                    Text(AppLocalizer.format("meal.macros.summary", Int(macros.protein), Int(macros.fat), Int(macros.carbs)))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func updateGrams(by delta: Int) {
        let next = min(Int(maxFoodPortionGrams), max(1, Int(draft.grams) + delta))
        draft.gramsText = String(next)
    }

    private func gramsStepperButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .frame(width: 30, height: 30)
                .foregroundStyle(.primary)
                .background(Color(.tertiarySystemGroupedBackground), in: Circle())
        }
        .buttonStyle(.plain)
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
            let key: String

            // AI-блюда должны отображаться одной строкой по groupID, даже если
            // у части старых записей нет корректного aiMealName.
            if let aiMealGroupID = entry.aiMealGroupID, !aiMealGroupID.isEmpty {
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
            let isGroupedAIMeal = key.hasPrefix("ai-")
            let normalizedMealName = entries
                .compactMap { $0.aiMealName?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty })

            let title = isGroupedAIMeal
                ? (normalizedMealName ?? first.product?.name ?? AppLocalizer.string("product.default"))
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
        let safeNewPortion = min(max(newPortion.safeFinite, 1), maxFoodPortionGrams)
        guard let product = entry.product, safeNewPortion > 0 else { return }
        let old = max(1.0, entry.portionSafe)
        let k = (safeNewPortion / old).safeFinite
        product.protein = max(product.protein.safeFinite * k, 0)
        product.fat = max(product.fat.safeFinite * k, 0)
        product.carbs = max(product.carbs.safeFinite * k, 0)
        product.calories = max(Int((Double(product.calories).safeFinite * k).rounded()), 0)
        entry.portion = safeNewPortion
        do { try modelContext.save() } catch {}
    }

    private func applyNewPortion(_ entries: [FoodEntry], newTotalPortion: Double) {
        let safeNewTotalPortion = min(max(newTotalPortion.safeFinite, 1), maxFoodPortionGrams)
        let oldTotal = max(1.0, entries.reduce(0.0) { $0 + $1.portionSafe }.safeFinite)
        let k = (safeNewTotalPortion / oldTotal).safeFinite

        for entry in entries {
            if let product = entry.product {
                product.protein = max(product.protein.safeFinite * k, 0)
                product.fat = max(product.fat.safeFinite * k, 0)
                product.carbs = max(product.carbs.safeFinite * k, 0)
                product.calories = max(Int((Double(product.calories).safeFinite * k).rounded()), 0)
            }
            entry.portion = min(max(1.0, (entry.portionSafe * k).safeFinite), maxFoodPortionGrams)
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
        _gramsText = State(initialValue: String(Int(max(1, entry.portionSafe))))
    }

    private var previewScale: Double {
        guard entry.portionSafe > 0 else { return 1 }
        return (gramsValue / max(1.0, entry.portionSafe)).safeFinite
    }

    private var gramsValue: Double {
        min(max(1, (Double(gramsText) ?? entry.portionSafe).safeFinite), maxFoodPortionGrams)
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
                                .onChange(of: gramsText) { gramsText = sanitizeFoodPortionText(gramsText) }

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
                        Text(AppLocalizer.format("entry.will_be_kcal", max(Int((Double(pr.calories).safeFinite * previewScale).rounded()), 0)))
                            .font(.system(size: 30, weight: .bold))

                        VStack(spacing: 10) {
                            PortionMetricRow(title: AppLocalizer.string("macro.protein"), value: max(pr.protein.safeFinite * previewScale, 0))
                            PortionMetricRow(title: AppLocalizer.string("macro.fat"), value: max(pr.fat.safeFinite * previewScale, 0))
                            PortionMetricRow(title: AppLocalizer.string("macro.carbs"), value: max(pr.carbs.safeFinite * previewScale, 0))
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
        let next = min(Int(maxFoodPortionGrams), max(1, Int(gramsValue) + delta))
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
        let factor = (max(1.0, entry.portionSafe) / 100).safeFinite
        product.name = customProduct.name
        product.calories = max(Int((Double(customProduct.calories).safeFinite * factor).rounded()), 0)
        product.protein = max(customProduct.protein.safeFinite * factor, 0)
        product.fat = max(customProduct.fat.safeFinite * factor, 0)
        product.carbs = max(customProduct.carbs.safeFinite * factor, 0)
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
            Text(String(format: "%.1f %@", max(value.safeFinite, 0), AppLocalizer.string("unit.grams.short")))
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
        let initialGrams = max(1, Int(entries.reduce(0.0) { $0 + $1.portionSafe }))
        _gramsText = State(initialValue: String(initialGrams))
    }

    private var totalPortion: Double {
        max(1.0, entries.reduce(0.0) { $0 + $1.portionSafe }.safeFinite)
    }

    private var gramsValue: Double {
        min(max(1, (Double(gramsText) ?? totalPortion).safeFinite), maxFoodPortionGrams)
    }

    private var previewScale: Double {
        (gramsValue / totalPortion).safeFinite
    }

    private var totalCalories: Int {
        entries.reduce(0) { $0 + ($1.product?.calories ?? 0) }
    }

    private var totalProtein: Double {
        entries.reduce(0.0) { $0 + ($1.product?.protein ?? 0).safeFinite }
    }

    private var totalFat: Double {
        entries.reduce(0.0) { $0 + ($1.product?.fat ?? 0).safeFinite }
    }

    private var totalCarbs: Double {
        entries.reduce(0.0) { $0 + ($1.product?.carbs ?? 0).safeFinite }
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
                                .onChange(of: gramsText) { gramsText = sanitizeFoodPortionText(gramsText) }

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
                    Text(AppLocalizer.format("entry.will_be_kcal", max(Int((Double(totalCalories).safeFinite * previewScale).rounded()), 0)))
                        .font(.system(size: 30, weight: .bold))

                    VStack(spacing: 10) {
                        PortionMetricRow(title: AppLocalizer.string("macro.protein"), value: max(totalProtein * previewScale, 0))
                        PortionMetricRow(title: AppLocalizer.string("macro.fat"), value: max(totalFat * previewScale, 0))
                        PortionMetricRow(title: AppLocalizer.string("macro.carbs"), value: max(totalCarbs * previewScale, 0))
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
        let next = min(Int(maxFoodPortionGrams), max(1, Int(gramsValue) + delta))
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

private func sanitizeFoodPortionText(_ text: String) -> String {
    let digits = text.filter(\.isNumber)
    guard let value = Double(digits), value > 0 else { return digits }
    return String(Int(min(value, maxFoodPortionGrams)))
}

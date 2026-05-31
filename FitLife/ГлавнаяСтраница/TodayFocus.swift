import SwiftUI

enum TodayFocusAction {
    case addFood
    case addWater
    case openWorkouts
    case none
}

struct TodayFocus {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let actionTitle: String
    let action: TodayFocusAction
}

enum TodayFocusResolver {
    static func resolve(
        consumedCalories: Int,
        targetCalories: Int,
        waterIntake: Double,
        waterGoal: Double,
        hasCompletedWorkoutToday: Bool,
        theme: AppTheme
    ) -> TodayFocus {
        let waterProgress = safeProgress(current: waterIntake, goal: waterGoal)
        let calorieProgress = safeProgress(current: Double(consumedCalories), goal: Double(targetCalories))

        if consumedCalories <= 0 {
            return TodayFocus(
                title: localized(ru: "Начни с питания", en: "Start with nutrition"),
                subtitle: localized(ru: "Добавь первый приём пищи, чтобы день был под контролем.", en: "Log your first meal to keep the day under control."),
                systemImage: "fork.knife",
                tint: theme.accent,
                actionTitle: localized(ru: "Добавить", en: "Add"),
                action: .addFood
            )
        }

        if waterProgress < 0.5 {
            return TodayFocus(
                title: localized(ru: "Добери воду", en: "Hydrate next"),
                subtitle: localized(ru: "Небольшая порция воды поможет держать темп дня.", en: "A small water portion helps keep the day on track."),
                systemImage: "drop.fill",
                tint: theme.accent,
                actionTitle: localized(ru: "Добавить", en: "Add"),
                action: .addWater
            )
        }

        if calorieProgress < 0.65 {
            return TodayFocus(
                title: localized(ru: "Проверь питание", en: "Check nutrition"),
                subtitle: localized(ru: "До цели ещё есть запас. Добавь следующий приём, когда поешь.", en: "There is still room today. Log the next meal when you eat."),
                systemImage: "chart.pie.fill",
                tint: theme.accent,
                actionTitle: localized(ru: "Открыть", en: "Open"),
                action: .addFood
            )
        }

        if hasCompletedWorkoutToday {
            if waterProgress < 1 {
                return TodayFocus(
                    title: localized(ru: "Добери воду", en: "Finish hydration"),
                    subtitle: localized(ru: "Тренировка готова. Осталось закрыть норму воды.", en: "Workout is complete. Finish your water target next."),
                    systemImage: "drop.fill",
                    tint: theme.accent,
                    actionTitle: localized(ru: "Вода", en: "Water"),
                    action: .addWater
                )
            }

            return TodayFocus(
                title: localized(ru: "День закрыт", en: "Day complete"),
                subtitle: localized(ru: "Питание, вода и тренировка уже в работе. Хороший темп.", en: "Nutrition, water, and workout are on track. Good pace."),
                systemImage: "checkmark.seal.fill",
                tint: theme.accent,
                actionTitle: localized(ru: "Готово", en: "Done"),
                action: .none
            )
        }

        return TodayFocus(
            title: localized(ru: "День под контролем", en: "Day under control"),
            subtitle: localized(ru: "Питание и вода уже в работе. Можно перейти к тренировкам.", en: "Nutrition and water are moving. Workouts are a good next step."),
            systemImage: "checkmark.seal.fill",
            tint: theme.accent,
            actionTitle: localized(ru: "Тренировки", en: "Workouts"),
            action: .openWorkouts
        )
    }

    private static func localized(ru: String, en: String) -> String {
        AppLocalizer.currentLanguage == .russian ? ru : en
    }
}

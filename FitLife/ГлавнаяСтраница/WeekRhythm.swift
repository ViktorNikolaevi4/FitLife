import Foundation

struct WeekRhythmDay: Identifiable {
    let date: Date
    let hasNutrition: Bool
    let hasWaterGoal: Bool
    let hasWorkout: Bool

    var id: Date { date }
    var score: Int {
        [hasNutrition, hasWaterGoal, hasWorkout].filter { $0 }.count
    }
}

struct WeekRhythmSnapshot {
    let days: [WeekRhythmDay]

    static let empty = WeekRhythmSnapshot(days: [])

    var activeDays: Int {
        days.filter { $0.score > 0 }.count
    }

    var strongDays: Int {
        days.filter { $0.score >= 2 }.count
    }

    var totalSignals: Int {
        days.reduce(0) { $0 + $1.score }
    }

    var title: String {
        AppLocalizer.currentLanguage == .russian ? "Ритм недели" : "Weekly rhythm"
    }

    var subtitle: String {
        if strongDays >= 5 {
            return localized(
                ru: "Отличный темп: \(strongDays) дней с хорошим ритмом.",
                en: "Strong pace: \(strongDays) days with a solid rhythm."
            )
        }

        if activeDays > 0 {
            return localized(
                ru: "Активных дней: \(activeDays) из 7. Держим темп постепенно.",
                en: "Active days: \(activeDays) of 7. Keep building the pace."
            )
        }

        return localized(
            ru: "Начни с одного действия сегодня: еда, вода или тренировка.",
            en: "Start with one action today: nutrition, water, or workout."
        )
    }

    var progressText: String {
        "\(strongDays)/7"
    }

    private func localized(ru: String, en: String) -> String {
        AppLocalizer.currentLanguage == .russian ? ru : en
    }
}

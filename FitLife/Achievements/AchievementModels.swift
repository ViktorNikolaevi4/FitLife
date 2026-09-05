import Foundation
import SwiftData

@Model
final class UserAchievementProgress {
    @Attribute(.unique) var scopeID: String = ""
    var ownerId: String = ""
    var genderRawValue: String = Gender.male.rawValue
    var totalXP: Int = 0
    var xpResetAt: Date?
    var achievementResetAt: Date?
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastActiveDate: Date?
    var migrationVersion: Int = 2
    var updatedAt: Date = Date.now
    var totalActiveDays: Int = 0
    var totalWorkouts: Int = 0
    var maximumWeeklyWorkouts: Int = 0
    var totalWaterGoalDays: Int = 0
    var maximumNutritionTargetDaysPerWeek: Int = 0
    var activeDaysInLastMonth: Int = 0
    /// Extensible storage lets the catalogue grow without adding a SwiftData column per achievement.
    var achievementMetricsJSON: String = "{}"

    init(scopeID: String, ownerId: String, gender: Gender) {
        self.scopeID = scopeID
        self.ownerId = ownerId
        self.genderRawValue = gender.rawValue
    }

    func metricValue(for id: AchievementID) -> Int {
        metricValues[id.rawValue] ?? 0
    }

    func setMetricValues(_ values: [AchievementID: Int]) {
        let rawValues = Dictionary(uniqueKeysWithValues: values.map { ($0.key.rawValue, max($0.value, 0)) })
        guard let data = try? JSONEncoder().encode(rawValues),
              let json = String(data: data, encoding: .utf8) else { return }
        achievementMetricsJSON = json
    }

    private var metricValues: [String: Int] {
        guard let data = achievementMetricsJSON.data(using: .utf8),
              let values = try? JSONDecoder().decode([String: Int].self, from: data) else { return [:] }
        return values
    }
}

@Model
final class XPTransaction {
    @Attribute(.unique) var compositeEventID: String = ""
    var scopeID: String = ""
    var eventID: String = ""
    var amount: Int = 0
    var reason: String = ""
    var occurredAt: Date = Date.now

    init(scopeID: String, eventID: String, amount: Int, reason: String, occurredAt: Date) {
        self.compositeEventID = "\(scopeID):\(eventID)"
        self.scopeID = scopeID
        self.eventID = eventID
        self.amount = max(amount, 0)
        self.reason = reason
        self.occurredAt = occurredAt
    }
}

@Model
final class UnlockedAchievement {
    @Attribute(.unique) var compositeID: String = ""
    var scopeID: String = ""
    var achievementID: String = ""
    var unlockedAt: Date = Date.now
    var rewardedXP: Int = 0
    /// Defaults to seen for records created by older app versions during migration.
    var isUnseen: Bool = false

    init(scopeID: String, achievementID: AchievementID, unlockedAt: Date, rewardedXP: Int) {
        self.compositeID = "\(scopeID):\(achievementID.rawValue)"
        self.scopeID = scopeID
        self.achievementID = achievementID.rawValue
        self.unlockedAt = unlockedAt
        self.rewardedXP = max(rewardedXP, 0)
        self.isUnseen = true
    }
}

struct AchievementReconciliationResult {
    let unlockedIDs: [AchievementID]
    let awardedXP: Int
    let previousLevel: Int
    let currentLevel: Int
    let totalXP: Int

    var shouldCelebrate: Bool {
        unlockedIDs.isEmpty == false || currentLevel > previousLevel
    }
}

enum AchievementID: String, CaseIterable, Codable {
    case firstAssignedWorkout, firstWorkout, firstWaterLog, firstFoodLog, baselineMeasurement, firstHealthConnection
    case workouts5, workouts25, workouts50, workouts100, workouts250
    case assignedWorkouts25, firstStrengthPR, strongFoundation, backToTraining
    case firstWaterGoal, waterGoal7Total, waterStreak7, waterGoal30Total, waterGoal100Total
    case firstNutritionTarget, nutritionWeek5, nutritionStreak14, nutritionGoal30Total, nutritionWeeks12
    case firstStepGoal, stepGoal7Total, stepGoal30Total, stepGoal100Total, millionSteps
    case firstCheckIn, checkIns4, checkIns10, coachMonth, coachThreeMonths, coachHalfYear
    case measurements4, measurements12, measurements26, measurements52
}

enum AchievementCategory: String, CaseIterable, Codable {
    case firstSteps, workouts, water, nutrition, steps, coach, measurements
}

enum AchievementVisibility: String, Codable {
    case standard
    case hiddenUntilUnlocked
}

struct AchievementDefinition: Identifiable {
    let id: AchievementID
    let titleKey: String
    let descriptionKey: String
    let icon: String
    let category: AchievementCategory
    let target: Int
    let xpReward: Int
    let visibility: AchievementVisibility

    init(id: AchievementID, icon: String, category: AchievementCategory, target: Int, xpReward: Int, visibility: AchievementVisibility = .standard) {
        self.id = id
        self.titleKey = "profile.achievements.badge.\(id.rawValue)"
        self.descriptionKey = "profile.achievements.description.\(id.rawValue)"
        self.icon = icon
        self.category = category
        self.target = target
        self.xpReward = xpReward
        self.visibility = visibility
    }
}

enum AchievementCatalog {
    static let definitions: [AchievementDefinition] = [
        .init(id: .firstAssignedWorkout, icon: "checkmark.circle.fill", category: .firstSteps, target: 1, xpReward: 50),
        .init(id: .firstWorkout, icon: "dumbbell.fill", category: .firstSteps, target: 1, xpReward: 50),
        .init(id: .firstWaterLog, icon: "drop.fill", category: .firstSteps, target: 1, xpReward: 25),
        .init(id: .firstFoodLog, icon: "fork.knife", category: .firstSteps, target: 1, xpReward: 25),
        .init(id: .baselineMeasurement, icon: "ruler.fill", category: .firstSteps, target: 1, xpReward: 50),
        .init(id: .firstHealthConnection, icon: "heart.fill", category: .firstSteps, target: 1, xpReward: 25),

        .init(id: .workouts5, icon: "dumbbell.fill", category: .workouts, target: 5, xpReward: 100),
        .init(id: .workouts25, icon: "dumbbell.fill", category: .workouts, target: 25, xpReward: 250),
        .init(id: .workouts50, icon: "dumbbell.fill", category: .workouts, target: 50, xpReward: 400),
        .init(id: .workouts100, icon: "medal.fill", category: .workouts, target: 100, xpReward: 750),
        .init(id: .workouts250, icon: "trophy.fill", category: .workouts, target: 250, xpReward: 1_000),
        .init(id: .assignedWorkouts25, icon: "list.clipboard.fill", category: .workouts, target: 25, xpReward: 300),
        .init(id: .firstStrengthPR, icon: "arrow.up.right", category: .workouts, target: 1, xpReward: 250, visibility: .hiddenUntilUnlocked),
        .init(id: .strongFoundation, icon: "chart.line.uptrend.xyaxis", category: .workouts, target: 3, xpReward: 500, visibility: .hiddenUntilUnlocked),

        .init(id: .backToTraining, icon: "arrow.uturn.forward.circle.fill", category: .workouts, target: 1, xpReward: 150, visibility: .hiddenUntilUnlocked),

        .init(id: .firstWaterGoal, icon: "drop.fill", category: .water, target: 1, xpReward: 50),
        .init(id: .waterGoal7Total, icon: "drop.fill", category: .water, target: 7, xpReward: 100),
        .init(id: .waterStreak7, icon: "drop.circle.fill", category: .water, target: 7, xpReward: 200),
        .init(id: .waterGoal30Total, icon: "water.waves", category: .water, target: 30, xpReward: 400),
        .init(id: .waterGoal100Total, icon: "water.waves", category: .water, target: 100, xpReward: 750),

        .init(id: .firstNutritionTarget, icon: "fork.knife", category: .nutrition, target: 1, xpReward: 50),
        .init(id: .nutritionWeek5, icon: "calendar.badge.checkmark", category: .nutrition, target: 5, xpReward: 200),
        .init(id: .nutritionStreak14, icon: "fork.knife.circle.fill", category: .nutrition, target: 14, xpReward: 250),
        .init(id: .nutritionGoal30Total, icon: "chart.bar.fill", category: .nutrition, target: 30, xpReward: 400),
        .init(id: .nutritionWeeks12, icon: "calendar", category: .nutrition, target: 12, xpReward: 750),

        .init(id: .firstStepGoal, icon: "figure.walk", category: .steps, target: 1, xpReward: 50),
        .init(id: .stepGoal7Total, icon: "figure.walk", category: .steps, target: 7, xpReward: 100),
        .init(id: .stepGoal30Total, icon: "shoeprints.fill", category: .steps, target: 30, xpReward: 400),
        .init(id: .stepGoal100Total, icon: "shoeprints.fill", category: .steps, target: 100, xpReward: 750),
        .init(id: .millionSteps, icon: "map.fill", category: .steps, target: 1_000_000, xpReward: 1_500, visibility: .hiddenUntilUnlocked),

        .init(id: .firstCheckIn, icon: "checkmark.bubble.fill", category: .coach, target: 1, xpReward: 50),
        .init(id: .checkIns4, icon: "checkmark.bubble.fill", category: .coach, target: 4, xpReward: 300),
        .init(id: .checkIns10, icon: "person.2.fill", category: .coach, target: 10, xpReward: 500),
        .init(id: .coachMonth, icon: "calendar.badge.checkmark", category: .coach, target: 30, xpReward: 250),
        .init(id: .coachThreeMonths, icon: "person.2.fill", category: .coach, target: 90, xpReward: 750),
        .init(id: .coachHalfYear, icon: "star.fill", category: .coach, target: 180, xpReward: 1_000),

        .init(id: .measurements4, icon: "ruler.fill", category: .measurements, target: 4, xpReward: 200),
        .init(id: .measurements12, icon: "ruler.fill", category: .measurements, target: 12, xpReward: 400),
        .init(id: .measurements26, icon: "chart.line.uptrend.xyaxis", category: .measurements, target: 26, xpReward: 750),
        .init(id: .measurements52, icon: "calendar", category: .measurements, target: 52, xpReward: 1_000)
    ]

    static func definition(for id: AchievementID) -> AchievementDefinition? {
        definitions.first { $0.id == id }
    }
}

struct AchievementLevelProgress {
    let level: Int
    let totalXP: Int
    let xpInsideLevel: Int
    let requiredXP: Int

    var isMaximumLevel: Bool { level >= AchievementLevelCalculator.maximumLevel }
    var remainingXP: Int { isMaximumLevel ? 0 : max(requiredXP - xpInsideLevel, 0) }
    var fraction: Double {
        if isMaximumLevel { return 1 }
        guard requiredXP > 0 else { return 0 }
        return min(max(Double(xpInsideLevel) / Double(requiredXP), 0), 1)
    }
}

enum AchievementLevelCalculator {
    static let maximumLevel = 50

    static var maximumLevelTotalXP: Int { totalXPRequired(toReach: maximumLevel) }

    static func requiredXP(for level: Int) -> Int {
        250 + max(level - 1, 0) * 20
    }

    static func totalXPRequired(toReach level: Int) -> Int {
        guard level > 1 else { return 0 }
        return (1..<level).reduce(0) { $0 + requiredXP(for: $1) }
    }

    static func progress(totalXP: Int) -> AchievementLevelProgress {
        let safeXP = max(totalXP, 0)
        var level = 1
        var remaining = safeXP
        var requirement = requiredXP(for: level)

        while level < maximumLevel && remaining >= requirement {
            remaining -= requirement
            level += 1
            requirement = requiredXP(for: level)
        }

        return AchievementLevelProgress(level: level, totalXP: safeXP, xpInsideLevel: remaining, requiredXP: requirement)
    }
}

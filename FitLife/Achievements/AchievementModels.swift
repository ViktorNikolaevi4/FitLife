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
    var migrationVersion: Int = 3
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
    case workouts5, workouts10, workouts25, workouts50, workouts75, workouts100, workouts150, workouts250
    case assignedWorkouts5, assignedWorkouts10, assignedWorkouts25, assignedWorkouts50
    case firstStrengthPR, strongFoundation, strengthExercises5, backToTraining
    case firstWaterGoal, waterGoal7Total, waterGoal14Total, waterGoal30Total, waterGoal60Total, waterGoal100Total
    case waterStreak7, waterStreak14, waterStreak30
    case firstNutritionTarget, nutritionGoal7Total, nutritionGoal14Total, nutritionGoal30Total, nutritionGoal60Total
    case nutritionWeek5, nutritionWeeks4, nutritionWeeks8, nutritionWeeks12
    case nutritionStreak7, nutritionStreak14, nutritionStreak30
    case firstStepGoal, stepGoal7Total, stepGoal14Total, stepGoal30Total, stepGoal60Total, stepGoal100Total
    case steps250K, steps500K, millionSteps
    case firstCheckIn, checkIns4, checkIns10, checkIns25
    case coachMonth, coachTwoMonths, coachThreeMonths, coachFourMonths, coachHalfYear
    case measurements4, measurements8, measurements12, measurements18, measurements26, measurements39, measurements52
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
        .init(id: .workouts10, icon: "dumbbell.fill", category: .workouts, target: 10, xpReward: 75),
        .init(id: .workouts25, icon: "dumbbell.fill", category: .workouts, target: 25, xpReward: 200),
        .init(id: .workouts50, icon: "dumbbell.fill", category: .workouts, target: 50, xpReward: 300),
        .init(id: .workouts75, icon: "medal.fill", category: .workouts, target: 75, xpReward: 150),
        .init(id: .workouts100, icon: "medal.fill", category: .workouts, target: 100, xpReward: 550),
        .init(id: .workouts150, icon: "trophy.fill", category: .workouts, target: 150, xpReward: 250),
        .init(id: .workouts250, icon: "trophy.fill", category: .workouts, target: 250, xpReward: 600),
        .init(id: .assignedWorkouts5, icon: "list.clipboard.fill", category: .workouts, target: 5, xpReward: 75),
        .init(id: .assignedWorkouts10, icon: "list.clipboard.fill", category: .workouts, target: 10, xpReward: 100),
        .init(id: .assignedWorkouts25, icon: "list.clipboard.fill", category: .workouts, target: 25, xpReward: 225),
        .init(id: .assignedWorkouts50, icon: "list.clipboard.fill", category: .workouts, target: 50, xpReward: 200),
        .init(id: .firstStrengthPR, icon: "arrow.up.right", category: .workouts, target: 1, xpReward: 200, visibility: .hiddenUntilUnlocked),
        .init(id: .strongFoundation, icon: "chart.line.uptrend.xyaxis", category: .workouts, target: 3, xpReward: 350, visibility: .hiddenUntilUnlocked),
        .init(id: .strengthExercises5, icon: "bolt.fill", category: .workouts, target: 5, xpReward: 250, visibility: .hiddenUntilUnlocked),

        .init(id: .backToTraining, icon: "arrow.uturn.forward.circle.fill", category: .workouts, target: 1, xpReward: 150, visibility: .hiddenUntilUnlocked),

        .init(id: .firstWaterGoal, icon: "drop.fill", category: .water, target: 1, xpReward: 50),
        .init(id: .waterGoal7Total, icon: "drop.fill", category: .water, target: 7, xpReward: 100),
        .init(id: .waterGoal14Total, icon: "drop.fill", category: .water, target: 14, xpReward: 75),
        .init(id: .waterGoal30Total, icon: "water.waves", category: .water, target: 30, xpReward: 300),
        .init(id: .waterGoal60Total, icon: "water.waves", category: .water, target: 60, xpReward: 150),
        .init(id: .waterGoal100Total, icon: "water.waves", category: .water, target: 100, xpReward: 500),
        .init(id: .waterStreak7, icon: "drop.circle.fill", category: .water, target: 7, xpReward: 150),
        .init(id: .waterStreak14, icon: "drop.circle.fill", category: .water, target: 14, xpReward: 100),
        .init(id: .waterStreak30, icon: "drop.circle.fill", category: .water, target: 30, xpReward: 200),

        .init(id: .firstNutritionTarget, icon: "fork.knife", category: .nutrition, target: 1, xpReward: 50),
        .init(id: .nutritionGoal7Total, icon: "fork.knife", category: .nutrition, target: 7, xpReward: 75),
        .init(id: .nutritionGoal14Total, icon: "fork.knife", category: .nutrition, target: 14, xpReward: 75),
        .init(id: .nutritionGoal30Total, icon: "chart.bar.fill", category: .nutrition, target: 30, xpReward: 300),
        .init(id: .nutritionGoal60Total, icon: "chart.bar.fill", category: .nutrition, target: 60, xpReward: 150),
        .init(id: .nutritionWeek5, icon: "calendar.badge.checkmark", category: .nutrition, target: 5, xpReward: 150),
        .init(id: .nutritionWeeks4, icon: "calendar", category: .nutrition, target: 4, xpReward: 150),
        .init(id: .nutritionWeeks8, icon: "calendar", category: .nutrition, target: 8, xpReward: 200),
        .init(id: .nutritionWeeks12, icon: "calendar", category: .nutrition, target: 12, xpReward: 500),
        .init(id: .nutritionStreak7, icon: "fork.knife.circle.fill", category: .nutrition, target: 7, xpReward: 75),
        .init(id: .nutritionStreak14, icon: "fork.knife.circle.fill", category: .nutrition, target: 14, xpReward: 200),
        .init(id: .nutritionStreak30, icon: "fork.knife.circle.fill", category: .nutrition, target: 30, xpReward: 200),

        .init(id: .firstStepGoal, icon: "figure.walk", category: .steps, target: 1, xpReward: 50),
        .init(id: .stepGoal7Total, icon: "figure.walk", category: .steps, target: 7, xpReward: 100),
        .init(id: .stepGoal14Total, icon: "figure.walk", category: .steps, target: 14, xpReward: 75),
        .init(id: .stepGoal30Total, icon: "shoeprints.fill", category: .steps, target: 30, xpReward: 300),
        .init(id: .stepGoal60Total, icon: "shoeprints.fill", category: .steps, target: 60, xpReward: 150),
        .init(id: .stepGoal100Total, icon: "shoeprints.fill", category: .steps, target: 100, xpReward: 550),
        .init(id: .steps250K, icon: "map.fill", category: .steps, target: 250_000, xpReward: 100),
        .init(id: .steps500K, icon: "map.fill", category: .steps, target: 500_000, xpReward: 150),
        .init(id: .millionSteps, icon: "map.fill", category: .steps, target: 1_000_000, xpReward: 900, visibility: .hiddenUntilUnlocked),

        .init(id: .firstCheckIn, icon: "checkmark.bubble.fill", category: .coach, target: 1, xpReward: 50),
        .init(id: .checkIns4, icon: "checkmark.bubble.fill", category: .coach, target: 4, xpReward: 250),
        .init(id: .checkIns10, icon: "person.2.fill", category: .coach, target: 10, xpReward: 400),
        .init(id: .checkIns25, icon: "person.2.fill", category: .coach, target: 25, xpReward: 200),
        .init(id: .coachMonth, icon: "calendar.badge.checkmark", category: .coach, target: 30, xpReward: 200),
        .init(id: .coachTwoMonths, icon: "calendar.badge.checkmark", category: .coach, target: 60, xpReward: 150),
        .init(id: .coachThreeMonths, icon: "person.2.fill", category: .coach, target: 90, xpReward: 550),
        .init(id: .coachFourMonths, icon: "person.2.fill", category: .coach, target: 120, xpReward: 250),
        .init(id: .coachHalfYear, icon: "star.fill", category: .coach, target: 180, xpReward: 700),

        .init(id: .measurements4, icon: "ruler.fill", category: .measurements, target: 4, xpReward: 150),
        .init(id: .measurements8, icon: "ruler.fill", category: .measurements, target: 8, xpReward: 100),
        .init(id: .measurements12, icon: "ruler.fill", category: .measurements, target: 12, xpReward: 300),
        .init(id: .measurements18, icon: "chart.line.uptrend.xyaxis", category: .measurements, target: 18, xpReward: 200),
        .init(id: .measurements26, icon: "chart.line.uptrend.xyaxis", category: .measurements, target: 26, xpReward: 550),
        .init(id: .measurements39, icon: "calendar", category: .measurements, target: 39, xpReward: 300),
        .init(id: .measurements52, icon: "calendar", category: .measurements, target: 52, xpReward: 600)
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

import Foundation
import SwiftData

@MainActor
enum AchievementEngine {
    static func scopeID(ownerId: String, gender: Gender) -> String {
        "\(ownerId):\(gender.rawValue)"
    }

    static func reconcile(
        ownerId: String,
        gender: Gender,
        userData: UserData,
        workouts: [WorkoutSession],
        foodEntries: [FoodEntry],
        waterEntries: [WaterIntake],
        measurements: [BodyMeasurements],
        externalSnapshot: AchievementExternalSnapshot? = nil,
        modelContext: ModelContext,
        now: Date = .now
    ) throws -> AchievementReconciliationResult {
        let scope = scopeID(ownerId: ownerId, gender: gender)
        let calendar = Calendar.current

        let allProgress = try modelContext.fetch(FetchDescriptor<UserAchievementProgress>())
        let progress: UserAchievementProgress
        if let existing = allProgress.first(where: { $0.scopeID == scope }) {
            progress = existing
        } else {
            progress = UserAchievementProgress(scopeID: scope, ownerId: ownerId, gender: gender)
            modelContext.insert(progress)
        }
        let previousTotalXP = progress.totalXP
        let previousLevel = AchievementLevelCalculator.progress(totalXP: previousTotalXP).level

        let achievementStart = progress.achievementResetAt ?? .distantPast
        let matchingWorkouts = workouts
            .filter {
                $0.ownerId == ownerId &&
                $0.gender == gender &&
                $0.endedAt != nil &&
                ($0.endedAt ?? $0.createdAt) >= achievementStart
            }
            .sorted { ($0.endedAt ?? $0.createdAt) < ($1.endedAt ?? $1.createdAt) }
        let matchingFood = foodEntries.filter {
            $0.ownerId == ownerId && $0.gender == gender && $0.date >= achievementStart
        }
        let matchingWater = waterEntries.filter {
            ($0.ownerId == ownerId || $0.user?.id == userData.id) &&
            $0.gender == gender &&
            $0.date >= achievementStart
        }
        let matchingMeasurements = measurements.filter {
            $0.ownerId == ownerId && $0.date >= achievementStart
        }

        let existingTransactions = try modelContext.fetch(FetchDescriptor<XPTransaction>())
            .filter { $0.scopeID == scope }
        var transactionIDs = Set(existingTransactions.map(\.eventID))
        var newlyAwardedXP = 0

        func award(eventID: String, amount: Int, reason: String, occurredAt: Date) {
            guard transactionIDs.insert(eventID).inserted else { return }
            modelContext.insert(
                XPTransaction(scopeID: scope, eventID: eventID, amount: amount, reason: reason, occurredAt: occurredAt)
            )
            newlyAwardedXP += max(amount, 0)
        }

        let routineXPStart = progress.xpResetAt ?? .distantPast

        for workout in matchingWorkouts where (workout.endedAt ?? workout.createdAt) >= routineXPStart {
            award(
                eventID: "workout:\(workout.id.uuidString):completed",
                amount: 100,
                reason: "workout_completed",
                occurredAt: workout.endedAt ?? workout.createdAt
            )
        }

        let waterGoal = max(userData.weight.safeFinite * 35.0 / 1_000.0, 0)
        let waterByDay = Dictionary(grouping: matchingWater) { calendar.startOfDay(for: $0.date) }
            .mapValues { $0.reduce(0) { $0 + max($1.intake.safeFinite, 0) } }
        let completedWaterDays = Set(waterByDay.compactMap { day, total in
            waterGoal > 0 && total >= waterGoal ? day : nil
        })
        for day in completedWaterDays where day >= routineXPStart {
            award(
                eventID: "water:\(dayKey(day, calendar: calendar)):goal",
                amount: 25,
                reason: "water_goal",
                occurredAt: day
            )
        }

        let foodByDay = Dictionary(grouping: matchingFood) { calendar.startOfDay(for: $0.date) }
        var nutritionTargetDays = Set<Date>()
        for (day, entries) in foodByDay {
            if day >= routineXPStart {
                award(
                    eventID: "nutrition:\(dayKey(day, calendar: calendar)):logged",
                    amount: 20,
                    reason: "nutrition_logged",
                    occurredAt: day
                )
            }
            let calories = entries.reduce(0) { $0 + max($1.product?.calories ?? 0, 0) }
            let lower = Int(Double(max(userData.calories, 0)) * 0.90)
            let upper = Int(Double(max(userData.calories, 0)) * 1.10)
            if userData.calories > 0 && calories >= lower && calories <= upper {
                nutritionTargetDays.insert(day)
                if day >= routineXPStart {
                    award(
                        eventID: "nutrition:\(dayKey(day, calendar: calendar)):target",
                        amount: 30,
                        reason: "nutrition_target",
                        occurredAt: day
                    )
                }
            }
        }

        let workoutDays = Set(matchingWorkouts.map { calendar.startOfDay(for: $0.endedAt ?? $0.createdAt) })
        let activeDays = workoutDays.union(completedWaterDays).union(foodByDay.keys)
        let activityStreak = streakValues(days: activeDays, now: now, calendar: calendar)
        let waterStreak = streakValues(days: completedWaterDays, now: now, calendar: calendar).longest
        let nutritionStreak = streakValues(days: nutritionTargetDays, now: now, calendar: calendar).longest

        let nutritionByWeek = Dictionary(grouping: nutritionTargetDays) {
            weekStart(for: $0, calendar: calendar)
        }
        let maximumNutritionDaysInWeek = nutritionByWeek.values.map(\.count).max() ?? 0
        let successfulNutritionWeeks = nutritionByWeek.values.filter { $0.count >= 5 }.count
        let assignedWorkoutCount = matchingWorkouts.filter {
            guard let id = $0.remoteAssignmentId else { return false }
            return id.isEmpty == false
        }.count
        let improvedStrengthExercises = strengthImprovementCount(workouts: matchingWorkouts)
        let regularMeasurements = regularMeasurementCount(matchingMeasurements, calendar: calendar)
        let returnedAfterLongBreak = hasWorkoutReturn(workouts: matchingWorkouts, calendar: calendar) ? 1 : 0

        var values: [AchievementID: Int] = [
            .firstAssignedWorkout: assignedWorkoutCount,
            .firstWorkout: matchingWorkouts.count,
            .firstWaterLog: matchingWater.count,
            .firstFoodLog: matchingFood.count,
            .baselineMeasurement: matchingMeasurements.count,
            .workouts5: matchingWorkouts.count,
            .workouts10: matchingWorkouts.count,
            .workouts25: matchingWorkouts.count,
            .workouts50: matchingWorkouts.count,
            .workouts75: matchingWorkouts.count,
            .workouts100: matchingWorkouts.count,
            .workouts150: matchingWorkouts.count,
            .workouts250: matchingWorkouts.count,
            .assignedWorkouts5: assignedWorkoutCount,
            .assignedWorkouts10: assignedWorkoutCount,
            .assignedWorkouts25: assignedWorkoutCount,
            .assignedWorkouts50: assignedWorkoutCount,
            .firstStrengthPR: improvedStrengthExercises,
            .strongFoundation: improvedStrengthExercises,
            .strengthExercises5: improvedStrengthExercises,
            .backToTraining: returnedAfterLongBreak,
            .firstWaterGoal: completedWaterDays.count,
            .waterGoal7Total: completedWaterDays.count,
            .waterGoal14Total: completedWaterDays.count,
            .waterGoal30Total: completedWaterDays.count,
            .waterGoal60Total: completedWaterDays.count,
            .waterGoal100Total: completedWaterDays.count,
            .waterStreak7: waterStreak,
            .waterStreak14: waterStreak,
            .waterStreak30: waterStreak,
            .firstNutritionTarget: nutritionTargetDays.count,
            .nutritionGoal7Total: nutritionTargetDays.count,
            .nutritionGoal14Total: nutritionTargetDays.count,
            .nutritionGoal30Total: nutritionTargetDays.count,
            .nutritionGoal60Total: nutritionTargetDays.count,
            .nutritionWeek5: maximumNutritionDaysInWeek,
            .nutritionWeeks4: successfulNutritionWeeks,
            .nutritionWeeks8: successfulNutritionWeeks,
            .nutritionWeeks12: successfulNutritionWeeks,
            .nutritionStreak7: nutritionStreak,
            .nutritionStreak14: nutritionStreak,
            .nutritionStreak30: nutritionStreak,
            .measurements4: regularMeasurements,
            .measurements8: regularMeasurements,
            .measurements12: regularMeasurements,
            .measurements18: regularMeasurements,
            .measurements26: regularMeasurements,
            .measurements39: regularMeasurements,
            .measurements52: regularMeasurements
        ]

        let externalIDs: [AchievementID] = [
            .firstHealthConnection,
            .firstStepGoal, .stepGoal7Total, .stepGoal14Total, .stepGoal30Total, .stepGoal60Total, .stepGoal100Total,
            .steps250K, .steps500K, .millionSteps,
            .firstCheckIn, .checkIns4, .checkIns10, .checkIns25,
            .coachMonth, .coachTwoMonths, .coachThreeMonths, .coachFourMonths, .coachHalfYear
        ]
        for id in externalIDs {
            values[id] = progress.metricValue(for: id)
        }

        // Preserve externally sourced progress when upgrading an existing local profile.
        let storedStepGoalDays = progress.metricValue(for: .stepGoal100Total)
        values[.stepGoal14Total] = max(values[.stepGoal14Total] ?? 0, storedStepGoalDays)
        values[.stepGoal60Total] = max(values[.stepGoal60Total] ?? 0, storedStepGoalDays)
        let storedTotalSteps = progress.metricValue(for: .millionSteps)
        values[.steps250K] = max(values[.steps250K] ?? 0, storedTotalSteps)
        values[.steps500K] = max(values[.steps500K] ?? 0, storedTotalSteps)
        let storedCheckIns = progress.metricValue(for: .checkIns10)
        values[.checkIns25] = max(values[.checkIns25] ?? 0, storedCheckIns)
        let storedCoachDays = max(
            progress.metricValue(for: .coachMonth),
            max(
                progress.metricValue(for: .coachThreeMonths),
                progress.metricValue(for: .coachHalfYear)
            )
        )
        values[.coachTwoMonths] = storedCheckIns >= 6 ? storedCoachDays : 0
        values[.coachFourMonths] = storedCheckIns >= 11 ? storedCoachDays : 0

        if let externalSnapshot {
            values[.firstHealthConnection] = externalSnapshot.healthConnected ? 1 : 0
            if let stepGoalDays = externalSnapshot.stepGoalDays {
                values[.firstStepGoal] = stepGoalDays
                values[.stepGoal7Total] = stepGoalDays
                values[.stepGoal14Total] = stepGoalDays
                values[.stepGoal30Total] = stepGoalDays
                values[.stepGoal60Total] = stepGoalDays
                values[.stepGoal100Total] = stepGoalDays
            }
            if let totalSteps = externalSnapshot.totalSteps {
                values[.steps250K] = totalSteps
                values[.steps500K] = totalSteps
                values[.millionSteps] = totalSteps
            }
            if let checkInCount = externalSnapshot.checkInCount {
                values[.firstCheckIn] = checkInCount
                values[.checkIns4] = checkInCount
                values[.checkIns10] = checkInCount
                values[.checkIns25] = checkInCount
            }
            if let coachDays = externalSnapshot.coachDays {
                let checkIns = externalSnapshot.checkInCount ?? values[.checkIns25] ?? 0
                values[.coachMonth] = checkIns >= 3 ? coachDays : 0
                values[.coachTwoMonths] = checkIns >= 6 ? coachDays : 0
                values[.coachThreeMonths] = checkIns >= 8 ? coachDays : 0
                values[.coachFourMonths] = checkIns >= 11 ? coachDays : 0
                values[.coachHalfYear] = checkIns >= 16 ? coachDays : 0
            }
        }

        let existingUnlocks = try modelContext.fetch(FetchDescriptor<UnlockedAchievement>())
            .filter { $0.scopeID == scope }
        var unlockedIDs = Set(existingUnlocks.compactMap { AchievementID(rawValue: $0.achievementID) })
        var newlyUnlockedIDs: [AchievementID] = []

        for definition in AchievementCatalog.definitions where (values[definition.id] ?? 0) >= definition.target {
            guard unlockedIDs.insert(definition.id).inserted else { continue }
            newlyUnlockedIDs.append(definition.id)
            modelContext.insert(
                UnlockedAchievement(
                    scopeID: scope,
                    achievementID: definition.id,
                    unlockedAt: now,
                    rewardedXP: definition.xpReward
                )
            )
            award(
                eventID: "achievement:\(definition.id.rawValue)",
                amount: definition.xpReward,
                reason: "achievement_unlocked",
                occurredAt: now
            )
        }

        let recentMonthStart = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now)) ?? now
        progress.totalXP = existingTransactions.reduce(0) { $0 + max($1.amount, 0) } + newlyAwardedXP
        progress.currentStreak = activityStreak.current
        progress.longestStreak = max(progress.longestStreak, activityStreak.longest)
        progress.lastActiveDate = activeDays.max()
        progress.totalActiveDays = activeDays.count
        progress.totalWorkouts = matchingWorkouts.count
        progress.maximumWeeklyWorkouts = Dictionary(grouping: matchingWorkouts) {
            weekStart(for: $0.endedAt ?? $0.createdAt, calendar: calendar)
        }.values.map(\.count).max() ?? 0
        progress.totalWaterGoalDays = completedWaterDays.count
        progress.maximumNutritionTargetDaysPerWeek = maximumNutritionDaysInWeek
        progress.activeDaysInLastMonth = activeDays.filter { $0 >= recentMonthStart }.count
        progress.setMetricValues(values)
        progress.migrationVersion = 3
        progress.updatedAt = now
        try modelContext.save()

        return AchievementReconciliationResult(
            unlockedIDs: newlyUnlockedIDs,
            awardedXP: newlyAwardedXP,
            previousLevel: previousLevel,
            currentLevel: AchievementLevelCalculator.progress(totalXP: progress.totalXP).level,
            totalXP: progress.totalXP
        )
    }

    static func resetProgress(
        scopeID: String,
        modelContext: ModelContext,
        now: Date = .now
    ) throws {
        let transactions = try modelContext.fetch(FetchDescriptor<XPTransaction>())
            .filter { $0.scopeID == scopeID }
        for transaction in transactions {
            modelContext.delete(transaction)
        }

        let unlocks = try modelContext.fetch(FetchDescriptor<UnlockedAchievement>())
            .filter { $0.scopeID == scopeID }
        for unlock in unlocks {
            modelContext.delete(unlock)
        }

        let progressRecords = try modelContext.fetch(FetchDescriptor<UserAchievementProgress>())
        if let progress = progressRecords.first(where: { $0.scopeID == scopeID }) {
            progress.totalXP = 0
            progress.xpResetAt = now
            progress.achievementResetAt = now
            progress.currentStreak = 0
            progress.longestStreak = 0
            progress.lastActiveDate = nil
            progress.totalActiveDays = 0
            progress.totalWorkouts = 0
            progress.maximumWeeklyWorkouts = 0
            progress.totalWaterGoalDays = 0
            progress.maximumNutritionTargetDaysPerWeek = 0
            progress.activeDaysInLastMonth = 0
            progress.setMetricValues([:])
            progress.updatedAt = now
        }
        try modelContext.save()
    }

    private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private static func weekStart(for date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: day) ?? day
    }

    private static func streakValues(days: Set<Date>, now: Date, calendar: Calendar) -> (current: Int, longest: Int) {
        let sorted = days.sorted()
        guard sorted.isEmpty == false else { return (0, 0) }

        var longest = 1
        var running = 1
        for index in 1..<sorted.count {
            let difference = calendar.dateComponents([.day], from: sorted[index - 1], to: sorted[index]).day ?? 0
            running = difference == 1 ? running + 1 : 1
            longest = max(longest, running)
        }

        let today = calendar.startOfDay(for: now)
        let latest = sorted.last ?? today
        let daysSinceLatest = calendar.dateComponents([.day], from: latest, to: today).day ?? 0
        guard daysSinceLatest == 0 || daysSinceLatest == 1 else { return (0, longest) }

        var current = 1
        var cursor = latest
        while let previous = calendar.date(byAdding: .day, value: -1, to: cursor), days.contains(previous) {
            current += 1
            cursor = previous
        }
        return (current, longest)
    }

    private static func regularMeasurementCount(_ measurements: [BodyMeasurements], calendar: Calendar) -> Int {
        let dates = Set(measurements.map { calendar.startOfDay(for: $0.date) }).sorted()
        guard var lastAccepted = dates.first else { return 0 }
        var count = 1
        for date in dates.dropFirst() {
            let gap = calendar.dateComponents([.day], from: lastAccepted, to: date).day ?? 0
            if gap >= 6 {
                count += 1
                lastAccepted = date
            }
        }
        return count
    }

    private static func hasWorkoutReturn(workouts: [WorkoutSession], calendar: Calendar) -> Bool {
        guard workouts.count > 1 else { return false }
        for index in 1..<workouts.count {
            let previous = workouts[index - 1].endedAt ?? workouts[index - 1].createdAt
            let current = workouts[index].endedAt ?? workouts[index].createdAt
            if (calendar.dateComponents([.day], from: previous, to: current).day ?? 0) >= 30 {
                return true
            }
        }
        return false
    }

    private static func strengthImprovementCount(workouts: [WorkoutSession]) -> Int {
        var performances: [String: [(date: Date, estimatedOneRepMax: Double)]] = [:]

        for workout in workouts {
            let date = workout.endedAt ?? workout.createdAt
            for exercise in workout.exerciseItems {
                let best = exercise.setItems.compactMap { set -> Double? in
                    guard set.isCompleted, set.metricType == .reps else { return nil }
                    let weight = max((set.actualWeight ?? set.weight).safeFinite, 0)
                    let reps = max(set.actualReps ?? set.reps, 0)
                    guard weight > 0, reps > 0 else { return nil }
                    return weight * (1 + Double(reps) / 30.0)
                }.max()
                guard let best else { continue }
                let key = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard key.isEmpty == false else { continue }
                performances[key, default: []].append((date, best))
            }
        }

        return performances.values.filter { values in
            let ordered = values.sorted { $0.date < $1.date }
            guard let baseline = ordered.first?.estimatedOneRepMax, baseline > 0, ordered.count > 1 else { return false }
            return ordered.dropFirst().contains { $0.estimatedOneRepMax >= baseline * 1.10 }
        }.count
    }
}

import Foundation
import SwiftData

enum WorkoutSetMetricType: String, Codable {
    case reps
    case duration
}

enum WorkoutActivityType: String, Codable {
    case strength
    case cardio
    case hiit
    case core
    case mobility
}

enum WorkoutBlockType: String, Codable {
    case warmup
    case strength
    case main
    case circuit
    case stretching
    case cooldown

    var title: String {
        switch self {
        case .warmup:
            return AppLocalizer.string("workout.block.warmup.title")
        case .strength:
            return AppLocalizer.string("workout.block.strength.title")
        case .main:
            return AppLocalizer.string("workout.block.main.title")
        case .circuit:
            return AppLocalizer.string("workout.block.circuit.title")
        case .stretching:
            return AppLocalizer.string("workout.block.stretching.title")
        case .cooldown:
            return AppLocalizer.string("workout.block.cooldown.title")
        }
    }

    static let templateCases: [WorkoutBlockType] = [
        .warmup,
        .strength,
        .main,
        .circuit,
        .stretching,
        .cooldown
    ]
}

@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var ownerId: String = ""
    var createdAt: Date = Foundation.Date.now
    var endedAt: Date?
    var title: String = ""
    var genderRawValue: String = FitLife.Gender.male.rawValue
    var elapsedSeconds: Int = 0
    var isTimerRunning: Bool = false
    var estimatedCalories: Int = 0
    var note: String = ""
    var remoteAssignmentId: String?
    var remoteTrainerId: String?
    var remoteClientId: String?
    var source: String?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.session) var exercises: [WorkoutExercise]?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutBlock.session) var blocks: [WorkoutBlock]?

    var exerciseItems: [WorkoutExercise] {
        get { exercises ?? [] }
        set { exercises = newValue }
    }

    var blockItems: [WorkoutBlock] {
        get { blocks ?? [] }
        set { blocks = newValue }
    }

    var gender: Gender {
        get { Gender(rawValue: genderRawValue) ?? .male }
        set { genderRawValue = newValue.rawValue }
    }

    init(
        ownerId: String = "",
        createdAt: Date = .now,
        endedAt: Date? = nil,
        title: String,
        gender: Gender,
        elapsedSeconds: Int = 0,
        isTimerRunning: Bool = false,
        estimatedCalories: Int = 0,
        note: String = "",
        remoteAssignmentId: String? = nil,
        remoteTrainerId: String? = nil,
        remoteClientId: String? = nil,
        source: String? = nil
    ) {
        self.ownerId = ownerId
        self.createdAt = createdAt
        self.endedAt = endedAt
        self.title = title
        self.genderRawValue = gender.rawValue
        self.elapsedSeconds = elapsedSeconds
        self.isTimerRunning = isTimerRunning
        self.estimatedCalories = estimatedCalories
        self.note = note
        self.remoteAssignmentId = remoteAssignmentId
        self.remoteTrainerId = remoteTrainerId
        self.remoteClientId = remoteClientId
        self.source = source
    }
}

@Model
final class WorkoutBlock {
    var id: UUID = UUID()
    var title: String = ""
    var typeRawValue: String = WorkoutBlockType.strength.rawValue
    var orderIndex: Int = 0
    var rounds: Int = 1
    var workSeconds: Int = 0
    var restSeconds: Int = 0
    var restBetweenRoundsSeconds: Int = 0

    var session: WorkoutSession?

    @Relationship(deleteRule: .nullify, inverse: \WorkoutExercise.block) var exercises: [WorkoutExercise]?

    var exerciseItems: [WorkoutExercise] {
        get { exercises ?? [] }
        set { exercises = newValue }
    }

    var type: WorkoutBlockType {
        get { WorkoutBlockType(rawValue: typeRawValue) ?? .strength }
        set { typeRawValue = newValue.rawValue }
    }

    init(
        title: String,
        type: WorkoutBlockType = .strength,
        orderIndex: Int,
        rounds: Int = 1,
        workSeconds: Int = 0,
        restSeconds: Int = 0,
        restBetweenRoundsSeconds: Int = 0
    ) {
        self.title = title
        self.typeRawValue = type.rawValue
        self.orderIndex = orderIndex
        self.rounds = rounds
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.restBetweenRoundsSeconds = restBetweenRoundsSeconds
    }
}

@Model
final class WorkoutExercise {
    var id: UUID = UUID()
    var name: String = ""
    var systemImage: String = ""
    var accentName: String = ""
    var orderIndex: Int = 0
    var isExpanded: Bool = false
    var note: String = ""
    var activityTypeRaw: String = WorkoutActivityType.strength.rawValue
    var metValue: Double = 5.0

    var session: WorkoutSession?
    var block: WorkoutBlock?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise) var sets: [WorkoutSet]?

    var setItems: [WorkoutSet] {
        get { sets ?? [] }
        set { sets = newValue }
    }

    var activityType: WorkoutActivityType {
        get { WorkoutActivityType(rawValue: activityTypeRaw) ?? .strength }
        set { activityTypeRaw = newValue.rawValue }
    }

    init(
        name: String,
        systemImage: String,
        accentName: String,
        orderIndex: Int,
        isExpanded: Bool = false,
        note: String = "",
        activityType: WorkoutActivityType = .strength,
        metValue: Double = 5.0
    ) {
        self.name = name
        self.systemImage = systemImage
        self.accentName = accentName
        self.orderIndex = orderIndex
        self.isExpanded = isExpanded
        self.note = note
        self.activityTypeRaw = activityType.rawValue
        self.metValue = metValue
    }
}

@Model
final class WorkoutSet {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var weight: Double = 0
    var metricTypeRaw: String = WorkoutSetMetricType.reps.rawValue
    var reps: Int = 0
    var durationSeconds: Int = 30
    var isCompleted: Bool = false

    var exercise: WorkoutExercise?

    var metricType: WorkoutSetMetricType {
        get { WorkoutSetMetricType(rawValue: metricTypeRaw) ?? .reps }
        set { metricTypeRaw = newValue.rawValue }
    }

    init(
        orderIndex: Int,
        weight: Double,
        reps: Int,
        durationSeconds: Int = 30,
        metricType: WorkoutSetMetricType = .reps,
        isCompleted: Bool = false
    ) {
        self.orderIndex = orderIndex
        self.weight = weight
        self.metricTypeRaw = metricType.rawValue
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.isCompleted = isCompleted
    }
}

@Model
final class CustomWorkoutExerciseTemplate {
    var id: UUID = UUID()
    var createdAt: Date = Foundation.Date.now
    var name: String = ""
    var systemImage: String = ""
    var accentName: String = ""
    var activityTypeRaw: String = WorkoutActivityType.strength.rawValue
    var metValue: Double = 5.0

    var activityType: WorkoutActivityType {
        get { WorkoutActivityType(rawValue: activityTypeRaw) ?? .strength }
        set { activityTypeRaw = newValue.rawValue }
    }

    init(
        name: String,
        systemImage: String,
        accentName: String,
        activityType: WorkoutActivityType = .strength,
        metValue: Double = 5.0,
        createdAt: Date = .now
    ) {
        self.name = name
        self.systemImage = systemImage
        self.accentName = accentName
        self.activityTypeRaw = activityType.rawValue
        self.metValue = metValue
        self.createdAt = createdAt
    }
}

enum WorkoutCalorieEstimator {
    static func estimateWorkoutCalories(workout: WorkoutSession, userWeightKg: Double) -> Int {
        let safeWeight = userWeightKg > 0 ? userWeightKg : 70
        let exercises = workout.exerciseItems
        let hasCompletedSets = exercises
            .flatMap(\.setItems)
            .contains { $0.isCompleted }

        let totalCalories = exercises.reduce(0.0) { total, exercise in
            let sets = exercise.setItems.filter { hasCompletedSets ? $0.isCompleted : true }
            guard sets.isEmpty == false else { return total }

            let activeSeconds = sets.reduce(0) { partial, set in
                partial + estimatedActiveSeconds(for: set)
            }
            let activeCalories = calories(
                met: max(exercise.metValue, 1.0),
                weightKg: safeWeight,
                seconds: activeSeconds
            )

            let restSeconds = max(0, sets.count - 1) * 60
            let restCalories = calories(met: 1.8, weightKg: safeWeight, seconds: restSeconds)

            return total + activeCalories + restCalories
        }

        return max(0, Int(totalCalories.rounded()))
    }

    private static func estimatedActiveSeconds(for set: WorkoutSet) -> Int {
        switch set.metricType {
        case .duration:
            return max(0, set.durationSeconds)
        case .reps:
            return max(0, set.reps) * 4
        }
    }

    private static func calories(met: Double, weightKg: Double, seconds: Int) -> Double {
        met * weightKg * (Double(seconds) / 3600.0)
    }
}

func formattedWorkoutWeight(_ weight: Double) -> String {
    if weight.rounded() == weight {
        return String(Int(weight))
    }
    return String(format: "%.1f", weight)
}

func formattedWorkoutMetricValue(
    reps: Int,
    durationSeconds: Int,
    metricType: WorkoutSetMetricType
) -> String {
    switch metricType {
    case .reps:
        return "\(reps)"
    case .duration:
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

func formattedWorkoutSetValue(
    weight: Double,
    reps: Int,
    durationSeconds: Int,
    metricType: WorkoutSetMetricType
) -> String {
    "\(formattedWorkoutWeight(weight)) kg × \(formattedWorkoutMetricValue(reps: reps, durationSeconds: durationSeconds, metricType: metricType))"
}

func formattedWorkoutCalories(_ calories: Int) -> String {
    "\(max(0, calories)) \(AppLocalizer.string("unit.kcal"))"
}

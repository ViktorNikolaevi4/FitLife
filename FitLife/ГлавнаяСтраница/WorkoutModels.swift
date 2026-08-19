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
    case superset
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
        case .superset:
            return AppLocalizer.string("workout.block.superset.title")
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
        .superset,
        .circuit,
        .stretching,
        .cooldown
    ]
}

enum WorkoutBlockMode: String, Codable {
    case rounds
    case amrap
    case tabata
    case emom

    var title: String {
        switch self {
        case .rounds:
            return AppLocalizer.string("workout.block.mode.rounds")
        case .amrap:
            return AppLocalizer.string("workout.block.mode.amrap")
        case .tabata:
            return AppLocalizer.string("workout.block.mode.tabata")
        case .emom:
            return AppLocalizer.string("workout.block.mode.emom")
        }
    }

    static let circuitCases: [WorkoutBlockMode] = [.rounds, .amrap, .tabata, .emom]
}

enum WorkoutBlockRunnerPhase: String, Codable {
    case ready
    case work
    case rest
    case paused
    case completed
}

enum WorkoutBlockPreset: String, CaseIterable, Identifiable {
    case warmup
    case strength
    case superset
    case circuit
    case hiit
    case tabata
    case amrap
    case emom
    case e2mom
    case e3mom
    case forTime
    case rft
    case pyramid
    case dropSet
    case clusterSet
    case ladder
    case mobility
    case stretching
    case cooldown

    var id: String { rawValue }

    var title: String { AppLocalizer.string("workout.block.preset.\(rawValue).title") }
    var subtitle: String { AppLocalizer.string("workout.block.preset.\(rawValue).subtitle") }
    var description: String { AppLocalizer.string("workout.block.preset.\(rawValue).description") }

    var iconName: String {
        switch self {
        case .warmup: "figure.walk"
        case .strength: "square.stack.3d.up.fill"
        case .superset: "link"
        case .circuit: "arrow.triangle.2.circlepath"
        case .hiit: "bolt.fill"
        case .tabata: "stopwatch.fill"
        case .amrap: "infinity"
        case .emom: "clock.fill"
        case .e2mom: "2.circle.fill"
        case .e3mom: "3.circle.fill"
        case .forTime: "flag.checkered"
        case .rft: "timer"
        case .pyramid: "triangle.fill"
        case .dropSet: "arrow.down.right"
        case .clusterSet: "circle.grid.3x3.fill"
        case .ladder: "stairs"
        case .mobility: "figure.flexibility"
        case .stretching: "figure.cooldown"
        case .cooldown: "wind"
        }
    }

    var blockType: WorkoutBlockType {
        switch self {
        case .warmup: .warmup
        case .strength: .strength
        case .superset: .superset
        case .stretching, .mobility: .stretching
        case .cooldown: .cooldown
        case .circuit, .hiit, .tabata, .amrap, .emom, .e2mom, .e3mom, .forTime, .rft, .pyramid, .dropSet, .clusterSet, .ladder: .circuit
        }
    }

    var mode: WorkoutBlockMode {
        switch self {
        case .tabata: .tabata
        case .amrap: .amrap
        case .emom, .e2mom, .e3mom: .emom
        case .warmup, .strength, .superset, .circuit, .hiit, .forTime, .rft, .pyramid, .dropSet, .clusterSet, .ladder, .mobility, .stretching, .cooldown: .rounds
        }
    }

    var defaultTitle: String { title }
    var defaultRounds: Int {
        switch self {
        case .tabata: 8
        case .pyramid: 4
        case .dropSet: 2
        case .clusterSet: 3
        case .ladder: 5
        case .strength, .warmup, .mobility, .stretching, .cooldown, .forTime: 1
        default: 3
        }
    }
    var defaultDurationMinutes: Int {
        switch self {
        case .amrap, .emom: 12
        case .e2mom, .e3mom: 15
        case .forTime: 20
        case .hiit: 16
        default: 0
        }
    }
    var defaultWorkSeconds: Int { self == .tabata || self == .hiit ? 20 : 0 }
    var defaultRestSeconds: Int { self == .tabata || self == .hiit ? 10 : 0 }
    var defaultRestBetweenRoundsSeconds: Int {
        switch self {
        case .circuit, .hiit, .rft: 60
        case .superset: 90
        case .clusterSet: 15
        default: 0
        }
    }

    /// Restores the visual identity of a saved block. Older saved blocks only
    /// contain a general type/mode, so named presets are detected from title
    /// first and then fall back to their broad category.
    static func inferred(title: String, type: WorkoutBlockType, mode: WorkoutBlockMode) -> WorkoutBlockPreset {
        let normalizedTitle = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if let namedPreset = allCases.first(where: {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedTitle
        }) {
            return namedPreset
        }

        switch type {
        case .warmup:
            return .warmup
        case .strength, .main:
            return .strength
        case .superset:
            return .superset
        case .stretching:
            return .stretching
        case .cooldown:
            return .cooldown
        case .circuit:
            switch mode {
            case .tabata: return .tabata
            case .amrap: return .amrap
            case .emom: return .emom
            case .rounds: return .circuit
            }
        }
    }
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
        get {
            var seenIDs = Set<UUID>()
            return (blocks ?? []).filter { seenIDs.insert($0.id).inserted }
        }
        set {
            var seenIDs = Set<UUID>()
            blocks = newValue.filter { seenIDs.insert($0.id).inserted }
        }
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
    var modeRawValue: String = WorkoutBlockMode.rounds.rawValue
    var presetRawValue: String = ""
    var orderIndex: Int = 0
    var rounds: Int = 1
    var durationMinutes: Int = 12
    var workSeconds: Int = 0
    var restSeconds: Int = 0
    var restBetweenRoundsSeconds: Int = 0
    var isFinished: Bool = false
    var currentRoundIndex: Int = 0
    var currentExerciseIndex: Int = 0
    var runnerPhaseRawValue: String = WorkoutBlockRunnerPhase.ready.rawValue
    var phaseBeforePauseRawValue: String = WorkoutBlockRunnerPhase.work.rawValue
    var phaseEndsAt: Date?
    var pausedRemainingSeconds: Int = 0
    var runnerStartedAt: Date?
    var runnerCompletedAt: Date?
    var completedIntervalsRawValue: String = ""

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

    var mode: WorkoutBlockMode {
        get { WorkoutBlockMode(rawValue: modeRawValue) ?? .rounds }
        set { modeRawValue = newValue.rawValue }
    }

    var runnerPhase: WorkoutBlockRunnerPhase {
        get { WorkoutBlockRunnerPhase(rawValue: runnerPhaseRawValue) ?? .ready }
        set { runnerPhaseRawValue = newValue.rawValue }
    }

    var phaseBeforePause: WorkoutBlockRunnerPhase {
        get { WorkoutBlockRunnerPhase(rawValue: phaseBeforePauseRawValue) ?? .work }
        set { phaseBeforePauseRawValue = newValue.rawValue }
    }

    var preset: WorkoutBlockPreset {
        get {
            WorkoutBlockPreset(rawValue: presetRawValue)
                ?? WorkoutBlockPreset.inferred(title: title, type: type, mode: mode)
        }
        set { presetRawValue = newValue.rawValue }
    }

    var completedIntervalIndexes: Set<Int> {
        get {
            Set(
                completedIntervalsRawValue
                    .split(separator: ",")
                    .compactMap { Int($0) }
            )
        }
        set {
            completedIntervalsRawValue = newValue
                .sorted()
                .map(String.init)
                .joined(separator: ",")
        }
    }

    init(
        title: String,
        type: WorkoutBlockType = .strength,
        mode: WorkoutBlockMode = .rounds,
        preset: WorkoutBlockPreset? = nil,
        orderIndex: Int,
        rounds: Int = 1,
        durationMinutes: Int = 12,
        workSeconds: Int = 0,
        restSeconds: Int = 0,
        restBetweenRoundsSeconds: Int = 0,
        isFinished: Bool = false,
        currentRoundIndex: Int = 0,
        currentExerciseIndex: Int = 0,
        runnerPhase: WorkoutBlockRunnerPhase = .ready
    ) {
        self.title = title
        self.typeRawValue = type.rawValue
        self.modeRawValue = mode.rawValue
        self.presetRawValue = preset?.rawValue ?? ""
        self.orderIndex = orderIndex
        self.rounds = rounds
        self.durationMinutes = durationMinutes
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.restBetweenRoundsSeconds = restBetweenRoundsSeconds
        self.isFinished = isFinished
        self.currentRoundIndex = currentRoundIndex
        self.currentExerciseIndex = currentExerciseIndex
        self.runnerPhaseRawValue = runnerPhase.rawValue
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
    var isFinished: Bool = false
    /// Guidance supplied by the trainer or when composing the workout.
    var note: String = ""
    /// Private note recorded by the person performing the workout.
    var userNote: String = ""
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
        isFinished: Bool = false,
        note: String = "",
        userNote: String = "",
        activityType: WorkoutActivityType = .strength,
        metValue: Double = 5.0
    ) {
        self.name = name
        self.systemImage = systemImage
        self.accentName = accentName
        self.orderIndex = orderIndex
        self.isExpanded = isExpanded
        self.isFinished = isFinished
        self.note = note
        self.userNote = userNote
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

func circuitSubtitle(
    mode: WorkoutBlockMode,
    rounds: Int,
    exerciseCount: Int,
    durationMinutes: Int,
    workSeconds: Int,
    restSeconds: Int,
    restBetweenRoundsSeconds: Int
) -> String {
    switch mode {
    case .rounds:
        return AppLocalizer.format(
            "workout.block.circuit.summary",
            rounds,
            exerciseCount,
            restBetweenRoundsSeconds
        )
    case .amrap:
        return AppLocalizer.format(
            "workout.block.amrap.summary",
            durationMinutes,
            exerciseCount
        )
    case .tabata:
        return AppLocalizer.format(
            "workout.block.tabata.summary",
            rounds,
            workSeconds,
            restSeconds,
            exerciseCount
        )
    case .emom:
        return AppLocalizer.format(
            "workout.block.emom.summary",
            durationMinutes,
            exerciseCount
        )
    }
}

func workoutBlockSubtitle(
    title: String,
    type: WorkoutBlockType,
    mode: WorkoutBlockMode,
    rounds: Int,
    exerciseCount: Int,
    durationMinutes: Int,
    workSeconds: Int,
    restSeconds: Int,
    restBetweenRoundsSeconds: Int
) -> String {
    let preset = WorkoutBlockPreset.inferred(title: title, type: type, mode: mode)

    switch preset {
    case .dropSet:
        return AppLocalizer.format("workout.block.drop_set.summary", rounds, exerciseCount, restBetweenRoundsSeconds)
    case .clusterSet:
        return AppLocalizer.format("workout.block.cluster_set.summary", rounds, exerciseCount, restBetweenRoundsSeconds)
    case .pyramid:
        return AppLocalizer.format("workout.block.pyramid.summary", rounds, exerciseCount)
    case .ladder:
        return AppLocalizer.format("workout.block.ladder.summary", rounds, exerciseCount)
    case .forTime:
        return AppLocalizer.format("workout.block.for_time.summary", durationMinutes, exerciseCount)
    case .hiit:
        return AppLocalizer.format("workout.block.hiit.summary", rounds, workSeconds, restSeconds, exerciseCount)
    default:
        if type == .circuit {
            return circuitSubtitle(
                mode: mode,
                rounds: rounds,
                exerciseCount: exerciseCount,
                durationMinutes: durationMinutes,
                workSeconds: workSeconds,
                restSeconds: restSeconds,
                restBetweenRoundsSeconds: restBetweenRoundsSeconds
            )
        }
        return AppLocalizer.format("workout.block.exercise_count", exerciseCount)
    }
}

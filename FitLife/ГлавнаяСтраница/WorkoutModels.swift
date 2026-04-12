import Foundation
import SwiftData

enum WorkoutSetMetricType: String, Codable {
    case reps
    case duration
}

@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var ownerId: String = ""
    var createdAt: Date = Foundation.Date.now
    var endedAt: Date?
    var title: String = ""
    var gender: Gender = FitLife.Gender.male
    var elapsedSeconds: Int = 0
    var isTimerRunning: Bool = false
    var note: String = ""
    var remoteAssignmentId: String?
    var remoteTrainerId: String?
    var remoteClientId: String?
    var source: String?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.session) var exercises: [WorkoutExercise] = []

    init(
        ownerId: String = "",
        createdAt: Date = .now,
        endedAt: Date? = nil,
        title: String,
        gender: Gender,
        elapsedSeconds: Int = 0,
        isTimerRunning: Bool = false,
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
        self.gender = gender
        self.elapsedSeconds = elapsedSeconds
        self.isTimerRunning = isTimerRunning
        self.note = note
        self.remoteAssignmentId = remoteAssignmentId
        self.remoteTrainerId = remoteTrainerId
        self.remoteClientId = remoteClientId
        self.source = source
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

    var session: WorkoutSession?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise) var sets: [WorkoutSet] = []

    init(
        name: String,
        systemImage: String,
        accentName: String,
        orderIndex: Int,
        isExpanded: Bool = false,
        note: String = ""
    ) {
        self.name = name
        self.systemImage = systemImage
        self.accentName = accentName
        self.orderIndex = orderIndex
        self.isExpanded = isExpanded
        self.note = note
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

    init(name: String, systemImage: String, accentName: String, createdAt: Date = .now) {
        self.name = name
        self.systemImage = systemImage
        self.accentName = accentName
        self.createdAt = createdAt
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

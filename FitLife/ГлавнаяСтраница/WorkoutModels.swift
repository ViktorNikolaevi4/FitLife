import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var createdAt: Date = Foundation.Date.now
    var endedAt: Date?
    var title: String = ""
    var gender: Gender = FitLife.Gender.male
    var elapsedSeconds: Int = 0
    var isTimerRunning: Bool = false
    var remoteAssignmentId: String?
    var remoteTrainerId: String?
    var remoteClientId: String?
    var source: String?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.session) var exercises: [WorkoutExercise] = []

    init(
        createdAt: Date = .now,
        endedAt: Date? = nil,
        title: String,
        gender: Gender,
        elapsedSeconds: Int = 0,
        isTimerRunning: Bool = false,
        remoteAssignmentId: String? = nil,
        remoteTrainerId: String? = nil,
        remoteClientId: String? = nil,
        source: String? = nil
    ) {
        self.createdAt = createdAt
        self.endedAt = endedAt
        self.title = title
        self.gender = gender
        self.elapsedSeconds = elapsedSeconds
        self.isTimerRunning = isTimerRunning
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
    var isExpanded: Bool = true

    var session: WorkoutSession?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise) var sets: [WorkoutSet] = []

    init(name: String, systemImage: String, accentName: String, orderIndex: Int, isExpanded: Bool = true) {
        self.name = name
        self.systemImage = systemImage
        self.accentName = accentName
        self.orderIndex = orderIndex
        self.isExpanded = isExpanded
    }
}

@Model
final class WorkoutSet {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var weight: Double = 0
    var reps: Int = 0
    var isCompleted: Bool = false

    var exercise: WorkoutExercise?

    init(orderIndex: Int, weight: Double, reps: Int, isCompleted: Bool = false) {
        self.orderIndex = orderIndex
        self.weight = weight
        self.reps = reps
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

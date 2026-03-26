import Foundation
import FirebaseFirestore

enum WorkoutAssignmentStatus: String, CaseIterable, Codable {
    case assigned
    case started
    case completed
    case skipped

    var localizationKey: String {
        switch self {
        case .assigned: return "assignment.status.assigned"
        case .started: return "assignment.status.started"
        case .completed: return "assignment.status.completed"
        case .skipped: return "assignment.status.skipped"
        }
    }
}

struct WorkoutAssignment: Identifiable, Hashable {
    let id: String
    let trainerId: String
    let clientId: String
    let templateId: String
    let titleSnapshot: String
    let notesSnapshot: String
    let exerciseCount: Int
    let assignedAt: Date
    let status: WorkoutAssignmentStatus

    init(
        id: String,
        trainerId: String,
        clientId: String,
        templateId: String,
        titleSnapshot: String,
        notesSnapshot: String,
        exerciseCount: Int,
        assignedAt: Date = .now,
        status: WorkoutAssignmentStatus = .assigned
    ) {
        self.id = id
        self.trainerId = trainerId
        self.clientId = clientId
        self.templateId = templateId
        self.titleSnapshot = titleSnapshot
        self.notesSnapshot = notesSnapshot
        self.exerciseCount = exerciseCount
        self.assignedAt = assignedAt
        self.status = status
    }

    init?(id: String, data: [String: Any]) {
        guard
            let trainerId = data["trainerId"] as? String,
            let clientId = data["clientId"] as? String,
            let templateId = data["templateId"] as? String,
            let titleSnapshot = data["titleSnapshot"] as? String,
            let statusRaw = data["status"] as? String,
            let status = WorkoutAssignmentStatus(rawValue: statusRaw)
        else {
            return nil
        }

        self.id = id
        self.trainerId = trainerId
        self.clientId = clientId
        self.templateId = templateId
        self.titleSnapshot = titleSnapshot
        self.notesSnapshot = (data["notesSnapshot"] as? String) ?? ""
        self.exerciseCount = (data["exerciseCount"] as? Int) ?? 0
        self.status = status

        if let timestamp = data["assignedAt"] as? Timestamp {
            self.assignedAt = timestamp.dateValue()
        } else {
            self.assignedAt = (data["assignedAt"] as? Date) ?? .now
        }
    }

    var firestoreData: [String: Any] {
        [
            "trainerId": trainerId,
            "clientId": clientId,
            "templateId": templateId,
            "titleSnapshot": titleSnapshot,
            "notesSnapshot": notesSnapshot,
            "exerciseCount": exerciseCount,
            "assignedAt": assignedAt,
            "status": status.rawValue
        ]
    }
}

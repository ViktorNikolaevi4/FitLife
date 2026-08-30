import Foundation
import FirebaseFirestore

struct WorkoutTemplate: Identifiable, Hashable {
    let id: String
    let trainerId: String
    let title: String
    let notes: String
    let createdAt: Date
    let updatedAt: Date
    let isActive: Bool
    let sourceLibraryTemplateId: String?

    init(
        id: String,
        trainerId: String,
        title: String,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isActive: Bool = true,
        sourceLibraryTemplateId: String? = nil
    ) {
        self.id = id
        self.trainerId = trainerId
        self.title = title
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isActive = isActive
        self.sourceLibraryTemplateId = sourceLibraryTemplateId
    }

    init?(id: String, data: [String: Any]) {
        guard
            let trainerId = data["trainerId"] as? String,
            let title = data["title"] as? String
        else {
            return nil
        }

        self.id = id
        self.trainerId = trainerId
        self.title = title
        self.notes = (data["notes"] as? String) ?? ""
        self.isActive = (data["isActive"] as? Bool) ?? true
        self.sourceLibraryTemplateId = data["sourceLibraryTemplateId"] as? String

        if let createdAt = data["createdAt"] as? Timestamp {
            self.createdAt = createdAt.dateValue()
        } else {
            self.createdAt = (data["createdAt"] as? Date) ?? .now
        }

        if let updatedAt = data["updatedAt"] as? Timestamp {
            self.updatedAt = updatedAt.dateValue()
        } else {
            self.updatedAt = (data["updatedAt"] as? Date) ?? .now
        }
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "trainerId": trainerId,
            "title": title,
            "notes": notes,
            "createdAt": createdAt,
            "updatedAt": updatedAt,
            "isActive": isActive
        ]
        if let sourceLibraryTemplateId {
            data["sourceLibraryTemplateId"] = sourceLibraryTemplateId
        }
        return data
    }
}

enum WorkoutLibraryCategory: String, CaseIterable {
    case warmup
    case strength
    case mobility
    case cardio
    case crossTraining
    case cooldown
    case other

    var localizationKey: String {
        "trainer.templates.library.category.\(rawValue)"
    }
}

struct LibraryWorkoutTemplate: Identifiable, Hashable {
    let id: String
    let title: String
    let notes: String
    let category: WorkoutLibraryCategory
    let difficulty: String
    let durationMinutes: Int
    let exerciseCount: Int
    let sortOrder: Int
    let updatedAt: Date
    let isActive: Bool
    let authorName: String

    init?(id: String, data: [String: Any]) {
        guard let title = data["title"] as? String else { return nil }

        self.id = id
        self.title = title
        self.notes = data["notes"] as? String ?? ""
        self.category = WorkoutLibraryCategory(rawValue: data["category"] as? String ?? "") ?? .other
        self.difficulty = data["difficulty"] as? String ?? ""
        self.durationMinutes = data["durationMinutes"] as? Int ?? 0
        self.exerciseCount = data["exerciseCount"] as? Int ?? 0
        self.sortOrder = data["sortOrder"] as? Int ?? 0
        self.isActive = data["isActive"] as? Bool ?? true
        self.authorName = data["authorName"] as? String ?? ""

        if let timestamp = data["updatedAt"] as? Timestamp {
            self.updatedAt = timestamp.dateValue()
        } else {
            self.updatedAt = data["updatedAt"] as? Date ?? .now
        }
    }
}

enum WorkoutTemplateSubmissionStatus: String, CaseIterable {
    case pending
    case approved
    case rejected

    var localizationKey: String {
        "trainer.templates.submission.status.\(rawValue)"
    }
}

struct WorkoutTemplateSubmission: Identifiable, Hashable {
    let id: String
    let trainerId: String
    let trainerName: String
    let sourceTemplateId: String
    let title: String
    let notes: String
    let exerciseCount: Int
    let status: WorkoutTemplateSubmissionStatus
    let submittedAt: Date
    let reviewedAt: Date?
    let reviewedBy: String?
    let reviewNote: String
    let publishedTemplateId: String?

    init(
        id: String,
        trainerId: String,
        trainerName: String,
        sourceTemplateId: String,
        title: String,
        notes: String,
        exerciseCount: Int,
        status: WorkoutTemplateSubmissionStatus = .pending,
        submittedAt: Date = .now,
        reviewedAt: Date? = nil,
        reviewedBy: String? = nil,
        reviewNote: String = "",
        publishedTemplateId: String? = nil
    ) {
        self.id = id
        self.trainerId = trainerId
        self.trainerName = trainerName
        self.sourceTemplateId = sourceTemplateId
        self.title = title
        self.notes = notes
        self.exerciseCount = exerciseCount
        self.status = status
        self.submittedAt = submittedAt
        self.reviewedAt = reviewedAt
        self.reviewedBy = reviewedBy
        self.reviewNote = reviewNote
        self.publishedTemplateId = publishedTemplateId
    }

    init?(id: String, data: [String: Any]) {
        guard
            let trainerId = data["trainerId"] as? String,
            let sourceTemplateId = data["sourceTemplateId"] as? String,
            let title = data["title"] as? String,
            let statusRaw = data["status"] as? String,
            let status = WorkoutTemplateSubmissionStatus(rawValue: statusRaw)
        else {
            return nil
        }

        self.id = id
        self.trainerId = trainerId
        self.trainerName = data["trainerName"] as? String ?? ""
        self.sourceTemplateId = sourceTemplateId
        self.title = title
        self.notes = data["notes"] as? String ?? ""
        self.exerciseCount = data["exerciseCount"] as? Int ?? 0
        self.status = status
        self.submittedAt = (data["submittedAt"] as? Timestamp)?.dateValue() ?? .now
        self.reviewedAt = (data["reviewedAt"] as? Timestamp)?.dateValue()
        self.reviewedBy = data["reviewedBy"] as? String
        self.reviewNote = data["reviewNote"] as? String ?? ""
        self.publishedTemplateId = data["publishedTemplateId"] as? String
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "trainerId": trainerId,
            "trainerName": trainerName,
            "sourceTemplateId": sourceTemplateId,
            "title": title,
            "notes": notes,
            "exerciseCount": exerciseCount,
            "status": status.rawValue,
            "submittedAt": submittedAt,
            "reviewNote": reviewNote
        ]
        if let reviewedAt { data["reviewedAt"] = reviewedAt }
        if let reviewedBy { data["reviewedBy"] = reviewedBy }
        if let publishedTemplateId { data["publishedTemplateId"] = publishedTemplateId }
        return data
    }
}

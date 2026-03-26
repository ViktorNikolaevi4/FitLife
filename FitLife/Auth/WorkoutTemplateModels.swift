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

    init(
        id: String,
        trainerId: String,
        title: String,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isActive: Bool = true
    ) {
        self.id = id
        self.trainerId = trainerId
        self.title = title
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isActive = isActive
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
        [
            "trainerId": trainerId,
            "title": title,
            "notes": notes,
            "createdAt": createdAt,
            "updatedAt": updatedAt,
            "isActive": isActive
        ]
    }
}

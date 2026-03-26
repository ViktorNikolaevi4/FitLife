import Foundation
import FirebaseFirestore

struct TrainerClientLink: Identifiable, Hashable {
    let id: String
    let trainerId: String
    let clientId: String
    let createdAt: Date
    let createdByOwnerId: String
    let status: String

    init(
        id: String,
        trainerId: String,
        clientId: String,
        createdAt: Date = .now,
        createdByOwnerId: String,
        status: String = "active"
    ) {
        self.id = id
        self.trainerId = trainerId
        self.clientId = clientId
        self.createdAt = createdAt
        self.createdByOwnerId = createdByOwnerId
        self.status = status
    }

    init?(id: String, data: [String: Any]) {
        guard
            let trainerId = data["trainerId"] as? String,
            let clientId = data["clientId"] as? String,
            let createdByOwnerId = data["createdByOwnerId"] as? String
        else {
            return nil
        }

        self.id = id
        self.trainerId = trainerId
        self.clientId = clientId
        self.createdByOwnerId = createdByOwnerId
        self.status = (data["status"] as? String) ?? "active"

        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = (data["createdAt"] as? Date) ?? .now
        }
    }

    var firestoreData: [String: Any] {
        [
            "trainerId": trainerId,
            "clientId": clientId,
            "createdAt": createdAt,
            "createdByOwnerId": createdByOwnerId,
            "status": status
        ]
    }
}

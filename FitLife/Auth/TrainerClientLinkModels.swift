import Foundation
import FirebaseFirestore

struct TrainerClientLink: Identifiable, Hashable {
    let id: String
    let trainerId: String
    let clientId: String
    let createdAt: Date
    let createdByOwnerId: String
    let status: String
    let clientDisplayName: String?
    let clientEmail: String?

    init(
        id: String,
        trainerId: String,
        clientId: String,
        createdAt: Date = .now,
        createdByOwnerId: String,
        status: String = "active",
        clientDisplayName: String? = nil,
        clientEmail: String? = nil
    ) {
        self.id = id
        self.trainerId = trainerId
        self.clientId = clientId
        self.createdAt = createdAt
        self.createdByOwnerId = createdByOwnerId
        self.status = status
        self.clientDisplayName = clientDisplayName
        self.clientEmail = clientEmail
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
        self.clientDisplayName = (data["clientDisplayName"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.clientEmail = (data["clientEmail"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = (data["createdAt"] as? Date) ?? .now
        }
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "trainerId": trainerId,
            "clientId": clientId,
            "createdAt": createdAt,
            "createdByOwnerId": createdByOwnerId,
            "status": status
        ]
        if let clientDisplayName, clientDisplayName.isEmpty == false {
            data["clientDisplayName"] = clientDisplayName
        }
        if let clientEmail, clientEmail.isEmpty == false {
            data["clientEmail"] = clientEmail
        }
        return data
    }

    var clientProfileSnapshot: AppUserProfile? {
        guard let clientDisplayName, clientDisplayName.isEmpty == false else { return nil }

        return AppUserProfile(
            id: clientId,
            email: clientEmail ?? "",
            displayName: clientDisplayName,
            role: .client,
            createdAt: createdAt,
            isActive: true
        )
    }
}

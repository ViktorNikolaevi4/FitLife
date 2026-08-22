import Foundation
import FirebaseFirestore

enum AppUserRole: String, CaseIterable, Codable {
    case owner
    case trainer
    case client

    var localizationKey: String {
        switch self {
        case .owner: return "role.owner"
        case .trainer: return "role.trainer"
        case .client: return "role.client"
        }
    }
}

struct AppUserProfile: Identifiable, Hashable {
    let id: String
    var email: String
    var displayName: String
    var role: AppUserRole
    var createdAt: Date
    var isActive: Bool
    var photoURL: String?

    init(
        id: String,
        email: String,
        displayName: String,
        role: AppUserRole,
        createdAt: Date = .now,
        isActive: Bool = true,
        photoURL: String? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.role = role
        self.createdAt = createdAt
        self.isActive = isActive
        self.photoURL = photoURL
    }

    init?(id: String, data: [String: Any]) {
        guard
            let email = data["email"] as? String,
            let displayName = data["displayName"] as? String,
            let roleRaw = data["role"] as? String,
            let role = AppUserRole(rawValue: roleRaw)
        else {
            return nil
        }

        self.id = id
        self.email = email
        self.displayName = displayName
        self.role = role
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = (data["createdAt"] as? Date) ?? .now
        }
        self.isActive = (data["isActive"] as? Bool) ?? true
        self.photoURL = data["photoURL"] as? String
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "uid": id,
            "email": email,
            "displayName": displayName,
            "role": role.rawValue,
            "createdAt": createdAt,
            "isActive": isActive
        ]
        if let photoURL, photoURL.isEmpty == false {
            data["photoURL"] = photoURL
        }
        return data
    }
}

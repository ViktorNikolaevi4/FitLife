import Foundation
import FirebaseFirestore

enum ClientCoachingGoal: String, CaseIterable, Codable, Identifiable {
    case loseWeight = "lose_weight"
    case gainMass = "gain_mass"
    case maintain = "maintain"
    case strength
    case endurance
    case recovery

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .loseWeight: return "coaching.goal.lose_weight"
        case .gainMass: return "coaching.goal.gain_mass"
        case .maintain: return "coaching.goal.maintain"
        case .strength: return "coaching.goal.strength"
        case .endurance: return "coaching.goal.endurance"
        case .recovery: return "coaching.goal.recovery"
        }
    }
}

enum ClientCoachingSex: String, CaseIterable, Codable, Identifiable {
    case male
    case female

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .male: return "profile.gender.male"
        case .female: return "profile.gender.female"
        }
    }
}

enum ClientCoachingActivity: String, CaseIterable, Codable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .low: return "coaching.activity.low"
        case .medium: return "coaching.activity.medium"
        case .high: return "coaching.activity.high"
        }
    }
}

enum ClientCoachingExperience: String, CaseIterable, Codable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .beginner: return "coaching.experience.beginner"
        case .intermediate: return "coaching.experience.intermediate"
        case .advanced: return "coaching.experience.advanced"
        }
    }
}

enum CoachingRequestStatus: String, CaseIterable, Codable {
    case draft
    case submitted
    case needsClarification = "needs_clarification"
    case approved
    case rejected
    case assigned

    var localizationKey: String {
        switch self {
        case .draft: return "coaching.status.draft"
        case .submitted: return "coaching.status.submitted"
        case .needsClarification: return "coaching.status.needs_clarification"
        case .approved: return "coaching.status.approved"
        case .rejected: return "coaching.status.rejected"
        case .assigned: return "coaching.status.assigned"
        }
    }
}

struct ClientCoachingMeasurements: Hashable {
    var waist: Double
    var chest: Double
    var hips: Double
}

struct ClientIntakeProfile: Identifiable, Hashable {
    let id: String
    var clientId: String
    var clientEmail: String
    var clientDisplayName: String
    var goal: ClientCoachingGoal
    var age: Int
    var height: Double
    var weight: Double
    var sex: ClientCoachingSex
    var activity: ClientCoachingActivity
    var experience: ClientCoachingExperience
    var limitations: String
    var equipment: String
    var schedule: String
    var notes: String
    var measurements: ClientCoachingMeasurements
    var status: String
    var updatedAt: Date
    var submittedAt: Date?

    init(
        id: String,
        clientId: String,
        clientEmail: String,
        clientDisplayName: String,
        goal: ClientCoachingGoal = .maintain,
        age: Int = 25,
        height: Double = 175,
        weight: Double = 70,
        sex: ClientCoachingSex = .male,
        activity: ClientCoachingActivity = .medium,
        experience: ClientCoachingExperience = .beginner,
        limitations: String = "",
        equipment: String = "",
        schedule: String = "",
        notes: String = "",
        measurements: ClientCoachingMeasurements = .init(waist: 0, chest: 0, hips: 0),
        status: String = "draft",
        updatedAt: Date = .now,
        submittedAt: Date? = nil
    ) {
        self.id = id
        self.clientId = clientId
        self.clientEmail = clientEmail
        self.clientDisplayName = clientDisplayName
        self.goal = goal
        self.age = age
        self.height = height
        self.weight = weight
        self.sex = sex
        self.activity = activity
        self.experience = experience
        self.limitations = limitations
        self.equipment = equipment
        self.schedule = schedule
        self.notes = notes
        self.measurements = measurements
        self.status = status
        self.updatedAt = updatedAt
        self.submittedAt = submittedAt
    }

    init?(id: String, data: [String: Any]) {
        guard
            let clientId = data["clientId"] as? String,
            let clientEmail = data["clientEmail"] as? String,
            let clientDisplayName = data["clientDisplayName"] as? String,
            let goalRaw = data["goal"] as? String,
            let goal = ClientCoachingGoal(rawValue: goalRaw),
            let age = data["age"] as? Int,
            let height = data["height"] as? Double,
            let weight = data["weight"] as? Double,
            let sexRaw = data["sex"] as? String,
            let sex = ClientCoachingSex(rawValue: sexRaw),
            let activityRaw = data["activity"] as? String,
            let activity = ClientCoachingActivity(rawValue: activityRaw),
            let experienceRaw = data["experience"] as? String,
            let experience = ClientCoachingExperience(rawValue: experienceRaw),
            let limitations = data["limitations"] as? String,
            let equipment = data["equipment"] as? String,
            let schedule = data["schedule"] as? String,
            let notes = data["notes"] as? String,
            let waist = data["measurementWaist"] as? Double,
            let chest = data["measurementChest"] as? Double,
            let hips = data["measurementHips"] as? Double
        else {
            return nil
        }

        self.id = id
        self.clientId = clientId
        self.clientEmail = clientEmail
        self.clientDisplayName = clientDisplayName
        self.goal = goal
        self.age = age
        self.height = height
        self.weight = weight
        self.sex = sex
        self.activity = activity
        self.experience = experience
        self.limitations = limitations
        self.equipment = equipment
        self.schedule = schedule
        self.notes = notes
        self.measurements = .init(waist: waist, chest: chest, hips: hips)
        self.status = (data["status"] as? String) ?? "draft"
        if let updatedAt = data["updatedAt"] as? Timestamp {
            self.updatedAt = updatedAt.dateValue()
        } else {
            self.updatedAt = (data["updatedAt"] as? Date) ?? .now
        }
        if let submittedAt = data["submittedAt"] as? Timestamp {
            self.submittedAt = submittedAt.dateValue()
        } else {
            self.submittedAt = data["submittedAt"] as? Date
        }
    }

    var firestoreData: [String: Any] {
        [
            "clientId": clientId,
            "clientEmail": clientEmail,
            "clientDisplayName": clientDisplayName,
            "goal": goal.rawValue,
            "age": age,
            "height": height,
            "weight": weight,
            "sex": sex.rawValue,
            "activity": activity.rawValue,
            "experience": experience.rawValue,
            "limitations": limitations,
            "equipment": equipment,
            "schedule": schedule,
            "notes": notes,
            "measurementWaist": measurements.waist,
            "measurementChest": measurements.chest,
            "measurementHips": measurements.hips,
            "status": status,
            "updatedAt": updatedAt,
            "submittedAt": submittedAt as Any
        ]
    }

    var snapshotData: [String: Any] { firestoreData }
}

struct CoachingRequest: Identifiable, Hashable {
    let id: String
    var clientId: String
    var status: CoachingRequestStatus
    var reviewComment: String
    var assignedTrainerId: String?
    var updatedAt: Date
    var submittedAt: Date?

    init(
        id: String,
        clientId: String,
        status: CoachingRequestStatus = .draft,
        reviewComment: String = "",
        assignedTrainerId: String? = nil,
        updatedAt: Date = .now,
        submittedAt: Date? = nil
    ) {
        self.id = id
        self.clientId = clientId
        self.status = status
        self.reviewComment = reviewComment
        self.assignedTrainerId = assignedTrainerId
        self.updatedAt = updatedAt
        self.submittedAt = submittedAt
    }

    init?(id: String, data: [String: Any]) {
        guard
            let clientId = data["clientId"] as? String,
            let statusRaw = data["status"] as? String,
            let status = CoachingRequestStatus(rawValue: statusRaw)
        else {
            return nil
        }

        self.id = id
        self.clientId = clientId
        self.status = status
        self.reviewComment = data["reviewComment"] as? String ?? ""
        self.assignedTrainerId = data["assignedTrainerId"] as? String
        if let updatedAt = data["updatedAt"] as? Timestamp {
            self.updatedAt = updatedAt.dateValue()
        } else {
            self.updatedAt = (data["updatedAt"] as? Date) ?? .now
        }
        if let submittedAt = data["submittedAt"] as? Timestamp {
            self.submittedAt = submittedAt.dateValue()
        } else {
            self.submittedAt = data["submittedAt"] as? Date
        }
    }

    func firestoreData(with intake: ClientIntakeProfile) -> [String: Any] {
        [
            "clientId": clientId,
            "status": status.rawValue,
            "reviewComment": reviewComment,
            "assignedTrainerId": assignedTrainerId as Any,
            "updatedAt": updatedAt,
            "submittedAt": submittedAt as Any,
            "intakeSnapshot": intake.snapshotData
        ]
    }
}

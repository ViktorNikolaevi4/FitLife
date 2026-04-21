import SwiftUI
import FirebaseFirestore
import SwiftData

enum ProfileUpdateRequestType: String, CaseIterable, Codable, Identifiable {
    case weightUpdate = "weight_update"
    case measurementsUpdate = "measurements_update"
    case limitationsUpdate = "limitations_update"
    case equipmentUpdate = "equipment_update"
    case generalUpdate = "general_update"

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .weightUpdate: return "coaching.update_request.type.weight"
        case .measurementsUpdate: return "coaching.update_request.type.measurements"
        case .limitationsUpdate: return "coaching.update_request.type.limitations"
        case .equipmentUpdate: return "coaching.update_request.type.equipment"
        case .generalUpdate: return "coaching.update_request.type.general"
        }
    }
}

enum CoachingNoteAuthorRole: String, Codable {
    case trainer
    case client
}

struct ProgressCheckIn: Identifiable, Hashable {
    let id: String
    let clientId: String
    let trainerId: String
    let weight: Double
    let waist: Double
    let chest: Double
    let hips: Double
    let energy: Int
    let adherence: Int
    let notes: String
    let createdAt: Date

    init(
        id: String,
        clientId: String,
        trainerId: String,
        weight: Double,
        waist: Double,
        chest: Double,
        hips: Double,
        energy: Int,
        adherence: Int,
        notes: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.clientId = clientId
        self.trainerId = trainerId
        self.weight = weight
        self.waist = waist
        self.chest = chest
        self.hips = hips
        self.energy = energy
        self.adherence = adherence
        self.notes = notes
        self.createdAt = createdAt
    }

    init?(id: String, data: [String: Any]) {
        guard
            let clientId = data["clientId"] as? String,
            let trainerId = data["trainerId"] as? String,
            let weight = data["weight"] as? Double,
            let waist = data["waist"] as? Double,
            let chest = data["chest"] as? Double,
            let hips = data["hips"] as? Double,
            let energy = data["energy"] as? Int,
            let adherence = data["adherence"] as? Int,
            let notes = data["notes"] as? String
        else {
            return nil
        }

        self.id = id
        self.clientId = clientId
        self.trainerId = trainerId
        self.weight = weight
        self.waist = waist
        self.chest = chest
        self.hips = hips
        self.energy = energy
        self.adherence = adherence
        self.notes = notes
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = (data["createdAt"] as? Date) ?? .now
        }
    }

    var firestoreData: [String: Any] {
        [
            "clientId": clientId,
            "trainerId": trainerId,
            "weight": weight,
            "waist": waist,
            "chest": chest,
            "hips": hips,
            "energy": energy,
            "adherence": adherence,
            "notes": notes,
            "createdAt": createdAt
        ]
    }
}

struct ProfileUpdateRequest: Identifiable, Hashable {
    let id: String
    let clientId: String
    let trainerId: String
    let type: ProfileUpdateRequestType
    let message: String
    let status: String
    let createdAt: Date
    let resolvedAt: Date?

    init(
        id: String,
        clientId: String,
        trainerId: String,
        type: ProfileUpdateRequestType,
        message: String,
        status: String = "open",
        createdAt: Date = .now,
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.clientId = clientId
        self.trainerId = trainerId
        self.type = type
        self.message = message
        self.status = status
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
    }

    init?(id: String, data: [String: Any]) {
        guard
            let clientId = data["clientId"] as? String,
            let trainerId = data["trainerId"] as? String,
            let typeRaw = data["type"] as? String,
            let type = ProfileUpdateRequestType(rawValue: typeRaw),
            let message = data["message"] as? String
        else {
            return nil
        }

        self.id = id
        self.clientId = clientId
        self.trainerId = trainerId
        self.type = type
        self.message = message
        self.status = (data["status"] as? String) ?? "open"
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = (data["createdAt"] as? Date) ?? .now
        }
        if let timestamp = data["resolvedAt"] as? Timestamp {
            self.resolvedAt = timestamp.dateValue()
        } else {
            self.resolvedAt = data["resolvedAt"] as? Date
        }
    }

    var firestoreData: [String: Any] {
        [
            "clientId": clientId,
            "trainerId": trainerId,
            "type": type.rawValue,
            "message": message,
            "status": status,
            "createdAt": createdAt,
            "resolvedAt": resolvedAt as Any
        ]
    }
}

struct CoachingNote: Identifiable, Hashable {
    let id: String
    let clientId: String
    let trainerId: String
    let authorId: String
    let authorRole: CoachingNoteAuthorRole
    let message: String
    let createdAt: Date

    init(
        id: String,
        clientId: String,
        trainerId: String,
        authorId: String,
        authorRole: CoachingNoteAuthorRole,
        message: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.clientId = clientId
        self.trainerId = trainerId
        self.authorId = authorId
        self.authorRole = authorRole
        self.message = message
        self.createdAt = createdAt
    }

    init?(id: String, data: [String: Any]) {
        guard
            let clientId = data["clientId"] as? String,
            let trainerId = data["trainerId"] as? String,
            let authorId = data["authorId"] as? String,
            let authorRoleRaw = data["authorRole"] as? String,
            let authorRole = CoachingNoteAuthorRole(rawValue: authorRoleRaw),
            let message = data["message"] as? String
        else {
            return nil
        }

        self.id = id
        self.clientId = clientId
        self.trainerId = trainerId
        self.authorId = authorId
        self.authorRole = authorRole
        self.message = message
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = (data["createdAt"] as? Date) ?? .now
        }
    }

    var firestoreData: [String: Any] {
        [
            "clientId": clientId,
            "trainerId": trainerId,
            "authorId": authorId,
            "authorRole": authorRole.rawValue,
            "message": message,
            "createdAt": createdAt
        ]
    }
}

struct CoachingWorkoutSetSnapshot: Hashable {
    let orderIndex: Int
    let weight: Double
    let reps: Int
    let durationSeconds: Int
    let metricTypeRaw: String
    let isCompleted: Bool

    init(set: WorkoutSet) {
        orderIndex = set.orderIndex
        weight = set.weight
        reps = set.reps
        durationSeconds = set.durationSeconds
        metricTypeRaw = set.metricType.rawValue
        isCompleted = set.isCompleted
    }

    init?(_ data: [String: Any]) {
        guard
            let orderIndex = data["orderIndex"] as? Int,
            let weight = data["weight"] as? Double,
            let reps = data["reps"] as? Int,
            let durationSeconds = data["durationSeconds"] as? Int,
            let metricTypeRaw = data["metricTypeRaw"] as? String,
            let isCompleted = data["isCompleted"] as? Bool
        else {
            return nil
        }

        self.orderIndex = orderIndex
        self.weight = weight
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.metricTypeRaw = metricTypeRaw
        self.isCompleted = isCompleted
    }

    var firestoreData: [String: Any] {
        [
            "orderIndex": orderIndex,
            "weight": weight,
            "reps": reps,
            "durationSeconds": durationSeconds,
            "metricTypeRaw": metricTypeRaw,
            "isCompleted": isCompleted
        ]
    }
}

struct CoachingWorkoutExerciseSnapshot: Identifiable, Hashable {
    let id: String
    let name: String
    let systemImage: String
    let accentName: String
    let orderIndex: Int
    let note: String
    let sets: [CoachingWorkoutSetSnapshot]

    init(exercise: WorkoutExercise) {
        id = exercise.id.uuidString
        name = exercise.name
        systemImage = exercise.systemImage
        accentName = exercise.accentName
        orderIndex = exercise.orderIndex
        note = exercise.note
        sets = exercise.sets
            .sorted { $0.orderIndex < $1.orderIndex }
            .map(CoachingWorkoutSetSnapshot.init(set:))
    }

    init?(_ data: [String: Any]) {
        guard
            let id = data["id"] as? String,
            let name = data["name"] as? String,
            let systemImage = data["systemImage"] as? String,
            let accentName = data["accentName"] as? String,
            let orderIndex = data["orderIndex"] as? Int,
            let note = data["note"] as? String,
            let setsData = data["sets"] as? [[String: Any]]
        else {
            return nil
        }

        self.id = id
        self.name = name
        self.systemImage = systemImage
        self.accentName = accentName
        self.orderIndex = orderIndex
        self.note = note
        self.sets = setsData.compactMap(CoachingWorkoutSetSnapshot.init)
    }

    var firestoreData: [String: Any] {
        [
            "id": id,
            "name": name,
            "systemImage": systemImage,
            "accentName": accentName,
            "orderIndex": orderIndex,
            "note": note,
            "sets": sets.map(\.firestoreData)
        ]
    }
}

struct CoachingWorkoutSnapshot: Identifiable, Hashable {
    let id: String
    let title: String
    let createdAt: Date
    let endedAt: Date?
    let elapsedSeconds: Int
    let note: String
    let exercises: [CoachingWorkoutExerciseSnapshot]

    init(workout: WorkoutSession) {
        id = workout.id.uuidString
        title = workout.title
        createdAt = workout.createdAt
        endedAt = workout.endedAt
        elapsedSeconds = workout.elapsedSeconds
        note = workout.note
        exercises = workout.exercises
            .sorted { $0.orderIndex < $1.orderIndex }
            .map(CoachingWorkoutExerciseSnapshot.init(exercise:))
    }

    init?(_ data: [String: Any]) {
        guard
            let id = data["id"] as? String,
            let title = data["title"] as? String,
            let elapsedSeconds = data["elapsedSeconds"] as? Int,
            let note = data["note"] as? String,
            let exercisesData = data["exercises"] as? [[String: Any]]
        else {
            return nil
        }

        self.id = id
        self.title = title
        self.elapsedSeconds = elapsedSeconds
        self.note = note
        if let createdTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdTimestamp.dateValue()
        } else {
            self.createdAt = (data["createdAt"] as? Date) ?? .now
        }
        if let endedTimestamp = data["endedAt"] as? Timestamp {
            self.endedAt = endedTimestamp.dateValue()
        } else {
            self.endedAt = data["endedAt"] as? Date
        }
        self.exercises = exercisesData.compactMap(CoachingWorkoutExerciseSnapshot.init)
    }

    var firestoreData: [String: Any] {
        [
            "id": id,
            "title": title,
            "createdAt": createdAt,
            "endedAt": endedAt as Any,
            "elapsedSeconds": elapsedSeconds,
            "note": note,
            "exercises": exercises.map(\.firestoreData)
        ]
    }

    var exerciseCount: Int { exercises.count }
    var setCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var completedSetCount: Int { exercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count } }
    var exerciseNoteCount: Int { exercises.filter { $0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }.count }
}

struct CoachingWorkoutReport: Identifiable, Hashable {
    let id: String
    let clientId: String
    let trainerId: String
    let createdAt: Date
    let workouts: [CoachingWorkoutSnapshot]

    init(id: String = UUID().uuidString, clientId: String, trainerId: String, createdAt: Date = .now, workouts: [CoachingWorkoutSnapshot]) {
        self.id = id
        self.clientId = clientId
        self.trainerId = trainerId
        self.createdAt = createdAt
        self.workouts = workouts
    }

    init?(id: String, data: [String: Any]) {
        guard
            let clientId = data["clientId"] as? String,
            let trainerId = data["trainerId"] as? String,
            let workoutsData = data["workouts"] as? [[String: Any]]
        else {
            return nil
        }

        self.id = id
        self.clientId = clientId
        self.trainerId = trainerId
        if let createdTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdTimestamp.dateValue()
        } else {
            self.createdAt = (data["createdAt"] as? Date) ?? .now
        }
        self.workouts = workoutsData.compactMap(CoachingWorkoutSnapshot.init)
    }

    var firestoreData: [String: Any] {
        [
            "clientId": clientId,
            "trainerId": trainerId,
            "createdAt": createdAt,
            "workouts": workouts.map(\.firestoreData)
        ]
    }

    var workoutCount: Int { workouts.count }
}

@MainActor
final class ClientCoachingHomeStore: ObservableObject {
    @Published private(set) var checkIns: [ProgressCheckIn] = []
    @Published private(set) var updateRequests: [ProfileUpdateRequest] = []
    @Published private(set) var notes: [CoachingNote] = []
    @Published private(set) var workoutReports: [CoachingWorkoutReport] = []
    @Published private(set) var nutritionReports: [CoachingNutritionReport] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?

    private let clientId: String
    private let trainerId: String
    private let firestore: Firestore

    init(clientId: String, trainerId: String, firestore: Firestore = .firestore()) {
        self.clientId = clientId
        self.trainerId = trainerId
        self.firestore = firestore
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            async let checkInsSnapshot = firestore
                .collection("progress_checkins")
                .whereField("clientId", isEqualTo: clientId)
                .getDocuments()

            async let requestsSnapshot = firestore
                .collection("profile_update_requests")
                .whereField("clientId", isEqualTo: clientId)
                .getDocuments()

            async let notesSnapshot = firestore
                .collection("coaching_notes")
                .whereField("clientId", isEqualTo: clientId)
                .getDocuments()

            async let workoutReportsSnapshot = firestore
                .collection("coaching_workout_reports")
                .whereField("clientId", isEqualTo: clientId)
                .whereField("trainerId", isEqualTo: trainerId)
                .getDocuments()

            async let nutritionReportsSnapshot = firestore
                .collection("coaching_nutrition_reports")
                .whereField("clientId", isEqualTo: clientId)
                .whereField("trainerId", isEqualTo: trainerId)
                .getDocuments()

            let (checkInDocs, requestDocs, noteDocs, workoutReportDocs, nutritionReportDocs) = try await (
                checkInsSnapshot,
                requestsSnapshot,
                notesSnapshot,
                workoutReportsSnapshot,
                nutritionReportsSnapshot
            )

            checkIns = checkInDocs.documents.compactMap { ProgressCheckIn(id: $0.documentID, data: $0.data()) }
                .sorted { $0.createdAt > $1.createdAt }

            updateRequests = requestDocs.documents.compactMap { ProfileUpdateRequest(id: $0.documentID, data: $0.data()) }
                .sorted { $0.createdAt > $1.createdAt }

            notes = noteDocs.documents.compactMap { CoachingNote(id: $0.documentID, data: $0.data()) }
                .sorted { $0.createdAt > $1.createdAt }

            workoutReports = workoutReportDocs.documents.compactMap { CoachingWorkoutReport(id: $0.documentID, data: $0.data()) }
                .sorted { $0.createdAt > $1.createdAt }

            nutritionReports = nutritionReportDocs.documents.compactMap { CoachingNutritionReport(id: $0.documentID, data: $0.data()) }
                .sorted { $0.createdAt > $1.createdAt }

            isLoading = false
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
            isLoading = false
        }
    }

    func submitCheckIn(
        weight: Double,
        waist: Double,
        chest: Double,
        hips: Double,
        energy: Int,
        adherence: Int,
        notes: String,
        senderName: String = ""
    ) async {
        isSubmitting = true
        errorMessage = nil

        let checkIn = ProgressCheckIn(
            id: UUID().uuidString,
            clientId: clientId,
            trainerId: trainerId,
            weight: weight,
            waist: waist,
            chest: chest,
            hips: hips,
            energy: energy,
            adherence: adherence,
            notes: notes
        )

        do {
            try await firestore
                .collection("progress_checkins")
                .document(checkIn.id)
                .setData(checkIn.firestoreData)
            try? await AppNotificationEventWriter.create(
                type: .checkInSubmitted,
                recipientId: trainerId,
                senderId: clientId,
                senderName: senderName,
                targetType: .checkIn,
                targetId: checkIn.id,
                firestore: firestore
            )
            isSubmitting = false
            await load()
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
            isSubmitting = false
        }
    }

    func sendNote(_ message: String, senderName: String = "") async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        isSubmitting = true
        errorMessage = nil

        let note = CoachingNote(
            id: UUID().uuidString,
            clientId: clientId,
            trainerId: trainerId,
            authorId: clientId,
            authorRole: .client,
            message: trimmed
        )

        do {
            try await firestore
                .collection("coaching_notes")
                .document(note.id)
                .setData(note.firestoreData)
            try? await AppNotificationEventWriter.create(
                type: .clientNoteReceived,
                recipientId: trainerId,
                senderId: clientId,
                senderName: senderName,
                targetType: .coachingConnection,
                targetId: note.id,
                firestore: firestore
            )
            isSubmitting = false
            await load()
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
            isSubmitting = false
        }
    }

    func resolveUpdateRequest(_ request: ProfileUpdateRequest) async {
        errorMessage = nil

        do {
            try await firestore
                .collection("profile_update_requests")
                .document(request.id)
                .setData([
                    "status": "resolved",
                    "resolvedAt": Date()
                ], merge: true)
            await load()
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
        }
    }

    func sendWorkoutReport(workouts: [WorkoutSession], senderName: String = "") async {
        guard workouts.isEmpty == false else { return }

        isSubmitting = true
        errorMessage = nil

        let report = CoachingWorkoutReport(
            clientId: clientId,
            trainerId: trainerId,
            workouts: workouts.map(CoachingWorkoutSnapshot.init(workout:))
        )

        do {
            try await firestore
                .collection("coaching_workout_reports")
                .document(report.id)
                .setData(report.firestoreData)
            try? await AppNotificationEventWriter.create(
                type: .workoutReportSent,
                recipientId: trainerId,
                senderId: clientId,
                senderName: senderName,
                targetType: .workoutReport,
                targetId: report.id,
                firestore: firestore
            )
            isSubmitting = false
            await load()
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
            isSubmitting = false
        }
    }

    func sendNutritionReport(_ report: CoachingNutritionReport, senderName: String = "") async {
        isSubmitting = true
        errorMessage = nil

        do {
            try await firestore
                .collection("coaching_nutrition_reports")
                .document(report.id)
                .setData(report.firestoreData)
            try? await AppNotificationEventWriter.create(
                type: .nutritionReportSent,
                recipientId: trainerId,
                senderId: clientId,
                senderName: senderName,
                targetType: .nutritionReport,
                targetId: report.id,
                firestore: firestore
            )
            isSubmitting = false
            await load()
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
            isSubmitting = false
        }
    }

    func deleteCheckIn(_ checkIn: ProgressCheckIn) async {
        errorMessage = nil

        do {
            try await firestore
                .collection("progress_checkins")
                .document(checkIn.id)
                .delete()
            await load()
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
        }
    }

    func deleteWorkoutReport(_ report: CoachingWorkoutReport) async {
        errorMessage = nil

        do {
            try await firestore
                .collection("coaching_workout_reports")
                .document(report.id)
                .delete()
            await load()
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
        }
    }

    func deleteNutritionReport(_ report: CoachingNutritionReport) async {
        errorMessage = nil

        do {
            try await firestore
                .collection("coaching_nutrition_reports")
                .document(report.id)
                .delete()
            await load()
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
        }
    }
}

@MainActor
final class TrainerClientSupportStore: ObservableObject {
    @Published private(set) var intake: ClientIntakeProfile?
    @Published private(set) var activeLink: TrainerClientLink?
    @Published private(set) var checkIns: [ProgressCheckIn] = []
    @Published private(set) var updateRequests: [ProfileUpdateRequest] = []
    @Published private(set) var notes: [CoachingNote] = []
    @Published private(set) var workoutReports: [CoachingWorkoutReport] = []
    @Published private(set) var nutritionReports: [CoachingNutritionReport] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?

    private let trainerId: String
    private let client: AppUserProfile
    private let firestore: Firestore

    init(trainerId: String, client: AppUserProfile, firestore: Firestore = .firestore()) {
        self.trainerId = trainerId
        self.client = client
        self.firestore = firestore
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            async let intakeSnapshot = firestore
                .collection("client_intakes")
                .document(client.id)
                .getDocument()

            async let activeLinkSnapshot = firestore
                .collection("trainer_client_links")
                .document("\(trainerId)_\(client.id)")
                .getDocument()

            async let checkInsSnapshot = firestore
                .collection("progress_checkins")
                .whereField("clientId", isEqualTo: client.id)
                .whereField("trainerId", isEqualTo: trainerId)
                .getDocuments()

            async let requestsSnapshot = firestore
                .collection("profile_update_requests")
                .whereField("clientId", isEqualTo: client.id)
                .whereField("trainerId", isEqualTo: trainerId)
                .getDocuments()

            async let notesSnapshot = firestore
                .collection("coaching_notes")
                .whereField("clientId", isEqualTo: client.id)
                .whereField("trainerId", isEqualTo: trainerId)
                .getDocuments()

            async let workoutReportsSnapshot = firestore
                .collection("coaching_workout_reports")
                .whereField("clientId", isEqualTo: client.id)
                .whereField("trainerId", isEqualTo: trainerId)
                .getDocuments()

            async let nutritionReportsSnapshot = firestore
                .collection("coaching_nutrition_reports")
                .whereField("clientId", isEqualTo: client.id)
                .whereField("trainerId", isEqualTo: trainerId)
                .getDocuments()

            let (intakeDoc, activeLinkDoc, checkInDocs, requestDocs, noteDocs, workoutReportDocs, nutritionReportDocs) = try await (
                intakeSnapshot,
                activeLinkSnapshot,
                checkInsSnapshot,
                requestsSnapshot,
                notesSnapshot,
                workoutReportsSnapshot,
                nutritionReportsSnapshot
            )

            intake = intakeDoc.data().flatMap { ClientIntakeProfile(id: intakeDoc.documentID, data: $0) }
            activeLink = activeLinkDoc.data().flatMap { TrainerClientLink(id: activeLinkDoc.documentID, data: $0) }

            checkIns = checkInDocs.documents.compactMap { ProgressCheckIn(id: $0.documentID, data: $0.data()) }
                .sorted { $0.createdAt > $1.createdAt }

            updateRequests = requestDocs.documents.compactMap { ProfileUpdateRequest(id: $0.documentID, data: $0.data()) }
                .sorted { $0.createdAt > $1.createdAt }

            notes = noteDocs.documents.compactMap { CoachingNote(id: $0.documentID, data: $0.data()) }
                .sorted { $0.createdAt > $1.createdAt }

            workoutReports = workoutReportDocs.documents.compactMap { CoachingWorkoutReport(id: $0.documentID, data: $0.data()) }
                .sorted { $0.createdAt > $1.createdAt }

            nutritionReports = nutritionReportDocs.documents.compactMap { CoachingNutritionReport(id: $0.documentID, data: $0.data()) }
                .sorted { $0.createdAt > $1.createdAt }

            isLoading = false
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
            isLoading = false
        }
    }

    func sendNote(_ message: String, senderName: String = "") async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        isSubmitting = true
        errorMessage = nil

        let note = CoachingNote(
            id: UUID().uuidString,
            clientId: client.id,
            trainerId: trainerId,
            authorId: trainerId,
            authorRole: .trainer,
            message: trimmed
        )

        do {
            try await firestore
                .collection("coaching_notes")
                .document(note.id)
                .setData(note.firestoreData)
            try? await AppNotificationEventWriter.create(
                type: .coachNoteReceived,
                recipientId: client.id,
                senderId: trainerId,
                senderName: senderName,
                targetType: .coachingConnection,
                targetId: note.id,
                firestore: firestore
            )
            isSubmitting = false
            await load()
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
            isSubmitting = false
        }
    }

    func createUpdateRequest(type: ProfileUpdateRequestType, message: String, senderName: String = "") async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        isSubmitting = true
        errorMessage = nil

        let request = ProfileUpdateRequest(
            id: UUID().uuidString,
            clientId: client.id,
            trainerId: trainerId,
            type: type,
            message: trimmed
        )

        do {
            try await firestore
                .collection("profile_update_requests")
                .document(request.id)
                .setData(request.firestoreData)
            try? await AppNotificationEventWriter.create(
                type: .profileUpdateRequested,
                recipientId: client.id,
                senderId: trainerId,
                senderName: senderName,
                targetType: .profileUpdateRequest,
                targetId: request.id,
                firestore: firestore
            )
            isSubmitting = false
            await load()
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
            isSubmitting = false
        }
    }
}

struct ClientCoachingHomeScreen: View {
    let clientId: String
    let trainerId: String
    let trainer: AppUserProfile?

    @EnvironmentObject private var sessionStore: AppSessionStore
    @Query private var workouts: [WorkoutSession]
    @StateObject private var store: ClientCoachingHomeStore
    @State private var showCheckInSheet = false
    @State private var showWorkoutReportSheet = false
    @State private var showNutritionReportSheet = false
    @State private var selectedWorkoutReport: CoachingWorkoutReport?
    @State private var selectedNutritionReport: CoachingNutritionReport?
    @State private var showAllCheckIns = false
    @State private var showAllWorkoutReports = false
    @State private var showAllNutritionReports = false
    @State private var noteMessage = ""

    init(clientId: String, trainerId: String, trainer: AppUserProfile?) {
        self.clientId = clientId
        self.trainerId = trainerId
        self.trainer = trainer
        _store = StateObject(wrappedValue: ClientCoachingHomeStore(clientId: clientId, trainerId: trainerId))
    }

    var body: some View {
        List {
            if let errorMessage = store.errorMessage, errorMessage.isEmpty == false {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                if let trainer {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(AppLocalizer.string("coaching.linked.trainer"))
                            .font(.headline)
                        Text(trainer.displayName)
                            .font(.title3.weight(.semibold))
                        Text(trainer.email)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    showCheckInSheet = true
                } label: {
                    Label(AppLocalizer.string("coaching.checkin.action.new"), systemImage: "waveform.path.ecg")
                }

                Button {
                    showWorkoutReportSheet = true
                } label: {
                    Label(AppLocalizer.string("coaching.workouts.action.send"), systemImage: "paperplane.fill")
                }

                Button {
                    showNutritionReportSheet = true
                } label: {
                    Label(AppLocalizer.string("coaching.nutrition.action.send"), systemImage: "fork.knife")
                }
            }

            Section(AppLocalizer.string("coaching.update_request.section")) {
                let openRequests = store.updateRequests.filter { $0.status == "open" }
                if openRequests.isEmpty {
                    Text(AppLocalizer.string("coaching.update_request.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(openRequests) { request in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppLocalizer.string(request.type.localizationKey))
                                .font(.headline)
                            Text(request.message)
                                .foregroundStyle(.secondary)
                            Button(AppLocalizer.string("coaching.update_request.action.resolve")) {
                                Task { await store.resolveUpdateRequest(request) }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section(
                header: coachingSectionHeader(
                    title: AppLocalizer.string("coaching.checkin.history"),
                    showsViewAll: store.checkIns.count > 2,
                    action: { showAllCheckIns = true }
                )
            ) {
                if store.checkIns.isEmpty {
                    Text(AppLocalizer.string("coaching.checkin.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.checkIns.prefix(2)) { checkIn in
                        CoachingCheckInRow(checkIn: checkIn, isTrainerView: false)
                    }
                }
            }

            Section(
                header: coachingSectionHeader(
                    title: AppLocalizer.string("coaching.workouts.section"),
                    showsViewAll: store.workoutReports.count > 2,
                    action: { showAllWorkoutReports = true }
                )
            ) {
                if completedWorkouts.isEmpty {
                    Text(AppLocalizer.string("coaching.workouts.empty.available"))
                        .foregroundStyle(.secondary)
                } else if store.workoutReports.isEmpty {
                    Text(AppLocalizer.string("coaching.workouts.empty.sent"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.workoutReports.prefix(2)) { report in
                        Button {
                            selectedWorkoutReport = report
                        } label: {
                            CoachingWorkoutReportRow(report: report)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section(
                header: coachingSectionHeader(
                    title: AppLocalizer.string("coaching.nutrition.section"),
                    showsViewAll: store.nutritionReports.count > 2,
                    action: { showAllNutritionReports = true }
                )
            ) {
                if store.nutritionReports.isEmpty {
                    Text(AppLocalizer.string("coaching.nutrition.empty.sent"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.nutritionReports.prefix(2)) { report in
                        Button {
                            selectedNutritionReport = report
                        } label: {
                            CoachingNutritionReportRow(report: report)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section(AppLocalizer.string("coaching.notes.section")) {
                TextField(AppLocalizer.string("coaching.notes.placeholder.client"), text: $noteMessage, axis: .vertical)
                    .lineLimit(2...5)

                Button {
                    Task {
                        await store.sendNote(
                            noteMessage,
                            senderName: sessionStore.profile?.displayName ?? ""
                        )
                        if store.errorMessage == nil {
                            noteMessage = ""
                        }
                    }
                } label: {
                    HStack {
                        Text(AppLocalizer.string("coaching.notes.action.send"))
                        Spacer()
                        if store.isSubmitting {
                            ProgressView()
                        }
                    }
                }
                .disabled(store.isSubmitting || noteMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if store.notes.isEmpty {
                    Text(AppLocalizer.string("coaching.notes.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.notes.prefix(10)) { note in
                        CoachingNoteRow(note: note)
                    }
                }
            }
        }
        .navigationTitle(AppLocalizer.string("workouts.connection"))
        .task {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
        .sheet(isPresented: $showCheckInSheet) {
            NavigationStack {
                ClientCheckInFormScreen(store: store)
            }
        }
        .sheet(isPresented: $showWorkoutReportSheet) {
            NavigationStack {
                ClientWorkoutReportComposerScreen(
                    workouts: completedWorkouts,
                    store: store
                )
            }
        }
        .sheet(isPresented: $showNutritionReportSheet) {
            NavigationStack {
                ClientNutritionReportComposerScreen(
                    clientId: clientId,
                    trainerId: trainerId,
                    store: store
                )
            }
        }
        .sheet(item: $selectedWorkoutReport) { report in
            NavigationStack {
                CoachingWorkoutReportDetailScreen(report: report)
            }
        }
        .sheet(item: $selectedNutritionReport) { report in
            NavigationStack {
                CoachingNutritionReportDetailScreen(report: report)
            }
        }
        .sheet(isPresented: $showAllCheckIns) {
            NavigationStack {
                CoachingCheckInHistoryScreen(
                    title: AppLocalizer.string("coaching.checkin.history"),
                    checkIns: store.checkIns,
                    isTrainerView: false,
                    canDelete: true,
                    onDelete: { checkIn in
                        await store.deleteCheckIn(checkIn)
                    }
                )
            }
        }
        .sheet(isPresented: $showAllWorkoutReports) {
            NavigationStack {
                CoachingWorkoutReportHistoryScreen(
                    reports: store.workoutReports,
                    canDelete: true,
                    onDelete: { report in
                        await store.deleteWorkoutReport(report)
                    }
                )
            }
        }
        .sheet(isPresented: $showAllNutritionReports) {
            NavigationStack {
                CoachingNutritionReportHistoryScreen(
                    reports: store.nutritionReports,
                    canDelete: true,
                    onDelete: { report in
                        await store.deleteNutritionReport(report)
                    }
                )
            }
        }
    }

    private var completedWorkouts: [WorkoutSession] {
        workouts
            .filter { $0.ownerId == clientId && $0.endedAt != nil }
            .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
    }
}

private struct ClientCheckInFormScreen: View {
    @ObservedObject var store: ClientCoachingHomeStore
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: AppSessionStore

    @State private var weight: Double = 70
    @State private var waist: Double = 80
    @State private var chest: Double = 95
    @State private var hips: Double = 95
    @State private var energy = 3
    @State private var adherence = 3
    @State private var notes = ""

    var body: some View {
        Form {
            Section(AppLocalizer.string("coaching.checkin.section.metrics")) {
                metricField(AppLocalizer.string("coaching.intake.weight"), value: $weight, unit: AppLocalizer.string("coaching.unit.kg"), precision: .fractionLength(1))
                metricField(AppLocalizer.string("coaching.intake.measurement.waist"), value: $waist, unit: AppLocalizer.string("coaching.unit.cm"), precision: .fractionLength(1))
                metricField(AppLocalizer.string("coaching.intake.measurement.chest"), value: $chest, unit: AppLocalizer.string("coaching.unit.cm"), precision: .fractionLength(1))
                metricField(AppLocalizer.string("coaching.intake.measurement.hips"), value: $hips, unit: AppLocalizer.string("coaching.unit.cm"), precision: .fractionLength(1))
            }

            Section(AppLocalizer.string("coaching.checkin.section.state")) {
                Stepper("\(AppLocalizer.string("coaching.checkin.energy")): \(energy)/5", value: $energy, in: 1...5)
                Stepper("\(AppLocalizer.string("coaching.checkin.adherence")): \(adherence)/5", value: $adherence, in: 1...5)
                TextField(AppLocalizer.string("coaching.checkin.notes"), text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section {
                Button {
                    Task {
                        await store.submitCheckIn(
                            weight: weight,
                            waist: waist,
                            chest: chest,
                            hips: hips,
                            energy: energy,
                            adherence: adherence,
                            notes: notes,
                            senderName: sessionStore.profile?.displayName ?? ""
                        )
                        if store.errorMessage == nil {
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        Text(AppLocalizer.string("coaching.checkin.action.submit"))
                        Spacer()
                        if store.isSubmitting {
                            ProgressView()
                        }
                    }
                }
                .disabled(store.isSubmitting)
            }
        }
        .navigationTitle(AppLocalizer.string("coaching.checkin.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(AppLocalizer.string("common.cancel")) {
                    dismiss()
                }
            }
        }
    }

    private func metricField(
        _ title: String,
        value: Binding<Double>,
        unit: String,
        precision: FloatingPointFormatStyle<Double>.Configuration.Precision
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number.precision(precision))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ClientWorkoutReportComposerScreen: View {
    let workouts: [WorkoutSession]

    @ObservedObject var store: ClientCoachingHomeStore
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: AppSessionStore
    @State private var selectedWorkoutIds: Set<String> = []

    var body: some View {
        List {
            Section {
                Text(AppLocalizer.string("coaching.workouts.compose.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section(AppLocalizer.string("coaching.workouts.compose.section")) {
                if workouts.isEmpty {
                    Text(AppLocalizer.string("coaching.workouts.empty.available"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(workouts, id: \.id) { workout in
                        Button {
                            toggle(workout)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: isSelected(workout) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected(workout) ? Color.accentColor : .secondary)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(workout.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    Text(workoutDateText(workout))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text(
                                        AppLocalizer.format(
                                            "coaching.workouts.summary",
                                            workout.exercises.count,
                                            workout.exercises.reduce(0) { $0 + $1.sets.count }
                                        )
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section {
                Button {
                    Task {
                        await store.sendWorkoutReport(
                            workouts: selectedWorkouts,
                            senderName: sessionStore.profile?.displayName ?? ""
                        )
                        if store.errorMessage == nil {
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        Text(AppLocalizer.string("coaching.workouts.action.submit"))
                        Spacer()
                        if store.isSubmitting {
                            ProgressView()
                        }
                    }
                }
                .disabled(store.isSubmitting || selectedWorkouts.isEmpty)
            }
        }
        .navigationTitle(AppLocalizer.string("coaching.workouts.compose.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(AppLocalizer.string("common.cancel")) {
                    dismiss()
                }
            }
        }
        .onAppear {
            if selectedWorkoutIds.isEmpty, let firstWorkout = workouts.first {
                selectedWorkoutIds.insert(firstWorkout.id.uuidString)
            }
        }
    }

    private var selectedWorkouts: [WorkoutSession] {
        workouts.filter { selectedWorkoutIds.contains($0.id.uuidString) }
    }

    private func isSelected(_ workout: WorkoutSession) -> Bool {
        selectedWorkoutIds.contains(workout.id.uuidString)
    }

    private func toggle(_ workout: WorkoutSession) {
        let id = workout.id.uuidString
        if selectedWorkoutIds.contains(id) {
            selectedWorkoutIds.remove(id)
        } else {
            selectedWorkoutIds.insert(id)
        }
    }

    private func workoutDateText(_ workout: WorkoutSession) -> String {
        (workout.endedAt ?? workout.createdAt).formatted(date: .abbreviated, time: .omitted)
    }
}

struct TrainerClientSupportScreen: View {
    let trainerId: String
    let client: AppUserProfile

    @EnvironmentObject private var sessionStore: AppSessionStore
    @StateObject private var store: TrainerClientSupportStore
    @State private var requestType: ProfileUpdateRequestType = .generalUpdate
    @State private var requestMessage = ""
    @State private var noteMessage = ""
    @State private var selectedWorkoutReport: CoachingWorkoutReport?
    @State private var selectedNutritionReport: CoachingNutritionReport?
    @State private var showAllCheckIns = false
    @State private var showAllWorkoutReports = false
    @State private var showAllNutritionReports = false
    @FocusState private var focusedField: TrainerWorkspaceField?

    init(trainerId: String, client: AppUserProfile) {
        self.trainerId = trainerId
        self.client = client
        _store = StateObject(wrappedValue: TrainerClientSupportStore(trainerId: trainerId, client: client))
    }

    var body: some View {
        List {
            if let errorMessage = store.errorMessage, errorMessage.isEmpty == false {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                TrainerClientWorkspaceSummary(
                    client: client,
                    intake: store.intake,
                    activeLink: store.activeLink,
                    lastCheckIn: store.checkIns.first,
                    openRequestCount: openRequests.count,
                    lastNote: store.notes.first
                )
            }

            Section(AppLocalizer.string("coaching.workspace.quick_actions")) {
                Button {
                    focusedField = .updateRequest
                } label: {
                    Label(AppLocalizer.string("coaching.workspace.action.request_update"), systemImage: "arrow.triangle.2.circlepath")
                }

                Button {
                    focusedField = .note
                } label: {
                    Label(AppLocalizer.string("coaching.workspace.action.add_note"), systemImage: "square.and.pencil")
                }
            }

            if let intake = store.intake {
                Section(AppLocalizer.string("coaching.workspace.intake")) {
                    TrainerWorkspaceInfoRow(
                        title: AppLocalizer.string("coaching.intake.goal"),
                        value: AppLocalizer.string(intake.goal.localizationKey)
                    )
                    TrainerWorkspaceInfoRow(
                        title: AppLocalizer.string("coaching.intake.weight"),
                        value: "\(String(format: "%.1f", intake.weight)) \(AppLocalizer.string("coaching.unit.kg"))"
                    )
                    TrainerWorkspaceInfoRow(
                        title: AppLocalizer.string("coaching.intake.height"),
                        value: "\(String(format: "%.0f", intake.height)) \(AppLocalizer.string("coaching.unit.cm"))"
                    )
                    TrainerWorkspaceInfoRow(
                        title: AppLocalizer.string("coaching.intake.activity"),
                        value: AppLocalizer.string(intake.activity.localizationKey)
                    )
                    TrainerWorkspaceInfoRow(
                        title: AppLocalizer.string("coaching.intake.experience"),
                        value: AppLocalizer.string(intake.experience.localizationKey)
                    )

                    if intake.limitations.isEmpty == false {
                        TrainerWorkspaceTextBlock(
                            title: AppLocalizer.string("coaching.intake.limitations"),
                            value: intake.limitations
                        )
                    }

                    if intake.equipment.isEmpty == false {
                        TrainerWorkspaceTextBlock(
                            title: AppLocalizer.string("coaching.intake.equipment"),
                            value: intake.equipment
                        )
                    }

                    if intake.schedule.isEmpty == false {
                        TrainerWorkspaceTextBlock(
                            title: AppLocalizer.string("coaching.intake.schedule"),
                            value: intake.schedule
                        )
                    }

                    if intake.notes.isEmpty == false {
                        TrainerWorkspaceTextBlock(
                            title: AppLocalizer.string("coaching.intake.notes"),
                            value: intake.notes
                        )
                    }
                }
            }

            Section(AppLocalizer.string("coaching.update_request.section")) {
                Picker(AppLocalizer.string("coaching.update_request.type"), selection: $requestType) {
                    ForEach(ProfileUpdateRequestType.allCases) { type in
                        Text(AppLocalizer.string(type.localizationKey)).tag(type)
                    }
                }

                TextField(AppLocalizer.string("coaching.update_request.message"), text: $requestMessage, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .updateRequest)

                Button {
                    Task {
                        await store.createUpdateRequest(
                            type: requestType,
                            message: requestMessage,
                            senderName: sessionStore.profile?.displayName ?? ""
                        )
                        if store.errorMessage == nil {
                            requestMessage = ""
                            requestType = .generalUpdate
                        }
                    }
                } label: {
                    HStack {
                        Text(AppLocalizer.string("coaching.update_request.action.send"))
                        Spacer()
                        if store.isSubmitting {
                            ProgressView()
                        }
                    }
                }
                .disabled(store.isSubmitting || requestMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if openRequests.isEmpty == false {
                    ForEach(openRequests) { request in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(AppLocalizer.string(request.type.localizationKey))
                                .font(.headline)
                            Text(request.message)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section(
                header: coachingSectionHeader(
                    title: AppLocalizer.string("coaching.checkin.history"),
                    showsViewAll: store.checkIns.count > 2,
                    action: { showAllCheckIns = true }
                )
            ) {
                if store.checkIns.isEmpty {
                    Text(AppLocalizer.string("coaching.checkin.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.checkIns.prefix(2)) { checkIn in
                        CoachingCheckInRow(checkIn: checkIn, isTrainerView: true)
                    }
                }
            }

            Section(
                header: coachingSectionHeader(
                    title: AppLocalizer.string("coaching.workouts.section"),
                    showsViewAll: store.workoutReports.count > 2,
                    action: { showAllWorkoutReports = true }
                )
            ) {
                if store.workoutReports.isEmpty {
                    Text(AppLocalizer.string("coaching.workouts.empty.received"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.workoutReports.prefix(2)) { report in
                        Button {
                            selectedWorkoutReport = report
                        } label: {
                            CoachingWorkoutReportRow(report: report)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section(
                header: coachingSectionHeader(
                    title: AppLocalizer.string("coaching.nutrition.section"),
                    showsViewAll: store.nutritionReports.count > 2,
                    action: { showAllNutritionReports = true }
                )
            ) {
                if store.nutritionReports.isEmpty {
                    Text(AppLocalizer.string("coaching.nutrition.empty.received"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.nutritionReports.prefix(2)) { report in
                        Button {
                            selectedNutritionReport = report
                        } label: {
                            CoachingNutritionReportRow(report: report)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section(AppLocalizer.string("coaching.notes.section")) {
                TextField(AppLocalizer.string("coaching.notes.placeholder.trainer"), text: $noteMessage, axis: .vertical)
                    .lineLimit(2...5)
                    .focused($focusedField, equals: .note)

                Button {
                    Task {
                        await store.sendNote(
                            noteMessage,
                            senderName: sessionStore.profile?.displayName ?? ""
                        )
                        if store.errorMessage == nil {
                            noteMessage = ""
                        }
                    }
                } label: {
                    HStack {
                        Text(AppLocalizer.string("coaching.notes.action.send"))
                        Spacer()
                        if store.isSubmitting {
                            ProgressView()
                        }
                    }
                }
                .disabled(store.isSubmitting || noteMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if store.notes.isEmpty {
                    Text(AppLocalizer.string("coaching.notes.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.notes) { note in
                        CoachingNoteRow(note: note)
                    }
                }
            }
        }
        .navigationTitle(client.displayName)
        .task {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
        .sheet(item: $selectedWorkoutReport) { report in
            NavigationStack {
                CoachingWorkoutReportDetailScreen(report: report)
            }
        }
        .sheet(item: $selectedNutritionReport) { report in
            NavigationStack {
                CoachingNutritionReportDetailScreen(report: report)
            }
        }
        .sheet(isPresented: $showAllCheckIns) {
            NavigationStack {
                CoachingCheckInHistoryScreen(
                    title: AppLocalizer.string("coaching.checkin.history"),
                    checkIns: store.checkIns,
                    isTrainerView: true,
                    canDelete: false,
                    onDelete: nil
                )
            }
        }
        .sheet(isPresented: $showAllWorkoutReports) {
            NavigationStack {
                CoachingWorkoutReportHistoryScreen(
                    reports: store.workoutReports,
                    canDelete: false,
                    onDelete: nil
                )
            }
        }
        .sheet(isPresented: $showAllNutritionReports) {
            NavigationStack {
                CoachingNutritionReportHistoryScreen(
                    reports: store.nutritionReports,
                    canDelete: false,
                    onDelete: nil
                )
            }
        }
    }

    private var openRequests: [ProfileUpdateRequest] {
        store.updateRequests.filter { $0.status == "open" }
    }
}

private struct CoachingWorkoutReportRow: View {
    let report: CoachingWorkoutReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(AppLocalizer.format("coaching.workouts.report.header", report.workoutCount))
                    .font(.headline)
                Spacer()
                Text(report.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(report.workouts, id: \.id) { workout in
                VStack(alignment: .leading, spacing: 6) {
                    Text(workout.title)
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 10) {
                        Text((workout.endedAt ?? workout.createdAt).formatted(date: .abbreviated, time: .omitted))
                        Text(AppLocalizer.format("coaching.workouts.summary", workout.exerciseCount, workout.setCount))
                        Text(AppLocalizer.format("coaching.workouts.completed_sets", workout.completedSetCount))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if workout.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        Text(workout.note)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }

                    if workout.exerciseNoteCount > 0 {
                        Text(AppLocalizer.format("coaching.workouts.exercise_notes", workout.exerciseNoteCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

private func coachingSectionHeader(
    title: String,
    showsViewAll: Bool,
    action: @escaping () -> Void
) -> some View {
    HStack {
        Text(title)
        Spacer()
        if showsViewAll {
            Button(AppLocalizer.string("coaching.history.view_all"), action: action)
                .font(.caption.weight(.semibold))
                .textCase(.none)
        }
    }
}

private struct CoachingCheckInRow: View {
    let checkIn: ProgressCheckIn
    let isTrainerView: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(checkIn.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.headline)
            Text("\(AppLocalizer.string("coaching.intake.weight")): \(String(format: "%.1f", checkIn.weight)) \(AppLocalizer.string("coaching.unit.kg"))")
                .foregroundStyle(.secondary)
            if isTrainerView {
                Text("\(AppLocalizer.string("coaching.intake.measurement.waist")): \(String(format: "%.1f", checkIn.waist)) • \(AppLocalizer.string("coaching.intake.measurement.chest")): \(String(format: "%.1f", checkIn.chest)) • \(AppLocalizer.string("coaching.intake.measurement.hips")): \(String(format: "%.1f", checkIn.hips))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(AppLocalizer.string("coaching.checkin.energy")): \(checkIn.energy)/5  •  \(AppLocalizer.string("coaching.checkin.adherence")): \(checkIn.adherence)/5")
                .font(.caption)
                .foregroundStyle(.secondary)
            if checkIn.notes.isEmpty == false {
                Text(checkIn.notes)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CoachingCheckInHistoryScreen: View {
    let title: String
    let checkIns: [ProgressCheckIn]
    let isTrainerView: Bool
    let canDelete: Bool
    let onDelete: ((ProgressCheckIn) async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var pendingDelete: ProgressCheckIn?

    var body: some View {
        List {
            if checkIns.isEmpty {
                Text(AppLocalizer.string("coaching.checkin.empty"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(checkIns) { checkIn in
                    CoachingCheckInRow(checkIn: checkIn, isTrainerView: isTrainerView)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if canDelete {
                                Button(role: .destructive) {
                                    pendingDelete = checkIn
                                } label: {
                                    Label(AppLocalizer.string("common.delete"), systemImage: "trash")
                                }
                            }
                        }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(AppLocalizer.string("common.close")) {
                    dismiss()
                }
            }
        }
        .alert(AppLocalizer.string("coaching.history.delete.title"), isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button(AppLocalizer.string("common.cancel"), role: .cancel) {
                pendingDelete = nil
            }
            Button(AppLocalizer.string("common.delete"), role: .destructive) {
                guard let pendingDelete, let onDelete else { return }
                Task {
                    await onDelete(pendingDelete)
                }
                self.pendingDelete = nil
            }
        } message: {
            Text(AppLocalizer.string("coaching.history.delete.message"))
        }
    }
}

private struct CoachingWorkoutReportHistoryScreen: View {
    let reports: [CoachingWorkoutReport]
    let canDelete: Bool
    let onDelete: ((CoachingWorkoutReport) async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedWorkoutReport: CoachingWorkoutReport?
    @State private var pendingDelete: CoachingWorkoutReport?

    var body: some View {
        List {
            if reports.isEmpty {
                Text(AppLocalizer.string("coaching.workouts.empty.received"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(reports) { report in
                    Button {
                        selectedWorkoutReport = report
                    } label: {
                        CoachingWorkoutReportRow(report: report)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if canDelete {
                            Button(role: .destructive) {
                                pendingDelete = report
                            } label: {
                                Label(AppLocalizer.string("common.delete"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(AppLocalizer.string("coaching.workouts.section"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(AppLocalizer.string("common.close")) {
                    dismiss()
                }
            }
        }
        .sheet(item: $selectedWorkoutReport) { report in
            NavigationStack {
                CoachingWorkoutReportDetailScreen(report: report)
            }
        }
        .alert(AppLocalizer.string("coaching.history.delete.title"), isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button(AppLocalizer.string("common.cancel"), role: .cancel) {
                pendingDelete = nil
            }
            Button(AppLocalizer.string("common.delete"), role: .destructive) {
                guard let pendingDelete, let onDelete else { return }
                Task {
                    await onDelete(pendingDelete)
                }
                self.pendingDelete = nil
            }
        } message: {
            Text(AppLocalizer.string("coaching.history.delete.message"))
        }
    }
}

struct CoachingWorkoutReportDetailScreen: View {
    let report: CoachingWorkoutReport

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppLocalizer.format("coaching.workouts.report.header", report.workoutCount))
                        .font(.headline)
                    Text(report.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            ForEach(report.workouts, id: \.id) { workout in
                Section(workout.title) {
                    LabeledContent(
                        AppLocalizer.string("coaching.workouts.detail.date"),
                        value: (workout.endedAt ?? workout.createdAt).formatted(date: .abbreviated, time: .omitted)
                    )
                    LabeledContent(
                        AppLocalizer.string("coaching.workouts.detail.duration"),
                        value: formattedElapsed(workout.elapsedSeconds)
                    )
                    LabeledContent(
                        AppLocalizer.string("coaching.workouts.detail.summary"),
                        value: AppLocalizer.format("coaching.workouts.summary", workout.exerciseCount, workout.setCount)
                    )

                    if workout.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(AppLocalizer.string("coaching.workouts.detail.workout_note"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(workout.note)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    }

                    ForEach(workout.exercises.sorted { $0.orderIndex < $1.orderIndex }, id: \.id) { exercise in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(exercise.name)
                                .font(.headline)

                            ForEach(exercise.sets.sorted { $0.orderIndex < $1.orderIndex }, id: \.orderIndex) { set in
                                HStack {
                                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(set.isCompleted ? Color.green : .secondary)
                                    Text(formattedSnapshotSetValue(set))
                                        .font(.subheadline)
                                    Spacer()
                                }
                            }

                            if exercise.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                                Text(exercise.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(AppLocalizer.string("coaching.workouts.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(AppLocalizer.string("common.close")) {
                    dismiss()
                }
            }
        }
    }

    private func formattedElapsed(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func formattedSnapshotSetValue(_ set: CoachingWorkoutSetSnapshot) -> String {
        let metricType = WorkoutSetMetricType(rawValue: set.metricTypeRaw) ?? .reps
        return formattedWorkoutSetValue(
            weight: set.weight,
            reps: set.reps,
            durationSeconds: set.durationSeconds,
            metricType: metricType
        )
    }
}

private struct CoachingNoteRow: View {
    let note: CoachingNote

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppLocalizer.string(note.authorRole == .trainer ? "coaching.notes.author.trainer" : "coaching.notes.author.client"))
                .font(.headline)
            Text(note.message)
            Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private enum TrainerWorkspaceField: Hashable {
    case updateRequest
    case note
}

private struct TrainerClientWorkspaceSummary: View {
    let client: AppUserProfile
    let intake: ClientIntakeProfile?
    let activeLink: TrainerClientLink?
    let lastCheckIn: ProgressCheckIn?
    let openRequestCount: Int
    let lastNote: CoachingNote?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(client.displayName)
                    .font(.title3.weight(.semibold))
                Text(client.email)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                WorkspaceMetricCard(
                    title: AppLocalizer.string("coaching.workspace.metric.goal"),
                    value: intake.map { AppLocalizer.string($0.goal.localizationKey) } ?? "—"
                )
                WorkspaceMetricCard(
                    title: AppLocalizer.string("coaching.workspace.metric.weight"),
                    value: intake.map { "\(String(format: "%.1f", $0.weight))" } ?? "—",
                    suffix: intake == nil ? nil : AppLocalizer.string("coaching.unit.kg")
                )
            }

            HStack(spacing: 12) {
                WorkspaceMetricCard(
                    title: AppLocalizer.string("coaching.workspace.metric.last_checkin"),
                    value: lastCheckIn.map { $0.createdAt.formatted(date: .abbreviated, time: .omitted) } ?? "—"
                )
                WorkspaceMetricCard(
                    title: AppLocalizer.string("coaching.workspace.metric.open_requests"),
                    value: "\(openRequestCount)"
                )
            }

            if let activeLink {
                Label(
                    "\(AppLocalizer.string("coaching.workspace.connected_since")) \(activeLink.createdAt.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "link"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            if let lastNote, lastNote.message.isEmpty == false {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppLocalizer.string("coaching.workspace.last_note"))
                        .font(.headline)
                    Text(lastNote.message)
                        .font(.subheadline)
                    Text(lastNote.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct WorkspaceMetricCard: View {
    let title: String
    let value: String
    var suffix: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.headline)
                if let suffix {
                    Text(suffix)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct TrainerWorkspaceInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer(minLength: 16)
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
    }
}

private struct TrainerWorkspaceTextBlock: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

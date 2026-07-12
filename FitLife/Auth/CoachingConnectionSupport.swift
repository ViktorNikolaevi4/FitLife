import SwiftUI
import FirebaseFirestore
import SwiftData

enum CoachingReportDateRange: String, CaseIterable, Identifiable {
    case all
    case today
    case yesterday
    case week
    case month
    case threeMonths
    case halfYear
    case year
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return AppLocalizer.string("coaching.reports.range.all")
        case .today:
            return AppLocalizer.string("coaching.reports.range.today")
        case .yesterday:
            return AppLocalizer.string("coaching.reports.range.yesterday")
        case .week:
            return AppLocalizer.string("coaching.reports.range.week")
        case .month:
            return AppLocalizer.string("coaching.reports.range.month")
        case .threeMonths:
            return AppLocalizer.string("coaching.reports.range.three_months")
        case .halfYear:
            return AppLocalizer.string("coaching.reports.range.half_year")
        case .year:
            return AppLocalizer.string("coaching.reports.range.year")
        case .custom:
            return AppLocalizer.string("coaching.reports.range.custom")
        }
    }

    func contains(
        _ date: Date,
        customStart: Date,
        customEnd: Date,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        switch self {
        case .all:
            return true
        case .today:
            return calendar.isDateInToday(date)
        case .yesterday:
            return calendar.isDateInYesterday(date)
        case .week:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return true }
            return interval.contains(date)
        case .month:
            guard let interval = calendar.dateInterval(of: .month, for: now) else { return true }
            return interval.contains(date)
        case .threeMonths:
            guard let start = calendar.date(byAdding: .month, value: -3, to: now) else { return true }
            return date >= start && date <= now
        case .halfYear:
            guard let start = calendar.date(byAdding: .month, value: -6, to: now) else { return true }
            return date >= start && date <= now
        case .year:
            guard let start = calendar.date(byAdding: .year, value: -1, to: now) else { return true }
            return date >= start && date <= now
        case .custom:
            let start = calendar.startOfDay(for: customStart)
            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: customEnd) ?? customEnd
            return date >= start && date <= end
        }
    }
}

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
        sets = exercise.setItems
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

struct CoachingWorkoutBlockSnapshot: Identifiable, Hashable {
    let id: String
    let title: String
    let typeRawValue: String
    let orderIndex: Int
    let rounds: Int
    let restBetweenRoundsSeconds: Int
    let exercises: [CoachingWorkoutExerciseSnapshot]

    init(block: WorkoutBlock) {
        id = block.id.uuidString
        title = block.title
        typeRawValue = block.typeRawValue
        orderIndex = block.orderIndex
        rounds = block.rounds
        restBetweenRoundsSeconds = block.restBetweenRoundsSeconds
        exercises = block.exerciseItems
            .sorted { $0.orderIndex < $1.orderIndex }
            .map(CoachingWorkoutExerciseSnapshot.init(exercise:))
    }

    init(legacyExercises: [CoachingWorkoutExerciseSnapshot]) {
        id = "legacy-strength"
        title = AppLocalizer.string("workout.block.strength.title")
        typeRawValue = WorkoutBlockType.strength.rawValue
        orderIndex = 0
        rounds = 1
        restBetweenRoundsSeconds = 0
        exercises = legacyExercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    init?(_ data: [String: Any]) {
        guard
            let id = data["id"] as? String,
            let title = data["title"] as? String,
            let typeRawValue = data["typeRawValue"] as? String,
            let orderIndex = data["orderIndex"] as? Int,
            let rounds = data["rounds"] as? Int,
            let restBetweenRoundsSeconds = data["restBetweenRoundsSeconds"] as? Int,
            let exercisesData = data["exercises"] as? [[String: Any]]
        else {
            return nil
        }

        self.id = id
        self.title = title
        self.typeRawValue = typeRawValue
        self.orderIndex = orderIndex
        self.rounds = rounds
        self.restBetweenRoundsSeconds = restBetweenRoundsSeconds
        self.exercises = exercisesData.compactMap(CoachingWorkoutExerciseSnapshot.init)
    }

    var firestoreData: [String: Any] {
        [
            "id": id,
            "title": title,
            "typeRawValue": typeRawValue,
            "orderIndex": orderIndex,
            "rounds": rounds,
            "restBetweenRoundsSeconds": restBetweenRoundsSeconds,
            "exercises": exercises.map(\.firestoreData)
        ]
    }

    var type: WorkoutBlockType {
        WorkoutBlockType(rawValue: typeRawValue) ?? .strength
    }

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            return type.title
        }
        return trimmedTitle
    }

    var subtitle: String {
        switch type {
        case .circuit:
            return AppLocalizer.format(
                "workout.block.circuit.summary",
                rounds,
                exercises.count,
                restBetweenRoundsSeconds
            )
        default:
            return AppLocalizer.format("workout.block.exercise_count", exercises.count)
        }
    }
}

struct CoachingWorkoutSnapshot: Identifiable, Hashable {
    let id: String
    let title: String
    let createdAt: Date
    let endedAt: Date?
    let elapsedSeconds: Int
    let estimatedCalories: Int
    let note: String
    let exercises: [CoachingWorkoutExerciseSnapshot]
    let blocks: [CoachingWorkoutBlockSnapshot]

    init(workout: WorkoutSession) {
        id = workout.id.uuidString
        title = workout.title
        createdAt = workout.createdAt
        endedAt = workout.endedAt
        elapsedSeconds = workout.elapsedSeconds
        estimatedCalories = workout.estimatedCalories
        note = workout.note
        exercises = workout.exerciseItems
            .sorted { $0.orderIndex < $1.orderIndex }
            .map(CoachingWorkoutExerciseSnapshot.init(exercise:))
        blocks = workout.blockItems
            .sorted { $0.orderIndex < $1.orderIndex }
            .map(CoachingWorkoutBlockSnapshot.init(block:))
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
        self.estimatedCalories = (data["estimatedCalories"] as? Int) ?? 0
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
        if let blocksData = data["blocks"] as? [[String: Any]] {
            self.blocks = blocksData.compactMap(CoachingWorkoutBlockSnapshot.init)
        } else {
            self.blocks = []
        }
    }

    var firestoreData: [String: Any] {
        [
            "id": id,
            "title": title,
            "createdAt": createdAt,
            "endedAt": endedAt as Any,
            "elapsedSeconds": elapsedSeconds,
            "estimatedCalories": estimatedCalories,
            "note": note,
            "exercises": exercises.map(\.firestoreData),
            "blocks": blocks.map(\.firestoreData)
        ]
    }

    var exerciseCount: Int { exercises.count }
    var setCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var completedSetCount: Int { exercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count } }
    var exerciseNoteCount: Int { exercises.filter { $0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }.count }
    var displayBlocks: [CoachingWorkoutBlockSnapshot] {
        blocks.isEmpty ? [CoachingWorkoutBlockSnapshot(legacyExercises: exercises)] : blocks
    }
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

    func deleteNote(_ note: CoachingNote) async {
        errorMessage = nil

        do {
            try await firestore
                .collection("coaching_notes")
                .document(note.id)
                .delete()
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

    func deleteNote(_ note: CoachingNote) async {
        errorMessage = nil

        do {
            try await firestore
                .collection("coaching_notes")
                .document(note.id)
                .delete()
            await load()
        } catch {
            errorMessage = AppErrorPresenter.message(for: error)
        }
    }
}

struct ClientCoachingHomeScreen: View {
    let clientId: String
    let trainerId: String
    let trainer: AppUserProfile?

    @EnvironmentObject private var sessionStore: AppSessionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
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
    @State private var showAllNotes = false
    @State private var noteMessage = ""

    init(clientId: String, trainerId: String, trainer: AppUserProfile?) {
        self.clientId = clientId
        self.trainerId = trainerId
        self.trainer = trainer
        _store = StateObject(wrappedValue: ClientCoachingHomeStore(clientId: clientId, trainerId: trainerId))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let errorMessage = store.errorMessage, errorMessage.isEmpty == false {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                trainerCard
                requestCard
                summaryNavigationCard(
                    icon: "clock",
                    title: AppLocalizer.string("coaching.checkin.history"),
                    subtitle: store.checkIns.isEmpty ? AppLocalizer.string("coaching.checkin.empty") : latestCheckInSubtitle,
                    action: { showAllCheckIns = true }
                )
                summaryNavigationCard(
                    icon: "dumbbell.fill",
                    title: AppLocalizer.string("coaching.workouts.section"),
                    subtitle: workoutReportsSubtitle,
                    action: { showAllWorkoutReports = true }
                )
                summaryNavigationCard(
                    icon: "fork.knife",
                    title: AppLocalizer.string("coaching.nutrition.section"),
                    subtitle: nutritionReportsSubtitle,
                    action: { showAllNutritionReports = true }
                )
                notesSection
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 30)
        }
        .background(coachingBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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
        .sheet(isPresented: $showAllNotes) {
            NavigationStack {
                ClientCoachingChatScreen(
                    store: store,
                    noteMessage: $noteMessage
                )
            }
        }
    }

    private var completedWorkouts: [WorkoutSession] {
        workouts
            .filter { $0.ownerId == clientId && $0.endedAt != nil }
            .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
    }

    private var coachingBackground: Color {
        colorScheme == .dark ? Color(.systemGroupedBackground) : HomeColors.background
    }

    private var cardShadow: Color {
        colorScheme == .dark ? .clear : HomeColors.shadow
    }

    private var openRequests: [ProfileUpdateRequest] {
        store.updateRequests.filter { $0.status == "open" }
    }

    private var latestCheckInSubtitle: String {
        guard let checkIn = store.checkIns.first else {
            return AppLocalizer.string("coaching.checkin.empty")
        }
        return "\(checkIn.createdAt.formatted(date: .abbreviated, time: .omitted)) • \(String(format: "%.1f", checkIn.weight)) \(AppLocalizer.string("coaching.unit.kg"))"
    }

    private var workoutReportsSubtitle: String {
        if completedWorkouts.isEmpty {
            return AppLocalizer.string("coaching.workouts.empty.available")
        }
        if store.workoutReports.isEmpty {
            return AppLocalizer.string("coaching.workouts.empty.sent")
        }
        return store.workoutReports.first?.createdAt.formatted(date: .abbreviated, time: .shortened)
            ?? AppLocalizer.string("coaching.workouts.empty.sent")
    }

    private var nutritionReportsSubtitle: String {
        if store.nutritionReports.isEmpty {
            return AppLocalizer.string("coaching.nutrition.empty.sent")
        }
        return store.nutritionReports.first?.createdAt.formatted(date: .abbreviated, time: .shortened)
            ?? AppLocalizer.string("coaching.nutrition.empty.sent")
    }

    private var chatSubtitle: String {
        guard let note = store.notes.first else {
            return AppLocalizer.string("coaching.notes.empty")
        }
        return note.message
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(HomeColors.accent)
                    .frame(width: 54, height: 54)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.secondarySystemBackground)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color(.separator).opacity(0.16))
                    )
                    .shadow(color: cardShadow, radius: 14, x: 0, y: 6)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 7) {
                Text(AppLocalizer.string("workouts.connection"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                Text(AppLocalizer.string("workouts.connection.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var trainerCard: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(AppLocalizer.string("coaching.linked.trainer"))
                    .font(.headline.weight(.bold))
                Text(trainer?.displayName ?? AppLocalizer.string("role.trainer"))
                    .font(.title3.weight(.bold))
                Label(trainer?.email ?? "", systemImage: "envelope.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            HStack(spacing: 0) {
                quickAction(
                    icon: "waveform.path.ecg",
                    title: "Check-in",
                    action: { showCheckInSheet = true }
                )
                Divider().frame(height: 34)
                quickAction(
                    icon: "paperplane.fill",
                    title: AppLocalizer.string("tab.workouts"),
                    action: { showWorkoutReportSheet = true }
                )
                Divider().frame(height: 34)
                quickAction(
                    icon: "fork.knife",
                    title: AppLocalizer.string("tab.nutrition"),
                    action: { showNutritionReportSheet = true }
                )
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.18))
        )
        .shadow(color: cardShadow, radius: 14, x: 0, y: 6)
    }

    private func quickAction(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(HomeColors.accent.opacity(0.11))
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(HomeColors.accent)
                }
                .frame(width: 38, height: 38)

                VStack(spacing: 1) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(AppLocalizer.string("coaching.quick_action.send"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var requestCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryNavigationHeader(
                icon: "message",
                title: AppLocalizer.string("coaching.update_request.section"),
                subtitle: openRequests.isEmpty ? AppLocalizer.string("coaching.update_request.empty") : openRequests.first?.message ?? "",
                showsChevron: openRequests.count > 1,
                action: {}
            )

            ForEach(openRequests.prefix(1)) { request in
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppLocalizer.string(request.type.localizationKey))
                        .font(.subheadline.weight(.semibold))
                    Button(AppLocalizer.string("coaching.update_request.action.resolve")) {
                        Task { await store.resolveUpdateRequest(request) }
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(HomeColors.accent)
                }
                .padding(.leading, 68)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.16))
        )
        .shadow(color: cardShadow, radius: 14, x: 0, y: 6)
    }

    private func summaryNavigationCard(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            summaryNavigationHeader(icon: icon, title: title, subtitle: subtitle, showsChevron: true, action: action)
                .padding(16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color(.separator).opacity(0.16))
                )
                .shadow(color: cardShadow, radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func summaryNavigationHeader(
        icon: String,
        title: String,
        subtitle: String,
        showsChevron: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(HomeColors.accent.opacity(0.12))
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(HomeColors.accent)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var notesSection: some View {
        summaryNavigationCard(
            icon: "bubble.left.and.bubble.right",
            title: AppLocalizer.string("coaching.notes.section"),
            subtitle: chatSubtitle,
            action: { showAllNotes = true }
        )
    }
}

private struct ClientCoachingChatScreen: View {
    @ObservedObject var store: ClientCoachingHomeStore
    @Binding var noteMessage: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: AppSessionStore
    @State private var pendingDelete: CoachingNote?

    private var trimmedMessage: String {
        noteMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        CoachingChatContent(
            notes: store.notes,
            outgoingRole: .client,
            placeholder: AppLocalizer.string("coaching.notes.placeholder.client"),
            message: $noteMessage,
            isSubmitting: store.isSubmitting,
            onSend: {
                await store.sendNote(
                    noteMessage,
                    senderName: sessionStore.profile?.displayName ?? ""
                )
                if store.errorMessage == nil {
                    noteMessage = ""
                }
            },
            onRequestDelete: { pendingDelete = $0 }
        )
        .navigationTitle(AppLocalizer.string("coaching.notes.section"))
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
                guard let pendingDelete else { return }
                Task {
                    await store.deleteNote(pendingDelete)
                }
                self.pendingDelete = nil
            }
        } message: {
            Text(AppLocalizer.string("coaching.history.delete.message"))
        }
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
                                            workout.exerciseItems.count,
                                            workout.exerciseItems.reduce(0) { $0 + $1.setItems.count }
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

    @Environment(\.colorScheme) private var colorScheme
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
    @State private var showAllNotes = false
    @State private var showRequestComposer = false

    init(trainerId: String, client: AppUserProfile) {
        self.trainerId = trainerId
        self.client = client
        _store = StateObject(wrappedValue: TrainerClientSupportStore(trainerId: trainerId, client: client))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if let errorMessage = store.errorMessage, errorMessage.isEmpty == false {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                trainerClientSummaryCard
                quickActionsCard

                if store.intake != nil {
                    intakeCard
                }

                updateRequestsCard
                trainerNavigationCard(
                    icon: "clock",
                    title: AppLocalizer.string("coaching.checkin.history"),
                    subtitle: checkInSubtitle,
                    action: { showAllCheckIns = true }
                )
                trainerNavigationCard(
                    icon: "dumbbell.fill",
                    title: AppLocalizer.string("coaching.workouts.section"),
                    subtitle: workoutReportsSubtitle,
                    action: { showAllWorkoutReports = true }
                )
                trainerNavigationCard(
                    icon: "fork.knife",
                    title: AppLocalizer.string("coaching.nutrition.section"),
                    subtitle: nutritionReportsSubtitle,
                    action: { showAllNutritionReports = true }
                )
                trainerNavigationCard(
                    icon: "bubble.left.and.bubble.right",
                    title: AppLocalizer.string("coaching.workspace.client_chat"),
                    subtitle: chatSubtitle,
                    action: { showAllNotes = true }
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 30)
        }
        .background(trainerBackground.ignoresSafeArea())
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
        .sheet(isPresented: $showAllNotes) {
            NavigationStack {
                TrainerClientChatScreen(
                    store: store,
                    noteMessage: $noteMessage
                )
            }
        }
        .sheet(isPresented: $showRequestComposer) {
            NavigationStack {
                TrainerUpdateRequestComposerScreen(
                    store: store,
                    requestType: $requestType,
                    requestMessage: $requestMessage
                )
            }
        }
    }

    private var openRequests: [ProfileUpdateRequest] {
        store.updateRequests.filter { $0.status == "open" }
    }

    private var trainerBackground: Color {
        colorScheme == .dark ? Color(.systemGroupedBackground) : HomeColors.background
    }

    private var trainerCardShadow: Color {
        colorScheme == .dark ? .clear : HomeColors.shadow
    }

    private var checkInSubtitle: String {
        guard let checkIn = store.checkIns.first else {
            return AppLocalizer.string("coaching.checkin.empty")
        }
        return "\(checkIn.createdAt.formatted(date: .abbreviated, time: .shortened)) • \(String(format: "%.1f", checkIn.weight)) \(AppLocalizer.string("coaching.unit.kg"))"
    }

    private var workoutReportsSubtitle: String {
        guard let report = store.workoutReports.first else {
            return AppLocalizer.string("coaching.workouts.empty.received")
        }
        return report.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var nutritionReportsSubtitle: String {
        guard let report = store.nutritionReports.first else {
            return AppLocalizer.string("coaching.nutrition.empty.received")
        }
        return report.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var chatSubtitle: String {
        guard let note = store.notes.first else {
            return AppLocalizer.string("coaching.notes.empty")
        }
        return note.message
    }

    private var trainerClientSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(client.displayName)
                    .font(.title2.weight(.bold))
                Text(client.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                trainerMetricTile(
                    title: AppLocalizer.string("coaching.workspace.metric.goal"),
                    value: store.intake.map { AppLocalizer.string($0.goal.localizationKey) } ?? "—"
                )
                trainerMetricTile(
                    title: AppLocalizer.string("coaching.workspace.metric.weight"),
                    value: store.intake.map { "\(String(format: "%.1f", $0.weight)) \(AppLocalizer.string("coaching.unit.kg"))" } ?? "—"
                )
                trainerMetricTile(
                    title: AppLocalizer.string("coaching.workspace.metric.last_checkin"),
                    value: store.checkIns.first.map { $0.createdAt.formatted(date: .abbreviated, time: .omitted) } ?? "—"
                )
                trainerMetricTile(
                    title: AppLocalizer.string("coaching.workspace.metric.open_requests"),
                    value: "\(openRequests.count)"
                )
            }

            if let activeLink = store.activeLink {
                Label(
                    "\(AppLocalizer.string("coaching.workspace.connected_since")) \(activeLink.createdAt.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "link"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.16))
        )
        .shadow(color: trainerCardShadow, radius: 14, x: 0, y: 6)
    }

    private func trainerMetricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .padding(12)
        .background(HomeColors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppLocalizer.string("coaching.workspace.quick_actions"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            HStack(spacing: 0) {
                trainerQuickAction(
                    icon: "arrow.triangle.2.circlepath",
                    title: AppLocalizer.string("coaching.workspace.action.request_update"),
                    action: { showRequestComposer = true }
                )
                Divider().frame(height: 44)
                trainerQuickAction(
                    icon: "bubble.left.and.bubble.right",
                    title: AppLocalizer.string("coaching.workspace.client_chat"),
                    action: { showAllNotes = true }
                )
                Divider().frame(height: 44)
                trainerQuickAction(
                    icon: "dumbbell.fill",
                    title: AppLocalizer.string("coaching.workouts.section"),
                    action: { showAllWorkoutReports = true }
                )
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.16))
        )
        .shadow(color: trainerCardShadow, radius: 14, x: 0, y: 6)
    }

    private func trainerQuickAction(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(HomeColors.accent.opacity(0.12))
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(HomeColors.accent)
                }
                .frame(width: 38, height: 38)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var intakeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            trainerCardTitle(icon: "person.text.rectangle", title: AppLocalizer.string("coaching.workspace.intake"))

            if let intake = store.intake {
                trainerInfoRow(AppLocalizer.string("coaching.intake.goal"), AppLocalizer.string(intake.goal.localizationKey))
                trainerInfoRow(AppLocalizer.string("coaching.intake.height"), "\(String(format: "%.0f", intake.height)) \(AppLocalizer.string("coaching.unit.cm"))")
                trainerInfoRow(AppLocalizer.string("coaching.intake.activity"), AppLocalizer.string(intake.activity.localizationKey))
                trainerInfoRow(AppLocalizer.string("coaching.intake.experience"), AppLocalizer.string(intake.experience.localizationKey))

                if intake.limitations.isEmpty == false {
                    trainerTextBlock(AppLocalizer.string("coaching.intake.limitations"), intake.limitations)
                }
                if intake.equipment.isEmpty == false {
                    trainerTextBlock(AppLocalizer.string("coaching.intake.equipment"), intake.equipment)
                }
                if intake.schedule.isEmpty == false {
                    trainerTextBlock(AppLocalizer.string("coaching.intake.schedule"), intake.schedule)
                }
                if intake.notes.isEmpty == false {
                    trainerTextBlock(AppLocalizer.string("coaching.intake.notes"), intake.notes)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.16))
        )
        .shadow(color: trainerCardShadow, radius: 14, x: 0, y: 6)
    }

    private var updateRequestsCard: some View {
        Button {
            showRequestComposer = true
        } label: {
            trainerNavigationContent(
                icon: "arrow.triangle.2.circlepath",
                title: AppLocalizer.string("coaching.update_request.section"),
                subtitle: openRequests.first?.message ?? AppLocalizer.string("coaching.update_request.empty"),
                showsChevron: true
            )
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.16))
            )
            .shadow(color: trainerCardShadow, radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func trainerNavigationCard(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            trainerNavigationContent(icon: icon, title: title, subtitle: subtitle, showsChevron: true)
                .padding(16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color(.separator).opacity(0.16))
                )
                .shadow(color: trainerCardShadow, radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func trainerNavigationContent(
        icon: String,
        title: String,
        subtitle: String,
        showsChevron: Bool
    ) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(HomeColors.accent.opacity(0.12))
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(HomeColors.accent)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func trainerCardTitle(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(HomeColors.accent)
            Text(title)
                .font(.headline.weight(.semibold))
            Spacer()
        }
    }

    private func trainerInfoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .foregroundStyle(.primary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.55)
        }
    }

    private func trainerTextBlock(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 6)
    }
}

private struct TrainerUpdateRequestComposerScreen: View {
    @ObservedObject var store: TrainerClientSupportStore
    @Binding var requestType: ProfileUpdateRequestType
    @Binding var requestMessage: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: AppSessionStore

    private var trimmedMessage: String {
        requestMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            Section(AppLocalizer.string("coaching.update_request.section")) {
                Picker(AppLocalizer.string("coaching.update_request.type"), selection: $requestType) {
                    ForEach(ProfileUpdateRequestType.allCases) { type in
                        Text(AppLocalizer.string(type.localizationKey)).tag(type)
                    }
                }

                TextField(AppLocalizer.string("coaching.update_request.message"), text: $requestMessage, axis: .vertical)
                    .lineLimit(3...6)

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
                            dismiss()
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
                .disabled(store.isSubmitting || trimmedMessage.isEmpty)
            }

            if store.updateRequests.contains(where: { $0.status == "open" }) {
                Section(AppLocalizer.string("coaching.workspace.open_requests")) {
                    ForEach(store.updateRequests.filter { $0.status == "open" }) { request in
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
        }
        .navigationTitle(AppLocalizer.string("coaching.update_request.section"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(AppLocalizer.string("common.cancel")) {
                    dismiss()
                }
            }
        }
    }
}

private struct TrainerClientChatScreen: View {
    @ObservedObject var store: TrainerClientSupportStore
    @Binding var noteMessage: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionStore: AppSessionStore
    @State private var pendingDelete: CoachingNote?

    private var trimmedMessage: String {
        noteMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        CoachingChatContent(
            notes: store.notes,
            outgoingRole: .trainer,
            placeholder: AppLocalizer.string("coaching.notes.placeholder.trainer"),
            message: $noteMessage,
            isSubmitting: store.isSubmitting,
            onSend: {
                await store.sendNote(
                    noteMessage,
                    senderName: sessionStore.profile?.displayName ?? ""
                )
                if store.errorMessage == nil {
                    noteMessage = ""
                }
            },
            onRequestDelete: { pendingDelete = $0 }
        )
        .navigationTitle(AppLocalizer.string("coaching.workspace.client_chat"))
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
                guard let pendingDelete else { return }
                Task {
                    await store.deleteNote(pendingDelete)
                }
                self.pendingDelete = nil
            }
        } message: {
            Text(AppLocalizer.string("coaching.history.delete.message"))
        }
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
                        Text(formattedWorkoutCalories(workout.estimatedCalories))
                        if workout.displayBlocks.count > 1 {
                            Text(AppLocalizer.format("coaching.workouts.blocks", workout.displayBlocks.count))
                        }
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
    @State private var selectedRange: CoachingReportDateRange = .all
    @State private var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate = Date()
    @State private var visibleReportCount = 50
    @State private var selectedWorkoutReport: CoachingWorkoutReport?
    @State private var pendingDelete: CoachingWorkoutReport?

    private var filteredReports: [CoachingWorkoutReport] {
        reports.filter {
            selectedRange.contains(
                $0.createdAt,
                customStart: customStartDate,
                customEnd: customEndDate
            )
        }
    }

    private var visibleReports: [CoachingWorkoutReport] {
        Array(filteredReports.prefix(visibleReportCount))
    }

    var body: some View {
        List {
            Section {
                Picker(AppLocalizer.string("coaching.reports.range.title"), selection: $selectedRange) {
                    ForEach(CoachingReportDateRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.menu)

                if selectedRange == .custom {
                    DatePicker(
                        AppLocalizer.string("coaching.reports.range.start"),
                        selection: $customStartDate,
                        in: ...customEndDate,
                        displayedComponents: .date
                    )
                    DatePicker(
                        AppLocalizer.string("coaching.reports.range.end"),
                        selection: $customEndDate,
                        in: customStartDate...Date(),
                        displayedComponents: .date
                    )
                }
            }

            if reports.isEmpty {
                Text(AppLocalizer.string("coaching.workouts.empty.received"))
                    .foregroundStyle(.secondary)
            } else if filteredReports.isEmpty {
                Text(AppLocalizer.string("coaching.reports.range.empty"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visibleReports) { report in
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

                if filteredReports.count > visibleReports.count {
                    Button {
                        visibleReportCount += 50
                    } label: {
                        Text(AppLocalizer.format("coaching.reports.show_more", filteredReports.count - visibleReports.count))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
        .onChange(of: selectedRange) { _, _ in visibleReportCount = 50 }
        .onChange(of: customStartDate) { _, _ in visibleReportCount = 50 }
        .onChange(of: customEndDate) { _, _ in visibleReportCount = 50 }
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

private struct CoachingNotesHistoryScreen: View {
    let notes: [CoachingNote]
    let canDelete: Bool
    let onDelete: ((CoachingNote) async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var pendingDelete: CoachingNote?

    var body: some View {
        List {
            if notes.isEmpty {
                Text(AppLocalizer.string("coaching.notes.empty"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(notes) { note in
                    CoachingNoteRow(note: note)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if canDelete {
                                Button(role: .destructive) {
                                    pendingDelete = note
                                } label: {
                                    Label(AppLocalizer.string("common.delete"), systemImage: "trash")
                                }
                            }
                        }
                }
            }
        }
        .navigationTitle(AppLocalizer.string("coaching.notes.section"))
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

private struct CoachingChatContent: View {
    let notes: [CoachingNote]
    let outgoingRole: CoachingNoteAuthorRole
    let placeholder: String
    @Binding var message: String
    let isSubmitting: Bool
    let onSend: () async -> Void
    let onRequestDelete: (CoachingNote) -> Void

    private var sortedNotes: [CoachingNote] {
        notes.sorted { $0.createdAt < $1.createdAt }
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if sortedNotes.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(HomeColors.accent)
                            Text(AppLocalizer.string("coaching.notes.empty"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                    } else {
                        ForEach(sortedNotes) { note in
                            CoachingChatBubble(
                                note: note,
                                isOutgoing: note.authorRole == outgoingRole,
                                onRequestDelete: { onRequestDelete(note) }
                            )
                            .id(note.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                chatComposer
                    .background(.ultraThinMaterial)
            }
            .onAppear {
                scrollToLatest(proxy)
            }
            .onChange(of: notes.count) { _, _ in
                scrollToLatest(proxy)
            }
        }
    }

    private var chatComposer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(placeholder, text: $message, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color(.separator).opacity(0.18))
                )

            Button {
                Task {
                    await onSend()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(trimmedMessage.isEmpty ? Color(.systemGray4) : HomeColors.accent)
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 42, height: 42)
            }
            .disabled(isSubmitting || trimmedMessage.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        guard let lastId = sortedNotes.last?.id else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}

private struct CoachingChatBubble: View {
    let note: CoachingNote
    let isOutgoing: Bool
    let onRequestDelete: () -> Void

    private var authorTitle: String {
        AppLocalizer.string(note.authorRole == .trainer ? "coaching.notes.author.trainer" : "coaching.notes.author.client")
    }

    var body: some View {
        HStack {
            if isOutgoing {
                Spacer(minLength: 48)
            }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
                if isOutgoing == false {
                    Text(authorTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HomeColors.accent)
                }

                Text(note.message)
                    .font(.body)
                    .foregroundStyle(isOutgoing ? .white : .primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(isOutgoing ? Color.white.opacity(0.72) : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isOutgoing ? HomeColors.accent : Color(.secondarySystemGroupedBackground))
            )
            .overlay(alignment: isOutgoing ? .bottomTrailing : .bottomLeading) {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: isOutgoing ? 0 : 3,
                    bottomTrailingRadius: isOutgoing ? 3 : 0,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(isOutgoing ? HomeColors.accent : Color(.secondarySystemGroupedBackground))
                .frame(width: 14, height: 14)
                .offset(x: isOutgoing ? 5 : -5, y: 1)
            }
            .frame(maxWidth: 310, alignment: isOutgoing ? .trailing : .leading)
            .contextMenu {
                Button(role: .destructive) {
                    onRequestDelete()
                } label: {
                    Label(AppLocalizer.string("common.delete"), systemImage: "trash")
                }
            }

            if isOutgoing == false {
                Spacer(minLength: 48)
            }
        }
        .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
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
                        AppLocalizer.string("coaching.workouts.detail.calories"),
                        value: formattedWorkoutCalories(workout.estimatedCalories)
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

                    ForEach(workout.displayBlocks.sorted { $0.orderIndex < $1.orderIndex }, id: \.id) { block in
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(block.displayTitle)
                                    .font(.headline.weight(.semibold))
                                Text(block.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(block.exercises.sorted { $0.orderIndex < $1.orderIndex }, id: \.id) { exercise in
                                CoachingWorkoutReportExerciseDetail(
                                    exercise: exercise,
                                    formattedSetValue: formattedSnapshotSetValue
                                )
                            }
                        }
                        .padding(.vertical, 6)
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

private struct CoachingWorkoutReportExerciseDetail: View {
    let exercise: CoachingWorkoutExerciseSnapshot
    let formattedSetValue: (CoachingWorkoutSetSnapshot) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.name)
                .font(.subheadline.weight(.semibold))

            ForEach(exercise.sets.sorted { $0.orderIndex < $1.orderIndex }, id: \.orderIndex) { set in
                HStack {
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(set.isCompleted ? Color.green : .secondary)
                    Text(formattedSetValue(set))
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

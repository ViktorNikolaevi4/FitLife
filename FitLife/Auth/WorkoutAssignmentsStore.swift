import Foundation
import FirebaseFirestore
import SwiftData

@MainActor
final class WorkoutTemplateAssignmentStore: ObservableObject {
    @Published private(set) var clients: [AppUserProfile] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var assignedClientIds: Set<String> = []

    private let template: WorkoutTemplate
    private let firestore: Firestore

    init(template: WorkoutTemplate, firestore: Firestore = .firestore()) {
        self.template = template
        self.firestore = firestore
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            async let linksSnapshot = firestore
                .collection("trainer_client_links")
                .whereField("trainerId", isEqualTo: template.trainerId)
                .whereField("status", isEqualTo: "active")
                .getDocuments()

            async let assignmentsSnapshot = firestore
                .collection("workout_assignments")
                .whereField("trainerId", isEqualTo: template.trainerId)
                .whereField("templateId", isEqualTo: template.id)
                .whereField("status", isEqualTo: WorkoutAssignmentStatus.assigned.rawValue)
                .getDocuments()

            let (linkDocs, assignmentDocs) = try await (linksSnapshot, assignmentsSnapshot)

            let clientIds = linkDocs.documents.compactMap { document in
                TrainerClientLink(id: document.documentID, data: document.data())?.clientId
            }

            var loadedClients: [AppUserProfile] = []
            for clientId in clientIds {
                let snapshot = try await firestore.collection("users").document(clientId).getDocument()
                guard let data = snapshot.data(),
                      let profile = AppUserProfile(id: snapshot.documentID, data: data) else {
                    continue
                }
                loadedClients.append(profile)
            }

            clients = loadedClients.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }

            assignedClientIds = Set(
                assignmentDocs.documents.compactMap { document in
                    WorkoutAssignment(id: document.documentID, data: document.data())?.clientId
                }
            )
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func assignTemplate(to client: AppUserProfile, exerciseCount: Int) async -> Bool {
        errorMessage = nil

        do {
            let documentRef = firestore.collection("workout_assignments").document()
            let assignment = WorkoutAssignment(
                id: documentRef.documentID,
                trainerId: template.trainerId,
                clientId: client.id,
                templateId: template.id,
                titleSnapshot: template.title,
                notesSnapshot: template.notes,
                exerciseCount: exerciseCount
            )

            let templateExercises = try await firestore
                .collection("workout_templates")
                .document(template.id)
                .collection("exercises")
                .order(by: "orderIndex")
                .getDocuments()

            let exerciseItems = templateExercises.documents.compactMap { document in
                WorkoutTemplateExerciseItem(
                    id: document.documentID,
                    templateId: template.id,
                    data: document.data()
                )
            }

            let batch = firestore.batch()
            batch.setData(assignment.firestoreData, forDocument: documentRef)

            for exercise in exerciseItems {
                let exerciseRef = documentRef.collection("exercises").document(exercise.id)
                batch.setData(exercise.firestoreData, forDocument: exerciseRef)
            }

            try await batch.commit()
            assignedClientIds.insert(client.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func isAssigned(clientId: String) -> Bool {
        assignedClientIds.contains(clientId)
    }
}

@MainActor
final class ClientAssignedWorkoutsStore: ObservableObject {
    @Published private(set) var assignments: [WorkoutAssignment] = []
    @Published private(set) var trainerNamesById: [String: String] = [:]
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let clientId: String
    private let firestore: Firestore

    init(clientId: String, firestore: Firestore = .firestore()) {
        self.clientId = clientId
        self.firestore = firestore
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await firestore
                .collection("workout_assignments")
                .whereField("clientId", isEqualTo: clientId)
                .order(by: "assignedAt", descending: true)
                .getDocuments()

            let loadedAssignments = snapshot.documents.compactMap { document in
                WorkoutAssignment(id: document.documentID, data: document.data())
            }

            assignments = loadedAssignments

            var names: [String: String] = [:]
            for trainerId in Set(loadedAssignments.map(\.trainerId)) {
                let snapshot = try await firestore.collection("users").document(trainerId).getDocument()
                guard let data = snapshot.data(),
                      let profile = AppUserProfile(id: snapshot.documentID, data: data) else {
                    continue
                }
                names[trainerId] = profile.displayName
            }
            trainerNamesById = names
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func trainerName(for trainerId: String) -> String? {
        trainerNamesById[trainerId]
    }

    func startAssignment(
        _ assignment: WorkoutAssignment,
        gender: Gender,
        modelContext: ModelContext
    ) async -> WorkoutSession? {
        errorMessage = nil

        if let existingWorkout = existingWorkout(for: assignment, modelContext: modelContext) {
            if assignment.status == .assigned {
                try? await firestore
                    .collection("workout_assignments")
                    .document(assignment.id)
                    .setData(["status": WorkoutAssignmentStatus.started.rawValue], merge: true)
            }
            return existingWorkout
        }

        do {
            let exercisesSnapshot = try await firestore
                .collection("workout_assignments")
                .document(assignment.id)
                .collection("exercises")
                .order(by: "orderIndex")
                .getDocuments()

            let remoteExercises = exercisesSnapshot.documents.compactMap { document in
                WorkoutTemplateExerciseItem(
                    id: document.documentID,
                    templateId: assignment.id,
                    data: document.data()
                )
            }

            let workout = WorkoutSession(
                title: assignment.titleSnapshot,
                gender: gender,
                remoteAssignmentId: assignment.id,
                remoteTrainerId: assignment.trainerId,
                remoteClientId: assignment.clientId,
                source: "assigned"
            )

            for remoteExercise in remoteExercises {
                let exercise = WorkoutExercise(
                    name: remoteExercise.name,
                    systemImage: remoteExercise.systemImage,
                    accentName: remoteExercise.accentName,
                    orderIndex: remoteExercise.orderIndex
                )
                exercise.session = workout

                for (index, remoteSet) in remoteExercise.sets.enumerated() {
                    let set = WorkoutSet(
                        orderIndex: index,
                        weight: remoteSet.weight,
                        reps: remoteSet.reps
                    )
                    set.exercise = exercise
                    exercise.sets.append(set)
                }

                workout.exercises.append(exercise)
            }

            modelContext.insert(workout)
            try modelContext.save()

            try await firestore
                .collection("workout_assignments")
                .document(assignment.id)
                .setData(["status": WorkoutAssignmentStatus.started.rawValue], merge: true)

            if let index = assignments.firstIndex(where: { $0.id == assignment.id }) {
                assignments[index] = WorkoutAssignment(
                    id: assignment.id,
                    trainerId: assignment.trainerId,
                    clientId: assignment.clientId,
                    templateId: assignment.templateId,
                    titleSnapshot: assignment.titleSnapshot,
                    notesSnapshot: assignment.notesSnapshot,
                    exerciseCount: assignment.exerciseCount,
                    assignedAt: assignment.assignedAt,
                    status: .started
                )
            }

            return workout
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func activeWorkout(for assignmentId: String, workouts: [WorkoutSession]) -> WorkoutSession? {
        workouts
            .filter { $0.remoteAssignmentId == assignmentId && $0.endedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    private func existingWorkout(
        for assignment: WorkoutAssignment,
        modelContext: ModelContext
    ) -> WorkoutSession? {
        let descriptor = FetchDescriptor<WorkoutSession>()
        let workouts = (try? modelContext.fetch(descriptor)) ?? []
        return activeWorkout(for: assignment.id, workouts: workouts)
    }
}

@MainActor
final class ClientAssignmentDetailStore: ObservableObject {
    @Published private(set) var exercises: [WorkoutTemplateExerciseItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let assignment: WorkoutAssignment
    private let firestore: Firestore

    init(assignment: WorkoutAssignment, firestore: Firestore = .firestore()) {
        self.assignment = assignment
        self.firestore = firestore
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await firestore
                .collection("workout_assignments")
                .document(assignment.id)
                .collection("exercises")
                .order(by: "orderIndex")
                .getDocuments()

            exercises = snapshot.documents.compactMap { document in
                WorkoutTemplateExerciseItem(
                    id: document.documentID,
                    templateId: assignment.id,
                    data: document.data()
                )
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

@MainActor
final class TrainerAssignmentsOverviewStore: ObservableObject {
    @Published private(set) var assignments: [WorkoutAssignment] = []
    @Published private(set) var clientNamesById: [String: String] = [:]
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let trainerId: String
    private let firestore: Firestore

    init(trainerId: String, firestore: Firestore = .firestore()) {
        self.trainerId = trainerId
        self.firestore = firestore
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await firestore
                .collection("workout_assignments")
                .whereField("trainerId", isEqualTo: trainerId)
                .order(by: "assignedAt", descending: true)
                .getDocuments()

            let loadedAssignments = snapshot.documents.compactMap { document in
                WorkoutAssignment(id: document.documentID, data: document.data())
            }
            assignments = loadedAssignments

            var names: [String: String] = [:]
            for clientId in Set(loadedAssignments.map(\.clientId)) {
                let snapshot = try await firestore.collection("users").document(clientId).getDocument()
                guard let data = snapshot.data(),
                      let profile = AppUserProfile(id: snapshot.documentID, data: data) else {
                    continue
                }
                names[clientId] = profile.displayName
            }

            clientNamesById = names
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func clientName(for clientId: String) -> String? {
        clientNamesById[clientId]
    }

    func assignments(for status: WorkoutAssignmentStatus) -> [WorkoutAssignment] {
        assignments.filter { $0.status == status }
    }
}

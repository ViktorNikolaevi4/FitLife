import Foundation
import FirebaseFirestore

struct WorkoutTemplateExerciseItem: Identifiable, Hashable {
    let id: String
    let templateId: String
    let name: String
    let systemImage: String
    let accentName: String
    let orderIndex: Int
    let sets: [WorkoutDraftSet]

    init(
        id: String,
        templateId: String,
        name: String,
        systemImage: String,
        accentName: String,
        orderIndex: Int,
        sets: [WorkoutDraftSet]
    ) {
        self.id = id
        self.templateId = templateId
        self.name = name
        self.systemImage = systemImage
        self.accentName = accentName
        self.orderIndex = orderIndex
        self.sets = sets
    }

    init?(id: String, templateId: String, data: [String: Any]) {
        guard
            let name = data["name"] as? String,
            let systemImage = data["systemImage"] as? String,
            let accentName = data["accentName"] as? String,
            let orderIndex = data["orderIndex"] as? Int
        else {
            return nil
        }

        let rawSets = data["sets"] as? [[String: Any]] ?? []
        self.id = id
        self.templateId = templateId
        self.name = name
        self.systemImage = systemImage
        self.accentName = accentName
        self.orderIndex = orderIndex
        self.sets = rawSets.map { raw in
            WorkoutDraftSet(
                weight: raw["weight"] as? Double ?? 0,
                reps: raw["reps"] as? Int ?? 0
            )
        }
    }

    var firestoreData: [String: Any] {
        [
            "name": name,
            "systemImage": systemImage,
            "accentName": accentName,
            "orderIndex": orderIndex,
            "sets": sets.map { ["weight": $0.weight, "reps": $0.reps] }
        ]
    }
}

@MainActor
final class WorkoutTemplateContentStore: ObservableObject {
    @Published private(set) var exercises: [WorkoutTemplateExerciseItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

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
            let snapshot = try await firestore
                .collection("workout_templates")
                .document(template.id)
                .collection("exercises")
                .order(by: "orderIndex")
                .getDocuments()

            exercises = snapshot.documents.compactMap { document in
                WorkoutTemplateExerciseItem(
                    id: document.documentID,
                    templateId: template.id,
                    data: document.data()
                )
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func addExercise(_ draft: WorkoutExerciseDraft) async {
        errorMessage = nil
        do {
            let documentRef = firestore
                .collection("workout_templates")
                .document(template.id)
                .collection("exercises")
                .document()

            let item = WorkoutTemplateExerciseItem(
                id: documentRef.documentID,
                templateId: template.id,
                name: draft.name,
                systemImage: draft.systemImage,
                accentName: draft.accentName,
                orderIndex: exercises.count,
                sets: draft.sets
            )

            try await documentRef.setData(item.firestoreData)
            exercises.append(item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteExercise(_ exercise: WorkoutTemplateExerciseItem) async {
        errorMessage = nil
        do {
            try await firestore
                .collection("workout_templates")
                .document(template.id)
                .collection("exercises")
                .document(exercise.id)
                .delete()

            exercises.removeAll { $0.id == exercise.id }
            try await normalizeOrderIndexes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func normalizeOrderIndexes() async throws {
        let ordered = exercises.enumerated().map { index, item in
            WorkoutTemplateExerciseItem(
                id: item.id,
                templateId: item.templateId,
                name: item.name,
                systemImage: item.systemImage,
                accentName: item.accentName,
                orderIndex: index,
                sets: item.sets
            )
        }

        let batch = firestore.batch()
        for item in ordered {
            let ref = firestore
                .collection("workout_templates")
                .document(template.id)
                .collection("exercises")
                .document(item.id)
            batch.setData(["orderIndex": item.orderIndex], forDocument: ref, merge: true)
        }
        try await batch.commit()
        exercises = ordered
    }
}

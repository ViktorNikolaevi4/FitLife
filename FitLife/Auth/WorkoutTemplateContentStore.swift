import Foundation
import FirebaseFirestore

struct WorkoutTemplateExerciseItem: Identifiable, Hashable {
    let id: String
    let templateId: String
    let blockId: String?
    let name: String
    let systemImage: String
    let accentName: String
    let orderIndex: Int
    let sets: [WorkoutDraftSet]

    init(
        id: String,
        templateId: String,
        blockId: String? = nil,
        name: String,
        systemImage: String,
        accentName: String,
        orderIndex: Int,
        sets: [WorkoutDraftSet]
    ) {
        self.id = id
        self.templateId = templateId
        self.blockId = blockId
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
        self.blockId = data["blockId"] as? String
        self.name = name
        self.systemImage = systemImage
        self.accentName = accentName
        self.orderIndex = orderIndex
        self.sets = rawSets.map { raw in
            WorkoutDraftSet(
                weight: raw["weight"] as? Double ?? 0,
                reps: raw["reps"] as? Int ?? 0,
                durationSeconds: raw["durationSeconds"] as? Int ?? 30,
                metricType: WorkoutSetMetricType(rawValue: raw["metricType"] as? String ?? "") ?? .reps
            )
        }
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "name": name,
            "systemImage": systemImage,
            "accentName": accentName,
            "orderIndex": orderIndex,
            "sets": sets.map {
                [
                    "weight": $0.weight,
                    "reps": $0.reps,
                    "durationSeconds": $0.durationSeconds,
                    "metricType": $0.metricType.rawValue
                ]
            }
        ]
        if let blockId {
            data["blockId"] = blockId
        }
        return data
    }
}

struct WorkoutTemplateBlockItem: Identifiable, Hashable {
    let id: String
    let templateId: String
    let title: String
    let typeRawValue: String
    let orderIndex: Int
    let rounds: Int
    let restBetweenRoundsSeconds: Int

    init(
        id: String,
        templateId: String,
        title: String,
        type: WorkoutBlockType,
        orderIndex: Int,
        rounds: Int = 1,
        restBetweenRoundsSeconds: Int = 0
    ) {
        self.id = id
        self.templateId = templateId
        self.title = title
        self.typeRawValue = type.rawValue
        self.orderIndex = orderIndex
        self.rounds = rounds
        self.restBetweenRoundsSeconds = restBetweenRoundsSeconds
    }

    init?(id: String, templateId: String, data: [String: Any]) {
        guard
            let title = data["title"] as? String,
            let typeRawValue = data["typeRawValue"] as? String,
            let orderIndex = data["orderIndex"] as? Int
        else {
            return nil
        }

        self.id = id
        self.templateId = templateId
        self.title = title
        self.typeRawValue = typeRawValue
        self.orderIndex = orderIndex
        self.rounds = (data["rounds"] as? Int) ?? 1
        self.restBetweenRoundsSeconds = (data["restBetweenRoundsSeconds"] as? Int) ?? 0
    }

    var firestoreData: [String: Any] {
        [
            "title": title,
            "typeRawValue": typeRawValue,
            "orderIndex": orderIndex,
            "rounds": rounds,
            "restBetweenRoundsSeconds": restBetweenRoundsSeconds
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

    func subtitle(exerciseCount: Int) -> String {
        switch type {
        case .circuit:
            return AppLocalizer.format("workout.block.circuit.summary", rounds, exerciseCount, restBetweenRoundsSeconds)
        default:
            return AppLocalizer.format("workout.block.exercise_count", exerciseCount)
        }
    }
}

@MainActor
final class WorkoutTemplateContentStore: ObservableObject {
    @Published private(set) var blocks: [WorkoutTemplateBlockItem] = []
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
            async let blocksSnapshot = firestore
                .collection("workout_templates")
                .document(template.id)
                .collection("blocks")
                .order(by: "orderIndex")
                .getDocuments()

            async let exercisesSnapshot = firestore
                .collection("workout_templates")
                .document(template.id)
                .collection("exercises")
                .order(by: "orderIndex")
                .getDocuments()

            let (blockDocs, exerciseDocs) = try await (blocksSnapshot, exercisesSnapshot)

            blocks = blockDocs.documents.compactMap { document in
                WorkoutTemplateBlockItem(
                    id: document.documentID,
                    templateId: template.id,
                    data: document.data()
                )
            }

            exercises = exerciseDocs.documents.compactMap { document in
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
        await addExercise(draft, blockId: nil)
    }

    func addExercise(_ draft: WorkoutExerciseDraft, blockId: String?) async {
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
                blockId: blockId,
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

    func addBlock(
        title: String,
        type: WorkoutBlockType,
        rounds: Int,
        restBetweenRoundsSeconds: Int
    ) async {
        errorMessage = nil
        do {
            let documentRef = firestore
                .collection("workout_templates")
                .document(template.id)
                .collection("blocks")
                .document()

            let item = WorkoutTemplateBlockItem(
                id: documentRef.documentID,
                templateId: template.id,
                title: title,
                type: type,
                orderIndex: blocks.count,
                rounds: rounds,
                restBetweenRoundsSeconds: restBetweenRoundsSeconds
            )

            try await documentRef.setData(item.firestoreData)
            blocks.append(item)
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
                blockId: item.blockId,
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

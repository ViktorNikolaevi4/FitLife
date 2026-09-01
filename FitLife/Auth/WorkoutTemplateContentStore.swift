import Foundation
import FirebaseFirestore

struct WorkoutTemplateExerciseItem: Identifiable, Hashable {
    let id: String
    let templateId: String
    let blockId: String?
    let groupId: String?
    let name: String
    let systemImage: String
    let accentName: String
    let activityTypeRaw: String
    let metValue: Double
    let orderIndex: Int
    let sets: [WorkoutDraftSet]
    let note: String

    init(
        id: String,
        templateId: String,
        blockId: String? = nil,
        groupId: String? = nil,
        name: String,
        systemImage: String,
        accentName: String,
        activityType: WorkoutActivityType = .strength,
        metValue: Double = 5.0,
        orderIndex: Int,
        sets: [WorkoutDraftSet],
        note: String = ""
    ) {
        self.id = id
        self.templateId = templateId
        self.blockId = blockId
        self.groupId = groupId
        self.name = name
        self.systemImage = systemImage
        self.accentName = accentName
        self.activityTypeRaw = activityType.rawValue
        self.metValue = metValue
        self.orderIndex = orderIndex
        self.sets = sets
        self.note = note
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
        self.groupId = data["groupId"] as? String
        self.name = name
        self.systemImage = systemImage
        self.accentName = accentName
        self.activityTypeRaw = (data["activityTypeRaw"] as? String) ?? WorkoutActivityType.strength.rawValue
        self.metValue = (data["metValue"] as? Double) ?? 5.0
        self.orderIndex = orderIndex
        self.note = data["note"] as? String ?? ""
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
            "activityTypeRaw": activityTypeRaw,
            "metValue": metValue,
            "orderIndex": orderIndex,
            "note": note,
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
        if let groupId {
            data["groupId"] = groupId
        }
        return data
    }

    var activityType: WorkoutActivityType {
        WorkoutActivityType(rawValue: activityTypeRaw) ?? .strength
    }
}

private extension Array where Element == WorkoutDraftSet {
    func fillingRepeatingRounds(upTo requiredCount: Int) -> [WorkoutDraftSet] {
        guard let last, count < requiredCount else { return self }
        return self + Array(repeating: last, count: requiredCount - count)
    }
}

enum WorkoutBlockGroupKind: String, CaseIterable, Codable {
    case standard, pyramid, superset, circuit

    var title: String {
        switch self {
        case .standard: return "Группа"
        case .pyramid: return "Пирамида"
        case .superset: return "Суперсет"
        case .circuit: return "Круг"
        }
    }
}

struct WorkoutTemplateBlockGroupItem: Identifiable, Hashable {
    let id: String
    let title: String
    let kind: WorkoutBlockGroupKind
    let note: String
    let rounds: Int
    let restSeconds: Int
    let orderIndex: Int

    init(id: String = UUID().uuidString, title: String, kind: WorkoutBlockGroupKind = .standard, note: String = "", rounds: Int = 1, restSeconds: Int = 0, orderIndex: Int) {
        self.id = id; self.title = title; self.kind = kind; self.note = note
        self.rounds = rounds; self.restSeconds = restSeconds; self.orderIndex = orderIndex
    }

    init?(data: [String: Any]) {
        guard let id = data["id"] as? String else { return nil }
        self.init(id: id, title: data["title"] as? String ?? "", kind: WorkoutBlockGroupKind(rawValue: data["kind"] as? String ?? "") ?? .standard, note: data["note"] as? String ?? "", rounds: data["rounds"] as? Int ?? 1, restSeconds: data["restSeconds"] as? Int ?? 0, orderIndex: data["orderIndex"] as? Int ?? 0)
    }

    var firestoreData: [String: Any] { ["id": id, "title": title, "kind": kind.rawValue, "note": note, "rounds": rounds, "restSeconds": restSeconds, "orderIndex": orderIndex] }
}

struct WorkoutTemplateBlockItem: Identifiable, Hashable {
    let id: String
    let templateId: String
    let title: String
    let typeRawValue: String
    let modeRawValue: String
    let presetRawValue: String
    let orderIndex: Int
    let rounds: Int
    let durationMinutes: Int
    let workSeconds: Int
    let restSeconds: Int
    let restBetweenRoundsSeconds: Int
    let groups: [WorkoutTemplateBlockGroupItem]

    init(
        id: String,
        templateId: String,
        title: String,
        type: WorkoutBlockType,
        mode: WorkoutBlockMode = .rounds,
        preset: WorkoutBlockPreset? = nil,
        orderIndex: Int,
        rounds: Int = 1,
        durationMinutes: Int = 12,
        workSeconds: Int = 0,
        restSeconds: Int = 0,
        restBetweenRoundsSeconds: Int = 0,
        groups: [WorkoutTemplateBlockGroupItem] = []
    ) {
        self.id = id
        self.templateId = templateId
        self.title = title
        self.typeRawValue = type.rawValue
        self.modeRawValue = mode.rawValue
        self.presetRawValue = (preset ?? WorkoutBlockPreset.inferred(title: title, type: type, mode: mode)).rawValue
        self.orderIndex = orderIndex
        self.rounds = rounds
        self.durationMinutes = durationMinutes
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.restBetweenRoundsSeconds = restBetweenRoundsSeconds
        self.groups = groups
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
        self.modeRawValue = (data["modeRawValue"] as? String) ?? WorkoutBlockMode.rounds.rawValue
        let resolvedType = WorkoutBlockType(rawValue: typeRawValue) ?? .strength
        let resolvedMode = WorkoutBlockMode(rawValue: self.modeRawValue) ?? .rounds
        self.presetRawValue = (data["presetRawValue"] as? String)
            ?? WorkoutBlockPreset.inferred(title: title, type: resolvedType, mode: resolvedMode).rawValue
        self.orderIndex = orderIndex
        self.rounds = (data["rounds"] as? Int) ?? 1
        self.durationMinutes = (data["durationMinutes"] as? Int) ?? 12
        self.workSeconds = (data["workSeconds"] as? Int) ?? 0
        self.restSeconds = (data["restSeconds"] as? Int) ?? 0
        self.restBetweenRoundsSeconds = (data["restBetweenRoundsSeconds"] as? Int) ?? 0
        self.groups = ((data["groups"] as? [[String: Any]]) ?? []).compactMap(WorkoutTemplateBlockGroupItem.init(data:))
    }

    var firestoreData: [String: Any] {
        [
            "title": title,
            "typeRawValue": typeRawValue,
            "modeRawValue": modeRawValue,
            "presetRawValue": presetRawValue,
            "orderIndex": orderIndex,
            "rounds": rounds,
            "durationMinutes": durationMinutes,
            "workSeconds": workSeconds,
            "restSeconds": restSeconds,
            "restBetweenRoundsSeconds": restBetweenRoundsSeconds,
            "groups": groups.map(\.firestoreData)
        ]
    }

    var type: WorkoutBlockType {
        WorkoutBlockType(rawValue: typeRawValue) ?? .strength
    }

    var mode: WorkoutBlockMode {
        WorkoutBlockMode(rawValue: modeRawValue) ?? .rounds
    }

    var preset: WorkoutBlockPreset {
        WorkoutBlockPreset(rawValue: presetRawValue)
            ?? WorkoutBlockPreset.inferred(title: title, type: type, mode: mode)
    }

    var requiredSetCountPerExercise: Int {
        switch preset {
        case .superset, .circuit, .rft, .pyramid, .dropSet, .clusterSet, .ladder:
            return min(max(rounds, 1), 12)
        default:
            return 1
        }
    }

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            return type.title
        }
        return trimmedTitle
    }

    func subtitle(exerciseCount: Int) -> String {
        workoutBlockSubtitle(title: displayTitle, type: type, mode: mode, preset: preset, rounds: rounds, exerciseCount: exerciseCount, durationMinutes: durationMinutes, workSeconds: workSeconds, restSeconds: restSeconds, restBetweenRoundsSeconds: restBetweenRoundsSeconds)
    }

    func replacingOrderIndex(_ orderIndex: Int) -> WorkoutTemplateBlockItem {
        WorkoutTemplateBlockItem(
            id: id,
            templateId: templateId,
            title: title,
            type: type,
            mode: mode,
            preset: preset,
            orderIndex: orderIndex,
            rounds: rounds,
            durationMinutes: durationMinutes,
            workSeconds: workSeconds,
            restSeconds: restSeconds,
            restBetweenRoundsSeconds: restBetweenRoundsSeconds,
            groups: groups
        )
    }
}

@MainActor
final class WorkoutTemplateContentStore: ObservableObject {
    @Published private(set) var blocks: [WorkoutTemplateBlockItem] = []
    @Published private(set) var exercises: [WorkoutTemplateExerciseItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var librarySubmission: WorkoutTemplateSubmission?
    @Published private(set) var isSubmittingToLibrary = false
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
            await migrateLegacyRoundDrivenSetsIfNeeded()
            await loadLibrarySubmission()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private var librarySubmissionID: String {
        "\(template.trainerId)_\(template.id)"
    }

    private func loadLibrarySubmission() async {
        do {
            let snapshot = try await firestore
                .collection("workout_template_submissions")
                .whereField("trainerId", isEqualTo: template.trainerId)
                .whereField("sourceTemplateId", isEqualTo: template.id)
                .limit(to: 1)
                .getDocuments()
            guard let document = snapshot.documents.first else {
                librarySubmission = nil
                return
            }
            librarySubmission = WorkoutTemplateSubmission(
                id: document.documentID,
                data: document.data()
            )
        } catch {
            // Submission state is supplementary and must not hide the template.
            librarySubmission = nil
        }
    }

    func submitToLibrary(trainerName: String) async -> Bool {
        guard template.sourceLibraryTemplateId == nil,
              exercises.isEmpty == false,
              isSubmittingToLibrary == false,
              librarySubmission?.status != .pending,
              librarySubmission?.status != .approved else {
            return false
        }

        isSubmittingToLibrary = true
        defer { isSubmittingToLibrary = false }
        errorMessage = nil

        let submissionRef = firestore
            .collection("workout_template_submissions")
            .document(librarySubmissionID)
        let normalizedTrainerName = trainerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let submission = WorkoutTemplateSubmission(
            id: submissionRef.documentID,
            trainerId: template.trainerId,
            trainerName: normalizedTrainerName,
            sourceTemplateId: template.id,
            title: template.title,
            notes: template.notes,
            exerciseCount: exercises.count
        )

        do {
            var oldDocuments: [QueryDocumentSnapshot] = []
            if librarySubmission?.status == .rejected {
                async let oldExerciseDocs = submissionRef.collection("exercises").getDocuments()
                async let oldBlockDocs = submissionRef.collection("blocks").getDocuments()
                let (oldExercises, oldBlocks) = try await (oldExerciseDocs, oldBlockDocs)
                oldDocuments = oldExercises.documents + oldBlocks.documents
            }

            let batch = firestore.batch()
            batch.setData(submission.firestoreData, forDocument: submissionRef)
            for document in oldDocuments {
                batch.deleteDocument(document.reference)
            }
            for block in blocks {
                batch.setData(
                    block.firestoreData,
                    forDocument: submissionRef.collection("blocks").document(block.id)
                )
            }
            for exercise in exercises {
                batch.setData(
                    exercise.firestoreData,
                    forDocument: submissionRef.collection("exercises").document(exercise.id)
                )
            }
            try await batch.commit()
            librarySubmission = submission
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Repairs drafts saved by older versions where a multi-round block kept
    /// only one physical set per exercise. The UI is updated immediately; the
    /// Firestore write is best-effort so a migration failure never hides data.
    private func migrateLegacyRoundDrivenSetsIfNeeded() async {
        let blocksByID = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, $0) })
        var changedItems: [WorkoutTemplateExerciseItem] = []

        exercises = exercises.map { exercise in
            guard let blockID = exercise.blockId,
                  let block = blocksByID[blockID] else { return exercise }
            let expandedSets = exercise.sets.fillingRepeatingRounds(
                upTo: block.requiredSetCountPerExercise
            )
            guard expandedSets.count != exercise.sets.count else { return exercise }

            let updated = WorkoutTemplateExerciseItem(
                id: exercise.id,
                templateId: exercise.templateId,
                blockId: exercise.blockId,
                groupId: exercise.groupId,
                name: exercise.name,
                systemImage: exercise.systemImage,
                accentName: exercise.accentName,
                activityType: exercise.activityType,
                metValue: exercise.metValue,
                orderIndex: exercise.orderIndex,
                sets: expandedSets,
                note: exercise.note
            )
            changedItems.append(updated)
            return updated
        }

        guard changedItems.isEmpty == false else { return }
        let batch = firestore.batch()
        for item in changedItems {
            let ref = firestore
                .collection("workout_templates")
                .document(template.id)
                .collection("exercises")
                .document(item.id)
            batch.setData(item.firestoreData, forDocument: ref)
        }
        try? await batch.commit()
    }

    func addExercise(_ draft: WorkoutExerciseDraft) async {
        await addExercise(draft, blockId: nil)
    }

    func addExercise(
        _ draft: WorkoutExerciseDraft,
        blockId: String?,
        groupId: String? = nil
    ) async {
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
                groupId: groupId,
                name: draft.name,
                systemImage: draft.systemImage,
                accentName: draft.accentName,
                activityType: draft.activityType,
                metValue: draft.metValue,
                orderIndex: exercises.count,
                sets: draft.sets,
                note: draft.note
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
        mode: WorkoutBlockMode,
        preset: WorkoutBlockPreset? = nil,
        rounds: Int,
        durationMinutes: Int,
        workSeconds: Int,
        restSeconds: Int,
        restBetweenRoundsSeconds: Int
    ) async -> Bool {
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
                mode: mode,
                preset: preset,
                orderIndex: blocks.count,
                rounds: rounds,
                durationMinutes: durationMinutes,
                workSeconds: workSeconds,
                restSeconds: restSeconds,
                restBetweenRoundsSeconds: restBetweenRoundsSeconds
            )

            try await documentRef.setData(item.firestoreData)
            blocks.append(item)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func addGeneratedDraft(
        _ draft: AIWorkoutDraft,
        libraryTemplates: [AIWorkoutLibraryTemplateSnapshot] = []
    ) async {
        errorMessage = nil

        do {
            let resolvedDraft = draft.resolvingExercises(using: workoutTemplates())
            let templateRef = firestore.collection("workout_templates").document(template.id)
            let batch = firestore.batch()
            var newBlocks: [WorkoutTemplateBlockItem] = []
            var updatedBlocksByID: [String: WorkoutTemplateBlockItem] = [:]
            var newExercises: [WorkoutTemplateExerciseItem] = []
            var updatedExercisesByID: [String: WorkoutTemplateExerciseItem] = [:]
            var deletedExerciseIDs: Set<String> = []
            var nextBlockIndex = blocks.count
            var nextExerciseIndex = exercises.count
            var orderedBlockIDs = blocks
                .sorted { $0.orderIndex < $1.orderIndex }
                .map(\.id)

            // Library templates are copied deterministically rather than being
            // described to the language model. This preserves their exact
            // blocks, groups, prescriptions and coaching notes.
            for snapshot in libraryTemplates {
                var copiedBlockIDs: [String: String] = [:]
                var copiedGroupIDs: [String: String] = [:]

                for sourceBlock in snapshot.blocks.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                    let blockRef = templateRef.collection("blocks").document()
                    let copiedGroups = sourceBlock.groups
                        .sorted(by: { $0.orderIndex < $1.orderIndex })
                        .map { sourceGroup in
                            let copiedGroup = WorkoutTemplateBlockGroupItem(
                                title: sourceGroup.title,
                                kind: sourceGroup.kind,
                                note: sourceGroup.note,
                                rounds: sourceGroup.rounds,
                                restSeconds: sourceGroup.restSeconds,
                                orderIndex: sourceGroup.orderIndex
                            )
                            copiedGroupIDs["\(sourceBlock.id)|\(sourceGroup.id)"] = copiedGroup.id
                            return copiedGroup
                        }
                    let copiedBlock = WorkoutTemplateBlockItem(
                        id: blockRef.documentID,
                        templateId: template.id,
                        title: sourceBlock.title,
                        type: sourceBlock.type,
                        mode: sourceBlock.mode,
                        preset: sourceBlock.preset,
                        orderIndex: nextBlockIndex,
                        rounds: sourceBlock.rounds,
                        durationMinutes: sourceBlock.durationMinutes,
                        workSeconds: sourceBlock.workSeconds,
                        restSeconds: sourceBlock.restSeconds,
                        restBetweenRoundsSeconds: sourceBlock.restBetweenRoundsSeconds,
                        groups: copiedGroups
                    )
                    copiedBlockIDs[sourceBlock.id] = copiedBlock.id
                    batch.setData(copiedBlock.firestoreData, forDocument: blockRef)
                    newBlocks.append(copiedBlock)
                    orderedBlockIDs.append(copiedBlock.id)
                    nextBlockIndex += 1
                }

                for sourceExercise in snapshot.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                    let exerciseRef = templateRef.collection("exercises").document()
                    let copiedBlockID = sourceExercise.blockId.flatMap { copiedBlockIDs[$0] }
                    let copiedGroupID: String?
                    if let sourceBlockID = sourceExercise.blockId,
                       let sourceGroupID = sourceExercise.groupId {
                        copiedGroupID = copiedGroupIDs["\(sourceBlockID)|\(sourceGroupID)"]
                    } else {
                        copiedGroupID = nil
                    }
                    let copiedExercise = WorkoutTemplateExerciseItem(
                        id: exerciseRef.documentID,
                        templateId: template.id,
                        blockId: copiedBlockID,
                        groupId: copiedGroupID,
                        name: sourceExercise.name,
                        systemImage: sourceExercise.systemImage,
                        accentName: sourceExercise.accentName,
                        activityType: sourceExercise.activityType,
                        metValue: sourceExercise.metValue,
                        orderIndex: nextExerciseIndex,
                        sets: sourceExercise.sets,
                        note: sourceExercise.note
                    )
                    batch.setData(copiedExercise.firestoreData, forDocument: exerciseRef)
                    newExercises.append(copiedExercise)
                    nextExerciseIndex += 1
                }
            }

            for generatedBlock in resolvedDraft.blocks {
                let referencedExercise = generatedBlock.exercises
                    .compactMap(\.targetExerciseId)
                    .compactMap { targetID in exercises.first { $0.id == targetID } }
                    .first
                let effectiveTargetBlockID = generatedBlock.targetBlockId ?? referencedExercise?.blockId
                let existingBlock = effectiveTargetBlockID.flatMap { targetID in
                    blocks.first { $0.id == targetID }
                }

                let destinationBlock: WorkoutTemplateBlockItem
                if let existingBlock, generatedBlock.updatesBlockSettings {
                    let updatedBlock = WorkoutTemplateBlockItem(
                        id: existingBlock.id,
                        templateId: existingBlock.templateId,
                        title: generatedBlock.title,
                        type: generatedBlock.workoutBlockType,
                        mode: generatedBlock.workoutBlockMode,
                        preset: generatedBlock.workoutPreset,
                        orderIndex: existingBlock.orderIndex,
                        rounds: generatedBlock.rounds,
                        durationMinutes: generatedBlock.durationMinutes,
                        workSeconds: generatedBlock.workSeconds,
                        restSeconds: generatedBlock.restSeconds,
                        restBetweenRoundsSeconds: generatedBlock.restBetweenRoundsSeconds,
                        groups: existingBlock.groups
                    )
                    batch.setData(
                        updatedBlock.firestoreData,
                        forDocument: templateRef.collection("blocks").document(existingBlock.id)
                    )
                    updatedBlocksByID[existingBlock.id] = updatedBlock
                    destinationBlock = updatedBlock
                } else if let existingBlock {
                    destinationBlock = existingBlock
                } else {
                    let blockRef = templateRef.collection("blocks").document()
                    let block = WorkoutTemplateBlockItem(
                        id: blockRef.documentID,
                        templateId: template.id,
                        title: generatedBlock.title,
                        type: generatedBlock.workoutBlockType,
                        mode: generatedBlock.workoutBlockMode,
                        preset: generatedBlock.workoutPreset,
                        orderIndex: nextBlockIndex,
                        rounds: generatedBlock.rounds,
                        durationMinutes: generatedBlock.durationMinutes,
                        workSeconds: generatedBlock.workSeconds,
                        restSeconds: generatedBlock.restSeconds,
                        restBetweenRoundsSeconds: generatedBlock.restBetweenRoundsSeconds
                    )
                    batch.setData(block.firestoreData, forDocument: blockRef)
                    newBlocks.append(block)
                    if let anchorID = generatedBlock.insertAfterBlockId,
                       let anchorIndex = orderedBlockIDs.firstIndex(of: anchorID) {
                        orderedBlockIDs.insert(block.id, at: anchorIndex + 1)
                    } else {
                        orderedBlockIDs.append(block.id)
                    }
                    nextBlockIndex += 1
                    destinationBlock = block
                }

                for generatedExercise in generatedBlock.exercises {
                    switch generatedExercise.operation {
                    case .add:
                        let exerciseRef = templateRef.collection("exercises").document()
                        let exercise = WorkoutTemplateExerciseItem(
                            id: exerciseRef.documentID,
                            templateId: template.id,
                            blockId: destinationBlock.id,
                            name: generatedExercise.name,
                            systemImage: generatedExercise.systemImage,
                            accentName: generatedExercise.accentName,
                            activityType: generatedExercise.workoutActivityType,
                            metValue: generatedExercise.metValue,
                            orderIndex: nextExerciseIndex,
                            sets: generatedExercise.sets.map(\.workoutSet),
                            note: generatedExercise.note
                        )
                        batch.setData(exercise.firestoreData, forDocument: exerciseRef)
                        newExercises.append(exercise)
                        nextExerciseIndex += 1

                    case .update:
                        guard let targetID = generatedExercise.targetExerciseId,
                              let existingExercise = exercises.first(where: { $0.id == targetID }) else {
                            throw NSError(
                                domain: "AIWorkoutDraft",
                                code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "ИИ не указал изменяемое упражнение. Сформируйте черновик заново."]
                            )
                        }
                        let updatedExercise = WorkoutTemplateExerciseItem(
                            id: existingExercise.id,
                            templateId: existingExercise.templateId,
                            blockId: destinationBlock.id,
                            groupId: existingExercise.groupId,
                            name: generatedExercise.name,
                            systemImage: generatedExercise.systemImage,
                            accentName: generatedExercise.accentName,
                            activityType: generatedExercise.workoutActivityType,
                            metValue: generatedExercise.metValue,
                            orderIndex: existingExercise.orderIndex,
                            sets: generatedExercise.sets.map(\.workoutSet),
                            note: generatedExercise.note
                        )
                        batch.setData(
                            updatedExercise.firestoreData,
                            forDocument: templateRef.collection("exercises").document(existingExercise.id)
                        )
                        updatedExercisesByID[existingExercise.id] = updatedExercise

                    case .delete:
                        guard let targetID = generatedExercise.targetExerciseId,
                              exercises.contains(where: { $0.id == targetID }) else {
                            throw NSError(
                                domain: "AIWorkoutDraft",
                                code: 2,
                                userInfo: [NSLocalizedDescriptionKey: "ИИ не указал удаляемое упражнение. Сформируйте черновик заново."]
                            )
                        }
                        batch.deleteDocument(templateRef.collection("exercises").document(targetID))
                        deletedExerciseIDs.insert(targetID)
                    }
                }
            }

            // Persist a single, collision-free order after all insertions. This
            // lets a newly generated block sit immediately after its requested
            // anchor without relying on duplicate integer order values.
            let allBlocks = blocks.map { updatedBlocksByID[$0.id] ?? $0 } + newBlocks
            let blocksByID = Dictionary(uniqueKeysWithValues: allBlocks.map { ($0.id, $0) })
            let untrackedIDs = allBlocks
                .map(\.id)
                .filter { orderedBlockIDs.contains($0) == false }
            let normalizedBlocks = (orderedBlockIDs + untrackedIDs)
                .compactMap { blocksByID[$0] }
                .enumerated()
                .map { index, block in block.replacingOrderIndex(index) }

            for block in normalizedBlocks {
                batch.setData(
                    block.firestoreData,
                    forDocument: templateRef.collection("blocks").document(block.id)
                )
            }

            try await batch.commit()
            blocks = normalizedBlocks
            exercises = exercises
                .filter { deletedExerciseIDs.contains($0.id) == false }
                .map { updatedExercisesByID[$0.id] ?? $0 }
            exercises.append(contentsOf: newExercises)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addGroup(
        to block: WorkoutTemplateBlockItem,
        title: String,
        kind: WorkoutBlockGroupKind,
        rounds: Int,
        restSeconds: Int,
        note: String
    ) async {
        errorMessage = nil
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let group = WorkoutTemplateBlockGroupItem(
            title: trimmedTitle.isEmpty ? kind.title : trimmedTitle,
            kind: kind,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            rounds: rounds,
            restSeconds: restSeconds,
            orderIndex: block.groups.count
        )
        let updatedBlock = WorkoutTemplateBlockItem(
            id: block.id,
            templateId: block.templateId,
            title: block.title,
            type: block.type,
            mode: block.mode,
            preset: block.preset,
            orderIndex: block.orderIndex,
            rounds: block.rounds,
            durationMinutes: block.durationMinutes,
            workSeconds: block.workSeconds,
            restSeconds: block.restSeconds,
            restBetweenRoundsSeconds: block.restBetweenRoundsSeconds,
            groups: block.groups + [group]
        )

        do {
            try await firestore
                .collection("workout_templates")
                .document(template.id)
                .collection("blocks")
                .document(block.id)
                .setData(updatedBlock.firestoreData)
            if let index = blocks.firstIndex(where: { $0.id == block.id }) {
                blocks[index] = updatedBlock
            }
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

    func updateExercise(
        _ exercise: WorkoutTemplateExerciseItem,
        with draft: WorkoutExerciseDraft
    ) async {
        errorMessage = nil
        let updated = WorkoutTemplateExerciseItem(
            id: exercise.id,
            templateId: exercise.templateId,
            blockId: exercise.blockId,
            groupId: exercise.groupId,
            name: exercise.name,
            systemImage: exercise.systemImage,
            accentName: exercise.accentName,
            activityType: draft.activityType,
            metValue: draft.metValue,
            orderIndex: exercise.orderIndex,
            sets: draft.sets,
            note: draft.note
        )

        do {
            try await firestore
                .collection("workout_templates")
                .document(template.id)
                .collection("exercises")
                .document(exercise.id)
                .setData(updated.firestoreData)
            if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
                exercises[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveExercise(
        _ exercise: WorkoutTemplateExerciseItem,
        to block: WorkoutTemplateBlockItem
    ) async -> WorkoutTemplateBlockItem? {
        guard exercise.blockId != block.id else { return nil }
        errorMessage = nil

        let sourceBlock = blocks.first { $0.id == exercise.blockId }
        let sourceWillBeEmpty = sourceBlock.map { source in
            exercises.contains { $0.blockId == source.id && $0.id != exercise.id } == false
        } ?? false

        let targetOrderIndex = (exercises
            .filter { $0.blockId == block.id }
            .map(\.orderIndex)
            .max() ?? -1) + 1
        let updated = WorkoutTemplateExerciseItem(
            id: exercise.id,
            templateId: exercise.templateId,
            blockId: block.id,
            groupId: nil,
            name: exercise.name,
            systemImage: exercise.systemImage,
            accentName: exercise.accentName,
            activityType: exercise.activityType,
            metValue: exercise.metValue,
            orderIndex: targetOrderIndex,
            sets: exercise.sets,
            note: exercise.note
        )

        do {
            try await firestore
                .collection("workout_templates")
                .document(template.id)
                .collection("exercises")
                .document(exercise.id)
                .setData(updated.firestoreData)
            if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
                exercises[index] = updated
            }
            return sourceWillBeEmpty ? sourceBlock : nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func deleteEmptyBlock(_ block: WorkoutTemplateBlockItem) async {
        guard exercises.contains(where: { $0.blockId == block.id }) == false else { return }
        await deleteBlock(block)
    }

    func deleteBlock(_ block: WorkoutTemplateBlockItem) async {
        errorMessage = nil
        do {
            let templateRef = firestore.collection("workout_templates").document(template.id)
            let blockExercises = exercises.filter { $0.blockId == block.id }
            let batch = firestore.batch()

            for exercise in blockExercises {
                batch.deleteDocument(templateRef.collection("exercises").document(exercise.id))
            }
            batch.deleteDocument(templateRef.collection("blocks").document(block.id))
            try await batch.commit()

            blocks.removeAll { $0.id == block.id }
            exercises.removeAll { $0.blockId == block.id }
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
                groupId: item.groupId,
                name: item.name,
                systemImage: item.systemImage,
                accentName: item.accentName,
                activityType: item.activityType,
                metValue: item.metValue,
                orderIndex: index,
                sets: item.sets,
                note: item.note
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

extension WorkoutCalorieEstimator {
    static func estimateTemplateCalories(
        exercises: [WorkoutTemplateExerciseItem],
        userWeightKg: Double = 70
    ) -> Int {
        let safeWeight = userWeightKg > 0 ? userWeightKg : 70
        let totalCalories = exercises.reduce(0.0) { total, exercise in
            guard exercise.sets.isEmpty == false else { return total }

            let activeSeconds = exercise.sets.reduce(0) { partial, set in
                switch set.metricType {
                case .duration:
                    return partial + max(0, set.durationSeconds)
                case .reps:
                    return partial + max(0, set.reps) * 4
                }
            }
            let activeCalories = max(exercise.metValue, 1.0) * safeWeight * (Double(activeSeconds) / 3600.0)
            let restSeconds = max(0, exercise.sets.count - 1) * 60
            let restCalories = 1.8 * safeWeight * (Double(restSeconds) / 3600.0)

            return total + activeCalories + restCalories
        }

        return max(0, Int(totalCalories.rounded()))
    }
}

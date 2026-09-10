import Foundation
import FirebaseFirestore

struct AIWorkoutLibraryTemplateSnapshot: Identifiable {
    let template: LibraryWorkoutTemplate
    let blocks: [WorkoutTemplateBlockItem]
    let exercises: [WorkoutTemplateExerciseItem]

    var id: String { template.id }
}

private struct AIWorkoutLibraryPromptTemplate: Encodable {
    let title: String
    let blocks: [AIWorkoutLibraryPromptBlock]
}

private struct AIWorkoutLibraryPromptBlock: Encodable {
    let title: String
    let type: String
    let preset: String
    let mode: String
    let rounds: Int
    let durationMinutes: Int
    let workSeconds: Int
    let restSeconds: Int
    let restBetweenRoundsSeconds: Int
    let exercises: [AIWorkoutLibraryPromptExercise]
}

private struct AIWorkoutLibraryPromptExercise: Encodable {
    let name: String
    let systemImage: String
    let accentName: String
    let activityType: String
    let metValue: Double
    let note: String
    let sets: [AIWorkoutExistingSet]
}

struct AIWorkoutGenerationResult {
    let draft: AIWorkoutDraft
    let libraryTemplates: [AIWorkoutLibraryTemplateSnapshot]
}

struct AIWorkoutClarification: Identifiable, Equatable {
    let question: String
    let options: [String]
    let exerciseName: String?

    init(question: String, options: [String], exerciseName: String? = nil) {
        self.question = question
        self.options = options
        self.exerciseName = exerciseName
    }

    var id: String { question }
}

enum AIWorkoutGenerationDecision {
    case draft(AIWorkoutDraft)
    case clarification(AIWorkoutClarification)
}

struct AIWorkoutLibraryResolution {
    let templates: [AIWorkoutLibraryTemplateSnapshot]
    let remainingCommand: String

    var needsAI: Bool {
        let ignoredWords: Set<String> = [
            "возьми", "добавь", "добавить", "вставь", "вставить", "используй",
            "в", "во", "к", "тренировку", "тренировке", "тренировки", "шаблон",
            "шаблона", "из", "библиотеки", "библиотека", "fitlife", "и", "а",
            "пожалуйста", "например", "готовый", "готового", "мне",
            "add", "insert", "use", "to", "into", "workout", "template", "from",
            "library", "please", "and", "the"
        ]
        return normalizedLibraryText(remainingCommand)
            .split(separator: " ")
            .map(String.init)
            .contains { ignoredWords.contains($0) == false }
    }
}

actor AIWorkoutLibraryResolver {
    private let firestore: Firestore

    init(firestore: Firestore = .firestore()) {
        self.firestore = firestore
    }

    func resolve(command: String) async throws -> AIWorkoutLibraryResolution {
        let snapshot = try await firestore
            .collection("workout_template_library")
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        let commandKey = normalizedLibraryText(command)
        let candidates = snapshot.documents
            .compactMap { LibraryWorkoutTemplate(id: $0.documentID, data: $0.data()) }
            .filter {
                librarySearchTitles(for: $0).contains { title in
                    let titleKey = normalizedLibraryText(title)
                    return titleKey.isEmpty == false
                        && " \(commandKey) ".contains(" \(titleKey) ")
                }
            }
            .sorted {
                (librarySearchTitles(for: $0).map { normalizedLibraryText($0).count }.max() ?? 0)
                    > (librarySearchTitles(for: $1).map { normalizedLibraryText($0).count }.max() ?? 0)
            }

        // Prefer the most specific name: "Разминка 1" must not also resolve a
        // shorter library item named simply "Разминка".
        var matchedTemplates: [LibraryWorkoutTemplate] = []
        for candidate in candidates {
            let candidateKeys = librarySearchTitles(for: candidate).map(normalizedLibraryText)
            guard matchedTemplates.contains(where: {
                let matchedKeys = librarySearchTitles(for: $0).map(normalizedLibraryText)
                return candidateKeys.contains { candidateKey in
                    matchedKeys.contains { $0.contains(candidateKey) }
                }
            }) == false else { continue }
            matchedTemplates.append(candidate)
        }

        var resolved: [AIWorkoutLibraryTemplateSnapshot] = []
        for template in matchedTemplates {
            let reference = firestore.collection("workout_template_library").document(template.id)
            async let blocksSnapshot = reference.collection("blocks").getDocuments()
            async let exercisesSnapshot = reference.collection("exercises").getDocuments()
            let (blockDocs, exerciseDocs) = try await (blocksSnapshot, exercisesSnapshot)
            resolved.append(AIWorkoutLibraryTemplateSnapshot(
                template: template,
                blocks: blockDocs.documents.compactMap {
                    WorkoutTemplateBlockItem(id: $0.documentID, templateId: template.id, data: $0.data())
                }.sorted { $0.orderIndex < $1.orderIndex },
                exercises: exerciseDocs.documents.compactMap {
                    WorkoutTemplateExerciseItem(id: $0.documentID, templateId: template.id, data: $0.data())
                }.sorted { $0.orderIndex < $1.orderIndex }
            ))
        }

        var remainingCommand = command
        for template in matchedTemplates {
            for title in librarySearchTitles(for: template).sorted(by: { $0.count > $1.count }) {
                while let range = remainingCommand.range(
                    of: title,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) {
                    remainingCommand.removeSubrange(range)
                }
            }
        }
        remainingCommand = remainingCommand
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))

        return AIWorkoutLibraryResolution(templates: resolved, remainingCommand: remainingCommand)
    }
}

private func librarySearchTitles(for template: LibraryWorkoutTemplate) -> [String] {
    var titles = [template.fallbackTitle, template.title]
    if let titleKey = template.titleKey {
        titles.append(contentsOf: AppLanguage.allCases.map { $0.localized(titleKey) })
    }
    return Array(Set(titles.filter { $0.isEmpty == false }))
}

private func normalizedLibraryText(_ value: String) -> String {
    let folded = value.lowercased().folding(options: .diacriticInsensitive, locale: .current)
    return String(folded.unicodeScalars.map {
        CharacterSet.alphanumerics.contains($0) ? Character(String($0)) : " "
    })
    .split(whereSeparator: { $0.isWhitespace })
    .joined(separator: " ")
}

struct AIWorkoutDraft: Decodable, Identifiable {
    let summary: String
    let blocks: [AIWorkoutDraftBlock]

    var id: String { summary + "-" + String(blocks.count) }
}

struct AIWorkoutDraftBlock: Decodable, Identifiable {
    let title: String
    let targetBlockId: String?
    /// Used only for a newly created block. Unlike `targetBlockId`, this never
    /// means "merge"; it controls where the new block is inserted.
    let insertAfterBlockId: String?
    /// Existing block settings are preserved unless the trainer explicitly
    /// asked to change rounds, timing, rest, or the block format.
    let updatesBlockSettings: Bool
    /// Explicit block semantics. Optional so drafts created by older app versions
    /// can still be decoded and migrated through the legacy type/mode fields.
    let preset: String?
    let type: String
    let mode: String
    let rounds: Int
    let durationMinutes: Int
    let workSeconds: Int
    let restSeconds: Int
    let restBetweenRoundsSeconds: Int
    let exercises: [AIWorkoutDraftExercise]

    var id: String { title + "-" + type }

    var workoutPreset: WorkoutBlockPreset {
        if let preset, let explicitPreset = WorkoutBlockPreset(rawValue: preset) {
            return explicitPreset
        }
        return WorkoutBlockPreset.inferred(
            title: title,
            type: WorkoutBlockType(rawValue: type) ?? .main,
            mode: WorkoutBlockMode(rawValue: mode) ?? .rounds
        )
    }

    var workoutBlockType: WorkoutBlockType {
        workoutPreset.blockType
    }

    var workoutBlockMode: WorkoutBlockMode {
        workoutPreset.mode
    }

    /// These formats execute every exercise once per round/stage. Therefore the
    /// persisted set list must contain a real set for every round; otherwise the
    /// runner can repeat visually while history and reports still count one set.
    var repeatsEveryExerciseEachRound: Bool {
        switch workoutPreset {
        case .superset, .circuit, .rft, .pyramid, .dropSet, .clusterSet, .ladder:
            return true
        default:
            return false
        }
    }
}

struct AIWorkoutExistingBlock: Encodable {
    let id: String
    let title: String
    let type: String
    let preset: String
    let mode: String
    let orderIndex: Int
    let rounds: Int
    let durationMinutes: Int
    let workSeconds: Int
    let restSeconds: Int
    let restBetweenRoundsSeconds: Int
    let exercises: [AIWorkoutExistingExercise]
}

struct AIWorkoutExistingExercise: Encodable {
    let id: String
    let name: String
    let sets: [AIWorkoutExistingSet]
}

struct AIWorkoutExistingSet: Encodable {
    let weight: Double
    let reps: Int
    let durationSeconds: Int
    let metricType: String
    let method: String
    let methodGroup: Int
    let stepIndex: Int
    let restAfterSeconds: Int
    let pyramidPattern: String
}

extension Array where Element == WorkoutDraftSet {
    var aiExistingSets: [AIWorkoutExistingSet] {
        var groupNumbers: [UUID: Int] = [:]
        return map { set in
            let methodGroup: Int
            if let groupID = set.groupID, set.method != .normal {
                if let existing = groupNumbers[groupID] {
                    methodGroup = existing
                } else {
                    let next = groupNumbers.count + 1
                    groupNumbers[groupID] = next
                    methodGroup = next
                }
            } else {
                methodGroup = 0
            }
            return AIWorkoutExistingSet(
                weight: set.weight,
                reps: set.reps,
                durationSeconds: set.durationSeconds,
                metricType: set.metricType.rawValue,
                method: set.method.rawValue,
                methodGroup: methodGroup,
                stepIndex: set.stepIndex,
                restAfterSeconds: set.restAfterSeconds,
                pyramidPattern: set.pyramidPattern.rawValue
            )
        }
    }
}

enum AIWorkoutExerciseOperation: String, Decodable {
    case add, update, delete
}

struct AIWorkoutDraftExercise: Decodable, Identifiable {
    let operation: AIWorkoutExerciseOperation
    let targetExerciseId: String?
    let name: String
    let systemImage: String
    let accentName: String
    let activityType: String
    let metValue: Double
    let note: String
    let sets: [AIWorkoutDraftSet]

    var id: String { "\(operation.rawValue)-\(targetExerciseId ?? name)" }

    var workoutActivityType: WorkoutActivityType {
        WorkoutActivityType(rawValue: activityType) ?? .strength
    }

    var workoutSets: [WorkoutDraftSet] {
        var groupIDs: [Int: UUID] = [:]
        return sets.map { set in
            let method = WorkoutSetMethod(rawValue: set.method ?? "") ?? .normal
            let groupID: UUID?
            if method != .normal, let methodGroup = set.methodGroup, methodGroup > 0 {
                if let existing = groupIDs[methodGroup] {
                    groupID = existing
                } else {
                    let created = UUID()
                    groupIDs[methodGroup] = created
                    groupID = created
                }
            } else {
                groupID = nil
            }
            return set.workoutSet(method: method, groupID: groupID)
        }
    }
}

struct AIWorkoutDraftSet: Decodable {
    let weight: Double
    let reps: Int
    let durationSeconds: Int
    let metricType: String
    let method: String?
    let methodGroup: Int?
    let stepIndex: Int?
    let restAfterSeconds: Int?
    let pyramidPattern: String?

    func workoutSet(method resolvedMethod: WorkoutSetMethod? = nil, groupID: UUID? = nil) -> WorkoutDraftSet {
        let workoutMethod = resolvedMethod ?? WorkoutSetMethod(rawValue: method ?? "") ?? .normal
        return WorkoutDraftSet(
            weight: weight,
            reps: reps,
            durationSeconds: durationSeconds,
            metricType: WorkoutSetMetricType(rawValue: metricType) ?? .reps,
            method: workoutMethod,
            pyramidPattern: WorkoutPyramidPattern(rawValue: pyramidPattern ?? "") ?? .ascending,
            groupID: groupID,
            stepIndex: stepIndex ?? 0,
            restAfterSeconds: restAfterSeconds ?? 0
        )
    }

    func applying(method workoutMethod: WorkoutSetMethod, methodGroup: Int, stepIndex: Int) -> AIWorkoutDraftSet {
        AIWorkoutDraftSet(
            weight: weight,
            reps: reps,
            durationSeconds: durationSeconds,
            metricType: metricType,
            method: workoutMethod.rawValue,
            methodGroup: methodGroup,
            stepIndex: stepIndex,
            restAfterSeconds: restAfterSeconds,
            pyramidPattern: workoutMethod == .pyramid
                ? (pyramidPattern ?? WorkoutPyramidPattern.custom.rawValue)
                : WorkoutPyramidPattern.ascending.rawValue
        )
    }
}

extension AIWorkoutDraft {
    func exerciseResolutionClarification(
        using catalog: [WorkoutExerciseTemplate],
        alternateLanguageCatalogs: [[WorkoutExerciseTemplate]],
        sourceCommand: String,
        exerciseSelections: [String: String] = [:],
        language: AppLanguage
    ) -> AIWorkoutClarification? {
        for exercise in blocks.flatMap(\.exercises) {
            guard exerciseSelections[exercise.name] == nil else { continue }
            let nameMatches = catalog.bestScoringMatches(
                for: exercise.name,
                alternateLanguageCatalogs: alternateLanguageCatalogs
            )
            let commandMatches = nameMatches.count == 1
                ? catalog.bestScoringMatches(
                    for: sourceCommand,
                    alternateLanguageCatalogs: alternateLanguageCatalogs,
                    relatedTo: nameMatches
                )
                : []
            // The original command is authoritative. A model may turn a generic
            // exercise name into a more specific variation without being asked
            // (for example, "glute bridge" into "single-leg glute bridge").
            let ambiguousMatches: [WorkoutExerciseTemplate]
            if commandMatches.count > 1 {
                ambiguousMatches = commandMatches
            } else if nameMatches.count > 1 {
                ambiguousMatches = nameMatches
            } else if let commandMatch = commandMatches.first,
                      let nameMatch = nameMatches.first,
                      commandMatch.id != nameMatch.id {
                // The model selected a variation that the user's own wording
                // does not support. Let the trainer choose instead of silently
                // accepting the model's extra specificity.
                ambiguousMatches = [commandMatch, nameMatch]
            } else {
                ambiguousMatches = []
            }
            guard ambiguousMatches.count > 1 else { continue }

            return AIWorkoutClarification(
                question: String(
                    format: language.localized("trainer.ai.exercise_ambiguity.question"),
                    locale: language.locale,
                    arguments: [exercise.name]
                ),
                options: Array(ambiguousMatches.prefix(4).map(\.name)),
                exerciseName: exercise.name
            )
        }
        return nil
    }

    func resolvingExercises(
        using catalog: [WorkoutExerciseTemplate],
        alternateLanguageCatalogs: [[WorkoutExerciseTemplate]] = [],
        exerciseSelections: [String: String] = [:]
    ) -> AIWorkoutDraft {
        AIWorkoutDraft(
            summary: summary,
            blocks: blocks.map { block in
                let normalizedRounds = block.repeatsEveryExerciseEachRound
                    ? min(max(block.rounds, 1), 12)
                    : max(block.rounds, 1)
                return AIWorkoutDraftBlock(
                    title: block.title,
                    targetBlockId: block.targetBlockId,
                    insertAfterBlockId: block.insertAfterBlockId,
                    updatesBlockSettings: block.updatesBlockSettings,
                    preset: block.workoutPreset.rawValue,
                    type: block.type,
                    mode: block.mode,
                    rounds: normalizedRounds,
                    durationMinutes: block.durationMinutes,
                    workSeconds: block.workSeconds,
                    restSeconds: block.restSeconds,
                    restBetweenRoundsSeconds: block.restBetweenRoundsSeconds,
                    exercises: block.exercises.map { exercise in
                        var resolvedExercise = exercise
                        let requestedName = exerciseSelections[exercise.name] ?? exercise.name
                        if let template = catalog.bestMatch(
                            for: requestedName,
                            alternateLanguageCatalogs: alternateLanguageCatalogs
                        ) {
                            resolvedExercise = AIWorkoutDraftExercise(
                                operation: exercise.operation,
                                targetExerciseId: exercise.targetExerciseId,
                                name: template.name,
                                systemImage: template.systemImage,
                                accentName: template.accentName,
                                activityType: template.activityType.rawValue,
                                metValue: template.metValue,
                                note: exercise.note,
                                sets: exercise.sets
                            )
                        }

                        guard block.repeatsEveryExerciseEachRound,
                              let lastSet = resolvedExercise.sets.last,
                              resolvedExercise.sets.count < normalizedRounds else {
                            return resolvedExercise
                        }
                        return AIWorkoutDraftExercise(
                            operation: resolvedExercise.operation,
                            targetExerciseId: resolvedExercise.targetExerciseId,
                            name: resolvedExercise.name,
                            systemImage: resolvedExercise.systemImage,
                            accentName: resolvedExercise.accentName,
                            activityType: resolvedExercise.activityType,
                            metValue: resolvedExercise.metValue,
                            note: resolvedExercise.note,
                            sets: resolvedExercise.sets
                                + Array(repeating: lastSet, count: normalizedRounds - resolvedExercise.sets.count)
                        )
                    }
                )
            }
        )
    }

    /// Models sometimes interpret "new superset after the old one" as an edit
    /// because both blocks have the same display title. Make the user's explicit
    /// creation intent authoritative: the referenced block becomes the insertion
    /// anchor, never the merge destination.
    func applyingPlacementIntent(from command: String) -> AIWorkoutDraft {
        let normalized = command
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
        let explicitBlockCreationPhrases = [
            "новый блок", "нового блока", "новый суперсет", "нового суперсета",
            "новую разминку", "новый круг", "новую табату", "новый комплекс",
            "отдельный блок", "отдельный суперсет", "отдельную разминку",
            "еще один блок", "еще один суперсет", "ещё один блок", "ещё один суперсет",
            "new block", "new superset", "new circuit", "new warmup", "another block",
            "another superset", "separate block", "separate superset"
        ]
        guard explicitBlockCreationPhrases.contains(where: normalized.contains) else { return self }

        return AIWorkoutDraft(
            summary: summary,
            blocks: blocks.map { block in
                AIWorkoutDraftBlock(
                    title: block.title,
                    targetBlockId: nil,
                    insertAfterBlockId: block.insertAfterBlockId ?? block.targetBlockId,
                    updatesBlockSettings: block.updatesBlockSettings,
                    preset: block.preset,
                    type: block.type,
                    mode: block.mode,
                    rounds: block.rounds,
                    durationMinutes: block.durationMinutes,
                    workSeconds: block.workSeconds,
                    restSeconds: block.restSeconds,
                    restBetweenRoundsSeconds: block.restBetweenRoundsSeconds,
                    exercises: block.exercises
                )
            }
        )
    }

    /// A trainer can describe the initial prescription and then append a
    /// pyramid or extra sets for the same exercise. Models occasionally emit
    /// that as two `add` operations. Keep the trainer's explicit append intent
    /// authoritative and show one exercise with one ordered set list.
    func applyingSetAppendIntent(from command: String) -> AIWorkoutDraft {
        let normalizedCommand = command
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
        let appendPhrases = [
            "добавь подход", "добавить подход", "добавь еще подход", "добавь ещё подход",
            "добавь пирамид", "добавить пирамид", "дополни подход", "пирамида подход",
            "добавь дроп", "добавить дроп", "добавь кластер", "добавить кластер",
            "append set", "add set", "add another set", "add a pyramid", "append a pyramid",
            "add a drop set", "append a drop set", "add a cluster", "append a cluster"
        ]
        let separateExercisePhrases = [
            "отдельное упражнение", "отдельным упражнением", "еще одно упражнение",
            "ещё одно упражнение", "второе упражнение", "separate exercise",
            "another exercise", "second exercise"
        ]
        guard appendPhrases.contains(where: normalizedCommand.contains),
              separateExercisePhrases.contains(where: normalizedCommand.contains) == false else {
            return self
        }

        let requestedMethod: WorkoutSetMethod? = {
            if normalizedCommand.contains("дроп") || normalizedCommand.contains("drop set") {
                return .dropSet
            }
            if normalizedCommand.contains("пирамид") || normalizedCommand.contains("pyramid") {
                return .pyramid
            }
            if normalizedCommand.contains("кластер") || normalizedCommand.contains("cluster") {
                return .cluster
            }
            return nil
        }()

        return AIWorkoutDraft(
            summary: summary,
            blocks: blocks.map { block in
                var mergedExercises: [AIWorkoutDraftExercise] = []
                var addedExerciseIndexByName: [String: Int] = [:]

                for exercise in block.exercises {
                    let normalizedName = normalizedExerciseName(exercise.name)
                    if exercise.operation == .add,
                       exercise.targetExerciseId == nil,
                       normalizedName.isEmpty == false,
                       let existingIndex = addedExerciseIndexByName[normalizedName] {
                        let existing = mergedExercises[existingIndex]
                        let appendedSets: [AIWorkoutDraftSet]
                        if let requestedMethod,
                           exercise.sets.contains(where: { ($0.method ?? WorkoutSetMethod.normal.rawValue) != WorkoutSetMethod.normal.rawValue }) == false {
                            let nextGroup = (existing.sets.compactMap(\.methodGroup).max() ?? 0) + 1
                            appendedSets = exercise.sets.enumerated().map { index, set in
                                set.applying(method: requestedMethod, methodGroup: nextGroup, stepIndex: index)
                            }
                        } else {
                            appendedSets = exercise.sets
                        }
                        mergedExercises[existingIndex] = AIWorkoutDraftExercise(
                            operation: .add,
                            targetExerciseId: nil,
                            name: existing.name,
                            systemImage: existing.systemImage,
                            accentName: existing.accentName,
                            activityType: existing.activityType,
                            metValue: existing.metValue,
                            note: existing.note.isEmpty ? exercise.note : existing.note,
                            sets: existing.sets + appendedSets
                        )
                    } else {
                        if exercise.operation == .add,
                           exercise.targetExerciseId == nil,
                           normalizedName.isEmpty == false {
                            addedExerciseIndexByName[normalizedName] = mergedExercises.count
                        }
                        mergedExercises.append(exercise)
                    }
                }

                return AIWorkoutDraftBlock(
                    title: block.title,
                    targetBlockId: block.targetBlockId,
                    insertAfterBlockId: block.insertAfterBlockId,
                    updatesBlockSettings: block.updatesBlockSettings,
                    preset: block.preset,
                    type: block.type,
                    mode: block.mode,
                    rounds: block.rounds,
                    durationMinutes: block.durationMinutes,
                    workSeconds: block.workSeconds,
                    restSeconds: block.restSeconds,
                    restBetweenRoundsSeconds: block.restBetweenRoundsSeconds,
                    exercises: mergedExercises
                )
            }
        )
    }

    /// Treat an add-only trainer command as a delta, even if the model returns
    /// unchanged template exercises as `update` operations. An update is kept
    /// only when the command actually names that existing exercise (for
    /// example, "add two sets to bench press").
    func enforcingAddOnlyIntent(
        from command: String,
        existingBlocks: [AIWorkoutExistingBlock]
    ) -> AIWorkoutDraft {
        let commandWords = normalizedIntentWords(command)
        let additiveWords: Set<String> = [
            "добавь", "добавить", "добавьте", "вставь", "вставить",
            "add", "append", "insert"
        ]
        let mutationWords: Set<String> = [
            "замени", "заменить", "замените", "измени", "изменить", "измените",
            "удали", "удалить", "удалите", "обнови", "обновить",
            "replace", "change", "edit", "update", "delete", "remove"
        ]
        guard commandWords.isDisjoint(with: additiveWords) == false,
              commandWords.isDisjoint(with: mutationWords) else {
            return self
        }

        let existingExercises = Dictionary(
            uniqueKeysWithValues: existingBlocks
                .flatMap(\.exercises)
                .map { ($0.id, $0) }
        )
        let targetsEveryExercise = commandWords.contains { $0.hasPrefix("кажд") }
            && commandWords.contains { $0.hasPrefix("упраж") }

        let filteredBlocks = blocks.compactMap { block -> AIWorkoutDraftBlock? in
            let filteredExercises = block.exercises.filter { exercise in
                switch exercise.operation {
                case .add:
                    return true
                case .delete:
                    return false
                case .update:
                    guard let targetID = exercise.targetExerciseId,
                          let existingExercise = existingExercises[targetID] else {
                        return false
                    }
                    return targetsEveryExercise
                        || intentMentionsExercise(commandWords, name: existingExercise.name)
                }
            }
            guard filteredExercises.isEmpty == false else { return nil }
            return block.replacingExercises(filteredExercises)
        }

        return AIWorkoutDraft(summary: summary, blocks: filteredBlocks)
    }

    /// The API schema represents every physical set as one array item. Expand
    /// explicit plain-language counts such as "25 kg, 2 reps, 3 sets" when the
    /// model returned only one matching item. Limit this deterministic repair to
    /// a single newly added exercise so prescriptions cannot leak across several
    /// exercises in a more complex command.
    func applyingExplicitSetCounts(from command: String) -> AIWorkoutDraft {
        let addedExercises = blocks
            .flatMap(\.exercises)
            .filter { $0.operation == .add }
        guard addedExercises.count == 1 else { return self }

        let requestedCounts = explicitSetCounts(in: command)
        guard requestedCounts.isEmpty == false else { return self }

        let targetID = addedExercises[0].id
        return AIWorkoutDraft(
            summary: summary,
            blocks: blocks.map { block in
                block.replacingExercises(block.exercises.map { exercise in
                    guard exercise.id == targetID else { return exercise }
                    var repairedSets = exercise.sets
                    for (prescription, requestedCount) in requestedCounts {
                        let matchingIndices = repairedSets.indices.filter {
                            prescription.matches(repairedSets[$0])
                        }
                        guard let insertionIndex = matchingIndices.last,
                              matchingIndices.count < requestedCount else { continue }
                        let missingCount = min(requestedCount - matchingIndices.count, 12 - repairedSets.count)
                        guard missingCount > 0 else { continue }
                        repairedSets.insert(
                            contentsOf: Array(repeating: repairedSets[insertionIndex], count: missingCount),
                            at: insertionIndex + 1
                        )
                    }
                    return exercise.replacingSets(repairedSets)
                })
            }
        )
    }
}

private extension AIWorkoutDraftBlock {
    func replacingExercises(_ exercises: [AIWorkoutDraftExercise]) -> AIWorkoutDraftBlock {
        AIWorkoutDraftBlock(
            title: title,
            targetBlockId: targetBlockId,
            insertAfterBlockId: insertAfterBlockId,
            updatesBlockSettings: updatesBlockSettings,
            preset: preset,
            type: type,
            mode: mode,
            rounds: rounds,
            durationMinutes: durationMinutes,
            workSeconds: workSeconds,
            restSeconds: restSeconds,
            restBetweenRoundsSeconds: restBetweenRoundsSeconds,
            exercises: exercises
        )
    }
}

private extension AIWorkoutDraftExercise {
    func replacingSets(_ sets: [AIWorkoutDraftSet]) -> AIWorkoutDraftExercise {
        AIWorkoutDraftExercise(
            operation: operation,
            targetExerciseId: targetExerciseId,
            name: name,
            systemImage: systemImage,
            accentName: accentName,
            activityType: activityType,
            metValue: metValue,
            note: note,
            sets: sets
        )
    }
}

private struct ExplicitSetPrescription: Hashable {
    let weight: Double
    let reps: Int

    func matches(_ set: AIWorkoutDraftSet) -> Bool {
        abs(set.weight - weight) < 0.001
            && set.reps == reps
            && set.metricType == WorkoutSetMetricType.reps.rawValue
    }
}

private func explicitSetCounts(in command: String) -> [ExplicitSetPrescription: Int] {
    var result: [ExplicitSetPrescription: Int] = [:]
    for line in command.components(separatedBy: .newlines) {
        guard let weightText = firstRegexCapture(
            in: line,
            pattern: #"([0-9]+(?:[\.,][0-9]+)?)\s*(?:кг|kg)\b"#
        ),
        let repsText = firstRegexCapture(
            in: line,
            pattern: #"([0-9]+)\s*(?:повтор(?:ение|ения|ений|а|ов)?|повт\.?|раз(?:а)?|reps?|repetitions?)\b"#
        ),
        let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")),
        let reps = Int(repsText) else { continue }

        let count = firstRegexCapture(
            in: line,
            pattern: #"([0-9]+)\s*(?:подход(?:а|ов)?|сет(?:а|ов)?|sets?)\b"#
        ).flatMap(Int.init) ?? 1
        let prescription = ExplicitSetPrescription(weight: weight, reps: reps)
        result[prescription, default: 0] += min(max(count, 1), 12)
    }
    return result
}

private func firstRegexCapture(in value: String, pattern: String) -> String? {
    guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
        return nil
    }
    let range = NSRange(value.startIndex..., in: value)
    guard let match = expression.firstMatch(in: value, range: range),
          match.numberOfRanges > 1,
          let captureRange = Range(match.range(at: 1), in: value) else {
        return nil
    }
    return String(value[captureRange])
}

private func normalizedIntentWords(_ value: String) -> Set<String> {
    let normalized = value
        .lowercased()
        .folding(options: .diacriticInsensitive, locale: .current)
    return Set(normalized.split { $0.isLetter == false }.map(String.init))
}

private func intentMentionsExercise(_ commandWords: Set<String>, name: String) -> Bool {
    let nameWords = normalizedIntentWords(name).filter { word in
        word.count > 2 && ["with", "and", "the", "для", "или"].contains(word) == false
    }
    guard nameWords.isEmpty == false else { return false }
    let matchedCount = nameWords.filter { nameWord in
        commandWords.contains { commandWord in
            let prefixLength = min(5, min(nameWord.count, commandWord.count))
            guard prefixLength >= 3 else { return false }
            return nameWord.prefix(prefixLength) == commandWord.prefix(prefixLength)
        }
    }.count
    return matchedCount >= min(2, nameWords.count)
}

private extension Array where Element == WorkoutExerciseTemplate {
    func bestMatch(
        for exerciseName: String,
        alternateLanguageCatalogs: [[WorkoutExerciseTemplate]]
    ) -> WorkoutExerciseTemplate? {
        let matches = bestScoringMatches(
            for: exerciseName,
            alternateLanguageCatalogs: alternateLanguageCatalogs
        )
        return matches.count == 1 ? matches[0] : nil
    }

    func bestScoringMatches(
        for exerciseName: String,
        alternateLanguageCatalogs: [[WorkoutExerciseTemplate]],
        relatedTo referenceTemplates: [WorkoutExerciseTemplate] = []
    ) -> [WorkoutExerciseTemplate] {
        let requested = normalizedExerciseName(exerciseName)
        guard requested.isEmpty == false else { return [] }
        let requestedTokens = Set(requested.split(separator: " ").map(String.init))

        let matches = indices.compactMap { index -> (template: WorkoutExerciseTemplate, score: Int)? in
            if referenceTemplates.isEmpty == false,
               isRelatedExercise(
                at: index,
                to: referenceTemplates,
                alternateLanguageCatalogs: alternateLanguageCatalogs
               ) == false {
                return nil
            }
            let localizedNames = [self[index].name] + alternateLanguageCatalogs.compactMap { catalog in
                catalog.indices.contains(index) ? catalog[index].name : nil
            } + exerciseMatchingAliases(for: self[index].localizationKey)
            let score = localizedNames
                .map { exerciseMatchScore($0, requested: requested, requestedTokens: requestedTokens) }
                .max() ?? 0
            return score >= 100 ? (self[index], score) : nil
        }

        guard let bestScore = matches.map(\.score).max() else { return [] }
        return matches
            .filter { $0.score == bestScore }
            .map(\.template)
    }

    func isRelatedExercise(
        at index: Index,
        to referenceTemplates: [WorkoutExerciseTemplate],
        alternateLanguageCatalogs: [[WorkoutExerciseTemplate]]
    ) -> Bool {
        let candidateNames = ([self[index].name] + alternateLanguageCatalogs.compactMap { catalog in
            catalog.indices.contains(index) ? catalog[index].name : nil
        } + exerciseMatchingAliases(for: self[index].localizationKey)).map(normalizedExerciseName)

        return referenceTemplates.contains { reference in
            guard let referenceIndex = firstIndex(where: { $0.id == reference.id }) else { return false }
            let referenceNames = ([self[referenceIndex].name] + alternateLanguageCatalogs.compactMap { catalog in
                catalog.indices.contains(referenceIndex) ? catalog[referenceIndex].name : nil
            } + exerciseMatchingAliases(for: self[referenceIndex].localizationKey)).map(normalizedExerciseName)

            return candidateNames.contains { candidateName in
                referenceNames.contains { referenceName in
                    let shorterTokenCount = Swift.min(
                        candidateName.split(separator: " ").count,
                        referenceName.split(separator: " ").count
                    )
                    return shorterTokenCount >= 2
                        && (candidateName.contains(referenceName) || referenceName.contains(candidateName))
                }
            }
        }
    }
}

private func exerciseMatchingAliases(for localizationKey: String?) -> [String] {
    switch localizationKey {
    case "workout.exercise.assault_bike":
        return [
            "assault bike",
            "assaultbike",
            "air bike",
            "аэробайк",
            "эйрбайк",
            "воздушный велосипед"
        ]
    case "workout.exercise.banded_lateral_walk":
        return [
            "banded lateral walk",
            "band lateral walk",
            "lateral band walk",
            "side band walk",
            "side steps with band",
            "monster walk",
            "боковая ходьба с резинкой",
            "боковая ходьба с резинкой",
            "ходьба боком с резинкой",
            "шаги в сторону с резинкой",
            "боковые шаги с резинкой",
            "монстр walk"
        ]
    case "workout.exercise.bird_dog":
        return [
            "bird dog",
            "bird-dog",
            "берд дог",
            "птица собака"
        ]
    case "workout.exercise.devil_press":
        return [
            "devil press",
            "devil's press",
            "девил пресс",
            "дьявольский жим",
            "берпи с гантелями"
        ]
    case "workout.exercise.jumping_jack":
        return [
            "jumping jack",
            "jumping jacks",
            "прыжки джек",
            "прыжок джек",
            "джампинг джек",
            "прыжки звездочка",
            "звездочка"
        ]
    case "workout.exercise.muscle_snatch":
        return [
            "muscle snatch",
            "масл снэч",
            "мышечный рывок",
            "протяжка рывковым хватом",
            "рывковая протяжка"
        ]
    case "workout.exercise.single_leg_deadlift":
        return [
            "single leg deadlift",
            "single-leg deadlift",
            "one leg deadlift",
            "one-leg deadlift",
            "single leg rdl",
            "single-leg rdl",
            "single leg romanian deadlift",
            "становая тяга одной ногой",
            "становая тяга одной ногой",
            "становая на одной ноге",
            "тяга одной ногой",
            "тяга на одной ноге",
            "румынская тяга одной ногой"
        ]
    case "workout.exercise.ski_erg":
        return [
            "skierg",
            "ski erg",
            "ски эрг",
            "лыжный тренажер",
            "лыжный эргометр"
        ]
    case "workout.exercise.stair_master":
        return [
            "stairmaster",
            "stair master",
            "стейрмастер",
            "лестничный тренажер",
            "степпер"
        ]
    default:
        return []
    }
}

private func exerciseMatchScore(
    _ candidateName: String,
    requested: String,
    requestedTokens: Set<String>
) -> Int {
    let candidate = normalizedExerciseName(candidateName)
    if candidate == requested {
        return 10_000
    }

    let candidateTokens = Set(candidate.split(separator: " ").map(String.init))
    let commonTokens = requestedTokens.intersection(candidateTokens)
        .filter { $0.count > 2 }
    return commonTokens.count * 100
        + (candidate.contains(requested) || requested.contains(candidate) ? 40 : 0)
}

private func normalizedExerciseName(_ value: String) -> String {
    let lowercased = value.lowercased().folding(options: .diacriticInsensitive, locale: .current)
    let cleaned = lowercased.unicodeScalars.map { scalar -> Character in
        CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : " "
    }
    return String(cleaned)
        .split(whereSeparator: { $0.isWhitespace })
        .filter { token in
            ["со", "с", "на", "для", "по", "и", "кг", "kg"].contains(String(token)) == false
        }
        .joined(separator: " ")
}

private struct AIWorkoutDraftRequest: Encodable {
    let command: String
    let language: String
}

private struct AIWorkoutDraftErrorResponse: Decodable {
    struct APIError: Decodable {
        let code: String
    }

    let error: APIError
}

private struct AIWorkoutModelResponse: Decodable {
    let kind: String
    let summary: String
    let question: String
    let options: [String]
    let blocks: [AIWorkoutDraftBlock]

    var decision: AIWorkoutGenerationDecision? {
        switch kind {
        case "clarification":
            let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
            let usableOptions = Array(options
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }
                .prefix(4))
            guard trimmedQuestion.isEmpty == false, usableOptions.count >= 2 else { return nil }
            return .clarification(AIWorkoutClarification(question: trimmedQuestion, options: usableOptions))
        case "draft":
            guard blocks.isEmpty == false,
                  blocks.allSatisfy({ $0.exercises.isEmpty == false }) else { return nil }
            return .draft(AIWorkoutDraft(summary: summary, blocks: blocks))
        default:
            return nil
        }
    }
}

enum AIWorkoutDraftGeneratorError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return AppLocalizer.string("trainer.ai.error.missing_api_key")
        case .invalidResponse:
            return AppLocalizer.string("trainer.ai.error.invalid_response")
        case .requestFailed(let code):
            switch code {
            case "trainer_role_required":
                return AppLocalizer.string("trainer.ai.error.role_required")
            case "invalid_command":
                return AppLocalizer.string("trainer.ai.error.invalid_command")
            case "empty_workout_draft":
                return AppLocalizer.string("trainer.ai.error.empty_draft")
            case "missing_openai_key":
                return AppLocalizer.string("trainer.ai.error.server_not_configured")
            default:
                return AppLocalizer.string("trainer.ai.error.generic")
            }
        }
    }
}

actor AIWorkoutDraftGenerator {
    private let endpoint = URL(string: "https://api.openai.com/v1/responses")!
    private let model = "gpt-4.1-mini"

    func generate(
        command: String,
        language: AppLanguage,
        existingBlocks: [AIWorkoutExistingBlock]
    ) async throws -> AIWorkoutGenerationDecision {
        guard let apiKey = AIWorkoutOpenAIConfiguration.apiKey else {
            throw AIWorkoutDraftGeneratorError.missingAPIKey
        }
        let languageName = language == .english ? "English" : "Russian"
        let existingBlocksJSON = String(
            data: try JSONEncoder().encode(existingBlocks),
            encoding: .utf8
        ) ?? "[]"

        let userPrompt = "Trainer instruction: \(command)\nCurrent template blocks: \(existingBlocksJSON)"
        let outputText = try await requestOutput(
            apiKey: apiKey,
            systemPrompt: systemPrompt(language: languageName),
            userPrompt: userPrompt
        )

        if let decision = Self.decodeDecision(from: outputText) {
            return decision.applyingIntent(from: command, existingBlocks: existingBlocks)
        }

        let repairedOutputText = try await requestOutput(
            apiKey: apiKey,
            systemPrompt: repairSystemPrompt(language: languageName),
            userPrompt: "Original trainer instruction:\n\(command)\n\nCurrent template blocks:\n\(existingBlocksJSON)\n\nInvalid draft to repair:\n\(outputText)"
        )
        guard let repairedDecision = Self.decodeDecision(from: repairedOutputText) else {
            throw AIWorkoutDraftGeneratorError.invalidResponse
        }
        return repairedDecision.applyingIntent(from: command, existingBlocks: existingBlocks)
    }

    func generateModifiedLibraryCopy(
        command: String,
        language: AppLanguage,
        templates: [AIWorkoutLibraryTemplateSnapshot]
    ) async throws -> AIWorkoutGenerationDecision {
        let promptTemplates = templates.map { snapshot in
            AIWorkoutLibraryPromptTemplate(
                title: snapshot.template.title,
                blocks: snapshot.blocks.sorted(by: { $0.orderIndex < $1.orderIndex }).map { block in
                    AIWorkoutLibraryPromptBlock(
                        title: block.displayTitle,
                        type: block.typeRawValue,
                        preset: block.presetRawValue,
                        mode: block.modeRawValue,
                        rounds: block.rounds,
                        durationMinutes: block.durationMinutes,
                        workSeconds: block.workSeconds,
                        restSeconds: block.restSeconds,
                        restBetweenRoundsSeconds: block.restBetweenRoundsSeconds,
                        exercises: snapshot.exercises
                            .filter { $0.blockId == block.id }
                            .sorted(by: { $0.orderIndex < $1.orderIndex })
                            .map { exercise in
                                AIWorkoutLibraryPromptExercise(
                                    name: exercise.name,
                                    systemImage: exercise.systemImage,
                                    accentName: exercise.accentName,
                                    activityType: exercise.activityTypeRaw,
                                    metValue: exercise.metValue,
                                    note: exercise.note,
                                    sets: exercise.sets.aiExistingSets
                                )
                            }
                    )
                }
            )
        }
        let templatesJSON = String(
            data: try JSONEncoder().encode(promptTemplates),
            encoding: .utf8
        ) ?? "[]"
        let modification = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let copyCommand = """
        Create a NEW editable copy of the FitLife library template JSON below and apply only the requested changes.
        Return the COMPLETE resulting copy, including every unchanged block, exercise and set.
        Every returned block is new: targetBlockId and insertAfterBlockId must be null.
        Every returned exercise uses operation "add" and targetExerciseId null.
        Preserve values that the trainer did not ask to change.
        If the trainer asks only to make the template X percent harder, increase repetitions and timed durations by X percent, rounded to the nearest whole number; keep weights, rounds and rest unchanged.
        For a superset or round-based circuit, an unqualified rest value means restBetweenRoundsSeconds.
        When rounds are increased for a superset or circuit, output one set object per round for every exercise.

        Requested changes: \(modification)
        FitLife base templates: \(templatesJSON)
        """
        return try await generate(
            command: copyCommand,
            language: language,
            existingBlocks: []
        )
    }

    private func requestOutput(
        apiKey: String,
        systemPrompt: String,
        userPrompt: String
    ) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "input": [
                [
                    "role": "system",
                    "content": [[
                        "type": "input_text",
                        "text": systemPrompt
                    ]]
                ],
                [
                    "role": "user",
                    "content": [[
                        "type": "input_text",
                        "text": userPrompt
                    ]]
                ]
            ],
            // A single exercise can contain many individually represented sets,
            // so leave enough room for a complete JSON document on the first try.
            "max_output_tokens": 4_000,
            // Structured Outputs keeps the first response compatible with the
            // app's Codable models instead of relying on the model to remember
            // every technical field in a prompt.
            "text": ["format": Self.workoutDraftResponseFormat()]
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIWorkoutDraftGeneratorError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let code = Self.apiErrorCode(from: data)
            throw AIWorkoutDraftGeneratorError.requestFailed(code ?? "unknown")
        }

        guard let outputText = Self.outputText(from: data) else {
            throw AIWorkoutDraftGeneratorError.invalidResponse
        }
        return outputText
    }

    private static func workoutDraftResponseFormat() -> [String: Any] {
        let setSchema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": [
                "weight", "reps", "durationSeconds", "metricType", "method",
                "methodGroup", "stepIndex", "restAfterSeconds", "pyramidPattern"
            ],
            "properties": [
                "weight": ["type": "number"],
                "reps": ["type": "integer", "minimum": 0, "maximum": 500],
                "durationSeconds": ["type": "integer", "minimum": 0, "maximum": 7_200],
                "metricType": ["type": "string", "enum": ["reps", "duration"]],
                "method": ["type": "string", "enum": ["normal", "dropSet", "pyramid", "cluster"]],
                "methodGroup": ["type": "integer", "minimum": 0, "maximum": 100],
                "stepIndex": ["type": "integer", "minimum": 0, "maximum": 100],
                "restAfterSeconds": ["type": "integer", "minimum": 0, "maximum": 7_200],
                "pyramidPattern": ["type": "string", "enum": ["ascending", "descending", "full", "custom"]]
            ]
        ]

        let exerciseSchema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": ["operation", "targetExerciseId", "name", "systemImage", "accentName", "activityType", "metValue", "note", "sets"],
            "properties": [
                "operation": ["type": "string", "enum": ["add", "update", "delete"]],
                "targetExerciseId": ["type": ["string", "null"]],
                "name": ["type": "string"],
                "systemImage": ["type": "string"],
                "accentName": ["type": "string", "enum": ["blue", "green", "orange", "purple", "teal", "red"]],
                "activityType": ["type": "string", "enum": ["strength", "cardio", "hiit", "core", "mobility"]],
                "metValue": ["type": "number", "minimum": 0],
                "note": ["type": "string"],
                "sets": ["type": "array", "minItems": 1, "maxItems": 12, "items": setSchema]
            ]
        ]

        let blockSchema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": [
                "title", "targetBlockId", "insertAfterBlockId", "updatesBlockSettings", "preset", "type", "mode", "rounds", "durationMinutes",
                "workSeconds", "restSeconds", "restBetweenRoundsSeconds", "exercises"
            ],
            "properties": [
                "title": ["type": "string"],
                "targetBlockId": ["type": ["string", "null"]],
                "insertAfterBlockId": ["type": ["string", "null"]],
                "updatesBlockSettings": ["type": "boolean"],
                "preset": [
                    "type": "string",
                    "enum": WorkoutBlockPreset.allCases.map(\.rawValue)
                ],
                "type": ["type": "string", "enum": ["warmup", "strength", "main", "superset", "circuit", "stretching", "cooldown"]],
                "mode": ["type": "string", "enum": ["rounds", "amrap", "tabata", "emom"]],
                "rounds": ["type": "integer", "minimum": 0, "maximum": 100],
                "durationMinutes": ["type": "integer", "minimum": 0, "maximum": 300],
                "workSeconds": ["type": "integer", "minimum": 0, "maximum": 7_200],
                "restSeconds": ["type": "integer", "minimum": 0, "maximum": 7_200],
                "restBetweenRoundsSeconds": ["type": "integer", "minimum": 0, "maximum": 7_200],
                "exercises": ["type": "array", "minItems": 1, "maxItems": 20, "items": exerciseSchema]
            ]
        ]

        return [
            "type": "json_schema",
            "name": "workout_draft",
            "strict": true,
            "schema": [
                "type": "object",
                "additionalProperties": false,
                "required": ["kind", "summary", "question", "options", "blocks"],
                "properties": [
                    "kind": ["type": "string", "enum": ["draft", "clarification"]],
                    "summary": ["type": "string"],
                    "question": ["type": "string"],
                    "options": [
                        "type": "array",
                        "maxItems": 4,
                        "items": ["type": "string"]
                    ],
                    "blocks": ["type": "array", "maxItems": 5, "items": blockSchema]
                ]
            ]
        ]
    }

    private func systemPrompt(language: String) -> String {
        """
        You are a fitness-programming assistant for certified trainers. Convert the trainer's instruction into a conservative workout TEMPLATE DRAFT, or ask one concise clarification when making a safe, exact draft is genuinely impossible. Return JSON only and respond in \(language). The trainer may write in any language. Regardless of the input language, translate every human-readable output field into \(language), including summary, question, options, block titles, exercise names, and notes. Never copy an exercise name from the input in another language when a \(language) name exists.
        Always return kind, summary, question, options, and blocks. For a completed draft use kind "draft", question "", options [], and non-empty blocks. For a clarification use kind "clarification", summary "", one concise question, 2 to 4 short mutually exclusive options, and blocks []. Ask only one question at a time. Clarify when multiple existing exercises or blocks match an edit, when the target/location of a destructive action is ambiguous, or when safety-critical information such as the location of pain is missing. Do not clarify harmless defaults that can be reviewed in a draft. Do not repeat a question already answered in the trainer instruction. Never guess an existing target id; ask if no exact target can be identified.
        Each draft block has title, targetBlockId (a current template block id or null), insertAfterBlockId (a current template block id or null), updatesBlockSettings, preset (warmup|strength|superset|circuit|hiit|tabata|amrap|emom|e2mom|e3mom|forTime|rft|pyramid|dropSet|clusterSet|ladder|mobility|stretching|cooldown), type (warmup|strength|main|superset|circuit|stretching|cooldown), mode (rounds|amrap|tabata|emom), rounds, durationMinutes, workSeconds, restSeconds, restBetweenRoundsSeconds, and exercises. preset is the source of truth; type and mode must match that preset. Each exercise has operation (add|update|delete), targetExerciseId (an existing exercise id or null), name, systemImage, accentName (blue|green|orange|purple|teal|red), activityType (strength|cardio|hiit|core|mobility), metValue, note, and sets. Each set has weight, reps, durationSeconds, metricType (reps|duration), method (normal|dropSet|pyramid|cluster), methodGroup, stepIndex, restAfterSeconds, and pyramidPattern (ascending|descending|full|custom).
        Rules: current template blocks and their exercises are provided in their current order in the user message. Use operation add with targetExerciseId null for a new exercise. To REPLACE an exercise, use operation update and its exact targetExerciseId; the output name and fields describe the replacement. To DELETE an exercise, use operation delete and its exact targetExerciseId. A delete operation is never an add. When the trainer says to add or append sets, a pyramid, a drop set, or another set sequence to an exercise, NEVER create a second copy of that exercise. If it is a new exercise in this draft, return one add operation whose sets contain the initial and appended sets in the requested order. If it is an existing exercise, return one update operation with its exact targetExerciseId and the COMPLETE set list: preserved existing sets followed by the appended sets. Preserve the existing sets for a replacement unless the trainer explicitly supplied a new prescription. Set updatesBlockSettings false for exercise-only additions, replacements, or deletions, so existing rounds/timers/rest remain unchanged; set it true only when the trainer explicitly changes block settings. If the trainer asks to EDIT or ADD EXERCISES TO an existing block by name, set targetBlockId to that exact id and set insertAfterBlockId to null. If the trainer says NEW, ANOTHER, or SEPARATE block, targetBlockId MUST be null even when its title/type matches an existing block. When that new block must appear after an existing block, set insertAfterBlockId to the existing block's exact id. A new block named "Суперсет" must never be merged into an existing block merely because both titles are "Суперсет". If no section or workout format is explicitly requested, return EXACTLY ONE block: title "Силовой блок" in Russian or "Strength block" in English, type "strength", and put every requested exercise in it. Never make a block from an exercise name; "bench press" must be an exercise inside the strength block, not a block named "bench press". Create multiple blocks only when the instruction explicitly asks for warmup, cooldown, a circuit/AMRAP/Tabata, or named separate sections. Create only what the trainer asked; do not provide medical advice; never guess a working weight — use 0 when it is not supplied.
        For a relative request such as "make it 20% harder" with no metric specified, increase repetitions and timed durations by that percentage, rounded to the nearest whole number. Keep weights, rounds and rest unchanged unless the trainer explicitly changes them. The preview is the source of truth and must show every resulting value.
        For a superset or round-based circuit, an unqualified rest value means restBetweenRoundsSeconds; restSeconds is only the short rest between work intervals when explicitly requested.
        Set-method rules: ordinary sets use method "normal", methodGroup 0, stepIndex 0, restAfterSeconds 0, and pyramidPattern "ascending". Consecutive steps explicitly identified as one drop set, pyramid, or cluster use method "dropSet", "pyramid", or "cluster" and share the same positive methodGroup; number their stepIndex from 0 in order. Use a different positive methodGroup for every separate special sequence. Mark only the sets the trainer identified as the special sequence: earlier warm-up or working sets remain normal. A descending-weight pyramid uses pyramidPattern "descending"; an ascending one uses "ascending"; an up-and-down one uses "full"; otherwise use "custom". A requested set method does not change the enclosing strength block preset.
        rounds means how many times the complete block sequence is performed. sets are the source of truth for exercise history and reports: output one sets array item for EVERY prescribed set. For superset, circuit, rft, pyramid, dropSet, clusterSet, and ladder, every exercise must have at least one set object per round/stage; repeat identical objects when prescriptions are identical. Thus a superset for 3 sets has rounds=3 and three set objects for each exercise. A circular warmup for 2 rounds is preset circuit, type circuit, mode rounds, rounds=2, and two set objects per exercise. A normal strength exercise for 3 sets remains preset strength, rounds=1, and has three set objects. Never put a prescription for sets, reps, weight, duration, or rest only into note. For example, "5 sets of 5 reps at 70 kg" must return five set objects, each {weight: 70, reps: 5, durationSeconds: 0, metricType: "reps"}; "2 sets of 15 at 20 kg, then 4 sets of 15 at 40 kg" must return six set objects in that exact order. "10x10" means 10 set objects of 10 reps. Use note only for coaching cues or explanations. Use duration only for timed exercises; use valid values; no more than 5 blocks, 20 exercises, or 12 sets per exercise; no markdown.
        """
    }

    private func repairSystemPrompt(language: String) -> String {
        """
        You repair workout-template assistant JSON for certified trainers. Return JSON only and respond in \(language). The original instruction may use any language. Translate every human-readable output field into \(language), including summary, question, options, block titles, exercise names, and notes. Never copy an exercise name from the input in another language when a \(language) name exists. Rebuild the response from the original trainer instruction, correcting the invalid response if useful. A relative request such as "make it 20% harder" increases repetitions and timed durations by that percentage, rounded to the nearest whole number, while weights, rounds and rest stay unchanged unless explicitly changed. Use exactly this schema: {kind:"draft"|"clarification",summary:String,question:String,options:[String],blocks:[{title:String,targetBlockId:String|null,insertAfterBlockId:String|null,updatesBlockSettings:Bool,preset:String,type:String,mode:String,rounds:Int,durationMinutes:Int,workSeconds:Int,restSeconds:Int,restBetweenRoundsSeconds:Int,exercises:[{operation:String,targetExerciseId:String|null,name:String,systemImage:String,accentName:String,activityType:String,metValue:Double,note:String,sets:[{weight:Double,reps:Int,durationSeconds:Int,metricType:String,method:String,methodGroup:Int,stepIndex:Int,restAfterSeconds:Int,pyramidPattern:String}]}]}]}. A draft uses question "", options [], and non-empty blocks. A clarification uses summary "", one concise question, 2 to 4 short mutually exclusive options, and blocks []. Ask only if an exact target is genuinely ambiguous or safety-critical information is missing; do not repeat an answered question. Every draft block must contain at least one exercise operation. Use add/null for new exercises, update/exact-id for replacements, and delete/exact-id for deletions. When adding sets, a pyramid, a drop set, or a cluster to the same exercise, return exactly one exercise operation with the complete ordered set list; never represent appended sets as a duplicate exercise. Exercise-only edits use updatesBlockSettings false. NEW/ANOTHER/SEPARATE blocks always have targetBlockId null; use insertAfterBlockId only to position a new block after an existing one. Use only preset warmup|strength|superset|circuit|hiit|tabata|amrap|emom|e2mom|e3mom|forTime|rft|pyramid|dropSet|clusterSet|ladder|mobility|stretching|cooldown, type warmup|strength|main|superset|circuit|stretching|cooldown, mode rounds|amrap|tabata|emom, operation add|update|delete, accentName blue|green|orange|purple|teal|red, activityType strength|cardio|hiit|core|mobility, metricType reps|duration, method normal|dropSet|pyramid|cluster, pyramidPattern ascending|descending|full|custom. Ordinary sets use method normal and methodGroup 0. Each explicitly requested special sequence shares a positive methodGroup and has stepIndex numbered from 0; only those sets receive the special method. Preserve every prescribed set as individual objects. For superset, circuit, rft, pyramid, dropSet, clusterSet, and ladder, every non-delete exercise needs at least one set object per round/stage. Never add markdown or explanation.
        """
    }

    private static func decodeDecision(from outputText: String) -> AIWorkoutGenerationDecision? {
        guard let outputData = outputText.data(using: .utf8),
              let response = try? JSONDecoder().decode(AIWorkoutModelResponse.self, from: outputData) else {
            return nil
        }
        return response.decision
    }

    private static func outputText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let outputText = json["output_text"] as? String, outputText.isEmpty == false {
            return outputText
        }
        let output = json["output"] as? [[String: Any]] ?? []
        for item in output {
            for content in item["content"] as? [[String: Any]] ?? [] {
                if let text = content["text"] as? String, text.isEmpty == false {
                    return text
                }
            }
        }
        return nil
    }

    private static func apiErrorCode(from data: Data) -> String? {
        guard let decoded = try? JSONDecoder().decode(AIWorkoutDraftErrorResponse.self, from: data) else {
            return nil
        }
        return decoded.error.code
    }
}

private extension AIWorkoutGenerationDecision {
    func applyingIntent(
        from command: String,
        existingBlocks: [AIWorkoutExistingBlock]
    ) -> AIWorkoutGenerationDecision {
        switch self {
        case .draft(let draft):
            return .draft(
                draft
                    .applyingPlacementIntent(from: command)
                    .applyingSetAppendIntent(from: command)
                    .enforcingAddOnlyIntent(from: command, existingBlocks: existingBlocks)
                    .applyingExplicitSetCounts(from: command)
            )
        case .clarification:
            return self
        }
    }
}

private enum AIWorkoutOpenAIConfiguration {
    static var apiKey: String? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String else {
            return nil
        }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.contains("$(") ? nil : trimmed
    }
}

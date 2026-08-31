import Foundation
import FirebaseFirestore

struct AIWorkoutLibraryTemplateSnapshot: Identifiable {
    let template: LibraryWorkoutTemplate
    let blocks: [WorkoutTemplateBlockItem]
    let exercises: [WorkoutTemplateExerciseItem]

    var id: String { template.id }
}

struct AIWorkoutGenerationResult {
    let draft: AIWorkoutDraft
    let libraryTemplates: [AIWorkoutLibraryTemplateSnapshot]
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
                let titleKey = normalizedLibraryText($0.title)
                return titleKey.isEmpty == false
                    && " \(commandKey) ".contains(" \(titleKey) ")
            }
            .sorted { normalizedLibraryText($0.title).count > normalizedLibraryText($1.title).count }

        // Prefer the most specific name: "Разминка 1" must not also resolve a
        // shorter library item named simply "Разминка".
        var matchedTemplates: [LibraryWorkoutTemplate] = []
        for candidate in candidates {
            let candidateKey = normalizedLibraryText(candidate.title)
            guard matchedTemplates.contains(where: {
                normalizedLibraryText($0.title).contains(candidateKey)
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
            while let range = remainingCommand.range(
                of: template.title,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) {
                remainingCommand.removeSubrange(range)
            }
        }
        remainingCommand = remainingCommand
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))

        return AIWorkoutLibraryResolution(templates: resolved, remainingCommand: remainingCommand)
    }
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
    let orderIndex: Int
}

struct AIWorkoutDraftExercise: Decodable, Identifiable {
    let name: String
    let systemImage: String
    let accentName: String
    let activityType: String
    let metValue: Double
    let note: String
    let sets: [AIWorkoutDraftSet]

    var id: String { name }

    var workoutActivityType: WorkoutActivityType {
        WorkoutActivityType(rawValue: activityType) ?? .strength
    }
}

struct AIWorkoutDraftSet: Decodable {
    let weight: Double
    let reps: Int
    let durationSeconds: Int
    let metricType: String

    var workoutSet: WorkoutDraftSet {
        WorkoutDraftSet(
            weight: weight,
            reps: reps,
            durationSeconds: durationSeconds,
            metricType: WorkoutSetMetricType(rawValue: metricType) ?? .reps
        )
    }
}

extension AIWorkoutDraft {
    func resolvingExercises(using catalog: [WorkoutExerciseTemplate]) -> AIWorkoutDraft {
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
                        if let template = catalog.bestMatch(for: exercise.name) {
                            resolvedExercise = AIWorkoutDraftExercise(
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
}

private extension Array where Element == WorkoutExerciseTemplate {
    func bestMatch(for exerciseName: String) -> WorkoutExerciseTemplate? {
        let requested = normalizedExerciseName(exerciseName)
        guard requested.isEmpty == false else { return nil }
        let requestedTokens = Set(requested.split(separator: " ").map(String.init))

        let matches = compactMap { template -> (template: WorkoutExerciseTemplate, score: Int)? in
            let candidate = normalizedExerciseName(template.name)
            if candidate == requested {
                return (template, 10_000)
            }

            let candidateTokens = Set(candidate.split(separator: " ").map(String.init))
            let commonTokens = requestedTokens.intersection(candidateTokens)
                .filter { $0.count > 2 }
            let score = commonTokens.count * 100
                + (candidate.contains(requested) || requested.contains(candidate) ? 40 : 0)
            return score >= 100 ? (template, score) : nil
        }

        return matches.max { $0.score < $1.score }?.template
    }
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

enum AIWorkoutDraftGeneratorError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key не настроен в приложении."
        case .invalidResponse:
            return "Не удалось прочитать черновик тренировки. Попробуйте ещё раз."
        case .requestFailed(let code):
            switch code {
            case "trainer_role_required":
                return "Создавать тренировку с ИИ может только активный тренер."
            case "invalid_command":
                return "Опишите тренировку немного подробнее."
            case "empty_workout_draft":
                return "ИИ не нашёл упражнений в запросе. Попробуйте сформулировать иначе."
            case "missing_openai_key":
                return "ИИ ещё не настроен на сервере."
            default:
                return "Не удалось создать черновик. Попробуйте ещё раз."
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
    ) async throws -> AIWorkoutDraft {
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

        if let draft = Self.decodeDraft(from: outputText) {
            return draft.applyingPlacementIntent(from: command)
        }

        let repairedOutputText = try await requestOutput(
            apiKey: apiKey,
            systemPrompt: repairSystemPrompt(language: languageName),
            userPrompt: "Original trainer instruction:\n\(command)\n\nCurrent template blocks:\n\(existingBlocksJSON)\n\nInvalid draft to repair:\n\(outputText)"
        )
        guard let repairedDraft = Self.decodeDraft(from: repairedOutputText) else {
            throw AIWorkoutDraftGeneratorError.invalidResponse
        }
        return repairedDraft.applyingPlacementIntent(from: command)
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
            "required": ["weight", "reps", "durationSeconds", "metricType"],
            "properties": [
                "weight": ["type": "number"],
                "reps": ["type": "integer", "minimum": 0, "maximum": 500],
                "durationSeconds": ["type": "integer", "minimum": 0, "maximum": 7_200],
                "metricType": ["type": "string", "enum": ["reps", "duration"]]
            ]
        ]

        let exerciseSchema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": ["name", "systemImage", "accentName", "activityType", "metValue", "note", "sets"],
            "properties": [
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
                "title", "targetBlockId", "insertAfterBlockId", "preset", "type", "mode", "rounds", "durationMinutes",
                "workSeconds", "restSeconds", "restBetweenRoundsSeconds", "exercises"
            ],
            "properties": [
                "title": ["type": "string"],
                "targetBlockId": ["type": ["string", "null"]],
                "insertAfterBlockId": ["type": ["string", "null"]],
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
                "required": ["summary", "blocks"],
                "properties": [
                    "summary": ["type": "string"],
                    "blocks": ["type": "array", "minItems": 1, "maxItems": 5, "items": blockSchema]
                ]
            ]
        ]
    }

    private func systemPrompt(language: String) -> String {
        """
        You are a fitness-programming assistant for certified trainers. Convert the trainer's instruction into a conservative workout TEMPLATE DRAFT. Return JSON only and respond in \(language).
        Return an object with a short string field summary and a blocks array. Each block has title, targetBlockId (a current template block id or null), insertAfterBlockId (a current template block id or null), preset (warmup|strength|superset|circuit|hiit|tabata|amrap|emom|e2mom|e3mom|forTime|rft|pyramid|dropSet|clusterSet|ladder|mobility|stretching|cooldown), type (warmup|strength|main|superset|circuit|stretching|cooldown), mode (rounds|amrap|tabata|emom), rounds, durationMinutes, workSeconds, restSeconds, restBetweenRoundsSeconds, and exercises. preset is the source of truth; type and mode must match that preset. Each exercise has name, systemImage, accentName (blue|green|orange|purple|teal|red), activityType (strength|cardio|hiit|core|mobility), metValue, note, and sets. Each set has weight, reps, durationSeconds, metricType (reps|duration).
        Rules: current template blocks are provided in their current order in the user message. If the trainer asks to EDIT or ADD EXERCISES TO an existing block by name, set targetBlockId to that exact id and set insertAfterBlockId to null. If the trainer says NEW, ANOTHER, or SEPARATE block, targetBlockId MUST be null even when its title/type matches an existing block. When that new block must appear after an existing block, set insertAfterBlockId to the existing block's exact id. A new block named "Суперсет" must never be merged into an existing block merely because both titles are "Суперсет". If no section or workout format is explicitly requested, return EXACTLY ONE block: title "Силовой блок" in Russian or "Strength block" in English, type "strength", and put every requested exercise in it. Never make a block from an exercise name; "bench press" must be an exercise inside the strength block, not a block named "bench press". Create multiple blocks only when the instruction explicitly asks for warmup, cooldown, a circuit/AMRAP/Tabata, or named separate sections. Create only what the trainer asked; do not provide medical advice; never guess a working weight — use 0 when it is not supplied.
        rounds means how many times the complete block sequence is performed. sets are the source of truth for exercise history and reports: output one sets array item for EVERY prescribed set. For superset, circuit, rft, pyramid, dropSet, clusterSet, and ladder, every exercise must have at least one set object per round/stage; repeat identical objects when prescriptions are identical. Thus a superset for 3 sets has rounds=3 and three set objects for each exercise. A circular warmup for 2 rounds is preset circuit, type circuit, mode rounds, rounds=2, and two set objects per exercise. A normal strength exercise for 3 sets remains preset strength, rounds=1, and has three set objects. Never put a prescription for sets, reps, weight, duration, or rest only into note. For example, "5 sets of 5 reps at 70 kg" must return five set objects, each {weight: 70, reps: 5, durationSeconds: 0, metricType: "reps"}; "2 sets of 15 at 20 kg, then 4 sets of 15 at 40 kg" must return six set objects in that exact order. "10x10" means 10 set objects of 10 reps. Use note only for coaching cues or explanations. Use duration only for timed exercises; use valid values; no more than 5 blocks, 20 exercises, or 12 sets per exercise; no markdown.
        """
    }

    private func repairSystemPrompt(language: String) -> String {
        """
        You repair workout-template draft JSON for certified trainers. Return JSON only and respond in \(language). Rebuild the draft from the original trainer instruction, correcting the invalid draft if useful. Use exactly this schema: {summary:String, blocks:[{title:String,targetBlockId:String|null,insertAfterBlockId:String|null,preset:String,type:String,mode:String,rounds:Int,durationMinutes:Int,workSeconds:Int,restSeconds:Int,restBetweenRoundsSeconds:Int,exercises:[{name:String,systemImage:String,accentName:String,activityType:String,metValue:Double,note:String,sets:[{weight:Double,reps:Int,durationSeconds:Int,metricType:String}]}]}]}. Every block must contain at least one exercise. NEW/ANOTHER/SEPARATE blocks always have targetBlockId null; use insertAfterBlockId only to position a new block after an existing one. Use only preset warmup|strength|superset|circuit|hiit|tabata|amrap|emom|e2mom|e3mom|forTime|rft|pyramid|dropSet|clusterSet|ladder|mobility|stretching|cooldown, type warmup|strength|main|superset|circuit|stretching|cooldown, mode rounds|amrap|tabata|emom, accentName blue|green|orange|purple|teal|red, activityType strength|cardio|hiit|core|mobility, metricType reps|duration. Preserve every prescribed set as individual objects. For superset, circuit, rft, pyramid, dropSet, clusterSet, and ladder, every exercise needs at least one set object per round/stage. Never add markdown or explanation.
        """
    }

    private static func decodeDraft(from outputText: String) -> AIWorkoutDraft? {
        guard let outputData = outputText.data(using: .utf8),
              let draft = try? JSONDecoder().decode(AIWorkoutDraft.self, from: outputData),
              draft.blocks.isEmpty == false,
              draft.blocks.allSatisfy({ $0.exercises.isEmpty == false }) else {
            return nil
        }
        return draft
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

private enum AIWorkoutOpenAIConfiguration {
    static var apiKey: String? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String else {
            return nil
        }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.contains("$(") ? nil : trimmed
    }
}

import Foundation

struct AIWorkoutDraft: Decodable, Identifiable {
    let summary: String
    let blocks: [AIWorkoutDraftBlock]

    var id: String { summary + "-" + String(blocks.count) }
}

struct AIWorkoutDraftBlock: Decodable, Identifiable {
    let title: String
    let targetBlockId: String?
    let type: String
    let mode: String
    let rounds: Int
    let durationMinutes: Int
    let workSeconds: Int
    let restSeconds: Int
    let restBetweenRoundsSeconds: Int
    let exercises: [AIWorkoutDraftExercise]

    var id: String { title + "-" + type }

    var workoutBlockType: WorkoutBlockType {
        WorkoutBlockType(rawValue: type) ?? .main
    }

    var workoutBlockMode: WorkoutBlockMode {
        WorkoutBlockMode(rawValue: mode) ?? .rounds
    }
}

struct AIWorkoutExistingBlock: Encodable {
    let id: String
    let title: String
    let type: String
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
                AIWorkoutDraftBlock(
                    title: block.title,
                    targetBlockId: block.targetBlockId,
                    type: block.type,
                    mode: block.mode,
                    rounds: block.rounds,
                    durationMinutes: block.durationMinutes,
                    workSeconds: block.workSeconds,
                    restSeconds: block.restSeconds,
                    restBetweenRoundsSeconds: block.restBetweenRoundsSeconds,
                    exercises: block.exercises.map { exercise in
                        guard let template = catalog.bestMatch(for: exercise.name) else {
                            return exercise
                        }
                        return AIWorkoutDraftExercise(
                            name: template.name,
                            systemImage: template.systemImage,
                            accentName: template.accentName,
                            activityType: template.activityType.rawValue,
                            metValue: template.metValue,
                            note: exercise.note,
                            sets: exercise.sets
                        )
                    }
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
                        "text": systemPrompt(language: languageName)
                    ]]
                ],
                [
                    "role": "user",
                    "content": [[
                        "type": "input_text",
                        "text": "Trainer instruction: \(command)\nCurrent template blocks: \(existingBlocksJSON)"
                    ]]
                ]
            ],
            "text": ["format": ["type": "json_object"]]
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIWorkoutDraftGeneratorError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let code = Self.apiErrorCode(from: data)
            throw AIWorkoutDraftGeneratorError.requestFailed(code ?? "unknown")
        }

        do {
            guard let outputText = Self.outputText(from: data),
                  let outputData = outputText.data(using: .utf8) else {
                throw AIWorkoutDraftGeneratorError.invalidResponse
            }
            let draft = try JSONDecoder().decode(AIWorkoutDraft.self, from: outputData)
            guard draft.blocks.isEmpty == false,
                  draft.blocks.allSatisfy({ $0.exercises.isEmpty == false }) else {
                throw AIWorkoutDraftGeneratorError.invalidResponse
            }
            return draft
        } catch {
            if let generatorError = error as? AIWorkoutDraftGeneratorError {
                throw generatorError
            }
            throw AIWorkoutDraftGeneratorError.invalidResponse
        }
    }

    private func systemPrompt(language: String) -> String {
        """
        You are a fitness-programming assistant for certified trainers. Convert the trainer's instruction into a conservative workout TEMPLATE DRAFT. Return JSON only and respond in \(language).
        Return an object with a short string field summary and a blocks array. Each block has title, targetBlockId (a current template block id or null), type (warmup|strength|main|circuit|stretching|cooldown), mode (rounds|amrap|tabata), rounds, durationMinutes, workSeconds, restSeconds, restBetweenRoundsSeconds, and exercises. Each exercise has name, systemImage, accentName (blue|green|orange|purple|teal|red), activityType (strength|cardio|hiit|core|mobility), metValue, note, and sets. Each set has weight, reps, durationSeconds, metricType (reps|duration).
        Rules: current template blocks are provided in the user message. If the trainer refers to an existing block by name, set targetBlockId to that exact id and add exercises to it. Only use null when a new block is actually requested. Create only what the trainer asked; do not provide medical advice; never guess a working weight — use 0 when it is not supplied.
        Sets are the source of truth: output one sets array item for EVERY prescribed set. Never put a prescription for sets, reps, weight, duration, or rest only into note. For example, "5 sets of 5 reps at 70 kg" must return five set objects, each {weight: 70, reps: 5, durationSeconds: 0, metricType: "reps"}; "2 sets of 15 at 20 kg, then 4 sets of 15 at 40 kg" must return six set objects in that exact order. "10x10" means 10 set objects of 10 reps. Use note only for coaching cues or explanations. Use duration only for timed exercises; use valid values; no more than 5 blocks, 20 exercises, or 12 sets per exercise; no markdown.
        """
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

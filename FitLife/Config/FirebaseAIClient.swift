import Foundation
import FirebaseAuth
import FirebaseCore

enum FirebaseAIClientError: LocalizedError {
    case notAuthenticated
    case invalidConfiguration
    case invalidResponse
    case requestFailed(code: String, statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return AppLocalizer.currentLanguage == .russian
                ? "Войдите в аккаунт и попробуйте ещё раз."
                : "Sign in and try again."
        case .invalidConfiguration:
            return AppLocalizer.currentLanguage == .russian
                ? "AI-сервис не настроен."
                : "The AI service is not configured."
        case .invalidResponse:
            return AppLocalizer.currentLanguage == .russian
                ? "AI-сервис вернул некорректный ответ."
                : "The AI service returned an invalid response."
        case .requestFailed:
            return AppLocalizer.currentLanguage == .russian
                ? "AI-сервис временно недоступен."
                : "The AI service is temporarily unavailable."
        }
    }
}

enum FirebaseAIClient {
    private struct ErrorEnvelope: Decodable {
        struct ServerError: Decodable {
            let code: String?
        }

        let error: ServerError?
    }

    static func post(
        functionName: String,
        body: [String: Any],
        timeout: TimeInterval = 120
    ) async throws -> Data {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseAIClientError.notAuthenticated
        }
        guard
            let projectId = FirebaseApp.app()?.options.projectID,
            let endpoint = FirebaseEmulatorConfiguration.functionsURL(
                named: functionName,
                projectId: projectId
            )
        else {
            throw FirebaseAIClientError.invalidConfiguration
        }

        let idToken = try await user.getIDToken()
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FirebaseAIClientError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let code = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?
                .error?.code ?? "unknown"
            throw FirebaseAIClientError.requestFailed(
                code: code,
                statusCode: httpResponse.statusCode
            )
        }
        return data
    }
}

import Foundation
import os

/// Translation backend that uses LLM APIs (OpenAI, Gemini, Claude).
///
/// Reads the selected provider, model, and system prompt from `UserPreferences`
/// and the API key from `KeychainVault`.
final class LLMTranslator: TranslationService {
    private let provider: TranslationProvider
    private let model: String
    private let keychainVault: KeychainVault
    private let preferences: UserPreferences
    private let session: URLSession
    private let logger = Logger(subsystem: "com.quicktranslate", category: "LLMTranslator")

    /// Creates a new LLM translator.
    ///
    /// - Parameters:
    ///   - provider: The LLM provider to use (openai, gemini, or claude).
    ///   - model: The model identifier within the provider.
    ///   - keychainVault: Vault configured with the provider's keychain service ID.
    ///   - preferences: User preferences containing the system prompt.
    ///   - session: URL session for network requests. Defaults to `.shared`.
    init(
        provider: TranslationProvider,
        model: String,
        keychainVault: KeychainVault,
        preferences: UserPreferences,
        session: URLSession = .shared
    ) {
        self.provider = provider
        self.model = model
        self.keychainVault = keychainVault
        self.preferences = preferences
        self.session = session
    }

    /// Translates the given request using the configured LLM provider.
    ///
    /// - Parameter request: The translation request.
    /// - Returns: A `TranslationResult` with translated text.
    /// - Throws: A `TranslationError` on failure.
    func translate(_ request: TranslationRequest) async throws -> TranslationResult {
        guard let apiKey = try keychainVault.retrieve() else {
            logger.error("No API key found for \(self.provider.displayName)")
            throw TranslationError.noApiKey
        }

        let systemPrompt = await MainActor.run {
            preferences.resolvedPrompt(for: request.targetLanguage.displayName)
        }

        logger.info("Translating via \(self.provider.displayName) (\(self.model)) to \(request.targetLanguage.displayName)")

        let (urlRequest, _) = try buildRequest(
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            userText: request.sourceText
        )

        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await session.data(for: urlRequest)
        } catch {
            logger.error("Network error: \(error.localizedDescription)")
            throw TranslationError.networkError(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        logger.info("\(self.provider.displayName) responded with status \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200:
            break
        case 429:
            throw TranslationError.rateLimited
        case 400...499:
            let body = String(data: responseData, encoding: .utf8) ?? "unknown"
            logger.error("Client error \(httpResponse.statusCode): \(body)")
            throw TranslationError.invalidResponse
        default:
            throw TranslationError.invalidResponse
        }

        let translatedText = try extractText(from: responseData)
        logger.info("Translation successful (\(translatedText.count) chars)")

        return TranslationResult(
            translatedText: translatedText,
            detectedSourceLanguage: nil
        )
    }

    // MARK: - Request Building

    /// Builds the URL request and body for the configured provider.
    private func buildRequest(
        apiKey: String,
        systemPrompt: String,
        userText: String
    ) throws -> (URLRequest, Data) {
        switch provider {
        case .openai:
            return try buildOpenAIRequest(apiKey: apiKey, systemPrompt: systemPrompt, userText: userText)
        case .gemini:
            return try buildGeminiRequest(apiKey: apiKey, systemPrompt: systemPrompt, userText: userText)
        case .claude:
            return try buildClaudeRequest(apiKey: apiKey, systemPrompt: systemPrompt, userText: userText)
        case .deepl:
            fatalError("DeepL should use DeepLTranslator, not LLMTranslator")
        }
    }

    private func buildOpenAIRequest(
        apiKey: String,
        systemPrompt: String,
        userText: String
    ) throws -> (URLRequest, Data) {
        var request = URLRequest(url: provider.apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userText],
            ],
            "temperature": 0.3,
        ]

        let data = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = data
        return (request, data)
    }

    private func buildGeminiRequest(
        apiKey: String,
        systemPrompt: String,
        userText: String
    ) throws -> (URLRequest, Data) {
        let url = URL(string: "\(provider.apiURL.absoluteString)\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                ["parts": [["text": userText]]]
            ],
            "generationConfig": [
                "temperature": 0.3
            ],
        ]

        let data = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = data
        return (request, data)
    }

    private func buildClaudeRequest(
        apiKey: String,
        systemPrompt: String,
        userText: String
    ) throws -> (URLRequest, Data) {
        var request = URLRequest(url: provider.apiURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userText]
            ],
        ]

        let data = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = data
        return (request, data)
    }

    // MARK: - Response Parsing

    /// Extracts the translated text from the provider's JSON response.
    private func extractText(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranslationError.invalidResponse
        }

        switch provider {
        case .openai:
            return try extractOpenAIText(json)
        case .gemini:
            return try extractGeminiText(json)
        case .claude:
            return try extractClaudeText(json)
        case .deepl:
            fatalError("DeepL should use DeepLTranslator, not LLMTranslator")
        }
    }

    private func extractOpenAIText(_ json: [String: Any]) throws -> String {
        guard
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            logger.error("Failed to parse OpenAI response")
            throw TranslationError.invalidResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractGeminiText(_ json: [String: Any]) throws -> String {
        guard
            let candidates = json["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let firstPart = parts.first,
            let text = firstPart["text"] as? String
        else {
            logger.error("Failed to parse Gemini response")
            throw TranslationError.invalidResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractClaudeText(_ json: [String: Any]) throws -> String {
        guard
            let contentArray = json["content"] as? [[String: Any]],
            let first = contentArray.first,
            let text = first["text"] as? String
        else {
            logger.error("Failed to parse Claude response")
            throw TranslationError.invalidResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

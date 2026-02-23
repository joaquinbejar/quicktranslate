import Foundation
import os

/// Translation backend that uses the DeepL API Free endpoint.
final class DeepLTranslator: TranslationService {
    /// DeepL Free API base URL.
    private static let apiURL = URL(string: "https://api-free.deepl.com/v2/translate")!

    /// Maximum text length for DeepL Free tier (128 KB).
    private static let maxTextBytes = 128 * 1024

    private let keychainVault: KeychainVault
    private let session: URLSession
    private let logger = Logger(subsystem: "com.quicktranslate", category: "DeepLTranslator")

    /// Creates a new DeepL translator.
    ///
    /// - Parameters:
    ///   - keychainVault: Vault from which to retrieve the API key.
    ///   - session: URL session for network requests. Defaults to `.shared`.
    init(keychainVault: KeychainVault, session: URLSession = .shared) {
        self.keychainVault = keychainVault
        self.session = session
    }

    /// Translates the given request using the DeepL API.
    ///
    /// - Parameter request: The translation request.
    /// - Returns: A `TranslationResult` with translated text and detected source language.
    /// - Throws: A `TranslationError` on failure.
    func translate(_ request: TranslationRequest) async throws -> TranslationResult {
        guard let apiKey = try keychainVault.retrieve() else {
            logger.error("No API key found in keychain")
            throw TranslationError.noApiKey
        }

        // Truncate to DeepL's free tier limit
        let sourceText: String
        if request.sourceText.utf8.count > Self.maxTextBytes {
            let data = Data(request.sourceText.utf8.prefix(Self.maxTextBytes))
            sourceText = String(data: data, encoding: .utf8) ?? String(request.sourceText.prefix(5000))
        } else {
            sourceText = request.sourceText
        }

        var urlRequest = URLRequest(url: Self.apiURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyComponents = [
            "text": sourceText,
            "target_lang": request.targetLanguage.apiCode,
        ]
        urlRequest.httpBody = bodyComponents
            .map { key, value in
                let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? value
                return "\(key)=\(escapedValue)"
            }
            .joined(separator: "&")
            .data(using: .utf8)

        logger.info("Sending translation request to DeepL (target: \(request.targetLanguage.apiCode))")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            logger.error("Network error: \(error.localizedDescription)")
            throw TranslationError.networkError(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        logger.info("DeepL responded with status \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200:
            break
        case 429:
            throw TranslationError.rateLimited
        case 456:
            throw TranslationError.textTooLong
        default:
            throw TranslationError.invalidResponse
        }

        let decoded: DeepLResponse
        do {
            decoded = try JSONDecoder().decode(DeepLResponse.self, from: data)
        } catch {
            logger.error("Failed to decode DeepL response: \(error.localizedDescription)")
            throw TranslationError.invalidResponse
        }

        guard let first = decoded.translations.first else {
            throw TranslationError.invalidResponse
        }

        logger.info("Translation successful, detected source: \(first.detectedSourceLanguage ?? "unknown")")

        return TranslationResult(
            translatedText: first.text,
            detectedSourceLanguage: first.detectedSourceLanguage
        )
    }
}

// MARK: - DeepL API Response Model

/// Top-level response from the DeepL /v2/translate endpoint.
private struct DeepLResponse: Codable {
    let translations: [Translation]

    struct Translation: Codable {
        let text: String
        let detectedSourceLanguage: String?

        enum CodingKeys: String, CodingKey {
            case text
            case detectedSourceLanguage = "detected_source_language"
        }
    }
}

// MARK: - URL Encoding Helpers

private extension CharacterSet {
    /// Characters allowed in a URL query parameter value.
    static let urlQueryValueAllowed: CharacterSet = {
        var cs = CharacterSet.urlQueryAllowed
        cs.remove(charactersIn: "&=+")
        return cs
    }()
}

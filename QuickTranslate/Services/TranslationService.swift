import Foundation

/// Errors that can occur during translation.
enum TranslationError: Error, LocalizedError {
    /// No API key is configured.
    case noApiKey
    /// A network error occurred.
    case networkError(underlying: Error)
    /// The API returned an invalid or unexpected response.
    case invalidResponse
    /// The API rate limit has been exceeded.
    case rateLimited
    /// The selected text exceeds the maximum allowed length.
    case textTooLong

    var errorDescription: String? {
        switch self {
        case .noApiKey:
            return "No API key configured. Open Settings to add your API key."
        case .networkError:
            return "Network error. Check your internet connection."
        case .invalidResponse:
            return "Translation failed. Please try again."
        case .rateLimited:
            return "Too many requests. Please wait a moment."
        case .textTooLong:
            return "Selected text is too long to translate."
        }
    }
}

/// Contract for any translation backend.
protocol TranslationService: Sendable {
    /// Translates the given request and returns a result.
    ///
    /// - Parameter request: The translation request containing source text and target language.
    /// - Returns: A `TranslationResult` with the translated text and metadata.
    /// - Throws: A `TranslationError` if translation fails.
    func translate(_ request: TranslationRequest) async throws -> TranslationResult
}

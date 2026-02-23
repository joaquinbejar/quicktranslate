import Foundation

/// A value object representing the result of a translation.
struct TranslationResult: Sendable {
    /// The translated text.
    let translatedText: String
    /// The language detected in the source text, if available (e.g., "EN", "ES").
    let detectedSourceLanguage: String?
}

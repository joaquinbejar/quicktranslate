import Foundation

/// Supported target languages for translation.
enum TargetLanguage: String, Sendable, CaseIterable {
    case english
    case spanish

    /// DeepL API language code.
    var apiCode: String {
        switch self {
        case .english: return "EN"
        case .spanish: return "ES"
        }
    }

    /// Human-readable display name.
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        }
    }
}

/// A value object representing a request to translate text into a target language.
struct TranslationRequest: Sendable {
    /// The source text to translate.
    let sourceText: String
    /// The desired target language for translation.
    let targetLanguage: TargetLanguage
}

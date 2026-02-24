import Foundation

/// Supported translation API providers.
enum TranslationProvider: String, CaseIterable, Codable, Sendable {
    case openai
    case gemini
    case claude
    case deepl

    /// Human-readable display name.
    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .gemini: return "Google Gemini"
        case .claude: return "Anthropic Claude"
        case .deepl: return "DeepL"
        }
    }

    /// Available models for this provider.
    var models: [String] {
        switch self {
        case .openai:
            return ["gpt-4o-mini", "gpt-4o", "gpt-4-turbo", "gpt-3.5-turbo"]
        case .gemini:
            return ["gemini-2.0-flash", "gemini-1.5-flash", "gemini-1.5-pro"]
        case .claude:
            return ["claude-sonnet-4-20250514", "claude-3-5-haiku-latest", "claude-3-5-sonnet-latest"]
        case .deepl:
            return ["default"]
        }
    }

    /// The default model for this provider.
    var defaultModel: String {
        models.first ?? "default"
    }

    /// Keychain service identifier for this provider's API key.
    var keychainServiceId: String {
        "com.quicktranslate.api-key.\(rawValue)"
    }

    /// Whether this provider supports custom system prompts.
    var supportsSystemPrompt: Bool {
        self != .deepl
    }

    /// Whether this provider supports model selection.
    var supportsModelSelection: Bool {
        self != .deepl
    }

    /// API endpoint URL for this provider.
    var apiURL: URL {
        switch self {
        case .openai:
            return URL(string: "https://api.openai.com/v1/chat/completions")!
        case .gemini:
            // Model name is appended at request time.
            return URL(string: "https://generativelanguage.googleapis.com/v1beta/models/")!
        case .claude:
            return URL(string: "https://api.anthropic.com/v1/messages")!
        case .deepl:
            return URL(string: "https://api-free.deepl.com/v2/translate")!
        }
    }

    /// URL where users can obtain an API key for this provider.
    var apiKeyURL: String {
        switch self {
        case .openai: return "https://platform.openai.com/api-keys"
        case .gemini: return "https://aistudio.google.com/apikey"
        case .claude: return "https://console.anthropic.com/settings/keys"
        case .deepl: return "https://www.deepl.com/pro-api"
        }
    }
}

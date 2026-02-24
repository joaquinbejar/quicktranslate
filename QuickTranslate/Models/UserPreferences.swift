import Foundation

/// Persists user preferences (provider, model, system prompt) in UserDefaults.
final class UserPreferences: ObservableObject, @unchecked Sendable {
    private static let providerKey = "selectedProvider"
    private static let modelKey = "selectedModel"
    private static let systemPromptKey = "systemPrompt"

    /// Default system prompt used for LLM-based translation.
    static let defaultSystemPrompt = """
    You are a professional translator. \
    Translate the following text to {target_language}. \
    Return only the translated text without any explanation, prefix, or formatting. \
    Preserve the original formatting, line breaks, and markdown structure.
    """

    private let defaults: UserDefaults

    /// The currently selected translation provider.
    @Published var selectedProvider: TranslationProvider {
        didSet {
            defaults.set(selectedProvider.rawValue, forKey: Self.providerKey)
            // Reset model to provider's default when switching providers.
            if !selectedProvider.models.contains(selectedModel) {
                selectedModel = selectedProvider.defaultModel
            }
        }
    }

    /// The currently selected model within the provider.
    @Published var selectedModel: String {
        didSet {
            defaults.set(selectedModel, forKey: Self.modelKey)
        }
    }

    /// The custom system prompt for LLM-based providers.
    @Published var systemPrompt: String {
        didSet {
            defaults.set(systemPrompt, forKey: Self.systemPromptKey)
        }
    }

    /// Creates a new UserPreferences instance.
    ///
    /// - Parameter defaults: The UserDefaults store to use. Defaults to `.standard`.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let providerRaw = defaults.string(forKey: Self.providerKey) ?? TranslationProvider.openai.rawValue
        let provider = TranslationProvider(rawValue: providerRaw) ?? .openai

        let model = defaults.string(forKey: Self.modelKey) ?? provider.defaultModel
        let prompt = defaults.string(forKey: Self.systemPromptKey) ?? Self.defaultSystemPrompt

        self.selectedProvider = provider
        self.selectedModel = provider.models.contains(model) ? model : provider.defaultModel
        self.systemPrompt = prompt
    }

    /// Returns the system prompt with `{target_language}` replaced by the given language name.
    ///
    /// - Parameter language: The target language display name (e.g., "English").
    /// - Returns: The resolved system prompt string.
    func resolvedPrompt(for language: String) -> String {
        systemPrompt.replacingOccurrences(of: "{target_language}", with: language)
    }

    /// Resets the system prompt to the default value.
    func resetPromptToDefault() {
        systemPrompt = Self.defaultSystemPrompt
    }
}

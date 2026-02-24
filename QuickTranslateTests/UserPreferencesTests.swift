@testable import QuickTranslate
import XCTest

/// Tests for UserPreferences.
final class UserPreferencesTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "com.quicktranslate.tests.\(UUID().uuidString)")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.volatileDomainNames.first ?? "")
        defaults = nil
        super.tearDown()
    }

    func testDefaultProvider() {
        let prefs = UserPreferences(defaults: defaults)
        XCTAssertEqual(prefs.selectedProvider, .openai)
    }

    func testDefaultModel() {
        let prefs = UserPreferences(defaults: defaults)
        XCTAssertEqual(prefs.selectedModel, TranslationProvider.openai.defaultModel)
    }

    func testDefaultSystemPrompt() {
        let prefs = UserPreferences(defaults: defaults)
        XCTAssertEqual(prefs.systemPrompt, UserPreferences.defaultSystemPrompt)
    }

    func testProviderPersistence() {
        let prefs = UserPreferences(defaults: defaults)
        prefs.selectedProvider = .claude

        let prefs2 = UserPreferences(defaults: defaults)
        XCTAssertEqual(prefs2.selectedProvider, .claude)
    }

    func testModelPersistence() {
        let prefs = UserPreferences(defaults: defaults)
        prefs.selectedProvider = .openai
        prefs.selectedModel = "gpt-4o"

        let prefs2 = UserPreferences(defaults: defaults)
        XCTAssertEqual(prefs2.selectedModel, "gpt-4o")
    }

    func testSystemPromptPersistence() {
        let prefs = UserPreferences(defaults: defaults)
        prefs.systemPrompt = "Custom prompt"

        let prefs2 = UserPreferences(defaults: defaults)
        XCTAssertEqual(prefs2.systemPrompt, "Custom prompt")
    }

    func testSwitchingProviderResetsModelIfInvalid() {
        let prefs = UserPreferences(defaults: defaults)
        prefs.selectedProvider = .openai
        prefs.selectedModel = "gpt-4o"

        prefs.selectedProvider = .claude
        XCTAssertTrue(TranslationProvider.claude.models.contains(prefs.selectedModel))
    }

    func testResolvedPrompt() {
        let prefs = UserPreferences(defaults: defaults)
        prefs.systemPrompt = "Translate to {target_language} please."

        let resolved = prefs.resolvedPrompt(for: "Spanish")
        XCTAssertEqual(resolved, "Translate to Spanish please.")
    }

    func testResetPromptToDefault() {
        let prefs = UserPreferences(defaults: defaults)
        prefs.systemPrompt = "Custom"
        XCTAssertNotEqual(prefs.systemPrompt, UserPreferences.defaultSystemPrompt)

        prefs.resetPromptToDefault()
        XCTAssertEqual(prefs.systemPrompt, UserPreferences.defaultSystemPrompt)
    }

    func testInvalidProviderFallsBackToOpenAI() {
        defaults.set("nonexistent", forKey: "selectedProvider")
        let prefs = UserPreferences(defaults: defaults)
        XCTAssertEqual(prefs.selectedProvider, .openai)
    }

    func testInvalidModelFallsBackToProviderDefault() {
        defaults.set("openai", forKey: "selectedProvider")
        defaults.set("nonexistent-model", forKey: "selectedModel")
        let prefs = UserPreferences(defaults: defaults)
        XCTAssertEqual(prefs.selectedModel, TranslationProvider.openai.defaultModel)
    }
}

@testable import QuickTranslate
import XCTest

/// Tests for the TranslationProvider enum.
final class TranslationProviderTests: XCTestCase {
    func testAllCasesCount() {
        XCTAssertEqual(TranslationProvider.allCases.count, 4)
    }

    func testDisplayNames() {
        XCTAssertEqual(TranslationProvider.openai.displayName, "OpenAI")
        XCTAssertEqual(TranslationProvider.gemini.displayName, "Google Gemini")
        XCTAssertEqual(TranslationProvider.claude.displayName, "Anthropic Claude")
        XCTAssertEqual(TranslationProvider.deepl.displayName, "DeepL")
    }

    func testModelsNotEmpty() {
        for provider in TranslationProvider.allCases {
            XCTAssertFalse(provider.models.isEmpty, "\(provider.displayName) should have at least one model")
        }
    }

    func testDefaultModelIsFirstModel() {
        for provider in TranslationProvider.allCases {
            XCTAssertEqual(provider.defaultModel, provider.models.first)
        }
    }

    func testKeychainServiceIdUnique() {
        let ids = TranslationProvider.allCases.map(\.keychainServiceId)
        XCTAssertEqual(Set(ids).count, ids.count, "Keychain service IDs must be unique")
    }

    func testSupportsSystemPrompt() {
        XCTAssertTrue(TranslationProvider.openai.supportsSystemPrompt)
        XCTAssertTrue(TranslationProvider.gemini.supportsSystemPrompt)
        XCTAssertTrue(TranslationProvider.claude.supportsSystemPrompt)
        XCTAssertFalse(TranslationProvider.deepl.supportsSystemPrompt)
    }

    func testSupportsModelSelection() {
        XCTAssertTrue(TranslationProvider.openai.supportsModelSelection)
        XCTAssertTrue(TranslationProvider.gemini.supportsModelSelection)
        XCTAssertTrue(TranslationProvider.claude.supportsModelSelection)
        XCTAssertFalse(TranslationProvider.deepl.supportsModelSelection)
    }

    func testApiURLNotNil() {
        for provider in TranslationProvider.allCases {
            XCTAssertFalse(provider.apiURL.absoluteString.isEmpty)
        }
    }

    func testApiKeyURLNotEmpty() {
        for provider in TranslationProvider.allCases {
            XCTAssertFalse(provider.apiKeyURL.isEmpty)
            XCTAssertTrue(provider.apiKeyURL.hasPrefix("https://"))
        }
    }

    func testCodable() throws {
        let provider = TranslationProvider.openai
        let data = try JSONEncoder().encode(provider)
        let decoded = try JSONDecoder().decode(TranslationProvider.self, from: data)
        XCTAssertEqual(decoded, provider)
    }
}

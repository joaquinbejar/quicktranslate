@testable import QuickTranslate
import XCTest

/// Tests for the core domain models.
final class TranslationModelTests: XCTestCase {
    // MARK: - TargetLanguage

    func testEnglishApiCode() {
        XCTAssertEqual(TargetLanguage.english.apiCode, "EN")
    }

    func testSpanishApiCode() {
        XCTAssertEqual(TargetLanguage.spanish.apiCode, "ES")
    }

    func testEnglishDisplayName() {
        XCTAssertEqual(TargetLanguage.english.displayName, "English")
    }

    func testSpanishDisplayName() {
        XCTAssertEqual(TargetLanguage.spanish.displayName, "Spanish")
    }

    func testAllCases() {
        XCTAssertEqual(TargetLanguage.allCases.count, 2)
    }

    // MARK: - TranslationRequest

    func testTranslationRequestInit() {
        let request = TranslationRequest(sourceText: "Hello", targetLanguage: .spanish)
        XCTAssertEqual(request.sourceText, "Hello")
        XCTAssertEqual(request.targetLanguage, .spanish)
    }

    func testTranslationRequestWithEmptyText() {
        let request = TranslationRequest(sourceText: "", targetLanguage: .english)
        XCTAssertTrue(request.sourceText.isEmpty)
    }

    // MARK: - TranslationResult

    func testTranslationResultInit() {
        let result = TranslationResult(translatedText: "Hola", detectedSourceLanguage: "EN")
        XCTAssertEqual(result.translatedText, "Hola")
        XCTAssertEqual(result.detectedSourceLanguage, "EN")
    }

    func testTranslationResultWithNilDetectedLanguage() {
        let result = TranslationResult(translatedText: "Hola", detectedSourceLanguage: nil)
        XCTAssertNil(result.detectedSourceLanguage)
    }

    // MARK: - TranslationError

    func testTranslationErrorDescriptions() {
        XCTAssertNotNil(TranslationError.noApiKey.errorDescription)
        XCTAssertNotNil(TranslationError.rateLimited.errorDescription)
        XCTAssertNotNil(TranslationError.textTooLong.errorDescription)
        XCTAssertNotNil(TranslationError.invalidResponse.errorDescription)

        let networkError = TranslationError.networkError(
            underlying: URLError(.notConnectedToInternet)
        )
        XCTAssertNotNil(networkError.errorDescription)
    }
}

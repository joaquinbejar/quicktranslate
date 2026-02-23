@testable import QuickTranslate
import XCTest

/// Tests to verify MockTranslationService behaves correctly for use in other tests.
final class MockTranslationServiceTests: XCTestCase {
    func testDefaultReturnsMockTranslation() async throws {
        let mock = MockTranslationService()
        let request = TranslationRequest(sourceText: "Hello", targetLanguage: .spanish)
        let result = try await mock.translate(request)

        XCTAssertEqual(result.translatedText, "mock translation")
        XCTAssertTrue(mock.translateCalled)
        XCTAssertEqual(mock.translateCallCount, 1)
        XCTAssertEqual(mock.lastRequest?.sourceText, "Hello")
        XCTAssertEqual(mock.lastRequest?.targetLanguage, .spanish)
    }

    func testConfiguredResult() async throws {
        let mock = MockTranslationService()
        mock.resultToReturn = TranslationResult(translatedText: "Hola", detectedSourceLanguage: "EN")

        let request = TranslationRequest(sourceText: "Hello", targetLanguage: .spanish)
        let result = try await mock.translate(request)

        XCTAssertEqual(result.translatedText, "Hola")
    }

    func testConfiguredError() async {
        let mock = MockTranslationService()
        mock.errorToThrow = TranslationError.rateLimited

        let request = TranslationRequest(sourceText: "Hello", targetLanguage: .spanish)

        do {
            _ = try await mock.translate(request)
            XCTFail("Expected error")
        } catch let error as TranslationError {
            if case .rateLimited = error {
                // Expected
            } else {
                XCTFail("Expected .rateLimited")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testReset() async throws {
        let mock = MockTranslationService()
        let request = TranslationRequest(sourceText: "Hello", targetLanguage: .english)
        _ = try await mock.translate(request)

        mock.reset()

        XCTAssertFalse(mock.translateCalled)
        XCTAssertEqual(mock.translateCallCount, 0)
        XCTAssertNil(mock.lastRequest)
    }

    func testMultipleCalls() async throws {
        let mock = MockTranslationService()
        let r1 = TranslationRequest(sourceText: "A", targetLanguage: .english)
        let r2 = TranslationRequest(sourceText: "B", targetLanguage: .spanish)

        _ = try await mock.translate(r1)
        _ = try await mock.translate(r2)

        XCTAssertEqual(mock.translateCallCount, 2)
        XCTAssertEqual(mock.lastRequest?.sourceText, "B")
    }
}

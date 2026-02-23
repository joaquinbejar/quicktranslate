@testable import QuickTranslate
import XCTest

/// Tests for DeepLTranslator using URLProtocol mocking.
final class DeepLTranslatorTests: XCTestCase {
    private var vault: KeychainVault!
    private var session: URLSession!
    private var translator: DeepLTranslator!

    override func setUp() {
        super.setUp()
        vault = KeychainVault(serviceIdentifier: "com.quicktranslate.test-deepl")
        try? vault.delete()

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)

        translator = DeepLTranslator(keychainVault: vault, session: session)
    }

    override func tearDown() {
        try? vault.delete()
        MockURLProtocol.requestHandler = nil
        vault = nil
        session = nil
        translator = nil
        super.tearDown()
    }

    // MARK: - No API Key

    func testTranslateWithoutApiKeyThrowsNoApiKey() async {
        let request = TranslationRequest(sourceText: "Hello", targetLanguage: .spanish)

        do {
            _ = try await translator.translate(request)
            XCTFail("Expected TranslationError.noApiKey")
        } catch let error as TranslationError {
            if case .noApiKey = error {
                // Expected
            } else {
                XCTFail("Expected .noApiKey, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Successful Translation

    func testSuccessfulTranslation() async throws {
        try vault.save(apiKey: "test-key-123")

        let responseJSON = """
        {
            "translations": [
                {
                    "detected_source_language": "EN",
                    "text": "Hola"
                }
            ]
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, responseJSON.data(using: .utf8)!)
        }

        let request = TranslationRequest(sourceText: "Hello", targetLanguage: .spanish)
        let result = try await translator.translate(request)

        XCTAssertEqual(result.translatedText, "Hola")
        XCTAssertEqual(result.detectedSourceLanguage, "EN")
    }

    // MARK: - Error Code Mapping

    func testRateLimitedResponse() async throws {
        try vault.save(apiKey: "test-key")

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let request = TranslationRequest(sourceText: "Hello", targetLanguage: .spanish)

        do {
            _ = try await translator.translate(request)
            XCTFail("Expected TranslationError.rateLimited")
        } catch let error as TranslationError {
            if case .rateLimited = error {
                // Expected
            } else {
                XCTFail("Expected .rateLimited, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testTextTooLongResponse() async throws {
        try vault.save(apiKey: "test-key")

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 456,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let request = TranslationRequest(sourceText: "Hello", targetLanguage: .spanish)

        do {
            _ = try await translator.translate(request)
            XCTFail("Expected TranslationError.textTooLong")
        } catch let error as TranslationError {
            if case .textTooLong = error {
                // Expected
            } else {
                XCTFail("Expected .textTooLong, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testServerErrorResponse() async throws {
        try vault.save(apiKey: "test-key")

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let request = TranslationRequest(sourceText: "Hello", targetLanguage: .spanish)

        do {
            _ = try await translator.translate(request)
            XCTFail("Expected TranslationError.invalidResponse")
        } catch let error as TranslationError {
            if case .invalidResponse = error {
                // Expected
            } else {
                XCTFail("Expected .invalidResponse, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Malformed Response

    func testMalformedJSONThrowsInvalidResponse() async throws {
        try vault.save(apiKey: "test-key")

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, "not json".data(using: .utf8)!)
        }

        let request = TranslationRequest(sourceText: "Hello", targetLanguage: .spanish)

        do {
            _ = try await translator.translate(request)
            XCTFail("Expected TranslationError.invalidResponse")
        } catch let error as TranslationError {
            if case .invalidResponse = error {
                // Expected
            } else {
                XCTFail("Expected .invalidResponse, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testEmptyTranslationsArrayThrowsInvalidResponse() async throws {
        try vault.save(apiKey: "test-key")

        let responseJSON = """
        { "translations": [] }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, responseJSON.data(using: .utf8)!)
        }

        let request = TranslationRequest(sourceText: "Hello", targetLanguage: .spanish)

        do {
            _ = try await translator.translate(request)
            XCTFail("Expected TranslationError.invalidResponse")
        } catch let error as TranslationError {
            if case .invalidResponse = error {
                // Expected
            } else {
                XCTFail("Expected .invalidResponse, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Request Verification

    func testRequestContainsCorrectHeaders() async throws {
        try vault.save(apiKey: "my-secret-key")

        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let body = """
            { "translations": [{ "text": "Hola", "detected_source_language": "EN" }] }
            """
            return (response, body.data(using: .utf8)!)
        }

        let request = TranslationRequest(sourceText: "Hello", targetLanguage: .spanish)
        _ = try await translator.translate(request)

        XCTAssertNotNil(capturedRequest)
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(
            capturedRequest?.value(forHTTPHeaderField: "Authorization"),
            "DeepL-Auth-Key my-secret-key"
        )
        XCTAssertEqual(
            capturedRequest?.value(forHTTPHeaderField: "Content-Type"),
            "application/x-www-form-urlencoded"
        )
    }
}

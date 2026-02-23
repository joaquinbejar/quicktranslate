@testable import QuickTranslate
import Foundation

/// A mock translation service for unit testing.
///
/// Can be configured to return a specific result or throw a specific error.
/// Tracks whether `translate()` was called and with what request.
final class MockTranslationService: TranslationService {
    /// The result to return from `translate()`. If `nil`, `errorToThrow` is used.
    var resultToReturn: TranslationResult?
    /// The error to throw from `translate()`. Ignored if `resultToReturn` is set.
    var errorToThrow: Error?

    /// Whether `translate()` was called.
    private(set) var translateCalled = false
    /// The last request passed to `translate()`.
    private(set) var lastRequest: TranslationRequest?
    /// Total number of times `translate()` was called.
    private(set) var translateCallCount = 0

    func translate(_ request: TranslationRequest) async throws -> TranslationResult {
        translateCalled = true
        lastRequest = request
        translateCallCount += 1

        if let result = resultToReturn {
            return result
        }

        if let error = errorToThrow {
            throw error
        }

        return TranslationResult(translatedText: "mock translation", detectedSourceLanguage: "EN")
    }

    /// Resets all tracking state.
    func reset() {
        translateCalled = false
        lastRequest = nil
        translateCallCount = 0
        resultToReturn = nil
        errorToThrow = nil
    }
}

// MARK: - MockURLProtocol

/// A URLProtocol subclass that intercepts network requests for testing.
final class MockURLProtocol: URLProtocol {
    /// Handler that returns (response, data) for a given request.
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@testable import QuickTranslate
import XCTest

/// Tests for KeychainVault using a test-specific service identifier.
final class KeychainVaultTests: XCTestCase {
    /// Uses a unique service identifier to avoid polluting the real keychain.
    private var vault: KeychainVault!

    override func setUp() {
        super.setUp()
        vault = KeychainVault(serviceIdentifier: "com.quicktranslate.test-api-key")
        try? vault.delete()
    }

    override func tearDown() {
        try? vault.delete()
        vault = nil
        super.tearDown()
    }

    func testRetrieveReturnsNilWhenEmpty() throws {
        let result = try vault.retrieve()
        XCTAssertNil(result)
    }

    func testSaveAndRetrieve() throws {
        let testKey = "test-deepl-api-key-12345"
        try vault.save(apiKey: testKey)

        let retrieved = try vault.retrieve()
        XCTAssertEqual(retrieved, testKey)
    }

    func testSaveOverwritesExistingKey() throws {
        try vault.save(apiKey: "first-key")
        try vault.save(apiKey: "second-key")

        let retrieved = try vault.retrieve()
        XCTAssertEqual(retrieved, "second-key")
    }

    func testDeleteRemovesKey() throws {
        try vault.save(apiKey: "key-to-delete")
        try vault.delete()

        let retrieved = try vault.retrieve()
        XCTAssertNil(retrieved)
    }

    func testDeleteWhenEmptyDoesNotThrow() throws {
        XCTAssertNoThrow(try vault.delete())
    }

    func testSaveEmptyStringSucceeds() throws {
        try vault.save(apiKey: "")
        let retrieved = try vault.retrieve()
        XCTAssertEqual(retrieved, "")
    }

    func testSaveLongKey() throws {
        let longKey = String(repeating: "a", count: 1000)
        try vault.save(apiKey: longKey)

        let retrieved = try vault.retrieve()
        XCTAssertEqual(retrieved, longKey)
    }

    func testFullCycle() throws {
        try vault.save(apiKey: "cycle-key")
        XCTAssertEqual(try vault.retrieve(), "cycle-key")

        try vault.save(apiKey: "updated-key")
        XCTAssertEqual(try vault.retrieve(), "updated-key")

        try vault.delete()
        XCTAssertNil(try vault.retrieve())
    }
}

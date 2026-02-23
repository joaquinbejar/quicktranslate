import Foundation
import Security

/// Errors that can occur during Keychain operations.
enum KeychainError: Error, LocalizedError {
    /// Failed to save the API key to the Keychain.
    case saveFailed(OSStatus)
    /// Failed to retrieve the API key from the Keychain.
    case retrieveFailed(OSStatus)
    /// Failed to delete the API key from the Keychain.
    case deleteFailed(OSStatus)
    /// The Keychain returned data in an unexpected format.
    case unexpectedData

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain save failed with status \(status)"
        case .retrieveFailed(let status):
            return "Keychain retrieve failed with status \(status)"
        case .deleteFailed(let status):
            return "Keychain delete failed with status \(status)"
        case .unexpectedData:
            return "Keychain returned unexpected data"
        }
    }
}

/// Secure storage for the DeepL API key using macOS Keychain Services.
final class KeychainVault: Sendable {
    /// The Keychain service identifier used for storing the API key.
    let serviceIdentifier: String

    /// Creates a new KeychainVault.
    ///
    /// - Parameter serviceIdentifier: The Keychain service identifier. Defaults to
    ///   `"com.quicktranslate.api-key"`.
    init(serviceIdentifier: String = "com.quicktranslate.api-key") {
        self.serviceIdentifier = serviceIdentifier
    }

    /// Saves an API key to the Keychain.
    ///
    /// If a key already exists for this service, it is updated.
    ///
    /// - Parameter apiKey: The API key string to store.
    /// - Throws: `KeychainError.saveFailed` if the operation fails.
    func save(apiKey: String) throws {
        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.unexpectedData
        }

        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Retrieves the stored API key from the Keychain.
    ///
    /// - Returns: The API key string, or `nil` if no key is stored.
    /// - Throws: `KeychainError.retrieveFailed` or `KeychainError.unexpectedData`.
    func retrieve() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.retrieveFailed(status)
        }

        guard let data = result as? Data, let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }

        return string
    }

    /// Deletes the stored API key from the Keychain.
    ///
    /// - Throws: `KeychainError.deleteFailed` if the operation fails.
    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

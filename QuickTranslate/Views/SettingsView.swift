import SwiftUI

/// Settings view for configuring the DeepL API key.
struct SettingsView: View {
    let keychainVault: KeychainVault

    @State private var apiKeyInput = ""
    @State private var statusMessage = ""
    @State private var statusIsError = false
    @State private var isTesting = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DeepL API Key")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Enter your DeepL API Free key. You can get one at [deepl.com/pro-api](https://www.deepl.com/pro-api).")
                .font(.subheadline)
                .foregroundColor(.secondary)

            SecureField("Paste your API key here", text: $apiKeyInput)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Button("Save") {
                    saveKey()
                }
                .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Test") {
                    testKey()
                }
                .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty && !keyExists)

                Spacer()

                Button("Clear Key") {
                    showDeleteConfirmation = true
                }
                .foregroundColor(.red)
                .alert("Clear API Key?", isPresented: $showDeleteConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear", role: .destructive) {
                        clearKey()
                    }
                } message: {
                    Text("This will remove your stored DeepL API key.")
                }
            }

            if !statusMessage.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: statusIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(statusIsError ? .red : .green)
                    Text(statusMessage)
                        .font(.subheadline)
                }
            }

            if isTesting {
                ProgressView("Testing...")
                    .font(.subheadline)
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 280)
        .onAppear {
            loadExistingKey()
        }
    }

    // MARK: - Helpers

    private var keyExists: Bool {
        (try? keychainVault.retrieve()) != nil
    }

    private func loadExistingKey() {
        if let key = try? keychainVault.retrieve() {
            // Show masked version
            apiKeyInput = key
        }
    }

    private func saveKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            try keychainVault.save(apiKey: trimmed)
            statusMessage = "API key saved successfully."
            statusIsError = false
        } catch {
            statusMessage = "Failed to save: \(error.localizedDescription)"
            statusIsError = true
        }
    }

    private func testKey() {
        isTesting = true
        statusMessage = ""

        Task {
            do {
                // Ensure the current input is saved before testing
                let keyToTest = apiKeyInput.trimmingCharacters(in: .whitespaces)
                if !keyToTest.isEmpty {
                    try keychainVault.save(apiKey: keyToTest)
                }

                let translator = DeepLTranslator(keychainVault: keychainVault)
                let request = TranslationRequest(sourceText: "Hello", targetLanguage: .spanish)
                let result = try await translator.translate(request)

                await MainActor.run {
                    statusMessage = "Test passed! \"Hello\" → \"\(result.translatedText)\""
                    statusIsError = false
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Test failed: \(error.localizedDescription)"
                    statusIsError = true
                    isTesting = false
                }
            }
        }
    }

    private func clearKey() {
        do {
            try keychainVault.delete()
            apiKeyInput = ""
            statusMessage = "API key cleared."
            statusIsError = false
        } catch {
            statusMessage = "Failed to clear: \(error.localizedDescription)"
            statusIsError = true
        }
    }
}

import SwiftUI

/// Settings view for configuring the translation provider, model, API key, and system prompt.
struct SettingsView: View {
    @ObservedObject var preferences: UserPreferences

    @State private var apiKeyInput = ""
    @State private var statusMessage = ""
    @State private var statusIsError = false
    @State private var isTesting = false
    @State private var showDeleteConfirmation = false
    @State private var showResetPromptConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                providerSection
                modelSection
                apiKeySection
                promptSection
            }
            .padding(24)
        }
        .frame(minWidth: 520, minHeight: 560)
        .onAppear {
            loadExistingKey()
        }
        .onChange(of: preferences.selectedProvider) { _ in
            loadExistingKey()
        }
    }

    // MARK: - Provider Section

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Translation Provider")
                .font(.title2)
                .fontWeight(.semibold)

            Picker("Provider", selection: $preferences.selectedProvider) {
                ForEach(TranslationProvider.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Model Section

    @ViewBuilder
    private var modelSection: some View {
        if preferences.selectedProvider.supportsModelSelection {
            VStack(alignment: .leading, spacing: 8) {
                Text("Model")
                    .font(.headline)

                Picker("Model", selection: $preferences.selectedModel) {
                    ForEach(preferences.selectedProvider.models, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 300)
            }
        }
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(preferences.selectedProvider.displayName) API Key")
                .font(.headline)

            Text("Get your API key at [\(preferences.selectedProvider.apiKeyURL)](\(preferences.selectedProvider.apiKeyURL))")
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
                    Text("This will remove your stored \(preferences.selectedProvider.displayName) API key.")
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
        }
    }

    // MARK: - System Prompt Section

    @ViewBuilder
    private var promptSection: some View {
        if preferences.selectedProvider.supportsSystemPrompt {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("System Prompt")
                        .font(.headline)

                    Spacer()

                    Button("Reset to Default") {
                        showResetPromptConfirmation = true
                    }
                    .font(.subheadline)
                    .alert("Reset System Prompt?", isPresented: $showResetPromptConfirmation) {
                        Button("Cancel", role: .cancel) {}
                        Button("Reset", role: .destructive) {
                            preferences.resetPromptToDefault()
                        }
                    } message: {
                        Text("This will restore the default translation prompt.")
                    }
                }

                Text("Use `{target_language}` as a placeholder for the target language.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextEditor(text: $preferences.systemPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
                    .border(Color.secondary.opacity(0.3), width: 1)
                    .cornerRadius(4)
            }
        }
    }

    // MARK: - Helpers

    private var currentVault: KeychainVault {
        KeychainVault(serviceIdentifier: preferences.selectedProvider.keychainServiceId)
    }

    private var keyExists: Bool {
        (try? currentVault.retrieve()) != nil
    }

    private func loadExistingKey() {
        if let key = try? currentVault.retrieve() {
            apiKeyInput = key
        } else {
            apiKeyInput = ""
        }
        statusMessage = ""
    }

    private func saveKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            try currentVault.save(apiKey: trimmed)
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
                let keyToTest = apiKeyInput.trimmingCharacters(in: .whitespaces)
                if !keyToTest.isEmpty {
                    try currentVault.save(apiKey: keyToTest)
                }

                let translator: TranslationService
                let provider = preferences.selectedProvider

                switch provider {
                case .deepl:
                    translator = DeepLTranslator(keychainVault: currentVault)
                case .openai, .gemini, .claude:
                    translator = LLMTranslator(
                        provider: provider,
                        model: preferences.selectedModel,
                        keychainVault: currentVault,
                        preferences: preferences
                    )
                }

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
            try currentVault.delete()
            apiKeyInput = ""
            statusMessage = "API key cleared."
            statusIsError = false
        } catch {
            statusMessage = "Failed to clear: \(error.localizedDescription)"
            statusIsError = true
        }
    }
}

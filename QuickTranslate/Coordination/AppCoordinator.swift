import AppKit
import os
import SwiftUI

/// Orchestrates the full capture → translate → replace flow.
///
/// Ties together the hotkey manager, clipboard gateway, and translation service
/// to provide seamless in-place translation triggered by global shortcuts.
@MainActor
final class AppCoordinator: ObservableObject {
    // MARK: - Published State

    /// Whether a translation is currently in progress.
    @Published var isTranslating = false
    /// The last error message to display to the user.
    @Published var lastError: String?
    /// Whether the app has Accessibility permission.
    @Published var hasAccessibilityPermission = false

    // MARK: - Dependencies

    private let clipboard: ClipboardGateway
    private let hotkeyManager: HotkeyManager
    private let preferences: UserPreferences
    private let logger = Logger(subsystem: "com.quicktranslate", category: "AppCoordinator")

    /// Creates a new coordinator and wires up the hotkey callbacks.
    ///
    /// - Parameters:
    ///   - preferences: User preferences for provider/model/prompt selection.
    ///   - clipboard: Gateway for clipboard read/write.
    ///   - hotkeyManager: Manages global keyboard shortcuts.
    init(
        preferences: UserPreferences,
        clipboard: ClipboardGateway,
        hotkeyManager: HotkeyManager
    ) {
        self.preferences = preferences
        self.clipboard = clipboard
        self.hotkeyManager = hotkeyManager

        checkAccessibility()

        // Wire hotkey events to the translation flow.
        self.hotkeyManager.onTranslationRequested = { [weak self] language in
            guard let self else { return }
            Task { @MainActor in
                await self.handleTranslation(to: language)
            }
        }
    }

    // MARK: - Accessibility

    /// Checks and updates the Accessibility permission status.
    func checkAccessibility() {
        hasAccessibilityPermission = hotkeyManager.isAccessibilityGranted
    }

    /// Opens System Settings to the Accessibility pane.
    func requestAccessibilityPermission() {
        hotkeyManager.requestAccessibilityPermission()
    }

    // MARK: - Translation Flow

    /// Builds a `TranslationService` based on current user preferences.
    private func buildTranslator() -> TranslationService {
        let provider = preferences.selectedProvider
        let model = preferences.selectedModel
        let vault = KeychainVault(serviceIdentifier: provider.keychainServiceId)

        switch provider {
        case .deepl:
            return DeepLTranslator(keychainVault: vault)
        case .openai, .gemini, .claude:
            return LLMTranslator(
                provider: provider,
                model: model,
                keychainVault: vault,
                preferences: preferences
            )
        }
    }

    /// Executes the translation flow.
    ///
    /// - English (⌘⇧E): In-place replacement — copies selected text, translates, pastes back.
    /// - Spanish (⌘⇧S): Popup display — copies selected text, translates, shows floating popup.
    ///
    /// - Parameter targetLanguage: The language to translate the selected text into.
    func handleTranslation(to targetLanguage: TargetLanguage) async {
        guard !isTranslating else {
            logger.warning("Translation already in progress, ignoring request")
            return
        }

        isTranslating = true
        lastError = nil
        logger.info("Starting translation to \(targetLanguage.displayName) via \(self.preferences.selectedProvider.displayName)")

        do {
            // 1. Save current clipboard
            let savedClipboard = clipboard.save()

            // 2. Simulate Cmd+C to copy selected text
            simulateCopy()

            // 3. Wait for clipboard to update (150 milliseconds)
            try await Task.sleep(nanoseconds: 150_000_000)

            // 4. Read the clipboard
            guard let selectedText = clipboard.read(), !selectedText.isEmpty,
                  selectedText != savedClipboard
            else {
                logger.warning("No text selected or clipboard unchanged")
                clipboard.restore(savedClipboard)
                showHUD(text: "No text selected", isError: true)
                isTranslating = false
                return
            }

            logger.info("Captured text (\(selectedText.count) chars)")

            // 5. Translate using current provider
            let translator = buildTranslator()
            let request = TranslationRequest(sourceText: selectedText, targetLanguage: targetLanguage)
            let result = try await translator.translate(request)

            logger.info("Translation complete")

            switch targetLanguage {
            case .english:
                // In-place replacement: paste translated text over selection
                clipboard.write(result.translatedText)
                simulatePaste()

                // Wait for paste to complete, then restore original clipboard (200 milliseconds)
                try await Task.sleep(nanoseconds: 200_000_000)
                clipboard.restore(savedClipboard)

                let preview = String(result.translatedText.prefix(80))
                showHUD(text: preview, isError: false)

            case .spanish:
                // Popup display: show translation without modifying original text
                clipboard.restore(savedClipboard)

                TranslationPopup.show(
                    originalText: selectedText,
                    translatedText: result.translatedText,
                    targetLanguage: targetLanguage.displayName
                )
            }

        } catch let error as TranslationError {
            let message = error.errorDescription ?? "Unknown translation error"
            logger.error("Translation error: \(message)")
            lastError = message
            showHUD(text: message, isError: true)
        } catch {
            let message = "Unexpected error: \(error.localizedDescription)"
            logger.error("\(message)")
            lastError = message
            showHUD(text: message, isError: true)
        }

        isTranslating = false
    }

    // MARK: - CGEvent Simulation

    /// Simulates pressing Cmd+C to copy the current selection.
    private func simulateCopy() {
        simulateKeyPress(keyCode: 8, flags: .maskCommand) // C key = 8
    }

    /// Simulates pressing Cmd+V to paste from the clipboard.
    private func simulatePaste() {
        simulateKeyPress(keyCode: 9, flags: .maskCommand) // V key = 9
    }

    /// Simulates a key press event with the given virtual keycode and modifier flags.
    ///
    /// - Parameters:
    ///   - keyCode: The virtual keycode (e.g., 8 for C, 9 for V).
    ///   - flags: The modifier flags to apply.
    private func simulateKeyPress(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            logger.error("Failed to create CGEvent for keycode \(keyCode)")
            return
        }

        keyDown.flags = flags
        keyUp.flags = flags

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    // MARK: - HUD

    /// Shows a floating HUD notification with the given text.
    ///
    /// - Parameters:
    ///   - text: The text to display.
    ///   - isError: Whether this is an error message (shows red icon) or success (green checkmark).
    func showHUD(text: String, isError: Bool) {
        TranslationHUD.show(text: text, isError: isError)
    }
}

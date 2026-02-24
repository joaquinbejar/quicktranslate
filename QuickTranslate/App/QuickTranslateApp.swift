import os
import SwiftUI

/// Main entry point for the QuickTranslate menu bar application.
@main
struct QuickTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var coordinator: AppCoordinator
    @StateObject private var preferences: UserPreferences

    init() {
        let prefs = UserPreferences()
        let clipboard = ClipboardGateway()
        let hotkeyManager = HotkeyManager()

        let coord = AppCoordinator(
            preferences: prefs,
            clipboard: clipboard,
            hotkeyManager: hotkeyManager
        )

        _coordinator = StateObject(wrappedValue: coord)
        _preferences = StateObject(wrappedValue: prefs)
    }

    var body: some Scene {
        MenuBarExtra("QuickTranslate", systemImage: "globe") {
            MenuBarView(coordinator: coordinator, preferences: preferences)
        }
    }
}

/// App delegate handling lifecycle events.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.quicktranslate", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("QuickTranslate launched")

        // Check accessibility on first launch
        if !AXIsProcessTrusted() {
            logger.warning("Accessibility permission not granted")
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("QuickTranslate terminating")
    }
}

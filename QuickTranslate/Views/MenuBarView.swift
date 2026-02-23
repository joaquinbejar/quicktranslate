import SwiftUI

/// The menu bar popover content showing app status, shortcuts, and actions.
struct MenuBarView: View {
    @ObservedObject var coordinator: AppCoordinator
    let keychainVault: KeychainVault
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            Text("QuickTranslate")
                .font(.headline)
                .padding(.bottom, 2)

            // Status
            HStack(spacing: 6) {
                if coordinator.isTranslating {
                    ProgressView()
                        .controlSize(.small)
                    Text("Translating...")
                        .foregroundColor(.secondary)
                } else {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Ready")
                        .foregroundColor(.secondary)
                }
            }
            .font(.subheadline)

            // API Key status
            HStack(spacing: 4) {
                Text("API Key:")
                    .foregroundColor(.secondary)
                if apiKeyConfigured {
                    Text("Configured ✓")
                        .foregroundColor(.green)
                } else {
                    Text("Not Set ✗")
                        .foregroundColor(.red)
                }
            }
            .font(.subheadline)

            Divider()

            // Settings
            Button("Settings...") {
                openSettings()
            }

            // Accessibility
            HStack(spacing: 4) {
                Text("Accessibility:")
                    .foregroundColor(.secondary)
                if coordinator.hasAccessibilityPermission {
                    Text("Granted ✓")
                        .foregroundColor(.green)
                } else {
                    Text("Not Granted ✗")
                        .foregroundColor(.red)
                }
            }
            .font(.subheadline)

            if !coordinator.hasAccessibilityPermission {
                Button("Grant Accessibility Permission") {
                    coordinator.requestAccessibilityPermission()
                }
                .font(.subheadline)
            }

            Divider()

            // Shortcuts reference
            Text("Keyboard Shortcuts")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("⌘⇧E → English")
                .font(.system(.subheadline, design: .monospaced))
            Text("⌘⇧S → Spanish")
                .font(.system(.subheadline, design: .monospaced))

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 240)
    }

    // MARK: - Helpers

    private var apiKeyConfigured: Bool {
        (try? keychainVault.retrieve()) != nil
    }

    private func openSettings() {
        let settingsView = SettingsView(keychainVault: keychainVault)
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "QuickTranslate Settings"
        window.setContentSize(NSSize(width: 420, height: 300))
        window.styleMask = [.titled, .closable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

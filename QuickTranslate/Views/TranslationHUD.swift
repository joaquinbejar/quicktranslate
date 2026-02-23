import AppKit
import SwiftUI

/// A floating HUD overlay that briefly shows translation results or errors.
///
/// Displays a borderless, translucent panel centered on screen that auto-dismisses
/// after 1.5 seconds with a fade-out animation.
final class TranslationHUD {
    private static var currentWindow: NSWindow?

    /// Shows the HUD with the given text.
    ///
    /// - Parameters:
    ///   - text: The message to display (truncated to 80 characters).
    ///   - isError: If `true`, shows a red X icon; otherwise a green checkmark.
    @MainActor
    static func show(text: String, isError: Bool) {
        // Dismiss any existing HUD
        currentWindow?.orderOut(nil)
        currentWindow = nil

        let truncated = String(text.prefix(80))

        let hudView = HUDContentView(text: truncated, isError: isError)
        let hostingView = NSHostingView(rootView: hudView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 360, height: 80)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.ignoresMouseEvents = true
        panel.contentView = hostingView

        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 180
            let y = screenFrame.midY - 40
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        currentWindow = panel

        // Fade in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1.0
        }

        // Auto-dismiss after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                panel.animator().alphaValue = 0.0
            }, completionHandler: {
                panel.orderOut(nil)
                if currentWindow === panel {
                    currentWindow = nil
                }
            })
        }
    }
}

/// SwiftUI content for the HUD overlay.
private struct HUDContentView: View {
    let text: String
    let isError: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(isError ? .red : .green)

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
    }
}

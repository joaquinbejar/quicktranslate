import AppKit
import SwiftUI

/// A floating speech-bubble popup that displays translation results near the mouse cursor.
///
/// The popup is interactive: users can copy the translated text or dismiss it.
/// It auto-dismisses after 15 seconds if not interacted with.
final class TranslationPopup {
    private static var currentWindow: NSPanel?
    private static var eventMonitor: Any?

    /// Shows the translation popup near the current mouse cursor position.
    ///
    /// - Parameters:
    ///   - originalText: The original source text.
    ///   - translatedText: The translated text to display.
    ///   - targetLanguage: The language the text was translated to.
    @MainActor
    static func show(originalText: String, translatedText: String, targetLanguage: String) {
        dismiss()

        let popupView = PopupContentView(
            translatedText: translatedText,
            targetLanguage: targetLanguage,
            onCopy: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(translatedText, forType: .string)
                dismiss()
            },
            onDismiss: { dismiss() }
        )

        let hostingView = NSHostingView(rootView: popupView)
        hostingView.setFrameSize(NSSize(width: 480, height: 10))
        let fittingSize = hostingView.fittingSize

        // Clamp to screen-relative bounds
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let maxW = min(screenFrame.width * 0.6, 600)
        let maxH = min(screenFrame.height * 0.7, 700)
        let width = min(max(fittingSize.width, 300), maxW)
        let height = min(max(fittingSize.height, 80), maxH)

        hostingView.setFrameSize(NSSize(width: width, height: height))

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.ignoresMouseEvents = false
        panel.contentView = hostingView

        // Position near mouse cursor, slightly above and to the right
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            var x = mouseLocation.x + 12
            var y = mouseLocation.y + 12

            // Keep within screen bounds
            if x + width > screenFrame.maxX {
                x = mouseLocation.x - width - 12
            }
            if y + height > screenFrame.maxY {
                y = mouseLocation.y - height - 12
            }
            if x < screenFrame.minX { x = screenFrame.minX + 8 }
            if y < screenFrame.minY { y = screenFrame.minY + 8 }

            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        currentWindow = panel

        // Fade in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1.0
        }

        // Dismiss on click outside or Escape key
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { event in
            if event.type == .keyDown && event.keyCode == 53 { // Escape
                dismiss()
                return nil
            }
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                if let window = currentWindow, !window.frame.contains(NSEvent.mouseLocation) {
                    dismiss()
                }
            }
            return event
        }
    }

    /// Dismisses the current popup with a fade-out animation.
    @MainActor
    static func dismiss() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        guard let panel = currentWindow else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
            panel.orderOut(nil)
            if currentWindow === panel {
                currentWindow = nil
            }
        })
    }
}

// MARK: - Popup Content View

/// SwiftUI content for the translation speech-bubble popup.
private struct PopupContentView: View {
    let translatedText: String
    let targetLanguage: String
    let onCopy: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "bubble.left.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14))
                Text("Translation → \(targetLanguage)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }

            // Translation text
            ScrollView(.vertical, showsIndicators: true) {
                Text(translatedText)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Actions
            HStack {
                Button(action: onCopy) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                        Text("Copy")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Spacer()

                Text("Esc to close")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .padding(14)
        .frame(width: 480)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}

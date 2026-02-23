import AppKit
import os

/// Gateway for reading and writing the macOS system clipboard.
///
/// All operations use `NSPasteboard.general` and must run on the main actor.
@MainActor
final class ClipboardGateway {
    private let logger = Logger(subsystem: "com.quicktranslate", category: "ClipboardGateway")

    /// Reads the current string from the system clipboard.
    ///
    /// - Returns: The clipboard string, or `nil` if no string content is available.
    func read() -> String? {
        let text = NSPasteboard.general.string(forType: .string)
        logger.debug("Clipboard read: \(text?.prefix(40) ?? "nil", privacy: .public)")
        return text
    }

    /// Writes a string to the system clipboard, clearing previous contents.
    ///
    /// - Parameter text: The text to place on the clipboard.
    func write(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        logger.debug("Clipboard write: \(text.prefix(40), privacy: .public)")
    }

    /// Saves the current clipboard content for later restoration.
    ///
    /// - Returns: The current clipboard string, or `nil` if empty.
    func save() -> String? {
        let content = read()
        logger.debug("Clipboard saved")
        return content
    }

    /// Restores previously saved clipboard content.
    ///
    /// - Parameter content: The content to restore. If `nil`, the clipboard is cleared.
    func restore(_ content: String?) {
        if let content {
            write(content)
        } else {
            NSPasteboard.general.clearContents()
        }
        logger.debug("Clipboard restored")
    }
}

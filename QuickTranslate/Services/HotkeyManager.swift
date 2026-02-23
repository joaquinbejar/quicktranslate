import Carbon.HIToolbox
import Cocoa
import os

/// Manages global keyboard shortcuts for triggering translations.
///
/// Registers event taps via `CGEvent` to listen for `Cmd+Shift+E` (English)
/// and `Cmd+Shift+S` (Spanish) globally.
final class HotkeyManager {
    /// Virtual keycode for the E key.
    static let kVKE: Int64 = 14
    /// Virtual keycode for the S key.
    static let kVKS: Int64 = 1

    /// Callback fired when a translation hotkey is pressed.
    var onTranslationRequested: ((TargetLanguage) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var runLoopThread: Thread?
    private let logger = Logger(subsystem: "com.quicktranslate", category: "HotkeyManager")

    /// Whether the app has been granted Accessibility permission.
    var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Creates and starts the global hotkey listener.
    init() {
        startEventTap()
    }

    deinit {
        stopEventTap()
    }

    // MARK: - Public Methods

    /// Prompts the user to grant Accessibility permission by opening System Settings.
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Event Tap

    private func startEventTap() {
        guard isAccessibilityGranted else {
            logger.warning("Accessibility permission not granted — event tap not started")
            return
        }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        // Use an Unmanaged pointer to pass `self` into the C callback.
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: hotkeyCallback,
                userInfo: selfPointer
            )
        else {
            logger.error("Failed to create CGEvent tap")
            return
        }

        eventTap = tap

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            logger.error("Failed to create run loop source for event tap")
            return
        }
        runLoopSource = source

        // Run the event tap on a dedicated background thread.
        let thread = Thread { [weak self] in
            guard let source = self?.runLoopSource else { return }
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
        thread.name = "com.quicktranslate.hotkey-runloop"
        thread.qualityOfService = .userInteractive
        thread.start()
        runLoopThread = thread

        logger.info("Global hotkey event tap started")
    }

    private func stopEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource, let thread = runLoopThread {
            // Signal the run loop on that thread to stop.
            CFRunLoopSourceInvalidate(source)
            thread.cancel()
        }
        eventTap = nil
        runLoopSource = nil
        runLoopThread = nil
        logger.info("Global hotkey event tap stopped")
    }

    /// Called from the C callback when a matching hotkey is detected.
    fileprivate func handleHotkey(_ language: TargetLanguage) {
        logger.info("Hotkey triggered: translate to \(language.displayName)")
        onTranslationRequested?(language)
    }
}

// MARK: - C Callback

/// Global C function used as the `CGEvent` tap callback.
private func hotkeyCallback(
    proxy _: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // If the tap is disabled by the system, re-enable it.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown, let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let flags = event.flags
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

    // Check for Cmd+Shift modifier combination.
    let hasCmd = flags.contains(.maskCommand)
    let hasShift = flags.contains(.maskShift)
    guard hasCmd, hasShift else {
        return Unmanaged.passUnretained(event)
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

    switch keyCode {
    case HotkeyManager.kVKE:
        manager.handleHotkey(.english)
        return nil // Consume the event
    case HotkeyManager.kVKS:
        manager.handleHotkey(.spanish)
        return nil // Consume the event
    default:
        return Unmanaged.passUnretained(event)
    }
}

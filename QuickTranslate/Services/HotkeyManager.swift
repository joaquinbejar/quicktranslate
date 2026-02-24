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

    /// Callback fired when a translation hotkey is pressed (key down).
    var onTranslationRequested: ((TargetLanguage) -> Void)?
    /// Callback fired when the translation hotkey is released (key up or modifier released).
    var onHotkeyReleased: (() -> Void)?
    /// The language for the currently held hotkey, or `nil` if no hotkey is held.
    private(set) var activeHotkey: TargetLanguage?

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

        let eventMask: CGEventMask = (
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        )

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

    /// Called from the C callback when a matching hotkey is pressed.
    fileprivate func handleHotkeyDown(_ language: TargetLanguage) {
        guard activeHotkey == nil else { return } // Ignore repeats
        activeHotkey = language
        logger.info("Hotkey down: translate to \(language.displayName)")
        onTranslationRequested?(language)
    }

    /// Called from the C callback when the hotkey combination is released.
    fileprivate func handleHotkeyUp() {
        guard activeHotkey != nil else { return }
        logger.info("Hotkey released")
        activeHotkey = nil
        onHotkeyReleased?()
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

    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
    let flags = event.flags
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let hasCmd = flags.contains(.maskCommand)
    let hasShift = flags.contains(.maskShift)

    switch type {
    case .keyDown:
        guard hasCmd, hasShift else {
            return Unmanaged.passUnretained(event)
        }
        switch keyCode {
        case HotkeyManager.kVKE:
            manager.handleHotkeyDown(.english)
            return nil
        case HotkeyManager.kVKS:
            manager.handleHotkeyDown(.spanish)
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }

    case .keyUp:
        // Release when the letter key (E or S) is released.
        if manager.activeHotkey != nil,
           keyCode == HotkeyManager.kVKE || keyCode == HotkeyManager.kVKS
        {
            manager.handleHotkeyUp()
            return nil
        }
        return Unmanaged.passUnretained(event)

    case .flagsChanged:
        // Release when Cmd or Shift is released while hotkey is active.
        if manager.activeHotkey != nil, !(hasCmd && hasShift) {
            manager.handleHotkeyUp()
        }
        return Unmanaged.passUnretained(event)

    default:
        return Unmanaged.passUnretained(event)
    }
}

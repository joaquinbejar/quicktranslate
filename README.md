# QuickTranslate

A macOS menu bar app that translates selected text in-place using the DeepL API. Select text in any app, press a keyboard shortcut, and the selected text is replaced with its translation.

## Features

- **Menu bar app** — lives in the macOS menu bar, no dock icon
- **Global hotkeys** — `Cmd+Shift+E` (translate to English), `Cmd+Shift+S` (translate to Spanish)
- **In-place replacement** — selected text is replaced directly with the translation
- **HUD notifications** — floating overlay shows translation results
- **Secure API key storage** — DeepL API key stored in macOS Keychain
- **DeepL API** — uses the DeepL Free translation API

## Requirements

- macOS 13.0+
- Swift toolchain (Command Line Tools is enough to build; Xcode needed for tests)
- A [DeepL API Free](https://www.deepl.com/pro-api) key

## Installation

### Quick install (from source)

```bash
git clone https://github.com/joaquinbejar/quicktranslate.git
cd quicktranslate
make install    # builds and copies to /Applications
```

### Create a DMG for distribution

```bash
make dmg        # produces .build/release/QuickTranslate-1.0.dmg
```

Then open the DMG and drag **QuickTranslate.app** to **Applications**.

### Makefile targets

| Command | Description |
|---|---|
| `make build` | Build the executable (release mode) |
| `make app` | Build a complete `.app` bundle |
| `make install` | Install to `/Applications` |
| `make dmg` | Create a distributable `.dmg` |
| `make uninstall` | Remove from `/Applications` |
| `make clean` | Remove build artifacts |

## Getting Started

### 1. Grant Accessibility permission

On first launch, the app will prompt you to grant Accessibility permission in **System Settings → Privacy & Security → Accessibility**. This is required for the global hotkeys and simulated copy/paste to work.

### 2. Configure your DeepL API key

Click the globe icon in the menu bar → **Settings...** → paste your DeepL API Free key → **Save**. Use the **Test** button to verify it works.

### 3. Translate

1. Select text in any app
2. Press `Cmd+Shift+E` to translate to English, or `Cmd+Shift+S` for Spanish
3. The selected text is replaced with the translation

## Architecture

```
QuickTranslate/
├── App/
│   └── QuickTranslateApp.swift       # Entry point, wires dependencies
├── Models/
│   ├── TranslationRequest.swift       # Source text + target language
│   └── TranslationResult.swift        # Translated text + metadata
├── Services/
│   ├── TranslationService.swift       # Protocol + error types
│   ├── DeepLTranslator.swift          # DeepL API implementation
│   ├── ClipboardGateway.swift         # NSPasteboard read/write
│   ├── HotkeyManager.swift            # CGEvent global shortcuts
│   └── KeychainVault.swift            # Keychain API key storage
├── Coordination/
│   └── AppCoordinator.swift           # Orchestrates the translation flow
├── Views/
│   ├── MenuBarView.swift              # Menu bar popover content
│   ├── SettingsView.swift             # API key configuration
│   └── TranslationHUD.swift           # Floating result overlay
├── Resources/
│   └── AppIcon.icns                   # App icon
├── Info.plist
└── QuickTranslate.entitlements
```

## Translation Flow

1. User selects text and presses `Cmd+Shift+E` (or `S`)
2. `HotkeyManager` fires event → `AppCoordinator`
3. `AppCoordinator` saves clipboard, simulates `Cmd+C`, reads copied text
4. Sends text to `DeepLTranslator` via the `TranslationService` protocol
5. Writes translated text to clipboard, simulates `Cmd+V`
6. Restores original clipboard contents
7. Shows HUD notification with result

## Building

```bash
make build      # release build
swift build     # debug build
```

No Xcode required — Command Line Tools is sufficient.

## Xcode Project

If you prefer working in Xcode:

```bash
brew install xcodegen
xcodegen generate
open QuickTranslate.xcodeproj
```

## Testing

Tests cover the domain models, Keychain storage, DeepL API response parsing (via URLProtocol mocking), and the mock translation service.

**Tests require Xcode** (XCTest is not available with Command Line Tools alone):

```bash
swift test
```

## Contribution and Contact

We welcome contributions to this project! If you would like to contribute, please follow these steps:

1. Fork the repository.
2. Create a new branch for your feature or bug fix.
3. Make your changes and ensure that the project still builds and all tests pass.
4. Commit your changes and push your branch to your forked repository.
5. Submit a pull request to the main repository.

If you have any questions, issues, or would like to provide feedback, please feel free to contact the project
maintainer:

### Contact Information
- **Author**: Joaquín Béjar García
- **Email**: jb@taunais.com
- **Telegram**: [@joaquin_bejar](https://t.me/joaquin_bejar)
- **Repository**: <https://github.com/joaquinbejar/quicktranslate>

We appreciate your interest and look forward to your contributions!

**License**: MIT

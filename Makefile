# QuickTranslate — Build & Install
#
# Usage:
#   make build       Build the executable (release mode)
#   make app         Build a complete .app bundle
#   make install     Install to /Applications
#   make dmg         Create a distributable .dmg
#   make uninstall   Remove from /Applications
#   make clean       Remove build artifacts

APP_NAME     := QuickTranslate
BUNDLE_ID    := com.quicktranslate.app
VERSION      := 1.0
BUILD_DIR    := .build/release
APP_BUNDLE   := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS     := $(APP_BUNDLE)/Contents
MACOS_DIR    := $(CONTENTS)/MacOS
RESOURCES    := $(CONTENTS)/Resources
DMG_NAME     := $(APP_NAME)-$(VERSION).dmg
INSTALL_DIR  := /Applications

.PHONY: build app install dmg uninstall clean lint-fix pre-push

# ── Build ────────────────────────────────────────────────────────────────

build:
	swift build -c release

# ── App Bundle ───────────────────────────────────────────────────────────

app: build
	@echo "📦 Creating $(APP_NAME).app bundle..."
	@mkdir -p $(MACOS_DIR) $(RESOURCES)
	@# Executable
	@cp $(BUILD_DIR)/$(APP_NAME) $(MACOS_DIR)/$(APP_NAME)
	@# Info.plist
	@cp $(APP_NAME)/Info.plist $(CONTENTS)/Info.plist
	@# Icon
	@if [ -f $(APP_NAME)/Resources/AppIcon.icns ]; then \
		cp $(APP_NAME)/Resources/AppIcon.icns $(RESOURCES)/AppIcon.icns; \
		/usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" $(CONTENTS)/Info.plist 2>/dev/null || true; \
		/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" $(CONTENTS)/Info.plist; \
	fi
	@# Ensure LSUIElement is set
	@/usr/libexec/PlistBuddy -c "Set :LSUIElement true" $(CONTENTS)/Info.plist 2>/dev/null || \
		/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" $(CONTENTS)/Info.plist
	@# PkgInfo
	@echo "APPL????" > $(CONTENTS)/PkgInfo
	@echo "✅ $(APP_BUNDLE) created"

# ── Install ──────────────────────────────────────────────────────────────

install: app
	@echo "📲 Installing to $(INSTALL_DIR)..."
	@rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@cp -R $(APP_BUNDLE) "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "✅ Installed to $(INSTALL_DIR)/$(APP_NAME).app"
	@echo "   Launch from Spotlight or: open '$(INSTALL_DIR)/$(APP_NAME).app'"

# ── DMG ──────────────────────────────────────────────────────────────────

dmg: app
	@echo "💿 Creating $(DMG_NAME)..."
	@rm -f $(BUILD_DIR)/$(DMG_NAME)
	@mkdir -p $(BUILD_DIR)/dmg-stage
	@cp -R $(APP_BUNDLE) $(BUILD_DIR)/dmg-stage/
	@ln -sf /Applications $(BUILD_DIR)/dmg-stage/Applications
	@hdiutil create -volname "$(APP_NAME)" \
		-srcfolder $(BUILD_DIR)/dmg-stage \
		-ov -format UDZO \
		$(BUILD_DIR)/$(DMG_NAME) 2>/dev/null
	@rm -rf $(BUILD_DIR)/dmg-stage
	@echo "✅ $(BUILD_DIR)/$(DMG_NAME) created"

# ── Uninstall ────────────────────────────────────────────────────────────

uninstall:
	@echo "🗑  Removing $(APP_NAME) from $(INSTALL_DIR)..."
	@rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "✅ Uninstalled"

# ── Clean ────────────────────────────────────────────────────────────────

clean:
	swift package clean
	@rm -rf $(BUILD_DIR)/$(APP_NAME).app $(BUILD_DIR)/dmg-stage $(BUILD_DIR)/$(DMG_NAME)
	@echo "✅ Clean"

# ── Lint ─────────────────────────────────────────────────────────────────

lint-fix:
	swift build 2>&1

pre-push: lint-fix
	swift build -c release 2>&1

BIN_NAME = airswitch
APP_NAME = AirSwitch.app
INSTALL_DIR = $(HOME)/.local/bin
BUILD_DIR = ./build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME)
APPLICATIONS_DIR = /Applications

.PHONY: all build app install install-app uninstall clean run stop test dmg set-version release help

all: build

help:
	@echo "AirSwitch Makefile commands:"
	@echo "  make build                   - Compile release binary to ./build/$(BIN_NAME)"
	@echo "  make app                     - Package standalone AirSwitch.app bundle"
	@echo "  make install-app             - Install AirSwitch.app into /Applications"
	@echo "  make install                 - Copy CLI binary to $(INSTALL_DIR)/$(BIN_NAME)"
	@echo "  make uninstall               - Remove binary & app, stop daemon"
	@echo "  make dmg                     - Create AirSwitch.dmg for distribution"
	@echo "  make set-version VERSION=x.y.z - Sync version across Info.plist & Swift source"
	@echo "  make release [VERSION=x.y.z] - Bump version, tag, and push to trigger GitHub Release"
	@echo "  make test                    - Run test suite"
	@echo "  make run                     - Start AirSwitch in the background"
	@echo "  make stop                    - Stop any running AirSwitch daemon"
	@echo "  make clean                   - Clean build artifacts"

build:
	@swift build -c release
	@mkdir -p $(BUILD_DIR)
	@cp .build/release/$(BIN_NAME) $(BUILD_DIR)/$(BIN_NAME)
	@echo "Build complete: $(BUILD_DIR)/$(BIN_NAME)"

app: build
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp $(BUILD_DIR)/$(BIN_NAME) $(APP_BUNDLE)/Contents/MacOS/$(BIN_NAME)
	@cp Resources/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	@cp Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	@cp Resources/MenuBarIcon.png $(APP_BUNDLE)/Contents/Resources/MenuBarIcon.png
	@codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "App bundle built: $(APP_BUNDLE)"

install-app: app
	@rm -rf $(APPLICATIONS_DIR)/$(APP_NAME)
	@cp -R $(APP_BUNDLE) $(APPLICATIONS_DIR)/
	@echo "Installed $(APP_NAME) to $(APPLICATIONS_DIR)/$(APP_NAME)"

dmg: app
	@rm -rf $(BUILD_DIR)/dmg-staging $(BUILD_DIR)/AirSwitch.dmg
	@mkdir -p $(BUILD_DIR)/dmg-staging
	@cp -R $(APP_BUNDLE) $(BUILD_DIR)/dmg-staging/
	@ln -s /Applications $(BUILD_DIR)/dmg-staging/Applications
	@hdiutil create -volname "AirSwitch" -srcfolder $(BUILD_DIR)/dmg-staging -ov -format UDZO $(BUILD_DIR)/AirSwitch.dmg
	@rm -rf $(BUILD_DIR)/dmg-staging
	@echo "DMG created: $(BUILD_DIR)/AirSwitch.dmg"

set-version:
	@if [ -z "$(VERSION)" ]; then echo "Usage: make set-version VERSION=0.1.0"; exit 1; fi
	@CLEAN_VER=$$(echo "$(VERSION)" | sed 's/^v//'); \
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $$CLEAN_VER" Resources/Info.plist; \
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $$CLEAN_VER" Resources/Info.plist; \
	sed -i '' -E "s/fallbackVersion = \"[^\"]+\"/fallbackVersion = \"$$CLEAN_VER\"/" Sources/AirSwitchKit/Config/AppConstants.swift; \
	echo "Version set to $$CLEAN_VER"

release:
	@LATEST_TAG=$$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"); \
	CURRENT_VER=$${LATEST_TAG#v}; \
	if [ -n "$(VERSION)" ]; then \
		NEXT_VER=$$(echo "$(VERSION)" | sed 's/^v//'); \
	else \
		NEXT_VER=$$(echo "$$CURRENT_VER" | awk -F. '{print $$1"."$$2"."$$3+1}'); \
	fi; \
	git tag -a "v$$NEXT_VER" -m "Release v$$NEXT_VER"; \
	git push origin "v$$NEXT_VER"; \
	echo "Released v$$NEXT_VER! GitHub Actions will now build and publish the release."

test:
	@swift test

install: build
	@mkdir -p $(INSTALL_DIR)
	@cp $(BUILD_DIR)/$(BIN_NAME) $(INSTALL_DIR)/$(BIN_NAME)
	@echo "Installed $(BIN_NAME) to $(INSTALL_DIR)/$(BIN_NAME)"

uninstall: stop
	@rm -f $(INSTALL_DIR)/$(BIN_NAME)
	@rm -rf $(APPLICATIONS_DIR)/$(APP_NAME)
	@echo "Uninstalled $(BIN_NAME) and $(APP_NAME)"

run: install
	@nohup $(INSTALL_DIR)/$(BIN_NAME) >/dev/null 2>&1 &
	@echo "AirSwitch started in background. Press ⌃⌥A to toggle connection."

stop:
	@-pkill -f "$(BIN_NAME)" 2>/dev/null || true
	@echo "AirSwitch stopped."

clean:
	@rm -rf .build $(BUILD_DIR)
	@echo "Cleaned build artifacts."

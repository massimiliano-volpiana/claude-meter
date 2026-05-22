TEAM_ID      := 8KZ465VM76
BUNDLE_ID    := it.inrisalto.ClaudeMeter
CONFIG       ?= release
BUILD        := .build/apple/Products/Release

APP          := $(BUILD)/ClaudeMeter.app
CONTENTS     := $(APP)/Contents
MACOS        := $(CONTENTS)/MacOS
RESOURCES    := $(CONTENTS)/Resources

SIGN_ID      := $(shell security find-identity -v -p codesigning 2>/dev/null \
                  | grep "$(TEAM_ID)" | head -1 \
                  | sed 's/.*"\(.*\)".*/\1/')

.PHONY: build run clean install

# ── Build & bundle ─────────────────────────────────────────────────────────────

build:
	@echo "→ Compiling Swift sources (universal)..."
	swift build -c $(CONFIG) --arch arm64 --arch x86_64

	@echo "→ Creating bundle structure..."
	mkdir -p $(MACOS) $(RESOURCES)

	@echo "→ Copying executable..."
	cp $(BUILD)/ClaudeMeter $(MACOS)/ClaudeMeter

	@echo "→ Copying Info.plist..."
	cp Sources/ClaudeMeter/Info.plist $(CONTENTS)/Info.plist

	@echo "→ Building app icon..."
	@mkdir -p /tmp/ClaudeMeter.iconset
	@cp Sources/ClaudeMeter/Assets.xcassets/AppIcon.appiconset/icon_16.png   /tmp/ClaudeMeter.iconset/icon_16x16.png
	@cp Sources/ClaudeMeter/Assets.xcassets/AppIcon.appiconset/icon_32.png   /tmp/ClaudeMeter.iconset/icon_16x16@2x.png
	@cp Sources/ClaudeMeter/Assets.xcassets/AppIcon.appiconset/icon_32.png   /tmp/ClaudeMeter.iconset/icon_32x32.png
	@cp Sources/ClaudeMeter/Assets.xcassets/AppIcon.appiconset/icon_64.png   /tmp/ClaudeMeter.iconset/icon_32x32@2x.png
	@cp Sources/ClaudeMeter/Assets.xcassets/AppIcon.appiconset/icon_128.png  /tmp/ClaudeMeter.iconset/icon_128x128.png
	@cp Sources/ClaudeMeter/Assets.xcassets/AppIcon.appiconset/icon_256.png  /tmp/ClaudeMeter.iconset/icon_128x128@2x.png
	@cp Sources/ClaudeMeter/Assets.xcassets/AppIcon.appiconset/icon_256.png  /tmp/ClaudeMeter.iconset/icon_256x256.png
	@cp Sources/ClaudeMeter/Assets.xcassets/AppIcon.appiconset/icon_512.png  /tmp/ClaudeMeter.iconset/icon_256x256@2x.png
	@cp Sources/ClaudeMeter/Assets.xcassets/AppIcon.appiconset/icon_512.png  /tmp/ClaudeMeter.iconset/icon_512x512.png
	@cp Sources/ClaudeMeter/Assets.xcassets/AppIcon.appiconset/icon_1024.png /tmp/ClaudeMeter.iconset/icon_512x512@2x.png
	@iconutil -c icns /tmp/ClaudeMeter.iconset -o $(RESOURCES)/AppIcon.icns

	@echo "→ Signing app..."
	codesign --force --sign "$(SIGN_ID)" \
		--entitlements Sources/ClaudeMeter/ClaudeMeter.entitlements \
		$(APP)

	@echo "✓ Built: $(APP)"

# ── Run ────────────────────────────────────────────────────────────────────────

run: build
	open $(APP)

# ── Install to /Applications ──────────────────────────────────────────────────

install: build
	rm -rf /Applications/ClaudeMeter.app
	cp -R $(APP) /Applications/ClaudeMeter.app
	@echo "✓ Installed to /Applications/ClaudeMeter.app"

# ── Clean ─────────────────────────────────────────────────────────────────────

clean:
	swift package clean
	rm -rf .build/apple $(BUILD)/ClaudeMeter.app

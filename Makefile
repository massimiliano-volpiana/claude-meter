TEAM_ID      := 8KZ465VM76
BUNDLE_ID    := it.inrisalto.ClaudeMeter
WIDGET_ID    := it.inrisalto.ClaudeMeter.widget
CONFIG       ?= release
BUILD        := .build/$(CONFIG)

APP          := $(BUILD)/ClaudeMeter.app
CONTENTS     := $(APP)/Contents
MACOS        := $(CONTENTS)/MacOS
RESOURCES    := $(CONTENTS)/Resources
PLUGINS      := $(CONTENTS)/PlugIns
APPEX        := $(PLUGINS)/ClaudeMeterWidget.appex
APPEX_MACOS  := $(APPEX)/Contents/MacOS

SIGN_ID      := $(shell security find-identity -v -p codesigning 2>/dev/null \
                  | grep "$(TEAM_ID)" | head -1 \
                  | sed 's/.*"\(.*\)".*/\1/')

.PHONY: build run clean install

# ── Build & bundle ─────────────────────────────────────────────────────────────

build:
	@echo "→ Compiling Swift sources..."
	swift build -c $(CONFIG)

	@echo "→ Creating bundle structure..."
	mkdir -p $(MACOS) $(RESOURCES) $(APPEX_MACOS)

	@echo "→ Copying executables..."
	cp $(BUILD)/ClaudeMeter       $(MACOS)/ClaudeMeter
	cp $(BUILD)/ClaudeMeterWidget $(APPEX_MACOS)/ClaudeMeterWidget

	@echo "→ Copying Info.plists..."
	cp Sources/ClaudeMeter/Info.plist       $(CONTENTS)/Info.plist
	cp Sources/ClaudeMeterWidget/Info.plist $(APPEX)/Contents/Info.plist

	@echo "→ Building app icon..."
	@mkdir -p /tmp/ClaudeMeter.iconset
	@cp icon_pngs/icon_16.png   /tmp/ClaudeMeter.iconset/icon_16x16.png
	@cp icon_pngs/icon_32.png   /tmp/ClaudeMeter.iconset/icon_16x16@2x.png
	@cp icon_pngs/icon_32.png   /tmp/ClaudeMeter.iconset/icon_32x32.png
	@cp icon_pngs/icon_64.png   /tmp/ClaudeMeter.iconset/icon_32x32@2x.png
	@cp icon_pngs/icon_128.png  /tmp/ClaudeMeter.iconset/icon_128x128.png
	@cp icon_pngs/icon_256.png  /tmp/ClaudeMeter.iconset/icon_128x128@2x.png
	@cp icon_pngs/icon_256.png  /tmp/ClaudeMeter.iconset/icon_256x256.png
	@cp icon_pngs/icon_512.png  /tmp/ClaudeMeter.iconset/icon_256x256@2x.png
	@cp icon_pngs/icon_512.png  /tmp/ClaudeMeter.iconset/icon_512x512.png
	@cp icon_pngs/icon_1024.png /tmp/ClaudeMeter.iconset/icon_512x512@2x.png
	@iconutil -c icns /tmp/ClaudeMeter.iconset -o $(RESOURCES)/AppIcon.icns

	@echo "→ Signing widget..."
	codesign --force --sign "$(SIGN_ID)" \
		--entitlements Sources/ClaudeMeterWidget/ClaudeMeterWidget.entitlements \
		$(APPEX)

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
	rm -rf $(BUILD)/ClaudeMeter.app

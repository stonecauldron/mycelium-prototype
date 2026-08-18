GODOT ?= godot
PORT ?= 8060
BUTLER ?= butler
ITCH_TARGET := cauldron/auto-shrooms:html
STEAMCMD := /Users/cauldron/Steamworks/steamcmd.sh
STEAM_USERNAME := octet_

WEB_DIR := build/web
WEB_HTML := $(WEB_DIR)/index.html
MACOS_APP := build/macos/AutoShrooms.app
WINDOWS_EXE := build/windows/AutoShrooms.exe
STEAM_STAGE := build/steam-output
GIT_DESC := $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)

.PHONY: all help \
	build-web run-web open-web upload-web \
	build-macos run-macos build-windows \
	upload-steam clean

all: help

help:
	@echo "Targets:"
	@echo "  make build-web      Export the Web preset to $(WEB_HTML)"
	@echo "  make run-web        Export Web, then serve locally on port $(PORT)"
	@echo "  make open-web       Same as run-web, and open the default browser"
	@echo "  make upload-web     Export Web, then push to itch.io ($(ITCH_TARGET))"
	@echo "  make build-macos    Export macOS to $(MACOS_APP)"
	@echo "  make run-macos      Export macOS, then open the .app"
	@echo "  make build-windows  Export Windows to $(WINDOWS_EXE)"
	@echo "  make upload-steam   Export macOS + Windows, then steamcmd to Steam Demo 5112860"
	@echo "  make clean          Remove build/"
	@echo ""
	@echo "Overrides: GODOT=$(GODOT) PORT=$(PORT) BUTLER=$(BUTLER)"
	@echo "SteamCMD cannot SetLive the default branch; set the new build live in Steamworks after upload."

build-web:
	@mkdir -p "$(WEB_DIR)"
	"$(GODOT)" --headless --path . --export-release "Web" "$(WEB_HTML)"
	@cp addons/GameAnalytics/web/GameAnalytics.js "$(WEB_DIR)/GameAnalytics.js"
	@echo "Exported → $(WEB_HTML)"

run-web: build-web
	@echo "Serving $(WEB_DIR) at http://localhost:$(PORT)"
	@echo "Press Ctrl+C to stop."
	python3 -m http.server "$(PORT)" --directory "$(WEB_DIR)"

open-web: build-web
	@echo "Serving $(WEB_DIR) at http://localhost:$(PORT)"
	@python3 -m http.server "$(PORT)" --directory "$(WEB_DIR)" & \
		server_pid=$$!; \
		sleep 0.5; \
		open "http://localhost:$(PORT)"; \
		wait $$server_pid

upload-web: build-web
	"$(BUTLER)" push "$(WEB_DIR)" "$(ITCH_TARGET)"

build-macos:
	@mkdir -p build/macos
	"$(GODOT)" --headless --path . --export-release "macOS" "$(MACOS_APP)"
	@echo "Exported → $(MACOS_APP)"

run-macos: build-macos
	open "$(MACOS_APP)"

build-windows:
	@mkdir -p build/windows
	"$(GODOT)" --headless --path . --export-release "Windows Desktop" "$(WINDOWS_EXE)"
	@echo "Exported → $(WINDOWS_EXE)"

upload-steam: build-macos build-windows
	@test -x "$(STEAMCMD)" || { echo "Missing $(STEAMCMD)"; exit 1; }
	@test -d "$(MACOS_APP)" || { echo "Missing $(MACOS_APP)"; exit 1; }
	@test -f "$(WINDOWS_EXE)" || { echo "Missing $(WINDOWS_EXE)"; exit 1; }
	@mkdir -p "$(STEAM_STAGE)"
	@sed \
		-e 's|__DESC__|$(GIT_DESC)|' \
		-e 's|__BUILD_OUTPUT__|$(abspath $(STEAM_STAGE))|' \
		steam/demo/app_build.vdf > "$(STEAM_STAGE)/app_build.vdf"
	@sed -e 's|__CONTENT_ROOT__|$(abspath build/windows)|' \
		steam/demo/depot_windows.vdf > "$(STEAM_STAGE)/depot_windows.vdf"
	@sed -e 's|__CONTENT_ROOT__|$(abspath build/macos)|' \
		steam/demo/depot_macos.vdf > "$(STEAM_STAGE)/depot_macos.vdf"
	"$(STEAMCMD)" +login "$(STEAM_USERNAME)" +run_app_build "$(abspath $(STEAM_STAGE)/app_build.vdf)" +quit

clean:
	rm -rf build

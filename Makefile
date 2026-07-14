GODOT ?= godot
PRESET ?= Web
BUILD_DIR := build/web
EXPORT_HTML := $(BUILD_DIR)/index.html
PORT ?= 8060

.PHONY: all build run serve open clean help

all: build

help:
	@echo "Targets:"
	@echo "  make build   Export the Web preset to $(EXPORT_HTML)"
	@echo "  make run     Export, then serve locally on port $(PORT)"
	@echo "  make open    Same as run, and open the default browser"
	@echo "  make clean   Remove build/"
	@echo ""
	@echo "Overrides: GODOT=$(GODOT) PORT=$(PORT) PRESET=$(PRESET)"

build:
	@mkdir -p "$(BUILD_DIR)"
	"$(GODOT)" --headless --path . --export-release "$(PRESET)" "$(EXPORT_HTML)"
	@echo "Exported → $(EXPORT_HTML)"

run: build
	@echo "Serving $(BUILD_DIR) at http://localhost:$(PORT)"
	@echo "Press Ctrl+C to stop."
	python3 -m http.server "$(PORT)" --directory "$(BUILD_DIR)"

open: build
	@echo "Serving $(BUILD_DIR) at http://localhost:$(PORT)"
	@python3 -m http.server "$(PORT)" --directory "$(BUILD_DIR)" & \
		server_pid=$$!; \
		sleep 0.5; \
		open "http://localhost:$(PORT)"; \
		wait $$server_pid

serve: run

clean:
	rm -rf build

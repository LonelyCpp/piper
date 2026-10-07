.DEFAULT_GOAL := help

APP_NAME := Piper
BUILD_DIR := build

.PHONY: help
help: ## Show available targets
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

# --- quality ----------------------------------------------------------------

SWIFTFORMAT := $(shell command -v swiftformat 2>/dev/null)
SWIFTLINT := $(shell command -v swiftlint 2>/dev/null)

# Each guard is a single recipe line: make runs every line in its own shell, so
# an `exit` in one line does not stop the next from running with an empty value.

.PHONY: lint
lint: ## Lint sources with swiftlint
	@if [ -z "$(SWIFTLINT)" ]; then echo "swiftlint not installed — brew install swiftlint"; exit 1; else $(SWIFTLINT) lint --strict; fi

.PHONY: format
format: ## Format sources in place with swiftformat
	@if [ -z "$(SWIFTFORMAT)" ]; then echo "swiftformat not installed — brew install swiftformat"; exit 1; else $(SWIFTFORMAT) .; fi

.PHONY: format-check
format-check: ## Verify formatting without writing
	@if [ -z "$(SWIFTFORMAT)" ]; then echo "swiftformat not installed — skipping"; exit 0; else $(SWIFTFORMAT) --lint .; fi

.PHONY: check
check: build lint format-check ## Build, lint, and verify formatting

# --- build ------------------------------------------------------------------

.PHONY: build
build: ## Debug build
	swift build

.PHONY: release
release: ## Release build
	swift build -c release

.PHONY: bundle
bundle: ## Assemble build/Piper.app (release)
	@Scripts/bundle.sh release | tail -1

.PHONY: run
run: ## Assemble + launch a debug Piper.app
	@Scripts/dev.sh

.PHONY: install
install: ## Build release bundle and copy to /Applications (asks for sudo)
	@Scripts/bundle.sh release | tail -1
	@sudo ditto "$(BUILD_DIR)/$(APP_NAME).app" "/Applications/$(APP_NAME).app"
	@echo "Installed /Applications/$(APP_NAME).app"

.PHONY: uninstall
uninstall: ## Remove /Applications/Piper.app (asks for sudo)
	@sudo rm -rf "/Applications/$(APP_NAME).app"
	@echo "Removed /Applications/$(APP_NAME).app"

.PHONY: clean
clean: ## Remove build artifacts
	rm -rf .build $(BUILD_DIR)

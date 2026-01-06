# Define a directory for dependencies in the user's home folder
DEPS_DIR := $(HOME)/VoiceInk-Dependencies
WHISPER_CPP_DIR := $(DEPS_DIR)/whisper.cpp
FRAMEWORK_PATH := $(WHISPER_CPP_DIR)/build-apple/whisper.xcframework

.PHONY: all clean whisper setup build build-debug build-release check healthcheck help dev run install install-local clean-derived list open logs launch

# Default target
all: check build

# Development workflow
dev: build run

# Prerequisites
check:
	@echo "Checking prerequisites..."
	@command -v git >/dev/null 2>&1 || { echo "git is not installed"; exit 1; }
	@command -v xcodebuild >/dev/null 2>&1 || { echo "xcodebuild is not installed (need Xcode)"; exit 1; }
	@command -v swift >/dev/null 2>&1 || { echo "swift is not installed"; exit 1; }
	@echo "Prerequisites OK"

healthcheck: check

# Build process
whisper:
	@mkdir -p $(DEPS_DIR)
	@if [ ! -d "$(FRAMEWORK_PATH)" ]; then \
		echo "Building whisper.xcframework in $(DEPS_DIR)..."; \
		if [ ! -d "$(WHISPER_CPP_DIR)" ]; then \
			git clone https://github.com/ggerganov/whisper.cpp.git $(WHISPER_CPP_DIR); \
		else \
			(cd $(WHISPER_CPP_DIR) && git pull); \
		fi; \
		cd $(WHISPER_CPP_DIR) && ./build-xcframework.sh; \
	else \
		echo "whisper.xcframework already built in $(DEPS_DIR), skipping build"; \
	fi

setup: whisper
	@echo "Whisper framework is ready at $(FRAMEWORK_PATH)"
	@echo "Please ensure your Xcode project references the framework from this new location."

# Common xcodebuild flags for unsigned local builds
UNSIGNED_FLAGS := CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

build: build-debug

build-debug: setup
	xcodebuild -scheme VoiceInk -configuration Debug $(UNSIGNED_FLAGS) build

build-release: setup
	xcodebuild -scheme VoiceInk -configuration Release $(UNSIGNED_FLAGS) build

# Run application
run:
	@echo "Looking for VoiceInk.app..."
	@APP_PATH=$$(find "$$HOME/Library/Developer/Xcode/DerivedData" -name "VoiceInk.app" -type d | head -1) && \
	if [ -n "$$APP_PATH" ]; then \
		echo "Found app at: $$APP_PATH"; \
		open "$$APP_PATH"; \
	else \
		echo "VoiceInk.app not found. Please run 'make build' first."; \
		exit 1; \
	fi

# Launch installed app from ~/Applications
launch:
	@if [ -d ~/Applications/VoiceInk.app ]; then \
		open ~/Applications/VoiceInk.app; \
	else \
		echo "VoiceInk.app not found in ~/Applications. Run 'make install-local' first."; \
		exit 1; \
	fi

# Stream app logs (Ctrl+C to stop)
logs:
	@echo "Streaming VoiceInk logs (Ctrl+C to stop)..."
	@log stream --predicate 'subsystem == "com.prakashjoshipax.VoiceInk" OR process == "VoiceInk"' --level debug

# Cleanup
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(DEPS_DIR)
	@echo "Clean complete"

# Clean Xcode DerivedData for this project
clean-derived:
	@echo "Cleaning DerivedData for VoiceInk..."
	@rm -rf ~/Library/Developer/Xcode/DerivedData/VoiceInk-*
	@echo "DerivedData cleaned"

# Install release build to ~/Applications
install: build-release
	@echo "Installing to ~/Applications..."
	@mkdir -p ~/Applications
	@rm -rf ~/Applications/VoiceInk.app
	@APP_PATH=$$(find ~/Library/Developer/Xcode/DerivedData -path "*/Release/VoiceInk.app" -type d | head -1) && \
	if [ -n "$$APP_PATH" ]; then \
		cp -R "$$APP_PATH" ~/Applications/; \
		echo "Installed to ~/Applications/VoiceInk.app"; \
	else \
		echo "Release build not found. Run 'make build-release' first."; \
		exit 1; \
	fi

# Install debug build to ~/Applications (dev icon, license bypassed)
install-local: build-debug
	@echo "Installing local dev build to ~/Applications..."
	@mkdir -p ~/Applications
	@rm -rf ~/Applications/VoiceInk.app
	@APP_PATH=$$(find ~/Library/Developer/Xcode/DerivedData -path "*/Debug/VoiceInk.app" -type d | head -1) && \
	if [ -n "$$APP_PATH" ]; then \
		cp -R "$$APP_PATH" ~/Applications/; \
		echo "Installed local dev build to ~/Applications/VoiceInk.app"; \
	else \
		echo "Debug build not found. Run 'make build-debug' first."; \
		exit 1; \
	fi

# List available schemes
list:
	@xcodebuild -list

# Open project in Xcode
open:
	@open VoiceInk.xcodeproj

# Help
help:
	@echo "Available targets:"
	@echo ""
	@echo "  Build:"
	@echo "    build            Build debug (unsigned, alias for build-debug)"
	@echo "    build-debug      Build debug configuration (unsigned)"
	@echo "    build-release    Build release configuration (unsigned)"
	@echo "    install          Build release and install to ~/Applications"
	@echo "    install-local    Build debug and install to ~/Applications (dev icon, no license)"
	@echo ""
	@echo "  Development:"
	@echo "    dev              Build and run the app"
	@echo "    run              Launch the built VoiceInk app"
	@echo "    launch           Launch installed app from ~/Applications"
	@echo "    logs             Stream app logs (Ctrl+C to stop)"
	@echo "    open             Open project in Xcode"
	@echo "    list             List available schemes"
	@echo ""
	@echo "  Setup:"
	@echo "    check            Check if required CLI tools are installed"
	@echo "    healthcheck      Alias for check"
	@echo "    whisper          Clone and build whisper.cpp XCFramework"
	@echo "    setup            Ensure whisper XCFramework is ready"
	@echo ""
	@echo "  Cleanup:"
	@echo "    clean            Remove whisper dependencies"
	@echo "    clean-derived    Remove Xcode DerivedData for this project"
	@echo ""
	@echo "  all                Run full build process (default)"
	@echo "  help               Show this help message"
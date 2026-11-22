SCHEME = Saathi
# First available iPhone simulator on this Mac; override with `make test SIM_ID=<udid>`
# or `make test DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro"`.
SIM_ID ?= $(shell xcrun simctl list devices available | grep -m1 -E '^[[:space:]]+iPhone' | grep -oE '[0-9A-F-]{36}')
DESTINATION ?= platform=iOS Simulator,id=$(SIM_ID)
FRAMES_DIR = docs/frames
RESULT_BUNDLE = build/SaathiFrames.xcresult

.PHONY: generate core-test test privacy-test frames clean

generate:
	xcodegen generate --spec project.yml

# Fast: SaathiCore engine + privacy tests on macOS via SwiftPM (no simulator needed).
core-test:
	swift test

test:
	xcodebuild test -project Saathi.xcodeproj -scheme $(SCHEME) -destination "$(DESTINATION)" -only-testing:SaathiTests

privacy-test:
	xcodebuild test -project Saathi.xcodeproj -scheme $(SCHEME) -destination "$(DESTINATION)" -only-testing:SaathiTests/PrivacyAndNetworkTests

# xcodebuild only forwards environment variables to the test runner when they are
# prefixed with TEST_RUNNER_, so the UI tests see SAATHI_FRAMES_OUT.
BUNDLE_ID = com.saathiCompanion.app

frames:
	mkdir -p $(FRAMES_DIR) build
	rm -rf $(RESULT_BUNDLE)
	# Pre-grant motion so the AirPods permission alert doesn't cover the screenshots.
	-xcrun simctl boot $(SIM_ID) 2>/dev/null
	-xcrun simctl privacy $(SIM_ID) grant motion $(BUNDLE_ID)
	TEST_RUNNER_SAATHI_FRAMES_OUT="$(abspath $(FRAMES_DIR))" xcodebuild test \
		-project Saathi.xcodeproj \
		-scheme $(SCHEME) \
		-destination "$(DESTINATION)" \
		-only-testing:SaathiUITests \
		-resultBundlePath $(RESULT_BUNDLE)
	@echo "Key frames exported to $(FRAMES_DIR)"

clean:
	rm -rf build

# Command surface for building and testing RideOrNah. Agents, humans and CI use these targets
# instead of raw xcodebuild invocations.

PROJECT := RideOrNah.xcodeproj
SCHEME := RideOrNah
KIT := Packages/RideOrNahKit
CONFIGURATION ?= Debug

# `make test` runs the UI tests on the oldest supported iOS and the newest, then the watch app's
# UI tests on the newest watchOS. Override with SIM_OLDEST=... SIM_LATEST=... WATCH_SIM=... if
# needed, or set DESTINATION to run the iPhone tests on one simulator only:
#   make test DESTINATION="$(scripts/find-simulator.sh 'iPhone 17' 26)"
# and WATCH_DESTINATION to run the watch tests on another watch:
#   make test-watch WATCH_DESTINATION="$(scripts/find-simulator.sh 'Apple Watch Series 11 (46mm)' 26 watchOS)"
# The defaults are looked up by ID when the tests run: a destination given only by name means
# the latest OS to xcodebuild, so it would skip the iOS 26 simulator.
SIM_OLDEST ?= $$(scripts/find-simulator.sh 'RideOrNah iOS 26' 26)
SIM_LATEST ?= $$(scripts/find-simulator.sh 'RideOrNah iOS 27' 27)
WATCH_SIM ?= $$(scripts/find-simulator.sh 'RideOrNah watchOS 27' 27 watchOS)
DESTINATION ?=
WATCH_DESTINATION ?=
RESULT_BUNDLE ?= build/UITests.xcresult

# OpenSpec from PATH, or the version this repo's OpenSpec skills were generated with. Its
# telemetry is turned off for every run.
OPENSPEC := OPENSPEC_TELEMETRY=0 $(shell command -v openspec >/dev/null 2>&1 \
	&& echo openspec || echo npx -y @fission-ai/openspec@1.13.2)

# Tracked and new Swift files, so generated and build output is never formatted. The style
# lives in .swift-format and the formatter is the one that ships with Xcode.
SWIFT_FILES = $(shell git ls-files --cached --others --exclude-standard '*.swift')

# With DESTINATION set, `make test` runs the iPhone tests there and skips the watch.
ifeq ($(DESTINATION),)
TEST_SETUP := simulators
TEST_DESTINATIONS := -destination "$(SIM_OLDEST)" -destination "$(SIM_LATEST)"
TEST_WATCH := test-watch
else
TEST_SETUP :=
TEST_DESTINATIONS := -destination "$(DESTINATION)"
TEST_WATCH :=
endif

ifeq ($(WATCH_DESTINATION),)
WATCH_SETUP := simulators
WATCH_TEST_DESTINATION := $(WATCH_SIM)
else
WATCH_SETUP :=
WATCH_TEST_DESTINATION := $(WATCH_DESTINATION)
endif

.PHONY: help project simulators build test test-ios test-watch test-release test-kit audit lint format \
	validate-specs spec-coverage

help:
	@echo "make project     Generate $(PROJECT) from project.yml"
	@echo "make simulators  Create the RideOrNah iOS 26, iOS 27 and watchOS 27 simulators if missing"
	@echo "make build       Build the app for the iOS Simulator (CONFIGURATION=$(CONFIGURATION))"
	@echo "make test        Run UI tests on the iOS 26 and iOS 27 simulators, then the watch's"
	@echo "                 (DESTINATION=... runs the iPhone tests there only)"
	@echo "make test-ios    Run only the iPhone tests"
	@echo "make test-watch  Run only the watch app's UI tests, on watchOS 27 or WATCH_DESTINATION"
	@echo "make test-release  Check a Release build has no debug-only code, on the same simulators"
	@echo "make test-kit    Run RideOrNahKit's Swift tests on this Mac"
	@echo "make audit       Fail if any remote package dependency is present"
	@echo "make lint        Fail if any Swift file doesn't match .swift-format"
	@echo "make format      Rewrite Swift files to match .swift-format"
	@echo "make validate-specs  Run openspec validate --all --strict"
	@echo "make spec-coverage   Fail if a spec scenario has no linked test or manual check"
	@echo "                     (CHANGE=<name> also requires that change's scenarios)"

project:
	@command -v xcodegen >/dev/null 2>&1 || { \
		echo "error: XcodeGen is not installed. Install it with: brew install xcodegen" >&2; \
		exit 1; }
	@xcodegen generate --quiet

simulators:
	@scripts/create-simulators.sh

build: project
	xcodebuild build -quiet -project $(PROJECT) -scheme $(SCHEME) \
		-configuration $(CONFIGURATION) -destination 'generic/platform=iOS Simulator'

test: test-ios $(TEST_WATCH)

test-ios: project $(TEST_SETUP)
	@rm -rf $(RESULT_BUNDLE)
	xcodebuild test -quiet -project $(PROJECT) -scheme $(SCHEME) \
		$(TEST_DESTINATIONS) -resultBundlePath $(RESULT_BUNDLE)

test-watch: project $(WATCH_SETUP)
	@rm -rf build/WatchUITests.xcresult
	xcodebuild test -quiet -project $(PROJECT) -scheme RideOrNahWatch \
		-destination "$(WATCH_TEST_DESTINATION)" -resultBundlePath build/WatchUITests.xcresult

# Release builds compile out debug-only code (fixture weather, the pipeline screen); this runs
# the UI test that checks it against a Release build.
test-release: project $(TEST_SETUP)
	@rm -rf build/ReleaseUITests.xcresult
	xcodebuild test -quiet -project $(PROJECT) -scheme RideOrNahRelease -configuration Release \
		$(TEST_DESTINATIONS) -only-testing:RideOrNahUITests/ReleaseBuildTests \
		-resultBundlePath build/ReleaseUITests.xcresult

test-kit:
	swift test --package-path $(KIT)

audit:
	@scripts/audit-dependencies.sh

lint:
	xcrun swift-format lint --strict --parallel $(SWIFT_FILES)

format:
	xcrun swift-format format --in-place --parallel $(SWIFT_FILES)

validate-specs:
	$(OPENSPEC) validate --all --strict

# Links are `// Scenario: <capability>: <scenario name>` comments above tests; scenarios no test
# can reach are listed in docs/manual-checks.md. Run with CHANGE=<name> before archiving it.
spec-coverage:
	@scripts/check-spec-coverage.sh $(if $(CHANGE),--change $(CHANGE))

# App Store Connect, through the pinned `asc` CLI. Setup and key handling: docs/app-store-connect.md
# Read-only: asc refuses any request that would change data, and sends no telemetry.
#   make asc-status      Check the stored API key against Apple
#   make asc-apps        List the team's apps
#   make asc-bundle-ids  List the team's bundle IDs
.PHONY: asc-check asc-status asc-apps asc-bundle-ids

ASC := ASC_READ_ONLY=1 asc --no-telemetry

asc-check:
	@command -v asc >/dev/null 2>&1 || { \
		echo "error: asc is not installed. See docs/app-store-connect.md" >&2; \
		exit 1; }

asc-status: asc-check
	@$(ASC) auth status --validate --output table

asc-apps: asc-check
	@$(ASC) apps list --paginate --output table

asc-bundle-ids: asc-check
	@$(ASC) bundle-ids list --paginate --output table

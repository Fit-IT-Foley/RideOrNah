# Command surface for building and testing RideOrNah. Agents, humans and CI use these targets
# instead of raw xcodebuild invocations.

PROJECT := RideOrNah.xcodeproj
SCHEME := RideOrNah
KIT := Packages/RideOrNahKit
CONFIGURATION ?= Debug

# `make test` runs the UI tests on the oldest supported iOS and the newest. Override with
# SIM_OLDEST=... SIM_LATEST=... if needed, or set DESTINATION to run on one simulator only:
#   make test DESTINATION="$(scripts/find-simulator.sh 'iPhone 17' 26)"
# The defaults are looked up by ID when the tests run: a destination given only by name means
# the latest OS to xcodebuild, so it would skip the iOS 26 simulator.
SIM_OLDEST ?= $$(scripts/find-simulator.sh 'RideOrNah iOS 26' 26)
SIM_LATEST ?= $$(scripts/find-simulator.sh 'RideOrNah iOS 27' 27)
DESTINATION ?=
RESULT_BUNDLE ?= build/UITests.xcresult

# OpenSpec from PATH, or the version this repo's OpenSpec skills were generated with. Its
# telemetry is turned off for every run.
OPENSPEC := OPENSPEC_TELEMETRY=0 $(shell command -v openspec >/dev/null 2>&1 \
	&& echo openspec || echo npx -y @fission-ai/openspec@1.13.2)

# Tracked and new Swift files, so generated and build output is never formatted. The style
# lives in .swift-format and the formatter is the one that ships with Xcode.
SWIFT_FILES = $(shell git ls-files --cached --others --exclude-standard '*.swift')

ifeq ($(DESTINATION),)
TEST_SETUP := simulators
TEST_DESTINATIONS := -destination "$(SIM_OLDEST)" -destination "$(SIM_LATEST)"
else
TEST_SETUP :=
TEST_DESTINATIONS := -destination "$(DESTINATION)"
endif

.PHONY: help project simulators build test test-kit audit lint format validate-specs

help:
	@echo "make project     Generate $(PROJECT) from project.yml"
	@echo "make simulators  Create the RideOrNah iOS 26 and iOS 27 simulators if missing"
	@echo "make build       Build the app for the iOS Simulator (CONFIGURATION=$(CONFIGURATION))"
	@echo "make test        Run UI tests on the iOS 26 and iOS 27 simulators, or on DESTINATION"
	@echo "make test-kit    Run RideOrNahKit's Swift tests on this Mac"
	@echo "make audit       Fail if any remote package dependency is present"
	@echo "make lint        Fail if any Swift file doesn't match .swift-format"
	@echo "make format      Rewrite Swift files to match .swift-format"
	@echo "make validate-specs  Run openspec validate --all --strict"

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

test: project $(TEST_SETUP)
	@rm -rf $(RESULT_BUNDLE)
	xcodebuild test -quiet -project $(PROJECT) -scheme $(SCHEME) \
		$(TEST_DESTINATIONS) -resultBundlePath $(RESULT_BUNDLE)

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

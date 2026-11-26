#!/bin/sh
# Checks that every scenario in openspec/specs is linked to a test, or listed in
# docs/manual-checks.md when no automated test can reach it. A test links to each scenario it
# proves with a comment on its own line directly above the test:
#   // Scenario: app-platform: Install on the oldest supported OS
#
#   scripts/check-spec-coverage.sh                   every main-spec scenario must be covered
#   scripts/check-spec-coverage.sh --change <name>   ...and every scenario in that change too
#
# Tests may link to scenarios in active changes before those are archived. A link or manual
# check naming a scenario that exists nowhere fails, so a rename can't leave tests behind.
# Paths with spaces aren't supported.
set -eu
cd "$(dirname "$0")/.."

manual=docs/manual-checks.md
change=
if [ "${1:-}" = "--change" ]; then
	change=${2:-}
	if [ -z "$change" ] || [ ! -d "openspec/changes/$change" ] || [ "$change" = archive ]; then
		echo "error: no active change named '$change' in openspec/changes" >&2
		exit 2
	fi
elif [ $# -gt 0 ]; then
	echo "usage: $0 [--change <name>]" >&2
	exit 2
fi

# Prints "<tag>	<capability>: <scenario>	<file>:<line>" for each scenario header in the given
# spec files. The capability is the spec's path under its specs/ directory.
scenarios() {
	tag=$1
	shift
	for file in "$@"; do
		awk -v tag="$tag" '
			FNR == 1 {
				capability = FILENAME
				sub(/.*\/specs\//, "", capability)
				sub(/\/spec\.md$/, "", capability)
			}
			/^#### Scenario:/ {
				name = $0
				sub(/^#### Scenario:[ \t]*/, "", name)
				sub(/[ \t]+$/, "", name)
				printf "%s\t%s: %s\t%s:%d\n", tag, capability, name, FILENAME, FNR
			}' "$file"
	done
}

# Prints "test	<capability>: <scenario>	<file>:<line>" for each link comment in the given files.
links() {
	for file in "$@"; do
		awk '
			/^[ \t]*\/\/ Scenario:/ {
				ref = $0
				sub(/^[ \t]*\/\/ Scenario:[ \t]*/, "", ref)
				sub(/[ \t]+$/, "", ref)
				printf "test\t%s\t%s:%d\n", ref, FILENAME, FNR
			}' "$file"
	done
}

# Prints "manual	<capability>: <scenario>	<file>:<line>" for each `## ` heading in the manual checks.
manual_checks() {
	[ -f "$manual" ] || return 0
	awk '
		/^## / {
			ref = $0
			sub(/^## +/, "", ref)
			sub(/[ \t]+$/, "", ref)
			printf "manual\t%s\t%s:%d\n", ref, FILENAME, FNR
		}' "$manual"
}

main_specs=$(find openspec/specs -name spec.md | sort)
change_specs=$(find openspec/changes -path openspec/changes/archive -prune -o -name spec.md -print | sort)
required_change_specs=
[ -z "$change" ] || required_change_specs=$(find "openspec/changes/$change" -name spec.md | sort)
# Swift files under any directory ending in "Tests": the package, unit and UI test targets.
test_files=$(git ls-files --cached --others --exclude-standard '*.swift' | grep -E '(^|/)[^/]*Tests/' || true)

# Scenarios are listed before links and manual checks, so every name is known when they arrive.
{
	scenarios main $main_specs
	scenarios change $required_change_specs
	scenarios known $change_specs
	links $test_files
	manual_checks
} | awk -F '\t' -v manual="$manual" -v change="$change" '
	function require(ref, where) {
		if (!(ref in required)) {
			required[ref] = where
			order[++count] = ref
		}
		known[ref] = 1
	}
	function fail(message) {
		print "error: " message > "/dev/stderr"
		errors++
	}
	$1 == "main" {
		if ($2 in main) fail($3 ": duplicate scenario \"" $2 "\" (first at " main[$2] ")")
		main[$2] = $3
		require($2, $3)
		next
	}
	$1 == "change" { require($2, $3); next }
	$1 == "known" { known[$2] = 1; next }
	$1 == "test" {
		if ($2 in known) tested[$2] = 1
		else fail($3 ": links to unknown scenario \"" $2 "\"")
		next
	}
	$1 == "manual" {
		if ($2 in known) manually[$2] = $3
		else fail($3 ": manual check for unknown scenario \"" $2 "\"")
		next
	}
	END {
		for (i = 1; i <= count; i++) {
			ref = order[i]
			if (ref in tested) {
				linked++
				if (ref in manually) fail(manually[ref] ": \"" ref "\" has a test, so remove its manual check")
			} else if (ref in manually) {
				checks[++manual_count] = ref
			} else {
				fail(required[ref] ": no test links to \"" ref "\" and it has no manual check")
			}
		}
		scope = change == "" ? "main specs" : "main specs and " change
		printf "spec coverage (%s): %d scenarios, %d linked to tests, %d manual checks\n", \
			scope, count, linked, manual_count
		if (manual_count > 0) {
			print "manual checks (" manual "):"
			for (i = 1; i <= manual_count; i++) print "  " checks[i]
		}
		if (errors > 0) {
			print errors " problem(s). Link tests with \"// Scenario: <capability>: <scenario name>\"." > "/dev/stderr"
			exit 1
		}
	}'

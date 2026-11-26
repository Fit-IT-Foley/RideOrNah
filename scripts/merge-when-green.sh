#!/bin/bash
# Squash-merges a pull request only when every expected CI check passed on its head commit.
# GitHub Free can't protect branches on a private repository, so this script is the merge gate:
# merge through it, never with a bare `gh pr merge`.
#
#   scripts/merge-when-green.sh <pr-number>          check once, merge if green
#   scripts/merge-when-green.sh --wait <pr-number>   wait up to 45 minutes for checks to finish
#
# Exit codes: 0 merged, 1 not mergeable or a check failed, 2 checks still running (no --wait).
set -euo pipefail

# The checks every pull request must pass, by job name in .github/workflows/ci.yml. A check
# that is missing, skipped, cancelled or still running blocks the merge. The UI test entries
# match the default matrix that ci.yml's `plan` job builds for pull requests.
EXPECTED_CHECKS=(
    "checks"
    "Spec validation"
    "plan"
    "UI tests (iPhone 17, iOS 26)"
    "UI tests (iPhone 17, iOS 27)"
)

WAIT_SECONDS=2700
POLL_SECONDS=30

wait=false
if [ "${1:-}" = "--wait" ]; then
    wait=true
    shift
fi
pr=${1:?usage: scripts/merge-when-green.sh [--wait] <pr-number>}

repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)

# Prints one line per expected check that hasn't passed, as "pending <name>" or "failed <name>
# (<reason>)", and "failed <name> (unexpected)" for any other check that failed.
unmet_checks() {
    local sha=$1 runs
    # The API returns the latest run of each check name for the commit.
    runs=$(gh api "repos/$repo/commits/$sha/check-runs?per_page=100" \
        --jq '.check_runs[] | [.name, .status, (.conclusion // "")] | @tsv')
    local name found status conclusion
    for name in "${EXPECTED_CHECKS[@]}"; do
        found=$(awk -F'\t' -v n="$name" '$1 == n' <<<"$runs" | head -1)
        if [ -z "$found" ]; then
            echo "pending $name (not started)"
            continue
        fi
        status=$(cut -f2 <<<"$found")
        conclusion=$(cut -f3 <<<"$found")
        if [ "$status" != "completed" ]; then
            echo "pending $name ($status)"
        elif [ "$conclusion" != "success" ]; then
            echo "failed $name ($conclusion)"
        fi
    done
    awk -F'\t' '$2 == "completed" && $3 ~ /^(failure|timed_out|cancelled|action_required|startup_failure)$/ \
        { print $1 }' <<<"$runs" | while IFS= read -r name; do
        printf '%s\n' "${EXPECTED_CHECKS[@]}" | grep -qxF "$name" || echo "failed $name (unexpected)"
    done
}

pr_field() {
    gh pr view "$pr" --json "$1" --jq ".$1"
}

state=$(pr_field state)
[ "$state" = OPEN ] || { echo "error: pull request #$pr is $state" >&2; exit 1; }
[ "$(pr_field isDraft)" = false ] || { echo "error: pull request #$pr is a draft" >&2; exit 1; }
base=$(pr_field baseRefName)
[ "$base" = main ] || { echo "error: pull request #$pr targets $base, not main" >&2; exit 1; }

deadline=$((SECONDS + WAIT_SECONDS))
while :; do
    sha=$(pr_field headRefOid)
    unmet=$(unmet_checks "$sha")
    if grep -q '^failed ' <<<"$unmet"; then
        echo "Not merging #$pr: checks failed on $sha" >&2
        sed 's/^/  /' <<<"$unmet" >&2
        exit 1
    fi
    [ -n "$unmet" ] || break
    if ! $wait || [ $SECONDS -ge $deadline ]; then
        echo "Not merging #$pr: checks not finished on $sha" >&2
        sed 's/^/  /' <<<"$unmet" >&2
        exit 2
    fi
    echo "Waiting for $(grep -c . <<<"$unmet") check(s) on $sha..."
    sleep "$POLL_SECONDS"
done

# GitHub works out mergeability in the background, so UNKNOWN is retried for a minute.
for _ in $(seq 12); do
    mergeable=$(pr_field mergeable)
    [ "$mergeable" = UNKNOWN ] || break
    sleep 5
done
[ "$mergeable" = MERGEABLE ] || { echo "error: pull request #$pr is $mergeable with main" >&2; exit 1; }

echo "All expected checks passed on $sha. Squash-merging #$pr."
# --match-head-commit refuses the merge if anything was pushed after the checks above ran.
gh pr merge "$pr" --squash --match-head-commit "$sha"

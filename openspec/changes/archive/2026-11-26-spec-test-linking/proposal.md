# Proposal

## Why

Specs are only trustworthy if something checks them. Today nothing ties a spec scenario to the test that proves it, so a scenario can ship untested, or a test can go stale after a scenario is renamed, and nobody notices. That matters most once `next-task` merges changes without review. The link has to exist before `ride-verdict-engine`, the first feature change, so its tests are written to the convention from the start rather than retrofitted.

## What Changes

- Tests link to the scenarios they prove with a `// Scenario: <capability>: <scenario name>` comment directly above the test. This works for Swift Testing and XCTest UI tests alike.
- Add `docs/manual-checks.md` for scenarios no automated test can reach, such as App Store behavior or recording a real device's network traffic. Each entry says how and when to check it, and why it can't be a test.
- Add `make spec-coverage`, which fails when a scenario in `openspec/specs/` has neither a linked test nor a manual check, or when a test or manual check names a scenario that doesn't exist. `CHANGE=<name>` also requires that change's scenarios, for use before archiving.
- Run it in CI's existing "Spec validation" job, so the merge gate's list of expected checks is unchanged.
- Cover the live `app-platform` scenarios: link the existing launch UI test; add app-hosted unit tests for the minimum OS and privacy manifest; add UI tests for the largest text size and switching to dark mode; and list the rest as manual checks.
- Add the convention to `openspec/config.yaml` rules and apply and archive guidance, `CLAUDE.md`, the README and the `next-task` skill.
- Non-goals: measuring code coverage, and linking requirements rather than scenarios. Scenarios are the testable unit.

## Capabilities

### New Capabilities
- None. This is repository tooling and process, so the change sets `skip_specs: true`.

### Modified Capabilities
- None.

## Impact

- New: `scripts/check-spec-coverage.sh`, `docs/manual-checks.md`, a `RideOrNahTests` app-hosted unit test target, and new UI tests.
- Changed: `Makefile`, `.github/workflows/ci.yml` (one step in the "Spec validation" job), `project.yml`, `openspec/config.yaml`, `CLAUDE.md`, `README.md`, `.claude/skills/next-task/SKILL.md`, and `ride-verdict-engine` task 5.2, whose hand-written requirement-to-test map this check replaces.
- Privacy: none. No app behavior changes. One accessibility identifier is added to the placeholder screen for the tests.
- WeatherKit requests: none.
- CI cost: the coverage check runs on the Linux spec-validation runner, so it adds no macOS minutes. The new tests run inside the existing pull request UI test jobs.

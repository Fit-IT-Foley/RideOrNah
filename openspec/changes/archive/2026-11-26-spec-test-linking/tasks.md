# Tasks

## 1. Coverage check

- [x] 1.1 Write `scripts/check-spec-coverage.sh`: required scenarios from `openspec/specs/`, known ones from active changes, `// Scenario:` links from Swift files under `*Tests/` directories, entries from `docs/manual-checks.md`, and `--change <name>` to require a change's scenarios. Verify it reports a missing link, an unknown link (with file and line), and a scenario listed as both tested and manual.
- [x] 1.2 Add `make spec-coverage` (with optional `CHANGE=`) and its help line. Verify `make spec-coverage CHANGE=ride-verdict-engine` fails, listing ride-verdict scenarios, and `make spec-coverage CHANGE=no-such-change` fails with a clear message.

## 2. Cover app-platform

- [x] 2.1 Link the launch UI test to "Install on the oldest supported OS". Verify `make spec-coverage` no longer lists that scenario as uncovered.
- [x] 2.2 Add the `RideOrNahTests` app-hosted unit test target to `project.yml` and the scheme, with tests for "Unsupported OS" (minimum OS 26.0) and "Manifest present in build" (privacy manifest contents). Verify they pass on the iOS 26 and iOS 27 simulators with `make test`.
- [x] 2.3 Add UI tests for "Largest text size" (launch at the largest accessibility size; title and subtitle fully on screen; screenshot attached) and "Switching appearance" (dark mode while open; background brightness drops; no relaunch). Verify they pass with `make test` on the iOS 26 and iOS 27 simulators.
- [x] 2.4 Write `docs/manual-checks.md` with entries for "Any supported OS", "Network destinations", "Privacy label" and "Color-independent state". Verify `make spec-coverage` passes and lists those four as manual.

## 3. Wire in the convention

- [x] 3.1 Add the `make spec-coverage` step to CI's "Spec validation" job. Verify the job name is unchanged, so `scripts/merge-when-green.sh` still expects it.
- [x] 3.2 Add spec and task rules, and apply and archive guidance, to `openspec/config.yaml`. Verify `openspec instructions apply --change ride-verdict-engine --json` prints no config warnings and includes the new guidance.
- [x] 3.3 Document the convention in `CLAUDE.md` and `README.md`, and add `make spec-coverage` to the `next-task` skill's test and archive steps. Verify each command as written runs.
- [x] 3.4 Replace `ride-verdict-engine` task 5.2's hand-written requirement-to-test map with a `make spec-coverage CHANGE=ride-verdict-engine` check. Verify `make validate-specs` passes.

## 4. Integration checks

- [x] 4.1 Run `make audit`, `make lint`, `make validate-specs`, `make spec-coverage`, `make test-kit`, `make build` and `make test`. Verify all pass.

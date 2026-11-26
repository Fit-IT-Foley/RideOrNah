# Design

## Context

`openspec/specs/` holds one capability today, `app-platform`, with nine scenarios. Seven more capabilities arrive as the active changes are archived. Scenario names are unique within a capability, but not across them: "Lapsed subscription" appears in both `widgets` and `watch-app`. Tests live in three places: `Packages/RideOrNahKit/Tests/` (Swift Testing, on macOS), `RideOrNahUITests/` (XCTest, on simulators), and, from this change, `RideOrNahTests/` (Swift Testing, hosted in the app on simulators). CI's "Spec validation" job runs on Linux. See proposal.md for motivation.

## Goals / Non-Goals

**Goals:**
- Anyone reading a test can see which scenario it proves, and anyone reading a scenario can find its test by searching for its name.
- The check runs anywhere: macOS, the Linux CI runner and agents' sandboxes, with no build and no simulator.
- Exceptions are explicit, justified and listed on every run, never silent.

**Non-Goals:**
- Proving a test actually exercises its scenario. Review and the task's verification step own that. The check only guarantees the link exists and points somewhere real.

## Decisions

### Link with a comment naming capability and scenario
`// Scenario: app-platform: Install on the oldest supported OS`, on its own line directly above the test, with one line per scenario when a test proves several.
- **Why:** it mirrors the spec's own `#### Scenario:` header, so a text search for the name finds both. It works identically in Swift Testing and XCTest, and parsing a comment needs nothing but text tools.
- **Alternatives:**
  - Swift Testing display names alone can't cover XCTest UI tests, and names collide across capabilities.
  - A custom Swift Testing trait would still need source parsing to check, and doesn't exist in XCTest.
  - Slug IDs (`app-platform#install-on-...`) are robust to punctuation but unreadable, and still change on rename.
- **Matching:** exact text after trimming, so a renamed scenario breaks its links loudly instead of drifting.

### Required versus known scenarios
Scenarios in `openspec/specs/` are required: each needs a linked test or a manual check. Scenarios in active changes' delta specs are known but not required, so tests written during `/opsx:apply` can link to them before the change is archived. With `CHANGE=<name>`, that change's delta scenarios become required too. That's the pre-archive check, because archiving is what turns them into required main-spec scenarios.

### Where tests are looked for
Swift files tracked by git, or new but not ignored, that sit under a directory whose name ends in `Tests`. That covers all three test locations and any future widget or watch test targets, and keeps a stray marker in app code from counting.

### Manual checks in a Markdown file
`docs/manual-checks.md` has one `## <capability>: <scenario name>` heading per scenario, with When, How and "Why not a test" bullets. Readers get a usable checklist, and the script only needs the headings. A scenario that gains a test should lose its entry. The script reports any scenario listed as both, so the list stays short.

### Plain shell and awk
`scripts/check-spec-coverage.sh` collects tagged lines (required, known, test link, manual) with `find`, `git ls-files` and POSIX awk, then one awk pass reports. This matches the other scripts and runs on macOS and the Ubuntu runner with nothing installed. Paths with spaces aren't supported, and the repo has none.

### Cover `app-platform` with real tests where a simulator can
- **Install on the oldest supported OS:** the existing launch UI test, which `make test` runs on iOS 26 and 27.
- **Unsupported OS:** an app-hosted unit test asserts the bundle's `MinimumOSVersion` is `26.0`. That's the value the App Store uses to tell iOS 18 users the app needs a newer iOS.
- **Manifest present in build:** an app-hosted unit test reads `PrivacyInfo.xcprivacy` from the app bundle and asserts tracking off, no tracking domains and no collected data. Debug and Release bundle the same file.
- **Largest text size:** a UI test launches at the largest accessibility size and asserts the title and subtitle are fully on screen, with a screenshot attached. It can't detect glyph truncation inside a text element. The screenshot is for that.
- **Switching appearance:** a UI test switches the device to dark mode while the app is open and samples the background brightness before and after, so the app must redraw without relaunching.
- **Manual:** "Any supported OS" (Liquid Glass can't be detected from a UI test, so the check is reviewing CI's launch screenshots), "Network destinations" (needs a real device and every feature), "Privacy label" (lives in App Store Connect), and "Color-independent state" (no color-coded state exists yet; the first verdict screen must replace this entry with a VoiceOver test).

### Guidance where agents will read it
- `openspec/config.yaml` gets rules for specs and tasks, and `operations` guidance for apply and archive. OpenSpec passes these to every agent working on a change.
- `CLAUDE.md` and the README state the convention for people.
- The `next-task` skill runs the check before and after archiving.

## Risks / Trade-offs

- [A link only proves a test claims a scenario, not that it tests it] → The task verification step and pull request review still matter. The check makes a missing test impossible to miss, not a weak test.
- [Exact-name matching breaks links on any scenario wording edit] → That's intended: the failure names the file and line to update.
- [The manual-checks list could become a dumping ground] → Each entry needs a "Why not a test" reason, the check prints every entry on every run, and the config rules limit it to scenarios a simulator or the Mac can't reach.

## Open Questions

- None.

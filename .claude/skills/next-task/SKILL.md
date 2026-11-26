---
name: next-task
description: Take the next Todo item on the RideOrNah GitHub project board all the way through on its own (OpenSpec proposal, implementation, tests, archive, pull request, merge into main), or finish the pull request already in flight. Use whenever someone says "next task", "next-task", "work the board", "pick up the next item" or "what's next on the board", and whenever a scheduled routine asks for board work to be done, even if the board isn't named.
---

Take one item from the RideOrNah project board from Todo to merged on main, without waiting for review. The owner has asked for this to run autonomously, so every step below exists to make an unreviewed merge safe: OpenSpec keeps the specs true, CI decides whether code is good, and anything that needs a human leaves the pipeline with a comment instead of guessing.

Read `CLAUDE.md` and `openspec/config.yaml` first. Their rules win over anything here.

## The board

Project "RideOrNah": https://github.com/users/Fit-IT-Foley/projects/1, linked to `Fit-IT-Foley/RideOrNah`.

| What | ID |
| --- | --- |
| Project | `PVT_kwHOAjn17s4BtPYk` |
| Repository | `R_kgDOV8JX4w` |
| Status field | `PVTSSF_lAHOAjn17s4BtPYkzhrZx7I` |
| Status: Todo | `f75ad846` |
| Status: In Progress | `47fc9ee4` |
| Status: Done | `98236657` |

- List items in board order: `gh project item-list 1 --owner Fit-IT-Foley --format json --limit 200`
- Set a status: `gh project item-edit --project-id PVT_kwHOAjn17s4BtPYk --id <item-id> --field-id PVTSSF_lAHOAjn17s4BtPYkzhrZx7I --single-select-option-id <option-id>`
- Clear a status (moves the item to No Status): the same command with `--clear` in place of `--single-select-option-id`.

The board's built-in workflows put newly added items in Todo and move items to Done when their pull request merges. You don't set Done yourself.

No Status is where items wait for the owner. Anything that leaves the pipeline goes there with a comment saying exactly what it needs, such as "needs the design session for today-and-outlook" or "tasks 3.2 and 3.3 need the Developer Program".

## Attended or unattended

You're unattended when a scheduled routine or anything else started you with no one to answer; the prompt says so. Then never wait for an answer: where these steps say "blocked", comment on the item, clear its status, and carry on. When someone is at the keyboard, ask them instead. The pipeline is otherwise the same either way, merge included.

Use `openspec` if it's on PATH, otherwise `npx -y @fission-ai/openspec@1.13.2` (the version this repo's OpenSpec skills were generated with).

## 1. Finish the pull request in flight

Look for an open pull request from a `next-task/` branch without the `needs-owner` label. If there is one, take it through step 7 (get it green and merge) before anything else. One unfinished pull request at a time keeps main moving in order. If it merges, go on to step 2. If it can't be finished in this run, stop and report.

## 2. Pick the item

Take the first Todo item in board order. If it's a draft rather than an issue, convert it so it can take comments and be closed by the pull request:

```bash
gh api graphql -f query='mutation($item:ID!,$repo:ID!){convertProjectV2DraftIssueItemToIssue(input:{itemId:$item,repositoryId:$repo}){item{content{... on Issue{number url}}}}}' -f item=<item-id> -f repo=R_kgDOV8JX4w
```

Read the issue's body and comments in full. They're the requirements. Then move the item to In Progress, run `git fetch origin`, and branch from `origin/main` as `next-task/<issue-number>-<short-slug>`.

If Todo is empty, report that and stop. If an item turns out blocked, try the next Todo item, up to three in one run.

## 3. Propose the change with OpenSpec

Every item lands as an OpenSpec change, so main's specs keep describing what the app does. The one exception is a docs or comment fix that changes no behavior, which can skip to step 4.

- **An active change in `openspec/changes/` already covers the item.** Use it; don't propose a duplicate. If it lacks design.md or tasks.md, write them from `openspec instructions design --change <name> --json` and `openspec instructions tasks --change <name> --json`.
- **Nothing covers it.** Propose a new change by following `.claude/skills/openspec-propose/SKILL.md`. For a bug, the delta spec adds or sharpens the scenario that would have caught it.

These are blocked, and need the owner first:

- **UI without a design session.** CLAUDE.md requires a design session before the design and tasks of anything with UI (screens, widgets, watch views, notification content). The sign is that the change has UI and no design.md or tasks.md yet. Unattended, write and merge only the proposal and specs (they describe behavior, never visuals), then block the item for the design session. Attended, offer to hold the design session now.
- **Out of order.** The change would start while an earlier change in CLAUDE.md's v1 order still has unticked tasks, other than ones marked "(needs Developer Program)". Later changes build on earlier ones.
- **Unclear.** Acting on the item would mean guessing what the owner wants.

Run `openspec validate --all --strict`. It must pass before you go on.

## 4. Implement

Follow `.claude/skills/openspec-apply-change/SKILL.md` for the change. Tick each task only when its specified behavior is fully there, because the archive in step 6 trusts those ticks. If the work turns out bigger than the change describes, update the change (`.claude/skills/openspec-update-change/SKILL.md`) rather than absorbing it silently.

Tasks marked "(needs Developer Program)" can't be done or verified here or in CI. Implement whatever part of them can be written and tested without the program, leave them unticked, and name them in the pull request.

Write commit messages like the repository's history: one imperative sentence, no prefix.

## 5. Test

- With `xcodebuild` on PATH (the owner's Mac), run `make audit`, `make lint`, `make test-kit` and `make build`, plus `make test` when UI changed. All must pass before you go on.
- Without it (a Linux sandbox), you can't build or run the tests here. CI is the test, in step 7.
- `make validate-specs` (`openspec validate --all --strict`) must pass. CI runs it too.

## 6. Archive and open the pull request

If every task in the change is ticked, archive it by following `.claude/skills/openspec-archive-change/SKILL.md`, which merges its delta specs into `openspec/specs/`. Validate again. If tasks remain unticked (Developer Program, or partial work the item asked for), don't archive. Say why in the pull request; the change stays active until they're done.

Push the branch and open a pull request whose title is the one-sentence summary (it becomes the squash commit on main):

```markdown
Closes #<issue>

## What changed
<one or two sentences>

## OpenSpec
<change name; tasks ticked; archived, or which tasks remain and why>

## Verification
<what ran locally and passed, or that this was written in a Linux sandbox and CI is the test>
```

## 7. Get it green and merge

Repeat until merged or stuck:

1. **Conflicts.** Check `gh pr view <n> --json mergeable,mergeStateStatus`. If it conflicts with main, merge `origin/main` into the branch (never rebase or force-push a pushed branch) and resolve the conflicts. Where the conflict is in `openspec/`, keep both sides' requirements and re-run `openspec validate --all --strict`. Push.
2. **CI.** Wait for checks with `gh pr checks <n> --watch`. They take up to half an hour. If no checks appear within five minutes of a push, CI isn't running, so don't merge.
3. **Failures.** Read the failing log (`gh run view <run-id> --log-failed`), fix the cause on the branch, push, and go back to 1. Never skip, disable or weaken a check or test to get green.
4. **Merge.** Run `scripts/merge-when-green.sh --wait <n>`. It's the only way to merge: GitHub Free can't protect main on a private repository, so this script is the gate. It squash-merges only when every expected check in its list has passed on the head commit, and treats a check that is missing, skipped, cancelled or still running as a failure. Never call `gh pr merge` yourself. Exit 1 means a check failed or the pull request can't merge, so go back to 1 or 3. Exit 2 means checks were still running when the wait ran out, so run it again. Once it merges, run `git push origin --delete <branch>`. Leave the branch with `git fetch origin && git switch --detach origin/main` and delete it locally with `git branch -D <branch>`. This works in a worktree even when main is checked out somewhere else, which `--delete-branch` doesn't. The board moves the item to Done.

If CI still fails after three fix attempts in one run, or the merge needs a judgment you can't make, it's stuck. Comment on the pull request with what's failing and what you tried, add the `needs-owner` label (create it if missing), and block the item. Step 1 skips `needs-owner` pull requests, so a stuck one doesn't hold up the board.

If this run ends while CI is still going, that's fine: the next run picks the pull request up in step 1.

If tasks were left unticked, block the item once merged. Main has the work so far, and the comment says which tasks remain.

## Guardrails

- Never push to main directly, force-push, or merge other than through `scripts/merge-when-green.sh`. The merge is safe only because CI passed.
- Never merge a pull request that a human opened or a branch that isn't `next-task/`.
- Stay inside the item. Unrelated problems you notice go in your report, not in this pull request.

## Report

Finish with a short summary: what merged (pull request links), what's waiting on CI, and every item you blocked and why. If nothing happened, say why in one line, such as "Todo is empty".

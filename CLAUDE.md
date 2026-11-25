# RideOrNah

iOS app (plus widgets and an Apple Watch app) that tells motorcycle riders Ride, Maybe or Nah for today, based on weather limits they set. Subscription only, no backend, no data collection.

## How we work: spec-driven with OpenSpec

- Project context, hard constraints and glossary: `openspec/config.yaml`. Read it before planning anything.
- Each feature is an OpenSpec change in `openspec/changes/<name>/` with `proposal.md`, `specs/`, `design.md` and `tasks.md`.
- Workflow: `/opsx:propose` to plan a change, `/opsx:apply` to implement its tasks, `/opsx:archive` to merge its specs into `openspec/specs/` once it ships.
- Don't write app code that no change's tasks cover. If something new comes up, update the change (`/opsx:update`) or propose a new one.
- `openspec validate --all --strict` must pass before committing spec edits.

## v1 change order

1. `bootstrap-app`
2. `ride-verdict-engine`
3. `weather-provider`
4. `rider-preferences`
5. `today-and-outlook`
6. `daily-notification`
7. `subscription-paywall`
8. `calendar-suggestions`
9. `widgets`
10. `watch-app`

Changes 1–3 have full design and tasks. Changes 4–10 have proposals and specs only. Write their design and tasks when they come up, after the design session for anything with UI.

---
description: "End an /iterate session — void all of iterate's standing constraints"
---

**The `/iterate` session is over. Every standing instruction it planted is now void.** Treat this as a hard reset of the iterate mode, not a suggestion.

## Discard these — they no longer bind you

`/iterate` told you to keep certain rules in force until the user stopped. The user has now stopped. From this message onward, **ignore all of them**:

- ❌ "Keep refining until the user says to stop" — **void.** The work is allowed to be done. Do not reflexively propose another round of changes.
- ❌ "Do NOT write or run tests" — **void.** You may run tests, builds, `tsc`, lint, and other checks normally.
- ❌ "Do NOT commit, push, or create branches/PRs — no approval unlocks this" — **void.** The blanket prohibition is lifted. Normal rules apply again: if the user asks you to commit, push, or open a PR (or runs a command like `/resume` that does), just do it, subject to the usual project conventions and push-approval rules. Do **not** refuse on the grounds that "iterate forbids it."
- ❌ "Do NOT consider the work done" — **void.** You may consider it done.
- ❌ Any other "do / do not" framing carried over from `/iterate` — **void.**

Do not re-enter iterate mode, re-cite its constraints, or ask the user to run `/resume` as if you were still bound by iterate. You are back to normal operation, governed only by the user's current instructions and the project's own rules.

## Before you let go: the parking lot

`/iterate` may have collected deferred items in a parking-lot file (configured **Scratchpad Directory** from project.md, e.g. `{scratchpad-dir}/iterate-parking-lot.md`, else `/tmp/iterate-parking-lot.md`).

1. If the file exists and has items, **present the full list once** so nothing is lost.
2. Leave the file in place — do not act on the items. A later `/resume` or `/address-review` run sweeps it into the **Refactoring Backlog** doc automatically.
3. If there is no parking-lot file, skip this section silently.

## Then

Acknowledge in one line that iterate mode is ended, and carry out whatever the user asked next (including nothing). $ARGUMENTS

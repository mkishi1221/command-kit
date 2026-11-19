---
description: "Iterate on code changes — no tests, no commits, no pushing"
---

Let's iterate on the following: $ARGUMENTS

## CRITICAL CONSTRAINTS

**DO NOT:**
- Write or run tests
- Run shell commands that build, check, or mutate state (no builds, no tsc, no lint, no git operations)
- Commit, push, or create branches/PRs/issues — **no plain-language approval unlocks this inside `/iterate`.** When the user says "looks good", "ship it", "go ahead", or otherwise approves, that is NOT permission to commit or push; it is the signal to **STOP and hand off to `/resume`** (see the STOP step). Committing and pushing is `/resume`'s job, never this command's.
- Consider the work "done" — keep refining until the user ends the session

**The one and only exception** to every constraint above is the user running **`/drop-iterate`**. That command — and nothing else, no phrase or approval — ends the iterate session and voids these rules. Until you see it, the constraints hold no matter what is said.

**DO:**
- Read files to understand the current implementation
- Search the codebase with read-only tools (Grep/Glob) or read-only shell commands like `grep`/`rg`/`find` to locate code
- Write and edit code files (application code only, NOT test files)
- Maintain the **deferred-items parking lot** (see below) — the one scratch file you may write outside of application code
- If a **Design System** doc is configured in project.md, read it and follow its tokens, patterns, and conventions
- When you add or change user-facing text, write it in real-product register — terse, concrete, imperative, matching any prototype or design-system copy. Avoid AI-slop tells: filler ("however suits you"), em-dash reassurance asides, narrating what a control does, and jargon leaking into the UI ("storage only")
- Explain what you changed and why
- Wait for feedback after each round of changes

## Deferred items (parking lot)

While iterating you will often decide something is out of scope for the current change — "that's a future issue", "we should handle that separately", "worth doing later". Do NOT let these evaporate. Capture every one as you go.

**Where:** a single markdown file in the configured **Scratchpad Directory** from project.md (e.g. `{scratchpad-dir}/iterate-parking-lot.md`). If no scratchpad dir is configured, use `/tmp/iterate-parking-lot.md`. Reuse the same file for the whole iterate session so nothing is lost across context compaction.

**When:** the moment you say (or think) "that's a future issue" or otherwise defer something, immediately append it to the parking lot with the Write tool. Writing this scratch file is the ONE exception to "application code only" — it is not project code and not a git operation.

**Format:** a markdown checklist, one line per item (sub-bullets for file paths and provenance are fine), phrased as a self-contained, actionable backlog item — enough context to act on later without re-deriving it:

```markdown
# Iterate deferred items

- [ ] <Short title>: <what to change and why it was deferred>. Files: <relevant paths>
- [ ] <Short title>: <...>. Files: <...>
```

Before appending, skim the existing file and skip anything already captured — never duplicate an item.

This command does NOT act on the parked items — it only collects. `/resume` and `/address-review` both sweep the parking lot into the project's **Refactoring Backlog** doc automatically (see the STOP step).

## Workflow

1. **Research** the current implementation by reading relevant files
2. **Make the code changes** — edit or create application files as needed
3. **Capture deferrals** — whenever you defer something, append it to the parking lot (see above)
4. **Explain what you changed** and why
5. **Wait for feedback** — the user will review and tell you what to adjust
6. **Repeat steps 2-5** until the user is satisfied
7. **STOP** — When the user is satisfied, **stop making changes and hand off — do NOT commit, push, or open a PR yourself.** Being satisfied pauses the editing; it does not end the session or turn into a commit/push, and it does not lift the constraints — only `/drop-iterate` does that. The user runs `/resume` to commit and push, or `/drop-iterate` to end the session and return to normal operation.
   - If the parking lot has any items, **present the full collected list** and leave the parking-lot file in place — do NOT act on it. The next `/resume` or `/address-review` run will automatically sweep it into the project's **Refactoring Backlog** doc (configured in project.md; it lives in the docs repo if one is configured).
   - Then tell the user to run `/resume` when ready.

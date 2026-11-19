---
description: "Tear down a PR — cancel in-flight state, roll back and remove migrations, delete the branch, reopen the issue"
---

Tear down the PR / branch: $ARGUMENTS

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, base branch, scratchpad directory, docs repo, dev/prod Supabase project refs) before executing. Use those values throughout.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it — except the confirmation gate in step 2, which is the one place you STOP and wait.**

This command abandons in-flight work: it reverses what `/execute`, `/iterate`, `/resume`, and `/address-review` set up — the feature branch, the PR, the dev-DB migrations, the closed issue, and the scratch state — leaving you back on the base branch with a clean tree. Use it when a PR should be discarded, not merged.

> **Stack note:** The migration-rollback steps assume **Supabase** (CLI + `schema_migrations`). If your project uses a different migration tool, ask Claude Code to adapt the DB-reversal commands in step 3; the git, PR, and issue steps are stack-agnostic.

## Hard invariants

- **Never force push. Never checkout, pull, push, or delete `main` or the base branch.** Deleting a *remote feature* branch (`git push origin --delete <branch>`) is not a force push and is allowed.
- **Dev DB only.** Migrations are release-gated, so they were never applied to production — there is nothing to roll back on prod, and prod Supabase writes are hook-blocked regardless. All rollback targets the dev project only.
- **`execute_sql` is SELECT-only** (hook-enforced). Use it to *read* `supabase_migrations.schema_migrations`, never to write. Reversal DDL and tracking-row cleanup go through the Supabase CLI (linked to dev) — see step 3.

## Workflow

### 1. Detect the full teardown scope

Gather everything before presenting the plan — do not change anything yet.

- **Branch:** `git rev-parse --abbrev-ref HEAD` (or the branch named in `$ARGUMENTS`). **GUARD:** if it is the base branch or `main`, STOP — there is nothing to tear down and these are never deletable.
- **PR:** `gh pr view <branch-or-#> --json number,headRefName,baseRefName,state,url,body`. The PR may not exist yet (branch never pushed / PR never opened) — that is fine, skip the PR-specific steps later.
  - **GUARD:** if the PR state is `MERGED`, STOP. Teardown is for abandoning unmerged work; a merged PR needs a revert PR, not a teardown. Tell the user.
- **Issue:** parse `Closes #<n>` from the PR body/commits, or the `issue-<n>` segment of the branch name.
- **Migrations introduced by this branch** — BOTH of:
  - committed on the branch: `git diff --name-only origin/<base>...HEAD -- supabase/migrations/`
  - uncommitted in the working tree: `git status --porcelain -- supabase/migrations/` (added/modified). **These untracked files survive `git checkout` and branch deletion, so they must be removed explicitly.**
  For each, read the file and work out the inverse DDL (a `DROP COLUMN` reverses to re-adding it, an `ADD COLUMN`/`CREATE TABLE` reverses to dropping it, etc.) so the plan can state exactly what will change on dev.
- **In-flight state files:** the iterate parking lot (`{scratchpad-dir}/iterate-parking-lot.md`, fallback `/tmp/iterate-parking-lot.md`) and any scratchpad the issue references (`## Research Context` → `**Scratchpad:**`), plus a design scratchpad in the docs repo if one matches this issue's topic.
- **Uncommitted changes:** `git status` — everything here will be discarded.

### 2. Present the teardown plan and STOP for confirmation

Print exactly what will happen, then STOP and wait for an explicit "yes". Do nothing destructive until the user confirms.

```
Teardown plan for <branch>:
- Branch:      delete local + remote (<branch>)
- PR:          close #<n> (<url>)            [omit if no PR]
- Issue:       reopen #<n>, reset label in-review → ready-to-implement   [omit if none]
- Migrations:  roll back on dev + delete files:
                 <version>_<name>.sql  →  <one-line inverse, e.g. re-add column X>
- State files: delete <parking lot>, <scratchpad(s)>   (abandoned, NOT swept to backlog)
- Discards:    <N uncommitted changes>
```

If anything in scope looks unintended (parked items worth keeping, uncommitted work unrelated to this PR), call it out here so the user can object before it is gone.

### 3. Roll back and remove migrations (dev only)

For each migration found in step 1, smallest-numbered-last (reverse dependency order):

1. **Reverse its effect on the dev DB** so dev's schema matches the base branch again. `execute_sql` cannot run DDL, so apply the inverse DDL via the Supabase CLI against the linked dev project (the CLI is already linked to dev; never pass the prod ref). If the branch only *added* objects and the clean path is unavailable, `apply_migration` with the inverse DDL is an acceptable fallback — but you must still clear the tracking rows in the next step so no orphan rows remain.
2. **Clear its tracking row:** `supabase migration repair --status reverted <version>` (operates on the linked dev project; removes the row from `supabase_migrations.schema_migrations`).
3. **Delete the migration file** from the working tree (`rm supabase/migrations/<version>_<name>.sql`) — required for untracked files, which neither checkout nor branch deletion removes.

Then **verify dev is clean:** read `supabase_migrations.schema_migrations` via a SELECT (and/or `supabase migration list`) and confirm none of the torn-down versions remain, and that the reversed objects are back to their base-branch state. Do not touch production — those versions were never applied there.

### 4. Cancel in-flight state

- Delete the iterate parking lot and the issue's scratchpad file(s) identified in step 1. These are being abandoned with the PR — do **not** sweep them into the Refactoring Backlog (that is for work that ships; this work is discarded).
- Any `/execute`, `/iterate`, or `/resume` run in progress is superseded by this teardown — there is no daemon to stop, only the files above.

### 5. Reopen and reset the issue (skip if there is no issue)

- `gh issue reopen <n>`
- Reset labels to the pre-implementation state: remove `in-review` / `in-progress`, add `ready-to-implement` (use the label set from project.md).
- Comment so the trail is clear: `gh issue comment <n> --body "PR #<pr> torn down; implementation abandoned. Issue reopened for re-planning or re-execution."`

### 6. Close the PR and delete the branch

- **Get off the branch first** — you cannot delete the branch you are on, and all uncommitted changes were confirmed for discard in step 2: `git checkout <base>` (use `git checkout -f <base>` if local changes block it; discarding is intended here). Then `git fetch origin <base>` so local base is current.
- **If a PR exists:** `gh pr close <n> --delete-branch --comment "Torn down — implementation abandoned."` This closes the PR and deletes the remote branch in one step.
- **If no PR exists** but the branch was pushed: delete the remote branch directly — `git push origin --delete <branch>`.
- **Delete the local branch:** `git branch -D <branch>` (force, because it is unmerged). Run this even after `--delete-branch` in case the local deletion was skipped.
- **Prune the stale remote-tracking ref:** `git remote prune origin`. Deleting the branch on the remote does NOT remove this clone's cached `remotes/origin/<branch>` pointer — a plain `git fetch` only adds refs, never removes them — so without a prune the dead branch keeps showing up in `git branch -a` / `git branch -r` and reads as "still there". The prune also clears any other tracking refs for branches already deleted on the remote.
- **Verify it is actually gone, not just pretend-gone** — all three must come back empty:
  - `git ls-remote --heads origin <branch>` → empty (authoritative: not on the remote).
  - `git branch --list <branch>` → empty (no local branch).
  - `git branch -r --list "origin/<branch>"` → empty (no stale tracking ref — this is the one a missing prune leaves behind).
  If the tracking ref is still listed, re-run `git remote prune origin` (or `git fetch origin --prune`) until it clears.

### 7. Final report

State the end result plainly — no process narration:

- Branch `<branch>`: deleted (remote + local + stale tracking ref pruned) — verified gone via `git ls-remote` + `git branch -a`.
- PR #<n>: closed. / No PR existed.
- Issue #<n>: reopened, label reset to `ready-to-implement`. / No issue linked.
- Migrations: `<list>` rolled back on dev and files removed; `schema_migrations` verified clean. / None.
- State files deleted: `<list>`.
- Now on `<base>` with a clean working tree (`git status`).

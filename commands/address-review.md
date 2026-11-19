---
description: "Address /review findings end-to-end — fix, test, commit, update PR, push"
---

Address the review findings: $ARGUMENTS

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, base branch, scratchpad directory, etc.) before executing. Use those values throughout this workflow.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it. Run ALL steps end-to-end without stopping for approval — unlike `/iterate`, this command commits and pushes. The only reason to stop is a genuine blocker that requires a user decision.**

## How this differs from /iterate

- `/iterate` is exploratory: no tests, no builds, no git operations, wait for feedback after each round. This command is the opposite: it closes out a review pass in one uninterrupted run — fix, verify, commit, update the PR, push.
- **Tests ARE in scope.** Review findings regularly converge on tests: a fixed bug needs a regression test, a refactor invalidates existing tests, or the finding itself is about test code. Write and edit test files freely.

## Input

Findings always come from the `/review` command (the report with Security / Error Handling / Duplication / Project Conventions sections). Locate them in this order:

1. If `$ARGUMENTS` contains a pasted report or specific findings, use those. `$ARGUMENTS` may also scope the work ("only the security findings", "skip the duplication one") — obey that scoping.
2. Otherwise use the most recent `/review` report in the current conversation.
3. If neither exists, STOP and tell the user to run `/review` first. This is the one legitimate early stop.

Identify the PR: `gh pr view --json number,headRefName,baseRefName,title`. Confirm the current branch is the PR's head branch. **Work on the current branch — never create a new branch.**

Check `git status` before starting: uncommitted changes from this session's review discussion are part of this pass and get committed with the fixes. If there are uncommitted changes that are clearly unrelated to the review, tell the user what they are and how you will handle them before the commit step.

## Workflow (execute all steps without stopping)

### 1. Triage — every finding gets an explicit disposition

Build a checklist of every finding in the report. Each one gets exactly ONE of:

- **FIX** — the finding is valid and belongs in this PR. This is the default.
- **DISPUTE** — the finding is a false positive or the behavior is by design. Disputing requires evidence: cite the file/line, RLS policy, project rule, or design decision that proves it. Check the project's rules and docs (`.claude/rules.md`, product docs configured in project.md) — some "issues" are documented intentional behavior. Never dispute on a hunch.
- **DEFER** — genuinely out of scope for this PR (a pre-existing pattern the PR merely touched, a refactor bigger than the finding warrants). Append it to the iterate parking lot immediately (see below) so it cannot evaporate.

**Never silently drop a finding.** If the report has 7 findings, the final report has 7 dispositions.

**Parking lot:** same file and format as `/iterate` — `{scratchpad-dir}/iterate-parking-lot.md` from project.md's **Scratchpad Directory** (fall back to `/tmp/iterate-parking-lot.md`). One checklist line per item, self-contained enough to act on later, with file paths and provenance (which review pass deferred it). Skim the existing file first and never duplicate an item. THIS command sweeps the parking lot into the Refactoring Backlog itself in step 9 — do NOT leave that to `/resume`.

### 2. Research before fixing

For every FIX finding, read the affected file in full — not just the flagged lines. The review's suggested fix was written from the reviewer's context; verify it against the actual surrounding code (imports, auth wrappers, RLS policies, existing utilities, call sites) before applying it. If the suggested fix is wrong or there is a better one, implement the better fix and say so in the final report.

If a **Design System** doc is configured in project.md and any fix touches UI, read it and follow its tokens and patterns.

### 3. Implement the fixes

- Apply every FIX, keeping each change scoped to its finding. Improvements you notice along the way that are NOT in the report go to the parking lot, not into this commit.
- **Migration findings — roll back and amend in place, never stack a new migration.** When a finding requires changing a migration that has already been applied to dev (Supabase projects), the fix is to reverse the mistake on dev and re-apply the corrected version: adjust or reverse the already-applied DDL on dev via `execute_sql` so dev's actual schema matches the corrected migration, keep the SAME `(version, name)` tracking row (never add a new row, and never `DELETE` the row — the DDL/DML hook blocks that), and rewrite the same `supabase/migrations/<version>_<name>.sql` file with the fix. Verify with the migration-drift check before pushing. This is where the apply-to-dev-first flow is reconciled: `/execute` applies migrations to dev up front, so a migration finding here is corrected on dev directly rather than by adding a follow-up migration.
- **Update tests alongside the code:** add a regression test for every real bug fixed (especially Critical/High security and error-handling findings), fix tests the changes invalidate, and apply findings that target test code directly. Duplication/refactor findings need existing tests to still pass — new tests only if behavior changed.
- Follow the project's existing testing patterns and conventions.

### 4. Run targeted CI checks — STOP and fix ALL failures before proceeding. Do NOT push code that fails any check.

- `npx tsc --noEmit`
- `npm run lint`
- `npx vitest run --changed origin/<base-branch>` (only tests touching changed files; finishes in seconds)
- **Database tests (only when the branch touches database code):** if `git diff --name-only origin/<base-branch>...HEAD` includes migrations, RLS policies, SQL functions, or database test files (for Supabase projects: anything under `supabase/`), run the database test suite locally — `supabase test db`, starting the local stack first (`supabase start`) if it is not running. Neither tsc/lint/vitest nor the pre-push hook covers these; CI runs them as a separate job, so a broken schema or RLS expectation otherwise surfaces only after push.
- **Do NOT run the full `npm test` suite or `npm run build` locally** — the pre-push hook runs the full suite and CI runs the build.
- **If ANY check fails:** fix the issue, then re-run ALL checks from the beginning. Repeat until all pass. Never push with known failures.
- If any fix touched `package.json`, also run `npm audit`.

### 5. Commit

One commit for the pass (or a few logically grouped commits if the fixes are unrelated). Detailed message: which PR/review pass this addresses and what each change does. No Claude attribution, no AI footer.

### 6. Update the PR BEFORE pushing

Using `gh pr edit`, update the PR title (if scope changed) and description to cover ALL changes on the branch (`git diff <base-branch>...HEAD`), not just this pass. Update the test plan so it covers every changed file. Briefly note the review pass in the description (findings addressed, anything disputed or deferred).

### 7. Push

- Push the current branch to remote. **Never force push.** **Do NOT pause to ask "shall I push?" — pushing and updating the PR are non-destructive; just push.** The push starts CI, so steps 8-10 run after it, in parallel with the CI run — do not do them before the push.
- Do NOT rebase — this branch is already published with an open PR; rebasing would require a force push. If the base branch has moved and there are conflicts, merge `origin/<base-branch>` into the branch instead.

### 8. Verify against real data (for data-related fixes)

Now that the PR is updated and pushed, verify the fix against real data — this runs in parallel with CI, so it no longer blocks the push. If a fix changed queries, RLS-adjacent code, or data handling, verify the fixed path against real data the way `/execute` and `/resume` do. If verification surfaces a bug, fix it, commit, and push.

### 9. Sweep the parking lot into the Refactoring Backlog

A review pass is usually the last stop before merge — `/resume` may never run again on this branch, so this command does the sweep itself. Do NOT skip this step, do NOT ask for confirmation, and do NOT end the run by telling the user `/resume` will handle it:

- Look for `iterate-parking-lot.md` in the **Scratchpad Directory** configured in project.md (fall back to `/tmp/iterate-parking-lot.md`). If the file is missing or has no unchecked items, skip to the final report.
- Move every unchecked item — including items parked by earlier `/iterate` sessions on this branch, not just this pass's deferrals — into the **Refactoring Backlog** doc:
  - **Where the backlog doc lives:** read project.md for a **Refactoring Backlog** entry (path + repo). If none is configured, default to `docs/technical/REFACTORING_BACKLOG.md` in the docs repo (or the current repo if there is no docs repo).
  - Create the doc (with a short header) and/or a sensible section heading if either is missing.
  - Preserve each item's title, description, and file paths, and keep (or add) a one-line provenance note (the related issue/PR, and the date if known).
  - Skim the existing backlog first and never duplicate: skip items already captured, and if a parked item supersedes, merges with, or carries an explicit reconciliation note about an existing backlog entry, EDIT that entry rather than appending a new one.
- Delete the parking-lot file.
- Commit the backlog update to the appropriate repo (docs repo if configured, otherwise the current repo) and push it.

### 10. Final report

Present the outcome — no narration of the process, just the results:

- **Every finding and its disposition:** Fixed (what changed, one line each), Disputed (with the evidence), Deferred (now in the Refactoring Backlog).
- **Checks:** which ran and their results.
- **Commit and PR:** commit sha(s), PR link.
- **Backlog sweep:** which items were added to (or reconciled with) the Refactoring Backlog, and the commit that recorded them.

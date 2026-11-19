---
description: "Resume the /execute workflow from wherever it left off"
---

Resume the `/execute` workflow for: $ARGUMENTS

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, assignee, base branch, file paths, docs repo, etc.) before executing. Use those values throughout this workflow.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it. Do not describe what you would do or ask for permission - execute the step.**

This command assumes `/execute` or `/iterate` was already run.

## Workflow (execute all steps without stopping)

1. **Assess current state** — Identify the feature branch, issue number, and how far `/execute` got.
   - **Understand full PR scope** — Run `git log <base-branch>..HEAD --oneline` and `git diff <base-branch>...HEAD --stat` to see ALL commits and ALL changed files on this branch, not just recent commits. The full branch diff is the scope of work — any commit pushed to this branch (whether via `/execute`, `/iterate`, manual work, or other means) is part of the PR.
   - **Load research context** — Fetch the GitHub issue and check if it references a scratchpad file (look for a `## Research Context` section with a `**Scratchpad:**` path). If found, read the scratchpad file to recover research findings. Also check if a **Scratchpad Directory** is configured in project.md and look for a file matching this issue's topic there.
   - If a **Design System** doc is configured in project.md, check if the current code contradicts it. If so, ask the user if the Design System doc should be updated. Do not proceed until resolved.
   - If `/execute` already got past writing tests, **critically evaluate the existing tests**: are they comprehensive enough? Consider: are all key code paths covered (happy path, error cases, edge cases)? Are there untested branches or conditions? Do the tests verify behavior, not just that code runs without errors? If `/iterate` changed the code, tests may be invalidated. **Start again from step 2** to fill any gaps.
   - If `/execute` stopped before writing tests, pick up from where it left off.

2. **Write comprehensive tests** for the current code:
   - Unit tests for individual functions/components
   - Integration tests for feature workflows
   - Follow the project's existing testing patterns and conventions

3. **Run targeted CI checks — STOP and fix ALL failures before proceeding. Do NOT push code that fails any check.**
   - `npx tsc --noEmit`
   - `npm run lint`
   - `npx vitest run --changed origin/<base-branch>` (only tests touching changed files; finishes in seconds)
   - **Database tests (only when the branch touches database code):** if `git diff --name-only origin/<base-branch>...HEAD` includes migrations, RLS policies, SQL functions, or database test files (for Supabase projects: anything under `supabase/`), run the database test suite locally — `supabase test db`, starting the local stack first (`supabase start`) if it is not running. Neither tsc/lint/vitest nor the pre-push hook covers these; CI runs them as a separate job, so a broken schema or RLS expectation otherwise surfaces only after push.
   - **Do NOT run the full `npm test` suite or `npm run build` locally** — the project's pre-push hook runs the full test suite before push, and CI runs the build.
   - **If ANY check fails:** fix the issue, then re-run ALL checks from the beginning. Repeat until all pass. Never push with known failures.

4. **Run `npm audit`** if this branch changed dependencies (`git diff --name-only origin/<base-branch>...HEAD` includes `package.json`/`package-lock.json`) — CI gates on it, so it stays before push. Skip when the lockfile is unchanged.

5. **Commit** with detailed message (reference the issue: "Closes #<issue_number>", no Claude footer)

6. **Rebase on base branch:** `git fetch origin <base-branch>` then `git rebase origin/<base-branch>`

7. **Push** the branch to remote with upstream tracking — this starts CI. **Do NOT pause to ask "shall I push?" — pushing a feature branch and opening its PR are non-destructive and reversible. Just push.** (Force push stays forbidden.) Steps 9-13 are bookkeeping that runs after the PR is open, in parallel with the CI run; do not do them before the push.

8. **Open (or update) the PR** — a lean step: the push already started CI, so just open the PR with a description. Do NOT fold issue bookkeeping (assigning, comment, labels, closing) into this step — that is step 9.
   - Summary must cover ALL changes on the branch (use `git diff <base-branch>...HEAD` to review), not just changes made in this session
   - Include test coverage and test plan
   - Reference: "Closes #<issue_number>"
   - If updating an existing PR, update its description with `gh pr edit` so it reflects the current state

9. **Record the issue state** — with the PR open, update its tracking (recording actions, kept separate from opening the PR):
   - Assign the PR to the default assignee (from project.md)
   - Comment on the issue: `gh issue comment <issue_number> --body "Implementation PR created: #{PR_NUMBER}"`
   - Swap the issue label: `gh issue edit <issue_number> --remove-label "planned" --add-label "in-review"`
   - Close the issue: `gh issue close <issue_number> --reason completed`

10. **Verify against real data** (for data-related changes) — runs after the PR, in parallel with CI. If verification surfaces a bug, fix it, commit, and push.

11. **Update Data Fields doc** — If this implementation changed the database (migrations, new/modified tables, columns, storage buckets, or RLS policies):
    - Check if a **Data Fields Doc** is configured in project.md
    - If so, read the doc and update it to reflect all database/storage changes made in this PR
    - Add new tables, update modified schemas, document new storage paths and RLS policies
    - Commit the update to the appropriate repo (docs repo if the file is in one, otherwise current repo)
    - If no Data Fields Doc is configured, skip this step

12. **Sweep the iterate parking lot into the Refactoring Backlog:**
    - Look for `iterate-parking-lot.md` in the **Scratchpad Directory** configured in project.md (fall back to `/tmp/iterate-parking-lot.md` if no scratchpad dir is configured).
    - If the file is missing or has no unchecked items, skip this step.
    - Otherwise, append every unchecked item to the **Refactoring Backlog** doc automatically — do NOT ask for confirmation:
      - **Where the backlog doc lives:** read project.md for a **Refactoring Backlog** entry (path + repo). If none is configured, default to `docs/technical/REFACTORING_BACKLOG.md` in the docs repo (or the current repo if there is no docs repo).
      - Create the doc (with a short header) and/or a sensible section heading if either is missing.
      - Preserve each item's title, description, and file paths, and keep (or add) a one-line provenance note (the related issue/PR, and the date if known).
      - Skim the existing backlog first and skip any item already captured — never duplicate.
    - Delete the parking-lot file.
    - Commit the backlog update to the appropriate repo (docs repo if configured, otherwise the current repo) and tell the user which items were added.

13. **Update planning documentation:**
    - Check project.md for docs repo config
    - Search for the task in the sprint plan
    - **NEVER create new entries in the sprint plan.** The sprint plan is for pre-planned work only.
    - **If the task exists in the sprint plan:** mark as completed with date and PR number
    - **If the task does NOT exist in the sprint plan:**
      - Check if a **Fixes Directory** is configured in project.md
      - If so, append to the current month file (`fixes-YYYY-MM.md`), creating it if needed
      - If no Fixes Directory, skip — do not add to the sprint plan
    - Commit planning doc updates to the appropriate repo

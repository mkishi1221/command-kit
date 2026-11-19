---
description: "Pull hotfixes from main to dev via a sync PR"
---

Sync hotfixes from main into dev: $ARGUMENTS

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, assignee, base branch, file paths, etc.) before executing. Use those values throughout this workflow.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it. Do not describe what you would do or ask for permission - execute the step.**

## Workflow

1. **Fetch latest state:**
   ```bash
   git fetch origin main dev
   ```

2. **Check for unsynced commits** — list commits on main that are not yet in dev:
   ```bash
   git log origin/dev..origin/main --oneline --no-merges
   ```
   If there are no commits, report "main and dev are already in sync" and **STOP**.

3. **Gather context** — for each unsynced commit, identify:
   - Associated PRs (look for merge commits or use `gh pr list --base main --state merged`)
   - Whether any include database migrations (check for files in `supabase/migrations/`)
   - Whether any include edge function changes
   - Summary of what changed

4. **Create a dedicated sync branch** — NEVER use `main` as the head branch:
   ```bash
   git checkout -b sync/main-to-dev-$(date +%Y%m%d-%H%M%S) origin/dev
   ```

5. **Merge main into the sync branch:**
   ```bash
   git merge origin/main --no-edit
   ```
   - If there are **merge conflicts**: list the conflicting files, print the conflict markers, and **STOP**. Ask the user how to resolve each conflict.
   - If the merge is clean: proceed.

6. **Run targeted CI checks — STOP and fix ALL failures before proceeding:**
   - `npx tsc --noEmit`
   - `npm run lint`
   - `npx vitest run --changed origin/dev` (only tests touching changed files)
   - **If ANY check fails:** report the failure and **STOP**. Ask the user how to proceed.

7. **Push the sync branch:**
   ```bash
   git push -u origin HEAD
   ```
   The push starts CI. The only gates are the genuine blockers above (no unsynced commits, merge conflicts, CI failures) — none of which apply here, so continue straight to the PR.

8. **Create the PR** targeting dev — do NOT stop for confirmation; opening a PR is not destructive:
   - Title: `Sync hotfixes from main to dev (YYYY-MM-DD)`
   - Body should include:
     ```
     ## Summary
     Backmerge hotfix commits from `main` into `dev`.

     ## PRs Included
     [table of PR numbers, titles, and labels from the unsynced commits]

     ## Changes
     [brief description of what the hotfixes addressed]

     ## Test Plan
     - [ ] CI passes
     - [ ] No merge conflicts
     - [any migration-specific checks if applicable]
     ```
   - Use `gh pr create --base dev` with a HEREDOC for the body
   - Assign to the default assignee (from project.md)

9. **Report the result:**
    - Print the PR URL
    - If migrations were included, remind the user that the migration files are expected to be no-ops on dev (the MCP already applied them during the hotfix workflow)

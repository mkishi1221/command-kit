---
description: "Create a release branch from dev and open a PR into main"
---

Create a new release from dev → main: $ARGUMENTS

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, assignee, base branch, file paths, etc.) before executing. Use those values throughout this workflow.

> **Stack note:** The migration and edge-function deploy-inventory steps assume **Supabase**. If your project deploys differently, ask Claude Code to adapt those checks; the branch and PR flow is stack-agnostic.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it. Do not describe what you would do or ask for permission - execute the step.**

## Workflow

### Phase 1: Pre-release analysis

1. **Ensure dev is clean and up to date:**
   ```bash
   git checkout dev
   git pull origin dev
   ```

2. **Prepare a scratch directory** for intermediate results that agents write to disk (avoids context overflow from passing large outputs through prompts):
   ```bash
   SCRATCH="/tmp/release-$(date +%s)"
   mkdir -p "$SCRATCH"
   ```
   Save the `$SCRATCH` path for use in agent prompts and cleanup.

3. **Determine the release name:** if `$ARGUMENTS` includes a name or version, use it; otherwise use today's date (`YYYY-MM-DD`). Save as `$RELEASE_NAME`.

4. **Run the scout agent** (foreground — analysis agents need its output):

   Launch a single Agent with this prompt (substitute `$SCRATCH` with the actual path):

   > You are gathering release metadata for a dev-to-main release. Other agents will use your output (written to disk) to perform risk, legal, deployment, and CI analysis.
   >
   > TASKS:
   > 1. Read .claude/project.md for the GitHub repo slug, assignee, and (for Supabase projects) the dev/prod project IDs
   > 2. Find the merge base between main and dev: `git merge-base origin/main origin/dev`
   > 3. Get the merge base date: `git show -s --format=%ci <merge-base-hash>`
   > 4. List all PRs merged to dev since the merge base:
   >    `gh pr list --base dev --state merged --json number,title,labels,mergedAt --limit 200`
   >    Filter to ONLY PRs whose mergedAt is after the merge base date.
   > 5. List direct commits not associated with PRs: `git log <merge-base>..origin/dev --oneline --no-merges`
   > 6. Get diff stats: `git diff --stat <merge-base>..origin/dev`
   >
   > Write ALL findings to `$SCRATCH/scout.md` using the Write tool. Use this format:
   >
   > ```
   > MERGE_BASE: <hash>
   > MERGE_BASE_DATE: <date>
   > GITHUB_REPO: <owner/repo from project.md>
   > DEFAULT_ASSIGNEE: <from project.md>
   > DEV_PROJECT_ID: <from project.md>
   > PROD_PROJECT_ID: <from project.md>
   >
   > ## PRs in this release
   > | PR | Title | Labels | Merged |
   > [one row per PR]
   >
   > ## Grouped Changelog
   > ### Features / Enhancements / Bug Fixes / Other
   > [grouped by label — skip empty groups]
   >
   > ## Direct Commits
   > [commits not from PRs, or "None"]
   >
   > ## Diff Stats
   > [git diff --stat output]
   > ```
   >
   > After writing the file, respond only with "Done".

5. **Launch all analysis agents in parallel** (background — they run concurrently):

   Launch ALL five agents in a **single message** with `run_in_background: true`. Substitute `$SCRATCH` with the actual path in every prompt.

   **a. `risk`** — Per-PR risk assessment:
   - Read context from `$SCRATCH/scout.md`
   - For EVERY PR: read the diff (`gh pr diff <number>`), categorize (Database Migration, Middleware/Routing, Dependency, Env Var, API/Server Action, UI/Page), assign risk level (HIGH/MEDIUM/LOW/NEGLIGIBLE), note mitigation
   - Write to `$SCRATCH/risk.md`: Per-PR Risk Assessment table, plus supplementary tables ONLY for categories with actual changes (Database Migrations, Dependency Changes, Middleware & Routing, Environment Variables)

   **b. `legal`** — Legal compliance check:
   - Read context from `$SCRATCH/scout.md`
   - Read Terms of Service and Privacy Policy (check src/content/legal/ or paths from .claude/project.md)
   - For each PR diff: check for new personal data collection, new third-party services, data sharing changes, new cookies/tracking, data retention changes, auth flow changes, content licensing changes, new user obligations, international data transfers
   - Write to `$SCRATCH/legal.md`: Legal Compliance Check table, then `LEGAL_STATUS: PASS` or `LEGAL_STATUS: FAIL` with details

   **c. `deploy`** — Deployment inventory:
   - Read context from `$SCRATCH/scout.md`
   - MIGRATIONS (Supabase projects): find migration files in diff, use Supabase MCP (ToolSearch for "supabase" tools) to query schema_migrations on both dev and prod project IDs, compare which are pending
   - EDGE FUNCTIONS: find changed function files, check _shared/ imports, compare MCP list_edge_functions hashes between dev and prod
   - ENV VARS: check for new variables in .env.example
   - Write to `$SCRATCH/deploy.md`: Migrations table (Pending/Already applied), Edge Functions table, Environment Variables

   **d. `ci`** — CI checks (run all, report pass/fail for each):
   - Run sequentially: `npx tsc --noEmit`, `npm run lint`, `npm test`, `npm audit`, `npm run build`
   - Write to `$SCRATCH/ci.md`: CI Check Results table (TypeScript/Lint/Tests/Security Audit/Build), then `CI_STATUS: ALL_PASS` or `CI_STATUS: HAS_FAILURES` with failure details

   **e. `backlog`** — Backlog gap review (is anything important being left out of this release?):
   - Read context from `$SCRATCH/scout.md` (has the merge base and GitHub repo)
   - **Release completeness:** confirm the release carries everything merged to dev. Compare `gh pr list --base dev --state merged --json number,title,mergedAt --limit 50` against the merge-base..dev range (`git log <merge-base>..origin/dev --oneline`). Flag anything merged to dev that never reached main.
   - **Open in-review / ready PRs:** `gh pr list --base dev --state open --json number,title,labels,updatedAt,mergeable,reviewDecision --limit 50`. List open PRs that are close to done (approved, mergeable, non-draft) and could arguably belong in this release. Do NOT assume they must ship.
   - **Ready/unshipped issues:** `gh issue list --state open --label ready-to-implement --json number,title` and `--label in-review`. Flag anything done-but-unshipped. Note any issue labelled **Urgent** whose PR is still open.
   - **Sync/hotfix gaps:** check for commits on main not in dev (`git log origin/dev..origin/main --oneline`) — an un-backmerged hotfix. Report or "None".
   - **Planned fixes doc:** read `.claude/plans/fixes/fixes-<YYYY-MM>.md` for the current month (path from `.claude/project.md`, in the docs repo); flag any item marked done/ready that is not in this release.
   - **Sprint plan:** skim the sprint plan (path from `.claude/project.md`) for any item flagged complete/in-progress that should be shipping.
   - Write to `$SCRATCH/backlog.md`: sections for Release completeness (YES/NO + evidence), Merged-but-unreleased, Open PRs that could belong (table with recommendation), Ready/unshipped issues, Sync/hotfix gaps, Planned fixes not in release, then a final line `BACKLOG_VERDICT: NOTHING_MISSING` or `BACKLOG_VERDICT: MINOR_GAPS` or `BACKLOG_VERDICT: IMPORTANT_MISSING` with a bullet list of each gap and why it matters

6. **Wait for all background agents to complete.** Verify all files exist:
   ```bash
   for f in $SCRATCH/{scout,risk,legal,deploy,ci,backlog}.md; do
     if [ -f "$f" ]; then echo "OK: $(basename $f)"; else echo "MISSING: $(basename $f)"; fi
   done
   ```

   If any files are missing after all agents have completed, re-launch agents for just the missing sections.

7. **Assemble the release analysis:**

   Read ALL six files from `$SCRATCH/`. Synthesize into:

   **a. `blockers` list** — scan the analysis files:
   - If `CI_STATUS` is `HAS_FAILURES` → add each specific failure
   - If `LEGAL_STATUS` is `FAIL` → add "Legal documents require updates before release"

   **a2. `gaps` list** — from `backlog.md`:
   - Capture the `BACKLOG_VERDICT` and every gap it lists. These are NOT blockers (they do not stop the release), but `IMPORTANT_MISSING` gaps require an explicit user decision before Phase 2 (see step 9).

   **b. `summary`** — markdown release summary for user review:
   - Blockers (show prominently at top if any)
   - **Backlog gaps** (show prominently right after blockers if the verdict is `MINOR_GAPS` or `IMPORTANT_MISSING` — list each gap and why it matters)
   - Overview (feature themes, PR count, lines changed)
   - Grouped changelog (Features, Enhancements, Bug Fixes, Other — skip empty groups)
   - Per-PR risk assessment table
   - Supplementary risk tables (only for categories with content)
   - Legal compliance results
   - Deployment inventory
   - CI check results table
   - Backlog gap review (release completeness + verdict)

   **c. `prTitle`** — short descriptive title under 70 chars, format: "Release: <key themes>"

   **d. `prBody`** — complete PR body markdown. ONLY include sections with actual content:
   - `## Summary` — one paragraph overview
   - `## PRs Included` — table from scout data
   - `## Risk Assessment` — per-PR table + supplementary tables for categories with changes
   - `## Legal Compliance` — results from legal analysis
   - `## Smoke Test` — manual testing checklist derived from actual changes, grouped by theme, specific and actionable, every MEDIUM+ risk PR gets at least one test step
   - `## Pre-merge Checklist` — `[x]` for completed checks, `[ ]` for pending (code review, smoke test)
   - `## Post-merge Checklist` — specific deployment steps: name each pending migration, each out-of-sync edge function, new env vars, error monitoring focus areas, run /db-audit

   **e. `legalIssues` list** — one entry per affected document (with document name, sections, and reason), empty if no legal updates needed

8. **Clean up scratch files:**
   ```bash
   rm -rf $SCRATCH
   ```

9. **Handle the results:**

   - **If `blockers` is non-empty:**
     - Print all blockers clearly
     - If there are CI failures: instruct the user to fix them and re-run `/release`
     - If there are legal issues: create **separate** GitHub issues — one per document in `legalIssues`. Label each `legal`. Assign to the project's default assignee (from project.md). Print the issue URLs.
     - **STOP the release workflow.** Do NOT proceed to Phase 2. Explain what must be resolved first.

   - **If `blockers` is empty:**
     - Print the `summary`
     - **If `gaps` verdict is `IMPORTANT_MISSING`:** call out each missing item prominently, explain why it matters, and **STOP** — ask the user to explicitly choose: (a) hold the release so the missing work can be merged to dev and re-cut, or (b) proceed anyway and defer it. Do NOT proceed to Phase 2 until they decide. This is a genuine must-decide gap, not a routine confirmation.
     - **Otherwise** (`NOTHING_MISSING` or `MINOR_GAPS`): **proceed straight to Phase 2 and create the release PR — do NOT stop for confirmation.** All checks passed and neither gate applies (no blockers, no `IMPORTANT_MISSING` gap), so there is nothing to authorise: opening a PR is not destructive and is reversible. The `summary` is already printed above and surfaces any `MINOR_GAPS` for the record — note them but do not hold the release.

### Phase 2: Create release PR

10. **Create the release branch:**
    - Use the `$RELEASE_NAME` from step 3
    - Create branch: `git checkout -b release/$RELEASE_NAME` from dev

11. **Push and create the PR:**
    - Push: `git push -u origin release/$RELEASE_NAME`
    - Create PR targeting main using `prTitle` and `prBody`
    - Use `gh pr create --base main` with a HEREDOC for the body
    - Assign PR to the project's default assignee (from project.md)

12. **Report the result:**
    - Print the PR URL
    - Remind user of post-merge steps, including running `/db-audit` after migrations and edge functions are deployed to prod — that step catches deployment gaps (e.g. a migration applied to dev but forgotten on prod, or an edge function redeployed to prod via hotfix but not back to dev).

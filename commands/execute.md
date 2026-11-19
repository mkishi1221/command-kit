---
description: "Execute implementation of a GitHub issue that already has a detailed plan"
---

Execute the implementation plan from GitHub issue: $ARGUMENTS

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, assignee, base branch, file paths, docs repo, etc.) before executing. Use those values throughout this workflow.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it. Do not describe what you would do or ask for permission - execute the step.**

This command assumes the issue already contains a detailed implementation plan. Do NOT enter plan mode.

## Workflow (execute all steps without stopping)

**Optimise for time-to-push.** The moment you push, CI starts running, so the critical path (steps 1-17) is only the work that determines whether CI passes — implement, test, run the fast local checks, commit, push. Opening the PR (step 18) is a lean step: just open it with its description. Everything after that — recording the issue state, real-data verification, Data Fields/planning docs, scratchpad cleanup, Sentry (steps 19-25) — is bookkeeping that does NOT gate CI, so it runs AFTER the PR is open, in parallel with the CI run. **Each of those is its own distinct step; never fold them back into the PR step.** Opening the PR is not the finish line — the recording steps are. Do not do that follow-up work before the PR exists, and do not sit idle waiting for CI once it is open. The only things that stay before push are the checks that gate a clean CI run — skipping them just trades PR speed for a wasted red-CI cycle.

1. Fetch the GitHub issue details using: gh issue view <issue_number>
2. Read and understand the implementation plan in the issue
3. **Load research context** — Check if the issue body references a scratchpad file (look for a `## Research Context` section with a `**Scratchpad:**` path). If found, read the scratchpad file to recover research findings from the planning phase. Also check if a **Scratchpad Directory** is configured in project.md and look for a file matching this issue's topic there. If the issue involves UI changes, also check `docs/product/design-research/` in the docs repo for a design scratchpad file matching this issue's topic — it contains design references and rationale from the planning phase.
4. Research the current codebase to understand context for the planned changes
   - Use the scratchpad and issue's Research Context section as a starting point — these contain file paths, patterns, and findings from the planning phase, so you can skip re-researching what's already documented
   - **Load prototype spec** — only if the issue references one:
     - The `## Prototype` section gives the slug and source path — use that prototype.
     - **If the issue references a prototype:**
       - **Open the file and Read its full JSX source yourself — now, before any other research.** Read the CANONICAL page (`prototype/src/pages/{folder}/{slug}.jsx`): working code with the exact component structure, Tailwind classes, layout logic, spacing, colors, and visual hierarchy already built. **The JSX source is the PRIMARY spec.** A scratchpad, research digest, issue summary, or a subagent's description of the prototype is a POINTER to this file, never a substitute for it — building from the summary instead of the source is the single most common way this step fails (silent divergence from the design). If a subagent read the prototype, you still Read it yourself; its summary dropped the exact values. Ignore variant files (`{slug}-{name}.jsx`) and anything marked NON-CANONICAL unless the issue names one.
       - Read the matching research notes (`prototype/research/{folder}-{slug}-*/notes.md`) — the `**Chosen:**` line and the user's recorded feedback are the design intent behind the JSX; use them to resolve any porting ambiguity
       - Do NOT take screenshots — the sandbox has no screenshot tooling; the JSX and the notes are the spec
       - **The prototype is the AUTHORITATIVE spec for layout and structure.** The JSX is your starting code. Port it into the real app's architecture (proper imports, real data, project components, routing), but preserve the prototype's markup structure, class names, layout patterns, and visual hierarchy. Do NOT rewrite the UI from scratch.
       - **Reconcile tokens with the Design System doc.** Where the prototype's colors, fonts, spacing, borders, or radii diverge from the Design System doc, flag it and reconcile with the user — update the prototype or the doc — rather than silently overriding one. The prototype drives layout and component structure.
       - **Do NOT change existing dialog designs.** Use the app's existing dialog components and patterns as-is unless the issue specifically asks for dialog changes.
     - **If the issue references no prototype:** use the design references and ASCII layouts from the issue body (and the design system).
   - If the issue involves UI changes and a **Design System** doc is configured in project.md, read it and follow its tokens, patterns, and conventions throughout implementation
5. **Research best practices** — Before implementing, check official docs for the technologies this issue touches:
   - Read the **Tech Stack** table in project.md to identify which libraries are relevant
   - For each relevant library, search its official documentation for current best practices:
     - For Supabase projects, use the Supabase MCP `search_docs` tool for backend topics (auth, RLS, storage, edge functions, realtime, SSR)
     - Use web search for other libraries (Next.js, React, Tailwind, the project's component library from the Tech Stack table, Mux, dnd-kit, etc.)
   - Specifically look for:
     - Recommended patterns and APIs for the implementation's use case
     - Deprecations or breaking changes that affect the planned approach
     - Security guidance (especially for auth, RLS, and input handling)
   - If no Tech Stack table exists in project.md, skip this step
6. **Determine base branch** — Check if the issue has a `hotfix` label or if the issue body's Research Context specifies `Fix type: hotfix`:
   - **If hotfix:** use `main` as the base branch and `hotfix/` as the branch prefix
   - **Otherwise:** use the project's base branch (from project.md) and the standard branch prefix
7. Fetch the base branch so the new branch starts from its latest tip. **The working tree may currently be on a previous issue's feature branch** (carrying that issue's commits ahead of the base). Branching off the *current* branch would stack this issue's PR on top of that unmerged work and pull the other issue's changes into your diff — so always branch off the freshly-fetched base, never off whatever branch you happen to be on.
   - `git fetch origin <base-branch>` (the base determined in step 6)
   - If the working tree has any uncommitted changes at this point, `git stash -u` first (there should be none this early — implementation has not started), then `git stash pop` after step 8.
8. Create a new feature branch **off the fetched base tip** so it is guaranteed to start from a clean base even if you were on another issue's branch:
   - `git checkout -b <new-branch> origin/<base-branch>` (this branches directly off the fetched base, not the current `HEAD`)
   - Naming: `hotfix/issue-<number>-brief-description` for hotfixes, `fix/issue-<number>-brief-description` for bug fixes, `feature/issue-<number>-brief-description` for features
9. **Load review checklist** — Check if the issue body has a `## Review Checklist` section. If found, read its security, error handling, and reuse requirements. These must be implemented as part of the code — they are not optional notes. Specifically:
   - **Security items** (auth checks, input validation, RLS, rate limiting, secrets) → implement these as you build each endpoint/action/component, not as a separate pass
   - **Error handling items** (generic client messages, server-side logging, async error paths) → follow the specified strategy for every error path in the implementation
   - **Reuse items** (existing utilities, patterns) → use the specified existing code instead of reimplementing
   If no Review Checklist section exists, apply these concerns using your own judgment.
10. Implement all changes according to the plan in the issue
   - **STOP — before editing any file, confirm you are on the fresh branch from step 8.** This is the checkpoint that catches a skipped step 7/8. Run:
     - `git rev-parse --abbrev-ref HEAD` → must be the `<prefix>/issue-<number>-*` branch you created in step 8, NOT the base branch and NOT a previous issue's branch.
     - `git rev-list --count origin/<base-branch>..HEAD` → must be `0`. A non-zero count means the branch is stacked on another issue's commits (you branched off the wrong place); redo steps 7-8 to branch cleanly off `origin/<base-branch>`.
     If either check fails, STOP and fix the branch before making a single edit. Never implement on a pre-existing or stacked branch — it conflates two issues' PRs and blocks this one from merging until the other does.
   - **STOP — if the issue references a prototype or names any authoritative source, confirm you Read its full source in THIS session before editing a single `src/` file.** This is the checkpoint that catches building from a summary instead of the source. The full prototype JSX (or whatever file the issue marks authoritative) must appear as a `Read` you performed this session — not a scratchpad digest, not a subagent's summary, not recall from a similar page. If you have not, go back to step 4 and Read it now. A `PreToolUse` hook enforces this: the first edit to product `src/` is blocked until the named prototype file has been Read in-session.
   - **If the plan includes a database migration, apply it to dev FIRST — before pushing** (follow the project's migration policy in project.md / CLAUDE.md for the mechanics). The dev database is the user's own, so apply schema changes to it without asking. Applying before the push means the dev tracking row already exists when the branch is pushed, so the migration-drift check passes on the FIRST CI run — deferring it until after review would fail the drift check and force a wasteful second CI run. Do NOT hold the migration back for post-review application; if a later review flags the migration, `/address-review` owns rolling it back and re-applying.
   - **UI primitives come from the project's component library** (see project.md → Design System). NEVER hand-roll native `<button>`, `<select>`, `<input>`, `<textarea>`, `<dialog>`, or custom-built calendars, date pickers, dropdowns, tooltips, tabs, toasts, or pagination when the library provides them. When a widget seems missing, compose library primitives first; follow any escape-hatch policy in project.md before writing a custom one.
   - **User-facing microcopy reads like shipped product copy — terse, concrete, imperative.** If a prototype or design scratchpad was loaded, its copy IS the spec — port the strings verbatim. Otherwise, write in the register real products use (matching any microcopy notes in the design scratchpad). Avoid the AI-slop tells: filler ("however suits you"), em-dash reassurance asides, narrating the mechanics ("we turn this into text and add it…"), internal jargon leaking into the UI ("storage only"), and eyebrows that just repeat the title. Helper text states constraints only; buttons are short verbs.
   - **If a prototype was loaded in step 4:** The prototype JSX is your starting code — port it, don't rewrite it. Copy the prototype's markup, Tailwind classes, and layout structure into the real app components. Adapt imports (use the project's component library per project.md → Design System instead of inline elements), wire up real data instead of placeholder content, and integrate with the app's routing/state — but keep the same DOM structure, class names, spacing, and visual hierarchy. If the prototype uses a specific layout pattern, use it. Do NOT simplify, redesign, or "improve" the UI.
     - **Reconcile token conflicts, don't override.** When the prototype's hardcoded tokens (colors, spacing, typography, borders) conflict with the Design System doc, flag it and reconcile with the user — update the prototype or the doc. The prototype drives layout and structure.
     - **Do NOT change existing dialog designs.** When the prototype uses dialogs/modals, use the app's existing dialog components and patterns as-is. Do not redesign, restyle, or restructure dialogs unless the issue specifically asks for dialog changes.
11. **Write tests** — this step is NOT optional. Implement every test listed in the issue's `## Test Plan` or `## Regression Tests` section:
    - Unit tests for individual functions/components
    - Integration tests for feature workflows
    - Follow the project's existing testing patterns and conventions
    - **If the issue has no test plan or it is vague**, research the codebase's existing test patterns and write tests covering: happy path, error states, edge cases, and access control (RLS/auth) before proceeding
    - Do NOT skip this step even if the implementation seems simple
12. **Run targeted CI checks locally — this is the last gate on the critical path before push, so keep it to the fast checks below and nothing slower. STOP and fix ALL failures before proceeding. Do NOT push code that fails any check.**
    - TypeScript check: `npx tsc --noEmit`
    - Lint check: `npm run lint`
    - Targeted tests: `npx vitest run --changed origin/<base-branch>` (runs only tests touching changed files; finishes in seconds)
    - **Database tests (only when the branch touches database code):** if `git diff --name-only origin/<base-branch>...HEAD` includes migrations, RLS policies, SQL functions, or database test files (for Supabase projects: anything under `supabase/`), run the database test suite locally — `supabase test db`, starting the local stack first (`supabase start`) if it is not running. Neither tsc/lint/vitest nor the pre-push hook covers these; CI runs them as a separate job, so a broken schema or RLS expectation otherwise surfaces only after push.
    - **CI test-split check (only when the branch changes CI test-selection/sharding config):** if `git diff --name-only origin/<base-branch>...HEAD` touches the test CI workflow's shard matrix or test-run step, an affected-file/test-region selector, a vitest sequencer or shard config, or a committed timing manifest, verify the change keeps every test path **parallelized**. Simulate the test plan for a representative diff (or read the resulting shard matrix) and confirm the affected/fast path still shards across runners rather than collapsing a broad selection into one un-sharded job. A fast path that silently runs most of the suite serially in a single job is slower than the sharded full run it was meant to avoid — that defeats the split and must be fixed before push.
    - **Do NOT run the full `npm test` suite or `npm run build` locally** — the project's pre-push hook runs the full test suite as the final safety net before push, and CI runs the build. Running them locally doubles wall time without catching anything new.
    - **If ANY check fails:** fix the issue, then re-run ALL checks from the beginning. Repeat until all pass. Never push with known failures.
13. Run `npm audit --audit-level=high` **only if this branch changed dependencies** — i.e. `git diff --name-only origin/<base-branch>...HEAD` includes `package.json` or `package-lock.json`. CI gates on this exact command, so running it locally when deps changed avoids a wasted red-CI cycle; when the lockfile is unchanged from base there is nothing new to find, so skip it and stay off the critical path.
14. Commit with a detailed message following the repository's conventions:
    - Short imperative summary line
    - Blank line
    - Detailed body with bullet points explaining changes and tests added
    - Reference the issue: "Closes #<issue_number>"
    - Do NOT include Claude Code footer or Co-Authored-By lines
15. Pull latest base branch and rebase before pushing:
    - `git fetch origin <base-branch>` then `git rebase origin/<base-branch>` (use the base branch determined in step 6)
    - If there are conflicts, resolve them and continue the rebase
    - If the rebase reported "up to date" / "current" (HEAD did not move), go straight to push — there is nothing new to re-check. Otherwise re-run the fast targeted checks (tsc, lint, `vitest --changed`, and database tests if they ran in step 12) because the base branch may have introduced breaking changes. The pre-push hook will run the full test suite when you push.
16. **Hotfix risk gate** (hotfixes only — skip for regular fixes):
    - Re-read the `## Risk Assessment` section from the issue
    - Verify the implementation matches the assessed risk:
      - Does the actual diff stay within the stated blast radius, or did the fix touch more than planned?
      - If the confidence level was "Low", flag this to the user and do NOT push until they confirm
      - If the fix introduced migrations not mentioned in the risk assessment, flag this to the user
    - Print a one-line risk summary: `Hotfix risk: [confidence] — [blast radius summary]`
    - If anything deviates from the risk assessment, STOP and ask the user before pushing
17. Push the branch to remote with upstream tracking. **Do NOT pause to ask "shall I push?" — pushing a feature branch and opening its PR are non-destructive and reversible, and the plan was already approved. Just push.** (Force push stays forbidden.)
18. **Open the PR** — a lean step: the push already started CI, so just open the PR with a description. Do NOT fold issue bookkeeping (linking, assigning, labels, closing) into this step — that is step 19.
    - **Base branch:** Use `gh pr create --base <base-branch>` with the base branch determined in step 6 (e.g., `--base main` for hotfixes)
    - **If pushing additional commits to an existing PR, update the PR description BEFORE pushing:** `gh pr edit --title "..." --body "updated description here"`, then push. This keeps the description reflecting the current state of changes.
    - The description includes:
      - Summary of changes
      - Test coverage details (what was tested and how)
      - **Comprehensive manual test plan** — the test plan MUST cover every changed component/file, not just the primary fix target. Review `git diff --stat` and include at least one manual verification step for each changed file. Prioritise into two groups:
        - **Critical (must test):** The component where the bug was reported, the highest-traffic paths, files that gained new error handling where none existed before, and a regression check that existing validation/error messages still work.
        - **Nice to test:** Remaining files that follow the same pattern as the critical ones (lower risk since the same wrapper/logic applies). Group by feature area (e.g., "Pets & Family", "Portfolio", "Brands") for readability.
      - Reference: "Closes #<issue_number>"
    - Do NOT include Claude Code footer

**The PR is now open and CI is running.** Steps 19-25 do NOT gate PR creation — do them now, while CI runs, instead of waiting for CI to finish. If any of them surfaces a problem that needs a code change, fix it, commit, and push (the running CI picks up the new commit, exactly as when addressing a CI failure).

19. **Record the issue state** — with the PR open, update its tracking. These are recording actions, kept separate from opening the PR:
    - Assign the PR to the project's default assignee (from project.md)
    - Link the PR to the issue: `gh pr edit {PR_NUMBER} --add-issue <issue_number>`
    - Comment on the issue: `gh issue comment <issue_number> --body "Implementation PR created: #{PR_NUMBER}"`
    - Swap the issue label to in-review: `gh issue edit <issue_number> --remove-label "planned" --add-label "in-review"`
    - Close the issue (it will reopen if the PR is closed without merging): `gh issue close <issue_number> --reason completed`

20. **Verify against real data** (for data-related changes like API responses, database queries, external services):
    - Don't assume mocks passing means the fix works
    - Test against actual APIs/databases when possible
    - Create a quick script to verify the behavior with real data
    - This runs in parallel with CI, so it no longer blocks the PR — but do NOT skip it. If verification surfaces a bug, fix it, commit, and push the fix.
21. **Update Data Fields doc** — If this implementation changed the database (migrations, new/modified tables, columns, storage buckets, or RLS policies):
    - Check if a **Data Fields Doc** is configured in project.md
    - If so, read the doc and update it to reflect all database/storage changes made in this PR
    - Add new tables, update modified schemas, document new storage paths and RLS policies
    - Commit the update to the appropriate repo (docs repo if the file is in one, otherwise current repo)
    - If no Data Fields Doc is configured, skip this step
22. Update any relevant planning documentation:
    - **Check project.md for a docs repo configuration.** If a separate docs repo is configured:
      - Find it at the relative path specified in project.md
      - The sprint plan file location is specified in project.md
    - **If no separate docs repo**, use the sprint plan in the current project
    - **Search the sprint plan for an existing entry** matching this issue/feature
    - **NEVER create new entries in the sprint plan.** The sprint plan is for pre-planned work only. If the task isn't already there, route it as follows:
    - **If the task already exists in the sprint plan:**
      - Mark the feature/task as completed with ✓ or [x]
      - Add completion date (today's date) and PR number
      - Update status from "planned"/"in-progress" to "completed"
      - Update any progress counters or completion percentages
      - Note any dependent features that are now unblocked
    - **If the task does NOT exist in the sprint plan:**
      - Check if a **Fixes Directory** is configured in project.md (e.g., `.claude/plans/fixes/`)
      - If a Fixes Directory exists, write the entry to the current month file: `fixes-YYYY-MM.md` (e.g., `fixes-2026-05.md`)
      - If the file doesn't exist, create it with header: `# Bug Fixes & Hotfixes — {Month} {Year}\n`
      - Append the entry at the end of the file
      - If no Fixes Directory is configured, skip — do not add to the sprint plan
    - If the plan has an execution order file (e.g., *-execution-order.md):
      - Update the item's status to completed
      - Add the PR reference
    - Commit the planning doc updates to the appropriate repo (docs repo if configured, otherwise current repo)
23. **Clean up scratchpad** — If a scratchpad file was loaded in step 3, delete it now that the PR is created. Commit the deletion to the docs repo (if configured) alongside the planning doc updates.
24. **Resolve Sentry issues** — If the issue body references Sentry IDs (look for `**Sentry IDs:**` in the issue body), resolve them in Sentry now that the fix has shipped:
    - Read the org, project, and auth token from `~/.sentryclirc`
    - The Sentry IDs in the issue are short suffixes (e.g. `E`, `3H`, `2P`). The full shortId is `{PROJECT_SLUG}-{suffix}` (e.g. `JAVASCRIPT-NEXTJS-E`). Match against the API to get numeric IDs:
      ```bash
      curl -s -H "Authorization: Bearer $TOKEN" \
        "https://sentry.io/api/0/projects/$ORG/$PROJECT/issues/?query=is:unresolved&statsPeriod=14d"
      ```
    - Resolve using numeric IDs:
      ```bash
      sentry-cli issues resolve -i <ID1> -i <ID2> ... --org <org> --project <project>
      ```
    - If `~/.sentryclirc` doesn't exist or the resolve fails, skip — don't block the workflow on Sentry.
25. **Public hotfix summary** (hotfixes only — skip for regular fixes and features): At the very end, print a summary written for a public, non-technical audience. Format it as three lines:

    ```
    <Short descriptive title of the bug>
    <Problem sentence — no label>
    Fix: <fix sentence>
    ```

    - **Title line:** a short heading naming the bug (e.g. "Duplicate brand name error", "Uploads dropping on slow connections"). No `#issue`/`PR` numbers.
    - **Problem line — REQUIRED elements:** name the specific *person* affected (e.g. "a creator", not "a user" or "people") and *what they were doing* when it broke (e.g. "adding a past-work brand", "uploading a video to their portfolio"). Include the concrete trigger or context that caused it when known (e.g. "often on iPhone with iCloud videos", "on a slow mobile connection"). Describe what they experienced, not the code cause. A problem line that says only "when something failed, they saw an error" is NOT acceptable — it must be obvious *who* hit the problem, *while doing what*, and *under what conditions*. No `Problem:` label on this line.
    - **Fix line:** one sentence, prefixed with `Fix: `, describing what now works as a result, phrased around the same person from the problem line.
    - **Keep it short.** One sentence each, tight — concrete does not mean padded. No code, file names, function names, or technical terms.
    - **Worked example** (this is the target quality — match it on the first pass):
      ```
      Uploads dropping on slow connections
      When a creator on a slow mobile connection uploaded a larger video, it would stall partway and fail, forcing a restart.
      Fix: Uploads now adjust to the creator's connection strength, succeeding more often on the first try.
      ```

Begin implementation immediately - do not ask for approval since the plan was already approved when the issue was created.

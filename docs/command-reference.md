# Command reference

Every command, grouped by stage. Each command is a markdown prompt in [commands/](../commands/); all of them read `.claude/project.md` for project-specific values at runtime.

A rule that runs through the whole kit: **planning commands plan and stop; they do not write code.** You review the plan on GitHub, then an execution command implements it. This keeps a human approval step between "what we will build" and "building it."

## Plan

### `/feature`
Plan a feature and open a GitHub issue with an implementation spec.
- **When:** you have a new capability to add and want a reviewed plan before any code.
- **Produces:** a GitHub issue containing research findings and a step-by-step implementation plan. Then it stops.
- **Example:** `/feature Add a saved-search button to the results page`

### `/enhancement`
Plan an enhancement to existing behavior and open issues with an implementation spec.
- **When:** you are changing or extending something that already ships, not building net-new.
- **Produces:** one or more GitHub issues with the plan. Then it stops.
- **Example:** `/enhancement Let users rename a saved search inline`

### `/bugfix`
Plan a bug fix and open an issue with root-cause analysis.
- **When:** something is broken and you want the cause understood and a fix planned before touching code.
- **Produces:** a GitHub issue with the root cause and the planned fix. Then it stops.
- **Example:** `/bugfix Saved searches disappear after refresh`

### `/hotfix`
Plan an urgent fix that branches from and targets your release branch.
- **When:** a production issue needs to ship directly, outside the normal base-branch flow.
- **Produces:** a GitHub issue set up for the hotfix branch/target policy in `project.md`. Then it stops.
- **Example:** `/hotfix Checkout button 500s on empty cart`

### `/plan`
Turn a large vision into a strategic plan, broken into features.
- **When:** the work is too big for one issue and needs to be decomposed first.
- **Produces:** a roadmap that breaks the vision into feature-sized pieces.
- **Example:** `/plan Build a team workspace with shared saved searches`

### `/plan-batch`
Open GitHub issues with detailed plans for several features at once.
- **When:** you have a list of features ready to plan and want issues for all of them in one pass.
- **Produces:** multiple GitHub issues, each with its own implementation plan.
- **Example:** `/plan-batch` (then list the features)

### `/refine-issue`
Refine an existing issue's implementation plan based on comments and discussion.
- **When:** review comments or a conversation have changed what an issue should say.
- **Produces:** an updated issue plan that folds in the discussion.
- **Example:** `/refine-issue 42`

## Build and ship

### `/execute`
Implement an issue that already has a detailed plan, end-to-end.
- **When:** an issue's plan is approved and ready to build.
- **Produces:** a feature branch, the code and tests, a commit, and a PR.
- **Example:** `/execute 42`

### `/resume`
Resume the `/execute` workflow from wherever it left off.
- **When:** an `/execute` run was interrupted and you want to continue it rather than restart.
- **Produces:** continuation of the in-flight branch and PR.
- **Example:** `/resume`

### `/iterate`
Iterate on code changes with no tests, commits, or pushing.
- **When:** you want fast, exploratory edits without the full ship workflow kicking in.
- **Produces:** working-tree changes only. Nothing is committed or pushed until you leave iterate mode.
- **Example:** `/iterate Try a two-column layout for the results list`

### `/drop-iterate`
End an `/iterate` session and clear its standing constraints.
- **When:** you are done iterating and want the normal workflow (tests, commits) back.
- **Produces:** nothing; it lifts the iterate restrictions.
- **Example:** `/drop-iterate`

### `/review`
Review a PR for security issues, error handling, code duplication, and performance.
- **When:** a PR is open and you want a structured review before merging.
- **Produces:** a findings report organized by category.
- **Example:** `/review 42`

### `/address-review`
Address `/review` findings end-to-end: fix, test, commit, update the PR, push.
- **When:** a review produced findings you want applied.
- **Produces:** fixes on the branch, an updated PR description, and a push.
- **Example:** `/address-review`

### `/teardown`
Abandon a PR: cancel in-flight state, roll back and remove migrations, delete the branch, reopen the issue.
- **When:** a PR should be discarded rather than merged.
- **Produces:** a clean base branch with the branch, PR, and in-flight state removed, and the issue reopened. The migration-rollback steps assume Supabase; adapt them for a different migration tool.
- **Example:** `/teardown 42`

### `/release`
Open a release PR from your working branch into your release branch.
- **When:** a batch of merged work is ready to promote.
- **Produces:** a release branch and a PR into the release target, with a change inventory.
- **Example:** `/release`

### `/sync-hotfixes`
Pull hotfixes from the release branch back into the working branch via a sync PR.
- **When:** hotfixes landed on the release branch and need to flow back so branches do not diverge.
- **Produces:** a sync PR.
- **Example:** `/sync-hotfixes`

### `/sentry-hotfixes`
Turn a Sentry error report into prioritized hotfix issues.
- **Stack:** assumes Sentry (reads via the Sentry CLI and API). Ask Claude Code to adapt it for another error tracker.
- **When:** you want production errors triaged into actionable, prioritized GitHub issues.
- **Produces:** a Sentry error report plus hotfix issues for the actionable errors, and it resolves the non-actionable ones in Sentry. It stops before implementing.
- **Example:** `/sentry-hotfixes` or `/sentry-hotfixes P1 only`

## Database (Supabase)

Both commands read a live Supabase database through the Supabase MCP. Ask Claude Code to adapt them if you use a different database.

### `/data-fields`
Generate or update a data-fields doc from the live database.
- **When:** you want current schema documentation (tables, fields, RLS, storage) generated from the real database, not hand-maintained.
- **Produces:** a data-fields document, preserving manually curated sections on update.
- **Example:** `/data-fields`

### `/db-audit`
Compare two environments and report schema divergence.
- **When:** after a release or hotfix, to confirm dev and prod match, or any time you suspect drift.
- **Produces:** a parity report listing every divergence (schema, RLS, functions, storage, edge functions, and more).
- **Example:** `/db-audit`

## Audits

Each audit reads the codebase (and config in `project.md`) and writes or updates a report. They do not change code; they tell you what to change.

### `/audit`
Generate or update a comprehensive codebase audit document.
- **When:** you want a current, broad picture of the codebase's structure and health.
- **Produces:** an audit document.
- **Example:** `/audit`

### `/design-audit`
Audit design tokens: color, type, spacing, borders, transparency, and visual consistency.
- **When:** the UI has drifted and you want token-level inconsistencies surfaced.
- **Produces:** a design-audit report.
- **Example:** `/design-audit`

### `/performance-audit`
Audit the whole app for real and perceived performance: data access, rendering, streaming, and optimistic UI.
- **When:** the app feels slow or you want a ranked list of performance fixes.
- **Produces:** a performance-audit report with a staged fix list.
- **Example:** `/performance-audit`

### `/security-audit`
Audit API endpoint protection, bot defenses, and cost-exposure vectors.
- **When:** you want to find unprotected endpoints and abuse or cost-driving paths.
- **Produces:** a security-audit report.
- **Example:** `/security-audit`

### `/login-audit`
Audit login flows, session security, auth config, and the identity attack surface.
- **When:** you want auth and session handling checked against common weaknesses.
- **Produces:** a login-audit report.
- **Example:** `/login-audit`

### `/wcag-audit`
Audit the codebase against WCAG AA: contrast, semantics, labels, focus, and use of color.
- **When:** you want accessibility gaps found against a concrete standard.
- **Produces:** a WCAG-audit report.
- **Example:** `/wcag-audit`

### `/compliance-audit`
Audit the codebase against your legal and compliance documents for gaps.
- **When:** you have policies (privacy, terms, data handling) and want the code checked against them.
- **Produces:** a compliance-gap report.
- **Example:** `/compliance-audit`

### `/microcopy-audit`
Audit UI microcopy for editorializing, ambiguity, and inconsistent terms.
- **When:** you want the product's wording checked for clarity and consistency.
- **Produces:** a microcopy-audit report.
- **Example:** `/microcopy-audit`

## Sprints and docs

### `/add-sprint`
Add a new sprint to the sprint plan from a phase in the roadmap.
- **When:** you are ready to turn the next roadmap phase into a tracked sprint.
- **Produces:** a new sprint section in the sprint plan.
- **Example:** `/add-sprint`

### `/expand-sprint`
Expand a sprint in the sprint plan with detailed implementation tasks.
- **When:** a sprint is defined at a high level and needs task-level detail.
- **Produces:** detailed tasks under the sprint.
- **Example:** `/expand-sprint`

### `/update-progress`
Update roadmap and progress-tracker docs to reflect completed work.
- **When:** work has shipped and the planning docs are behind.
- **Produces:** updated roadmap and progress docs.
- **Example:** `/update-progress`

### `/achievement`
Update a running achievement tracker from your merged work.
- **When:** after shipping, to keep a self-updating record of what you built. Useful for reviews and promotions (see the [README](../README.md#tracking-your-work)).
- **Produces:** tracker entries assembled from merged PRs, closed issues, and commits. It backfills any days it missed.
- **Example:** `/achievement` or `/achievement led the architecture review`

### `/setup`
Set up a new project with command-kit configuration.
- **When:** you are onboarding a fresh project and want the config files and structure created interactively.
- **Produces:** `.claude/project.md`, `.claude/rules.md`, and the planning-doc structure, filled in from your answers.
- **Example:** `/setup`

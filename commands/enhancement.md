---
description: "Plan enhancement and create GitHub issues with implementation spec"
---

Plan the following enhancement: $ARGUMENTS

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, assignee, base branch, file paths, etc.) before executing. Use those values throughout this workflow.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it. Do not describe what you would do or ask for permission - execute the step.**

---

## Workflow

### 0. Clarity check

Before doing anything else, check the enhancement request in $ARGUMENTS for open decisions:
- **Multiple reasonable interpretations of what to build** — the request could reasonably map to more than one scope or outcome
- **Architecture or approach decisions not dictated by the request or existing codebase convention** — e.g., how to structure something new, whether to split work into parts, which of several viable technical approaches to take, a new data model shape

Do NOT ask about implementation details that already follow existing codebase patterns, naming, or established conventions — those are fine to just do.

If any open decisions exist, ask via `AskUserQuestion` before doing any research — do not pick an interpretation and proceed, and do not research multiple options and present one as if it were already decided. If the request is unambiguous, continue to Step 1 without asking.

### 1. Prepare scratch space

```bash
SCRATCH="/tmp/enhancement-plan-$(date +%s)"
mkdir -p "$SCRATCH"
```

Save the `$SCRATCH` path for use in agent prompts and cleanup.

### 2. Scout phase (foreground)

Launch a single Agent to identify what this enhancement touches and gather project context. It must write its output to `$SCRATCH/scout.md`.

> You are scouting an enhancement request to prepare for parallel research. The enhancement is: **[insert enhancement description]**
>
> Do the following and write a structured summary to `$SCRATCH/scout.md`:
>
> 1. **Project config:** Read `.claude/project.md` and extract: GitHub repo, assignee, base branch, design system doc path, data fields doc path, scratchpad dir, tech stack table
> 2. **Enhancement scope:** Search the codebase to identify which areas this enhancement likely touches — routes, components, server actions, database tables, APIs, types. List specific file paths.
> 3. **Prototype check:** If the request names a specific prototype (path/route/slug), note it. No name → none is used.
> 4. **Design system:** If a Design System doc is configured, read it and summarize relevant tokens, patterns, and conventions for this enhancement
> 5. **Has UI changes:** Determine whether this enhancement involves ANY frontend/UI changes (yes/no)
> 6. **Tech stack involved:** List which tech stack items from project.md this enhancement touches
> 7. **Type definitions:** Find and list relevant type definition file paths
>
> Write your output to `$SCRATCH/scout.md` using the Write tool. Respond only with "Done".

### 3. Research agents (parallel, background)

Read `$SCRATCH/scout.md` to understand what the scout found. Then launch ALL of the following agents in a **single message** with `run_in_background: true`. Each writes to `$SCRATCH/<key>.md`.

**a. `codebase`** — Research existing codebase patterns:

> Read `$SCRATCH/scout.md` for context about the enhancement being planned.
>
> Research the current codebase thoroughly:
> 1. **Existing patterns:** Read files in the enhancement area identified in scout.md — check how similar features are implemented, note conventions
> 2. **Type definitions:** Read the relevant type files listed in scout.md, document the types/interfaces needed
> 3. **Reusable utilities:** Search `src/lib/`, `src/utils/`, `src/hooks/`, `src/components/ui/` for existing utilities and hooks that should be reused for this enhancement
> 4. **Related code:** Read all files directly related to this enhancement area — note their structure, patterns, and how they connect
> 5. **Database context:** If a Data Fields Doc path is mentioned in scout.md, read it to understand existing tables, conventions, and design principles
>
> Write a structured research summary to `$SCRATCH/codebase.md`. Respond only with "Done".

**b. `ui-research`** — UI reference research (skip if scout says no UI changes):

> Read `$SCRATCH/scout.md` for context about the enhancement being planned.
>
> If scout.md says this enhancement has NO UI changes, write "N/A — no UI changes" to `$SCRATCH/ui-research.md` and stop.
>
> **If the request named a specific prototype** (listed in scout.md):
> - Read the JSX source of the named page (`prototype/src/pages/{folder}/{slug}.jsx`) — the prototype code is the PRIMARY spec. Ignore variant files (`{slug}-{name}.jsx`) and anything marked NON-CANONICAL unless the request names one.
> - Read the matching research notes (`prototype/research/{folder}-{slug}-*/notes.md`) — the `**Chosen:**` line and the user's recorded feedback are the design intent behind the JSX; quote them where they explain a decision
> - Do NOT take screenshots — the sandbox has no screenshot tooling; the JSX and the notes are the spec
> - Note: if the prototype's tokens (colors, fonts, spacing, borders, radii) diverge from the Design System doc, flag it and reconcile — update the prototype or the doc — rather than assuming either wins.
> - Document the prototype's key design decisions and how they map to the design system
> - The prototype already incorporates Mobbin research and the user's recorded reactions — do NOT run additional reference searches
>
> **Otherwise** — design from the shipped product's conventions and Mobbin:
> - Use the Mobbin MCP `search_screens` tool (`mode: "deep"`, `platform: "web"`, `image_format: "jpg"`) to find real-app references for the UI pattern (e.g., "settings page", "onboarding flow", "pricing table")
> - Search 2-3 variations of the query to cover different angles (e.g., "user profile edit form" and "account settings page")
> - Review the returned screenshots and note the best reference designs — which layouts, component patterns, and interaction models to adopt or avoid
> - **Research the microcopy too** — read the actual words in the screens (titles, helper text, button labels, empty states, privacy/error notes) and capture the register real products use for this surface, so the implemented copy reads like shipped product text, not generic AI prose (terse, concrete, imperative; no filler, no narrating the mechanics, no jargon leaking into the UI)
>
> **Save a design scratchpad** to the docs repo at `docs/product/design-research/{enhancement-slug}.md`:
> - If a prototype was named: note its slug, its key design decisions, and how it maps to the design system
> - Otherwise: Mobbin search queries used, best screenshots found, design decisions and rationale, and the microcopy register to follow (with example strings from the references)
> - How the references map to the project's design system
>
> Write your findings to `$SCRATCH/ui-research.md`. Respond only with "Done".

**c. `best-practices`** — Research official docs for relevant technologies:

> Read `$SCRATCH/scout.md` for context about which tech stack items are involved.
>
> If no Tech Stack table exists in scout.md, write "N/A — no tech stack table" to `$SCRATCH/best-practices.md` and stop.
>
> For each relevant library/framework identified in scout.md:
> - For Supabase projects, use the Supabase MCP `search_docs` tool for backend topics (auth, RLS, storage, edge functions, realtime, SSR)
> - Use web search for other libraries (Next.js, React, Tailwind, the project's component library from the Tech Stack table, Mux, dnd-kit, etc.)
>
> Specifically look for:
> - Recommended patterns and APIs for this enhancement's use case
> - Deprecations or breaking changes that affect the planned approach
> - Security guidance (especially for auth, RLS, and input handling)
> - Performance recommendations
>
> Write your findings to `$SCRATCH/best-practices.md`. Respond only with "Done".

### 4. Wait and verify

Wait for all background agents to complete. Verify all files exist:

```bash
for f in $SCRATCH/{scout,codebase,ui-research,best-practices}.md; do
  if [ -f "$f" ]; then echo "OK: $(basename $f)"; else echo "MISSING: $(basename $f)"; fi
done
```

Re-launch agents for any missing sections.

### 5. Compile research and save scratchpad

Read all section files from `$SCRATCH/`.

If a **Scratchpad Directory** is configured in project.md, write a research context file to preserve findings across context compaction:
- Filename: `{scratchpad-dir}/{enhancement-slug}.md` (e.g., `scratch/improve-profile-loading.md`)
- Include:
  - **Key files and their roles** — file paths discovered during research and what they do
  - **Existing patterns** — conventions, utilities, hooks found in similar features
  - **Type definitions** — relevant types/interfaces and where they live
  - **Best practice findings** — recommendations from official docs, deprecations, security notes
  - **Design system tokens** — relevant colors, spacing, component patterns (if UI work)
  - **Key code snippets** — small excerpts showing current patterns to follow

### 6. Scope assessment

Using all the compiled research, estimate the size of this enhancement:
- Count the number of files to be created or modified
- Estimate total lines changed (additions + deletions)
- Categorize the scope:
  - **S** (Small): 1-3 files, ~100-200 lines changed, single concern → 1 PR
  - **M** (Medium): 4-8 files, ~300-500 lines changed, 2-3 concerns → 1-2 PRs
  - **L** (Large): 9-15 files, ~500-1000 lines changed, multiple concerns → 2-3 PRs
  - **XL** (Extra Large): 16+ files, 1000+ lines changed, cross-cutting concerns → 3+ PRs
- Present the scope estimate clearly: `Scope: M (~6 files, ~400 changes across 2 concerns)`

### 7. Task decomposition

Decide whether to split based on actual size:
- **Small enhancements (S/M scope, under ~500 lines) → 1 issue, 1 PR.** Don't split for the sake of splitting.
- **Large enhancements (L/XL scope, over ~500 lines) → split into multiple issues**, one per PR, targeting ~500 lines each. But **visual verifiability takes priority over the line limit** — it's OK to exceed ~500 lines if splitting would produce PRs that can't be independently verified.
- Each issue must be **independently shippable** — the app works correctly after merging each PR
- If splitting, order issues so each builds on the previous one
- **Migrations are NOT separate issues** — include migrations in the PR that needs the new schema. Don't create standalone "database migration" issues.
- Examples of good splits (for large enhancements):
  - Issue 1: "Add server action and API layer" (includes migration + types if new tables needed; verify: action works via test/REPL)
  - Issue 2: "Add UI form component" (verify: form renders and submits)
  - Issue 3: "Add validation and error states" (verify: error messages display correctly)
- Examples of BAD splits:
  - Splitting an S/M enhancement into 2 issues just to have multiple issues
  - "Add database migration and types" as a standalone issue (migration should live with the code that uses it)
  - "Add half the form fields" / "Add the other half" (not meaningful boundaries)
  - "Backend" / "Frontend" when neither works alone

### 8. Present the implementation plan

**Before presenting, audit for invented scope:** re-read everything below against the original request and any Step 0 answers. For every decision in it — architecture choice, added mechanism, a "while we're at it" addition, a claim that "X also implies Y" — confirm it's either explicitly stated by the user or the only reasonable way to satisfy something they explicitly asked for. Anything else must not be presented as settled: pull it out and ask about it via `AskUserQuestion`, isolated from the rest of the plan, before including it.

Present the plan including:
- **Scope estimate** from step 6
- **Issue breakdown** from step 7 — list each issue with:
  - Title
  - What changes it includes
  - How to visually verify it works
- **Detailed UI design proposal** (informed by UI research):
  - **Real-app references** — List the best Mobbin references or prototype findings from the research, noting which design patterns to adopt
  - Layout and component hierarchy (ASCII diagrams)
  - User interactions and state changes
  - Loading, error, and empty states
  - Responsive behavior (mobile/tablet/desktop)
  - Accessibility considerations (keyboard navigation, screen readers)
  - **When a prototype was named**, it is the spec for layout and structure — the plan and issue describe building what it shows. If its tokens (colors, fonts, spacing, borders, radii) diverge from the Design System doc, flag it and reconcile — update the prototype or the doc. Keep existing dialog designs unless the issue asks for dialog changes.
- **Detailed storage proposal** (if file storage is required):
  - Bucket name and structure
  - File path pattern (e.g., `{creatorId}/{type}/{filename}`)
  - File naming conventions and allowed types
  - Size limits and validation rules
  - RLS policies for access control
- **Detailed table proposal** (if database changes are required):
  - Table schema with column names, types, and constraints
  - Foreign key relationships and indexes
  - RLS policies (SELECT, INSERT, UPDATE, DELETE)
  - Default values and nullable fields
  - Migration strategy for existing data
- **API/Backend changes** (if required):
  - New endpoints, server actions, or Edge Functions needed
  - Request/response schemas
- **State management:**
  - Client-side state approach (hooks, context, etc.)
  - Data fetching and caching strategy
- **Review checklist** — address each dimension that applies to this change (mark irrelevant ones "N/A"). This maps directly to what `/review` checks, so planning for it avoids rework:
  - **Security:**
    - Auth & authorization: session verification on all new endpoints/actions, resource ownership checks, fail-closed patterns (`if (!session) return` not `if (session) proceed`)
    - Input & injection: user input validated on server, no raw input in SQL/HTML/shell, file upload type/size checks, redirect URL allowlists
    - RLS & data access: new/modified tables have RLS policies, `auth.uid()` checks correct, no unnecessary service-role bypass
    - Rate limiting: new endpoints rate-limited, especially those triggering costly services (AI, email, video encoding)
    - Secrets & exposure: no secrets in client code or `NEXT_PUBLIC_` vars, error responses don't leak internal paths/stack traces, API responses don't over-expose data
  - **Error handling:**
    - No empty catch blocks or swallowed errors — every error path either re-throws, returns an error state, or gives user feedback
    - Client gets generic error messages; real errors logged server-side
    - All async paths (promises, server actions, API calls) have error handling
  - **Reuse:**
    - Existing utilities, hooks, components, or middleware to reuse instead of reimplementing
    - Similar feature patterns to follow for consistency
- **Performance considerations:**
  - Pagination strategy for lists
  - Caching approach
  - Lazy loading / code splitting needs
  - Optimistic updates for better UX
- **Dependencies:**
  - Any new packages required (with justification)
- Detailed breakdown of code changes needed per issue
- **Test plan** — for each testable concern, specify:
  - Test file path (new or existing)
  - Scenario description (what the test verifies)
  - Type: unit | integration
  - Cover: happy path, error states, edge cases, and access control (RLS/auth)
- Wait for user approval before proceeding

### 9. Create GitHub issues

Create issues with `gh issue create` — one issue per PR:
- Prefix each title with `N/Total:` (e.g., `1/3: Refactor data layer`, `2/3: Update UI components`, `3/3: Add error handling`)
- **Issue body quality rules** — these are non-negotiable:
  - **Detail means WHAT to build, not HOW to code it.** Describe every file to create/modify, every function/component name, every DB column and type, every prop and its shape, every API endpoint with request/response shape, every UI state (loading/error/empty/populated). Do NOT write implementation code, code snippets, or pseudo-code to pad the issue — `/execute` writes the code, the issue describes the spec.
  - **Do NOT consolidate multiple components into one issue to reduce issue count.** If the work has 5 distinct components, create 5 issues. The number of issues should reflect the actual complexity, not an artificial target.
  - **Do NOT understate complexity.** Rate by PR line-change count: **S** <500 lines · **M** 500–800 (add a justification) · **L** 801–1000 · **XL** >1000. Be honest, and split any **L/XL** into multiple S/M issues.
- Body for each issue must include:
  - Summary, what's included, implementation steps, how to visually verify, acceptance criteria (as checklist)
  - **Research Context section** — include key file paths, relevant patterns, and best practice notes so `/execute` has full context without re-researching:
    ```
    ## Research Context
    **Key files:** list of file paths relevant to this issue and their roles
    **Patterns to follow:** conventions/utilities discovered during research
    **Best practices:** relevant findings from official docs
    **Scratchpad:** path to scratchpad file (if one was created in step 5)
    ```
  - **If a prototype was named for this enhancement**, include a `## Prototype` section (so `/execute` uses that one):
    ```
    ## Prototype
    **Page:** {folder}/{slug} (`localhost:4000/{folder}/{slug}`)
    **Source:** `prototype/src/pages/{folder}/{slug}.jsx`
    **Notes:** `prototype/research/{folder}-{slug}-{date}/notes.md`
    ```
    This tells `/execute` to use the prototype as the authoritative visual spec. `/execute` will read the JSX source and the research notes (the Chosen decision and the user's recorded feedback) to match the design faithfully.
  - **If the issue involves ANY UI changes, the body MUST include a UI proposal** with:
    - **References** — Prototype route + chosen-variant notes (if exists) or Mobbin references that inspired the design, with notes on which patterns were adopted
    - **ASCII layout** — component hierarchy and key states (loading, error, empty)
    - This is non-negotiable — every UI issue needs references + visual spec in the issue body.
  - **Test Plan section** — every issue MUST include specific tests:
    ```
    ## Test Plan
    - [ ] Test: [description of what to test]
      - File: [test file path]
      - Type: unit | integration
      - Scenario: [what the test verifies]
    ```
    Include happy path, error states, edge cases, and access control tests as applicable.
  - **Review Checklist section** — include the review checklist from the plan so `/execute` addresses these proactively and `/review` finds nothing:
    ```
    ## Review Checklist
    **Security:** [which dimensions apply and how — auth checks, input validation, RLS policies, rate limiting, secrets exposure. "N/A" for dimensions that don't apply]
    **Error handling:** [error strategy — what's caught, what's surfaced to client vs logged server-side, async error paths]
    **Reuse:** [existing utilities/hooks/components to reuse, patterns from similar features to follow]
    ```
- Link issues to each other (note dependencies in the body)
- Assign to the project's default assignee (from project.md)
- Add label: `enhancement`

### 10. Clean up

```bash
rm -rf $SCRATCH
```

### 11. STOP

Do not proceed until user runs `/execute` on a specific issue.

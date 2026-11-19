---
description: "Create GitHub issues with detailed implementation plans for multiple features"
---

Create detailed implementation plans for the following features and save them as GitHub issues: $ARGUMENTS

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, assignee, base branch, file paths, docs repo, etc.) before executing. Use those values throughout this workflow.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it.**

The features can be provided as:
- A comma-separated list: "feature 1, feature 2, feature 3"
- A file path containing a list of features (one per line or markdown checklist)
- A markdown checklist in the arguments
- An **iterate parking-lot file** (`.../iterate-parking-lot.md`) — the deferred-items list produced by `/iterate` at STOP. Treat each checklist line as one feature; the trailing `Files:` hints are useful context for the scout/feature-to-area mapping. This is the expected handoff path from `/iterate`.

---

## Workflow

### 0. Clarity check

Before doing anything else, check each feature description in $ARGUMENTS for open decisions:
- **Multiple reasonable interpretations of what to build** — a feature description could reasonably map to more than one scope or outcome
- **Architecture or approach decisions not dictated by the description or existing codebase convention** — e.g., how to structure something new, whether to split work into parts, which of several viable technical approaches to take, a new data model shape

Do NOT ask about implementation details that already follow existing codebase patterns, naming, or established conventions — those are fine to just do.

If any open decisions exist for any feature, ask via `AskUserQuestion` before doing any research — batch all the questions together rather than asking one feature at a time. Do not pick an interpretation and proceed, and do not research multiple options and present one as if it were already decided. If every feature description is unambiguous, continue to Step 1 without asking.

### 1. Prepare scratch space

```bash
SCRATCH="/tmp/plan-batch-$(date +%s)"
mkdir -p "$SCRATCH"
```

Save the `$SCRATCH` path for use in agent prompts and cleanup.

### 2. Scout phase (foreground)

Parse the input to extract individual feature descriptions. Then launch a single Agent to gather shared project context. It must write its output to `$SCRATCH/scout.md`.

> You are preparing to batch-plan multiple features. The features are:
> 1. [feature 1]
> 2. [feature 2]
> 3. [feature N]
>
> Do the following and write a structured summary to `$SCRATCH/scout.md`:
>
> 1. **Project config:** Read `.claude/project.md` and extract: GitHub repo, assignee, base branch, design system doc path, data fields doc path, scratchpad dir, tech stack table, sprint plan location
> 2. **Tech stack:** Copy the full Tech Stack table from project.md — needed by the best-practices agent
> 3. **Prototypes:** Note only prototypes a feature request names explicitly (path/route/slug). No name → none used.
> 4. **Design system:** If configured, summarize key tokens and patterns
> 5. **Codebase overview:** Map the directory structure under `src/` to depth 2, list existing routes and server actions
> 6. **Feature-to-area mapping:** For each feature, identify which areas of the codebase it likely touches
>
> Write your output to `$SCRATCH/scout.md` using the Write tool. Respond only with "Done".

### 3. Shared research agents (parallel, background)

Read `$SCRATCH/scout.md`. Then launch these agents in a **single message** with `run_in_background: true`.

**a. `best-practices`** — Research official docs for the batch's tech stack:

> Read `$SCRATCH/scout.md` for the Tech Stack table and the list of features being planned.
>
> If no Tech Stack table exists, write "N/A" to `$SCRATCH/best-practices.md` and stop.
>
> Identify which libraries the batch of features will touch. Search official docs ONCE per relevant library (not per feature):
> - For Supabase projects, use the Supabase MCP `search_docs` tool for backend topics (auth, RLS, storage, edge functions, realtime, SSR)
> - Use web search for other libraries (Next.js, React, Tailwind, the project's component library from the Tech Stack table, Mux, dnd-kit, etc.)
> - Note recommended patterns, deprecations, and security guidance to apply across all feature plans
>
> Write your findings to `$SCRATCH/best-practices.md`. Respond only with "Done".

**b. `shared-patterns`** — Research shared codebase patterns:

> Read `$SCRATCH/scout.md` for the codebase overview and the list of features.
>
> Research patterns that apply across ALL the features:
> 1. **Reusable utilities:** Search `src/lib/`, `src/utils/`, `src/hooks/`, `src/components/ui/` and list all available utilities, hooks, and shared components
> 2. **Convention patterns:** Read 2-3 existing feature implementations to understand the project's conventions for server actions, data fetching, component structure, error handling
> 3. **Database context:** If a Data Fields Doc path is in scout.md, read it for table conventions and design principles
> 4. **Type definitions:** Find and document key type definition files and their contents
>
> Write a structured summary to `$SCRATCH/shared-patterns.md`. Respond only with "Done".

### 4. Wait for shared research

Wait for both background agents to complete. Verify files exist:

```bash
for f in $SCRATCH/{scout,best-practices,shared-patterns}.md; do
  if [ -f "$f" ]; then echo "OK: $(basename $f)"; else echo "MISSING: $(basename $f)"; fi
done
```

### 5. Per-feature research agents (parallel, background)

Now launch one agent PER FEATURE in a **single message** with `run_in_background: true`. Each agent does deep research for its specific feature.

For each feature N, launch an agent:

**`feature-N`** — Deep research for feature N:

> Read `$SCRATCH/scout.md`, `$SCRATCH/best-practices.md`, and `$SCRATCH/shared-patterns.md` for shared context.
>
> You are researching feature N: **[feature description]**
>
> Do the following:
> 1. **Codebase search:** Search for files directly related to this feature — read them and note their structure, patterns, and how they connect
> 2. **Prototype check:** If the feature request named a specific prototype (per scout.md):
>    - Read the JSX source of the named page (`prototype/src/pages/{folder}/{slug}.jsx`) as the PRIMARY spec for layout and structure — ignore variant files (`{slug}-{name}.jsx`) and anything marked NON-CANONICAL
>    - Read the matching `prototype/research/{folder}-{slug}-*/notes.md` — the `**Chosen:**` line and the user's recorded feedback are the design intent
>    - Do NOT take screenshots — the sandbox has no screenshot tooling; the JSX and notes are the spec
>    - If its tokens (colors, fonts, spacing, borders, radii) diverge from the Design System doc, flag it and reconcile (update the prototype or the doc)
>    - Document key design decisions
> 3. **Mobbin UI research** — if the feature has UI changes and no prototype was named:
>    - Use the Mobbin MCP `search_screens` tool (`mode: "deep"`, `platform: "web"`) to find real-app references for the UI pattern
>    - Search 2-3 variations of the query to cover different angles
>    - Note the best reference screenshots and their design patterns
>    - **Save a design scratchpad** to `docs/product/design-research/{feature-slug}.md`
> 4. **Files to modify:** List specific files that need changes, with what changes are needed
> 5. **New files:** List any new files that need to be created
> 6. **Dependencies:** Note any external packages needed
> 7. **Risks:** Flag edge cases, breaking changes, or complications
>
> Write a detailed research report to `$SCRATCH/feature-N.md`. Respond only with "Done".

### 6. Wait for per-feature research

Wait for all per-feature agents to complete. Verify files exist:

```bash
for i in $(seq 1 [NUM_FEATURES]); do
  f="$SCRATCH/feature-$i.md"
  if [ -f "$f" ]; then echo "OK: feature-$i.md"; else echo "MISSING: feature-$i.md"; fi
done
```

Re-launch agents for any missing features.

### 7. Save shared research context

If a **Scratchpad Directory** is configured in project.md, write a research context file:
- Filename: `{scratchpad-dir}/batch-{slug}.md` (e.g., `scratch/batch-onboarding-features.md`)
- Include shared best-practice findings, codebase architecture notes, and conventions that apply across all features

### 8. Create implementation plans and GitHub issues

Read all research files from `$SCRATCH/`. For EACH feature, create a detailed implementation plan and GitHub issue.

**Before creating issues, audit each plan for invented scope:** re-read it against that feature's original description and any Step 0 answers. For every decision in it — architecture choice, added mechanism, a "while we're at it" addition, a claim that "X also implies Y" — confirm it's either explicitly stated by the user or the only reasonable way to satisfy something they explicitly asked for. Anything else must not be written into the issue as settled: pull it out and ask about it via `AskUserQuestion` before including it.

For each feature, the plan must include:
- **Summary**: Clear description of what needs to be built
- **Scope estimate**: S/M/L/XL with file count and estimated lines changed
- **Files to Modify**: List of specific files with what changes are needed
- **New Files**: Any new files that need to be created
- **UI Proposal** (if ANY UI changes): **MUST include a UI proposal** with:
  - **References** — Prototype (route + chosen-variant notes) or Mobbin references that inspired the design
  - **ASCII layout** — component hierarchy and key states (loading, error, empty)
  - This is non-negotiable — every UI feature needs references + visual spec.
  - **When a prototype was named**, it is the spec for layout and structure. If its tokens (colors, fonts, spacing, borders, radii) diverge from the Design System doc, flag it and reconcile (update the prototype or the doc). Keep existing dialog designs unless asked.
- **Detailed storage proposal** (if file storage is required):
  - Bucket name and structure, file path pattern, naming conventions, allowed types, size limits, RLS policies
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
- **Review checklist** — address each dimension that applies (mark irrelevant ones "N/A"). This maps directly to what `/review` checks, so planning for it avoids rework:
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
  - Pagination strategy for lists, caching approach, lazy loading / code splitting needs, optimistic updates
- **Dependencies**: External packages or internal modules needed (with justification)
- **Test Plan** — for each testable concern, specify:
  - Test file path (new or existing)
  - Scenario description (what the test verifies)
  - Type: unit | integration
  - Cover: happy path, error states, edge cases, and access control (RLS/auth)
- **Implementation Steps**: Numbered, actionable steps
- **Acceptance Criteria**: How to verify the feature works correctly
- **Potential Risks**: Edge cases, breaking changes, or complications

Create a GitHub issue for EACH feature with `gh issue create`:
- Title: Prefix with `N/Total:` to show order (e.g., `1/3: Add Terms of Service pages`, `2/3: Add consent columns`, `3/3: Add consent flow`)
- If features come from a planning doc with step numbers (e.g., "Step 6a"), use those instead: `6a/6c: Customer Portal`
- **Issue body quality rules** — these are non-negotiable:
  - **Detail means WHAT to build, not HOW to code it.** Describe every file to create/modify, every function/component name, every DB column and type, every prop and its shape, every API endpoint with request/response shape, every UI state (loading/error/empty/populated). Do NOT write implementation code, code snippets, or pseudo-code to pad the issue — `/execute` writes the code, the issue describes the spec.
  - **Do NOT consolidate multiple features into fewer issues to save time.** Each feature in the input list gets its own issue. If a single feature has multiple components, it may need multiple issues.
  - **Do NOT understate complexity.** Be honest about scope.
- Body for each issue must include:
  - The full implementation plan in markdown format
  - **Research Context section** — include key file paths, relevant patterns, and best practice notes so `/execute` has full context without re-researching:
    ```
    ## Research Context
    **Key files:** list of file paths relevant to this issue and their roles
    **Patterns to follow:** conventions/utilities discovered during research
    **Best practices:** relevant findings from official docs
    **Scratchpad:** path to scratchpad file (if one was created in step 7)
    ```
  - **If a prototype was named for this feature**, include a `## Prototype` section (so `/execute` uses that one):
    ```
    ## Prototype
    **Page:** {slug} (`localhost:4000/{slug}`)
    **Source:** `prototype/src/pages/{folder}/{slug}.jsx`
    **Notes:** `prototype/research/{folder}-{slug}-{date}/notes.md`
    ```
    This tells `/execute` to use the prototype as the authoritative visual spec.
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
- Labels: `planned` plus the appropriate type label (from project.md)
- Assign to the project's default assignee (from project.md)

### 9. Summary table

After creating all issues, provide a summary table:
- Issue number
- Feature title
- Estimated complexity: ~N lines → S (<500) | M (500–800) | L (801–1000) | XL (>1000)
- Key files involved

### 10. Update the sprint plan

- **Check project.md for sprint plan location and docs repo configuration**
- If a docs repo is configured, update the sprint plan there
- Otherwise update the sprint plan in the current project
- Add each new issue to the appropriate sprint/section
- Format: `- [ ] \`/feature {description}\` #{issue_number} (Dependencies: ..., Complexity: ~N lines → S|M|L|XL)`
- If no appropriate sprint exists, create one or add to a "Planned" section
- **If inserting between existing numbered issues**, renumber subsequent issues to maintain correct order
- Commit the sprint plan updates to the appropriate repo

### 11. Clean up

```bash
rm -rf $SCRATCH
```

---

## Important Notes

- Do NOT implement anything — this is planning only
- **Split migrations across the issues that need them.** Each feature issue carries its own migration for the tables, columns, and RLS policies it introduces. Do NOT consolidate migrations into a standalone "schema setup" issue — distribute them so each issue is self-contained with its own schema changes
- Be thorough in research — read relevant files to understand context
- Make plans detailed enough that any developer could implement them without asking questions — every file path, every function signature, every DB column, every component prop
- If a feature description is ambiguous, ask clarifying questions before creating the issue
- Each issue should be self-contained and independent when possible
- Consider the order of implementation if features depend on each other

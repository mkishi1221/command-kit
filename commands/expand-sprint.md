---
description: "Expand the sprint plan with detailed implementation tasks from a roadmap"
---

Expand the sprint plan with detailed implementation tasks. Reads a roadmap and creates fully expanded sprints with component tasks — no TBC placeholders.

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, reference documents, file paths, docs repo, etc.) before executing. Use those values throughout this workflow.

## Arguments

The user may pass a roadmap document path as an argument: `/expand-sprint docs/product/*roadmap*.md`

If no argument is given, search for roadmap documents in `docs/product/*roadmap*.md`. If none found, fall back to the legacy reference documents approach (see "Legacy Workflow" below).

---

## Roadmap-Based Workflow

### 0. Clarity check

Before doing anything else, read the roadmap phases that need expanding and check for open decisions the roadmap doesn't resolve:
- **Multiple reasonable ways to break a phase into components** — a phase description could reasonably map to more than one task breakdown
- **Architecture or approach decisions not dictated by the roadmap or existing codebase convention** — e.g., how to structure something new, a new data model shape, which of several viable technical approaches to take

Do NOT ask about implementation details that already follow existing codebase patterns, naming, or established conventions — those are fine to just do.

If any open decisions exist, ask via `AskUserQuestion` before proceeding — batch all the questions together rather than asking one phase at a time. Do not pick an interpretation and continue, and do not research multiple options and present one as if it were already decided. If every phase is unambiguous, continue to Step 1 without asking.

### 1. Prepare scratch space

```bash
SCRATCH="/tmp/expand-sprint-$(date +%s)"
mkdir -p "$SCRATCH"
```

Save the `$SCRATCH` path for use in agent prompts and cleanup.

### 2. Scout phase (foreground)

Launch a single Agent to read all reference documents and map what already exists. It must write its output to `$SCRATCH/scout.md`.

> You are preparing to expand a sprint plan with detailed implementation tasks.
>
> Do the following and write a structured summary to `$SCRATCH/scout.md`:
>
> 1. **Project config:** Read `.claude/project.md` and extract: GitHub repo, sprint plan location, design system doc path, tech stack table, docs repo
> 2. **Roadmap document:** Read the roadmap document at `[path]` — summarize ALL phases with their descriptions
> 3. **Current sprint plan:** Read the sprint plan — note which sprints are already completed and which need expanding
> 4. **Prototypes:** List ALL files in `prototype/src/pages/` with their slugs
> 5. **Design system:** If a Design System doc is configured, read and summarize key tokens and patterns
> 6. **What to expand:** Identify which phases from the roadmap are NOT yet expanded in the sprint plan
>
> Write your output to `$SCRATCH/scout.md` using the Write tool. Respond only with "Done".

### 3. Research agents (parallel, background)

Read `$SCRATCH/scout.md` to understand the scope. Then launch ALL of the following agents in a **single message** with `run_in_background: true`.

**a. `codebase-state`** — Check what already exists in the codebase:

> Read `$SCRATCH/scout.md` for context about which sprints need expanding.
>
> Survey the current codebase to understand what already exists:
> 1. **Database tables:** List all existing tables (check migration files or use Supabase MCP if available)
> 2. **Components:** List key components in `src/components/` relevant to the sprints being expanded
> 3. **Routes:** List existing page routes and API routes
> 4. **Server actions:** Find files with `"use server"` and list their exported functions
> 5. **Utilities/hooks:** List key utilities in `src/lib/`, `src/utils/`, `src/hooks/`
> 6. **Tech stack:** Read the tech stack from project.md — note framework versions and conventions
>
> Write a structured summary to `$SCRATCH/codebase-state.md`. Respond only with "Done".

**b. `prototype-analysis`** — Analyze prototypes matching the sprints to expand:

> Read `$SCRATCH/scout.md` for the list of prototypes and the phases that need expanding.
>
> For each prototype that matches a phase being expanded:
> 1. Read the JSX source file to understand the design and structure
> 2. Note key design decisions: layout, component hierarchy, state management, interactions
> 3. Map which phase/task each prototype corresponds to
> 4. Note the slug for linking in sprint plan tasks
>
> If no prototypes match any phases being expanded, write "N/A — no matching prototypes" to `$SCRATCH/prototype-analysis.md`.
>
> Write your findings to `$SCRATCH/prototype-analysis.md`. Respond only with "Done".

**c. `dependency-map`** — Map cross-sprint dependencies:

> Read `$SCRATCH/scout.md` for the full roadmap document content and the phases to expand.
>
> Analyze dependencies across phases:
> 1. **Cross-phase dependencies:** Which phases depend on outputs from earlier phases?
> 2. **Shared infrastructure:** What tables, components, or utilities are needed by multiple phases?
> 3. **Reuse opportunities:** Where does the roadmap say "reuse X from Sprint N"?
> 4. **Task ordering:** What's the optimal order for tasks within each phase?
>
> Write a dependency map to `$SCRATCH/dependency-map.md`. Respond only with "Done".

### 4. Wait and verify

Wait for all background agents to complete. Verify all files exist:

```bash
for f in $SCRATCH/{scout,codebase-state,prototype-analysis,dependency-map}.md; do
  if [ -f "$f" ]; then echo "OK: $(basename $f)"; else echo "MISSING: $(basename $f)"; fi
done
```

Re-launch agents for any missing sections.

### 5. Create sprints and expand ALL of them

Read all section files from `$SCRATCH/`. Using the compiled research:

- Each phase in the roadmap becomes a sprint plan sprint with a description of what it validates/adds
- **Expand every sprint with component tasks** — no TBC placeholders. The entire plan must be coherent with cross-sprint dependencies visible.
- Link prototypes to specific tasks where matches were found

### 6. Break each sprint into component tasks

Think of a sprint like an airplane. Don't break it into "make passengers comfortable" (too outcome-driven, too big) or "install bolt #47" (too granular). Break it into **components** — seats, floor, lighting, galley, cockpit. Each component is a self-contained piece that can be built, tested, and verified independently.

- **Each task must be independently verifiable.** If you can't confirm it works on its own, it's not a task — either it's too small (fold it into a bigger piece) or too entangled (split it differently).
- **NEVER make migration/schema a task.** A migration is an implementation detail inside a feature task, not a task itself. Task names describe UI components or user-facing features ("Campaign deliverables list"), never schema or migration ("Deliverable Specs schema"). Each feature task carries its own migration as a sub-bullet — not bolded, not leading. No standalone "schema setup" tasks.
- **Right-sized chunks:** Each task = one PR = one component.
- **Reuse over rebuild:** If the roadmap says "reuse X from Sprint N", reference the earlier task as a dependency

### 7. Write detailed tasks following the established pattern

- **Task descriptions name the component**, not the user journey or the technical implementation detail (e.g. "Onboarding gate" not "User can sign up and be guided into onboarding" and not "Add middleware redirect and profiles table")
- Use this format:

  ```markdown
  - [ ] `/feature [Component description]` (Dependencies: [deps], Complexity: ~N lines → S|M)
    - **Prototype:** [slug] (`prototype/src/pages/{slug}.jsx`) - Brief description
    - [Implementation details]
    - [Technical notes from roadmap]
    - **Review focus:** [Security/error handling/reuse considerations — e.g. "Needs RLS policies, rate limiting on AI endpoint, reuse existing form patterns"]
    - **Verify:** [How to confirm this component works independently]
  ```

- Include **Prototype** line when a matching prototype page exists in `prototype/src/pages/`
- Include **Review focus** line with the security, error handling, and reuse considerations that `/review` will check — auth checks, RLS policies, rate limiting (especially for costly services), input validation, error handling strategy, and which existing utilities/patterns to reuse. This primes `/feature` and `/execute` to address these proactively.
- Verification must be something you can actually check after the PR lands — not aspirational

### 8. Update the sprint plan

**Before writing, audit every expanded task for invented scope:** re-read it against its roadmap phase and any Step 0 answers. For every decision in it — architecture choice, added mechanism, a "while we're at it" addition — confirm it's either explicit in the roadmap or the only reasonable way to satisfy something it explicitly calls for. Anything else must not be written into the sprint plan as settled: pull it out and ask about it via `AskUserQuestion` before including it.

- Write all expanded sprints to the sprint plan — completed sprints stay as-is
- Commit to the appropriate repo (docs repo if configured, otherwise current repo)

### 9. Clean up

```bash
rm -rf $SCRATCH
```

### 10. Present summary

1. Show the user a summary of what was added
2. List each sprint and its task count
3. Note any ambiguities or questions that came up
4. Flag any risks mentioned in the roadmap

---

## Legacy Workflow

### Legacy: Separate Reference Documents

When no roadmap document exists, read these reference documents from project.md:

1. **Data Fields / Schema Doc** - SOURCE OF TRUTH FOR DATABASE
   - Defines all database fields and their types
   - Shows which table each field belongs to
   - Indicates visibility (public/private) and policies
   - **Always use field names and types exactly as specified here**

2. **Progress Tracker / Requirements Doc**
   - Contains the sprint summary with due dates
   - Lists requirements per sprint with checkboxes
   - This is the source of truth for WHAT needs to be built

3. **Feature Spec / Portfolio Spec**
   - Defines feature sections and their contents
   - Shows what different user roles see
   - Contains UI/UX details and layout information

4. **Current Sprint Plan** (location from project.md)
   - Contains completed sprints as examples of the task format
   - Shows the current TBC sprints that need expanding
   - This is WHERE to write the output

5. **Prototypes** (`prototype/src/pages/`)
   - Interactive JSX prototypes that serve as the authoritative visual+structural spec
   - Scan for pages matching the sprint's features
   - Link relevant prototypes to specific tasks when expanding sprints

### Legacy Steps

0. **Clarity check** — same as roadmap-based workflow step 0, applied to the next TBC sprint's requirements
1. **Prepare scratch space** — same as roadmap-based workflow step 1

2. **Scout phase (foreground)** — Launch a single Agent to read all reference documents:

   > You are preparing to expand a sprint plan sprint. No roadmap document exists, so read these reference documents:
   >
   > 1. **Project config:** Read `.claude/project.md` and extract all reference document paths
   > 2. **Data Fields Doc:** Read the data fields/schema document — list ALL tables, columns, types
   > 3. **Requirements Doc:** Read the progress tracker — find the next TBC sprint and its requirements
   > 4. **Feature Spec:** Read the feature spec — note UI/UX details for the sprint
   > 5. **Current Sprint Plan:** Read the sprint plan — note completed sprints for format reference, identify TBC sprints
   > 6. **Prototypes:** List ALL files in `prototype/src/pages/`
   >
   > Write your output to `$SCRATCH/scout.md` using the Write tool. Respond only with "Done".

3. **Research agents (parallel, background)** — Launch all in a single message:

   **a. `codebase-state`** — same as roadmap-based workflow
   **b. `prototype-analysis`** — same as roadmap-based workflow
   **c. `field-mapping`** — Map requirements to data fields:

   > Read `$SCRATCH/scout.md` for the requirements and data fields.
   >
   > For each requirement in the next TBC sprint:
   > 1. Identify the relevant fields from the data fields document
   > 2. Note which table(s) each field belongs to
   > 3. Note field types, visibility, and any special considerations
   > 4. Map to UI sections from the feature spec
   >
   > Write a structured mapping to `$SCRATCH/field-mapping.md`. Respond only with "Done".

4. **Wait and verify** — same pattern as roadmap-based workflow

5. **Group into component tasks** — Using all research:
   - Each task = one independently verifiable component of the system
   - Group by actual UI section/component. Don't group by field name similarity.
   - Use sub-sprints (a, b, c) only when 4+ tasks fall into clear groups. No single-task sub-sprints.

6. **Write detailed tasks** — same format as roadmap-based workflow step 7

7. **Update the sprint plan** — Before writing, audit for invented scope the same way as roadmap-based workflow step 8. Replace the TBC placeholder with the detailed tasks, commit to appropriate repo

8. **Clean up** — remove `$SCRATCH`

---

## Important Guidelines (Both Workflows)

- **Each task must be independently verifiable** - If you can't confirm it works on its own after the PR lands, it's not a task. Either it's too small (fold into a bigger piece) or too entangled (split differently).
- **Tasks are components, not outcomes or implementation details** - "Onboarding gate" not "User can sign up and be guided into onboarding" and not "Add middleware redirect". Think airplane: seats, floor, lighting, galley, cockpit.
- **Right-sized tasks** - Each task = one PR = one verifiable component. Not one technical layer, not one user journey.
- **No single-task sub-sprints** - If a sub-sprint would only have one task, skip the sub-sprint
- **Include dependencies** - Reference earlier tasks/phases as needed
- **Honest complexity** - Rate by estimated PR line-change count: **S** <500 lines (ideal) · **M** 500–800 (acceptable — add a **Justification:** line) · **L** 801–1000 · **XL** >1000. Do NOT default to S — if it's 500–800 lines, call it M. **L and XL must be split** into multiple S/M tasks before planning
- **Respect the roadmap** - Use the exact terminology, table names, and technical guidance from the roadmap document
- **NEVER make migration/schema a task or task name.** Migration is an implementation detail inside each feature task. Task names describe UI components ("Campaign deliverables list"), never schema ("Deliverable Specs schema"). Each feature task carries its own migration as a brief sub-bullet — not bolded, not leading the task description. No standalone "schema setup" tasks, no "schema" in task names, no **Migration:** as the first bullet.

## Example Output

See the most recently completed sprint in the sprint plan for the expected format and level of detail.

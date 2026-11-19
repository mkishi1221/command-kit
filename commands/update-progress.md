---
description: "Update roadmap and progress tracker docs to reflect completed work"
---

Update the roadmap and progress tracker: $ARGUMENTS

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, docs repo, file paths, sprint plan location, reference documents, etc.) before executing. Use those values throughout this workflow.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it. Do not describe what you would do or ask for permission - execute the step.**

---

## Overview

This command synchronises the roadmap and progress tracker documents with actual completed work. It reads merged PRs, the sprint plan, and the fixes file to determine what's been done, then updates both documents: marking requirements complete, updating summary tables, adjusting sprint statuses and counts, and adding "Additional work" entries for cross-sprint deliveries.

---

## Workflow

### 1. Prepare scratch space

```bash
SCRATCH="/tmp/update-progress-$(date +%s)"
mkdir -p "$SCRATCH"
```

Save the actual `$SCRATCH` path — you will substitute it into every agent prompt below. Wherever an agent prompt contains `$SCRATCH`, replace it with the real path before launching the agent.

### 2. Scout phase (foreground)

Launch a single Agent with this prompt (substitute `$SCRATCH` with the actual path):

> You are preparing to update roadmap and progress tracker documents.
>
> Do the following and write a structured summary to `$SCRATCH/scout.md`:
>
> 1. **Project config:** Read `.claude/project.md` and extract:
>    - GitHub repo
>    - Docs repo path (if configured, planning docs live in a sibling repo)
>    - Sprint plan location
>    - Fixes directory
>    - Reference documents section (all paths)
>
> 2. **Find documents to update:** Locate the roadmap and progress tracker documents. Check these sources in order:
>    - `project.md` Reference Documents section for entries mentioning "Roadmap", "Progress Tracker", or similar
>    - The sprint plan file for "Source of truth" references to a roadmap
>    - Search the docs repo (or `docs/` directory) for files matching `*Roadmap*`, `*Progress_Tracker*`
>    - List ALL found documents with their full paths and a one-line description
>
> 3. **Read the roadmap:** Read the roadmap document. For each phase, record:
>    - Phase number and name
>    - Current status in summary table (Complete, In progress, Up next, Planned)
>    - Total requirement count and completed count
>    - The "Last Updated" date if present
>
> 4. **Read the progress tracker:** Read the progress tracker document. For each sprint, record:
>    - Sprint number and name
>    - Current status in summary table
>    - Total requirement count and completed count
>    - Due date if present
>    - Date completed if present
>    - The "Last Updated" date if present
>
> 5. **Identify what's in progress:** Note which phases/sprints are currently "In progress", "Up next", or have incomplete requirements. These are the update targets.
>
> 6. **Read the sprint plan:** Read the sprint plan. For the in-progress and up-next sprints, list all completed tasks with their PR numbers and completion dates.
>
> 7. **Read the fixes file:** If a fixes directory is configured, read the current month's fixes file. List all completed fixes with their PR numbers and completion dates.
>
> Write your output to `$SCRATCH/scout.md` using the Write tool. Respond only with "Done".

### 3. Research agents (parallel, background)

Read `$SCRATCH/scout.md` to understand the scope. Then launch ALL of the following agents in a **single message** with `run_in_background: true`. Each writes to `$SCRATCH/<key>.md`.

**a. `merged-prs`** — Gather merged PRs since last update:

> Read `$SCRATCH/scout.md` for context about the update.
>
> Use the "Last Updated" dates from the scout report.
>
> Gather merged PRs since the earlier of the two "Last Updated" dates (or the last 14 days if no date found):
>
> ```bash
> gh pr list --state merged --search "merged:>={date}" --json number,title,body,mergedAt --limit 200
> ```
>
> For each PR:
> 1. Note the PR number, title, merge date, and a brief one-line description
> 2. Check the PR body for references to phase/sprint requirements, issue numbers, or feature names
> 3. Flag any PR that mentions requirements from in-progress or upcoming phases/sprints
>
> Write your findings to `$SCRATCH/merged-prs.md`. Respond only with "Done".

**b. `requirement-mapping`** — Map completed work to requirements:

> Read `$SCRATCH/scout.md` for context about the update.
>
> Use the current state of phases/sprints from the scout report.
>
> For each in-progress or up-next phase/sprint:
> 1. List every requirement row that is NOT yet marked ✅
> 2. Read the sprint plan section for that sprint — find completed tasks (marked `[x]`) with their descriptions and PR numbers
> 3. Read the fixes file for bug fixes that satisfy requirements
> 4. For each incomplete requirement, determine if the sprint plan task or fix satisfies it — note the evidence (PR number, task description)
> 5. For completed sprint plan tasks that DON'T map to any requirement, flag them as candidates for "Additional work delivered"
>
> Return a structured mapping using this format:
>
> ```
> ## Phase/Sprint N: Name
>
> ### Requirements now satisfied:
> - "Requirement text" → Evidence: PR #NNN (task description)
>
> ### Requirements still incomplete:
> - "Requirement text" → No matching completed work found
>
> ### Additional work (no matching requirement):
> - PR #NNN: Description → Could satisfy Sprint M requirement or standalone
> ```
>
> Write your structured mapping to `$SCRATCH/requirement-mapping.md`. Respond only with "Done".

### 4. Wait and verify

Wait for all background agents to complete. Verify all files exist:

```bash
for f in $SCRATCH/{scout,merged-prs,requirement-mapping}.md; do
  if [ -f "$f" ]; then echo "OK: $(basename $f)"; else echo "MISSING: $(basename $f)"; fi
done
```

Re-launch any agent whose file is missing.

### 5. Apply updates

Read all files from `$SCRATCH/`. Using the compiled research, update both documents following the rules below.

#### Roadmap updates

1. **Requirement rows:** For each requirement now satisfied (per the mapping), change the Status column to `✅`
2. **Summary table:** Update the status column for each phase:
   - All requirements complete → `✅ Complete`
   - Some complete → `🔨 In progress` (no count in summary — the count goes in the phase heading)
   - Was "Up next" and now has completed items → `🔨 In progress`
   - Next phase after all in-progress ones → `🔜 Up next`
3. **Phase headings:** Update the heading line:
   - All complete → `## Phase N: Name ✅ Complete`
   - Some complete → `## Phase N: Name 🔨 In progress`
   - Next up → `## Phase N: Name 🔜 Up next`
4. **Last Updated date:** Update to today's date

#### Progress tracker updates

The progress tracker is for **non-technical stakeholders**. Follow these rules strictly:

- **No PR numbers, issue numbers, branch names, or commit hashes**
- **No technical jargon** (no "RLS", "RPC", "migration", "server action", "component", "hook")
- **No code references** (no file paths, function names, type names)
- Use plain language that describes what a user or admin experiences

1. **Requirement rows:** For each requirement now satisfied, change the Status column to `✅`
2. **Summary table:** Update each sprint row:
   - Status: `✅ Complete`, `🔨 In progress (X/Y)` (where X = completed, Y = total), or `Planned`
   - Date Completed: fill in when a sprint reaches ✅ Complete (use the merge date of the last completing PR)
3. **Sprint headings:** Update the heading line:
   - All complete → `## Sprint N: Name ✅ Complete (Delivered: DD Mon)`
   - Some complete → `## Sprint N: Name 🔨 In progress (X/Y) - Due DD Mon`
4. **Additional work:** If completed work delivered during this sprint satisfies requirements from FUTURE sprints, add an "Additional work delivered during Sprint N" table:
   ```
   **Additional work delivered during Sprint N:**

   | What was done | Satisfies |
   |---------------|-----------|
   | [Non-technical description of what was built] | Sprint M: [Requirement area] |
   | [Description without PR numbers] | - |
   ```
   - If the table already exists, add new rows — don't duplicate existing ones
   - The "Satisfies" column references the future sprint and group name, or `-` if standalone
5. **Notes section:** If noteworthy events occurred (sprint delivered early/late, scope changes, unplanned work), add or update a note at the bottom
6. **Last Updated date:** Update to today's date

### 6. Present changes for review

Before committing, present a summary of all changes:

1. **Roadmap changes:**
   - Requirements marked complete (list each with evidence)
   - Phase status changes (e.g., "Phase 6: Up next → In progress")
   - Any ambiguities or requirements that couldn't be confidently matched

2. **Progress tracker changes:**
   - Requirements marked complete
   - Sprint status and count changes
   - Additional work entries added
   - Notes added/updated

3. **Unmatched work:** List any merged PRs or completed sprint plan tasks that don't map to any requirement in either document — the user may want to add requirements or note these as additional work

**STOP and wait for user approval before committing.**

### 7. Commit

After approval, commit the changes to the appropriate repo:

- If a docs repo is configured in project.md, commit there:
  ```bash
  git -C <docs-repo-path> add <roadmap-path> <progress-tracker-path>
  git -C <docs-repo-path> commit -m "Update roadmap and progress tracker"
  git -C <docs-repo-path> push
  ```
- Otherwise commit to the current repo

### 8. Clean up

```bash
rm -rf $SCRATCH
```

---

## Arguments

The user may pass optional arguments to narrow the scope:

- **No arguments:** Update all in-progress and recently completed sprints
- **Sprint/phase number:** `/update-progress 6` — Update only phase/sprint 6
- **"all":** `/update-progress all` — Review and update all sprints, including completed ones that may need corrections
- **Specific note:** `/update-progress 6 - shortlist notification shipped` — Update sprint 6 with a hint about what changed

---

## Important Guidelines

- **Never invent completions.** Only mark a requirement ✅ when there is clear evidence (a merged PR, a completed sprint plan task, or a completed fix) that satisfies it. When uncertain, leave it incomplete and flag it for the user.
- **Progress tracker language must be non-technical.** This document is read by people who don't write code. "Creators can see campaigns they've been shortlisted for" not "Creator campaign view with RLS policies and server actions."
- **Roadmap can be technical.** PR numbers and technical terms are fine here.
- **Cross-sprint work goes in "Additional work" tables.** When work done during sprint N satisfies a requirement from sprint M (where M > N), add it to sprint N's "Additional work" section and optionally mark it in sprint M's requirement table.
- **Keep summary tables and headings in sync.** The summary table, sprint heading, and requirement checkmarks must all agree.
- **Preserve existing content.** Don't rewrite requirement text, sprint descriptions, or "Why this matters" paragraphs. Only modify status columns, summary tables, headings, additional work tables, and notes.

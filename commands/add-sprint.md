---
description: "Add a new sprint to the sprint plan from a phase in the roadmap"
---

Add a new sprint to the sprint plan. Reads a specific phase from the roadmap, expands it into component tasks, and appends it to the sprint plan.

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, sprint plan path, docs repo, tech stack, etc.) before executing.

## Arguments

The user passes a phase number or name: `/add-sprint 6` or `/add-sprint Career timeline`.

If no argument is given, read the roadmap and the current sprint plan, identify phases that don't yet have a corresponding sprint, and list them. Ask the user which one to add.

---

## Steps

### 0. Clarity check

Before doing anything else, read the target phase's description in the roadmap and check for open decisions the roadmap doesn't resolve:
- **Multiple reasonable ways to break the phase into components** — the phase description could reasonably map to more than one task breakdown
- **Architecture or approach decisions not dictated by the roadmap or existing codebase convention** — e.g., how to structure something new, a new data model shape, which of several viable technical approaches to take

Do NOT ask about implementation details that already follow existing codebase patterns, naming, or established conventions — those are fine to just do.

If any open decisions exist, ask via `AskUserQuestion` before proceeding — do not pick an interpretation and continue, and do not research multiple options and present one as if it were already decided. If the phase is unambiguous, continue to Step 1 without asking.

### 1. Read project config and current state

- Read `.claude/project.md` for paths (sprint plan, roadmap, design system, UI samples)
- Read the **full roadmap** — understand the complete product flow and all phases
- Read the **current sprint plan** — note existing sprints, the last sprint number, and established format
- Identify the target phase from the argument (by number or name match)

### 2. Check existing codebase state

- Review what already exists that's relevant to the target phase (tables, components, routes, prompts)
- Check the tech stack in project.md for framework versions and conventions
- Check UI samples for reference images relevant to the phase's tasks

### 3. Determine the new sprint number and header

- Find the **last actively worked sprint** — the most recent sprint with `[x]` completed tasks or active work
- The new sprint number = that sprint's number + 1
- Sprint header format: `## Sprint N: [Description] ([date range])`
- Date range comes from the roadmap if available
- Add a one-line **Adds:** or **Goal:** description below the header, matching the roadmap's goal statement

### 4. Break the phase into component tasks

Think of a sprint like an airplane. Don't break it into "make passengers comfortable" (too outcome-driven, too big) or "install bolt #47" (too granular). Break it into **components** — seats, floor, lighting, galley, cockpit. Each component is a self-contained piece that can be built, tested, and verified independently.

Rules:
- **Each task must be independently verifiable.** If you can't confirm it works on its own, it's not a task.
- **Migrations must be bundled with the feature that uses them.** Never create a standalone "create tables" or "schema setup" task. Each feature task carries its own migration for the tables, columns, and RLS policies it introduces.
- **Right-sized chunks:** Each task = one PR = one component.
- **Reuse over rebuild:** Reference earlier sprints/tasks as dependencies where the roadmap says to reuse.

### 5. Write detailed tasks

Use this format for each task:

```markdown
- [ ] `/feature [Component description]` (Dependencies: [deps], Complexity: ~N lines → S|M)
  - **Prototype:** [slug] (`prototype/src/pages/{slug}.jsx`) - Brief description
  - [Implementation details]
  - [Technical notes from roadmap]
  - **Verify:** [How to confirm this component works independently]
```

Guidelines:
- **Task descriptions name the component**, not the user journey or implementation detail
- Include **Prototype** line when a matching prototype page exists in `prototype/src/pages/`
- Verification must be something you can actually check after the PR lands
- Include dependencies on earlier sprints or tasks within this sprint
- Honest complexity by PR line-change count: **S** <500 lines (ideal) · **M** 500–800 (acceptable — add a **Justification:** line). **L** (801–1000) and **XL** (>1000) must be split into multiple S/M tasks — never plan an L/XL task
- No single-task sub-sprints — if a sub-sprint would have one task, skip the grouping

### 6. Insert into the sprint plan after the last active sprint

**Before inserting, audit the tasks for invented scope:** re-read them against the roadmap phase and any Step 0 answers. For every decision in them — architecture choice, added mechanism, a "while we're at it" addition — confirm it's either explicit in the roadmap or the only reasonable way to satisfy something it explicitly calls for. Anything else must not be written into the sprint plan as settled: pull it out and ask about it via `AskUserQuestion` before including it.

The new sprint goes directly after the **last sprint that was actively worked on** — the most recent sprint containing completed (`[x]`) or in-progress tasks. Do NOT blindly append to the end of the file, since later sprints may be stale, cancelled, or from a prior product direction.

To find the insertion point:
1. Scan all `## Sprint N:` headers in the sprint plan
2. For each sprint, check whether it contains any `[x]` completed tasks or is marked as actively in progress
3. The last such sprint is the **anchor sprint**
4. Insert the new sprint immediately after the anchor sprint's content ends (after its last task/enhancement/bug entry, before the next `---` separator or `## Sprint` header)
5. If sprints exist after the insertion point, they remain — the new sprint slots in between

Format:
- Add `---` separator before the new sprint
- The new sprint number = anchor sprint number + 1
- All tasks start as `- [ ]` (unchecked)
- Update the `Last updated` date at the top of the sprint plan
- Do NOT renumber existing sprints after the insertion point

### 7. Commit

Commit to the docs repo (from project.md):

```bash
git -C ../{docs_repo} add .claude/plans/sprintplan.md
git -C ../{docs_repo} commit -m "Add Sprint N: [description] to sprint plan"
git -C ../{docs_repo} push
```

### 8. Summary

Show the user:
- Sprint number and title
- Number of tasks added
- Task list with dependencies
- Any ambiguities or questions from the roadmap
- Any risks or assumptions made

---

## Important Guidelines

- **Respect the roadmap** — use its terminology, table names, and technical guidance exactly
- **Match the established sprint plan format** — look at the most recently completed sprint for the right level of detail
- **Tasks are components, not outcomes** — "Timeline page" not "User can see their career history"
- **No TBC placeholders** — every task must be fully expanded with implementation details and verification
- **Cross-sprint dependencies** — reference earlier sprint tasks by issue pattern (e.g. "Dependencies: Sprint 9 #137")
- **Don't duplicate existing infrastructure** — if a capability already exists (extraction pipeline, upload flow, PII redaction), reference it as a dependency, don't rebuild it

---
description: "Plan bug fix and create a GitHub issue with root cause analysis"
---

Plan a fix for the following bug: $ARGUMENTS

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, assignee, base branch, file paths, etc.) before executing. Use those values throughout this workflow.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it. Do not describe what you would do or ask for permission - execute the step.**

This is a **regular fix** — branches from the project's base branch (from project.md), branch prefix `fix/`, label `bug`. For critical production bugs, use `/hotfix` instead.

---

## Workflow

### 0. Clarity check

Before doing anything else, check the bug description in $ARGUMENTS for open decisions:
- **Multiple reasonable interpretations of what's actually wrong or what the expected behavior should be** — the report could reasonably map to more than one bug
- **Architecture or approach decisions not dictated by the bug or existing codebase convention** — e.g., which of several viable fixes to apply, whether the fix should be local or address a broader pattern, a schema/data-model change

Do NOT ask about implementation details that already follow existing codebase patterns, naming, or established conventions — those are fine to just do.

If any open decisions exist, ask via `AskUserQuestion` before doing any research — do not pick an interpretation and proceed, and do not research multiple options and present one as if it were already decided. If the request is unambiguous, continue to Step 1 without asking.

### 1. Prepare scratch space

```bash
SCRATCH="/tmp/bug-plan-$(date +%s)"
mkdir -p "$SCRATCH"
```

Save the `$SCRATCH` path for use in agent prompts and cleanup.

### 2. Root cause analysis (foreground)

Launch a single Agent to identify the root cause and gather project context. This must run first — subsequent agents need the root cause to do useful research. It must write its output to `$SCRATCH/root-cause.md`.

> You are investigating a bug to find its root cause. The bug is: **[insert bug description]**
>
> Do the following and write a structured analysis to `$SCRATCH/root-cause.md`:
>
> 1. **Project config:** Read `.claude/project.md` and extract: GitHub repo, assignee, base branch, design system doc path, data fields doc path, scratchpad dir, tech stack table
> 2. **Reproduce:** Attempt to reproduce the bug — trace through the code to understand the execution path. Identify the specific trigger conditions.
> 3. **Root cause:** Identify the exact file(s), function(s), and line(s) where the bug originates. Explain WHY the current code behaves incorrectly.
> 4. **Blast radius:** Check if the same bug pattern exists elsewhere in the codebase — search for similar code patterns that might have the same issue
> 5. **Has UI changes:** Determine whether the fix involves ANY frontend/UI changes (yes/no)
> 6. **Tech stack involved:** List which tech stack items from project.md the fix touches
> 7. **Related files:** List all files that will need to be modified for the fix, and why
>
> Write your output to `$SCRATCH/root-cause.md` using the Write tool. Respond only with "Done".

### 3. Research agents (parallel, background)

Read `$SCRATCH/root-cause.md` to understand the root cause. Then launch ALL applicable agents in a **single message** with `run_in_background: true`. Each writes to `$SCRATCH/<key>.md`.

**a. `related-code`** — Research related code and patterns:

> Read `$SCRATCH/root-cause.md` for context about the bug and its root cause.
>
> Research the codebase around the bug:
> 1. **Similar patterns:** Search for code that follows the same pattern as the buggy code — are there correct implementations to reference?
> 2. **Existing conventions:** Check how error handling, validation, or the specific operation is done elsewhere in the codebase
> 3. **Reusable utilities:** Search `src/lib/`, `src/utils/`, `src/hooks/` for existing utilities that the fix should use
> 4. **Type definitions:** Find and document relevant types/interfaces that the fix needs to work with
> 5. **Test patterns:** Check existing test files for the affected area — what patterns do they follow? What test utilities exist?
>
> Write a structured summary to `$SCRATCH/related-code.md`. Respond only with "Done".

**b. `best-practices`** — Research correct patterns from official docs:

> Read `$SCRATCH/root-cause.md` for context about the bug and which tech stack items are involved.
>
> If no Tech Stack table exists or the bug doesn't involve library misuse, write "N/A" to `$SCRATCH/best-practices.md` and stop.
>
> Check if the bug stems from a deprecated API, misused pattern, or missing configuration:
> - For Supabase projects, use the Supabase MCP `search_docs` tool for backend topics
> - Use web search for other libraries (Next.js, React, Tailwind, etc.)
> - Specifically look for the correct usage pattern for the API/feature that's broken
> - Check for known issues, migration guides, or deprecation notices
>
> Write your findings to `$SCRATCH/best-practices.md`. Respond only with "Done".

### 4. Wait and verify

Wait for all background agents to complete. Verify all files exist:

```bash
for f in $SCRATCH/{root-cause,related-code}.md; do
  if [ -f "$f" ]; then echo "OK: $(basename $f)"; else echo "MISSING: $(basename $f)"; fi
done
# Check optional files
for f in $SCRATCH/best-practices.md; do
  if [ -f "$f" ]; then echo "OK: $(basename $f)"; fi
done
```

Re-launch agents for any missing required sections.

### 5. Save research context

Read all section files from `$SCRATCH/`.

If a **Scratchpad Directory** is configured in project.md, write a research context file:
- Filename: `{scratchpad-dir}/{bug-slug}.md` (e.g., `scratch/fix-auth-redirect.md`)
- Include:
  - **Key files and their roles** — file paths involved in the bug and what they do
  - **Root cause details** — the specific code causing the bug, with file paths and line references
  - **Existing patterns** — conventions found in related code
  - **Best practice findings** — recommendations from official docs
  - **Reproduction steps** — how to trigger the bug reliably

### 6. Present the fix plan

**Before presenting, audit for invented scope:** re-read everything below against the original bug report and any Step 0 answers. For every decision in it — architecture choice, added mechanism, a "while we're at it" addition, a claim that "X also implies Y" — confirm it's either explicitly stated by the user or the only reasonable way to satisfy something they explicitly asked for. Anything else must not be presented as settled: pull it out and ask about it via `AskUserQuestion`, isolated from the rest of the plan, before including it.

Using all the compiled research, present:
- **Root cause analysis:**
  - What is causing the bug
  - Why the current code behaves incorrectly
- **Fix approach:**
  - What specifically will change
  - Files and functions affected
- **Regression test plan:**
  - Tests to add to prevent recurrence
  - Edge cases to cover
- **Review checklist** — address each dimension that applies to this fix (mark irrelevant ones "N/A"). This maps directly to what `/review` checks, so planning for it avoids rework:
  - **Security:**
    - Auth & authorization: does the fix maintain session verification, resource ownership checks, fail-closed patterns?
    - Input & injection: does the fix touch user input paths? Validate on server, no raw input in SQL/HTML/shell
    - RLS & data access: does the fix change data access patterns? Ensure RLS policies and `auth.uid()` checks are correct
    - Rate limiting: does the fix affect endpoints that need rate limits?
    - Secrets & exposure: does the fix change error responses? Generic messages to client, no leaked internals
  - **Error handling:**
    - No empty catch blocks or swallowed errors in the fix — every error path either re-throws, returns an error state, or gives user feedback
    - Client gets generic error messages; real errors logged server-side
    - All async paths in the fix have error handling
  - **Reuse:**
    - Existing utilities or patterns to reuse in the fix instead of reimplementing
- Wait for user approval before proceeding

### 7. Create a GitHub issue

Create issue with `gh issue create`:
- Title: Clear and descriptive (e.g., "Fix: [brief description]")
- Body should include:
  - Steps to reproduce
  - Expected vs actual behavior
  - Root cause analysis
  - Fix approach
  - **Research Context section** — key file paths, root cause code references, and best practice notes:
    ```
    ## Research Context
    **Base branch:** [project base branch from project.md]
    **Key files:** list of file paths relevant to this bug and their roles
    **Root cause:** specific file, function, and line where the bug originates
    **Patterns to follow:** conventions discovered during research
    **Best practices:** relevant findings from official docs
    **Scratchpad:** path to scratchpad file (if one was created in step 5)
    ```
  - **Regression tests** — specific tests to add that prevent this bug from recurring:
    ```
    ## Regression Tests
    - [ ] Test: [description of what to test]
      - File: [test file path]
      - Scenario: [what the test verifies]
      - Why: [how this prevents the bug from recurring]
    ```
    Include edge cases and boundary conditions that should be covered.
  - **If the fix involves ANY UI changes, include a UI proposal** with:
    - **References** — the existing component/pattern being fixed and the Design System doc, so the fix matches the current UI
    - **ASCII layout** — before/after showing the fix, component hierarchy, and key states
  - **Review Checklist section** — include the review checklist from the plan so `/execute` addresses these proactively and `/review` finds nothing:
    ```
    ## Review Checklist
    **Security:** [which dimensions apply and how — auth checks, input validation, RLS policies, rate limiting, secrets exposure. "N/A" for dimensions that don't apply]
    **Error handling:** [error strategy — what's caught, what's surfaced to client vs logged server-side, async error paths]
    **Reuse:** [existing utilities/hooks/components to reuse, patterns to follow]
    ```
  - Acceptance criteria (as checklist)
- Link to related issues if applicable
- Assign to the project's default assignee (from project.md)
- Labels: `bug`

### 8. Clean up

```bash
rm -rf $SCRATCH
```

### 9. STOP

Do not proceed until user runs `/execute`.

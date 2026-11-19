---
description: "Audit UI microcopy for editorializing, ambiguity, and inconsistent terms using ASD-STE100 discipline"
---

Run a microcopy audit on: $ARGUMENTS

**Project settings:** Read `.claude/project.md` for project-specific configuration (file paths, docs repo, etc.) before executing. Use those values throughout this workflow.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it. Do not describe what you would do or ask for permission - execute the step.**

**Output location:** Check project.md for an "Audit Output" section. If a microcopy/copy audit path is specified there, use it. Otherwise default to the plans directory, file named `microcopy-audit.md`.

This is a **code-based audit** — findings come from reading source files and extracting the user-facing strings, not from screenshots or browser automation.

**Use the `asd-ste100` skill** for the underlying rule set (one meaning per word, active voice, simple tense, short sentences). This command adds product-microcopy priorities on top of it — the editorializing check below is the primary lens, not STE compliance for its own sake.

## Scope

Parse `$ARGUMENTS`:
- A path (file or directory) → audit those files
- A component/page name → find and audit it plus the shared components it imports
- Empty → audit the whole source directory, page/view files first

## What counts as microcopy

Every user-facing string: headings, subtitles, button/menu labels, placeholders, helper text, empty states, tooltips, error and validation messages, dialog titles and bodies, toast/status text, and `aria-label`s. Ignore code identifiers, comments, className values, and console logs.

## Process

1. **Extract every user-facing string in scope.** Record file, line, and the exact string. Include dynamic templates (e.g. `` `${n} sources` ``) with their variable parts marked.

2. **Audit each string against these checks, in priority order:**

   **Editorializing (PRIMARY — flag these first):**
   - Explains *why* a feature exists or what it is for (rationale/purpose prose) — a label should name the thing, not justify it
   - Reassures or editorializes tone ("Don't worry", "Easily…", "Simply…")
   - Hedges or speculates ("looks like", "seems", "probably")
   - Repeats what a nearby heading, title, or label already says (redundant filler)
   - Any second sentence/clause that adds no new instruction or fact

   **Ambiguity & grammar (STE — mechanical):**
   - Passive voice where an actor exists ("is shown" → "appears" / name the actor)
   - Ellipsis: dropped subject or verb ("Could not read that PDF" → "We could not read…")
   - Run-on: more than one instruction in a sentence; split into separate sentences or a list
   - Sentence length: >20 words for an instruction, >25 for a description
   - Noun clusters of 4+ stacked words
   - Ambiguous pronoun with no clear referent ("it", "this", "that")

   **Term consistency (one word, one meaning):**
   - The same object named differently across the UI (e.g. "box" vs "source" vs "item")
   - The same action named differently (e.g. "delete" vs "remove", "read" vs "extract")
   - Build a term map: concept → every variant found → the one term to standardize on

3. **Write the audit report** to the output location:
   - **Summary** — overall state and counts by category (editorializing / ambiguity / consistency)
   - **Term map** — each concept with its variant strings and the recommended single term
   - **Findings table** grouped by category, each row: file:line, original string, the issue, and a **mechanical rewrite** that preserves the exact original meaning
   - If an area is clean, say so plainly — do not pad the report with invented findings

4. **Present the summary** to the user with the top findings, then **ask whether to apply fixes** (all, one category only, or none). If yes:
   - Apply minimal diffs — change only the string
   - Fix shared components first, then page-level instances
   - Run the project's CI checks from project.md conventions (typecheck, lint) before committing
   - Commit with a descriptive message following project conventions

## CRITICAL CONSTRAINTS

**The rewrite discipline — this is the point of the command:**
- Make the **smallest mechanical fix** that preserves the exact original meaning: passive→active, restore a dropped subject, split a run-on, swap an inconsistent term.
- **Never invent new copy, cut informational content, or make product decisions** (what to keep or remove) inside a rewrite. Inventing replacement phrasing is itself editorializing — the exact thing this audit exists to catch.
- When a string genuinely should be **cut or restructured** (not just grammar-fixed), do NOT rewrite it — flag it separately as a **product-voice call for the user to make**, with the reason. Leave the decision to them.
- Contractions and light warmth are a product-voice choice, not a defect — flag them only if the user has asked for a formal register; never strip them by default.

**DO NOT:**
- Use screenshots or browser automation — this audit reads code
- Rewrite for style, brevity, or "punchiness" beyond fixing the specific flagged issue
- Flag compliant strings (short active labels, standard "X ago" timestamps, plain imperatives like "Paste text here")
- Edit anything before the user has chosen what to fix in step 4

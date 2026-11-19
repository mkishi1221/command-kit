---
description: "Generate Sentry error report and create hotfix issues in one command"
---

Generate a Sentry error report, then create hotfix issues for all recommended errors. $ARGUMENTS

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, assignee, base branch, file paths, docs repo, etc.) before executing. Use those values throughout this workflow.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it. Do not describe what you would do or ask for permission - execute the step.**

**Reads from Sentry and resolves non-actionable issues. Creates hotfix GitHub issues.**

> **Stack note:** This command assumes **Sentry** — it reads errors through the Sentry CLI and API. If your project uses a different error tracker, ask Claude Code to adapt the report and resolve steps to your stack.

---

# Phase 1: Sentry Report

## 1.1 Configuration

Read Sentry credentials from `~/.sentryclirc`:

```bash
grep -E 'token|org|project' ~/.sentryclirc
```

Resolve the org and project slugs. If `~/.sentryclirc` only has a token, discover them:

```bash
sentry-cli projects list --org <your-org-slug>
```

Use the token, org slug, and project slug for all subsequent API calls.

## 1.2 Fetch all issues

Fetch unresolved issues with volume data (14-day stats window):

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://sentry.io/api/0/projects/$ORG/$PROJECT/issues/?query=is:unresolved&statsPeriod=14d"
```

Parse each issue for: `shortId`, `title`, `count` (events), `userCount` (affected users), `firstSeen`, `lastSeen`, `status`, `level`.

If there are more than 25 results, paginate using the `Link` header until all unresolved issues are collected.

Also fetch resolved issues for the historical summary:

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://sentry.io/api/0/projects/$ORG/$PROJECT/issues/?query=is:resolved&statsPeriod=14d&limit=100"
```

## 1.3 Filter out development noise

Exclude issues that are clearly local development artifacts:
- ENOENT errors referencing local file paths (`/Users/`, `.next/dev/cache/`)
- Webpack/turbopack dev cache errors

## 1.4 Categorise every issue

Assign each issue to exactly one category based on the error title and type. Use these categories:

| Category | Matching patterns |
|---|---|
| **React / Next.js Framework** | Hydration, hooks ordering, Server Components render, UnrecognizedActionError (stale Server Action), router state, CSP violations |
| **Network / Connection** | AbortError, connection closed, unexpected response, fetch failed, network error, signal aborted |
| **Infinite Loop / Stack Overflow** | Maximum call stack size exceeded, RangeError with stack context |
| **DOM / Browser** | NotFoundError (DOM), Java object is gone, browser extension errors (`__firefox__`, `__webkit__`), registerLazyResult |
| **Supabase / Database** | PGRST error codes (PGRST100, PGRST202, PGRST203, etc.), invalid UUID, storage schema errors |
| **Mux / Media** | Mux asset timeout, asset not found (404 on mux domains), next/image hostname for mux |
| **External Services** | SendGrid, email API, third-party service errors |
| **Code Errors** | ReferenceError (undefined variables), TypeError on property access of undefined |
| **Build / Dev Environment** | ENOENT on cache/build files (should be filtered, but include if in production) |
| **Opaque / Unclassifiable** | Minified errors (`Error: ee`), `<anonymous>`, `<unknown>`, errors with no readable title |

If an error doesn't fit any category, place it in "Opaque / Unclassifiable" and note what information is missing.

## 1.5 Write the report

Write the report to `docs/product/{Project}_Sentry_Error_Report.md` in the docs repo (path from project.md).

Use this structure:

```markdown
# Sentry Error Report - YYYY-MM-DD

Project: `<project-slug>` | Org: `<org-slug>`
Period: <date range of data> | Stats window: 14 days

## Summary

- **X unresolved** errors across Y categories
- **Z resolved** errors in the stats window
- Top offenders by volume: <top 3 by event count>

---

## Unresolved Errors by Category

### 1. <Category Name> (N events, M users)

| ID | Events | Users | Span | Title |
|---|---|---|---|---|
| ... | ... | ... | ... | ... |

<Brief root cause analysis for the category>

**Action:** <Recommended next step>

(Repeat for each category, ordered by total events descending)

---

## Resolved Errors Summary

| Category | Count | Notes |
|---|---|---|
| ... | ... | ... |

---

## Recommended Priority Order

1. **<Highest priority>** - <Why>
2. ...

---

## Recommended Issues

Issues worth creating as hotfixes (created automatically in Phase 2).

| Priority | Title | Sentry IDs | Events | Users | Rationale |
|---|---|---|---|---|---|
| P1 | <short bug title> | <ID, ID> | <total> | <total> | <one-line why> |
| P2 | ... | ... | ... | ... | ... |
```

Prioritisation rules:
- Page crashes (stack overflow, infinite loops) rank highest
- High event count + multiple affected users ranks above low-count issues
- Errors affecting 0 users (server-side only) rank below user-facing errors
- Network/transient errors rank lowest unless volume is extreme
- Note any errors that should be filtered from Sentry to reduce noise

Issue recommendation rules:
- Only recommend issues for errors that are **actionable** - a code change can fix or mitigate them
- **DO create issues for:** code bugs (hook ordering, stack overflows, undefined references), database errors (function signature mismatches), broken integrations (Mux timeouts with a reproducible path), server component crashes
- **DO NOT create issues for:** transient network errors (AbortError, connection closed), browser extension interference (`__firefox__`), one-off errors with 1 event and no reproduction path, minified/opaque errors with no stack trace
- Group related Sentry IDs into a single issue when they share a root cause (e.g. two separate "hooks ordering" errors in the same component)
- Each issue title should be a clear bug description, not the raw Sentry error message (e.g. "Fix infinite re-render loop on creator profile page" not "RangeError: Maximum call stack size exceeded")
- Include all related Sentry IDs so they can be linked/resolved when the fix ships
- Assign priority: P1 = page crashes or data loss, P2 = broken functionality affecting multiple users, P3 = edge cases or low-volume errors

## 1.6 Resolve non-actionable issues in Sentry

Resolve all unresolved Sentry issues that are **not** in the Recommended Issues table. These are transient, browser-extension, or opaque errors that don't warrant a fix.

```bash
sentry-cli issues resolve \
  -i <ID1> -i <ID2> ... \
  --org $ORG --project $PROJECT
```

This keeps the unresolved list clean - only issues with matching GitHub hotfixes remain open.

Also resolve any issues where the fix has **already shipped** (e.g. check recent commits/migrations for fixes that landed but the Sentry issue was never closed).

List which issues were resolved and why (transient, browser extension, already fixed, etc.).

---

# Phase 2: Create Hotfix Issues

**These are hotfixes** - Sentry errors are production bugs. All issues use:
- Base branch: `main`
- Branch prefix: `hotfix/`
- Labels: `bug`, `hotfix`, `planned`

If `$ARGUMENTS` specifies particular priorities or titles (e.g., "P1 only", "the hook ordering one"), filter to those. Otherwise create issues for every row in the Recommended Issues table.

## 2.1 Research each bug

For EACH recommended issue, do targeted research:

- **Fetch Sentry stack traces** for the listed Sentry IDs to identify the actual file and function:
  ```bash
  curl -s -H "Authorization: Bearer $TOKEN" \
    "https://sentry.io/api/0/projects/$ORG/$PROJECT/issues/?query=is:unresolved&statsPeriod=14d"
  ```
  Match by shortId to get the issue's API ID, then fetch latest event:
  ```bash
  curl -s -H "Authorization: Bearer $TOKEN" \
    "https://sentry.io/api/0/issues/$ISSUE_ID/events/latest/"
  ```
  Extract the stack trace frames to identify the source file, function, and line number.

- **Search the codebase** using the file paths and function names from the stack trace to understand the root cause. Read the relevant source files.

- **Check if already fixed** - search recent commits and open PRs for references to the same file/function. If a fix already shipped, note it and skip creating the issue.

- **Identify the root cause** - explain what specifically is wrong in the code and why it produces the error.

- **If the bug involves a library API**, read the Tech Stack table in project.md and search official docs for the correct pattern.

## 2.2 Save shared research context

If a **Scratchpad Directory** is configured in project.md, write a research context file:
- Filename: `{scratchpad-dir}/sentry-hotfixes-{date}.md`
- Include: Sentry stack traces, root cause analysis for each bug, codebase file paths, and best-practice findings
- This file survives context compaction - re-read it if you lose context during the batch

## 2.3 Create a GitHub issue for EACH bug

Use `gh issue create` for each. Format:

**Title:** `1/N: Hotfix: {descriptive title}` (numbered by batch position)

**Body:**

```markdown
## Bug Report

**Source:** Sentry error report ({date})
**Sentry IDs:** {shortId, shortId, ...} (e.g. E, 3H - without the project prefix)
**Volume:** {N} events, {M} users affected
**Priority:** {P1/P2/P3}
**First seen:** {date} | **Last seen:** {date}

## Description

{What the user experiences. One paragraph.}

## Root Cause

{What specifically is wrong in the code. Reference file paths, function names, and the logic error. Not the Sentry error message - the actual bug.}

**Key files:**
- `path/to/file.ts` - {role in the bug}
- ...

## Fix Approach

{What needs to change and why. Be specific about files, functions, and the fix strategy. Do NOT write implementation code.}

## Risk Assessment

**Blast radius:** {what parts of the system this change touches}
**Data impact:** {none | describe schema/storage/cache changes}
**Rollback plan:** {git revert | manual steps needed}
**User-facing impact:** {none | describe what users experience during deploy}
**Migration risk:** {none | describe destructive or irreversible migration steps}
**Confidence:** {Low | Medium | High}

## Regression Tests

- [ ] Test: {description}
  - File: {test file path}
  - Scenario: {what the test verifies}

## Acceptance Criteria

- [ ] Sentry IDs {IDs} stop recurring after deploy
- [ ] {Specific behavior that should work}
- [ ] No regressions in {related functionality}

## Research Context

**Base branch:** main
**Stack trace:** {abbreviated - file, function, line for the top frame}
**Scratchpad:** {path to scratchpad file, if created}
```

**Labels:** `bug`, `hotfix`, `planned`
**Assignee:** from project.md

**Migration handling:** If a hotfix includes database migrations, include a note in the issue body:
> **Migration:** This hotfix requires a database migration. After the PR is created, the migration SQL and tracking row INSERT will be provided for manual application to production via SQL Editor.

## 2.4 Order and link issues

- If issues have dependencies (e.g., fixing the DB function overload before the component that calls it), note the dependency in the issue body
- P1 issues come first in numbering, then P2, then P3

## 2.5 Update the Sentry report

Edit `docs/product/{Project}_Sentry_Error_Report.md` in the docs repo:
- Add a new column to the Recommended Issues table: `Issue` with the GitHub issue number
- Commit the update to the docs repo

## 2.6 Update fixes tracker

Add each new issue to the current month's fixes file in the docs repo (check project.md for Fixes Directory path):
- File: `fixes/fixes-YYYY-MM.md` (current month)
- Format: `- [ ] Hotfix: {description} #{issue_number} (Priority: P1/P2/P3)` with a sub-bullet summarizing Sentry IDs, volume, and one-line root cause
- Commit the update to the docs repo

---

# Summary

After both phases complete, output a combined summary:

1. **Report stats:** unresolved vs resolved count, issues resolved in Sentry
2. **Issues created:** table with issue numbers, priorities, Sentry IDs, events, and root causes
3. **Next step:** remind to run `/execute #NNN` on individual issues

**STOP** - Do not implement any fixes. Wait for user to run `/execute` on individual issues.

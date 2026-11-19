---
description: "Review a PR for security issues, error handling, code duplication, and performance"
---

Review PR for security, error handling, duplication, and performance: $ARGUMENTS

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, base branch, etc.) before executing.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it.**

If `$ARGUMENTS` is a PR number, use it. If empty, detect the current branch's PR with `gh pr view --json number`.

---

## Workflow

### 1. Gather PR context

```bash
gh pr view <number> --json title,body,baseRefName,headRefName,files,additions,deletions
gh pr diff <number> > /tmp/pr-review-diff.patch
gh pr diff <number> --name-only
```

Then read any issue the PR closes (its body is where a prototype is usually specified). Extract the issue number from the PR body (`Closes #N`, `Fixes #N`, etc.) and fetch it:

```bash
gh issue view <issue-number> --json title,body > /tmp/pr-review-issue.json
```

Scan the PR body and the issue body for a **prototype reference** — a path under `prototype/`, a named prototype page/route, or an explicit instruction to match a prototype. If one exists, Agent 6 runs (see below); if not, skip it.

### 2. Read changed files in full

Read every changed file in full — not just the diff hunks. Agents need surrounding context (imports, middleware wrappers, RLS policies on the table, auth checks in the same file) to assess security correctly.

### 3. Launch all review agents in parallel

Launch all agents **in a single message** so they run concurrently — four always, plus Agent 5 when the project's `.claude/rules.md` has a `## Review Checklist` section, plus Agent 6 when the PR or its linked issue specifies a prototype to match. Agents may spawn sub-agents for faster codebase search if needed.

**CRITICAL: Do NOT show ANY output to the user until ALL agents (and any sub-agents they spawned) have fully completed and the combined summary is ready.** If an agent task notification arrives after the summary has been presented, read its `/tmp/pr-review-*.md` file and append any NEW findings to the existing report — do not repeat the full report, just add the missing section.

#### Agent 1: Security review

> You are a security reviewer. Read `/tmp/pr-review-diff.patch` and every changed file listed there in full.
>
> Focus exclusively on code that is **added or modified in the diff**. Review using these dimensions:
>
> **1. Authentication & Authorization**
> - API routes or server actions missing session verification
> - Endpoints that accept writes without verifying resource ownership
> - Auth checked client-side only without server-side verification
> - Missing auth on pages/routes that should require it
> - `if (session)` patterns that fail open instead of `if (!session) redirect/return`
> - Service role client used where anon/user client would suffice
>
> **2. Session & Token Security**
> - Insecure cookie settings (missing httpOnly, secure, sameSite)
> - JWT or session tokens logged, exposed in URLs, or stored in localStorage
> - Missing token expiry or rotation
> - Session not invalidated where it should be (password change, sign-out)
>
> **3. Input & Injection**
> - User input passed to SQL, shell commands, or `dangerouslySetInnerHTML` without sanitization
> - Missing or incomplete input validation on API routes and server actions
> - File uploads without type/size validation
> - Redirect URLs not validated against an allowlist
>
> **4. Identity Attack Surface**
> - Error messages that leak user existence (different messages for "not found" vs "wrong password")
> - Missing rate limits on auth-related endpoints
> - Privilege escalation paths (self-assigning roles, bypassing role checks)
>
> **5. RLS & Data Access**
> - New tables/columns missing RLS policies
> - RLS policies that are too permissive
> - Service role bypass where RLS should be enforced
> - `auth.uid()` checks missing or incorrect
>
> **6. Endpoint Protection**
> - New API routes missing rate limiting
> - Endpoints that trigger costly external services without rate limits
> - Webhook handlers missing signature verification
>
> **7. Secrets & Exposure**
> - Secrets, tokens, or keys in client-side code or `NEXT_PUBLIC_` env vars
> - Error messages that leak internal paths, stack traces, or user data
> - Sensitive data returned in API responses that the client doesn't need
>
> For each finding, report:
> - **File and line** (from the original file, not the patch)
> - **Severity:** Critical / High / Medium / Low
> - **Category:** which of the 7 dimensions above
> - **Issue:** What's wrong
> - **Fix:** Specific recommendation
>
> If no security issues found, say "No security issues found in this PR." Do not invent issues to appear thorough.
>
> Write your findings to `/tmp/pr-review-security.md`. Respond only with "Done".

#### Agent 2: Error handling review

> You are reviewing a PR for error handling issues. Read `/tmp/pr-review-diff.patch` and every changed file listed there in full.
>
> Focus exclusively on code that is **added or modified in the diff**. Review for:
>
> **Swallowed errors:**
> - Empty `catch` blocks (`.catch(() => {})`, `catch { }`) that silently discard errors — the caller has no way to know something failed
> - `catch` blocks that log but don't re-throw or return an error state, leaving the caller unaware
> - `.then()` chains with no `.catch()` on promises that can reject
> - `try/catch` around operations where the error is assigned but never checked or propagated
> - Error responses from Supabase/fetch/API calls where `error` is destructured but the `if (error)` branch does nothing meaningful (no throw, no return of error state, no user feedback)
> - Functions that return a success-shaped value in both the success AND error paths, making errors invisible to callers
>
> **Leaked error details:**
> - Error messages, stack traces, or internal details exposed to the client (in UI text, API responses, or console output visible in the browser)
> - Raw database/Supabase error messages surfaced to users instead of generic user-facing messages
> - When you find a leaked error, ALWAYS recommend logging the real error server-side (e.g. `console.error` in a server action or API route) and returning a generic message to the client
>
> **Missing error-tracking reporting (Sentry or equivalent):**
> - Server-side `catch` blocks for unexpected errors (500s, data corruption, unhandled exceptions) that only `console.error` without calling `captureException` or equivalent Sentry reporting
> - Critical failure paths in API routes, server actions, and background jobs where an unexpected error would go unnoticed without Sentry
> - Do NOT flag expected user errors (401/403 auth failures, validation errors, 404s, rate limits) - these are normal flow and should NOT be reported to Sentry
> - When recommending Sentry, check what the project already uses (e.g. `captureException`, `Sentry.captureException`, or a project-specific wrapper) and recommend the same pattern
>
> For each finding, report:
> - **File and line** (from the original file, not the patch)
> - **Severity:** Critical / High / Medium / Low
> - **Issue:** What's wrong
> - **Fix:** Specific recommendation
>
> If no error handling issues found, say "No error handling issues found in this PR." Do not invent issues to appear thorough.
>
> Write your findings to `/tmp/pr-review-errors.md`. Respond only with "Done".

#### Agent 3: Duplication review

> You are reviewing a PR for code duplication and reuse opportunities. Read `/tmp/pr-review-diff.patch` to understand what was added, then search the broader codebase yourself.
>
> For every non-trivial function, component, utility, or pattern added in the diff, search the existing codebase for:
>
> **Exact or near duplicates:**
> - Functions that do the same thing with minor variations (different variable names, slightly different args)
> - React components that render nearly identical UI with copy-pasted markup
> - API route handlers that repeat the same auth/validation/response pattern that could be a shared middleware
> - SQL queries or Supabase calls that duplicate existing data access patterns
> - Repeated inline logic (string formatting, date handling, error mapping) that an existing utility already covers
>
> **Missed reuse:**
> - The PR introduces a helper that already exists elsewhere under a different name
> - The PR copy-pastes a pattern from another file instead of extracting a shared function
> - Constants or config values that are hardcoded when a shared constant already exists
>
> **How to search:**
> - Read the added code to understand what it does
> - Use grep/find to search for similar function names, similar string literals, similar import patterns
> - Check `src/lib/`, `src/utils/`, `src/hooks/`, `src/components/ui/` for existing utilities
> - Check files in the same feature area for repeated patterns
>
> For each finding, report:
> - **New code:** file and line in the PR
> - **Existing code:** file and line of the duplicate/utility that should be reused
> - **Severity:** Critical / High / Medium / Low — rate by the maintenance cost of leaving it: cementing a repeated pattern that's spreading (e.g. the third copy of a component) is High; a one-off hardcoded value with an existing constant is Low
> - **Suggestion:** Extract, reuse, or consolidate — with a specific recommendation
>
> If no meaningful duplication found, say "No duplication issues found." Don't flag trivial similarities (same import statement, same JSX wrapper, same Supabase client instantiation pattern).
>
> Write your findings to `/tmp/pr-review-duplication.md`. Respond only with "Done".

#### Agent 4: Performance review

> You are reviewing a PR for performance and speed issues. Read `/tmp/pr-review-diff.patch` and every changed file listed there in full. Search the broader codebase when you need surrounding context (how a query is called, whether a table is indexed, whether a component re-renders often).
>
> Focus exclusively on code that is **added or modified in the diff**. Review for:
>
> **Database & data access:**
> - N+1 query patterns — a query inside a loop or `.map()` that should be a single batched/`IN` query or a join
> - `SELECT *` or fetching columns/rows the code never uses; missing `.limit()` or pagination on lists that can grow unbounded
> - Queries filtering or ordering on unindexed columns (check the schema/migrations for an index on the filtered column)
> - Sequential `await`s that are independent and could run concurrently with `Promise.all`
> - Repeated identical queries within one request that could be fetched once and reused
> - Redundant per-request auth/reference round-trips — the same `getUser()`/session verification or the same shared lookup (current admin/role, platform settings, feature flags) re-run by every server action and query in one request's fan-out. A page that fans out into N actions each calling its own auth guard does N `getUser()` round-trips + N role queries per load, nearly all redundant. Fix by memoizing the auth/reference fetch with React `cache()` (a request-scoped Data Access Layer) so it collapses to one per request; keep enforcement close to the data, just memoized. Flag guards that re-authenticate from scratch on every call.
> - Cacheable cross-request/global reads — data identical across users and requests (admin id lists, platform settings, activity aggregates) refetched on every load with no memoization or TTL cache, where a module-level/in-memory cache with a short TTL (and explicit invalidation on mutation) would remove the repeated work
> - Count queries or full-table scans where an aggregate, a head-only count, or a cached value would do — including a separate count query for a badge when the list is already fetched (use `.length`)
>
> **Rendering & client:**
> - Expensive work (sorting, filtering, mapping large arrays, JSON parsing) in a React render body that runs every render instead of behind `useMemo`
> - New object/array/function literals passed as props to memoized children, defeating memoization
> - `useEffect` chains that trigger cascading re-renders or refetch waterfalls
> - Missing `key` stability causing full list re-mounts
> - Large synchronous work on the main thread that blocks interaction
>
> **Bundle & imports:**
> - Importing an entire library for one function (e.g. `import _ from 'lodash'` for one helper) where a subpath or native equivalent exists
> - Heavy dependencies pulled into a client bundle that could be server-only or dynamically imported
> - Large assets or data inlined into the bundle
>
> **Algorithmic & loops:**
> - Nested loops over the same data producing O(n²) work where a Map/Set lookup would be O(n)
> - Repeated `.find()`/`.includes()` inside a loop over a large array instead of a precomputed lookup
> - Expensive operations (regex compilation, date parsing, deep clones) repeated inside a hot loop instead of hoisted
>
> **Perceived performance & responsiveness:**
> - User actions (toggles, likes, adds, deletes, reorders, form submits) that block on the server round-trip before showing any result, where an optimistic update would make the UI feel instant — the mutation should reflect immediately and reconcile/roll back on error
> - A list mutation (especially delete/remove) that leaves the item on screen through the full server round-trip AND a follow-up refetch/`router.refresh()` before it disappears, with no optimistic removal — the row should vanish immediately (e.g. `useOptimistic` reducer keyed by id) and reconcile on the refresh
> - Optimistic updates that are missing their rollback path — the UI is updated eagerly but a failed request leaves stale/incorrect state with no revert and no user feedback
> - `window.location.reload()` (or `location.href = location.href`) after a mutation, which re-downloads the whole document and discards all client state (active tab, filters, scroll) — a client-side `router.refresh()` re-renders in place instead. (Deliberate hard navigations across an auth boundary are fine.)
> - Row/card navigation wired as `onClick={() => router.push(...)}` instead of a real `<Link href>` — the framework can't prefetch a programmatic push, so the transition starts cold; a `<Link>` prefetches the destination shell/skeleton (and is more accessible)
> - Navigations or data-dependent views that render a blank screen or spinner where a skeleton, cached, or prefetched state would show structure sooner
> - An async/suspending region with NO loading state at all — a route segment missing `loading.tsx`, a `<Suspense>` with no `fallback`, or a client fetch that shows nothing (blank/layout-shift) until data arrives. Every perceptible load boundary should show a skeleton or loading animation. NOTE: a skeleton is only right when the final layout closely matches its shape (stable, predictable structure — a list, a card grid, a detail header); if the resolved content varies a lot in shape or length (highly variable/unknown layout, empty-vs-full states, error-prone regions), a matching skeleton would mislead and cause layout shift — use a spinner/loading animation instead. Flag both the missing-loading-state case AND a skeleton used where the layout is too variable to mirror.
> - Full-page or full-list refetch after a single-item mutation, instead of updating the one changed item in place (cache/`setQueryData`-style patch)
> - Missing loading/pending affordance on an async action, so the user re-clicks or perceives a hang
>
> **Server rendering & streaming (SSR / RSC):**
> - A server component that `await`s its entire query fan-out at the top before rendering anything, so the whole page blocks on the slowest query — independent slow regions could stream behind `<Suspense>` with a skeleton fallback while the shell and fast data paint immediately
> - An expensive query, RPC, or external call that runs BEFORE the existence/auth gate (`notFound()`, redirect, permission check), so missing-resource and unauthorized requests still pay its full cost — move it after the gate (and, if it only feeds one region, behind that region's `<Suspense>`)
> - Blocking data fetches placed in a layout/parent that force every child route to wait, where the fetch belongs in the leaf that needs it
>
> Only flag issues where the slow path plausibly runs on real data volumes or hot paths — do not flag micro-optimizations on a 3-element array or code that runs once at startup. For optimistic-UI findings, only flag user-facing actions on interactive/hot paths, not one-off admin or setup screens. For each finding, estimate the impact (e.g. "one query per row, ~50 rows per page = 50 round-trips", "toggle waits ~400ms on the round-trip before any feedback", or "whole page blocks on a service-role RPC that only feeds one card").
>
> **CI test-run throughput (only if the diff touches CI test-selection or sharding config):**
> - A change to the test CI workflow, an affected-file/test-region selector, a vitest sequencer or shard config, or a committed timing manifest that lets a path run its tests **un-sharded in a single job** — most dangerous on the "affected / fast" path, where a broad or substring-based selection can balloon to most of the suite and then run serially. A single job running a broad selection is SLOWER than the sharded full run it was meant to replace, so the split silently defeats itself. Flag when the fast path stops parallelizing across runners (e.g. a shard matrix of one, or a run step that drops `--shard`); report the expected vs actual shard count and confirm the affected path still shards.
>
> The six categories are a floor, not a ceiling — they are the recurring patterns, not the whole space of what makes code slow. If the diff does something wasteful that fits none of them (an oversized client payload, a synchronous third-party SDK on the critical path, an unsized/eager-loaded image, a hot serialization), report it anyway under an "Other" category with the same file:line / severity / impact / fix detail.
>
> For each finding, report:
> - **File and line** (from the original file, not the patch)
> - **Severity:** Critical / High / Medium / Low — rate by real-world impact: an N+1 or unbounded query on a hot path is High/Critical; a missed `useMemo` on a small list is Low
> - **Category:** which of the six areas above (or "Other")
> - **Issue:** What's slow and why, with the impact estimate
> - **Fix:** Specific recommendation
>
> If no performance issues found, say "No performance issues found in this PR." Do not invent issues to appear thorough.
>
> Write your findings to `/tmp/pr-review-performance.md`. Respond only with "Done".

#### Agent 5: Project conventions review (conditional)

Launch this agent ONLY if the project's `.claude/rules.md` contains a `## Review Checklist` section. Pass that section's full text into the prompt.

> You are reviewing a PR against this project's own conventions. Read `/tmp/pr-review-diff.patch` and every changed file listed there in full.
>
> The project defines the following review checklist — check the ADDED/MODIFIED code in the diff against every item:
>
> <paste the `## Review Checklist` section from `.claude/rules.md` here, including any documents it references — read those documents too if the diff touches the areas they govern>
>
> For each violation, report:
> - **Rule:** which checklist item is violated
> - **Where:** file and line in the PR
> - **Fix:** the compliant alternative, per the referenced convention docs
>
> Only flag genuine violations of the listed rules — do not invent additional style opinions. If everything complies, say "No convention violations found."
>
> Write your findings to `/tmp/pr-review-conventions.md`. Respond only with "Done".

#### Agent 6: Prototype fidelity review (conditional)

Launch this agent ONLY if the PR description or its linked issue (`/tmp/pr-review-issue.json`) specifies a prototype to match — a path under `prototype/`, a named prototype page/route, or an explicit instruction to build the surface to match a prototype. Pass the exact prototype reference from the issue into the prompt. If the issue specifies no prototype, do NOT launch this agent.

> You are reviewing a PR for fidelity to the prototype the issue specifies. The prototype JSX is the design spec for this work — the implementation should recreate it faithfully (layout, structure, copy, components, interactions, and states), not an approximation of it.
>
> The issue specifies this prototype: **<paste the exact prototype path/page reference from the issue here>**.
>
> Read, in full:
> - The prototype JSX for the referenced page (resolve `prototype/` — it symlinks to the prototype repo — and read the actual page source, not a screenshot). If the reference names a page but not an exact file, locate it under `prototype/src/pages/`.
> - `/tmp/pr-review-diff.patch` and every changed product file in the diff that implements this surface, in full.
>
> Compare the **implemented product UI** against the **prototype** and flag where the implementation deviates from what the prototype specifies:
>
> **Structure & layout:**
> - Sections present in the prototype but missing from the implementation (or vice versa — extra sections the prototype doesn't have)
> - Sections rendered in a different order than the prototype
> - A section placed in a different position/card/column than the prototype puts it
> - Different grouping — fields the prototype groups into one card split across several, or nested cards where the prototype uses one card with dividers
>
> **Copy:**
> - Headings, labels, button text, empty-state text, helper/placeholder text that differ from the prototype's wording (quote both the prototype copy and the shipped copy)
> - Overlines, section titles, or microcopy dropped or reworded
>
> **Components & styling:**
> - A handrolled element where the prototype uses a design-system component (or the reverse)
> - Visual treatment that diverges from the prototype — spacing, card fill, typography weight/colour, dividers, icon usage — where the prototype makes a deliberate choice the implementation ignores
> - Fields/affordances the prototype styles as peers rendered with unequal visibility/styling in the implementation
>
> **Interactions & states:**
> - Affordances present in the prototype (dialogs, hover/expand, inline edit, toggles, confirm steps) that the implementation omits or wires differently
> - Loading, empty, error, or disabled states the prototype defines that the implementation doesn't handle
>
> Note: the prototype is the spec for THIS surface as the issue scoped it — do not flag intentional, issue-stated deviations (if the issue says "differs from the prototype in X", that is not a finding). Only flag places the implementation silently drifts from the prototype. Read the prototype JSX as PRIMARY — never assume from memory what the prototype contains.
>
> For each finding, report:
> - **Where:** the product file and line in the diff, and the corresponding prototype file:line
> - **Severity:** Critical / High / Medium / Low — a missing section or wrong primary action is High; a minor copy or spacing difference is Low
> - **Prototype says:** what the prototype specifies
> - **Implementation does:** what the PR actually renders
> - **Fix:** the specific change to match the prototype
>
> If the implementation faithfully matches the prototype, say "Implementation matches the prototype." Do not invent deviations to appear thorough.
>
> Write your findings to `/tmp/pr-review-prototype.md`. Respond only with "Done".

### 4. Compile and present

After ALL agents have completed, read `/tmp/pr-review-security.md`, `/tmp/pr-review-errors.md`, `/tmp/pr-review-duplication.md`, `/tmp/pr-review-performance.md`, (if Agent 5 ran) `/tmp/pr-review-conventions.md`, and (if Agent 6 ran) `/tmp/pr-review-prototype.md`.

Present ONLY the combined findings to the user — no preamble, no narration about the review process, no extra commentary. Keep the structure below (one `##` title, one `###` section per agent, a `**Verdict:**` line at the end):

```
## PR Review: #<number> — <title>

### Security
<findings, or: **No security issues found.**>

### Error Handling
<findings, or: **No error handling issues found.**>

### Duplication
<findings, or: **No duplication issues found.**>

### Performance
<findings, or: **No performance issues found.**>

### Project Conventions
<findings, or: **No convention violations found.** — omit this section entirely if Agent 5 did not run>

### Prototype Fidelity
<findings, or: **Implementation matches the prototype.** — omit this section entirely if Agent 6 did not run>

---

**Verdict:** No issues / N issues (list severities, e.g. "1 critical, 2 medium"). One or two sentences on what matters most and whether anything blocks merge.
```

**Format rules:**
- **Never use tables.** Terminals truncate table cells (the reader loses the end of every Issue/Fix) and tables don't paste cleanly into an issue or PR comment. Write each finding as plain prose.
- For every finding include: the file and line as a clickable link `[file.ts:42](relative/path#L42)`, severity (Critical / High / Medium / Low — Duplication included), what's wrong, and the specific fix. Give the real detail — exact symbols, values, branches, and concrete fix code — never compress it to fit a single truncated line.
- Sort findings within each section by severity (Critical first, Low last).
- If an agent found no issues, print the section's "**No ... found.**" line.

### 5. Clean up

```bash
rm -f /tmp/pr-review-diff.patch /tmp/pr-review-issue.json /tmp/pr-review-security.md /tmp/pr-review-errors.md /tmp/pr-review-duplication.md /tmp/pr-review-performance.md /tmp/pr-review-conventions.md /tmp/pr-review-prototype.md
```

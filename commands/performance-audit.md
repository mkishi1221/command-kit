---
description: "Audit the whole app for real and perceived performance: data access, rendering, streaming, and optimistic UI"
---

Run a whole-app performance audit on: $ARGUMENTS

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, base branch, file paths, docs repo, etc.) before executing. Use those values throughout this workflow.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it. Do not describe what you would do or ask for permission — execute the step.**

This is a **codebase-wide** audit. It generalizes the per-PR performance reviewer to the entire app: instead of grading a diff, it surveys every page, data fetch, list surface, and interactive mutation, then produces a ranked, dependency-staged menu of fixes the user can turn into issues. It reads source and schema — it does not run the app or use browser automation.

**Output location:** Check project.md for an "Audit Output" section. Write the report to the same directory as other audit files, named `<prefix>_Performance_Audit.md` (using the same prefix as other audit files there, e.g. `ACME_Performance_Audit.md`). If no audit directory is configured, write to the plans directory as `performance-audit.md`.

## Scope

Parse `$ARGUMENTS`:
- A path (file or directory) → audit those files plus the shared data/UI infra they depend on.
- A feature/area name (e.g. "campaigns", "deliverables") → find that route subtree and audit it.
- Empty → audit the whole source tree: the app's data-access layer and shared UI/loading infra first, then every page and interactive surface.

---

## Workflow

### 1. Prepare scratch space

```bash
SCRATCH="/tmp/performance-audit-$(date +%s)"
mkdir -p "$SCRATCH"
```

### 2. Scout phase (foreground)

Launch a single Agent to map the performance surface. It must write its output to `$SCRATCH/scout.md`.

> You are mapping the performance surface of a web app (framework/stack per `.claude/project.md`). Read source only — do not run the app. Write a structured inventory to `$SCRATCH/scout.md` covering:
>
> 1. **Framework & data-fetching model:** Next.js/React versions, App vs Pages Router, RSC vs client, data library (React Query / SWR / none). Note global config: `next.config.*` caching (`experimental.staleTimes`, `revalidate`), and whether pages are `force-dynamic` / `force-static` / default.
> 2. **Pages & their data shape:** For every page/route, note how it fetches data — top-level `await`, `Promise.all` fan-out (count the queries), sequential waterfalls, or client-side fetch. Flag any query/RPC/external call that runs BEFORE an existence/auth gate (`notFound()`, redirect, permission check).
> 3. **Data-access layer:** Where queries live (server actions, route handlers, data-access modules). Note `SELECT *`, list queries with no `.limit()`/pagination, and queries filtering/ordering on columns — record the column so a later agent can check for an index.
> 4. **Interactive/mutation surfaces:** Every list or detail surface with a create/update/delete/toggle/reorder. For each, note: does it update optimistically, does it `router.refresh()` vs `window.location.reload()`, does it show a pending affordance, and how it navigates (real `<Link>` vs `onClick → router.push`).
> 5. **Loading states:** Coverage of `loading.tsx` / `<Suspense fallback>` / client loading UI per route. Note async regions with NO loading state, and skeletons used where the resolved layout is highly variable.
> 6. **Shared perf infra:** Skeleton/loading primitives, the server-action wrapper (and its error/null contract), toast system, any optimistic/prefetch precedent already in the code (grep `useOptimistic`, `router.prefetch`, `<Suspense`, `useMemo`, `staleTimes`). Also grep for request-scoped memoization and the auth layer: `cache(` (React `cache`), a Data Access Layer module (e.g. `lib/supabase/auth.ts`), the shared admin/role guards, and any module-level/in-memory TTL cache. Note whether auth guards are memoized or re-authenticate per call.
> 7. **Client bundle risks:** Heavy dependencies imported into client components, whole-library imports for one helper, large inlined data/assets.
> 8. **Indexes & schema:** Locate migrations/schema files so a later agent can cross-check filtered/ordered columns against existing indexes.
>
> Record concrete `file:line` for everything. Write to `$SCRATCH/scout.md` with the Write tool. Respond only with "Done".

### 3. Deep analysis agents (two waves)

**Wave 1 — the four categorized agents.** Launch agents `a`-`d` in a **single message** with `run_in_background: true`. Each reads `$SCRATCH/scout.md` for the inventory, then reads the referenced files in full and writes to `$SCRATCH/<key>.md`. Each agent may spawn sub-agents for faster codebase search.

**Wave 2 — the open-ended discovery agent.** After `a`-`d` complete, launch agent `e` (`discovery`); it reads their outputs so it can hunt for what they missed without repeating them. If you prefer to run everything at once, `e` may be launched in the same batch — it will read whatever category files exist and simply lean harder on the scout inventory.

Every finding must report: **file:line**, **Severity** (Critical / High / Medium / Low, rated by real-world impact on real data volumes and hot paths — an N+1 or unbounded query on a hot path is High/Critical; a missed `useMemo` on a small list is Low), **Issue** (what's slow and why, with an impact estimate), and **Fix** (a specific recommendation, with the concrete pattern to adopt). Only flag issues where the slow path plausibly runs on real data volumes or hot paths — do not flag micro-optimizations on tiny arrays or code that runs once at startup. If an area is clean, say so plainly — do not invent findings to appear thorough.

**The enumerated bullets in each agent are a floor, not a ceiling.** They are the known, recurring patterns — not the full space of what makes an app slow. Treat them as a starting point and actively look for performance problems they do NOT name: app-specific hot paths, novel anti-patterns, and whatever the current code happens to do wastefully. If you find something real that costs latency or wasted work but fits none of the listed buckets, report it anyway under an "Other / uncategorized" heading with the same file:line / severity / impact / fix detail. When useful, consult current framework and web-performance best practices (official docs, web.dev) rather than relying only on prior knowledge — the fastest-moving wins are often newer than any fixed checklist.

**a. `data-access`** — Database & data access:

> Read `$SCRATCH/scout.md`, then read every page and data-access file it lists. Cross-check filtered/ordered columns against the schema/migration files for indexes. Review for:
> - **N+1 queries** — a query inside a loop/`.map()` that should be a single batched/`IN` query or a join.
> - **`SELECT *` or over-fetching** columns/rows the code never uses; missing `.limit()`/pagination on lists that can grow unbounded.
> - **Unindexed filters/sorts** — queries filtering or ordering on a column with no index (check migrations).
> - **Sequential independent `await`s** that could run concurrently with `Promise.all`.
> - **Repeated identical queries** within one request that could be fetched once and reused.
> - **Redundant per-request auth / reference round-trips** — the same `getUser()` / session verification, or the same shared lookup (current admin/role, platform settings, feature flags), re-run by every server action and query in a single request's fan-out. On a page that fans out into N actions each calling its own auth guard, that is N `getUser()` network round-trips + N role queries per load, nearly all redundant with the middleware/page check that already ran. The fix is a request-scoped memoized Data Access Layer (React `cache()` around the auth/user fetch and the role lookup) so it collapses to one per request; enforcement stays close to the data (defense-in-depth), only memoized. Flag guards that re-authenticate from scratch on every call.
> - **Cacheable cross-request/global reads** — data identical across users and requests (admin id lists, platform settings, activity aggregates) refetched on every load with no memoization or TTL cache, where a module-level/in-memory cache with a short TTL (and an explicit invalidation action on mutation) would eliminate the repeated work.
> - **Count queries / full scans** where an aggregate, a head-only count, or a cached value would do; a separate count query for a badge when the list is already fetched (use `.length`).
>
> Write to `$SCRATCH/data-access.md`. Respond only with "Done".

**b. `rendering`** — Client rendering, algorithms & bundle:

> Read `$SCRATCH/scout.md`, then read the client components it lists. Review for:
> - **Render-body work** — sorting/filtering/mapping large arrays or JSON parsing in a render body every render, instead of behind `useMemo`.
> - **Broken memoization** — new object/array/function literals passed as props to memoized children; missing/unstable `key` causing full list re-mounts.
> - **Effect waterfalls** — `useEffect` chains that trigger cascading re-renders or refetch waterfalls.
> - **Main-thread blocking** — large synchronous work that blocks interaction.
> - **Algorithmic** — nested loops over the same data (O(n²)) where a Map/Set lookup is O(n); repeated `.find()`/`.includes()` inside a loop over a large array; expensive ops (regex/date-parse/deep-clone) repeated in a hot loop instead of hoisted.
> - **Bundle & imports** — importing a whole library for one function where a subpath/native equivalent exists; heavy deps in the client bundle that could be server-only or dynamically imported; large data/assets inlined.
>
> Write to `$SCRATCH/rendering.md`. Respond only with "Done".

**c. `perceived`** — Perceived performance & responsiveness:

> Read `$SCRATCH/scout.md`, then read every interactive/mutation surface it lists. This is the highest-signal category — it is what makes an app *feel* slow. Review for:
> - **Blocking mutations** — user actions (toggle, like, add, delete, reorder, submit) that block on the server round-trip before showing any result, where an optimistic update would make the UI feel instant (reflect immediately, reconcile/roll back on error).
> - **Non-optimistic list removal** — a delete/remove that leaves the item on screen through the full round-trip AND a follow-up refetch/`router.refresh()` before it disappears; the row should vanish immediately (e.g. `useOptimistic` reducer keyed by id) and reconcile on refresh.
> - **Optimistic updates missing rollback** — eager UI update with no revert and no user feedback when the request fails.
> - **`window.location.reload()`** (or `location.href = location.href`) after a mutation — re-downloads the whole document and discards client state (active tab, filters, scroll); a client-side `router.refresh()` re-renders in place. (Deliberate hard navigations across an auth boundary are fine.)
> - **Cold navigation** — row/card nav wired as `onClick={() => router.push(...)}` instead of a real `<Link href>`; the framework can't prefetch a programmatic push, so the transition starts cold and it's less accessible.
> - **Missing loading state** — an async/suspending region with no loading state at all (route segment missing `loading.tsx`, a `<Suspense>` with no `fallback`, or a client fetch showing blank/layout-shift until data arrives). Every perceptible load boundary should show a skeleton or loading animation. NOTE: a skeleton is only right when the final layout closely matches its shape (stable, predictable structure). If the resolved content varies a lot in shape/length (variable layout, empty-vs-full, error-prone regions), a skeleton misleads and shifts layout — a spinner is correct there. Flag BOTH the missing-loading-state case AND a skeleton used where the layout is too variable to mirror.
> - **Full-page/full-list refetch after a single-item mutation**, instead of patching the one changed item in place.
> - **Missing pending affordance** on an async action, so the user re-clicks or perceives a hang.
>
> Only flag user-facing actions on interactive/hot paths, not one-off admin/setup screens. Write to `$SCRATCH/perceived.md`. Respond only with "Done".

**d. `ssr-streaming`** — Server rendering, streaming & navigation caching:

> Read `$SCRATCH/scout.md`, then read the server components / pages / layouts and `next.config.*` it lists. Review for:
> - **Top-level await fan-out** — a server component that `await`s its entire query fan-out before rendering anything, so the whole page blocks on the slowest query; independent slow regions could stream behind `<Suspense>` with a skeleton fallback while the shell + fast data paint immediately.
> - **Expensive work before the gate** — a query/RPC/external call that runs BEFORE the existence/auth gate (`notFound()`, redirect, permission check), so missing-resource and unauthorized requests still pay its full cost; move it after the gate (and, if it only feeds one region, behind that region's `<Suspense>`). Keep `notFound()`/auth BEFORE the first streaming boundary — once streaming starts the HTTP status locks to 200.
> - **Blocking layout/parent fetches** — a fetch in a layout/parent that forces every child route to wait, where it belongs in the leaf that needs it.
> - **Navigation caching** — Back/forward re-running the full fan-out because no client Router Cache `staleTime` is configured (e.g. `experimental.staleTimes`) and routes are `force-dynamic` by default; and destinations that aren't prefetched. Note: do NOT recommend dropping `force-dynamic` where it guards auth/cookie-scoped data.
>
> Write to `$SCRATCH/ssr-streaming.md`. Respond only with "Done".

**e. `discovery`** — Open-ended, uncategorized wins:

> Read `$SCRATCH/scout.md` and the four other agents' outputs once they exist (`$SCRATCH/data-access.md`, `rendering.md`, `perceived.md`, `ssr-streaming.md`). Your job is to find the performance improvements the categorized agents' checklists would MISS — do not repeat their findings.
>
> - **Think from the user's experience inward, not the checklist outward.** Pick the app's most-trafficked and most-latency-sensitive flows (login, the first screen after auth, the busiest list, the heaviest detail page, the primary create/submit path) and ask "what is the slowest thing between intent and feedback here, and why?" Follow that thread wherever it leads, including into areas no bullet above names.
> - **Novel and app-specific anti-patterns** — wasteful work that is specific to how THIS codebase is built (a hot serialization, an oversized payload shipped to the client, a synchronous third-party SDK on the critical path, a redundant realtime subscription, an image/video not sized or lazy-loaded, a font/asset blocking first paint, a middleware doing work on every request). Whatever the code actually does wastefully.
> - **Measurement & observability gaps** — is there any way to KNOW what's slow in production (Web Vitals / RUM, server timing, slow-query logging, bundle-size tracking)? A missing feedback loop is itself a finding: it's why improvements stay undiscovered. Recommend the smallest instrumentation that would surface the next tier of wins.
> - **Emerging best practices** — check current official framework docs and web.dev for capabilities this app hasn't adopted that would plausibly help (newer caching/streaming/prefetch primitives, image/font strategies, partial pre-rendering, etc.). Cite the source.
> - **Systemic patterns** — a slow pattern repeated across many files is one finding with broad blast radius, not N findings; name the pattern and quantify the spread.
>
> Report each with file:line (or "systemic — N sites"), severity, impact estimate, and a concrete fix. It is fine — expected, even — for this agent to surface things nobody has thought to look for yet. Write to `$SCRATCH/discovery.md`. Respond only with "Done".

### 4. Wait and verify

Wait for all background agents to complete. Verify all files exist:

```bash
for f in $SCRATCH/{scout,data-access,rendering,perceived,ssr-streaming,discovery}.md; do
  if [ -f "$f" ]; then echo "OK: $(basename $f)"; else echo "MISSING: $(basename $f)"; fi
done
```

Re-launch agents for any missing sections.

### 5. Assemble the report

Read all section files from `$SCRATCH/`. If the output file already exists, preserve its `## Changelog` section.

Combine into a single markdown document:

```markdown
# Performance Audit: [project name]

**Generated:** [YYYY-MM-DD]
**Repository:** [from project.md]
**Scope:** [whole app | the path/area from $ARGUMENTS]

This document is auto-generated by the `/performance-audit` command. It surveys real (server/query) and perceived (client/interaction) performance across the app and proposes a staged, dependency-ordered set of fixes.

---
```

**Section order:**

1. **Executive Summary** — 5-10 bullets covering the highest-impact findings and any systemic pattern (e.g. "zero optimistic removal anywhere", "every detail page blocks on a full fan-out", "no Router Cache staleTime"). Lead with what makes the app *feel* slow.
2. **Data Access** (from `data-access.md`)
3. **Rendering, Algorithms & Bundle** (from `rendering.md`)
4. **Perceived Performance** (from `perceived.md`)
5. **Server Rendering & Streaming** (from `ssr-streaming.md`)
6. **Discovery / Uncategorized** (from `discovery.md`) — novel and app-specific wins, measurement gaps, and emerging best practices the fixed categories don't cover. Keep this section even when short; it's where next-round ideas live.
7. **Interactive-Surface Matrix** — synthesize one row per interactive surface with columns: Surface | Optimistic? | Refresh vs Reload | Prefetched Nav? | Pending Affordance | Loading State. Use PASS/FAIL/PARTIAL so the systemic gaps are visible at a glance.
8. **Ranked Fix Menu** — the deliverable. Group findings into a small number of coherent, independently-shippable **fix candidates** (not raw findings). For each: a one-line title, the surfaces/files it touches, the expected perceived/real win, effort (S/M/L), and **dependencies on other candidates** (e.g. "do after the refresh→reload swap"). Order by impact-per-effort, then by dependency. This is the menu the user picks from. Include the strongest Discovery findings here too — an uncategorized win is still a shippable candidate.
9. **Open Questions / To Investigate** — a short running list of hypotheses the audit could not confirm from source alone (needs a production profile, a real data-volume test, or a measurement it flagged as missing). This keeps the audit a living backlog of leads rather than a one-shot checklist; carry unresolved entries forward across runs.
10. **Changelog** (new dated entry summarizing what changed since the last run + preserved prior entries)

**Formatting:**
- Never use tables for findings prose (terminals truncate them); the Interactive-Surface Matrix and any status grids are the only tables. Write each finding as prose with a clickable `[file.ts:42](relative/path#L42)` link, severity, impact estimate, and concrete fix.
- Sort findings within each section by severity (Critical first).
- Cite `file:line` for every finding. Reference related GitHub issues if any exist (`gh issue list --search "performance OR optimistic OR slow OR staleTimes"`).

Write the assembled document to the output path.

### 6. Clean up

```bash
rm -rf $SCRATCH
```

### 7. Present and offer next steps

Present ONLY the Executive Summary and the Ranked Fix Menu to the user (not the full document) — no preamble, no narration about the process. End with the output file path and one line: the audit is written; each fix candidate in the menu can be turned into a staged issue with `/enhancement` (or `/plan-batch` for the whole set), in dependency order. Do NOT create issues or edit application code automatically — this command audits and proposes; issue creation and implementation are separate, user-authorized steps.

### 8. Commit and push the audit doc

- Determine which repo the output file belongs to (main repo or docs repo per project.md).
- Stage the audit file, commit with `"Update performance audit: [brief summary of key findings]"` (no attribution footer).
- Ask the user before pushing (do not push automatically).

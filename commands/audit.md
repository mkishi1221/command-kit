---
description: "Generate or update a comprehensive codebase audit document"
---

Generate a comprehensive audit of the current codebase state using parallel agents for deep per-section coverage.

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, file paths, docs repo, etc.) before executing. Use those values throughout this workflow.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it.**

**Output location:** Check project.md for "Audit Output" section. If configured, use the codebase audit path specified there. Otherwise default to the plans directory, file named `codebase-audit.md`.

**Process:**

1. **Read project configuration and existing audit:**
   - Read `.claude/project.md` for the audit output path and docs repo location
   - If the audit file already exists, extract ONLY the `## Changelog` section (from `## Changelog` to end of file). Save it to `$SCRATCH/changelog.md`.
   - If no existing file, set `existingChangelog` to empty string.

2. **Prepare a scratch directory** for intermediate results that agents write to disk (avoids context overflow from passing large outputs through prompts):
   ```bash
   SCRATCH="/tmp/audit-$(date +%s)"
   mkdir -p "$SCRATCH"
   ```
   Save the `$SCRATCH` path for use in agent prompts and cleanup.

3. **Run the scout agent** (foreground — other agents need its output):

   Launch a single Agent with this prompt (substitute `$SCRATCH` with the actual path):

   > You are scanning a codebase to produce structural metadata that other audit agents will use.
   >
   > Do the following and return a concise structured summary:
   > 1. Read package.json (or equivalent) - list ALL dependencies with their versions (deps + devDeps)
   > 2. Read .claude/project.md if it exists - note the tech stack, database, and any project-specific config
   > 3. Map directory structure: list all directories under src/ (or equivalent source root) recursively to depth 2, with file counts per directory
   > 4. List all page/view routes (e.g. find src -name 'page.tsx' or src/pages/**/index.*)
   > 5. List all API routes (e.g. find src -name 'route.ts' under api/, or routes/*)
   > 6. Counts: total source files, total lines (wc -l), migration files, test files
   > 7. Identify the tech stack: framework, language, database/ORM, auth provider, CSS/styling, test runner, CI system
   > 8. List .env* file names (NOT their contents - never output secrets)
   > 9. Read middleware or auth config files (just note which files exist and their purpose)
   > 10. Check for error tracking config (Sentry, Bugsnag, etc.) - note if configured
   > 11. Check for analytics config (PostHog, Mixpanel, etc.) - note if configured
   >
   > Be exhaustive in mapping but do NOT read file contents deeply. The goal is a structural map, not a code review.
   >
   > Write your complete output to `$SCRATCH/scout.md` using the Write tool.
   > After writing the file, respond only with "Done".

4. **Launch all section agents in parallel** (background — they run concurrently):

   Launch ALL of the following agents in a **single message** with `run_in_background: true`. Each agent writes its section to `$SCRATCH/<key>.md`. Substitute `$SCRATCH` with the actual path in every prompt.

   **CRITICAL: All agents must be launched in a single message so they run concurrently. Do not launch them one at a time.**

   Each agent prompt follows the same pattern:
   - Read context from `$SCRATCH/scout.md`
   - Perform deep research on its assigned topic
   - Write output to `$SCRATCH/<key>.md`
   - Respond with "Done"

   The section agents and their keys:

   **a. `overview`** — Write the "Overview" and "Architecture" sections:
   - Read package.json for the full stack with versions
   - Scan src/ directory structure and identify key patterns
   - Check recent git history (git log --oneline -20)
   - List what's deployed and working vs what's in progress
   - Output format: `## Overview` (Current Development Phase, What's Deployed, What's In Progress) + `## Architecture` (Stack table, File Structure, Key Patterns)

   **b. `database`** — Write the "Database Schema" section (MOST DETAILED section):
   - Detect database technology from codebase context
   - If Supabase: use MCP tools (ToolSearch for "supabase" tools) to query information_schema.columns, pg_policies, table_constraints, pg_indexes, pg_proc, pg_trigger. Read .claude/project.md for the dev project ID.
   - If Prisma/Drizzle: read schema files. If raw SQL: read migration files.
   - Document EVERY table: name, ALL columns with types/nullability/defaults, RLS policies, foreign keys
   - Output format: `## Database Schema` (Tables, Relationships, Security Policies, Indexes, Database Functions)

   **c. `auth`** — Write the "Authentication & Security" section:
   - Read middleware files for route protection rules
   - Find all auth-related code (grep for auth, session, login, signup, signout)
   - Read auth callback/flow routes and utility files
   - Check CSRF protection, rate limiting, input validation, cookie handling, CORS, CSP
   - List ALL environment variables (grep process.env) and check validation
   - Verify service/secret keys are server-side only
   - Output format: `## Authentication & Security` (Auth Flow, Route Protection, Session Management, Environment Variables table, Input Validation, CORS & Headers, Security Concerns)

   **d. `api`** — Write the "API Routes" section:
   - Find and READ ALL API route handler files
   - Document HTTP methods, purpose, auth checks, input validation, error handling, external calls
   - Find server actions (grep "use server") and read each file
   - Check rate limiting, request size limits, API versioning
   - Output format: `## API Routes` (Route Handlers table, Server Actions, API Concerns)

   **e. `testing`** — Write the "Testing" section:
   - Find ALL test files, categorize (unit, integration, e2e, database, RLS)
   - Count test cases per file
   - Read test and CI config files
   - Read 15+ representative test files to assess quality
   - Compare features vs test files to find coverage gaps
   - Output format: `## Testing` (Coverage Summary table, CI Pipeline, Test Quality Analysis with Coverage Gaps/Mock vs Reality/Low-Value/High-Value/Infrastructure, Test Performance, Recommendations)

   **f. `integrations`** — Write the "Third Party Integrations" and "MCP Usage" sections:
   - Search for ALL external service integrations (Video, Email, Payments, Analytics, Error tracking, Storage, Auth, Search, etc.)
   - Read key files for each integration found
   - Check edge functions, serverless functions
   - Read .mcp.json and Claude settings for MCP configuration
   - Output format: `## Third Party Integrations` (table + Edge Functions) + `## MCP Usage` (Currently Installed, Opportunities, Recommendations)

   **g. `dependencies`** — Write the "Dependency Health" section:
   - Run npm audit / yarn audit / pnpm audit
   - Run npm outdated / yarn outdated
   - Identify vulnerabilities, outdated packages, deprecated packages, misplaced deps
   - Output format: `## Dependency Health` (Security Vulnerabilities table, Outdated Packages table, Deprecated Packages, Dependency Analysis, Recommendations)

   **h. `performance`** — Write the "Performance Considerations" section:
   - Check large dependencies, lazy loading patterns, N+1 query patterns
   - Check pagination, caching, image optimization
   - Look for expensive client-side patterns
   - Read framework config for optimization settings
   - Output format: `## Performance Considerations` (Bundle Size, Data Fetching, Image Optimization, Client-Side Performance, Lazy Loading, Caching Strategy, Recommendations)

   **i. `errors`** — Write the "Error Handling & Observability" section:
   - Find all error boundary/handler files and read them
   - Analyze error handling patterns, console.log/error/warn usage
   - Read error tracking config (Sentry, etc.)
   - If Sentry: read ~/.sentryclirc, run sentry-cli issues list (unresolved, by freq and date), filter out localhost/dev
   - Check monitoring, APM, health checks
   - Output format: `## Error Handling & Observability` (Error Boundaries, Error Handling Patterns, Logging, Monitoring, Sentry Error Log Summary with Top Errors/Recent Errors/Error Trends, Recommendations)

   **j. `frontend`** — Write the "Accessibility", "Mobile Responsiveness", and "Code Duplication" sections:
   - Accessibility: images alt text, form labels, ARIA usage, keyboard navigation, focus management, color contrast
   - Mobile: responsive breakpoints, fixed widths, touch targets, viewport meta, responsive patterns
   - Code duplication: similar component patterns, repeated utilities, extractable hooks, duplicate types, copy-pasted patterns
   - Output format: `## Accessibility` + `## Mobile Responsiveness` + `## Code Duplication & Shared Component Opportunities`

   **k. `patterns`** — Write the "Code Patterns & Consistency", "Developer Experience", and "Technical Debt" sections:
   - Code patterns: data fetching consistency, state management, form handling, error handling, naming conventions, dead code
   - Developer experience: README quality, env setup, tsconfig, eslint, prettier, git hooks, onboarding assessment
   - Technical debt: TODO/FIXME/HACK items, shortcuts/workarounds, missing validation, deprecated APIs, anti-patterns, @ts-ignore usage
   - Output format: `## Code Patterns & Consistency` + `## Developer Experience` + `## Technical Debt`

   **l. `safety`** — Write the "Claude Code Safety Audit" section:
   - Read .claude/settings.local.json: check for hardcoded secrets, overly broad permissions, dangerous git permissions, stale entries
   - Check .claude/hooks/: list scripts, verify production safety hooks exist
   - Check .mcp.json: access tokens, write vs read-only access
   - Credential hygiene: .gitignore coverage, git history for env files
   - Output format: `## Claude Code Safety Audit` (Credentials Exposure, Permission Analysis, Production Safety Hooks table, MCP Server Configuration, Allow List Hygiene, Credential Hygiene)

5. **Wait for all background agents to complete.** Verify all section files exist:
   ```bash
   for f in $SCRATCH/{scout,overview,database,auth,api,testing,integrations,dependencies,performance,errors,frontend,patterns,safety}.md; do
     if [ -f "$f" ]; then echo "OK: $(basename $f)"; else echo "MISSING: $(basename $f)"; fi
   done
   ```

   If any files are missing after all agents have completed, re-launch agents for just the missing sections.

6. **Assemble the final document:**

   Read all section files from `$SCRATCH/` and the preserved changelog (if any). Combine into a single markdown document with this structure:

   **Header:**
   ```markdown
   # Codebase Audit: [project name]

   **Generated:** [today's date YYYY-MM-DD]
   **Repository:** [from project.md]
   **Branch:** [current branch] ([file count] source files, [line count] lines, [migration count] migrations, [test file count] test files, [table count] tables)

   This document is auto-generated by the `/audit` command. It provides a comprehensive snapshot of the codebase state.

   ---
   ```

   **Section order** (skip any with no data):
   1. Overview + Architecture (from `overview.md`)
   2. Database Schema (from `database.md`)
   3. Authentication & Security (from `auth.md`)
   4. API Routes (from `api.md`)
   5. Testing (from `testing.md`)
   6. Third Party Integrations + MCP Usage (from `integrations.md`)
   7. Dependency Health (from `dependencies.md`)
   8. Performance Considerations (from `performance.md`)
   9. Error Handling & Observability (from `errors.md`)
   10. Accessibility + Mobile Responsiveness + Code Duplication (from `frontend.md`)
   11. Code Patterns + Developer Experience + Technical Debt (from `patterns.md`)
   12. Claude Code Safety Audit (from `safety.md`)

   **Synthesized sections** (write these yourself based on the section file contents):
   13. **Security Checklist** — table with Area / Status / Notes for: Authentication, Session Management, Route Protection, Row-Level Security, CSRF, CSP, Input Validation, Rate Limiting, XSS Prevention, Service Key Isolation, Environment Variables, Error Tracking, Dependency Security, Credentials in Repo, Password Requirements
   14. **Sprint Plan Recommendations** — prioritized list (Priority 1: Security & Correctness, Priority 2: Code Quality, Priority 3: UI Consistency, Priority 4: Architecture, Priority 5: Testing & DevOps, Priority 6: Performance)
   15. **Changelog** — new entry for today + all preserved entries from the existing changelog

   **Formatting rules:**
   - Ensure consistent heading levels (`##` for top sections, `###` for subsections)
   - Add `---` separators between major sections
   - Remove any agent preamble text ("Here is the...", "Below is the...")
   - Ensure the top-level heading (`# ...`) only appears once

   Write the assembled document to the output path from project.md.

7. **Clean up scratch files:**
   ```bash
   rm -rf $SCRATCH
   ```

8. **Commit and push:**
   - Determine which repo the output file belongs to (main repo or docs repo per project.md)
   - Stage the audit file
   - Commit with message: `"Update codebase audit: [brief summary of key changes]"`
   - Ask the user before pushing (do not push automatically)

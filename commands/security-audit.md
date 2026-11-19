---
description: "Audit API endpoint protection, bot defenses, and cost exposure vectors"
---

Audit the codebase for security posture: rate limiting, bot protection, auth coverage, and cost exposure from abuse. Produces a report with per-endpoint findings and prioritised recommendations.

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, file paths, docs repo, etc.) before executing.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it.**

**Output location:** Check project.md for "Audit Output" section. Write the report to the same directory as other audit files, named `<prefix>_Security_Audit.md` (using the same prefix as other audit files in that directory). If no audit directory is configured, write to the plans directory.

---

## Workflow

### 1. Prepare scratch space

```bash
SCRATCH="/tmp/security-audit-$(date +%s)"
mkdir -p "$SCRATCH"
```

### 2. Scout phase (foreground)

Launch a single Agent to map the attack surface. It must write its output to `$SCRATCH/scout.md`.

> You are mapping the attack surface of a web application. Do the following and write a structured summary to `$SCRATCH/scout.md`:
>
> 1. **API routes:** Find all route handlers (`route.ts`, `route.js`) and list each with its HTTP methods
> 2. **Server actions:** Find all files containing `"use server"` and list exported functions
> 3. **Public pages:** Find all page routes - note which are behind auth and which are public
> 4. **Middleware:** Read middleware.ts/js if it exists - document route matching rules
> 5. **Auth config:** Find auth configuration files (Supabase config, NextAuth config, etc.) - note rate limits and session settings
> 6. **Security utilities:** Find files related to rate limiting, CSRF, input validation, bot detection, CAPTCHA
> 7. **External services:** List services that have usage-based billing (video encoding, email, storage, compute, analytics) by checking package.json and env vars
> 8. **Public assets:** Check for robots.txt, security.txt, .well-known/ files
> 9. **Security documentation:** Check docs/technical/ (and the docs repo if configured in project.md) for any security-related docs (firewall config, WAF rules, edge protection, infrastructure security). List what's documented and summarise each
> 10. **Webhook endpoints:** List all webhook handlers and their signature verification methods
> 11. **Environment variables:** List all env vars referenced (names only, never values) - flag any that are client-exposed (`NEXT_PUBLIC_*`)
>
> Write your output to `$SCRATCH/scout.md` using the Write tool. Respond only with "Done".

### 3. Deep analysis agents (parallel, background)

Launch ALL of the following agents in a **single message** with `run_in_background: true`. Each writes to `$SCRATCH/<key>.md`.

**a. `endpoints`** - Audit every API route and server action:

> Read `$SCRATCH/scout.md` for the list of API routes and server actions.
>
> For EVERY route handler and server action, read the file and document:
> - **Authentication:** Does it check for a session? What happens if unauthenticated?
> - **Authorization:** Does it verify roles/ownership? (admin, creator, superadmin, resource owner)
> - **CSRF protection:** Does it call a CSRF guard (e.g. requireSameOrigin)?
> - **Rate limiting:** Is there a rate limit? What are the limits (count/window)?
> - **Input validation:** Is user input validated? (schema validation, type checks, size limits)
> - **Error handling:** Does it fail closed (deny on error) or fail open?
>
> Output a markdown table with columns: Route | Methods | Auth | Authz | CSRF | Rate Limit | Input Validation | Notes
>
> After the table, list:
> - **Unprotected endpoints:** Routes missing auth that handle sensitive operations
> - **Missing rate limits:** Authenticated routes that could be abused (especially those that trigger external API calls or write to DB)
> - **Missing input validation:** Routes that accept user input without validation
>
> Write to `$SCRATCH/endpoints.md`. Respond only with "Done".

**b. `bot-protection`** - Audit bot and abuse defenses:

> Read `$SCRATCH/scout.md` for context.
>
> Check for the following bot protection mechanisms and document what exists vs what's missing:
>
> 1. **CAPTCHA/bot detection:** Search for reCAPTCHA, hCaptcha, Turnstile, Arkose, or any bot detection library in dependencies and code
> 2. **robots.txt:** Check public/ directory for robots.txt - document its contents or note absence
> 3. **WAF/edge protection:** Check vercel.json, netlify.toml, or similar for firewall rules, rate limiting rules, IP blocking. Also check for documentation of dashboard-configured rules in docs/technical/ (e.g. Vercel Firewall, Cloudflare) — these are configured outside the codebase but documented in the repo
> 4. **User-Agent filtering:** Search for any User-Agent checks in middleware or route handlers
> 5. **IP-based throttling:** Search for IP extraction and per-IP rate limiting
> 6. **Signup abuse prevention:** Read the signup flow - what prevents mass account creation? (CAPTCHA, email verification, phone verification, invite-only)
> 7. **Session/token abuse:** Check session configuration (token lifetime, refresh rotation, concurrent session limits)
> 8. **Crawler protection:** Check for any anti-scraping measures on data-heavy pages
> 9. **Security headers:** Read CSP, HSTS, X-Frame-Options, Permissions-Policy configuration
> 10. **Webhook security:** For each webhook endpoint, verify signature validation exists
>
> For each area, report: Present/Absent, implementation details if present, risk level if absent (Critical/High/Medium/Low).
>
> Write to `$SCRATCH/bot-protection.md`. Respond only with "Done".

**c. `cost-exposure`** - Assess billing abuse vectors:

> Read `$SCRATCH/scout.md` for context.
>
> For each external service with usage-based billing, assess the cost exposure from automated abuse:
>
> For each service found:
> 1. **Service name and billing model** (per-request, per-minute, per-GB, per-email, etc.)
> 2. **Entry points:** Which routes/actions trigger usage of this service?
> 3. **Current protections:** What rate limits, auth checks, or quotas gate access?
> 4. **Abuse scenario:** How could a bot drive up costs? (e.g. "spam video uploads to trigger Mux transcoding")
> 5. **Estimated exposure:** What's the worst-case cost from 24 hours of sustained abuse at the current rate limits (or lack thereof)?
> 6. **Spend alerts:** Are there billing alerts configured? (Check for monitoring config, alert thresholds)
>
> Common services to check: video encoding (Mux, Cloudflare Stream), email (Resend, SendGrid), database (Supabase), hosting/compute (Vercel), storage (S3, R2, Supabase Storage), analytics (PostHog), error tracking (Sentry), search, AI/LLM APIs.
>
> Output a risk table: Service | Billing Model | Entry Points | Rate Limited? | 24hr Worst Case | Risk Level
>
> Write to `$SCRATCH/cost-exposure.md`. Respond only with "Done".

**d. `auth-config`** - Audit auth configuration and rate limits:

> Read `$SCRATCH/scout.md` for context.
>
> Deep-dive into authentication and auth-adjacent configuration:
>
> 1. **Auth provider rate limits:** Read Supabase config files (config.toml, config.prod.toml) or equivalent - document all rate limit settings for sign-in, sign-up, email sends, token refresh, OTP
> 2. **Password policy:** Check minimum length, complexity requirements, breach database checks
> 3. **Session configuration:** JWT lifetime, refresh token rotation, inactivity timeout, max session duration
> 4. **Email verification:** Is email verification required before access? Can unverified accounts do anything?
> 5. **Account lockout:** Is there account lockout after failed attempts?
> 6. **Magic link / OTP security:** Token expiry, single-use enforcement, hash storage
> 7. **OAuth configuration:** Which providers? Correct redirect URI validation?
> 8. **Admin access:** How is admin/superadmin determined? Can it be self-assigned?
> 9. **Service role usage:** Where is the service role client used? Is it properly restricted to server-side?
> 10. **RLS bypass routes:** Any routes using service role that skip RLS? Document what they access.
>
> Write to `$SCRATCH/auth-config.md`. Respond only with "Done".

### 4. Wait and verify

Wait for all background agents to complete. Verify all files exist:

```bash
for f in $SCRATCH/{scout,endpoints,bot-protection,cost-exposure,auth-config}.md; do
  if [ -f "$f" ]; then echo "OK: $(basename $f)"; else echo "MISSING: $(basename $f)"; fi
done
```

Re-launch agents for any missing sections.

### 5. Assemble the report

Read all section files from `$SCRATCH/`. If the output file already exists, preserve its `## Changelog` section.

Combine into a single markdown document:

```markdown
# Security Audit: [project name]

**Generated:** [YYYY-MM-DD]
**Repository:** [from project.md]

This document is auto-generated by the `/security-audit` command. It provides a snapshot of the application's security posture, bot defenses, and cost exposure vectors.

---
```

**Section order:**

1. **Executive Summary** (synthesize from all sections - 5-10 bullet points covering the most important findings)
2. **Endpoint Protection Matrix** (from `endpoints.md` - the full table of every route and its protections)
3. **Bot & Abuse Protection** (from `bot-protection.md`)
4. **Cost Exposure Analysis** (from `cost-exposure.md` - risk table + abuse scenarios)
5. **Authentication & Configuration** (from `auth-config.md`)
6. **Security Checklist** (synthesize a table: Area | Status | Details - covering: Rate Limiting, CAPTCHA/Bot Detection, CSRF, CSP, Auth Rate Limits, Session Security, Input Validation, Webhook Verification, Crawler Protection, Spend Alerts, robots.txt, WAF/Edge Protection, Password Policy, Service Role Isolation)
7. **Recommendations** (prioritised: P0 = actively exploitable or high cost risk, P1 = missing standard protection, P2 = defense-in-depth improvements, P3 = nice-to-have hardening)
8. **Changelog** (new entry + preserved entries)

**Formatting:**
- Use checkmarks and crosses in the checklist (PASS/FAIL/PARTIAL)
- Include file paths for every finding
- Never include secrets, tokens, or PII
- Reference related GitHub issues if any exist (search with `gh issue list --search "rate limit OR bot OR security"`)

Write the assembled document to the output path.

### 6. Clean up

```bash
rm -rf $SCRATCH
```

### 7. Commit and push

- Determine which repo the output file belongs to (main repo or docs repo per project.md)
- Stage the audit file
- Commit with message: `"Update security audit: [brief summary of key findings]"`
- Ask the user before pushing (do not push automatically)

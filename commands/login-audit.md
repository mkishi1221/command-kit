---
description: "Audit login flows, session security, auth config, and identity attack surface"
---

Audit the login and authentication security posture end-to-end: sign-up, sign-in, session lifecycle, password/OTP handling, OAuth, middleware protection, and auth-related RLS. Produces a focused report with findings and prioritised recommendations.

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, file paths, docs repo, etc.) before executing.

> **Stack note:** The auth-config and row-level-security steps assume **Supabase Auth**. If your project uses a different auth provider, ask Claude Code to adapt those steps; the login-flow and session checks are provider-agnostic.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it.**

**Output location:** Check project.md for "Audit Output" section. Write the report to the same directory as other audit files, named `<prefix>_Login_Security_Audit.md` (using the same prefix as other audit files in that directory). If no audit directory is configured, write to the plans directory.

---

## Workflow

### 1. Prepare scratch space

```bash
SCRATCH="/tmp/login-audit-$(date +%s)"
mkdir -p "$SCRATCH"
```

### 2. Scout phase (foreground)

Launch a single Agent to map the authentication surface. It must write its output to `$SCRATCH/scout.md`.

> You are mapping the authentication and login surface of a web application. Do the following and write a structured summary to `$SCRATCH/scout.md`:
>
> 1. **Auth provider:** Identify the auth provider (Supabase Auth, NextAuth, Clerk, custom, etc.) by checking dependencies and config files
> 2. **Auth config files:** Find all auth-related config (supabase/config.toml, config.prod.toml, auth.ts, middleware.ts, etc.) and list them
> 3. **Login/signup routes:** Find all pages and API routes related to sign-in, sign-up, sign-out, password reset, magic link, OTP, callback, verify
> 4. **Auth utilities:** Find helper files for auth (createClient, getSession, requireAuth, etc.)
> 5. **Middleware:** Read middleware.ts/js - document which routes are protected and which are public
> 6. **OAuth providers:** List configured OAuth providers and their callback routes
> 7. **Server actions:** Find server actions related to auth (grep for signIn, signUp, signOut, resetPassword in "use server" files)
> 8. **Email templates:** Find auth-related email templates (verification, password reset, magic link, invitation)
> 9. **Auth-related DB tables:** List tables related to auth (users, sessions, profiles, roles, invitations, etc.)
> 10. **Rate limiting:** Find any rate limiting applied to auth endpoints
> 11. **CAPTCHA/bot protection:** Check for CAPTCHA on login/signup forms
> 12. **Client-side auth code:** Find components that handle login forms, auth state, session refresh, token storage
>
> Write your output to `$SCRATCH/scout.md` using the Write tool. Respond only with "Done".

### 3. Deep analysis agents (parallel, background)

Launch ALL of the following agents in a **single message** with `run_in_background: true`. Each writes to `$SCRATCH/<key>.md`.

**a. `auth-flows`** - Audit every login and registration flow end-to-end:

> Read `$SCRATCH/scout.md` for context.
>
> Trace every authentication flow from UI to database. For each flow, read the actual code and document:
>
> **Sign-up flow:**
> - What fields are collected? Is email verified before granting access?
> - What happens after signup (redirect, onboarding, immediate access)?
> - Are duplicate accounts prevented? What error is shown?
> - Is there an invitation/allowlist gate?
> - Is CAPTCHA present? What bot protections exist?
>
> **Sign-in flow (each method separately):**
> - Email/password: password validation, error messages (do they leak user existence?), lockout after failures
> - Magic link/OTP: token expiry, single-use enforcement, delivery method, error handling
> - OAuth: which providers, redirect URI validation, account linking behavior, what happens if OAuth email already exists
>
> **Password reset flow:**
> - How is the reset initiated? Token expiry? Single-use?
> - Can an attacker enumerate valid emails via the reset flow?
> - Is the user notified of password changes?
>
> **Sign-out flow:**
> - Does it invalidate the session server-side or just clear the client cookie?
> - Does it revoke refresh tokens?
> - Global sign-out (all devices) available?
>
> **Session refresh:**
> - How are tokens refreshed? Is rotation enabled?
> - What happens when refresh fails? Silent re-auth or forced login?
>
> For each flow, note: entry point file, key code paths, and any security concerns.
>
> Write to `$SCRATCH/auth-flows.md`. Respond only with "Done".

**b. `session-security`** - Audit session and token configuration:

> Read `$SCRATCH/scout.md` for context.
>
> Deep-dive into session and token security. Read all relevant config files and code:
>
> 1. **JWT configuration:**
>    - JWT lifetime (access token expiry)
>    - Refresh token rotation enabled/disabled
>    - Refresh token reuse interval
>    - Token signing algorithm
>
> 2. **Session limits:**
>    - Inactivity timeout
>    - Maximum session duration (time-box)
>    - Concurrent session limits per user
>    - Session revocation mechanism
>
> 3. **Cookie security:**
>    - HttpOnly flag
>    - Secure flag
>    - SameSite attribute
>    - Cookie path and domain
>    - Cookie name (is it predictable?)
>
> 4. **Token storage (client-side):**
>    - Where are tokens stored? (cookies, localStorage, sessionStorage, memory)
>    - Are tokens exposed to JavaScript?
>    - Is there XSS risk from token storage?
>
> 5. **CSRF protection:**
>    - Is CSRF protection in place for auth endpoints?
>    - How is CSRF token generated and validated?
>
> 6. **Auth state management (client-side):**
>    - How does the app detect session expiry?
>    - Is there a session listener/subscription?
>    - What happens on 401 responses?
>
> 7. **If Supabase:** Read config.toml and config.prod.toml for all auth settings. Compare dev vs prod config for any dangerous differences (e.g. dev has email confirmation disabled but prod requires it).
>
> Flag any configuration that deviates from security best practices. Compare dev and prod configs if both are available.
>
> Write to `$SCRATCH/session-security.md`. Respond only with "Done".

**c. `auth-provider-config`** - Audit auth provider rate limits and security settings:

> Read `$SCRATCH/scout.md` for context.
>
> If the project uses Supabase Auth, read config.toml AND config.prod.toml (check project.md for paths) and document:
>
> 1. **Rate limits for auth operations:**
>    - Sign-up rate limit (per IP, per email)
>    - Sign-in rate limit
>    - Token refresh rate limit
>    - Email send rate limit (magic links, verification, password reset)
>    - OTP rate limit
>    - SMS rate limit
>
> 2. **Password policy:**
>    - Minimum length
>    - Required complexity (uppercase, lowercase, numbers, symbols)
>    - Hibp (breach database) checking enabled?
>
> 3. **Email settings:**
>    - Is email confirmation required?
>    - Is double opt-in enabled?
>    - Email change requires confirmation?
>    - Secure email change (requires confirmation from both old and new)?
>    - Email OTP expiry
>    - Max email frequency per user
>
> 4. **MFA/2FA:**
>    - Is MFA available/required?
>    - Which MFA methods? (TOTP, SMS, WebAuthn)
>    - MFA enrollment flow
>
> 5. **External providers:**
>    - Which OAuth providers are enabled?
>    - Are redirect URIs restricted?
>    - Is manual account linking enabled?
>
> 6. **Hook/webhook configuration:**
>    - Auth hooks (custom access token, MFA verification, password verification, send email/SMS)
>    - Are there any custom auth hooks?
>
> 7. **Dev vs Prod differences:**
>    - Compare every auth setting between dev and prod config
>    - Flag any settings where dev is MORE permissive than prod (acceptable for development)
>    - Flag any settings where prod is MORE permissive than dev (potential security risk)
>
> For non-Supabase projects, find the equivalent auth provider configuration and document the same categories.
>
> Write to `$SCRATCH/auth-provider-config.md`. Respond only with "Done".

**d. `route-protection`** - Audit middleware and route-level auth enforcement:

> Read `$SCRATCH/scout.md` for context.
>
> Audit how authentication is enforced across the application:
>
> 1. **Middleware analysis:**
>    - Read the main middleware file completely
>    - Which routes are protected? Which are public?
>    - How is the session validated in middleware? (token check, cookie check, API call)
>    - What happens when auth fails? (redirect, 401, 403)
>    - Is there role-based routing? (admin routes, creator routes)
>
> 2. **Page-level auth checks:**
>    - Find pages that perform their own auth checks (getSession, getUser, etc.)
>    - Are there pages that SHOULD require auth but DON'T?
>    - Is there consistency between middleware protection and page-level checks?
>
> 3. **API route auth checks:**
>    - For EVERY API route: does it verify the session?
>    - For routes that modify data: does it verify ownership/role?
>    - Are there API routes accessible without authentication?
>    - Do API routes use the anon key or service role key?
>
> 4. **Server action auth checks:**
>    - Do server actions verify the session before acting?
>    - Is auth checked at the start of every action?
>
> 5. **Service role usage:**
>    - Where is the service role (admin) Supabase client used?
>    - Is it ONLY used server-side?
>    - Could any client-side code access the service role key?
>    - What operations use service role? Are they all necessary?
>
> 6. **Auth bypass risks:**
>    - Can any protected page/API be accessed by manipulating the URL?
>    - Are there fallthrough paths where auth is accidentally skipped?
>    - Check for `if (session)` patterns that fail open vs `if (!session) redirect`
>
> Output a table: Route/Page | Auth Check | Method | Role Check | Bypass Risk | Notes
>
> Write to `$SCRATCH/route-protection.md`. Respond only with "Done".

**e. `identity-attacks`** - Assess identity-specific attack vectors:

> Read `$SCRATCH/scout.md` for context.
>
> Assess the application's resilience to identity-focused attacks:
>
> 1. **Account enumeration:**
>    - Does the login error message differ for "user not found" vs "wrong password"?
>    - Does the signup flow reveal whether an email is already registered?
>    - Does the password reset flow confirm whether an email exists?
>    - Does the sign-up API return different status codes for existing vs new emails?
>
> 2. **Brute force:**
>    - What rate limits exist on the sign-in endpoint?
>    - Is there account lockout after N failures? What's the lockout duration?
>    - Is there IP-based rate limiting?
>    - Is there CAPTCHA after failed attempts?
>
> 3. **Session fixation/hijacking:**
>    - Are session tokens rotated on login?
>    - Is the session bound to any client fingerprint?
>    - Can session cookies be stolen via XSS?
>
> 4. **Token replay:**
>    - Are magic link/OTP tokens single-use?
>    - Are refresh tokens invalidated after use (rotation)?
>    - Are password reset tokens single-use?
>
> 5. **Privilege escalation:**
>    - How are roles assigned (admin, creator, superadmin)?
>    - Can a user modify their own role via any API endpoint?
>    - Is role checked server-side for every privileged operation?
>    - Are there RLS policies that prevent role tampering?
>
> 6. **Account takeover vectors:**
>    - OAuth account linking: can an attacker link their OAuth to another user's account?
>    - Email change: is the old email notified? Is confirmation required?
>    - Password change: does it require current password?
>    - Session invalidation: are other sessions killed after password change?
>
> 7. **Credential stuffing:**
>    - Is password breach database checking enabled?
>    - Are common passwords blocked?
>    - Is there monitoring for unusual login patterns?
>
> For each attack vector, rate: Protected / Partially Protected / Unprotected, with evidence from the code.
>
> Write to `$SCRATCH/identity-attacks.md`. Respond only with "Done".

**f. `auth-rls`** - Audit RLS policies related to auth and identity:

> Read `$SCRATCH/scout.md` for context.
>
> If the project uses Supabase (or another DB with RLS), audit row-level security policies related to authentication and identity:
>
> 1. **User identity tables:**
>    - What tables store user identity data? (profiles, creator records, etc.)
>    - Read the RLS policies on each of these tables
>    - Can a user read other users' private data?
>    - Can a user modify another user's profile?
>
> 2. **Auth-gated tables:**
>    - Which tables require authentication to read/write?
>    - Are the policies using `auth.uid()` correctly?
>    - Are there tables that SHOULD have auth-gated RLS but don't?
>
> 3. **Role-based RLS:**
>    - How do RLS policies check user roles? (JWT claims, lookup table, etc.)
>    - Can the role check be bypassed?
>    - Are admin/superadmin policies properly restricted?
>
> 4. **Service role bypass:**
>    - Which operations bypass RLS via service role?
>    - Are these all legitimate (e.g. admin operations, system tasks)?
>
> 5. **Query the database** (if Supabase MCP is available):
>    - Use ToolSearch to find Supabase MCP tools
>    - Query `pg_policies` for all policies on auth-related tables
>    - Query for tables with NO RLS enabled
>    - Check if RLS is enforced (not just enabled but with policies)
>
> Write to `$SCRATCH/auth-rls.md`. Respond only with "Done".

### 4. Wait and verify

Wait for all background agents to complete. Verify all files exist:

```bash
for f in $SCRATCH/{scout,auth-flows,session-security,auth-provider-config,route-protection,identity-attacks,auth-rls}.md; do
  if [ -f "$f" ]; then echo "OK: $(basename $f)"; else echo "MISSING: $(basename $f)"; fi
done
```

Re-launch agents for any missing sections.

### 5. Assemble the report

Read all section files from `$SCRATCH/`. If the output file already exists, preserve its `## Changelog` section.

Combine into a single markdown document:

```markdown
# Login & Security Audit: [project name]

**Generated:** [YYYY-MM-DD]
**Repository:** [from project.md]

This document is auto-generated by the `/login-audit` command. It provides a focused audit of authentication, login flows, session security, and identity attack surface.

---
```

**Section order:**

1. **Executive Summary** (synthesize from all sections - 5-10 bullet points covering the most critical findings, grouped by severity)
2. **Authentication Flows** (from `auth-flows.md` - sign-up, sign-in, password reset, sign-out, session refresh)
3. **Session & Token Security** (from `session-security.md` - JWT, cookies, CSRF, client-side token handling)
4. **Auth Provider Configuration** (from `auth-provider-config.md` - rate limits, password policy, email settings, MFA, dev vs prod diff)
5. **Route Protection Matrix** (from `route-protection.md` - the full table of routes and their auth enforcement)
6. **Identity Attack Surface** (from `identity-attacks.md` - enumeration, brute force, session attacks, privilege escalation, account takeover)
7. **Auth-Related RLS Policies** (from `auth-rls.md` - identity tables, role-based RLS, service role bypass)
8. **Security Checklist** (synthesize a table: Area | Status | Details - covering: Email Verification, Password Policy, Account Lockout, Rate Limiting (auth), CAPTCHA/Bot Detection, Session Expiry, Refresh Token Rotation, Cookie Security, CSRF Protection, Account Enumeration Prevention, MFA, OAuth Security, Role-Based Access, Service Role Isolation, Auth-Related RLS, Password Reset Security, Email Change Security, Sign-Out Completeness)
9. **Recommendations** (prioritised: P0 = actively exploitable, P1 = missing critical auth protection, P2 = best-practice gaps, P3 = defense-in-depth improvements)
10. **Changelog** (new entry + preserved entries)

**Formatting:**
- Use PASS/FAIL/PARTIAL in the checklist with brief notes
- Include file paths for every finding
- Never include secrets, tokens, or PII
- Reference related GitHub issues if any exist (search with `gh issue list --search "auth OR login OR session OR security"`)

Write the assembled document to the output path.

### 6. Clean up

```bash
rm -rf $SCRATCH
```

### 7. Commit and push

- Determine which repo the output file belongs to (main repo or docs repo per project.md)
- Stage the audit file
- Commit with message: `"Update login security audit: [brief summary of key findings]"`
- Ask the user before pushing (do not push automatically)

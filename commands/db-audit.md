---
description: "Compare dev and prod Supabase projects and report any divergence"
---

Audit dev vs prod Supabase parity. Report deltas only.

> **Stack note:** This command assumes **Supabase** — every check queries two Supabase projects through the Supabase MCP. If your project uses a different database or host, ask Claude Code to adapt the checks to your stack.

**Project settings:** Read `.claude/project.md` for project-specific configuration. This skill requires a `## Supabase Projects` section with `Dev Project ID` and `Prod Project ID`. If those fields are missing, ask the user for the two project IDs before continuing.

**Strictness:** Flag every divergence, including comment-only / whitespace-only diffs. Cosmetic differences in prod usually indicate someone applied SQL via the SQL Editor instead of via a tracked migration, which is worth surfacing.

**Read-only:** This skill makes no writes. Every query is `SELECT` against `mcp__supabase__execute_sql`, plus `mcp__supabase__list_migrations`, `mcp__supabase__list_extensions`, `mcp__supabase__list_edge_functions`, and `mcp__supabase__get_edge_function`.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it. Do not describe what you would do or ask for permission — execute the step.**

---

## Workflow

Run the checks below. For each one, output a single line: `✅ <area>` if dev and prod match, or `❌ <area>` followed by the specific deltas. End with a summary block listing every `❌` area for quick scanning.

Run independent queries in parallel — every check below issues the same SQL against dev and prod, and the two MCP calls have no dependency on each other.

### 1. Migrations

`mcp__supabase__list_migrations` on dev and prod. Diff the `(version, name)` pairs. Report any migrations on one but not the other.

### 2. Installed extensions

`mcp__supabase__list_extensions` on dev and prod. Filter to rows where `installed_version IS NOT NULL` — the catalog of *available* extensions can legitimately differ between Supabase regions/images and is not interesting. Diff the installed set.

### 3. Schema objects (hash compare)

Run identical SQL on dev and prod. The query produces one row per object with an md5 hash of the relevant definition; that lets you eyeball-diff the results without pulling full DDL into context.

**Tables and columns:**
```sql
SELECT table_schema, table_name,
       md5(string_agg(
         column_name||'|'||data_type||'|'||udt_name||'|'||is_nullable
         ||'|'||COALESCE(column_default,'')
         ||'|'||COALESCE(character_maximum_length::text,'')
         ||'|'||COALESCE(numeric_precision::text,'')
         ||'|'||COALESCE(numeric_scale::text,''),
         '||' ORDER BY column_name)) AS h,
       count(*) AS cols
FROM information_schema.columns
WHERE table_schema IN ('public','storage','auth')
GROUP BY table_schema, table_name
ORDER BY table_schema, table_name;
```

**Indexes:**
```sql
SELECT schemaname, tablename, indexname, md5(indexdef) AS h
FROM pg_indexes
WHERE schemaname IN ('public','storage','auth')
ORDER BY schemaname, tablename, indexname;
```

**Constraints:**
```sql
SELECT conrelid::regclass::text AS tbl, conname, contype,
       md5(pg_get_constraintdef(oid)) AS h
FROM pg_constraint
WHERE connamespace IN (
  SELECT oid FROM pg_namespace WHERE nspname IN ('public','storage','auth')
)
ORDER BY tbl, conname;
```

**Functions** (uses `pg_get_functiondef` which includes comments — intentional, see Strictness above):
```sql
SELECT n.nspname AS schema, p.proname AS name,
       pg_get_function_identity_arguments(p.oid) AS args,
       md5(pg_get_functiondef(p.oid)) AS def_hash
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public','storage','auth')
ORDER BY schema, name, args;
```

**Triggers:**
```sql
SELECT event_object_schema AS schema, event_object_table AS tbl, trigger_name,
       event_manipulation, action_timing, action_orientation,
       md5(action_statement) AS stmt_hash
FROM information_schema.triggers
WHERE event_object_schema IN ('public','storage','auth')
ORDER BY schema, tbl, trigger_name, event_manipulation;
```

**Views:**
```sql
SELECT table_schema, table_name, md5(view_definition) AS h
FROM information_schema.views
WHERE table_schema IN ('public','storage','auth')
ORDER BY table_schema, table_name;
```

For any object where the hash differs, fetch the full definition from both projects (`pg_get_functiondef`, `indexdef`, `pg_get_constraintdef`, `view_definition`, etc.) and include the diff inline. Don't make the user re-query for context.

### 4. RLS policies

```sql
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname IN ('public','storage')
ORDER BY schemaname, tablename, policyname;
```

This dump is large but bounded — there's no useful hashing here because `qual` and `with_check` are the whole point. If the raw result exceeds the inline token budget, the MCP saves it to a `tool-results` file; read both files and diff with `diff` or `jq` rather than re-reading the full JSON into context.

### 5. Storage buckets

```sql
SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets
ORDER BY id;
```

### 6. Cron jobs

```sql
SELECT jobname, schedule, command, active
FROM cron.job
ORDER BY jobname;
```

Note: cron commands that read from `vault.decrypted_secrets` are expected to match — only the *names* are compared, not the secret values.

### 7. Vault secret names

```sql
SELECT name FROM vault.secrets ORDER BY name;
```

Names only. Values are intentionally per-environment and never read by this skill.

### 8. Edge functions

For each function returned by `mcp__supabase__list_edge_functions`:

- **Do not rely on `ezbr_sha256`** — it includes deployment metadata and produces different values for identical source. Verified empirically.
- Fetch `mcp__supabase__get_edge_function` on dev and prod.
- For each file in the bundle, compute md5 of the `content` field. Compare per-file hashes.
- If a bundle is too large to fit inline (the tool will persist it to a `tool-results` JSON file), use the saved file. A clean way to hash each file from saved JSON:

```bash
DEV=<path-to-dev-tool-result>
PROD=<path-to-prod-tool-result>
jq -r '.[0].text | fromjson | .files[] | [.name, (.content|@base64)] | @tsv' "$DEV" \
  | while IFS=$(printf '\t') read -r name b64; do
      echo "$b64" | base64 -D | md5 | awk -v n="$name" '{print n, $0}'
    done
```

Run the same for prod and diff. If a function exists in one project but not the other, that's a hard fail.

### 9. Postgres version (informational only)

`mcp__supabase__get_project` on both. Compare `database.version`. A patch-level difference (e.g. `17.6.1.054` vs `17.6.1.063`) is normal Supabase maintenance — note it but don't flag as a failure. Anything bigger (different major/minor) means one side missed a planned upgrade and should be flagged.

---

## Output format

Single message, top-down. Don't ask intermediate questions — run everything, then report.

```
## Dev vs Prod Parity Audit

### ✅ Matching
- Migrations (N each)
- Installed extensions
- Tables / columns
- Indexes
- Constraints
- Triggers
- Views
- RLS policies
- Storage buckets
- Cron jobs
- Vault secret names
- Edge function: <name>
- ...

### ❌ Divergent
- <area>: <one-line summary>
  - <delta detail>
- ...

### ℹ️ Informational
- Postgres patch version: dev=X.Y.Z prod=X.Y.Z (expected)

### Summary
N divergences found. Recommended action: <e.g. "redeploy edge function X to dev" / "apply migration NNN to prod via SQL Editor" / "investigate function Y comment drift">.
```

If there are zero divergences, the `### ❌ Divergent` section is replaced by `**✅ All checks passed — dev and prod are fully aligned.**`

---

## When to run

- **Post-release** — after the dev→main PR merges and the user finishes applying production migrations and deploying edge functions. Verifies the deployment didn't leave anything behind.
- **After a hotfix** — hotfixes target main and are also applied to prod directly; the back-merge to dev can drift, especially for SQL applied via the SQL Editor. Run this after the hotfix back-merge completes to confirm both sides match.
- **Ad-hoc** — any time you suspect drift (e.g. someone hand-edited a function in the SQL Editor).

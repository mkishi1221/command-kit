---
description: "Generate or update the Data Fields doc from the current database state"
---

Generate or update the Data Fields documentation from the current database state.

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, Data Fields Doc path, docs repo, etc.) before executing. Use those values throughout this workflow.

> **Stack note:** This command assumes **Supabase** — it reads the live database through the Supabase MCP to generate the doc. If your project uses a different database, ask Claude Code to adapt the query steps to your stack.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it.**

## Workflow

1. **Check configuration** — Read `.claude/project.md` and look for a **Data Fields Doc** path under a `## Data Fields` section.
   - If configured, read the existing doc to understand current state and conventions
   - If NOT configured, create the doc at `docs/product/{Project_Name}_Data_Fields.md` (derive the project name from project.md's title) and add a `## Data Fields` section to project.md pointing to it

2. **Query the live database** — Use the Supabase MCP tools to inspect current state:
   - `list_tables` with `verbose: true` to get all public tables with columns, types, constraints, PKs, and FKs
   - `execute_sql` to query `pg_policies` for all RLS policies on public tables
   - `execute_sql` to query `storage.buckets` for all storage buckets
   - `execute_sql` to query `pg_policies` for storage RLS policies
   - `execute_sql` to query `information_schema.triggers` for triggers on auth.users
   - `execute_sql` to query function definitions for any trigger functions

3. **Generate the Data Fields doc** — Write or update the doc with the following structure:

   ```markdown
   # {Project Name} Data Fields

   **Last Updated:** {today's date}

   All database tables, storage structure, and access control for the {project name} application.

   ---

   ## Design Principles
   {Keep existing principles if updating. If creating new, derive from observed patterns:
    e.g., RLS conventions, naming patterns, FK strategies, constraint choices}

   ---

   ## Table Overview
   {Summary table: name, rows per user, RLS enabled, notes}

   ---

   ## RLS Policy Summary
   {Matrix: table vs role vs operations}

   ---

   ## {Table Name}
   {For each table, document:
    - Description and relationship (1:1, 1:many, etc.)
    - Field table: Field, Type, Required, Default, Notes
    - Include FK references, check constraints, unique constraints
    - Note any triggers that affect this table}

   ---

   ## Storage: `{bucket_name}` Bucket
   {For each storage bucket:
    - Public/private status
    - Path structure with examples
    - Path segment descriptions
    - RLS policy summary
    - File restrictions (size limits, MIME types)}
   ```

4. **Preserve manual content** — When updating an existing doc:
   - Keep the Design Principles section intact (these are manually curated)
   - Keep any custom notes or documentation that doesn't contradict the current DB state
   - Remove documentation for tables/buckets that no longer exist
   - Add documentation for new tables/buckets
   - Update changed columns, types, constraints, and policies

5. **Commit the doc** — Determine where the doc lives:
   - If it's in a path under `docs/` and a docs repo is configured in project.md, commit to the docs repo
   - Otherwise commit to the current project repo
   - Commit message: "Update Data Fields doc from current database state"

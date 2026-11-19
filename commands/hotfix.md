---
description: "Plan hotfix and create a GitHub issue (branches from main, targets main)"
---

Plan a hotfix for the following production bug: $ARGUMENTS

This is a **hotfix** — use the following overrides instead of the `/bugfix` defaults:
- Base branch: `main` (not the project base branch)
- Branch prefix: `hotfix/`
- Labels: `bug`, `hotfix`
- Risk assessment: **required** — include in both the plan (step 6) and the issue body (step 7):
  ```
  ## Risk Assessment
  **Blast radius:** [what parts of the system this change touches]
  **Data impact:** [none | describe schema/storage/cache changes]
  **Rollback plan:** [git revert | manual steps needed]
  **User-facing impact:** [none | describe what users experience during deploy]
  **Migration risk:** [none | describe destructive or irreversible migration steps]
  **Confidence:** [Low | Medium | High]
  ```

**Migration handling:** If the hotfix includes database migrations, at the end of the `/execute` workflow (after the PR is created), output the migration SQL and the `INSERT INTO supabase_migrations.schema_migrations (version, name) VALUES (...)` tracking row statement so the user can apply them to production via SQL Editor.

Now follow the `/bugfix` workflow from step 0 (Clarity check) with these overrides applied.

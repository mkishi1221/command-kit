---
description: "Audit codebase against legal/compliance documents for gaps"
---

You are auditing the project codebase against its legal and compliance documents.

**Project settings:** Read `.claude/project.md` for project-specific configuration. Look for the `## Compliance` section which defines:
- **Legal Docs:** Paths to the legal documents to audit against
- **Checklist:** (optional) Path to a detailed compliance checklist with specific audit sections
- **Audit Output:** Path for the output file (also listed under `## Audit Output`)

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it. Do not describe what you would do or ask for permission - execute the step.**

**Process:**

1. **Read all legal documents listed in project.md** in full before starting the audit.

2. **Determine audit scope:**
   - **If a checklist file is configured:** Read it and use its sections as your audit guide. The checklist contains project-specific areas to audit, with references to specific legal clauses, database tables, and code paths.
   - **If no checklist is configured:** Systematically derive audit areas from the legal documents themselves. For each requirement or promise in the legal docs, check whether the codebase implements it.

3. **For each audit area**, report one of three statuses:
   - **COMPLIANT** ✅: The codebase already supports this requirement.
   - **GAP** ⚠️: The legal documents promise or require something the codebase does not yet implement.
   - **UNCLEAR** ❓: You cannot determine compliance without more information.

   Be specific. Reference file paths, database tables, and code where relevant. Do not flag things that are clearly outside the platform's current scope.

4. **Output format** — For each section, provide:
   1. **Status**: COMPLIANT / GAP / UNCLEAR
   2. **Evidence**: Specific files, tables, or code paths you examined
   3. **Finding**: What you found
   4. **Recommendation** (for GAPs only): What needs to change, with priority (HIGH / MEDIUM / LOW)

5. **Summary table** — At the end, provide a summary table of all gaps ordered by priority, and flag any items that should be resolved before launch.

6. **Be specific:**
   - Use actual file paths
   - Use actual column names and types
   - Reference line numbers for complex logic
   - Include actual database table and policy names

7. **Add metadata:**
   - "Last updated: [date]" at the top
   - Note at the top: "This is a living document. Run `/compliance-audit` to regenerate."

**If the file already exists:** Update it in place, preserving any changelog section and adding a new entry for this update.

**If the file doesn't exist:** Create it fresh.

8. **Commit and push changes:**
   - Pull latest changes: `git pull origin <current-branch>`
   - Stage the audit file
   - Commit with message: `"Update compliance audit: [brief summary of changes]"`
   - Push to current branch

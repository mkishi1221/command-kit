---
description: "Set up a new project with command-kit configuration"
---

You are setting up a new project to work with the command-kit workflow system. This command creates all necessary configuration files and directory structure.

**IMPORTANT: This workflow is interactive. Ask the user for information at each step before proceeding.**

**Prerequisites:** The `command-kit` repo must be cloned as a sibling directory to the project (e.g., `../command-kit/`). Verify this before starting.

---

## Step 1: Gather Project Information

Ask the user for the following. Show defaults in brackets where applicable:

**Required:**
- GitHub repo (owner/name, e.g., `AcmeCorp/my-app`)
- Default assignee (GitHub username)
- Base branch [`dev`] — the branch all feature branches are created from
- Brief project description (1 sentence — used for CLAUDE.md)

**Optional (ask which apply):**
- **Docs repo:** Does the project use a separate repo for planning docs and product specs? If yes, get the repo name and GitHub path. If no, docs will live in the main project.
- **Tech stack:** What libraries/frameworks does the project use? (Suggest common ones: Next.js, React, Tailwind, Supabase, etc. — get versions if known)
- **Design system:** Is there a design system doc? Path?
- **UI samples:** Is there a directory of reference screenshots/images? Path?
- **Type definitions:** Where do shared types live? (e.g., `types/`, `src/types/`)
- **Legal/compliance docs:** Are there legal documents to audit against? Paths?
- **Achievement tracking:** Does the project track achievements/progress? File prefix?

---

## Step 2: Create Directory Structure

Based on the answers, create the necessary directories. If a docs repo is used, create files there; otherwise create them in the main project.

**Always create in the main project:**
```
.claude/
```

**Create based on answers (in main project or docs repo):**
```
.claude/plans/
.claude/plans/scratch/
docs/                          # if no docs repo
docs/product/                  # if no docs repo
docs/achievements/             # if achievement tracking
```

---

## Step 3: Create `.claude/project.md`

Generate the project configuration file with all applicable sections. Use the template below, including only sections that are relevant based on the user's answers:

```markdown
# Project Configuration — {PROJECT_NAME}

## Repository

- **GitHub Repo:** {owner/name}
- **Default Assignee:** {username}
- **Base Branch:** {branch}
- **NEVER checkout, pull from, or push to `main`** — main is only updated via PR merges from {base_branch} in GitHub

## Paths

- **Type Definitions:** {path}
- **Prototypes:** prototype/src/pages/ — interactive JSX prototypes (authoritative visual+structural spec for UI features)
- **Plans Directory:** .claude/plans/
- **Sprint Plan:** .claude/plans/sprintplan.md
- **Scratchpad Directory:** .claude/plans/scratch/

## Docs Repo

{Only if using a separate docs repo}

Planning docs, product specs, and achievement tracking live in a separate repo:

- **Repo Name:** {name}
- **GitHub:** {owner/name}
- **Relative Path:** ../{name} (sibling directory)
- **Contains:** Product docs, plans, achievement tracking, rules, project config
- **Commit planning updates to this repo, not the main project repo**

When committing to {docs_repo}:
\`\`\`bash
git -C ../{docs_repo} add <files>
git -C ../{docs_repo} commit -m "Description"
git -C ../{docs_repo} push
\`\`\`

## Achievement Tracking

{Only if using achievement tracking}

- **Tracker Directory:** docs/achievements/
- **File Prefix:** {PREFIX} (produces {PREFIX}_Achievement_Tracker_Mar2026.md)

## Tech Stack

{Only if tech stack was provided}

When planning or implementing features, search official docs for best practices relevant to the task.

| Library | Version | What to check docs for |
|---|---|---|
{rows}

## Reference Documents

{Only if reference docs exist}

- **Data Fields:** {path} — SOURCE OF TRUTH FOR DATABASE
- **Progress Tracker:** {path}
- **Feature Spec:** {path}

## Audit Output

- **Codebase Audit:** {path, e.g., docs/product/{PREFIX}_Codebase_Audit.md or .claude/plans/codebase-audit.md}
- **Design Audit:** {path}

## Compliance

{Only if legal docs exist}

- **Legal Docs:** {comma-separated paths}
- **Checklist:** {path, if exists}
- **Audit Output:** {path}

## Product Documentation

{Only if product docs exist — list them}

## Issue Labels

- `feature` — New capability or functionality
- `enhancement` — Iteration or improvement to existing feature
- `bug` — Something isn't working as expected
- `planned` — Issue created with implementation plan
- `ready-to-implement` — Plan approved, ready for /execute
- `in-progress` — Currently being implemented
- `in-review` — PR created, awaiting review
- `blocked` — Implementation failed or is stuck

## Conventions

- **NEVER push to main** — main is only updated via PR merges from {base_branch}
- **NEVER use force push** (`git push --force` or `git push -f`)
- **Update PR descriptions BEFORE pushing** additional commits
- **No Claude Code footer or Co-Authored-By** in commit messages
- **Run targeted CI checks before pushing:** `npx tsc --noEmit`, `npm run lint`, `npx vitest run --changed origin/{base_branch}` — let the pre-push hook run the full test suite and CI run the build
```

---

## Step 4: Create `.claude/rules.md`

Generate project rules. Adapt the template based on the user's answers:

```markdown
# Project Rules and Conventions

## Important: Project Configuration

**Read `.claude/project.md` for project-specific settings** (GitHub repo, assignee, base branch, file paths, docs repo, etc.).

{If using docs repo:}
## Important: Planning Documentation Location

**The sprint plan and planning docs are in the docs repo specified in project.md ({docs_repo}), NOT in the main project repo.**

When updating planning docs after completing a feature:
- The sprint plan location is specified in project.md
- Find the docs repo as a sibling directory (path in project.md)
- Commit planning doc updates to the docs repo (not the main project repo)
{If using symlinks:}
- The files are symlinked from the main project, but the actual repo is the docs repo

## Git Workflow

### Branch Strategy
- **`{base_branch}` is the default base branch for all work** (see project.md)
- **NEVER checkout, pull from, or push to `main`** — main is only updated via PR merges from {base_branch}
- Always create feature branches from `{base_branch}`
- Always target `{base_branch}` when creating PRs

### Branch Protection
- **NEVER push directly to the `{base_branch}` or `main` branches**
- All changes must go through pull requests

### Git Hooks
- **NEVER use `--no-verify` flag with git commands**
- Git hooks (pre-commit, pre-push) are in place for quality control
- Bypassing hooks with `--no-verify` is strictly forbidden

### Pull Request Workflow

1. Checkout and update {base_branch}: `git checkout {base_branch} && git pull origin {base_branch}`
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes and commit them
4. Push to the feature branch: `git push -u origin feature/your-feature-name`
5. Create a PR targeting {base_branch}: `gh pr create --base {base_branch}`
6. Wait for CI to pass
7. Get approval and merge

### Updating PR Descriptions

**ALWAYS update the PR title and description BEFORE pushing additional changes.** When iterating on an existing PR:

1. Run tests to ensure they pass
2. Commit your changes
3. **Update the PR description** using `gh pr edit` to reflect ALL changes
4. Then push to remote

### Creating PRs with gh CLI

**IMPORTANT**: When creating PRs with `gh pr create`, avoid using backticks, code blocks, or complex markdown in the `--body` parameter.

**Instead:** Use plain text descriptions, replace backticks with quotes, keep the body simple.

### Commit Strategy
- **Create new commits instead of amending** when iterating on changes
- PRs are squash-merged, so multiple commits on a feature branch are fine
- **NEVER use `git commit --amend`**
- **NEVER use `git push --force` or `--force-with-lease`**

### Commit Messages
- Use descriptive commit messages
- Do NOT include the "Generated with Claude Code" footer
- Do NOT include Co-Authored-By lines

{If using SQL migrations:}
## SQL Migrations

### Naming Convention
- Use **sequential numbered naming**: `NNN_description_in_snake_case.sql`
- Zero-pad to 3 digits (e.g., `001`, `042`, `098`)
- Check the highest existing migration number and increment by 1
- **NEVER use timestamp-based naming**

## Code Quality

### Linting
- Run `npm run lint` before committing
- Fix all ESLint errors and warnings

### Testing
- Run `npm test` to ensure all tests pass
- Update tests when modifying components
- **Verify against real data when possible**

### TypeScript
- Run `npx tsc --noEmit` to check for type errors
- Fix all TypeScript errors before committing

{If using docs repo with symlinks:}
## Symlinked Files

The `.claude/plans/`, `.claude/commands/`, `.claude/project.md`, and `.claude/rules.md` are symlinked from external repos:

- `{project}/.claude/commands/` → `command-kit/commands/`
- `{project}/.claude/plans/` → `{docs_repo}/.claude/plans/`
- `{project}/.claude/project.md` → `{docs_repo}/.claude/project.md`
- `{project}/.claude/rules.md` → `{docs_repo}/.claude/rules.md`
{If docs directory is symlinked:}
- `{project}/docs/` → `{docs_repo}/docs/`

## Updating Planning Docs After Implementation

When completing a feature from the sprint plan:
1. Mark the task as complete with PR number and date in the sprint plan
2. Update relevant audit sections
3. Commit planning doc updates to {docs_repo} (not {project})
```

---

## Step 5: Create `CLAUDE.md`

Generate the project's CLAUDE.md in the project root:

```markdown
# Project Instructions for Claude Code

## CRITICAL: Execution Policy

**When a workflow or command says "do X", EXECUTE it. Do not describe what you would do or ask for permission - just do it.** The only exception is when a step explicitly says "STOP" or "wait for approval".

## CRITICAL: Project Configuration

**Read `.claude/project.md` for all project-specific settings** — GitHub repo, assignee, base branch, file paths, docs repo, labels, and conventions. All workflow commands reference this file.

## CRITICAL: Git Branch Policy

**The base branch for this project is `{base_branch}`, NOT `main`.**

- ALWAYS create feature branches from `{base_branch}`
- ALWAYS target `{base_branch}` when creating PRs: `gh pr create --base {base_branch}`
- ALWAYS pull from `{base_branch}`: `git pull origin {base_branch}`
- NEVER checkout, pull from, or push to `main`
- NEVER use force push (`git push --force` or `git push -f`)
- `main` is only updated via PR merges from `{base_branch}` in GitHub

When starting work on a new feature:
\`\`\`bash
git checkout {base_branch}
git pull origin {base_branch}
git checkout -b feature/your-feature-name
\`\`\`

See `.claude/rules.md` for complete project conventions.

{If using symlinks:}
## Symlinked Resources

This project uses two external repos via symlinks:

### command-kit (generic workflow commands)
- **Repo:** `command-kit` (sibling directory)
- **Provides:** `.claude/commands/` — reusable workflow commands
- Commands are project-agnostic; they read `.claude/project.md` for project-specific values

{If using docs repo:}
### {docs_repo} ({PROJECT_NAME}-specific docs and config)
- **GitHub repo:** {docs_repo_github}
- **Provides:**
  - `.claude/project.md` — project configuration
  - `.claude/rules.md` — project rules and conventions
  - `.claude/plans/` — planning docs (sprint plan, audits)
  - `docs/` — product docs, achievement tracking

When committing changes to symlinked files:
\`\`\`bash
# Commit to {docs_repo} (not {project})
git -C ../{docs_repo} add <files>
git -C ../{docs_repo} commit -m "Description"
git -C ../{docs_repo} push
\`\`\`

{If reference docs exist:}
## Product Documentation

Product docs in `docs/product/` define what to build. When implementing features, reference:

{list reference docs with descriptions}

## Implementation Workflow

When implementing features or fixes, ALWAYS follow the workflow defined in `.claude/commands/feature.md`. Key steps include:

1. Research codebase context thoroughly
2. Create a GitHub issue with detailed implementation plan (then STOP for approval)
3. After approval: ensure {base_branch} branch is up to date before creating feature branch
4. Implement changes with comprehensive tests
5. Verify against real data when applicable
6. Run tests and npm audit
7. Commit with detailed message (no Claude attribution)
8. **Update PR title and description to reflect all changes BEFORE pushing**
9. Push to remote
10. Update planning docs {in docs repo if applicable}

## CRITICAL: PR Description Updates

**ALWAYS update the PR title and description BEFORE pushing code.** When making additional changes to an existing PR:

1. Run tests to ensure they pass
2. Commit your changes
3. **Update the PR description** using `gh pr edit` to reflect ALL changes made
4. Then push to remote
```

---

## Step 6: Set Up Symlinks

Create symlinks to connect the project to command-kit (and optionally the docs repo):

```bash
# Always: link commands
ln -s ../../command-kit/commands .claude/commands

# If using docs repo with symlinks:
ln -s ../../{docs_repo}/.claude/plans .claude/plans
ln -s ../../{docs_repo}/.claude/project.md .claude/project.md
ln -s ../../{docs_repo}/.claude/rules.md .claude/rules.md
ln -s ../{docs_repo}/docs docs
```

**Important:** If using a docs repo, `project.md` and `rules.md` should be created in the docs repo (not the main project), then symlinked. Move them if they were created in the main project.

---

## Step 7: Create Initial Sprint Plan

Create a minimal sprint plan file at the configured sprint plan path:

```markdown
# {PROJECT_NAME} Sprint Plan

> Last updated: {date}

## Overview

{one-line project description}

---

## Sprint 1: {name} — TBC

<!-- Use /expand-sprint to fill in detailed tasks -->
```

---

## Step 8: Create GitHub Labels

Create the standard issue labels on the GitHub repo:

```bash
gh label create "planned" --description "Issue created with implementation plan" --color "0E8A16" --repo {owner/name} --force
gh label create "ready-to-implement" --description "Plan approved, ready for /execute" --color "1D76DB" --force --repo {owner/name}
gh label create "in-progress" --description "Currently being implemented" --color "FBCA04" --force --repo {owner/name}
gh label create "in-review" --description "PR created, awaiting review" --color "D93F0B" --force --repo {owner/name}
gh label create "blocked" --description "Implementation failed or is stuck" --color "B60205" --force --repo {owner/name}
gh label create "feature" --description "New capability or functionality" --color "A2EEEF" --force --repo {owner/name}
gh label create "enhancement" --description "Improvement to existing feature" --color "7057FF" --force --repo {owner/name}
gh label create "bug" --description "Something isn't working as expected" --color "D73A4A" --force --repo {owner/name}
```

---

## Step 9: Summary

After completing all steps, show the user a summary:

1. Files created (with paths)
2. Symlinks established
3. Labels created
4. Available commands (list all `/command` names with one-line descriptions)
5. Suggested next steps:
   - Run `/audit` to generate an initial codebase audit
   - Run `/plan` to create a strategic plan
   - Run `/feature` to start implementing a feature

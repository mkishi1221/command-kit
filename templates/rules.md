# Project Rules and Conventions

## Important: Project Configuration

**Read `.claude/project.md` for project-specific settings** (GitHub repo, assignee, base branch, file paths, etc.).

## Git Workflow

### Branch Strategy

- **Check project.md for the base branch** (default: main)
- Always create feature branches from the base branch
- Always target the base branch when creating PRs

### Branch Protection

- **NEVER push directly to protected branches** (base branch, main, etc.)
- All changes must go through pull requests
- Git hooks (pre-commit, pre-push) are in place for quality control

### Git Hooks

- **NEVER use `--no-verify` flag with git commands**
- Git hooks run linters, tests, and enforce branch protection
- Bypassing hooks with `--no-verify` is strictly forbidden

### Pull Request Workflow

1. Checkout and update the base branch
2. Create a feature branch from the base branch
3. Make your changes and commit them
4. Push to the feature branch
5. Create a PR targeting the base branch
6. Wait for CI to pass
7. Get approval and merge

### Updating PR Descriptions

**ALWAYS update the PR title and description BEFORE pushing additional changes.** When iterating on an existing PR:

1. Run tests to ensure they pass
2. Commit your changes
3. **Update the PR description** using `gh pr edit` to reflect ALL changes made
4. Then push to remote

### Creating PRs with gh CLI

**IMPORTANT**: When creating PRs with `gh pr create`, avoid using backticks, code blocks, or complex markdown in the `--body` parameter. These cause shell escaping issues.

**Instead:**
- Use plain text descriptions
- Replace backticks with quotes or just remove formatting
- Keep the body simple and readable without code formatting

### Commit Strategy

- **Create new commits instead of amending** when iterating on changes
- PRs are squash-merged, so multiple commits on a feature branch are fine
- **NEVER use `git commit --amend`** - just create a new commit
- **NEVER use `git push --force` or `--force-with-lease`**

### Commit Messages

- Use descriptive commit messages
- Do NOT include the "Generated with Claude Code" footer
- Do NOT include Co-Authored-By lines
- Keep commit messages clean and professional

## Code Quality

### Linting

- Run the project's lint command before committing
- Fix all linting errors and warnings

### Testing

- Run the project's test suite to ensure all tests pass
- Update tests when modifying components
- Maintain test coverage
- **Verify against real data when possible**: When fixing data-related issues, don't just update mocks. Test against actual data/APIs to confirm the fix works.

### Type Checking

- Run the project's type checker before committing
- Fix all type errors before committing

## Planning Documentation

### Key Planning Documents

| Document | Location | Purpose |
|----------|----------|---------|
| `codebase-audit.md` | Plans directory | Technical audit of current codebase state |
| `sprintplan.md` | Plans directory | Execution sprint plan with task tracking |

### Updating Planning Docs After Implementation

When completing a feature from the sprint plan:

1. Mark the task as complete with PR number and date in the sprint plan
2. Update relevant sections in the codebase audit
3. Commit the planning doc updates to the appropriate repo (docs repo if configured in project.md, otherwise this repo)

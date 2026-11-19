# Getting started

This guide takes you from a fresh clone to running your first command in a project.

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed.
- The [GitHub CLI](https://cli.github.com/) (`gh`), authenticated: `gh auth login`. Most commands create or read GitHub issues and PRs.
- A git repository for the project you want to use the commands in.

## 1. Clone the kit

Clone command-kit next to your projects, so it can be referenced as a sibling directory:

```bash
git clone https://github.com/<your-username>/command-kit.git
```

## 2. Install into a project

From the kit, run the installer against your project:

```bash
cd my-project
../command-kit/install.sh .
```

The installer:

- Symlinks `commands/` into your project's `.claude/commands/`, so every command is available as a slash command.
- Seeds three config files if they do not already exist: `.claude/project.md`, `.claude/rules.md`, and `.claude/plans/sprintplan.md`. Existing files are never overwritten.

Add the symlink to your project's `.gitignore`:

```
.claude/commands
```

Whether you commit `.claude/project.md` and `.claude/rules.md` is up to you. If they describe a shared project, commit them so your team shares one config.

## 3. Configure the project

Every command reads `.claude/project.md` at runtime to get project-specific values. Open it and fill in at least:

- **GitHub repo** (`owner/name`) and the **default assignee** for issues.
- **Base branch** the commands branch from and target in PRs (for example `main`, or `dev` if you ship through a dev branch).
- **Paths** for scratch space and, if you use one, a separate docs repo.
- Any **labels** you want applied to issues the commands open.

Because the commands read this file instead of hardcoding anything, the same command behaves correctly across every project you install it in. To change behavior project-wide, edit this one file.

Then review `.claude/rules.md`, which holds your git workflow and code-quality conventions. The commands follow these rules, so put your branch policy, commit style, and test expectations here.

## 4. Run your first command

In Claude Code, plan a change:

```
/feature Add a saved-search button to the results page
```

`/feature` researches the codebase, writes an implementation plan, and opens a GitHub issue. It then stops so you can read and approve the plan on GitHub. When you are happy with it:

```
/execute 42
```

`/execute` implements issue #42 end-to-end: it branches, writes the code and tests, commits, and opens a PR.

For the full path from idea to merged PR, follow [the walkthrough](walkthrough.md). For every command's "when to use" and output, see the [command reference](command-reference.md).

## Optional: a separate docs repo

If your planning docs (roadmap, sprint plan, product specs) live in their own repository, set the docs-repo fields in `.claude/project.md`. Commands that update planning docs will commit to that repo instead of your main project. Leave it unset to keep docs in the main project.

## Guardrails

This repo protects itself with a content denylist so personal or internal strings are never committed. It is built from three files in [.githooks/](../.githooks/):

- `denylist.txt` holds the blocked words, one per line. Comments (`#`) and blank lines are ignored.
- `pre-commit` scans the lines a commit **adds** and blocks the commit if any match.
- `pre-push` scans **all tracked content** as a backstop, in case a commit slipped through with `--no-verify`.

A matching Claude Code hook in [.claude/settings.json](../.claude/settings.json) runs on every `Write`/`Edit` and denies the tool call before denylisted content reaches disk, giving you the feedback in-session.

Two design choices make it safe to run anywhere:

- It scans file **content only**, never file paths or the git remote URL. A repo can live under a path (or belong to an account) whose name matches a denied word without tripping the guard.
- It scans only **new** content on edits, so an edit that removes a denied word is never blocked.

### Reuse it in your own repo

1. Copy the `.githooks/` directory into your repo.
2. Edit `.githooks/denylist.txt` with the words you want blocked.
3. Turn the git hooks on (this is local config, so each clone runs it once):
   ```bash
   git config core.hooksPath .githooks
   ```
4. To get the in-session Claude Code warning too, copy the `PreToolUse` hook from `.claude/settings.json`.

## Troubleshooting

- **A command does not appear as a slash command.** Confirm `.claude/commands` is a symlink pointing into the kit: `ls -l .claude/commands`. Re-run the installer if needed.
- **A command cannot find your repo or branch.** It is reading `.claude/project.md`. Make sure the GitHub repo and base branch are filled in.
- **`gh` errors.** Run `gh auth status` and authenticate if needed.
- **The git hooks are not firing after cloning.** They are local config. Run `git config core.hooksPath .githooks` once in the clone.

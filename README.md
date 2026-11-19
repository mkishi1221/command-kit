# command-kit

A set of Claude Code slash commands for spec-driven software development: plan a change, build it, review it, and ship it, each as one command with a consistent workflow.

The commands are plain markdown prompts. They stay project-agnostic by reading one config file (`.claude/project.md`) at runtime, so the same command works across projects with different repos, branches, and conventions.

## The loop

command-kit is built around one loop you repeat per change:

```
/feature  "Add saved search"   ->  plans the work, opens a GitHub issue, stops for your review
/execute  42                   ->  implements issue #42: branch, code, tests, commit, PR
/review   42                   ->  reviews the PR for bugs, security, duplication, performance
/address-review                ->  fixes the findings, updates the PR, pushes
/release                       ->  opens the release PR when a batch is ready
```

Planning and shipping are separate commands on purpose: you read and approve the plan on GitHub before any code is written.

## Quick start

1. Clone the kit next to your projects:
   ```bash
   git clone https://github.com/<your-username>/command-kit.git
   ```
2. Install it into a project:
   ```bash
   cd my-project
   ../command-kit/install.sh .
   ```
   This symlinks the commands into `.claude/commands/` and seeds `.claude/project.md`, `.claude/rules.md`, and `.claude/plans/sprintplan.md`.
3. Fill in `.claude/project.md` with your GitHub repo, base branch, and paths.
4. In Claude Code, run `/feature` to plan your first change.

See [docs/getting-started.md](docs/getting-started.md) for full setup, and [docs/walkthrough.md](docs/walkthrough.md) for a worked example from idea to merged PR.

## Commands

### Plan
| Command | What it does |
|---------|--------------|
| `/feature` | Plan a feature and open a GitHub issue with an implementation spec |
| `/enhancement` | Plan an enhancement and open issues with an implementation spec |
| `/bugfix` | Plan a bug fix and open an issue with root-cause analysis |
| `/hotfix` | Plan a hotfix that branches from and targets your release branch |
| `/plan` | Turn a large vision into a strategic plan, broken into features |
| `/plan-batch` | Open issues with detailed plans for several features at once |
| `/refine-issue` | Refine an issue's plan based on comments and discussion |

### Build and ship
| Command | What it does |
|---------|--------------|
| `/execute` | Implement an issue end-to-end: branch, code, tests, commit, PR |
| `/resume` | Resume `/execute` from wherever it left off |
| `/iterate` | Iterate on code with no tests, commits, or pushing |
| `/drop-iterate` | End an `/iterate` session and clear its constraints |
| `/review` | Review a PR for security, error handling, duplication, performance |
| `/address-review` | Fix `/review` findings, update the PR, and push |
| `/teardown` | Abandon a PR: roll back state, remove the branch, reopen the issue |
| `/release` | Open a release PR from your working branch into your release branch |
| `/sync-hotfixes` | Pull hotfixes from the release branch back into the working branch |
| `/sentry-hotfixes` | Turn a Sentry error report into prioritized hotfix issues (assumes Sentry) |

### Database
| Command | What it does |
|---------|--------------|
| `/data-fields` | Generate a data-fields doc from the live database (assumes Supabase) |
| `/db-audit` | Compare two environments and report schema divergence (assumes Supabase) |

### Review and audit
| Command | What it does |
|---------|--------------|
| `/audit` | Generate or update a comprehensive codebase audit document |
| `/design-audit` | Audit design tokens: color, type, spacing, borders, consistency |
| `/performance-audit` | Audit real and perceived performance across the app |
| `/security-audit` | Audit endpoint protection, bot defenses, and cost-exposure vectors |
| `/login-audit` | Audit login flows, session security, and auth config |
| `/wcag-audit` | Audit against WCAG AA: contrast, semantics, labels, focus, color |
| `/compliance-audit` | Audit the codebase against legal and compliance documents |
| `/microcopy-audit` | Audit UI microcopy for ambiguity and inconsistent terms |

### Sprints and docs
| Command | What it does |
|---------|--------------|
| `/plan` | Create the high-level roadmap for a large vision |
| `/add-sprint` | Add a sprint to the sprint plan from a roadmap phase |
| `/expand-sprint` | Expand a sprint into detailed implementation tasks |
| `/update-progress` | Update roadmap and progress docs to reflect completed work |
| `/achievement` | Update a running achievement tracker from your merged work |
| `/setup` | Set up a new project with command-kit configuration |

Full reference with "when to use" and examples: [docs/command-reference.md](docs/command-reference.md).

## Tracking your work

`/achievement` keeps a running log of what you shipped, assembled from your merged PRs, closed issues, and commits. It is the one command here that is not about building the product. It is about building the record of your work.

That record is worth keeping. When it is time for a review, a raise, a promotion, or a new role, the hard part is remembering what you actually did months ago. A tracker that updates itself as you ship means you always have the specifics on hand: what you built, when, and why it mattered, in your own words rather than reconstructed under pressure.

Run it whenever you finish a chunk of work. It backfills any days it missed:

```
/achievement
```

## How it works

- Each command is a markdown file in [commands/](commands/). Claude Code loads it as the prompt for that slash command.
- Commands never hardcode project specifics. They read `.claude/project.md` for your repo, branch, paths, and labels. Edit that one file and every command adapts.
- `.claude/rules.md` holds your git and code conventions; the commands follow them.

## Origin stack

These commands were built and used on a specific stack: Next.js, TypeScript, and Tailwind on the front end; Supabase for database, auth, and migrations; Vercel for hosting; Sentry for error tracking; and GitHub for issues and PRs.

Where a command names one of these, treat it as an example, not a requirement. Database steps are marked "for Supabase projects," the error-tracking step is conditional, and anything stack-specific is called out so you can swap in your equivalent. The planning, review, and git workflow are stack-agnostic.

### Stack-coupled commands

A few commands lean on a specific vendor and say so in a **Stack note** at the top. They assume:

- **Supabase:** `/data-fields` and `/db-audit` (the whole command), plus the migration steps in `/teardown` and `/release` and the auth checks in `/login-audit`
- **Sentry:** `/sentry-hotfixes`

If you use a different stack, open the command and ask Claude Code to adapt the marked steps to your tools. The planning, review, and git flow around them does not change.

## Guardrails (and a reusable hook example)

This repo ships a small content guardrail that blocks a denylist of words from being committed, so personal or internal strings never leak into a public repo. It has two layers:

- Git hooks in [.githooks/](.githooks/) (`pre-commit` + `pre-push`) scan staged and tracked content.
- A Claude Code `PreToolUse` hook in [.claude/settings.json](.claude/settings.json) warns in-session before a `Write`/`Edit` lands.

Both read the word list from `.githooks/denylist.txt` and scan file **content only**, never file paths, so a repo can live under a path (or belong to an account) whose name matches a denied word. To reuse it in your own repo, edit the denylist and run:

```bash
git config core.hooksPath .githooks
```

It doubles as a working example of a guardrail hook you can teach or adapt. See [docs/getting-started.md](docs/getting-started.md#guardrails) for how each layer works.

## License

MIT. See [LICENSE](LICENSE).

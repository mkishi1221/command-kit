---
description: "Update the achievement tracker with today's progress and commit (before 4am = previous day)"
---

Update the achievement tracker: $ARGUMENTS

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, file prefix, tracker directory, docs repo path, etc.) before executing. Use those values throughout this workflow.

**IMPORTANT: This workflow requires EXECUTION, not description. When a step says "do X", actually do it. Do not describe what you would do or ask for permission - execute the step.**

## 1. Prepare Scratch Directory

```bash
SCRATCH="/tmp/achievement-$(date +%s)"
mkdir -p "$SCRATCH"
```

Save the `$SCRATCH` path for use in agent prompts and cleanup.

## 2. Run the Scout Agent (foreground)

Launch a single Agent with this prompt (substitute `$SCRATCH` with the actual path):

> You are scanning a project to determine which dates need achievement tracker entries.
>
> Do the following and write results to `$SCRATCH/scout.md`:
>
> 1. Read `.claude/project.md` for project-specific configuration (GitHub repo, file prefix, tracker directory, docs repo path, etc.)
> 2. **Determine the effective date:**
>    - Check the current time
>    - Before 4:00 AM → use yesterday's date
>    - 4:00 AM or later → use today's date
> 3. **Find and read the tracker file:**
>    - Trackers are in the tracker directory from project.md
>    - File naming: `{FilePrefix}_Achievement_Tracker_{Month}{Year}.md` (file prefix from project.md)
>    - If a docs repo is configured, trackers live there
>    - If no tracker exists for the effective month, note this and find the previous month's tracker to use as a template
> 4. **Find the last recorded date** by scanning for the most recent day entry heading (e.g., `### Day N · Build Day M: ...`)
>    - Record the last Day number, Build Day number, and calendar date
> 5. **Identify all dates needing entries:**
>    - Check every calendar day from the day after the last recorded date through the effective date
>    - For each date, run: `gh pr list --state merged --search "merged:{date}" --json number,title --limit 100`
>    - And: `gh issue list --state closed --search "closed:>={date}" --search "closed:<={date}" --json number,title --limit 100`
>    - And: `git log --oneline --since="{date} 04:00" --until="{next_date} 04:00"`
>    - A date needs an entry if it has any PRs, issues, or commits
>    - List all dates that need entries (skip dates with zero activity)
> 6. **Write to `$SCRATCH/scout.md`:**
>    - Effective date
>    - Tracker file path
>    - Whether a new tracker file needs to be created (and template path if so)
>    - Last Day number, Build Day number, and date
>    - List of dates needing entries with their quick activity summary (PR count, issue count, commit count)
>    - Current Week number from tracker (for week grouping)
>    - The full path to the docs repo (if configured)
>    - The GitHub repo identifier (owner/repo)
>
> After writing the file, respond only with "Done".

## 3. Launch Data Gathering Agents in Parallel (background)

After the scout completes, launch ALL of the following agents in a **single message** with `run_in_background: true`. Each agent writes its output to `$SCRATCH/<key>.md`. Substitute `$SCRATCH` with the actual path in every prompt.

**CRITICAL: All agents must be launched in a single message so they run concurrently. Do not launch them one at a time.**

**a. `main-repo`** — Gather main repo activity for all dates needing entries:

> You are gathering detailed achievement data from the main project repo.
>
> Read `$SCRATCH/scout.md` for the list of dates needing entries, the GitHub repo identifier, and the time windows.
>
> For each date listed as needing an entry, gather:
>
> 1. **Git commits:** `git log --oneline --since="{date} 04:00" --until="{next_date} 04:00"`
> 2. **Merged PRs:** `gh pr list --state merged --search "merged:{date}" --json number,title,body --limit 100`
>    - For each PR, note the PR number and a brief one-line description
> 3. **Closed issues:** `gh issue list --state closed --search "closed:>={date}" --search "closed:<={date}" --json number,title --limit 100`
>    - For each issue, note the issue number and title
>
> Write to `$SCRATCH/main-repo.md` with this format for each date:
> ```
> ## {YYYY-MM-DD}
> ### Commits
> {list of commits}
> ### PRs Merged
> {list with PR numbers and descriptions}
> ### Issues Closed
> {list with issue numbers and titles}
> ```
>
> After writing the file, respond only with "Done".

**b. `docs-repo`** — Gather docs repo activity (skip this agent if no docs repo is configured in scout.md):

> You are gathering achievement data from the docs/foundation repo.
>
> Read `$SCRATCH/scout.md` for the list of dates needing entries and the docs repo path.
>
> If no docs repo is configured, write "No docs repo configured" to `$SCRATCH/docs-repo.md` and stop.
>
> For each date listed as needing an entry, gather git commits from the docs repo:
> - `git -C {docs_repo_path} log --oneline --since="{date} 04:00" --until="{next_date} 04:00"`
>
> **Categorize each commit** into one of these types:
> - **Sprint Plan updates:** PR tracking, sprint progress, issue numbering
> - **Planning docs:** Data fields, schema docs, product specs
> - **Workflow improvements:** Command files, automation changes
> - **Achievement tracking:** Tracker setup, format improvements
> - **Doc cleanup:** Consolidations, removals, renames
> - **Other:** Anything that doesn't fit above
>
> Write to `$SCRATCH/docs-repo.md` with this format for each date:
> ```
> ## {YYYY-MM-DD}
> ### Sprint Plan updates
> {commits}
> ### Planning docs
> {commits}
> ### Workflow improvements
> {commits}
> ### Achievement tracking
> {commits}
> ### Doc cleanup
> {commits}
> ```
>
> Omit empty categories. After writing the file, respond only with "Done".

**c. `tracker-state`** — Analyze current tracker state for section updates:

> You are analyzing the current state of the achievement tracker to prepare section updates.
>
> Read `$SCRATCH/scout.md` for the tracker file path.
> Read the full tracker file.
>
> Extract and write to `$SCRATCH/tracker-state.md`:
>
> 1. **Current Progress Summary section** (verbatim)
> 2. **Current Goals table** (verbatim)
> 3. **Current Comms Log** (verbatim, if exists)
> 4. **Current Blockers & Decisions** (verbatim, if exists)
> 5. **The full existing tracker content** (so the assembly step can reconstruct the file)
> 6. **Template info:** If a new tracker file is needed, read the template tracker and include its full content
>
> After writing the file, respond only with "Done".

## 4. Wait for All Agents and Verify

Wait for all background agents to complete, then verify all section files exist:

```bash
for f in $SCRATCH/{scout,main-repo,docs-repo,tracker-state}.md; do
  if [ -f "$f" ]; then echo "OK: $(basename $f)"; else echo "MISSING: $(basename $f)"; fi
done
```

If any files are missing after all agents have completed, re-launch agents for just the missing sections.

## 5. Assemble and Update the Tracker

Read all files from `$SCRATCH/` and assemble the updated tracker.

For each date needing an entry (from scout.md), create a day entry using data from main-repo.md and docs-repo.md:

- **Increment Day and Build Day counters** from the last recorded values (only days with actual work get numbered)
- **Week grouping:** When a date starts a new ISO week, add a new `## Week N` heading

Each day entry should include:
- **Focus:** Brief description of the main focus area (derive from PRs and commits)
- **PRs merged:** List any PRs with PR numbers and brief descriptions
- **Issues closed:** List any issues resolved
- **Key accomplishments:** Bullet points of significant work completed
- **Documentation & Planning:** Detail all docs repo work with specific bullet points (if applicable)
- **Work in progress:** Items started but not yet complete

**If $ARGUMENTS is provided**, include that as additional non-engineering work (calls, strategy, planning, meetings, etc.) alongside the automated engineering summary. Apply arguments only to the effective date's entry, not to backfilled dates.

Also update (using tracker-state.md as the baseline):
- **Progress Summary** section (PR count, test count if changed)
- **Goals** table (update status emojis: ⬜ pending, 🔄 in progress, ✅ complete)
- **Comms Log** if any communications occurred
- **Blockers & Decisions** if relevant
- **"Tracker last updated"** timestamp at the bottom

Write the updated tracker file.

## 6. Clean Up Scratch Files

```bash
rm -rf $SCRATCH
```

## 7. Commit and Push

Determine which repo contains the tracker (docs repo if configured, otherwise current repo), then:

1. Ensure you're on the appropriate branch
2. Pull latest changes: `git -C {repo_path} pull origin {current-branch}`
3. Stage the tracker file
4. Commit with message: `"Update achievement tracker ({effective_date}): {brief summary}"`
5. Push to remote

## Format Guidelines

- Keep entries concise but informative
- Use PR numbers with # prefix (e.g., PR #142)
- Use issue numbers with # prefix (e.g., closes #93)
- Use consistent emoji for status: ⬜ (pending), 🔄 (in progress), ✅ (complete)
- Maintain the established markdown structure
- Always update the "Tracker last updated" timestamp
- **Day/Build Day numbering:** Only increment for days with actual work - days off (no PRs, no commits) are skipped entirely, they don't get entries or consume Day numbers

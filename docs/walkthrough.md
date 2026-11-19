# Walkthrough: idea to merged PR

This is the full loop on one small feature, so you can see where each command hands off to the next and where you stay in control. The example feature is a "saved search" button on a results page. Substitute your own.

The shape of the loop is always the same:

```
plan  ->  review the plan  ->  build  ->  review the PR  ->  address findings  ->  merge  ->  release
```

## 0. Setup (once per project)

Install the kit and fill in `.claude/project.md` (see [getting-started](getting-started.md)). The key field for this walkthrough is the base branch the commands branch from and target.

## 1. Plan the change

```
/feature Add a saved-search button to the results page
```

`/feature` researches the relevant code, then writes an implementation plan and opens a GitHub issue with it. It **stops** there. Nothing has been built, and no branch exists yet.

This stop is the point of separating planning from building: the plan is on GitHub where you can read it, comment, or hand it to a teammate.

## 2. Review and refine the plan

Open the issue. Read the plan the way you would review a PR: Does it touch the right files? Does it miss a case? Is it the right size?

- If it is good, move on.
- If it needs changes, comment on the issue and run:
  ```
  /refine-issue 42
  ```
  This folds your comments back into the plan. Repeat until the plan is right.

You now have an approved spec in issue #42.

## 3. Build it

```
/execute 42
```

`/execute` implements the approved plan end-to-end:

1. Branches from your base branch.
2. Writes the code and the tests.
3. Runs the local checks.
4. Commits.
5. Opens a PR that links back to issue #42.

If a run is interrupted, `/resume` continues from where it stopped instead of starting over.

If you want to try something exploratory mid-build without the full workflow, `/iterate` makes fast edits with no commits or pushes, and `/drop-iterate` returns you to the normal flow.

## 4. Review the PR

```
/review 42
```

`/review` reads the PR and reports findings grouped by category: security, error handling, duplication, and performance. You get a concrete list, not a "looks good."

## 5. Address the findings

```
/address-review
```

This applies the review's findings: it makes the fixes, runs tests, updates the PR description to reflect the changes, and pushes. Run `/review` again if you want a second pass.

## 6. Merge

Merge the PR on GitHub the way you normally would. The issue closes via the PR link.

If the change turns out to be wrong and you want to abandon it instead of merging:

```
/teardown 42
```

That reverses everything the loop set up: it removes the branch and PR, rolls back any dev-only migrations, and reopens the issue, leaving you back on a clean base branch.

## 7. Release

When a batch of merged work is ready to promote:

```
/release
```

`/release` opens a release PR into your release target with an inventory of what is shipping. If hotfixes landed directly on the release branch, `/sync-hotfixes` brings them back so your branches do not drift.

## Where this scales

The same loop runs several features in parallel: `/plan-batch` opens issues for a whole list at once, and each one flows through `/execute -> /review -> /address-review` independently. For larger efforts, `/plan` decomposes a vision into features first, and the sprint commands (`/add-sprint`, `/expand-sprint`, `/update-progress`) keep the plan and progress docs in sync as work ships.

## The one habit that makes it work

Read the plan before you run `/execute`. The kit deliberately puts a reviewable spec between the idea and the code. That review is where you catch a wrong approach while it is still one comment to fix, instead of a whole PR to redo.

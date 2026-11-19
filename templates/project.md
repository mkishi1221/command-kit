# Project Configuration

This file provides project-specific settings to the command-kit workflow.
Commands read this file to know your GitHub repo, assignee, branch conventions, etc.

## Repository

- **GitHub Repo:** OWNER/REPO
- **Default Assignee:** username
- **Base Branch:** main

## Paths

- **UI Samples:** (e.g., docs/ui-samples/)
- **Type Definitions:** (e.g., types/ or src/types/)
- **Plans Directory:** .claude/plans/
- **Sprint Plan:** .claude/plans/sprintplan.md

## Docs Repo (optional)

If your planning docs, product specs, and/or sprint plan live in a separate repo:

- **Repo Name:** (e.g., my-project-docs)
- **Relative Path:** (e.g., ../my-project-docs — sibling directory)
- **What it contains:** (e.g., plans, product docs, achievement tracking)
- **Commit planning updates to this repo, not the main project repo**

Leave this section blank if everything lives in the same repo.

## Achievement Tracking

- **Tracker Directory:** docs/achievements/
- **File Prefix:** MyProject (produces MyProject_Achievement_Tracker_Jan2026.md)

## Audit Output

- **Codebase Audit:** (e.g., docs/product/MyProject_Codebase_Audit.md)
- **Design Audit:** (e.g., docs/product/MyProject_Design_Audit.md)

## Reference Documents (for sprint plan expansion)

List the documents that `/expand-sprint` should consult:

- **Data Fields / Schema:** (e.g., docs/product/Data_Fields.md)
- **Progress Tracker / Requirements:** (e.g., docs/product/Progress_Tracker.md)
- **Feature Spec:** (e.g., docs/product/Feature_Spec.md)

## Issue Labels

- `feature` - New capability or functionality
- `enhancement` - Improvement to an existing feature
- `bug` - Something isn't working as expected
- `planned` - Issue created with implementation plan
- `ready-to-implement` - Plan approved, ready for /execute

## Conventions

Add any project-specific conventions here:

- (e.g., "Update PR descriptions BEFORE pushing additional commits")
- (e.g., "Never force push")
- (e.g., "No Claude Code footer or Co-Authored-By in commits")

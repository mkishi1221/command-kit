---
description: "Create a strategic plan for a large vision, breaking it into features"
---

Create a comprehensive strategic plan for: $ARGUMENTS

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, assignee, base branch, file paths, docs repo, etc.) before executing. Use those values throughout this workflow.

**Clarity check:** Before researching anything, check the vision described in $ARGUMENTS for open decisions — multiple reasonable interpretations of what the vision covers, or architecture/approach decisions not dictated by the request (e.g., how to structure a new system, which of several viable technical directions to take). Do NOT ask about implementation details that follow existing codebase convention. If any open decisions exist, ask via `AskUserQuestion` before doing any research. If the vision is unambiguous, proceed.

Follow this approach:

1. **Research the current codebase** to understand:
   - Existing architecture and patterns
   - Related functionality already in place
   - Technical constraints and dependencies
   - Testing infrastructure and patterns
   - Existing prototypes in `prototype/src/pages/` for visual+structural context

2. **Research best practices** — Check official docs for the key technologies this vision involves:
   - Read the **Tech Stack** table in project.md to identify which libraries are relevant
   - For each relevant library, search its official documentation for current best practices:
     - For Supabase projects, use the Supabase MCP `search_docs` tool for backend topics (auth, RLS, storage, edge functions, realtime, SSR)
     - Use web search for other libraries (Next.js, React, Tailwind, the project's component library from the Tech Stack table, Mux, dnd-kit, etc.)
   - Focus on architectural patterns, recommended approaches, and known pitfalls for the planned scope
   - Note findings that should inform the plan's technical decisions
   - If no Tech Stack table exists in project.md, skip this step

3. **Save research context** — If a **Scratchpad Directory** is configured in project.md, write a research context file to preserve findings across context compaction:
   - Filename: `{scratchpad-dir}/{vision-slug}.md` (e.g., `scratch/creator-onboarding.md`)
   - Include:
     - **Key files and their roles** — file paths discovered during research and what they do
     - **Architecture notes** — how existing systems are structured, dependencies between modules
     - **Existing patterns** — conventions, utilities, hooks found across the codebase
     - **Best practice findings** — recommendations from official docs, deprecations, security notes
     - **Technical constraints** — limitations, performance concerns, external dependencies
   - This file survives context compaction and can be re-read later during planning
   - If no Scratchpad Directory is configured, skip this step

4. **Analyze the vision** and break it down into:
   - Core features required
   - Dependencies between features
   - Logical implementation order
   - Technical challenges and considerations

5. **Create a strategic plan document** in the plans directory (from project.md) named `[vision-name].md`:
   - **NOTE**: If a docs repo is configured in project.md, create the plan there
   - **Vision Overview**: High-level description of the goal
   - **Technical Analysis**: Architecture considerations, dependencies, constraints
   - **Feature Breakdown**: List of individual features with:
     - Feature description (formatted as a `/feature` command)
     - Dependencies (what must be done first)
     - Estimated complexity by PR line-change count: S <500 (ideal) · M 500–800 (acceptable, add justification) · L 801–1000 · XL >1000 — L/XL must be split
     - Key technical considerations
   - **Implementation Phases**: Group features into logical sprints/phases
   - **Testing Strategy**: Overall approach to testing across features
   - **Success Criteria**: How to measure completion

6. **Present the plan** for review and refinement before creating the document. Before presenting, audit it against the original request and any clarity-check answers: every decision — architecture choice, added mechanism, a "while we're at it" addition — must be either explicitly stated by the user or the only reasonable way to satisfy something they explicitly asked for. Anything else must not be presented as settled; ask about it via `AskUserQuestion` first, isolated from the rest of the plan.

7. **Keep the plan updated**: The plan file should be treated as a living document that gets updated as:
   - Features are completed (mark with ✓)
   - New insights are discovered
   - Priorities change
   - Technical decisions are made

**Output Format Example:**
```markdown
# Vision: [Name]

## Overview
[Description of the overall goal]

## Phase 1: Foundation
- [ ] `/feature implement user authentication system` (Dependencies: none, Complexity: ~1200 lines → XL — split before building)

## Phase 2: Core Features
- [ ] `/feature add profile editing with database schema` (Dependencies: Phase 1, Complexity: ~620 lines → M — includes migration)
...

## Technical Notes
[Architecture decisions, patterns to follow, etc.]
```

This command does NOT write code - it only creates/updates the strategic plan document.

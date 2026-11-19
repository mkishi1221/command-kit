---
description: "Refine a GitHub issue's implementation plan based on comments and discussion"
---

Refine the implementation plan for GitHub issue: $ARGUMENTS

**Project settings:** Read `.claude/project.md` for project-specific configuration (GitHub repo, assignee, base branch, file paths, etc.) before executing. Use those values throughout this workflow.

Follow this workflow:

1. Fetch the issue using: `gh issue view $ISSUE_NUMBER --json number,title,body,comments --jq '.comments[] | "**@\(.author.login)** (\(.createdAt)):\n\(.body)\n"'` to get all comments
2. Also fetch the issue body: `gh issue view $ISSUE_NUMBER`
3. Read and analyze:
   - The original implementation plan (issue body)
   - All comments and discussions on the issue
   - Identify requested changes, concerns, or suggestions
4. Have a conversation with the user HERE to discuss:
   - What changes they want to make based on the comments
   - Any clarifications needed
   - Trade-offs or alternative approaches
   - Whether the scope should expand or contract
5. Once the user approves the refined plan, update the GitHub issue:
   - Update the issue body with the refined implementation plan
   - Use: `gh issue edit $ISSUE_NUMBER --body "..."`
   - Post a comment summarizing what was refined
   - Use: `gh issue comment $ISSUE_NUMBER --body "**Plan refined:**\n- Summary of changes\n- What was added/removed/modified"`
6. If the plan is ready for implementation:
   - Ask if the user wants to change the label to indicate it's ready
   - If yes, update labels accordingly (use label names from project.md)

Important notes:
- Keep the conversation in Claude Code, not in GitHub comments
- Maintain the same markdown structure for consistency
- Preserve good parts of the original plan
- Be specific about what changed and why
- If comments reveal the feature shouldn't be built, suggest closing the issue
- Update acceptance criteria if the scope changed

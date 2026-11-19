#!/usr/bin/env bash
# Claude Code PreToolUse guard for Write/Edit.
#
# Denies a tool call whose NEW content contains a denylisted word, giving
# in-session feedback before anything reaches disk. The git pre-commit /
# pre-push hooks are the hard gate; this is the early warning.
#
# Scans NEW content only:
#   - Write  -> tool_input.content
#   - Edit   -> tool_input.new_string
# It deliberately ignores tool_input.file_path (paths may legitimately
# contain a denied word) and tool_input.old_string (so an edit that REMOVES
# a denied word is never blocked).
set -euo pipefail

GUARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$GUARD_DIR/_scan.sh"
pattern="$(build_pattern)"
[ -z "$pattern" ] && exit 0

input="$(cat)"
content="$(printf '%s' "$input" \
  | jq -r '[.tool_input.content, .tool_input.new_string]
           | map(select(. != null)) | join("\n")')"

if printf '%s' "$content" | grep -qiE "$pattern"; then
  match="$(printf '%s' "$content" | grep -oiE "$pattern" | sort -u | paste -sd ', ' -)"
  jq -cn --arg m "$match" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("Blocked: new content contains a denylisted word (" + $m + "). This repo is public — see .githooks/denylist.txt.")
    }
  }'
fi
exit 0

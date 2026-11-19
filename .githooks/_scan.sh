#!/usr/bin/env bash
# Shared helper for the content-guard hooks.
#
# IMPORTANT: the guard scans FILE CONTENT only — never file paths or the git
# remote URL. The repo can legitimately live under a path or belong to an
# account whose name matches a denied word (e.g. a username containing "kishi").
# Scanning content only keeps those false positives out.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DENYLIST="$HOOK_DIR/denylist.txt"

# Build a single case-insensitive ERE from the denylist (one word per line;
# blank lines and # comments ignored). Prints empty if the list is empty.
build_pattern() {
  [ -f "$DENYLIST" ] || return 0
  grep -vE '^[[:space:]]*($|#)' "$DENYLIST" \
    | sed 's/[[:space:]]*$//' \
    | paste -sd '|' -
}

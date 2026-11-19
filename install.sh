#!/bin/bash

# command-kit installer
# Installs the workflow commands into a target project as a symlink, and seeds
# the project-config templates so every command can read project-specific
# values at runtime.
#
# Usage:
#   ./install.sh [target_dir]        # target defaults to the current directory
#
# Environment variables:
#   COMMAND_KIT_DIR  Override the kit source directory
#                    (defaults to the directory containing this script)

set -e

KIT_DIR="${COMMAND_KIT_DIR:-$(cd "$(dirname "$0")" && pwd)}"
TARGET_DIR="${1:-.}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

echo "Installing command-kit"
echo "  Source:  $KIT_DIR"
echo "  Target:  $TARGET_DIR"

if [[ ! -d "$KIT_DIR/commands" ]]; then
    echo "Error: source directory has no commands/ folder (expected $KIT_DIR/commands)"
    exit 1
fi

cd "$TARGET_DIR"
mkdir -p .claude

# Symlink the commands directory into .claude/commands
echo ""
echo "Symlinking commands..."
if [[ -L .claude/commands ]]; then
    rm .claude/commands
elif [[ -d .claude/commands ]]; then
    echo "  .claude/commands is a real directory — backing up to .claude/commands.bak"
    mv .claude/commands .claude/commands.bak
fi
ln -sf "$KIT_DIR/commands" .claude/commands
echo "  Linked: .claude/commands -> $KIT_DIR/commands"

# Seed config templates (never overwrite existing files)
echo ""
echo "Seeding config..."
seed() { # $1 = template name, $2 = destination
    if [[ -f "$2" ]]; then
        echo "  Skipped: $2 (already exists)"
    else
        mkdir -p "$(dirname "$2")"
        cp "$KIT_DIR/templates/$1" "$2"
        echo "  Created: $2"
    fi
}
seed project.md    .claude/project.md
seed rules.md      .claude/rules.md
seed sprintplan.md .claude/plans/sprintplan.md

echo ""
echo "Done. Next steps:"
echo "  1. Fill in .claude/project.md    (GitHub repo, base branch, paths)"
echo "  2. Adjust .claude/rules.md       (your git + code conventions)"
echo "  3. Add .claude/commands to your .gitignore (it is a symlink)"
echo "  4. Try it:  /feature  (plan)  ->  /execute <issue#>  (ship)"

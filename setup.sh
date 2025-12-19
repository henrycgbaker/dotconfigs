#!/bin/bash
# setup.sh - Install dotclaude configuration via symlinks
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "Installing dotclaude configuration..."
echo "Source: $SCRIPT_DIR"
echo "Target: $CLAUDE_DIR"
echo ""

# Create ~/.claude if it doesn't exist
mkdir -p "$CLAUDE_DIR"

# Helper function to backup and symlink
backup_and_link() {
    local src="$1"
    local dest="$2"
    local name="$3"

    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        echo "Backing up existing $name to $name.backup"
        mv "$dest" "$dest.backup"
    fi
    ln -sfn "$src" "$dest"
    echo "✓ Linked $name"
}

# Symlink CLAUDE.md
backup_and_link "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md" "CLAUDE.md"

# Symlink rules/
backup_and_link "$SCRIPT_DIR/rules" "$CLAUDE_DIR/rules" "rules/"

# Symlink agents/
backup_and_link "$SCRIPT_DIR/agents" "$CLAUDE_DIR/agents" "agents/"

# Symlink hooks/
backup_and_link "$SCRIPT_DIR/hooks" "$CLAUDE_DIR/hooks" "hooks/"

# Symlink commands/
backup_and_link "$SCRIPT_DIR/commands" "$CLAUDE_DIR/commands" "commands/"

# Symlink skills/
backup_and_link "$SCRIPT_DIR/skills" "$CLAUDE_DIR/skills" "skills/"

# Symlink project-agents/ (for iterative development)
backup_and_link "$SCRIPT_DIR/project-agents" "$CLAUDE_DIR/project-agents" "project-agents/"

# Copy settings.json (not symlinked - allows local overrides)
if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
    cp "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
    echo "✓ Copied settings.json"
else
    echo "⊘ settings.json exists (kept local version)"
    echo "  To update, manually merge or run: cp $SCRIPT_DIR/settings.json $CLAUDE_DIR/settings.json"
fi

# === Global Git Hooks ===
# These hooks apply to ALL git repos (identity enforcement, AI attribution blocking)
echo ""
echo "Installing global git hooks..."

# Create githooks directory and copy global hooks
mkdir -p "$CLAUDE_DIR/githooks"
cp "$SCRIPT_DIR/githooks/global/"* "$CLAUDE_DIR/githooks/" 2>/dev/null || true
chmod +x "$CLAUDE_DIR/githooks/"* 2>/dev/null || true

# Set global hooks path
git config --global core.hooksPath "$CLAUDE_DIR/githooks"
echo "✓ Global git hooks installed to $CLAUDE_DIR/githooks/"
echo "✓ Set git config --global core.hooksPath"

# === Dotclaude-specific hooks ===
# These are sourced by global hooks when working in this repo
if [ -d "$SCRIPT_DIR/.githooks" ]; then
    echo "✓ Repo-specific hooks available in .githooks/"
fi

echo ""
echo "Done! Configuration installed."
echo ""
echo "Symlinks created:"
ls -la "$CLAUDE_DIR/CLAUDE.md" \
       "$CLAUDE_DIR/rules" \
       "$CLAUDE_DIR/agents" \
       "$CLAUDE_DIR/hooks" \
       "$CLAUDE_DIR/commands" \
       "$CLAUDE_DIR/skills" \
       "$CLAUDE_DIR/project-agents" 2>/dev/null || true

echo ""
echo "Note: settings.json is copied (not symlinked) to allow local overrides."
echo "      project-agents/ is symlinked for iterative development."
echo "      Consider copying project-agents/ to .claude/agents/ in specific projects once stable."

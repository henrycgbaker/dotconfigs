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

# Copy settings.json (not symlinked - allows local overrides)
if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
    cp "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
    echo "✓ Copied settings.json"
else
    echo "⊘ settings.json exists (kept local version)"
    echo "  To update, manually merge or run: cp $SCRIPT_DIR/settings.json $CLAUDE_DIR/settings.json"
fi

# === Global Gitignore ===
echo ""
echo "Setting up global gitignore..."

if [ ! -f "$HOME/.gitignore_global" ]; then
    cp "$SCRIPT_DIR/gitignore_global" "$HOME/.gitignore_global"
    git config --global core.excludesfile "$HOME/.gitignore_global"
    echo "✓ Installed global gitignore"
else
    echo "⊘ ~/.gitignore_global exists (kept existing)"
    echo "  To update: cp $SCRIPT_DIR/gitignore_global ~/.gitignore_global"
fi

# === Git Hooks ===
# Copy hook templates to .git/hooks/ (not tracked by git)
echo ""
echo "Installing git hooks..."

if [ -d "$SCRIPT_DIR/.git" ]; then
    mkdir -p "$SCRIPT_DIR/.git/hooks"
    for hook in "$SCRIPT_DIR/githooks/"*; do
        if [ -f "$hook" ]; then
            hookname=$(basename "$hook")
            cp "$hook" "$SCRIPT_DIR/.git/hooks/$hookname"
            chmod +x "$SCRIPT_DIR/.git/hooks/$hookname"
            echo "✓ Installed hook: $hookname"
        fi
    done
else
    echo "⊘ Not a git repo, skipping hooks"
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
       "$CLAUDE_DIR/skills" 2>/dev/null || true

echo ""
echo "Note: settings.json is copied (not symlinked) to allow local overrides."

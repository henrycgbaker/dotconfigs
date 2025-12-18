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

# Backup and symlink CLAUDE.md
if [ -f "$CLAUDE_DIR/CLAUDE.md" ] && [ ! -L "$CLAUDE_DIR/CLAUDE.md" ]; then
    echo "Backing up existing CLAUDE.md to CLAUDE.md.backup"
    mv "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.backup"
fi
ln -sfn "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
echo "✓ Linked CLAUDE.md"

# Backup and symlink rules/
if [ -d "$CLAUDE_DIR/rules" ] && [ ! -L "$CLAUDE_DIR/rules" ]; then
    echo "Backing up existing rules/ to rules.backup/"
    mv "$CLAUDE_DIR/rules" "$CLAUDE_DIR/rules.backup"
fi
ln -sfn "$SCRIPT_DIR/rules" "$CLAUDE_DIR/rules"
echo "✓ Linked rules/"

# Backup and symlink agents/
if [ -d "$CLAUDE_DIR/agents" ] && [ ! -L "$CLAUDE_DIR/agents" ]; then
    echo "Backing up existing agents/ to agents.backup/"
    mv "$CLAUDE_DIR/agents" "$CLAUDE_DIR/agents.backup"
fi
ln -sfn "$SCRIPT_DIR/agents" "$CLAUDE_DIR/agents"
echo "✓ Linked agents/"

# Copy settings.json (not symlinked - allows local overrides)
if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
    cp "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
    echo "✓ Copied settings.json"
else
    echo "⊘ settings.json exists (kept local version)"
fi

echo ""
echo "Done! Configuration installed."
echo ""
echo "Symlinks created:"
ls -la "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/rules" "$CLAUDE_DIR/agents" 2>/dev/null || true

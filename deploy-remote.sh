#!/bin/bash
# deploy-remote.sh - Deploy dotclaude configuration to remote servers
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 <ssh-host> [--clone|--rsync]"
    echo ""
    echo "Options:"
    echo "  --clone   Clone from GitHub on remote (default, requires git)"
    echo "  --rsync   Rsync local copy to remote (requires rsync)"
    echo ""
    echo "Examples:"
    echo "  $0 hbaker"
    echo "  $0 dsl --rsync"
    echo "  $0 user@server.com --clone"
    exit 1
}

if [ -z "$1" ]; then
    usage
fi

HOST="$1"
METHOD="${2:---clone}"

echo "Deploying dotclaude to $HOST..."

# Test SSH connection
echo "Testing SSH connection..."
if ! ssh -o ConnectTimeout=10 "$HOST" "echo 'Connected successfully'" 2>/dev/null; then
    echo "ERROR: Cannot connect to $HOST"
    echo "Check that you're on the correct network and SSH is configured."
    exit 1
fi

if [ "$METHOD" == "--rsync" ]; then
    echo "Using rsync method..."
    rsync -av --exclude='.git' --exclude='.vscode' "$SCRIPT_DIR/" "$HOST:~/dotclaude/"
else
    echo "Using git clone method..."
    ssh "$HOST" "
        if [ -d ~/dotclaude ]; then
            echo 'Updating existing repo...'
            cd ~/dotclaude && git pull
        else
            echo 'Cloning repo...'
            git clone https://github.com/henrycgbaker/dotclaude.git ~/dotclaude
        fi
    "
fi

# Run setup on remote
echo "Running setup on remote..."
ssh "$HOST" "cd ~/dotclaude && chmod +x setup.sh && ./setup.sh"

# Update settings.json
echo "Updating settings.json..."
ssh "$HOST" "cp ~/dotclaude/settings.json ~/.claude/settings.json"

# Install git hooks if git is configured
echo "Installing git hooks..."
ssh "$HOST" "
    if [ -d ~/dotclaude/githooks ]; then
        mkdir -p ~/.config/git
        echo 'Git hooks available at ~/dotclaude/githooks/'
        echo 'To use in a repo: git config core.hooksPath ~/dotclaude/githooks'
    fi
"

echo ""
echo "Done! dotclaude deployed to $HOST"
echo ""
echo "Verify with: ssh $HOST 'ls -la ~/.claude/'"

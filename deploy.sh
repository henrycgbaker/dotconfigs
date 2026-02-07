#!/bin/bash
# deploy.sh — Deploy dotclaude configuration
# Usage: deploy.sh global [--interactive] [--target DIR]
#        deploy.sh project [path] [--interactive]
#        deploy.sh --help
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Source shared libraries
source "$SCRIPT_DIR/scripts/lib/wizard.sh"
source "$SCRIPT_DIR/scripts/lib/symlinks.sh"
source "$SCRIPT_DIR/scripts/lib/discovery.sh"

# Show usage information
show_usage() {
    cat <<EOF
dotclaude deployment tool

Usage:
  deploy.sh global [--target DIR] [--remote HOST] [--method METHOD]
    Deploy configuration to global ~/.claude/ directory

    Options:
      --interactive   (no-op, wizard always runs; kept for backwards compat)
      --target DIR    Deploy to custom directory (non-interactive)
      --remote HOST   Deploy to remote host via SSH
      --method METHOD Transfer method for remote: clone (default) or rsync

  deploy.sh project [path] [--interactive]
    Scaffold project-specific .claude/ directory

  deploy.sh --help
    Show this help message

Examples:
  deploy.sh global                          # Run wizard and deploy
  deploy.sh global --target ~/config        # Deploy to custom path (non-interactive)
  deploy.sh global --remote user@host       # Deploy to remote via clone
  deploy.sh global --remote host --method rsync  # Deploy to remote via rsync
  deploy.sh project .                       # Scaffold current project
  deploy.sh project /path/to/repo --interactive  # Scaffold with prompts

EOF
}

# Build CLAUDE.md from enabled templates
# Args: dotclaude_root, deploy_target, enabled_sections...
build_claude_md() {
    local dotclaude_root="$1"
    local deploy_target="$2"
    shift 2
    local enabled_sections=("$@")

    local templates_dir="$dotclaude_root/templates/claude-md"
    local output_file="$deploy_target/CLAUDE.md"

    # Clear output file
    > "$output_file"

    # Read templates in numeric order and concatenate enabled ones
    local first_section=true
    for template_file in "$templates_dir"/*.md; do
        if [[ ! -f "$template_file" ]]; then
            continue
        fi

        # Extract section name from filename (01-communication.md → communication)
        local filename=$(basename "$template_file")
        local section_name=$(echo "$filename" | sed -E 's/^[0-9]+-(.*)\.md$/\1/')

        # Check if section is enabled
        local section_enabled=false
        for enabled in "${enabled_sections[@]}"; do
            if [[ "$enabled" == "$section_name" ]]; then
                section_enabled=true
                break
            fi
        done

        if [[ "$section_enabled" == "true" ]]; then
            # Add blank line separator between sections (but not before first)
            if [[ "$first_section" == "false" ]]; then
                echo "" >> "$output_file"
            fi
            first_section=false

            # Append template content
            cat "$template_file" >> "$output_file"
        fi
    done

    echo "  ✓ Built CLAUDE.md from $(echo ${enabled_sections[@]} | wc -w | tr -d ' ') sections"
}

# Run the 9-step wizard to configure deployment
run_wizard() {
    local dotclaude_root="$1"

    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         dotclaude Global Deployment Wizard                 ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    # Step 1: Deploy target
    wizard_header 1 "Deploy Target"
    echo "Where should dotclaude configuration be deployed?"
    wizard_prompt "Deploy target directory" "${DEPLOY_TARGET:-$HOME/.claude}" DEPLOY_TARGET
    DEPLOY_TARGET="${DEPLOY_TARGET/#\~/$HOME}"  # Expand tilde

    # Step 2: Settings.json
    wizard_header 2 "Settings"
    echo "Claude Code permission rules control which files Claude can read and which"
    echo "commands it can run. This includes denying access to secrets (*.pem, credentials)"
    echo "and auto-formatting Python files with Ruff."
    echo ""
    local settings_default="y"
    [[ "${SETTINGS_ENABLED:-}" == "false" ]] && settings_default="n"
    if wizard_yesno "Deploy settings.json to $DEPLOY_TARGET? (symlinks from dotclaude repo)" "$settings_default"; then
        SETTINGS_ENABLED="true"
    else
        SETTINGS_ENABLED="false"
    fi

    # Step 3: CLAUDE.md sections
    wizard_header 3 "CLAUDE.md Sections"
    echo "Select which sections to include in your global CLAUDE.md"
    echo ""

    # Discover available sections
    local available_sections=()
    while IFS= read -r section; do
        available_sections+=("$section")
    done < <(discover_claude_sections "$dotclaude_root")

    # Toggle each section (pre-fill from previous config)
    local prev_sections="${CLAUDE_SECTIONS:-}"
    CLAUDE_SECTIONS_ENABLED=()
    for section in "${available_sections[@]}"; do
        local section_default="y"
        # If we have previous config, only default 'y' for previously enabled sections
        if [[ -n "$prev_sections" ]]; then
            if ! _is_in_list "$section" "$prev_sections"; then
                section_default="n"
            fi
        fi
        if wizard_yesno "  Include ${section}?" "$section_default"; then
            CLAUDE_SECTIONS_ENABLED+=("$section")
        fi
    done

    # Step 4: Claude Code Hooks
    wizard_header 4 "Claude Code Hooks"
    echo "Select which Claude Code hooks to enable"
    echo ""

    # Discover available hooks
    local available_hooks=()
    while IFS= read -r hook; do
        available_hooks+=("$hook")
    done < <(discover_hooks "$dotclaude_root")

    HOOKS_ENABLED=()
    if [[ ${#available_hooks[@]} -gt 0 ]]; then
        for hook in "${available_hooks[@]}"; do
            local hook_default="y"
            if [[ -n "${HOOKS_ENABLED_PREV:-}" ]]; then
                if ! _is_in_list "$hook" "$HOOKS_ENABLED_PREV"; then
                    hook_default="n"
                fi
            fi
            if wizard_yesno "  Enable ${hook}?" "$hook_default"; then
                HOOKS_ENABLED+=("$hook")
            fi
        done
    else
        echo "  No hooks found in hooks/ directory"
    fi

    # Step 5: Skills (Commands)
    wizard_header 5 "Skills"
    echo "Select which skills to enable"
    echo ""

    # Discover available skills
    local available_skills=()
    while IFS= read -r skill; do
        available_skills+=("$skill")
    done < <(discover_skills "$dotclaude_root")

    SKILLS_ENABLED=()
    if [[ ${#available_skills[@]} -gt 0 ]]; then
        for skill in "${available_skills[@]}"; do
            local skill_default="y"
            if [[ -n "${SKILLS_ENABLED_PREV:-}" ]]; then
                if ! _is_in_list "$skill" "$SKILLS_ENABLED_PREV"; then
                    skill_default="n"
                fi
            fi
            if wizard_yesno "  Enable ${skill}?" "$skill_default"; then
                SKILLS_ENABLED+=("$skill")
            fi
        done
    else
        echo "  No skills found in commands/ directory"
    fi

    # Step 6: GSD Framework
    wizard_header 6 "GSD Framework"
    echo "The Get Shit Done framework provides project planning agents."
    local gsd_default="n"
    [[ "${GSD_INSTALL:-}" == "true" ]] && gsd_default="y"
    if wizard_yesno "Install GSD framework?" "$gsd_default"; then
        GSD_INSTALL="true"
    else
        GSD_INSTALL="false"
    fi

    # Step 7: Git Identity
    wizard_header 7 "Git Identity"
    echo "Configure global git user.name and user.email"
    echo "(Leave empty to keep existing configuration)"
    echo ""
    local prev_name="${GIT_USER_NAME:-}"
    local prev_email="${GIT_USER_EMAIL:-}"
    if [[ -n "$prev_name" ]]; then
        read -p "Git user.name [$prev_name]: " GIT_USER_NAME
        GIT_USER_NAME="${GIT_USER_NAME:-$prev_name}"
    else
        read -p "Git user.name: " GIT_USER_NAME
    fi
    if [[ -n "$prev_email" ]]; then
        read -p "Git user.email [$prev_email]: " GIT_USER_EMAIL
        GIT_USER_EMAIL="${GIT_USER_EMAIL:-$prev_email}"
    else
        read -p "Git user.email: " GIT_USER_EMAIL
    fi

    # Step 8: Shell Aliases
    wizard_header 8 "Shell Aliases"
    echo "Set up shell aliases so you can run 'deploy global' instead of"
    echo "'bash $dotclaude_root/deploy.sh global'."
    echo ""
    local aliases_default="n"
    [[ "${ALIASES_ENABLED:-}" == "true" ]] && aliases_default="y"
    if wizard_yesno "Set up shell aliases?" "$aliases_default"; then
        ALIASES_ENABLED="true"
        local prev_alias="${ALIAS_DEPLOY_NAME:-deploy}"
        wizard_prompt "Alias for deploy.sh" "$prev_alias" ALIAS_DEPLOY_NAME
    else
        ALIASES_ENABLED="false"
    fi

    # Step 9: Conflict Review
    wizard_header 9 "Conflict Review"
    echo "Checking for existing files in deploy target..."
    echo ""

    if [[ -d "$DEPLOY_TARGET" ]]; then
        local conflicts_found=false

        # Check for CLAUDE.md
        if [[ -f "$DEPLOY_TARGET/CLAUDE.md" ]]; then
            if ! is_dotclaude_owned "$DEPLOY_TARGET/CLAUDE.md" "$dotclaude_root"; then
                echo "  ! $DEPLOY_TARGET/CLAUDE.md exists (not managed by dotclaude)"
                conflicts_found=true
            fi
        fi

        # Check for settings.json
        if [[ -f "$DEPLOY_TARGET/settings.json" ]]; then
            if ! is_dotclaude_owned "$DEPLOY_TARGET/settings.json" "$dotclaude_root"; then
                echo "  ! $DEPLOY_TARGET/settings.json exists (not managed by dotclaude)"
                conflicts_found=true
            fi
        fi

        if [[ "$conflicts_found" == "false" ]]; then
            echo "  ✓ No conflicts detected"
        else
            echo ""
            echo "  Conflicts will be handled during deployment (backup/overwrite/skip)"
        fi
    else
        echo "  ✓ Deploy target is empty (will be created)"
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    # Save configuration to .env
    save_config

    # Set array variables used by deploy_global()
    HOOKS_ENABLED_ARRAY=("${HOOKS_ENABLED[@]}")
    SKILLS_ENABLED_ARRAY=("${SKILLS_ENABLED[@]}")

    echo "Configuration saved to $ENV_FILE"
    echo ""
}

# Save current configuration to .env file
save_config() {
    # Create .env if it doesn't exist
    if [[ ! -f "$ENV_FILE" ]]; then
        cat > "$ENV_FILE" <<'EOF'
# dotclaude configuration
# Generated by: deploy.sh global (wizard)
# Re-run wizard: deploy.sh global

EOF
    fi

    wizard_save_env "$ENV_FILE" "DEPLOY_TARGET" "$DEPLOY_TARGET"
    wizard_save_env "$ENV_FILE" "SETTINGS_ENABLED" "$SETTINGS_ENABLED"

    # Save CLAUDE.md sections as space-separated list
    local sections_str="${CLAUDE_SECTIONS_ENABLED[*]}"
    wizard_save_env "$ENV_FILE" "CLAUDE_SECTIONS" "$sections_str"

    # Save hooks as space-separated list
    local hooks_str="${HOOKS_ENABLED[*]}"
    wizard_save_env "$ENV_FILE" "HOOKS_ENABLED" "$hooks_str"

    # Save skills as space-separated list
    local skills_str="${SKILLS_ENABLED[*]}"
    wizard_save_env "$ENV_FILE" "SKILLS_ENABLED" "$skills_str"

    wizard_save_env "$ENV_FILE" "GSD_INSTALL" "$GSD_INSTALL"
    wizard_save_env "$ENV_FILE" "GIT_USER_NAME" "$GIT_USER_NAME"
    wizard_save_env "$ENV_FILE" "GIT_USER_EMAIL" "$GIT_USER_EMAIL"
    wizard_save_env "$ENV_FILE" "ALIASES_ENABLED" "${ALIASES_ENABLED:-false}"
    wizard_save_env "$ENV_FILE" "ALIAS_DEPLOY_NAME" "${ALIAS_DEPLOY_NAME:-deploy}"
}

# Load configuration from .env file
load_config() {
    if [[ ! -f "$ENV_FILE" ]]; then
        return 1
    fi

    source "$ENV_FILE"

    # Preserve raw space-separated strings for wizard pre-fill defaults
    HOOKS_ENABLED_PREV="${HOOKS_ENABLED:-}"
    SKILLS_ENABLED_PREV="${SKILLS_ENABLED:-}"

    # Convert space-separated strings back to arrays
    if [[ -n "$CLAUDE_SECTIONS" ]]; then
        IFS=' ' read -ra CLAUDE_SECTIONS_ENABLED <<< "$CLAUDE_SECTIONS"
    else
        CLAUDE_SECTIONS_ENABLED=()
    fi

    if [[ -n "$HOOKS_ENABLED" ]]; then
        IFS=' ' read -ra HOOKS_ENABLED_ARRAY <<< "$HOOKS_ENABLED"
    else
        HOOKS_ENABLED_ARRAY=()
    fi

    if [[ -n "$SKILLS_ENABLED" ]]; then
        IFS=' ' read -ra SKILLS_ENABLED_ARRAY <<< "$SKILLS_ENABLED"
    else
        SKILLS_ENABLED_ARRAY=()
    fi

    return 0
}

# Set up shell aliases in the user's RC file (idempotent)
# Uses marker-delimited block for safe replacement on re-run
setup_shell_aliases() {
    local dotclaude_root="$1"
    local alias_name="${ALIAS_DEPLOY_NAME:-deploy}"

    # Detect shell RC file
    local rc_file
    if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$(basename "${SHELL:-}")" == "zsh" ]]; then
        rc_file="$HOME/.zshrc"
    elif [[ -f "$HOME/.bash_profile" ]]; then
        rc_file="$HOME/.bash_profile"
    else
        rc_file="$HOME/.bashrc"
    fi

    local marker_start="# dotclaude aliases"
    local marker_end="# end dotclaude aliases"

    local alias_block
    alias_block=$(cat <<EOF
${marker_start}
alias ${alias_name}='bash ${dotclaude_root}/deploy.sh'
alias registry-scan='bash ${dotclaude_root}/scripts/registry-scan.sh'
${marker_end}
EOF
)

    # Create RC file if it doesn't exist
    if [[ ! -f "$rc_file" ]]; then
        touch "$rc_file"
    fi

    # Remove existing block if present, then append new one
    if grep -q "^${marker_start}$" "$rc_file" 2>/dev/null; then
        # Use sed to delete from marker_start to marker_end inclusive
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "/^${marker_start}$/,/^${marker_end}$/d" "$rc_file"
        else
            sed -i "/^${marker_start}$/,/^${marker_end}$/d" "$rc_file"
        fi
    fi

    # Append alias block
    echo "" >> "$rc_file"
    echo "$alias_block" >> "$rc_file"

    echo "  ✓ Added aliases to $rc_file"
    echo "    Run 'source $rc_file' or open a new terminal to activate"
    echo "    Alias: ${alias_name} → deploy.sh"
    echo "    Alias: registry-scan → scripts/registry-scan.sh"
}

# Perform the deployment based on loaded configuration
deploy_global() {
    local dotclaude_root="$1"
    local interactive="$2"

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Deploying dotclaude to: $DEPLOY_TARGET"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    # Create deploy target directory
    if [[ ! -d "$DEPLOY_TARGET" ]]; then
        mkdir -p "$DEPLOY_TARGET"
        echo "  ✓ Created $DEPLOY_TARGET"
    fi

    # 1. Symlink settings.json
    if [[ "$SETTINGS_ENABLED" == "true" ]]; then
        echo "Deploying settings.json..."
        backup_and_link "$dotclaude_root/settings.json" "$DEPLOY_TARGET/settings.json" "settings.json" "$interactive"
    fi

    # 2. Build CLAUDE.md
    if [[ ${#CLAUDE_SECTIONS_ENABLED[@]} -gt 0 ]]; then
        echo "Building CLAUDE.md..."
        build_claude_md "$dotclaude_root" "$DEPLOY_TARGET" "${CLAUDE_SECTIONS_ENABLED[@]}"
    fi

    # 3. Symlink Claude Code hooks
    if [[ ${#HOOKS_ENABLED_ARRAY[@]} -gt 0 ]]; then
        echo "Deploying Claude Code hooks..."
        mkdir -p "$DEPLOY_TARGET/hooks"
        for hook in "${HOOKS_ENABLED_ARRAY[@]}"; do
            backup_and_link "$dotclaude_root/hooks/$hook" "$DEPLOY_TARGET/hooks/$hook" "hooks/$hook" "$interactive"
        done
    fi

    # 4. Symlink skills
    if [[ ${#SKILLS_ENABLED_ARRAY[@]} -gt 0 ]]; then
        echo "Deploying skills..."
        mkdir -p "$DEPLOY_TARGET/commands"
        for skill in "${SKILLS_ENABLED_ARRAY[@]}"; do
            backup_and_link "$dotclaude_root/commands/${skill}.md" "$DEPLOY_TARGET/commands/${skill}.md" "commands/${skill}.md" "$interactive"
        done
    fi

    # 5. Copy git hooks and set core.hooksPath
    echo "Deploying git hooks..."
    local githooks_target="$DEPLOY_TARGET/git-hooks"
    mkdir -p "$githooks_target"

    # Copy all git hooks from githooks/ directory
    if [[ -d "$dotclaude_root/githooks" ]]; then
        for githook in "$dotclaude_root/githooks"/*; do
            if [[ -f "$githook" ]]; then
                local hook_name=$(basename "$githook")
                cp "$githook" "$githooks_target/$hook_name"
                chmod +x "$githooks_target/$hook_name"
                echo "  ✓ Copied $hook_name"
            fi
        done
    fi

    # Set global git hooks path
    git config --global core.hooksPath "$githooks_target"
    echo "  ✓ Set git config --global core.hooksPath=$githooks_target"

    # 6. Configure git identity
    if [[ -n "$GIT_USER_NAME" ]]; then
        git config --global user.name "$GIT_USER_NAME"
        echo "  ✓ Set git user.name=$GIT_USER_NAME"
    fi

    if [[ -n "$GIT_USER_EMAIL" ]]; then
        git config --global user.email "$GIT_USER_EMAIL"
        echo "  ✓ Set git user.email=$GIT_USER_EMAIL"
    fi

    # 7. Install GSD framework
    if [[ "$GSD_INSTALL" == "true" ]]; then
        echo "Installing GSD framework..."
        npx get-shit-done-cc --claude --global
        echo "  ✓ GSD framework installed"
    fi

    # 8. Set up shell aliases
    if [[ "${ALIASES_ENABLED:-false}" == "true" ]]; then
        echo "Setting up shell aliases..."
        setup_shell_aliases "$dotclaude_root"
    fi

    # 9. Handle .git/info/exclude for dotclaude repo (GHYG-01)
    local dotclaude_exclude="$dotclaude_root/.git/info/exclude"
    if [[ -f "$dotclaude_exclude" ]]; then
        if ! grep -q "^CLAUDE.md$" "$dotclaude_exclude" 2>/dev/null; then
            echo "CLAUDE.md" >> "$dotclaude_exclude"
            echo "  ✓ Added CLAUDE.md to .git/info/exclude"
        fi
        if ! grep -q "^\.claude/$" "$dotclaude_exclude" 2>/dev/null; then
            echo ".claude/" >> "$dotclaude_exclude"
            echo "  ✓ Added .claude/ to .git/info/exclude"
        fi
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Deployment complete!"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
}

# Deploy to remote host via SSH
deploy_remote() {
    local remote_host="$1"
    local transfer_method="$2"

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Remote Deployment to: $remote_host"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    # Test SSH connection
    echo "Testing SSH connection..."
    if ! ssh -o ConnectTimeout=10 "$remote_host" "echo connected" &>/dev/null; then
        echo "Error: Cannot connect to $remote_host" >&2
        echo "Check SSH configuration and try again" >&2
        exit 1
    fi
    echo "  ✓ SSH connection successful"
    echo ""

    # Transfer repo to remote
    if [[ "$transfer_method" == "rsync" ]]; then
        echo "Transferring via rsync..."
        rsync -av \
            --exclude='.git' \
            --exclude='.vscode' \
            --exclude='.env' \
            --exclude='.planning' \
            --exclude='*.pyc' \
            --exclude='__pycache__' \
            "$SCRIPT_DIR/" "$remote_host:~/dotclaude/"
        echo "  ✓ Rsync complete"
    else
        # Clone method (default)
        echo "Cloning/updating repo on remote..."

        # Get clone URL from config or git remote
        local clone_url="${REMOTE_REPO_URL:-}"
        if [[ -z "$clone_url" ]]; then
            clone_url=$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || echo "")
        fi

        if [[ -z "$clone_url" ]]; then
            echo "Error: No git remote found and REMOTE_REPO_URL not set in .env" >&2
            echo "Add REMOTE_REPO_URL to .env or use --method rsync" >&2
            exit 1
        fi

        # Clone or pull on remote
        ssh "$remote_host" bash <<EOF
if [[ -d ~/dotclaude ]]; then
    echo "  Repository exists, pulling updates..."
    cd ~/dotclaude
    git pull
else
    echo "  Cloning repository..."
    git clone "$clone_url" ~/dotclaude
fi
EOF
        echo "  ✓ Repository ready on remote"
    fi

    echo ""

    # Run deploy.sh global on remote
    echo "Running deploy.sh global on remote..."
    ssh "$remote_host" "cd ~/dotclaude && chmod +x deploy.sh && ./deploy.sh global"

    echo ""

    # Optional GSD installation
    if [[ "${GSD_INSTALL:-false}" == "true" ]]; then
        echo "Installing GSD framework on remote..."
        ssh "$remote_host" "npx get-shit-done-cc --claude --global"
        echo "  ✓ GSD installed on remote"
        echo ""
    fi

    echo "═══════════════════════════════════════════════════════════"
    echo "  Remote deployment complete!"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Note: Remote configuration (.env) is separate from local."
    echo "SSH to $remote_host to customize remote settings."
    echo ""
}

# Global subcommand implementation
cmd_global() {
    local force_interactive=false
    local target_override=""
    local remote_host=""
    local remote_method="clone"

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --interactive)
                force_interactive=true
                shift
                ;;
            --target)
                target_override="$2"
                shift 2
                ;;
            --remote)
                remote_host="$2"
                shift 2
                ;;
            --method)
                remote_method="$2"
                if [[ "$remote_method" != "clone" ]] && [[ "$remote_method" != "rsync" ]]; then
                    echo "Error: Invalid method '$remote_method'. Use 'clone' or 'rsync'" >&2
                    exit 1
                fi
                shift 2
                ;;
            *)
                echo "Error: Unknown option $1" >&2
                show_usage
                exit 1
                ;;
        esac
    done

    # Handle remote deployment
    if [[ -n "$remote_host" ]]; then
        # Load config for GSD_INSTALL flag
        load_config 2>/dev/null || true
        deploy_remote "$remote_host" "$remote_method"
        return 0
    fi

    # Determine mode: wizard vs config-driven
    local interactive_deploy=true

    if [[ -n "$target_override" ]]; then
        # Non-interactive mode with --target flag
        DEPLOY_TARGET="$target_override"
        DEPLOY_TARGET="${DEPLOY_TARGET/#\~/$HOME}"  # Expand tilde

        # Set defaults for non-interactive mode
        SETTINGS_ENABLED="true"
        CLAUDE_SECTIONS_ENABLED=("communication" "simplicity" "documentation" "git" "code-style")
        HOOKS_ENABLED_ARRAY=("post-tool-format.py")
        SKILLS_ENABLED_ARRAY=("commit" "squash-merge" "simplicity-check")
        GSD_INSTALL="false"
        GIT_USER_NAME=""
        GIT_USER_EMAIL=""
        ALIASES_ENABLED="false"

        interactive_deploy=false
    else
        # Always load existing config (if any) for pre-filled defaults
        load_config 2>/dev/null || true
        # Always run wizard — previous values appear as defaults
        run_wizard "$SCRIPT_DIR"
    fi

    # Perform deployment
    deploy_global "$SCRIPT_DIR" "$interactive_deploy"
}

# Detect project type from filesystem
detect_project_type() {
    local project_path="$1"

    # Check for Python
    if [[ -f "$project_path/pyproject.toml" ]] || \
       [[ -f "$project_path/setup.py" ]] || \
       [[ -f "$project_path/requirements.txt" ]] || \
       find "$project_path" -maxdepth 1 -name "*.py" -type f 2>/dev/null | grep -q .; then
        echo "python"
        return
    fi

    # Check for Node
    if [[ -f "$project_path/package.json" ]]; then
        echo "node"
        return
    fi

    # Check for Go
    if [[ -f "$project_path/go.mod" ]]; then
        echo "go"
        return
    fi

    # Default
    echo "generic"
}

# Merge JSON files (base + overlay)
merge_settings_json() {
    local base_file="$1"
    local overlay_file="$2"
    local output_file="$3"

    # Use jq to merge if available, otherwise simple concat approach
    if command -v jq &> /dev/null; then
        jq -s '.[0] * .[1]' "$base_file" "$overlay_file" > "$output_file"
    else
        # Fallback: Python-based merge
        python3 <<EOF
import json
import sys

try:
    with open("$base_file") as f:
        base = json.load(f)
    with open("$overlay_file") as f:
        overlay = json.load(f)

    # Deep merge
    def deep_merge(base, overlay):
        for key, value in overlay.items():
            if key in base and isinstance(base[key], dict) and isinstance(value, dict):
                deep_merge(base[key], value)
            elif key in base and isinstance(base[key], list) and isinstance(value, list):
                base[key].extend(value)
            else:
                base[key] = value
        return base

    result = deep_merge(base, overlay)

    with open("$output_file", "w") as f:
        json.dump(result, f, indent=2)
except Exception as e:
    print(f"Error merging JSON: {e}", file=sys.stderr)
    sys.exit(1)
EOF
    fi
}

# Project subcommand implementation
cmd_project() {
    local project_path="."
    local force_interactive=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --interactive)
                force_interactive=true
                shift
                ;;
            -*)
                echo "Error: Unknown option $1" >&2
                exit 1
                ;;
            *)
                project_path="$1"
                shift
                ;;
        esac
    done

    # Resolve to absolute path
    if [[ "$project_path" != /* ]]; then
        project_path="$(cd "$project_path" 2>/dev/null && pwd)"
        if [[ $? -ne 0 ]]; then
            echo "Error: Invalid path" >&2
            exit 1
        fi
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Project Scaffolding: $(basename "$project_path")"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    # Validate git repo
    if [[ ! -d "$project_path/.git" ]]; then
        echo "Error: Not a git repository: $project_path" >&2
        echo "Initialize with: git init" >&2
        exit 1
    fi

    # Detect project state (greenfield vs brownfield)
    local is_greenfield=true
    local existing_claude_dir=false
    local existing_claude_md=false
    local existing_git_exclude=false

    if [[ -d "$project_path/.claude" ]]; then
        existing_claude_dir=true
        is_greenfield=false
        echo "  ℹ Existing .claude/ directory detected (brownfield)"
    fi

    if [[ -f "$project_path/CLAUDE.md" ]]; then
        existing_claude_md=true
        is_greenfield=false
        echo "  ℹ Existing CLAUDE.md detected"
    fi

    if [[ -f "$project_path/.git/info/exclude" ]]; then
        existing_git_exclude=true
        echo "  ℹ Existing .git/info/exclude detected"
    fi

    if [[ "$is_greenfield" == "true" ]]; then
        echo "  ✓ Greenfield project (no existing configuration)"
    fi

    echo ""

    # Detect project type
    local project_type=$(detect_project_type "$project_path")
    echo "Project type: $project_type"
    echo ""

    # Step 1: Build and deploy settings.json
    echo "Step 1: Project settings.json"
    echo "──────────────────────────────"

    local claude_dir="$project_path/.claude"
    mkdir -p "$claude_dir"

    local settings_target="$claude_dir/settings.json"
    local base_settings="$SCRIPT_DIR/templates/settings/base.json"
    local type_settings="$SCRIPT_DIR/templates/settings/${project_type}.json"

    if [[ -f "$settings_target" ]]; then
        echo "  Existing settings.json found"
        if [[ "$force_interactive" == "true" ]]; then
            echo "  Choose action:"
            select action in "Overwrite" "Skip" "Show diff"; do
                case $action in
                    Overwrite)
                        break
                        ;;
                    Skip)
                        echo "  Skipped settings.json"
                        settings_target=""
                        break
                        ;;
                    "Show diff")
                        echo "  Current settings:"
                        head -20 "$settings_target"
                        ;;
                esac
            done
        else
            echo "  Skipping (use --interactive to overwrite)"
            settings_target=""
        fi
    fi

    if [[ -n "$settings_target" ]]; then
        if [[ -f "$type_settings" ]]; then
            # Merge base + type overlay
            merge_settings_json "$base_settings" "$type_settings" "$settings_target"
            echo "  ✓ Built settings.json from base + $project_type overlay"
        else
            # Copy base only
            cp "$base_settings" "$settings_target"
            echo "  ✓ Copied base settings.json"
        fi
    fi

    echo ""

    # Step 2: Deploy hooks.conf
    echo "Step 2: Hooks configuration"
    echo "──────────────────────────────"

    local hooks_conf_target="$claude_dir/hooks.conf"
    local hooks_template="default"

    if [[ "$force_interactive" == "true" ]]; then
        echo "  Select hooks profile:"
        select profile in "default" "strict" "permissive"; do
            case $profile in
                default|strict|permissive)
                    hooks_template="$profile"
                    break
                    ;;
            esac
        done
    fi

    local hooks_conf_source="$SCRIPT_DIR/templates/hooks-conf/${hooks_template}.conf"

    if [[ -f "$hooks_conf_target" ]]; then
        echo "  Existing hooks.conf found"
        if [[ "$force_interactive" == "true" ]]; then
            if wizard_yesno "  Overwrite hooks.conf?" "n"; then
                cp "$hooks_conf_source" "$hooks_conf_target"
                echo "  ✓ Copied $hooks_template hooks.conf"
            else
                echo "  Skipped hooks.conf"
            fi
        else
            echo "  Skipped (use --interactive to overwrite)"
        fi
    else
        cp "$hooks_conf_source" "$hooks_conf_target"

        # Adjust defaults based on project type
        if [[ "$project_type" == "python" ]]; then
            # RUFF_ENABLED already true in default template
            echo "  ✓ Copied $hooks_template hooks.conf (Python defaults)"
        elif [[ "$project_type" == "node" ]]; then
            # Disable Ruff for Node projects
            sed -i.bak 's/^RUFF_ENABLED=true/RUFF_ENABLED=false/' "$hooks_conf_target"
            rm -f "$hooks_conf_target.bak"
            echo "  ✓ Copied $hooks_template hooks.conf (Node defaults)"
        else
            echo "  ✓ Copied $hooks_template hooks.conf"
        fi
    fi

    echo ""

    # Step 3: Create/update CLAUDE.md
    echo "Step 3: Project CLAUDE.md"
    echo "──────────────────────────────"

    local claude_md_target="$project_path/CLAUDE.md"

    if [[ -f "$claude_md_target" ]]; then
        echo "  Existing CLAUDE.md found"
        if [[ "$force_interactive" == "true" ]]; then
            echo "  Choose action:"
            select action in "Append dotclaude section" "Skip"; do
                case $action in
                    "Append dotclaude section")
                        cat >> "$claude_md_target" <<EOF

## Project Configuration

Project type: $project_type
Configuration managed by: dotclaude (https://github.com/yourusername/dotclaude)

For global Claude instructions, see: ~/.claude/CLAUDE.md
EOF
                        echo "  ✓ Appended dotclaude section to CLAUDE.md"
                        break
                        ;;
                    Skip)
                        echo "  Skipped CLAUDE.md"
                        break
                        ;;
                esac
            done
        else
            echo "  Skipped (use --interactive to append)"
        fi
    else
        # Create minimal project CLAUDE.md
        cat > "$claude_md_target" <<EOF
# $(basename "$project_path")

Project type: $project_type

## Configuration

This project uses dotclaude for Claude Code configuration.
- Settings: .claude/settings.json
- Hooks: .claude/hooks.conf
- Global instructions: ~/.claude/CLAUDE.md
EOF
        echo "  ✓ Created minimal CLAUDE.md"
    fi

    echo ""

    # Step 4: Update .git/info/exclude
    echo "Step 4: Git exclusions"
    echo "──────────────────────────────"

    local git_exclude="$project_path/.git/info/exclude"

    # Ensure file exists
    touch "$git_exclude"

    # Add entries if not present
    local added_count=0

    if ! grep -q "^CLAUDE.md$" "$git_exclude" 2>/dev/null; then
        echo "CLAUDE.md" >> "$git_exclude"
        ((added_count++))
    fi

    if ! grep -q "^\.claude/$" "$git_exclude" 2>/dev/null; then
        echo ".claude/" >> "$git_exclude"
        ((added_count++))
    fi

    if ! grep -q "^\.claude-project$" "$git_exclude" 2>/dev/null; then
        echo ".claude-project" >> "$git_exclude"
        ((added_count++))
    fi

    if [[ $added_count -gt 0 ]]; then
        echo "  ✓ Added $added_count exclusion(s) to .git/info/exclude"
    else
        echo "  ✓ All exclusions already present"
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Project scaffolding complete!"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Created/updated:"
    echo "  - .claude/settings.json (merged from templates)"
    echo "  - .claude/hooks.conf (copy of $hooks_template template)"
    echo "  - CLAUDE.md (project-specific)"
    echo "  - .git/info/exclude (AI artefacts)"
    echo ""
}

# Main entry point
main() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 0
    fi

    case "$1" in
        global)
            shift
            cmd_global "$@"
            ;;
        project)
            shift
            cmd_project "$@"
            ;;
        --help|-h|help)
            show_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown command: $1" >&2
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"

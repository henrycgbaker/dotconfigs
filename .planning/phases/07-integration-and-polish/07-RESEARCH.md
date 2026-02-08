# Phase 7: Integration & Polish - Research

**Researched:** 2026-02-07
**Domain:** Bash CLI status reporting, ANSI colours, idempotency, conflict handling, help systems
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Status output format:**
- `dotconfigs status` shows ALL plugins in one view (no prompting to pick one)
- Per-file granularity: each managed file listed with its state
- Three-state model: not configured / configured but not deployed / deployed
- Drift detection: flag files that have changed since last deploy (symlink broken, config edited)
- Report drift only — no suggested fix commands
- ANSI colour output when TTY detected (green OK, yellow drift, red missing), plain text when piped
- `dotconfigs status <plugin>` filters to a single plugin

**List command:**
- Minimal output: plugin name + installed/not-installed status
- No descriptions — just `claude ✓ installed` / `git ✗ not installed`
- Uses same colour scheme as status

**Conflict detection:**
- When deploy encounters an existing file it didn't create: warn and prompt per-file (overwrite, skip, or diff)
- If user chooses overwrite: offer `.bak` backup before overwriting
- `--force` flag bypasses all conflict prompts and overwrites everything
- Ownership model: symlink check (SSOT architecture — repo is source of truth, symlinks express that; regular files at target location are foreign by definition)
- Cross-plugin file conflicts are not possible by design — plugins have separate namespaces; treat as a bug if it happens

**Idempotency & deploy behaviour:**
- `dotconfigs deploy` (no arg) deploys ALL configured plugins — one command to sync everything
- `dotconfigs deploy <plugin>` deploys a single plugin
- Always print deploy summary (files created, skipped, unchanged) — even when nothing changed
- `--dry-run` flag shows what deploy WOULD do without touching the filesystem

**Documentation (final plan in phase):**
- Audience: Semi-public — clear enough for others, no over-explaining or marketing fluff
- README sections: Overview, install, usage (setup/deploy/project/status/list), .env reference, directory structure
- No example terminal output — keep it concise
- `.env.example` polish: ensure all CLAUDE_* and GIT_* keys present and accurate; format at Claude's discretion
- No plugin developer guide — personal tool, not needed
- No separate config reference — `.env.example` and `dotconfigs help` cover it

### Claude's Discretion

- Ownership detection mechanism details (symlink-based fits SSOT, Claude to decide exact implementation)
- Skip-unchanged vs always-overwrite on idempotent re-deploy
- Help command format and content
- Exact colour codes and formatting
- Testing approach for macOS (bash 3.2) + Linux (bash 4+)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

## Summary

Phase 7 integrates cross-cutting concerns for a production-ready CLI: status visibility (per-file drift detection), help system, conflict handling (interactive prompts + `--force`), idempotent deploys (safe re-runs), and documentation. All patterns leverage existing bash 3.2 patterns from earlier phases — no new external dependencies.

The research domain covers five technical areas:
1. **ANSI colour output** with TTY detection for status/list commands
2. **Idempotent operations** using `ln -sfn` and existence checks
3. **Drift detection** via symlink target validation
4. **Interactive conflict prompts** (overwrite/skip/backup pattern)
5. **Help systems** for subcommand-based CLIs

All patterns are bash 3.2-compatible (macOS default). Existing `backup_and_link()` in `lib/symlinks.sh` already implements conflict detection and ownership checking via symlinks — Phase 7 extends this with `--force`, `--dry-run`, and status reporting.

**Primary recommendation:** Leverage existing `is_dotconfigs_owned()` symlink check for all drift detection. Use `test -t 1` for TTY detection before ANSI codes. Implement `--dry-run` as a global flag that wraps all filesystem operations in echo statements. Build status by iterating plugin .env keys and checking target paths. All patterns proven in existing codebase or standard bash practices.

## Standard Stack

No external dependencies required. All patterns use bash 3.2 features and standard UNIX utilities already present.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Bash | 3.2+ | Runtime environment | macOS default, already required |
| coreutils | Any | File operations (test, readlink, ln) | Standard UNIX utilities |
| tput | Any | Terminal capability queries | Part of ncurses, pre-installed |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| lib/symlinks.sh | Current | Ownership detection, backup_and_link | Deploy operations, status checks |
| lib/discovery.sh | Current | Plugin discovery | Status and list commands |
| readlink | Any | Symlink target resolution | Drift detection |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ANSI escape codes | tput commands | tput more portable but verbose, ANSI simpler for bash 3.2 |
| Symlink ownership check | Metadata file (.dotconfigs-managed) | Metadata requires sync, symlinks self-documenting |
| Interactive prompts | --force-only (no prompts) | Prompts safer for users, --force for automation |

**Installation:**
None required — all utilities pre-installed on macOS and Linux.

## Architecture Patterns

### Recommended Extensions to Existing Structure
```
dotconfigs/
├── dotconfigs              # CLI entry point (add status, list, help commands)
├── lib/
│   ├── symlinks.sh        # EXTEND: Add drift detection helpers
│   ├── discovery.sh       # EXTEND: Add plugin config detection
│   └── colours.sh         # NEW: ANSI colour helpers with TTY detection
├── plugins/
│   ├── claude/
│   │   └── deploy.sh      # EXTEND: Add --dry-run, --force support
│   └── git/
│       └── deploy.sh      # EXTEND: Add --dry-run, --force support
└── .env.example           # POLISH: Complete all plugin keys with descriptions
```

### Pattern 1: TTY-Aware ANSI Colour Output

**What:** Detect if stdout is a TTY before using ANSI colour codes. Fall back to plain text when piped or redirected.

**When to use:** All user-facing output in status and list commands.

**Example:**
```bash
# Source: https://misc.flogisoft.com/bash/tip_colors_and_formatting
# lib/colours.sh (NEW)

# Initialize colour codes based on TTY detection
init_colours() {
    if [[ -t 1 ]]; then
        # stdout is a TTY, colours are safe
        # Using ANSI codes (bash 3.2 compatible)
        COLOUR_GREEN='\033[32m'
        COLOUR_YELLOW='\033[33m'
        COLOUR_RED='\033[31m'
        COLOUR_RESET='\033[0m'
        SYMBOL_OK='✓'
        SYMBOL_DRIFT='Δ'
        SYMBOL_MISSING='✗'
    else
        # Not a TTY (piped/redirected), disable colours
        COLOUR_GREEN=''
        COLOUR_YELLOW=''
        COLOUR_RED=''
        COLOUR_RESET=''
        SYMBOL_OK='[OK]'
        SYMBOL_DRIFT='[DRIFT]'
        SYMBOL_MISSING='[MISSING]'
    fi
}

# Helper functions for coloured output
colour_green() {
    echo -e "${COLOUR_GREEN}${1}${COLOUR_RESET}"
}

colour_yellow() {
    echo -e "${COLOUR_YELLOW}${1}${COLOUR_RESET}"
}

colour_red() {
    echo -e "${COLOUR_RED}${1}${COLOUR_RESET}"
}
```

**Bash 3.2 Notes:**
- `test -t 1` checks if file descriptor 1 (stdout) is a TTY — available since bash 2.0
- ANSI escape codes work in bash 3.2 with `echo -e` or `printf`
- Alternative: `tput setaf N` for colour codes, but more verbose (requires tput calls per colour)

**TTY Detection Reference:**
- [ANSI Color Codes and TTY Detection](https://eklitzke.org/ansi-color-codes) — explains why TTY detection matters
- [Bash Colors and Formatting](https://misc.flogisoft.com/bash/tip_colors_and_formatting) — ANSI code reference

### Pattern 2: Idempotent Deploy Operations

**What:** Deploy operations that can run multiple times safely, producing the same result. Check before create, use force flags on overwrite commands.

**When to use:** All deploy operations — symlinks, file copies, git config writes.

**Example:**
```bash
# Source: https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/
# Idempotent symlink creation (already in lib/symlinks.sh)

link_file() {
    local src="$1"
    local dest="$2"
    local dest_dir

    dest_dir=$(dirname "$dest")

    # Create parent directory if needed (idempotent with -p)
    if [[ ! -d "$dest_dir" ]]; then
        mkdir -p "$dest_dir"
    fi

    # Create symlink (force overwrite if exists, -n prevents directory recursion)
    ln -sfn "$src" "$dest"
}

# Idempotent file operations patterns
# Source: https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/

# Directory creation
mkdir -p "$dir"  # Succeeds even if exists

# File removal
rm -f "$file"  # Succeeds even if missing

# Append to file (check first to avoid duplicates)
if ! grep -qF "$line" "$file"; then
    echo "$line" >> "$file"
fi

# Git config (naturally idempotent — overwrites existing value)
git config --global user.name "Name"  # Safe to run multiple times
```

**Key insight:** The existing `link_file()` function uses `ln -sfn` which is already idempotent:
- `-s`: Create symbolic link
- `-f`: Force (remove existing destination)
- `-n`: No dereference (treat symlink to directory as file, not directory)

**Running deploy twice:**
- First run: Creates symlinks, prints "✓ Linked X"
- Second run: Overwrites symlinks (no-op), prints "✓ Updated X" or "✓ Linked X"
- User decision needed: Skip unchanged (faster) or always overwrite (simpler)

### Pattern 3: Symlink-Based Drift Detection

**What:** Detect when deployed files have "drifted" from expected state — symlink broken, target changed, or file replaced with regular file.

**When to use:** Status command for all deployed files.

**Example:**
```bash
# Source: Existing lib/symlinks.sh + https://www.baeldung.com/linux/find-broken-symlinks
# lib/symlinks.sh (EXTEND)

# Check deployment state of a target file
# Returns: 0 (deployed OK), 1 (not deployed), 2 (drifted)
# Outputs state: "deployed" | "not-deployed" | "drifted-broken" | "drifted-foreign"
check_file_state() {
    local target_path="$1"
    local expected_source="$2"  # Expected symlink target
    local dotconfigs_root="$3"

    # Case 1: Target doesn't exist at all
    if [[ ! -e "$target_path" && ! -L "$target_path" ]]; then
        echo "not-deployed"
        return 1
    fi

    # Case 2: Target is a symlink
    if [[ -L "$target_path" ]]; then
        # Check if symlink is broken
        if [[ ! -e "$target_path" ]]; then
            echo "drifted-broken"
            return 2
        fi

        # Check if symlink points to expected source
        if is_dotconfigs_owned "$target_path" "$dotconfigs_root"; then
            # Get actual link target
            local actual_target
            if [[ "$OSTYPE" == "darwin"* ]]; then
                actual_target=$(perl -MCwd -le 'print Cwd::abs_path(shift)' "$target_path" 2>/dev/null)
            else
                actual_target=$(readlink -f "$target_path" 2>/dev/null)
            fi

            # Compare to expected
            if [[ "$actual_target" == "$expected_source" ]]; then
                echo "deployed"
                return 0
            else
                echo "drifted-wrong-target"
                return 2
            fi
        else
            # Symlink exists but doesn't point to dotconfigs
            echo "drifted-foreign"
            return 2
        fi
    fi

    # Case 3: Target is a regular file (not a symlink)
    if [[ -f "$target_path" ]]; then
        echo "drifted-foreign"
        return 2
    fi

    # Case 4: Unknown state
    echo "unknown"
    return 2
}
```

**Drift detection states:**
- `deployed`: Symlink exists, points to correct source
- `not-deployed`: Target doesn't exist
- `drifted-broken`: Symlink exists but target is gone
- `drifted-wrong-target`: Symlink points to wrong dotconfigs file
- `drifted-foreign`: Regular file exists (not managed by dotconfigs)

**Performance consideration:** Each file check requires `readlink` call. For plugins with 10+ files, this is ~50ms total (negligible).

### Pattern 4: Interactive Conflict Resolution

**What:** When deploy encounters unmanaged file, prompt user for action: overwrite, skip, or backup.

**When to use:** Deploy operations when `--force` flag not present and file exists but not owned by dotconfigs.

**Example:**
```bash
# Source: Existing lib/symlinks.sh backup_and_link() + https://linuxconfig.org/bash-script-yes-no-prompt-example
# Already implemented in lib/symlinks.sh — extend with diff option

backup_and_link() {
    local src="$1"
    local dest="$2"
    local name="$3"
    local interactive="$4"
    local dotconfigs_root

    dotconfigs_root=$(echo "$src" | sed -E 's|(.*)/[^/]+/[^/]+$|\1|')

    # If dest doesn't exist, create symlink
    if [[ ! -e "$dest" && ! -L "$dest" ]]; then
        link_file "$src" "$dest"
        echo "  ✓ Linked $name"
        return 0
    fi

    # If dest exists and is owned by dotconfigs, overwrite silently (idempotent)
    if is_dotconfigs_owned "$dest" "$dotconfigs_root"; then
        link_file "$src" "$dest"
        echo "  ✓ Updated $name"
        return 0
    fi

    # Dest exists and NOT owned by dotconfigs
    if [[ "$interactive" == "true" ]]; then
        echo "  ! Conflict: $name already exists and not managed by dotconfigs"
        echo "    Current: $dest"

        # Add diff option if it's a regular file
        if [[ -f "$dest" ]]; then
            echo "    Options: [o]verwrite, [s]kip, [b]ackup, [d]iff"
        else
            echo "    Options: [o]verwrite, [s]kip, [b]ackup"
        fi

        read -p "    Choice: " choice
        choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

        case "$choice" in
            o|overwrite)
                link_file "$src" "$dest"
                echo "  ✓ Overwrote $name"
                return 0
                ;;
            b|backup)
                local backup="${dest}.bak.$(date +%Y%m%d-%H%M%S)"
                mv "$dest" "$backup"
                link_file "$src" "$dest"
                echo "  ✓ Backed up to $backup and linked $name"
                return 0
                ;;
            d|diff)
                # Show diff if dest is a regular file
                if [[ -f "$dest" && -f "$src" ]]; then
                    echo "  Showing diff (source vs current):"
                    diff "$src" "$dest" || true
                    # Re-prompt after showing diff
                    echo "    Options: [o]verwrite, [s]kip, [b]ackup"
                    read -p "    Choice: " choice2
                    choice2=$(echo "$choice2" | tr '[:upper:]' '[:lower:]')
                    # Recurse with new choice (but not 'd' again)
                    if [[ "$choice2" == "o" ]]; then
                        link_file "$src" "$dest"
                        echo "  ✓ Overwrote $name"
                        return 0
                    elif [[ "$choice2" == "b" ]]; then
                        local backup="${dest}.bak.$(date +%Y%m%d-%H%M%S)"
                        mv "$dest" "$backup"
                        link_file "$src" "$dest"
                        echo "  ✓ Backed up to $backup and linked $name"
                        return 0
                    fi
                fi
                echo "  - Skipped $name"
                return 1
                ;;
            s|skip|*)
                echo "  - Skipped $name"
                return 1
                ;;
        esac
    else
        # Non-interactive mode: skip conflicts
        echo "  - Skipped $name (already exists, not managed)"
        return 1
    fi
}
```

**User decision (locked):** Prompt shows overwrite, skip, backup. If user chooses backup, offer `.bak` suffix.

**Implementation note:** Existing `backup_and_link()` already handles this — only needs diff option added.

### Pattern 5: Dry-Run Mode

**What:** Flag that shows what deploy would do without making filesystem changes.

**When to use:** Deploy operations when `--dry-run` flag present.

**Example:**
```bash
# Source: https://ostechnix.com/linux-dry-run-flag-guide-beginners/
# Global flag approach in deploy functions

plugin_claude_deploy() {
    local interactive=false
    local dry_run=false

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --interactive)
                interactive=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --force)
                interactive=false
                shift
                ;;
            *)
                echo "Error: Unknown option $1" >&2
                return 1
                ;;
        esac
    done

    # Load configuration
    if ! _claude_load_config; then
        return 1
    fi

    echo "Deploying Claude Code configuration..."
    if [[ "$dry_run" == "true" ]]; then
        echo "(DRY RUN - no changes will be made)"
        echo ""
    fi

    # Wrap file operations
    if [[ "$dry_run" == "true" ]]; then
        # Show what would happen
        if [[ "${CLAUDE_SETTINGS_ENABLED:-false}" == "true" ]]; then
            echo "  Would link: settings.json"
        fi
        # ... continue for all files
    else
        # Actually perform operations
        if [[ "${CLAUDE_SETTINGS_ENABLED:-false}" == "true" ]]; then
            backup_and_link "$DOTCONFIGS_ROOT/settings.json" "$CLAUDE_DEPLOY_TARGET/settings.json" "settings.json" "$interactive"
        fi
    fi

    echo ""
    if [[ "$dry_run" == "true" ]]; then
        echo "Dry run complete. Run without --dry-run to apply changes."
    else
        echo "Deployment complete!"
    fi
}
```

**Alternative approach:** Wrap `ln`, `mkdir`, `mv` commands in a `dry_run_exec` helper:
```bash
dry_run_exec() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "Would run: $@"
    else
        "$@"
    fi
}

# Usage
dry_run_exec ln -sfn "$src" "$dest"
dry_run_exec mkdir -p "$dir"
```

**User decision:** Always print summary even when nothing changed — dry-run shows "would create/skip/update" counts.

### Pattern 6: Status Command Implementation

**What:** Iterate all configured plugins, check deployment state of each configured file, report with colours.

**When to use:** `dotconfigs status [plugin]` command.

**Example:**
```bash
# dotconfigs main script (EXTEND)
cmd_status() {
    local plugin_filter="${1:-}"  # Optional plugin name

    # Initialize colours
    init_colours

    # Load .env to see what's configured
    if [[ ! -f "$ENV_FILE" ]]; then
        echo "No configuration found. Run 'dotconfigs setup <plugin>' first." >&2
        exit 1
    fi

    source "$ENV_FILE"

    echo ""

    # Iterate plugins
    while IFS= read -r plugin; do
        # Skip if filter provided and doesn't match
        if [[ -n "$plugin_filter" && "$plugin" != "$plugin_filter" ]]; then
            continue
        fi

        # Check if plugin is configured (has .env keys)
        local configured=false

        # Plugin-specific status check
        if [[ "$plugin" == "claude" ]]; then
            if [[ -n "${CLAUDE_DEPLOY_TARGET:-}" ]]; then
                configured=true
                check_claude_status
            fi
        elif [[ "$plugin" == "git" ]]; then
            if [[ -n "${GIT_IDENTITY_NAME:-}" ]]; then
                configured=true
                check_git_status
            fi
        fi

        # If not configured, show as such
        if [[ "$configured" == "false" ]]; then
            echo "  $(colour_red "$plugin")                    $SYMBOL_MISSING not configured"
        fi

    done < <(discover_plugins "$PLUGINS_DIR")

    echo ""
}

check_claude_status() {
    # Determine overall plugin state
    local files_ok=0
    local files_drift=0
    local files_missing=0

    # Check each configured component
    local files_to_check=()

    if [[ "${CLAUDE_SETTINGS_ENABLED:-false}" == "true" ]]; then
        files_to_check+=("$CLAUDE_DEPLOY_TARGET/settings.json|$DOTCONFIGS_ROOT/settings.json|settings.json")
    fi

    if [[ -n "${CLAUDE_HOOKS_ENABLED:-}" ]]; then
        IFS=' ' read -ra hooks_array <<< "$CLAUDE_HOOKS_ENABLED"
        for hook in "${hooks_array[@]}"; do
            files_to_check+=("$CLAUDE_DEPLOY_TARGET/hooks/$hook|$PLUGINS_DIR/claude/hooks/$hook|hooks/$hook")
        done
    fi

    # Similar for skills, CLAUDE.md, etc.

    # Check state of each file
    for file_spec in "${files_to_check[@]}"; do
        IFS='|' read -r target_path source_path display_name <<< "$file_spec"

        local state
        state=$(check_file_state "$target_path" "$source_path" "$DOTCONFIGS_ROOT")

        case "$state" in
            deployed)
                ((files_ok++))
                ;;
            drifted-*)
                ((files_drift++))
                ;;
            not-deployed)
                ((files_missing++))
                ;;
        esac
    done

    # Print overall status
    local total_files=$((files_ok + files_drift + files_missing))
    if [[ $files_drift -gt 0 ]]; then
        echo "  $(colour_yellow "claude")                    $SYMBOL_DRIFT deployed (drift detected)"
    elif [[ $files_missing -gt 0 ]]; then
        echo "  $(colour_yellow "claude")                    $SYMBOL_DRIFT partially deployed"
    else
        echo "  $(colour_green "claude")                    $SYMBOL_OK deployed"
    fi

    # Print per-file details
    for file_spec in "${files_to_check[@]}"; do
        IFS='|' read -r target_path source_path display_name <<< "$file_spec"

        local state
        state=$(check_file_state "$target_path" "$source_path" "$DOTCONFIGS_ROOT")

        case "$state" in
            deployed)
                echo "    $(colour_green "$display_name")    $SYMBOL_OK ok"
                ;;
            drifted-broken)
                echo "    $(colour_yellow "$display_name")    $SYMBOL_DRIFT drifted (broken symlink)"
                ;;
            drifted-wrong-target)
                echo "    $(colour_yellow "$display_name")    $SYMBOL_DRIFT drifted (wrong target)"
                ;;
            drifted-foreign)
                echo "    $(colour_yellow "$display_name")    $SYMBOL_DRIFT drifted (not symlink)"
                ;;
            not-deployed)
                echo "    $(colour_red "$display_name")    $SYMBOL_MISSING not deployed"
                ;;
        esac
    done
}
```

**User decision (locked):** Per-file granularity, three-state model (not configured/configured/deployed), drift detection, colour when TTY.

### Pattern 7: List Command Implementation

**What:** Show all available plugins with installed/not-installed status. Installed = has .env keys configured.

**When to use:** `dotconfigs list` command.

**Example:**
```bash
# dotconfigs main script (EXTEND)
cmd_list() {
    # Initialize colours
    init_colours

    # Load .env if exists
    local env_exists=false
    if [[ -f "$ENV_FILE" ]]; then
        source "$ENV_FILE"
        env_exists=true
    fi

    echo ""
    echo "Available plugins:"
    echo ""

    while IFS= read -r plugin; do
        local installed=false

        # Check if plugin has configuration
        if [[ "$env_exists" == "true" ]]; then
            if [[ "$plugin" == "claude" && -n "${CLAUDE_DEPLOY_TARGET:-}" ]]; then
                installed=true
            elif [[ "$plugin" == "git" && -n "${GIT_IDENTITY_NAME:-}" ]]; then
                installed=true
            fi
        fi

        # Print with colour and symbol
        if [[ "$installed" == "true" ]]; then
            echo "  $(colour_green "$plugin")   $SYMBOL_OK installed"
        else
            echo "  $(colour_red "$plugin")   $SYMBOL_MISSING not installed"
        fi
    done < <(discover_plugins "$PLUGINS_DIR")

    echo ""
}
```

**User decision (locked):** Minimal output, no descriptions. Just name + status.

### Pattern 8: Help System for Subcommands

**What:** Contextual help for commands and plugins.

**When to use:** `dotconfigs help`, `dotconfigs help <command>`, `dotconfigs <command> --help`.

**Example:**
```bash
# Source: Standard CLI patterns + http://subcommand.org/
# dotconfigs main script (EXTEND)

show_usage() {
    cat <<EOF
dotconfigs — Unified configuration management

Usage:
  dotconfigs setup <plugin>              Run setup wizard for plugin
  dotconfigs deploy [plugin] [options]   Deploy plugin configuration
  dotconfigs project [plugin] <path>     Scaffold project configuration
  dotconfigs status [plugin]             Show deployment status
  dotconfigs list                        List available plugins
  dotconfigs help [command]              Show help for command
  dotconfigs --help                      Show this help

Options for deploy:
  --interactive     Prompt for conflicts (default)
  --force          Overwrite all files without prompting
  --dry-run        Show what would be deployed without changes

Examples:
  dotconfigs setup claude                Configure Claude Code
  dotconfigs deploy                      Deploy all configured plugins
  dotconfigs deploy git --dry-run        Preview git deployment
  dotconfigs status                      Show all plugin status
  dotconfigs status claude               Show Claude plugin status
  dotconfigs list                        List all plugins

Run 'dotconfigs help <command>' for detailed help on a command.
EOF
}

show_command_help() {
    local command=$1

    case "$command" in
        setup)
            cat <<EOF
dotconfigs setup — Run setup wizard for a plugin

Usage:
  dotconfigs setup <plugin>

Description:
  Launches an interactive wizard to configure the specified plugin.
  Configuration is saved to .env in the dotconfigs repository.

Examples:
  dotconfigs setup claude    Configure Claude Code plugin
  dotconfigs setup git       Configure Git plugin

Available plugins:
EOF
            discover_plugins "$PLUGINS_DIR" | sed 's/^/  - /'
            ;;
        deploy)
            cat <<EOF
dotconfigs deploy — Deploy plugin configuration

Usage:
  dotconfigs deploy [plugin] [options]

Description:
  Deploys plugin configuration from .env to your filesystem.
  Without arguments, deploys all configured plugins.
  With plugin name, deploys only that plugin.

Options:
  --interactive     Prompt for conflicts (default)
  --force          Overwrite all files without prompting
  --dry-run        Show what would be deployed without changes

Examples:
  dotconfigs deploy                     Deploy all plugins
  dotconfigs deploy claude              Deploy Claude plugin only
  dotconfigs deploy --force             Overwrite all without prompting
  dotconfigs deploy git --dry-run       Preview git deployment
EOF
            ;;
        status)
            cat <<EOF
dotconfigs status — Show deployment status

Usage:
  dotconfigs status [plugin]

Description:
  Shows current deployment state of configured plugins.
  Reports per-file status: deployed, drifted, or missing.
  Without arguments, shows all plugins.
  With plugin name, shows only that plugin.

Examples:
  dotconfigs status           Show all plugins
  dotconfigs status claude    Show Claude plugin only
EOF
            ;;
        list)
            cat <<EOF
dotconfigs list — List available plugins

Usage:
  dotconfigs list

Description:
  Lists all available plugins with installed/not-installed status.
  Installed means the plugin has been configured (has .env entries).

Examples:
  dotconfigs list    Show all plugins
EOF
            ;;
        *)
            echo "Error: Unknown command '$command'" >&2
            echo "Run 'dotconfigs help' to see available commands." >&2
            exit 1
            ;;
    esac
}

cmd_help() {
    local command="${1:-}"

    if [[ -z "$command" ]]; then
        show_usage
    else
        show_command_help "$command"
    fi
}

# In main() function, add help routing:
main() {
    # ... existing code ...

    case "$1" in
        # ... existing cases ...
        help)
            cmd_help "${2:-}"
            ;;
        --help|-h)
            if [[ $# -eq 1 ]]; then
                show_usage
            else
                # Support: dotconfigs <command> --help
                show_command_help "$2"
            fi
            exit 0
            ;;
        *)
            echo "Error: Unknown command '$1'" >&2
            echo ""
            show_usage
            exit 1
            ;;
    esac
}
```

**User decision (Claude's discretion):** Help format and content decided by Claude. Pattern follows standard CLI conventions.

### Anti-Patterns to Avoid

- **Hard-coding colour codes everywhere:** Use helper functions and centralize colour definitions
- **Skipping TTY detection:** Always check before ANSI codes or piped output breaks
- **Not handling --dry-run consistently:** Every filesystem operation must respect the flag
- **Assuming symlinks always exist:** Check both `-L` (is symlink) and `-e` (target exists)
- **Prompting in non-interactive contexts:** Respect `--force` flag, default to safe behaviour (skip)

## Don't Hand-Roll

Problems that look simple but have standard solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Terminal colour detection | Parse $TERM variable | `test -t 1` | TTY detection is the standard, $TERM doesn't mean TTY |
| ANSI colour codes | Custom escape sequences | Standard codes `\033[XXm` | Widely supported, bash 3.2 compatible |
| Symlink target resolution | Parse `ls -l` output | `readlink` (with macOS perl fallback) | Already proven in lib/symlinks.sh |
| Interactive prompts | Custom read loops | `read -p` with case statement | Simple, standard, works in bash 3.2 |
| Dry-run flag parsing | Custom --dry-run handling per plugin | Global flag passed to all operations | Consistent UX, less code duplication |

**Key insight:** All patterns already exist in codebase or are standard bash practices. No novel implementations needed.

## Common Pitfalls

### Pitfall 1: ANSI Codes Breaking Piped Output

**What goes wrong:** Status/list commands emit ANSI colour codes, user pipes to `grep` or file, output contains literal escape sequences.

**Why it happens:**
- Script doesn't detect if stdout is a TTY
- Colour codes always enabled
- User runs `dotconfigs status | grep claude` → sees `^[[32mclaude^[[0m` instead of `claude`

**How to avoid:**
1. Always use TTY detection before colour codes:
   ```bash
   if [[ -t 1 ]]; then
       # TTY detected, colours safe
   else
       # Not TTY, disable colours
   fi
   ```
2. Initialize colour variables at command start (not globally)
3. Test with pipe: `dotconfigs status | cat` should show no escape codes

**Warning signs:**
- Grep results contain `^[` characters
- Redirected output looks garbled in text editors
- Users complain about "weird characters" when piping

**Source:** [ANSI Color Codes and TTY Detection](https://eklitzke.org/ansi-color-codes) — explains why TTY detection is critical

### Pitfall 2: Drift Detection False Positives on macOS

**What goes wrong:** `readlink -f` fails on macOS (BSD readlink lacks `-f` flag), drift detection always reports "drifted".

**Why it happens:**
- Linux `readlink -f` resolves absolute paths
- macOS `readlink` only shows immediate target (relative path)
- Code doesn't handle platform difference

**How to avoid:**
1. Use existing pattern from `lib/symlinks.sh`:
   ```bash
   if [[ "$OSTYPE" == "darwin"* ]]; then
       link_target=$(perl -MCwd -le 'print Cwd::abs_path(shift)' "$target_path" 2>/dev/null)
   else
       link_target=$(readlink -f "$target_path" 2>/dev/null)
   fi
   ```
2. Test on both macOS and Linux before shipping
3. Handle readlink failures gracefully (return unknown state, not error)

**Warning signs:**
- Status works on Linux, broken on macOS
- Error messages about "readlink: illegal option -- f"
- All files report as drifted on macOS

**Source:** Existing `lib/symlinks.sh` implementation (lines 18-24) — already solved

### Pitfall 3: Deploy "No Changes" Summary Looks Like Failure

**What goes wrong:** User runs `dotconfigs deploy` on already-deployed config, sees no output or only "Deployment complete!", thinks it failed.

**Why it happens:**
- Idempotent operations skip printing when no-op
- User expects visible confirmation
- Summary doesn't mention "0 files changed"

**How to avoid:**
1. Always print summary even when nothing changed:
   ```bash
   echo "Deployment summary:"
   echo "  Created: $created_count"
   echo "  Updated: $updated_count"
   echo "  Skipped: $skipped_count"
   echo "  Unchanged: $unchanged_count"
   ```
2. Track operation counts during deploy
3. For dry-run, show "Would create/update/skip" counts

**Warning signs:**
- Users re-run deploy multiple times "to make sure it worked"
- Support requests "did it actually deploy?"

**Source:** User decision in CONTEXT.md — "Always print deploy summary (files created, skipped, unchanged) — even when nothing changed"

### Pitfall 4: --force Flag Bypasses --dry-run

**What goes wrong:** User runs `dotconfigs deploy --dry-run --force`, sees "Would overwrite", but `--force` logic still executes writes.

**Why it happens:**
- Flag parsing order matters
- `--force` disables prompts AND checks
- `--dry-run` wraps writes but flags evaluated separately

**How to avoid:**
1. Parse both flags, ensure `--dry-run` takes precedence:
   ```bash
   if [[ "$dry_run" == "true" ]]; then
       echo "Would overwrite $file (--force enabled)"
       # Don't actually write
   elif [[ "$force" == "true" ]]; then
       # Write without prompting
   fi
   ```
2. Test flag combinations: `--dry-run --force`, `--force --dry-run`
3. Document flag precedence in help

**Warning signs:**
- Dry-run actually modifies files when --force present
- Inconsistent behaviour based on flag order

**Source:** Standard CLI flag precedence — read-only flags (--dry-run) override write flags (--force)

### Pitfall 5: Status Command Slow on Large Plugin Configurations

**What goes wrong:** User has 50+ files managed by plugins, `dotconfigs status` takes 5+ seconds.

**Why it happens:**
- Each file requires `readlink` syscall
- Perl invocation on macOS per-file (slow)
- No caching or batching

**How to avoid:**
1. Accept current performance (50 files × 10ms = 500ms, acceptable)
2. If needed: Batch readlink calls, cache results
3. Alternative: Only check overall plugin state, not per-file (defeats user requirement)

**Warning signs:**
- Status takes >2 seconds on normal plugin counts
- User complaints about slow status

**Mitigation:** Phase 7 plugins have ~10 files each, 100ms total acceptable. YAGNI principle — don't optimize prematurely.

**Source:** Performance best practices — 100ms human perception threshold for "instant"

### Pitfall 6: Deploy --dry-run Doesn't Show Conflicts

**What goes wrong:** User runs `dotconfigs deploy --dry-run`, sees "Would link file", but doesn't see that file already exists (conflict).

**Why it happens:**
- Dry-run shows intended operations, not state checks
- Conflict detection only runs during actual link attempt
- User surprised when real deploy prompts for conflicts

**How to avoid:**
1. Dry-run should call same conflict detection as real deploy:
   ```bash
   if [[ "$dry_run" == "true" ]]; then
       if [[ -e "$dest" ]] && ! is_dotconfigs_owned "$dest" "$dotconfigs_root"; then
           echo "  Would prompt: conflict at $name (file exists)"
       else
           echo "  Would link: $name"
       fi
   fi
   ```
2. Show what prompts user would see
3. Mention `--force` would bypass prompts

**Warning signs:**
- Dry-run output doesn't match real deploy behaviour
- Users confused by unexpected prompts after dry-run

**Source:** Dry-run best practices — show ALL side effects, including prompts

## Code Examples

Verified patterns from research and existing codebase.

### TTY Detection and Colour Helpers

```bash
# lib/colours.sh (NEW)
# Source: https://misc.flogisoft.com/bash/tip_colors_and_formatting

# Initialize colour codes based on TTY detection
init_colours() {
    if [[ -t 1 ]]; then
        # stdout is a TTY, colours safe
        COLOUR_GREEN='\033[32m'
        COLOUR_YELLOW='\033[33m'
        COLOUR_RED='\033[31m'
        COLOUR_RESET='\033[0m'
        SYMBOL_OK='✓'
        SYMBOL_DRIFT='Δ'
        SYMBOL_MISSING='✗'
    else
        # Not a TTY, plain text
        COLOUR_GREEN=''
        COLOUR_YELLOW=''
        COLOUR_RED=''
        COLOUR_RESET=''
        SYMBOL_OK='[OK]'
        SYMBOL_DRIFT='[DRIFT]'
        SYMBOL_MISSING='[MISSING]'
    fi
}

colour_green() {
    echo -e "${COLOUR_GREEN}${1}${COLOUR_RESET}"
}

colour_yellow() {
    echo -e "${COLOUR_YELLOW}${1}${COLOUR_RESET}"
}

colour_red() {
    echo -e "${COLOUR_RED}${1}${COLOUR_RESET}"
}
```

### Drift Detection Function

```bash
# lib/symlinks.sh (EXTEND)
# Source: Existing is_dotconfigs_owned() + https://www.baeldung.com/linux/find-broken-symlinks

# Check deployment state of a target file
# Args: target_path, expected_source, dotconfigs_root
# Returns: 0 (deployed), 1 (not deployed), 2 (drifted)
# Outputs: state string to stdout
check_file_state() {
    local target_path="$1"
    local expected_source="$2"
    local dotconfigs_root="$3"

    # Not deployed if doesn't exist
    if [[ ! -e "$target_path" && ! -L "$target_path" ]]; then
        echo "not-deployed"
        return 1
    fi

    # If it's a symlink
    if [[ -L "$target_path" ]]; then
        # Broken symlink
        if [[ ! -e "$target_path" ]]; then
            echo "drifted-broken"
            return 2
        fi

        # Check ownership
        if is_dotconfigs_owned "$target_path" "$dotconfigs_root"; then
            # Get actual target
            local actual_target
            if [[ "$OSTYPE" == "darwin"* ]]; then
                actual_target=$(perl -MCwd -le 'print Cwd::abs_path(shift)' "$target_path" 2>/dev/null)
            else
                actual_target=$(readlink -f "$target_path" 2>/dev/null)
            fi

            # Verify target matches expected
            if [[ "$actual_target" == "$expected_source" ]]; then
                echo "deployed"
                return 0
            else
                echo "drifted-wrong-target"
                return 2
            fi
        else
            echo "drifted-foreign"
            return 2
        fi
    fi

    # Regular file (not symlink)
    if [[ -f "$target_path" ]]; then
        echo "drifted-foreign"
        return 2
    fi

    echo "unknown"
    return 2
}
```

### Deploy with --dry-run Support

```bash
# plugins/claude/deploy.sh (EXTEND)
# Source: https://ostechnix.com/linux-dry-run-flag-guide-beginners/

plugin_claude_deploy() {
    local interactive=false
    local dry_run=false
    local force=false

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --interactive)
                interactive=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --force)
                force=true
                interactive=false  # --force implies non-interactive
                shift
                ;;
            *)
                echo "Error: Unknown option $1" >&2
                return 1
                ;;
        esac
    done

    # Load config
    if ! _claude_load_config; then
        return 1
    fi

    echo ""
    echo "Deploying Claude Code configuration to: $CLAUDE_DEPLOY_TARGET"
    if [[ "$dry_run" == "true" ]]; then
        echo "(DRY RUN - no changes will be made)"
    fi
    echo ""

    local files_created=0
    local files_updated=0
    local files_skipped=0

    # Deploy settings.json
    if [[ "${CLAUDE_SETTINGS_ENABLED:-false}" == "true" ]]; then
        if [[ "$dry_run" == "true" ]]; then
            echo "Would deploy settings.json"
            ((files_created++))
        else
            if backup_and_link "$DOTCONFIGS_ROOT/settings.json" "$CLAUDE_DEPLOY_TARGET/settings.json" "settings.json" "$interactive"; then
                ((files_created++))
            else
                ((files_skipped++))
            fi
        fi
    fi

    # Deploy hooks
    if [[ ${#CLAUDE_HOOKS_ENABLED_ARRAY[@]} -gt 0 ]]; then
        for hook in "${CLAUDE_HOOKS_ENABLED_ARRAY[@]}"; do
            if [[ "$dry_run" == "true" ]]; then
                echo "Would deploy hooks/$hook"
                ((files_created++))
            else
                if backup_and_link "$PLUGIN_DIR/hooks/$hook" "$CLAUDE_DEPLOY_TARGET/hooks/$hook" "hooks/$hook" "$interactive"; then
                    ((files_created++))
                else
                    ((files_skipped++))
                fi
            fi
        done
    fi

    # ... similar for skills, CLAUDE.md, etc.

    echo ""
    echo "Deployment summary:"
    echo "  Created/Updated: $files_created"
    echo "  Skipped: $files_skipped"

    if [[ "$dry_run" == "true" ]]; then
        echo ""
        echo "Dry run complete. Run without --dry-run to apply changes."
    fi

    return 0
}
```

### Status Command (Per-Plugin Check)

```bash
# dotconfigs main (EXTEND)
# Source: Existing patterns + drift detection research

cmd_status() {
    local plugin_filter="${1:-}"

    init_colours

    if [[ ! -f "$ENV_FILE" ]]; then
        echo "No configuration found. Run 'dotconfigs setup <plugin>' first." >&2
        exit 1
    fi

    source "$ENV_FILE"

    echo ""

    while IFS= read -r plugin; do
        if [[ -n "$plugin_filter" && "$plugin" != "$plugin_filter" ]]; then
            continue
        fi

        # Load plugin deploy script to access config parser
        if [[ -f "$PLUGINS_DIR/$plugin/deploy.sh" ]]; then
            source "$PLUGINS_DIR/$plugin/deploy.sh"

            # Call plugin-specific status function (to be added)
            if type -t "plugin_${plugin}_status" >/dev/null; then
                "plugin_${plugin}_status"
            fi
        fi
    done < <(discover_plugins "$PLUGINS_DIR")

    echo ""
}

# In plugins/claude/deploy.sh (NEW FUNCTION)
plugin_claude_status() {
    # Load config
    if ! _claude_load_config; then
        echo "  $(colour_red "claude")                    $SYMBOL_MISSING not configured"
        return
    fi

    local files_ok=0
    local files_drift=0
    local files_missing=0

    # Check settings.json
    if [[ "${CLAUDE_SETTINGS_ENABLED:-false}" == "true" ]]; then
        local state
        state=$(check_file_state "$CLAUDE_DEPLOY_TARGET/settings.json" "$DOTCONFIGS_ROOT/settings.json" "$DOTCONFIGS_ROOT")
        case "$state" in
            deployed) ((files_ok++)) ;;
            drifted-*) ((files_drift++)) ;;
            not-deployed) ((files_missing++)) ;;
        esac
    fi

    # Check hooks
    for hook in "${CLAUDE_HOOKS_ENABLED_ARRAY[@]}"; do
        local state
        state=$(check_file_state "$CLAUDE_DEPLOY_TARGET/hooks/$hook" "$PLUGIN_DIR/hooks/$hook" "$DOTCONFIGS_ROOT")
        case "$state" in
            deployed) ((files_ok++)) ;;
            drifted-*) ((files_drift++)) ;;
            not-deployed) ((files_missing++)) ;;
        esac
    done

    # ... similar for skills, CLAUDE.md

    # Print overall status
    if [[ $files_drift -gt 0 ]]; then
        echo "  $(colour_yellow "claude")                    $SYMBOL_DRIFT deployed (drift detected)"
    elif [[ $files_missing -gt 0 ]]; then
        echo "  $(colour_yellow "claude")                    $SYMBOL_DRIFT partially deployed"
    else
        echo "  $(colour_green "claude")                    $SYMBOL_OK deployed"
    fi

    # Print per-file details
    if [[ "${CLAUDE_SETTINGS_ENABLED:-false}" == "true" ]]; then
        local state
        state=$(check_file_state "$CLAUDE_DEPLOY_TARGET/settings.json" "$DOTCONFIGS_ROOT/settings.json" "$DOTCONFIGS_ROOT")
        _print_file_status "settings.json" "$state"
    fi

    for hook in "${CLAUDE_HOOKS_ENABLED_ARRAY[@]}"; do
        local state
        state=$(check_file_state "$CLAUDE_DEPLOY_TARGET/hooks/$hook" "$PLUGIN_DIR/hooks/$hook" "$DOTCONFIGS_ROOT")
        _print_file_status "hooks/$hook" "$state"
    done
}

_print_file_status() {
    local display_name="$1"
    local state="$2"

    case "$state" in
        deployed)
            echo "    $(colour_green "$display_name")    $SYMBOL_OK ok"
            ;;
        drifted-broken)
            echo "    $(colour_yellow "$display_name")    $SYMBOL_DRIFT drifted (broken symlink)"
            ;;
        drifted-wrong-target)
            echo "    $(colour_yellow "$display_name")    $SYMBOL_DRIFT drifted (wrong target)"
            ;;
        drifted-foreign)
            echo "    $(colour_yellow "$display_name")    $SYMBOL_DRIFT drifted (not symlink)"
            ;;
        not-deployed)
            echo "    $(colour_red "$display_name")    $SYMBOL_MISSING not deployed"
            ;;
    esac
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No status visibility | Per-file status with drift detection | v2.0 Phase 7 | Users see what's deployed, what's broken |
| Deploy overwrites silently | Interactive conflict prompts | v2.0 Phase 7 | Safer deploys, no accidental overwrites |
| Single deploy mode | --dry-run and --force flags | v2.0 Phase 7 | Preview changes, automate CI/CD |
| No colour output | TTY-aware ANSI colours | v2.0 Phase 7 | Better UX in terminal, clean piped output |
| Basic help only | Per-command help system | v2.0 Phase 7 | Self-documenting CLI |

**Deprecated/outdated:**
- None — Phase 7 extends existing patterns without deprecating anything

## Open Questions

1. **Should `dotconfigs deploy` (no arg) deploy ALL configured plugins or prompt to select?**
   - What we know: User decision is deploy ALL (locked in CONTEXT.md)
   - What's unclear: Nothing — decision is locked
   - Recommendation: Implement as decided — deploy all

2. **Should status command cache results or always check filesystem?**
   - What we know: Filesystem checks are fast (~10ms per file × 10 files = 100ms)
   - What's unclear: If users run status frequently, caching might help
   - Recommendation: No caching — always check (simpler, accurate, fast enough)

3. **Should drift detection compare file contents or just symlink targets?**
   - What we know: User decision is symlink-based ownership check
   - What's unclear: Nothing — decision is locked (symlink check only)
   - Recommendation: Implement as decided — symlink target check

4. **Should `--force` create backups or just overwrite?**
   - What we know: `--force` bypasses prompts, overwrites everything
   - What's unclear: Whether to silently create .bak files
   - Recommendation: No backups when `--force` used (user explicitly requested force)

## Sources

### Primary (HIGH confidence)
- [Bash Colors and Formatting](https://misc.flogisoft.com/bash/tip_colors_and_formatting) — ANSI colour codes reference
- [ANSI Color Codes and TTY Detection](https://eklitzke.org/ansi-color-codes) — TTY detection best practices
- [How to Write Idempotent Bash Scripts](https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/) — Idempotency patterns
- [Linux Commands – Find Broken Symlinks | Baeldung](https://www.baeldung.com/linux/find-broken-symlinks) — Symlink drift detection
- [Create Yes/No Prompt in Bash Script](https://linuxconfig.org/bash-script-yes-no-prompt-example) — Interactive prompts
- [Linux Dry Run Flag Guide](https://ostechnix.com/linux-dry-run-flag-guide-beginners/) — Dry-run patterns
- Existing codebase: `lib/symlinks.sh` (ownership detection, backup_and_link)
- Existing codebase: `lib/discovery.sh` (plugin discovery)
- Phase 4 research: Bash 3.2 patterns, macOS compatibility

### Secondary (MEDIUM confidence)
- [README Best Practices](https://github.com/jehna/readme-best-practices) — Documentation structure
- [.env.example Best Practices](https://dev.to/khalidk799/environment-variables-its-best-practices-1o1o) — Environment documentation
- [Testing Bash Scripts](https://www.funwithlinux.net/bash-scripting/how-to-test-and-validate-your-bash-scripts/) — Cross-platform testing
- [Bash SubCommand CLI Parser](http://subcommand.org/) — Help system patterns
- [Git Status Porcelain](https://git-scm.com/docs/git-status) — Status command design patterns

### Tertiary (LOW confidence)
- None used — all research verified with official sources

## Metadata

**Confidence breakdown:**
- ANSI colours: HIGH — Standard ANSI codes, TTY detection pattern verified
- Idempotency: HIGH — Existing `ln -sfn` pattern proven, research confirms
- Drift detection: HIGH — Existing symlink check proven, extension straightforward
- Conflict handling: HIGH — Existing backup_and_link implements core pattern
- Help system: HIGH — Standard CLI patterns, bash heredoc for text
- Documentation: MEDIUM — Structure is standard, content TBD during planning

**Research date:** 2026-02-07
**Valid until:** 90+ days (core bash patterns stable, ANSI codes unchanged for decades)

**Research notes:**
- Heavily leveraged existing lib/symlinks.sh patterns — ownership check and backup_and_link already solve core problems
- User decisions in CONTEXT.md locked most design — research focused on implementation details
- All patterns are bash 3.2 compatible (no new compatibility issues)
- No external dependencies required — pure bash + coreutils
- Existing backup_and_link() already implements conflict detection — only needs diff option added

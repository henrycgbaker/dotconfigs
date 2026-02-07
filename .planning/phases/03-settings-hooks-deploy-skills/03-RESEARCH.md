# Phase 3: Settings, Hooks, Deploy & Skills - Research

**Researched:** 2026-02-06
**Domain:** Bash deployment systems, Git hooks, Claude Code configuration, dotfiles management
**Confidence:** HIGH

## Summary

Phase 3 consolidates the dotclaude repo into a production-ready deployment system. Research covered Claude Code settings.json behaviour (including known bugs), git core.hooksPath mechanics, bash wizard patterns, symlink-based deployment portability, and CLAUDE.md build approaches.

**Key findings:**
- Claude Code deny rules are completely broken (#6699, #8961) — PreToolUse hooks are the only workaround
- Git core.hooksPath fully replaces .git/hooks/ (doesn't merge) — requires config-driven hook behaviour
- Bash select statement provides native menu system; readlink portability requires -f flag handling
- Symlink-based deployment is the standard dotfiles pattern (GNU Stow approach)
- CLAUDE.md build best done via concatenation with conditional sections

**Primary recommendation:** Accept Claude Code bugs as documented, use PreToolUse workaround for sensitive files, implement config-driven hooks with core.hooksPath, use bash select for wizards, symlink everything except CLAUDE.md (which should be built).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**GSD Coexistence:**
- Symlinks as ownership mechanism — dotclaude always deploys symlinks pointing back to the repo, never copies (exception: CLAUDE.md is built)
- Ownership detection: `readlink` — if it points to dotclaude repo, it's ours
- GSD files are never touched — GSD manages its own namespace (`agents/gsd-*`, `commands/gsd/*`, `hooks/gsd-*.js`)
- Conflict resolution (interactive): warn per-file, prompt overwrite / skip / backup-then-link (.bak). Non-interactive mode: skip conflicts
- Remote deployment: clone dotclaude repo on remote machine, then symlink — same ownership model everywhere

**Deploy System Architecture:**
- Single `deploy.sh` with subcommands: `deploy.sh global` (sets up ~/.claude/) and `deploy.sh project` (scaffolds a specific project)
- .env-driven configuration: all choices stored in `.env` (gitignored). `.env.example` committed with all settings documented. Each machine has its own `.env`
- `deploy.sh` reads `.env` from repo root. First run without `.env` triggers wizard. Re-runs read `.env` silently. `--interactive` re-runs wizard
- Non-interactive mode: `deploy.sh global --target DIR` (and other flags) skips wizard entirely

**Global Deploy Wizard (`deploy.sh global`):**
- Step-by-step sequential prompts (8 steps): deploy target, settings.json config, CLAUDE.md sections, hooks enable/disable, skills selection, GSD install, git identity, conflict review
- Dynamic discovery — wizard scans repo directories to find available hooks/skills/agents/rules. No hardcoded lists

**Project Deploy Wizard (`deploy.sh project`):**
- Full wizard to guide users to best project setup
- Greenfield/brownfield detection — scans for existing `.claude/`, `CLAUDE.md`, `.git/info/exclude`
- Never blindly overwrites — same conflict resolution as global deploy
- Existing CLAUDE.md found → offer merge/append rather than replace
- Creates: `.claude/settings.json`, `CLAUDE.md`, `.git/info/exclude` entries, optional project commands
- Detects project type from existing files, adjusts defaults

**CLAUDE.md Build System:**
- CLAUDE.md is the ONE exception to symlinks-only — it is built (assembled/generated), not symlinked
- Single source CLAUDE.md with toggleable sections controlled by .env flags (e.g., `CLAUDE_SIMPLICITY=true`, `CLAUDE_GIT=true`, `CLAUDE_PYTHON=true`)
- deploy.sh assembles the final CLAUDE.md from section templates + .env settings

**Profile System:**
- No named profile presets — .env IS the profile
- Each .env flag controls a specific aspect (settings, CLAUDE.md sections, hooks, skills)
- Per-machine configuration: each deployment (local or remote) has its own .env

**Git Hooks (via core.hooksPath):**
- `core.hooksPath` set globally to `~/.claude/git-hooks/` — all repos use the same hook scripts automatically
- Hook scripts are config-driven: read per-project `.claude/hooks.conf` to determine behaviour
- Projects without `.claude/hooks.conf` get sensible defaults
- Universal rules baked into hooks (e.g., AI attribution check — always applies)
- Per-project rules controlled by config (e.g., `CONVENTIONAL_COMMITS=true/false`, `BRANCH_PROTECTION=warn/block`)
- `deploy.sh project` wizard creates `.claude/hooks.conf` with project-appropriate settings

**Hook Behaviour:**
- Auto-fix when safe: formatting hooks (ruff) auto-fix silently
- Validation hooks always block with explanation + suggested fix
- Main branch protection: default warn-only. Projects opt into hard block via `.claude/hooks.conf`

**Settings.json:**
- Ship settings.json with deny rules as specified (*.pem, *credentials*, *secret* → deny; .env → ask)
- Accept known Claude Code bugs (#6699, #8961) — no PreToolUse hook workaround
- Project settings.json overrides global (native Claude Code behaviour)

**Deploy & Scan Paths:**
- No hardcoded directories — dotclaude never creates new directories, deploys wherever the user specifies
- Deploy target path stored in .env (`DEPLOY_TARGET=~/.claude` or any path)
- Scan paths stored in .env (`SCAN_PATHS=~/Repositories,~/Projects` — comma-separated)
- Wizard scan setup: probe common dev dirs, show which exist, offer recursive scan to find `.claude/` dirs

**Registry Scanner:**
- Dual purpose: (1) feeds deploy wizard with available configs, (2) audits what's deployed across projects
- Scan paths read from .env
- Output: human-readable table by default, `--json` flag for machine-readable
- Reports: project path, configs found, sync status

**Skills:**
- /commit: relaxed on branches, conventional commit format on main
- /squash-merge: guides through full squash merge workflow
- /simplicity-check: on-demand complexity review against simplicity rules
- Skills deployed via symlinks

### Claude's Discretion

- Settings.json exact allow/deny/ask rule granularity beyond what's specified
- CLAUDE.md section template content and build mechanism
- Deploy wizard prompt wording and UX details
- Registry scanner implementation (script language, scan algorithm)
- Exact .claude/hooks.conf format and default values
- Project type detection heuristics

### Deferred Ideas (OUT OF SCOPE)

- Rename repo to "dotconfigs" — future milestone
- Cloud sync for .env — future consideration

</user_constraints>

## Standard Stack

The established tools for bash deployment systems and dotfiles management:

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Bash | 4.0+ | Shell scripting, wizards | Universal, built-in to macOS/Linux |
| Git | 2.9+ | Hooks via core.hooksPath | Standard version control, 2.9+ added core.hooksPath |
| readlink | POSIX | Symlink detection | Built-in, identifies dotclaude-owned files |
| ln -sfn | POSIX | Create symlinks | Standard symlink tool (-s=symlink, -f=force, -n=no-deref) |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| select | Bash 3.0+ | Interactive menus | Built-in bash statement for wizard prompts |
| git check-ignore | Git 1.8+ | Detect gitignored paths | Determine if .planning should be committed |
| ssh | OpenSSH | Remote deployment | Deploy to remote servers |
| Python 3.10+ | - | Hook scripts | Existing hooks/post-tool-format.py uses Python |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Bash select | dialog/whiptail | Dialog requires external dependency, select is built-in |
| Symlinks | Copies | Copies lose sync with repo, can't detect ownership |
| core.hooksPath | Per-repo .git/hooks/ | Per-repo hooks don't scale, can't share across projects |
| Python hooks | Bash hooks | Python already used in existing hooks, more robust for JSON parsing |

**Installation:**
```bash
# All tools are built-in to macOS/Linux, no installation needed
# Optional: GNU coreutils for greadlink on macOS
brew install coreutils  # macOS only, for greadlink
```

## Architecture Patterns

### Recommended Project Structure

```
dotclaude/
├── deploy.sh                    # Main deployment script with subcommands
├── .env                         # Gitignored, per-machine config
├── .env.example                 # Committed, documents all settings
├── settings.json                # Source of truth for settings
├── CLAUDE.md                    # Will be deprecated in favour of templates/
├── templates/
│   ├── claude-md/              # CLAUDE.md section templates
│   │   ├── 01-communication.md
│   │   ├── 02-language.md
│   │   ├── 03-simplicity.md
│   │   ├── 04-git.md
│   │   └── 05-python.md
│   ├── settings/               # settings.json templates
│   │   ├── base.json
│   │   ├── python.json
│   │   └── node.json
│   └── hooks-conf/             # .claude/hooks.conf templates
│       ├── default.conf
│       ├── strict.conf
│       └── permissive.conf
├── commands/                    # Skills (symlinked)
│   ├── commit.md
│   ├── squash-merge.md
│   └── simplicity-check.md
├── hooks/                       # Claude Code hooks (symlinked)
│   └── post-tool-format.py
├── githooks/                    # Git hooks (copied to ~/.claude/git-hooks/)
│   ├── commit-msg
│   └── pre-commit
├── scripts/                     # Supporting scripts
│   ├── registry-scan.sh
│   └── lib/                    # Shared bash functions
│       ├── wizard.sh           # Wizard prompts, select menus
│       ├── symlinks.sh         # Symlink creation, ownership detection
│       └── discovery.sh        # Dynamic scanning of repo contents
└── docs/
    └── usage-guide.md          # Existing comprehensive guide
```

### Pattern 1: .env-Driven Configuration

**What:** All deployment decisions stored in `.env` file, read by deploy.sh to determine behaviour.

**When to use:** Every deployment. First run generates .env via wizard, subsequent runs read it silently.

**Example:**
```bash
# .env (gitignored, per-machine)
DEPLOY_TARGET=~/.claude
SCAN_PATHS=~/Repositories,~/Projects,~/code
CLAUDE_SIMPLICITY=true
CLAUDE_GIT=true
CLAUDE_PYTHON=true
HOOKS_ENABLED=post-tool-format,commit-msg,pre-commit
SKILLS_ENABLED=commit,squash-merge,simplicity-check
GSD_INSTALL=true
GIT_USER_NAME=henrycgbaker
GIT_USER_EMAIL=henry.c.g.baker@gmail.com

# .env.example (committed, documents all settings)
# Deploy target directory
DEPLOY_TARGET=~/.claude

# Scan paths for registry scanner (comma-separated)
SCAN_PATHS=~/Repositories,~/Projects

# CLAUDE.md sections to include
CLAUDE_SIMPLICITY=true|false
CLAUDE_GIT=true|false
CLAUDE_PYTHON=true|false
# ... etc
```

**Source:** Standard dotenv pattern, widely used in deployment scripts.

### Pattern 2: Symlink Ownership Detection

**What:** Use `readlink` to determine if a file/directory is owned by dotclaude.

**When to use:** Before overwriting existing files during deployment. Prevents clobbering user's custom configs.

**Example:**
```bash
# Source: deploy.sh
is_dotclaude_owned() {
    local target="$1"
    local dotclaude_path="$2"

    if [ -L "$target" ]; then
        # Follow symlink
        local link_target
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS: readlink without -f flag
            link_target=$(readlink "$target")
        else
            # Linux: use -f for canonical path
            link_target=$(readlink -f "$target")
        fi

        # Check if points to dotclaude repo
        if [[ "$link_target" == "$dotclaude_path"* ]]; then
            return 0  # Owned by us
        fi
    fi
    return 1  # Not owned by us
}

# Usage
if is_dotclaude_owned "$HOME/.claude/CLAUDE.md" "$SCRIPT_DIR"; then
    echo "File owned by dotclaude, safe to update"
    ln -sfn "$SCRIPT_DIR/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
else
    echo "File not owned by dotclaude, asking user"
    # Prompt for overwrite/skip/backup
fi
```

**Portability note:** macOS `readlink` doesn't support `-f` flag. Check `$OSTYPE` and handle accordingly.

**Source:** [GNU readlink differences on macOS](https://gist.github.com/esycat/5279354)

### Pattern 3: Bash Select for Interactive Menus

**What:** Use bash built-in `select` statement for wizard prompts.

**When to use:** Interactive deployment wizard. Provides numbered menus without external dependencies.

**Example:**
```bash
# Source: Wizard prompts in deploy.sh

# Customize prompt
PS3="Select deployment target: "

options=("Local (~/.claude/)" "Remote (SSH)" "Custom path" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Local (~/.claude/)")
            DEPLOY_TARGET="$HOME/.claude"
            break
            ;;
        "Remote (SSH)")
            read -p "Enter SSH host: " SSH_HOST
            # ... remote deployment logic
            break
            ;;
        "Custom path")
            read -p "Enter target path: " DEPLOY_TARGET
            break
            ;;
        "Quit")
            exit 0
            ;;
        *)
            echo "Invalid option $REPLY"
            ;;
    esac
done

echo "DEPLOY_TARGET=$DEPLOY_TARGET" >> .env
```

**Benefits:**
- Built-in to bash 3.0+, no dependencies
- Automatically numbers options
- Handles invalid input gracefully
- Simple to implement

**Source:** [Baeldung: Creating a Simple Select Menu](https://www.baeldung.com/linux/shell-script-simple-select-menu)

### Pattern 4: Dynamic Discovery Pattern

**What:** Scan repo directories at runtime to discover available configs, hooks, skills. No hardcoded lists.

**When to use:** Wizard steps that list available options (hooks, skills, CLAUDE.md sections).

**Example:**
```bash
# Source: scripts/lib/discovery.sh

discover_hooks() {
    local hooks_dir="$1"
    local available_hooks=()

    # Find all executable files in hooks/ and githooks/
    for hook_file in "$hooks_dir"/hooks/* "$hooks_dir"/githooks/*; do
        if [ -f "$hook_file" ] && [ -x "$hook_file" -o "${hook_file##*.}" = "py" ]; then
            available_hooks+=("$(basename "$hook_file")")
        fi
    done

    echo "${available_hooks[@]}"
}

discover_claude_sections() {
    local templates_dir="$1/templates/claude-md"
    local sections=()

    for section_file in "$templates_dir"/*.md; do
        if [ -f "$section_file" ]; then
            # Extract section name from filename (e.g., 01-communication.md -> communication)
            local section_name=$(basename "$section_file" .md | sed 's/^[0-9]*-//')
            sections+=("$section_name")
        fi
    done

    echo "${sections[@]}"
}

# Usage in wizard
available_hooks=$(discover_hooks "$SCRIPT_DIR")
echo "Available hooks: $available_hooks"
```

**Benefits:**
- Adding new hooks/skills automatically appears in wizard
- No maintenance of hardcoded lists
- Self-documenting system

### Pattern 5: CLAUDE.md Build System

**What:** Concatenate section templates into final CLAUDE.md based on .env flags.

**When to use:** During deployment, assemble CLAUDE.md from enabled sections.

**Example:**
```bash
# Source: deploy.sh

build_claude_md() {
    local templates_dir="$1/templates/claude-md"
    local output_file="$2"
    local env_file="$3"

    # Source .env to get flags
    source "$env_file"

    # Start with empty file
    > "$output_file"

    # Add sections based on flags (in order)
    for section_file in "$templates_dir"/*.md; do
        local section_name=$(basename "$section_file" .md | sed 's/^[0-9]*-//')
        local env_var="CLAUDE_$(echo "$section_name" | tr '[:lower:]' '[:upper:]')"

        # Check if section is enabled (default: true if not specified)
        local enabled="${!env_var:-true}"

        if [ "$enabled" = "true" ]; then
            cat "$section_file" >> "$output_file"
            echo "" >> "$output_file"  # Blank line between sections
        fi
    done

    echo "Built CLAUDE.md with enabled sections"
}

# Usage
build_claude_md "$SCRIPT_DIR" "$HOME/.claude/CLAUDE.md" "$SCRIPT_DIR/.env"
```

**Alternative approach:** Use heredoc markers (`<<SECTION>>`) in templates, but simple concatenation is clearer.

**Source:** [Simple bash markdown template generation](https://www.owenyoung.com/en/blog/simple-bash-to-generate-template-markdown-file-for-the-initial-blog-post/)

### Pattern 6: Config-Driven Git Hooks

**What:** Hooks read per-project `.claude/hooks.conf` to determine behaviour. Universal rules (AI attribution) always apply, project rules are configurable.

**When to use:** Git hooks deployed via core.hooksPath need per-project behaviour without duplicating hook files.

**Example:**
```bash
# Source: githooks/pre-commit

# Load project-specific config if it exists
HOOK_CONFIG="$REPO_ROOT/.claude/hooks.conf"

# Defaults
CONVENTIONAL_COMMITS=false
BRANCH_PROTECTION=warn  # or "block"
RUFF_ENABLED=true

# Override with project config
if [ -f "$HOOK_CONFIG" ]; then
    source "$HOOK_CONFIG"
fi

# Universal rule: Always block AI attribution
# (this cannot be disabled)
if echo "$COMMIT_MSG" | grep -qiE '(Co-Authored-By.*Claude|AI-assisted)'; then
    echo "❌ ERROR: AI attribution detected"
    exit 1
fi

# Project-specific rule: Branch protection
if [ "$CURRENT_BRANCH" = "main" ]; then
    if [ "$BRANCH_PROTECTION" = "block" ]; then
        echo "❌ ERROR: Direct commits to main blocked"
        exit 1
    elif [ "$BRANCH_PROTECTION" = "warn" ]; then
        echo "⚠️  WARNING: Committing directly to main (allowed but discouraged)"
    fi
fi
```

**Config file format:**
```bash
# .claude/hooks.conf
CONVENTIONAL_COMMITS=true
BRANCH_PROTECTION=block
RUFF_ENABLED=true
```

**Source:** [Git config-driven hooks pattern](https://benjamintoll.com/2021/03/30/on-a-git-hook-pattern/)

### Anti-Patterns to Avoid

- **Hardcoding paths:** Never assume `~/Repositories` exists. Read from .env or probe dynamically.
- **Copying instead of symlinking:** Breaks sync with repo, prevents ownership detection.
- **Global core.hooksPath without config:** Hooks would apply same rules to all projects.
- **Blindly overwriting configs:** Check ownership first, prompt for conflicts.
- **Symlinked CLAUDE.md:** Prevents per-machine customization via .env flags.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Interactive terminal menus | Custom input loops | `bash select` statement | Built-in, handles numbering/validation automatically |
| Symlink management | Custom scripts | Standard `ln -sfn` + ownership checks | POSIX standard, widely understood pattern |
| .env parsing | Custom parser | `source .env` in bash | Native bash behaviour, handles quoting correctly |
| Git hook distribution | Manual copy scripts | `core.hooksPath` global config | Git built-in feature (2.9+), automatic |
| Dotfile deployment | Custom rsync scripts | Symlink-based pattern (GNU Stow approach) | Industry standard, clear ownership model |
| Permission rules (Claude Code) | settings.json deny | PreToolUse hooks | Deny rules are broken, hooks are only workaround |

**Key insight:** Bash has powerful built-ins (select, source, readlink) that handle edge cases better than custom implementations. Git's core.hooksPath is specifically designed for shared hooks. Existing hooks/post-tool-format.py demonstrates working PreToolUse pattern.

## Common Pitfalls

### Pitfall 1: Claude Code Deny Rules Don't Work

**What goes wrong:** Settings.json `deny` rules are completely ignored. Files explicitly denied (`.env`, `*.pem`, `.ssh/**`) are still accessible to Claude.

**Why it happens:** Critical bug in Claude Code (issues #6699, #8961). Deny permission system is non-functional as of version 2.0.8 (January 2026).

**How to avoid:**
1. Document that deny rules are broken but ship them anyway (future-proofing for when bug is fixed)
2. Use PreToolUse hooks as workaround for truly sensitive files
3. Existing hooks/post-tool-format.py demonstrates working hook pattern

**Warning signs:**
- Claude can read `.env` file despite `deny: ["Read(.env)"]`
- Git commands work despite `deny: ["Bash(git:*)"]`
- Project-level deny rules ignored even with `settings.local.json`

**Status:** Issue #6699 marked COMPLETED but functionality still broken in 2.0.8. Issue #8961 remains OPEN as critical security bug.

**Sources:**
- [Issue #6699: Critical Security Bug - deny permissions not enforced](https://github.com/anthropics/claude-code/issues/6699)
- [Issue #8961: Claude Code ignores deny rules - security vulnerability](https://github.com/anthropics/claude-code/issues/8961)
- [The Register: Claude Code ignores rules meant to block secrets](https://www.theregister.com/2026/01/28/claude_code_ai_secrets_files/)

### Pitfall 2: Git core.hooksPath Replaces, Doesn't Merge

**What goes wrong:** Setting `core.hooksPath` globally completely replaces `.git/hooks/`, breaking per-project tools like Husky or pre-commit framework.

**Why it happens:** Git's core.hooksPath is a replacement mechanism, not an addition. Any project with repository-specific hooks will have them ignored.

**How to avoid:**
1. Make hooks config-driven via `.claude/hooks.conf` per-project
2. Document that dotclaude hooks are global, project-specific tools are incompatible
3. Provide escape hatch: users can unset core.hooksPath for specific projects

**Warning signs:**
- Husky hooks stop working after setting core.hooksPath
- Pre-commit framework installs but doesn't run
- Project-specific validation hooks silently fail

**Workaround for compatibility:**
```bash
# In project where you need local hooks instead
git config core.hooksPath .git/hooks
# This overrides the global setting for this repo only
```

**Sources:**
- [Git docs: core.hooksPath](https://git-scm.com/docs/githooks)
- [Husky issue: global core.hooksPath prevents husky from functioning](https://github.com/typicode/husky/issues/391)

### Pitfall 3: COMMIT_EDITMSG Not Available in pre-commit

**What goes wrong:** Existing githooks/pre-commit reads `.git/COMMIT_EDITMSG` to validate commit message, but file contains stale data from previous commit.

**Why it happens:** `COMMIT_EDITMSG` is not populated until after the pre-commit hook runs. Pre-commit runs *before obtaining the proposed commit log message*.

**How to avoid:** Move commit message validation to `commit-msg` hook, which receives the message file as parameter.

**Code fix:**
```bash
# WRONG: githooks/pre-commit (current code, lines 89-130)
COMMIT_MSG_FILE="$REPO_ROOT/.git/COMMIT_EDITMSG"
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")  # Contains OLD message

# RIGHT: githooks/commit-msg
COMMIT_MSG_FILE=$1  # File passed as parameter
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")  # Contains CURRENT message
```

**Current bug:** Phase 1 documented this issue. Existing pre-commit hook at lines 89-130 validates commit message, but reads stale file.

**Warning signs:**
- Commit message validation triggers on wrong message
- Previous commit's message causes current commit to fail
- Validation inconsistent between commits

**Source:** [Git hooks documentation](https://git-scm.com/docs/githooks) - clearly states pre-commit runs "before obtaining the proposed commit log message"

### Pitfall 4: readlink Portability Between macOS and Linux

**What goes wrong:** Bash script uses `readlink -f` to get canonical path, works on Linux, fails on macOS with "illegal option -- f".

**Why it happens:** BSD readlink (macOS) doesn't support `-f` flag for canonicalization. GNU readlink (Linux) does.

**How to avoid:**
```bash
# Portable approach
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS: basic readlink (or use greadlink from coreutils)
    link_target=$(readlink "$target")
else
    # Linux: use -f for canonical path
    link_target=$(readlink -f "$target")
fi

# Alternative: Check if greadlink is available (GNU coreutils on macOS)
if command -v greadlink &> /dev/null; then
    link_target=$(greadlink -f "$target")
else
    link_target=$(readlink "$target")
fi
```

**Warning signs:**
- Script works on Linux, fails on macOS with "illegal option"
- Symlink detection fails on macOS
- Error message: "readlink: illegal option -- f"

**Sources:**
- [GitHub Gist: How to get GNU's readlink -f on macOS](https://gist.github.com/esycat/5279354)
- [readlink portability across platforms](https://www.gnu.org/software/gnulib/manual/html_node/readlink.html)

### Pitfall 5: Assuming Directory Topology

**What goes wrong:** Deploy script assumes `~/Repositories` or `~/Projects` exists, breaks on users with different directory structures.

**Why it happens:** Developer's environment assumptions baked into script.

**How to avoid:**
1. Store scan paths in `.env` file
2. Wizard probes common directories, shows which exist
3. Allow user to specify custom paths
4. Never fail if expected directory doesn't exist

**Probe pattern:**
```bash
# Check common development directories
common_dirs=(
    "$HOME"
    "$HOME/Projects"
    "$HOME/code"
    "$HOME/src"
    "$HOME/Repositories"
    "$HOME/Developer"
    "$HOME/workspace"
)

existing_dirs=()
for dir in "${common_dirs[@]}"; do
    if [ -d "$dir" ]; then
        existing_dirs+=("$dir")
    fi
done

# Show user what exists, let them select/add
echo "Found development directories:"
for dir in "${existing_dirs[@]}"; do
    echo "  - $dir"
done
```

**Warning signs:**
- Script fails on fresh machines
- User's projects not discovered by registry scanner
- Hardcoded paths in script source

## Code Examples

Verified patterns from research and existing codebase:

### .env Loading Pattern

```bash
# Source: deploy.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    # Load existing config
    source "$ENV_FILE"
    echo "Loaded configuration from .env"
else
    # First run, trigger wizard
    echo "No .env found, running configuration wizard..."
    run_wizard
    # Wizard creates .env file
fi
```

### Symlink with Ownership Check

```bash
# Source: scripts/lib/symlinks.sh
backup_and_link() {
    local src="$1"
    local dest="$2"
    local name="$3"

    # Check if destination exists
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        # Check ownership
        if is_dotclaude_owned "$dest" "$SCRIPT_DIR"; then
            # Owned by us, safe to overwrite
            ln -sfn "$src" "$dest"
            echo "✓ Updated $name"
        else
            # Not owned by us, ask user
            echo "⚠️  $name exists and is not managed by dotclaude"
            read -p "Overwrite? (y/n/b for backup): " choice
            case "$choice" in
                y|Y)
                    ln -sfn "$src" "$dest"
                    echo "✓ Linked $name"
                    ;;
                b|B)
                    mv "$dest" "$dest.bak"
                    ln -sfn "$src" "$dest"
                    echo "✓ Backed up and linked $name"
                    ;;
                *)
                    echo "⊘ Skipped $name"
                    ;;
            esac
        fi
    else
        # Doesn't exist, create symlink
        ln -sfn "$src" "$dest"
        echo "✓ Linked $name"
    fi
}
```

### Wizard Select Menu

```bash
# Source: deploy.sh wizard

wizard_step_hooks() {
    echo ""
    echo "=== Step 4: Git Hooks ==="
    echo ""

    # Discover available hooks dynamically
    mapfile -t available_hooks < <(discover_hooks "$SCRIPT_DIR")

    HOOKS_ENABLED=()

    for hook in "${available_hooks[@]}"; do
        echo "Enable $hook?"
        PS3="Select: "
        options=("Yes" "No")
        select opt in "${options[@]}"; do
            case $opt in
                "Yes")
                    HOOKS_ENABLED+=("$hook")
                    break
                    ;;
                "No")
                    break
                    ;;
                *)
                    echo "Invalid option"
                    ;;
            esac
        done
    done

    # Save to .env
    echo "HOOKS_ENABLED=${HOOKS_ENABLED[*]}" >> "$ENV_FILE"
}
```

### PreToolUse Hook for Sensitive Files

```python
#!/usr/bin/env python3
# Source: hooks/protect-sensitive.py (NEW - workaround for deny bug)
"""PreToolUse hook to block access to sensitive files.

Workaround for Claude Code bug where deny rules are ignored.
Issues: #6699, #8961
"""

import sys
import json
from pathlib import Path

SENSITIVE_PATTERNS = {
    '.env', '.env.*', '*.pem', '*.key', '*credentials*',
    '*secret*', '.ssh/**', 'service-account.json'
}

def matches_sensitive_pattern(file_path: Path) -> bool:
    """Check if file matches any sensitive pattern."""
    file_name = file_path.name

    # Exact matches
    if file_name in SENSITIVE_PATTERNS:
        return True

    # Glob patterns
    for pattern in SENSITIVE_PATTERNS:
        if '*' in pattern:
            # Simple glob matching
            if pattern.startswith('*') and pattern.endswith('*'):
                # Contains pattern
                middle = pattern[1:-1]
                if middle in file_name:
                    return True
            elif pattern.startswith('*'):
                # Ends with pattern
                suffix = pattern[1:]
                if file_name.endswith(suffix):
                    return True
            elif pattern.endswith('*'):
                # Starts with pattern
                prefix = pattern[:-1]
                if file_name.startswith(prefix):
                    return True

        # Directory patterns (e.g., .ssh/**)
        if '/' in pattern:
            path_str = str(file_path)
            pattern_dir = pattern.split('/')[0]
            if pattern_dir in path_str:
                return True

    return False

def main() -> int:
    try:
        data = json.load(sys.stdin)
        tool_input = data.get('tool_input', {})
        file_path_str = tool_input.get('file_path')

        if not file_path_str:
            return 0  # No file path, allow

        file_path = Path(file_path_str)

        if matches_sensitive_pattern(file_path):
            error_message = (
                f"❌ BLOCKED: Access to '{file_path.name}' denied by security policy.\n"
                f"Reason: File matches sensitive pattern.\n"
                f"This protection is active because Claude Code deny rules are broken.\n"
                f"See: https://github.com/anthropics/claude-code/issues/8961"
            )
            print(error_message, file=sys.stderr)
            return 2  # Exit code 2 = BLOCK

        return 0  # Allow

    except (json.JSONDecodeError, KeyError) as e:
        print(f"Hook error: {e}", file=sys.stderr)
        return 0  # On error, allow (fail open)

if __name__ == "__main__":
    sys.exit(main())
```

**Settings to activate:**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "python ~/.claude/hooks/protect-sensitive.py"
          }
        ]
      }
    ]
  }
}
```

### Config-Driven Hook Pattern

```bash
# Source: githooks/pre-commit (refactored with config support)

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK_CONFIG="$REPO_ROOT/.claude/hooks.conf"

# Default configuration
CONVENTIONAL_COMMITS=${CONVENTIONAL_COMMITS:-false}
BRANCH_PROTECTION=${BRANCH_PROTECTION:-warn}
RUFF_ENABLED=${RUFF_ENABLED:-true}
BLOCK_AI_ATTRIBUTION=true  # Always true, cannot be disabled

# Load project config if exists
if [ -f "$HOOK_CONFIG" ]; then
    source "$HOOK_CONFIG"
fi

# Universal rule: Block AI attribution (always enforced)
if [ "$BLOCK_AI_ATTRIBUTION" = "true" ]; then
    if echo "$COMMIT_MSG" | grep -qiE '(Co-Authored-By.*Claude|AI-assisted)'; then
        echo "❌ ERROR: AI attribution detected in commit message"
        exit 1
    fi
fi

# Project-specific: Branch protection
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" = "main" ]; then
    case "$BRANCH_PROTECTION" in
        block)
            echo "❌ ERROR: Direct commits to main blocked by project policy"
            exit 1
            ;;
        warn)
            echo "⚠️  WARNING: Committing directly to main (discouraged)"
            # Continue
            ;;
        off)
            # No warning
            ;;
    esac
fi
```

**Project config file:**
```bash
# .claude/hooks.conf
# Created by: deploy.sh project

CONVENTIONAL_COMMITS=true
BRANCH_PROTECTION=block
RUFF_ENABLED=true
# BLOCK_AI_ATTRIBUTION cannot be changed (always true)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Per-repo .git/hooks/ | core.hooksPath global hooks | Git 2.9 (2016) | Enables shared hooks across all repos |
| Dotfiles via copies | Dotfiles via symlinks (GNU Stow pattern) | ~2010s | Clear ownership, stays in sync with repo |
| Manual .env parsing | Native bash `source .env` | Always available | Simpler, handles quoting correctly |
| settings.json deny rules | PreToolUse hooks as workaround | Bug exists since 2025 | Only reliable protection method |
| Hardcoded profiles | .env IS the profile | Modern config pattern | Per-machine flexibility |

**Deprecated/outdated:**
- **Copying settings.json:** Existing setup.sh copies instead of symlinks. Should symlink for global, project builds its own from templates.
- **Per-repo hook installation:** Existing setup.sh copies hooks to `.git/hooks/`. Phase 3 moves to global core.hooksPath.
- **Hardcoded repo paths:** Existing deploy-remote.sh assumes ~/dotclaude. Should read from .env or flag.
- **Relying on deny rules:** Known broken, but ship them anyway for future-proofing.

## Open Questions

### 1. Should settings.json be symlinked or built per-deployment?

**What we know:**
- Current setup.sh copies (not symlinks) settings.json
- Project settings override global (native Claude Code behaviour)
- Different projects need different permission rules

**What's unclear:**
- Should global settings.json be symlinked (single source of truth)?
- Or built/merged from templates like CLAUDE.md?

**Recommendation:** Symlink for global (`~/.claude/settings.json` → `dotclaude/settings.json`), build for projects. Project wizard assembles settings.json from templates + user choices. This allows per-project customization while keeping global settings synced.

### 2. How to handle PreToolUse hook for sensitive files?

**What we know:**
- Deny rules are broken (#6699, #8961)
- PreToolUse hooks can block operations (exit code 2)
- Existing hooks/post-tool-format.py demonstrates working pattern

**What's unclear:**
- Should protect-sensitive.py hook be installed by default?
- What files/patterns to block?
- How to avoid false positives blocking legitimate access?

**Recommendation:** Make it optional in wizard. Default to OFF (trust deny rules for now, future-proof), offer ON for paranoid mode. Document that it's a workaround for known bug. Provide conservative pattern list (.env, *.pem, *credentials*, *secret*). User can customize patterns in hook config.

### 3. Git identity handling in hooks

**What we know:**
- Current pre-commit hardcodes identity check (lines 33-49)
- Checks for specific user (henrycgbaker)
- Git identity should be configurable per-machine

**What's unclear:**
- Should hooks validate identity at all?
- If yes, where does expected identity come from?

**Recommendation:** Remove hardcoded identity check from hooks. Git already has user.name/email config. Deploy wizard asks for identity and sets it globally or per-project. Hooks don't validate identity (unnecessary — git requires identity to commit anyway). If validation needed, read expected identity from .claude/hooks.conf.

### 4. GSD installation mechanism

**What we know:**
- Current deploy-remote.sh runs `npx get-shit-done-cc --claude --global`
- GSD manages its own namespace (agents/gsd-*, commands/gsd/*)
- GSD installation is optional

**What's unclear:**
- Should deploy.sh invoke npx directly?
- Or provide instructions for user to run separately?
- How to handle GSD updates?

**Recommendation:** Wizard asks "Install GSD framework? (y/n)". If yes, run `npx get-shit-done-cc --claude --global` directly. Store choice in .env (`GSD_INSTALL=true/false`). On subsequent runs, check if GSD is installed, offer to install/update if not. GSD manages its own files, dotclaude never touches them.

### 5. Registry scanner output format

**What we know:**
- Dual purpose: (1) feed wizard with available configs, (2) audit deployed configs
- Output: human table by default, --json flag
- Should report: project path, configs found, sync status

**What's unclear:**
- What is "sync status" (up-to-date/outdated/custom)?
- How to determine if deployed config matches repo?

**Recommendation:** For symlinks, check if `readlink` points to dotclaude repo (owned=synced). For built files (CLAUDE.md), compare hash or timestamp against source templates. Report three states:
- ✓ Synced: symlink points to dotclaude repo
- ⚠️  Modified: file exists but not owned by dotclaude
- ✗ Missing: expected file doesn't exist

## Sources

### Primary (HIGH confidence)

**Git Official Documentation:**
- [Git Hooks Documentation](https://git-scm.com/docs/githooks) - Hook types, timing, parameters
- [Git check-ignore Documentation](https://git-scm.com/docs/git-check-ignore) - Debugging gitignore

**Claude Code GitHub Issues (verified bugs):**
- [Issue #6699: Critical Security Bug - deny permissions not enforced](https://github.com/anthropics/claude-code/issues/6699)
- [Issue #8961: Claude Code ignores deny rules in settings.local.json](https://github.com/anthropics/claude-code/issues/8961)

**Existing Dotclaude Codebase:**
- settings.json (line-by-line review)
- hooks/post-tool-format.py (working hook pattern)
- githooks/commit-msg, githooks/pre-commit (git hook patterns)
- setup.sh, deploy-remote.sh (existing deployment logic)
- docs/usage-guide.md (670 lines, comprehensive config guide)

### Secondary (MEDIUM confidence)

**Claude Code Configuration:**
- [A developer's guide to settings.json in Claude Code](https://www.eesel.ai/blog/settings-json-claude-code) - Settings hierarchy, layering behaviour
- [Claude Code settings documentation](https://code.claude.com/docs/en/settings) - Official settings docs

**Bash Scripting Best Practices:**
- [Baeldung: Creating a Simple Select Menu](https://www.baeldung.com/linux/shell-script-simple-select-menu) - Bash select statement patterns
- [Baeldung: Write a Bash Script That Answers Interactive Prompts](https://www.baeldung.com/linux/bash-interactive-prompts) - Interactive wizard patterns

**Dotfiles Management:**
- [GNU Stow for Dotfiles](https://simoninglis.com/posts/gnu-stow-dotfiles/) - Symlink-based deployment pattern
- [How to Manage Dotfiles With Git (Best Practices)](https://www.control-escape.com/linux/dotfiles/) - Dotfiles architecture patterns

**Git Hooks Patterns:**
- [On a Git Hook Pattern](https://benjamintoll.com/2021/03/30/on-a-git-hook-pattern/) - Config-driven hooks
- [GitHub: githooks - per-repo and global Git hooks](https://github.com/rycus86/githooks) - Global hooks management

**Portability:**
- [GitHub Gist: How to get GNU's readlink -f on macOS](https://gist.github.com/esycat/5279354) - readlink portability
- [GNU Gnulib: readlink](https://www.gnu.org/software/gnulib/manual/html_node/readlink.html) - POSIX portability notes

### Tertiary (LOW confidence)

**Markdown Assembly:**
- [Simple bash to generate template markdown file](https://www.owenyoung.com/en/blog/simple-bash-to-generate-template-markdown-file-for-the-initial-blog-post/) - Bash markdown templating (unverified approach)

**Directory Scanning:**
- [Vercel Open-Sources Bash Tool for Context Retrieval](https://www.infoq.com/news/2026/01/vercel-bash-tool/) - Recent bash tooling (mentions file scanning, not detailed)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All tools are POSIX standard or Git built-ins, verified availability
- Architecture: HIGH - Patterns verified in existing codebase and official docs
- Claude Code bugs: HIGH - Multiple verified GitHub issues with reproduction steps
- Bash patterns: MEDIUM - Best practices from tutorials, not formally standardized
- Hook config approach: MEDIUM - Pattern exists but not officially documented by Git
- CLAUDE.md build: LOW - Proposed approach, not yet implemented or verified
- Registry scanner specifics: LOW - Architecture decision, no prior art

**Research date:** 2026-02-06
**Valid until:** 60 days (stable technologies) except Claude Code bugs (monitor for fixes)

**Known gaps:**
- Exact .claude/hooks.conf format not standardized (design decision)
- Project type detection heuristics not researched (complex topic, out of scope)
- Remote deployment SSH key management not covered (assumed configured)
- GSD integration details not verified (GSD is separate project)

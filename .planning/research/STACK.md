# Technology Stack: dotconfigs v2.0 Plugin Architecture

**Project:** dotconfigs v2.0 (bash plugin architecture + git config management)
**Researched:** 2026-02-07
**Constraint:** Bash 3.2 compatibility (macOS default), no external dependencies

## Executive Summary

The v2.0 plugin architecture requires NO new external dependencies. All patterns leverage bash 3.2 features already in use (function-based routing, directory discovery, sourcing). The git plugin uses standard `git config` commands. This research identifies specific patterns and anti-patterns for bash 3.2 plugin systems based on existing frameworks (Bash-it, oh-my-bash) and current CLI design best practices.

## Core Stack (No Changes)

| Technology | Version | Purpose | Notes |
|------------|---------|---------|-------|
| Bash | 3.2+ | Core runtime | macOS ships 3.2.57, must avoid bash 4+ features |
| Git | 2.9+ | Git operations & config | core.hooksPath requires Git 2.9+ |
| coreutils | Any | File operations | Standard UNIX utilities (find, sed, ln) |

**Rationale:** Existing deploy.sh already demonstrates all needed capabilities. No new tools required.

## Plugin Architecture Patterns

### Pattern 1: Function-Based Subcommand Routing

**What:** Entry point dispatches to `cmd_<subcommand>` functions, which then dispatch to `plugin_<name>_<action>` functions.

**Why:** Already proven in deploy.sh (lines 627-1084). Bash 3.2 compatible. Exit code 127 detects missing functions naturally.

**Implementation:**
```bash
# Entry point: dotconfigs
subcommand=$1
shift

case "$subcommand" in
    setup|deploy)
        plugin=$1
        shift
        "cmd_${subcommand}" "$plugin" "$@"
        ;;
    *)
        show_usage
        exit 1
        ;;
esac

# Commands dispatch to plugin functions
cmd_setup() {
    local plugin=$1
    shift

    # Load plugin
    source "$PLUGINS_DIR/$plugin/setup.sh"

    # Call plugin's setup function
    "plugin_${plugin}_setup" "$@"
}
```

**Bash 3.2 Notes:**
- Use `"${var}"` not `${var,,}` (lowercase expansion not available)
- Use `tr '[:upper:]' '[:lower:]'` for case conversion
- No associative arrays — use simple variables or indexed arrays

**Source:** [Simple bash subcommands gist](https://gist.github.com/waylan/4080362)

### Pattern 2: Directory-Based Plugin Discovery

**What:** Plugins live in `plugins/<name>/` directories. Entry point discovers by listing directories.

**Why:** Already implemented in scripts/lib/discovery.sh. No registration file needed — filesystem IS the registry.

**Implementation:**
```bash
# Discovery (similar to existing discover_* functions)
discover_plugins() {
    local plugins_dir="$1"

    find "$plugins_dir" -mindepth 1 -maxdepth 1 -type d | while read -r plugin_path; do
        basename "$plugin_path"
    done | sort
}

# Validation
plugin_exists() {
    local plugin=$1
    [[ -d "$PLUGINS_DIR/$plugin" ]] && [[ -f "$PLUGINS_DIR/$plugin/setup.sh" ]]
}
```

**Rationale:** Avoids configuration files. Self-documenting. Same pattern as existing hooks/skills discovery.

**Source:** Existing scripts/lib/discovery.sh (lines 8-92)

### Pattern 3: Lazy Plugin Loading

**What:** Plugins are sourced only when invoked, not at script startup.

**Why:** Faster startup. Only load claude plugin if `dotconfigs deploy claude` called.

**Implementation:**
```bash
# Load plugin on-demand
load_plugin() {
    local plugin=$1
    local action=$2  # setup or deploy

    local plugin_script="$PLUGINS_DIR/$plugin/${action}.sh"

    if [[ ! -f "$plugin_script" ]]; then
        echo "Error: Plugin '$plugin' does not support '$action'" >&2
        return 1
    fi

    source "$plugin_script"
}
```

**Anti-pattern:** Loading all plugins at startup (slow, wasteful).

**Source:** Plugin architecture best practices — [Plugin Architecture Guide](https://www.devleader.ca/2023/09/07/plugin-architecture-design-pattern-a-beginners-guide-to-modularity/)

### Pattern 4: Shared Library Layer

**What:** Common utilities in `lib/*.sh` sourced by plugins and entry point.

**Why:** Avoid duplication between claude and git plugins. Already exists (wizard.sh, symlinks.sh, discovery.sh).

**Structure:**
```
lib/
  wizard.sh        # Interactive prompts (existing)
  symlinks.sh      # Link management (existing)
  discovery.sh     # Directory scanning (existing)
  validation.sh    # NEW: Common validation (git repo check, path validation)
```

**Implementation:**
```bash
# Entry point sources lib files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/wizard.sh"
source "$SCRIPT_DIR/lib/symlinks.sh"
source "$SCRIPT_DIR/lib/discovery.sh"
source "$SCRIPT_DIR/lib/validation.sh"

# Plugins assume lib functions available
plugin_claude_setup() {
    wizard_header 1 "Claude Configuration"
    wizard_yesno "Enable settings.json?" "y"
    # ...
}
```

**Rationale:** Plugins stay focused on domain logic. Shared code stays DRY.

### Pattern 5: Plugin Interface Contract

**What:** Each plugin provides `setup.sh` and `deploy.sh` with standard function signatures.

**Why:** Predictable interface. Entry point can call any plugin the same way.

**Contract:**
```bash
# plugins/<name>/setup.sh
plugin_<name>_setup() {
    # Interactive wizard
    # Writes to .env
}

# plugins/<name>/deploy.sh
plugin_<name>_deploy() {
    # Reads from .env
    # Performs deployment
    # Returns 0 on success
}
```

**Enforcement:** Entry point validates presence of required functions before calling.

**Source:** [Plugin architecture contracts](https://arjancodes.com/blog/best-practices-for-decoupling-software-using-plugins/)

## Git Config Management Patterns

### Pattern 6: Git Config Commands (Not Config Files)

**What:** Use `git config` commands, not direct editing of .gitconfig files.

**Why:** Atomic operations. Git handles locking and formatting. Cross-platform safe.

**Implementation:**
```bash
# Global config
git config --global user.name "Name"
git config --global user.email "email@example.com"
git config --global core.hooksPath "$HOOKS_DIR"

# Project-local config
git config --local --add include.path "$CONFIG_FILE"
```

**Anti-pattern:** sed/awk editing of .gitconfig (fragile, breaks on format changes).

**Source:** [Git Configuration Guide](https://git-scm.com/book/en/v2/Customizing-Git-Git-Configuration)

### Pattern 7: Git Config Include Files

**What:** Modular config files included via `[include]` and `[includeIf]` directives.

**Why:** Separation of concerns. Can conditionally apply config based on directory.

**Implementation:**
```bash
# Global ~/.gitconfig
[include]
    path = ~/.config/git/dotconfigs-workflow.conf

# Conditional by directory (work vs personal)
[includeIf "gitdir:~/work/"]
    path = ~/.config/git/work.conf
[includeIf "gitdir:~/personal/"]
    path = ~/.config/git/personal.conf
```

**Use Cases:**
- Workflow settings (rebase.autosquash, diff.algorithm) in dotconfigs-workflow.conf
- Identity switching by directory (work vs personal email)
- Project-specific hooks path overrides

**Source:** [Git includeIf patterns](https://utf9k.net/blog/conditional-gitconfig/)

### Pattern 8: Global Hooks via core.hooksPath

**What:** Set `core.hooksPath` to shared hooks directory. All repos use same hooks.

**Why:** Single source of truth. Already implemented in deploy.sh (lines 491-492).

**Existing Implementation:**
```bash
git config --global core.hooksPath "$DEPLOY_TARGET/git-hooks"
```

**Consideration:** Projects can override locally with:
```bash
git config --local core.hooksPath ".git/hooks"  # Use local hooks
```

**Source:** Already implemented; validated by [Git hooks management](https://jpearson.blog/2022/09/07/tip-share-a-git-hooks-directory-across-your-repositories/)

## CLI Entry Point Design

### Pattern 9: Single Entry Point with Subcommands

**What:** `dotconfigs` script routes to `setup <plugin>` and `deploy <plugin>` subcommands.

**Why:** Matches existing deploy.sh pattern. Familiar to users (git-style).

**Structure:**
```bash
#!/bin/bash
# dotconfigs — Entry point

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_DIR="$SCRIPT_DIR/plugins"

source "$SCRIPT_DIR/lib/wizard.sh"
source "$SCRIPT_DIR/lib/symlinks.sh"
source "$SCRIPT_DIR/lib/discovery.sh"

# Route to command
main() {
    case "$1" in
        setup|deploy)
            cmd_$1 "${@:2}"
            ;;
        list)
            cmd_list
            ;;
        --help|-h)
            show_usage
            ;;
        *)
            echo "Unknown command: $1" >&2
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
```

**Bash 3.2 Note:** `"${@:2}"` (slice array from index 2) works in bash 3.2+.

**Source:** [CLI Design Best Practices](https://clig.dev/)

### Pattern 10: Argument Forwarding to Plugins

**What:** Entry point validates subcommand/plugin, then forwards remaining args to plugin function.

**Why:** Plugins control their own argument parsing. Entry point stays thin.

**Implementation:**
```bash
cmd_setup() {
    local plugin=$1
    shift

    # Validate
    if [[ -z "$plugin" ]]; then
        echo "Error: No plugin specified" >&2
        echo "Usage: dotconfigs setup <plugin>" >&2
        exit 1
    fi

    if ! plugin_exists "$plugin"; then
        echo "Error: Plugin '$plugin' not found" >&2
        exit 1
    fi

    # Load and execute
    source "$PLUGINS_DIR/$plugin/setup.sh"
    "plugin_${plugin}_setup" "$@"
}
```

**Rationale:** Separation of concerns. Entry point = routing. Plugin = logic.

## Migration from deploy.sh

### What Moves Where

| Current (deploy.sh) | Future Location | Reason |
|---------------------|-----------------|--------|
| cmd_global() | plugins/claude/deploy.sh → plugin_claude_deploy() | Claude-specific |
| cmd_project() | plugins/claude/deploy.sh → plugin_claude_project() | Claude-specific |
| run_wizard() | plugins/claude/setup.sh → plugin_claude_setup() | Claude-specific wizard |
| build_claude_md() | plugins/claude/deploy.sh (internal) | Claude-specific |
| Git identity config | plugins/git/deploy.sh → plugin_git_deploy() | Git-specific |
| Git hooks copy | plugins/git/deploy.sh | Git-specific |
| Shell aliases setup | plugins/claude/deploy.sh | Claude-specific (aliases deploy command) |
| scripts/lib/*.sh | lib/*.sh (unchanged) | Shared library |
| Entry routing | dotconfigs (new) | Entry point |

### What Stays in Shared Lib

| Function | Location | Reason |
|----------|----------|--------|
| wizard_prompt() | lib/wizard.sh | Used by all plugins |
| wizard_yesno() | lib/wizard.sh | Used by all plugins |
| wizard_save_env() | lib/wizard.sh | Used by all plugins |
| backup_and_link() | lib/symlinks.sh | Used by claude + future plugins |
| is_dotclaude_owned() | lib/symlinks.sh | Used by claude + future plugins |
| discover_* functions | lib/discovery.sh | Used by multiple plugins |

## Bash 3.2 Compatibility Checklist

### Available Features (Safe to Use)

- [x] Functions
- [x] Indexed arrays (`arr=("a" "b" "c")`)
- [x] Case statements
- [x] Here-docs
- [x] Process substitution (`while read -r line; do ... done < <(command)`)
- [x] Subshells
- [x] `source` command
- [x] Exit code checking (`$?`)
- [x] String manipulation (`${var#prefix}`, `${var%suffix}`)

### Unavailable Features (Must Avoid)

- [ ] Namerefs (`local -n`)
- [ ] Associative arrays (`declare -A`)
- [ ] Lowercase expansion (`${var,,}`)
- [ ] Uppercase expansion (`${var^^}`)
- [ ] `readarray` / `mapfile`
- [ ] `;&` and `;;&` case terminators

### Workarounds

| Bash 4+ Feature | Bash 3.2 Workaround |
|-----------------|---------------------|
| `${var,,}` | `tr '[:upper:]' '[:lower:]'` or `echo "$var" \| tr ...` |
| `local -n ref=var` | Use `eval` cautiously or restructure to avoid indirection |
| `declare -A map` | Use indexed arrays with key encoding or avoid (restructure) |
| `readarray -t arr < file` | `while IFS= read -r line; do arr+=("$line"); done < file` |

**Source:** [Bash 3.2 compatibility notes](https://scriptingosx.com/2020/06/about-bash-zsh-sh-and-dash-in-macos-catalina-and-beyond/)

## What NOT to Add

### Anti-Pattern 1: Plugin Registry File

**Don't:** Create plugins.conf listing enabled plugins
**Why:** Filesystem already tells us what's available. Discovery function handles it.
**Existing proof:** scripts/lib/discovery.sh scans directories, no registry needed

### Anti-Pattern 2: Plugin Dependencies

**Don't:** Allow plugins to import from each other (`source ../git/config.sh`)
**Why:** Creates coupling. Use shared lib instead.
**Rule:** Plugins can only source from `lib/`, never from other plugins

### Anti-Pattern 3: Complex Configuration Language

**Don't:** Invent DSL or YAML for plugin config
**Why:** .env already works. Bash reads it natively. Additional format = additional parser.
**Keep:** Space-separated strings in .env (existing pattern for CLAUDE_SECTIONS, HOOKS_ENABLED)

### Anti-Pattern 4: Plugin Versioning

**Don't:** Add version fields to plugins or compatibility checking
**Why:** All plugins ship together in repo. No independent versioning needed.
**Scope:** Future problem if plugins become external repos (not v2.0 goal)

### Anti-Pattern 5: External Dependencies

**Don't:** Add jq, yq, or other tools for config parsing
**Why:** Breaks "bash + git + coreutils only" constraint
**Exception:** Python3 already used in deploy.sh for JSON merging (line 742), acceptable fallback when jq unavailable

### Anti-Pattern 6: Bash 4+ Features

**Don't:** Use namerefs, associative arrays, or bash 4 string operations
**Why:** Breaks macOS default bash 3.2
**Validation:** Test on macOS before committing

**Source:** Project constraints from PROJECT.md

## Directory Structure

```
dotconfigs/
├── dotconfigs              # New entry point
├── lib/                    # Shared libraries
│   ├── wizard.sh
│   ├── symlinks.sh
│   ├── discovery.sh
│   └── validation.sh       # NEW
├── plugins/
│   ├── claude/
│   │   ├── setup.sh        # Wizard → writes .env
│   │   ├── deploy.sh       # Reads .env → performs deployment
│   │   ├── hooks/          # Moved from top-level hooks/
│   │   ├── commands/       # Moved from top-level commands/
│   │   └── templates/      # Moved from top-level templates/
│   └── git/
│       ├── setup.sh        # Git identity, workflow prefs wizard
│       ├── deploy.sh       # Apply git config, deploy hooks
│       ├── hooks/          # Git hooks (commit-msg, pre-commit, etc)
│       └── templates/      # Git config snippets
├── .env                    # Unified config (all plugins)
└── deploy.sh               # DEPRECATED in v2.0, kept for migration period
```

**Rationale:** Each plugin is self-contained. Shared code in lib/. Entry point is thin router.

## Implementation Phases

### Phase 1: Create Entry Point + Routing

1. Create `dotconfigs` script with subcommand routing
2. Add `lib/validation.sh` for common checks
3. Test routing without plugins

### Phase 2: Extract Claude Plugin

1. Create `plugins/claude/` structure
2. Move wizard code to `plugins/claude/setup.sh`
3. Move deployment code to `plugins/claude/deploy.sh`
4. Move assets (hooks, commands, templates) to plugins/claude/

### Phase 3: Build Git Plugin

1. Create `plugins/git/` structure
2. Build git config wizard in `plugins/git/setup.sh`
3. Build git deployment in `plugins/git/deploy.sh`
4. Move githooks/ to plugins/git/hooks/

### Phase 4: Unify Configuration

1. Merge git identity vars into .env (already exists: GIT_USER_NAME, GIT_USER_EMAIL)
2. Add git workflow vars to .env (GIT_WORKFLOW_ENABLED, GIT_WORKFLOW_PRESET)
3. Update both plugins to read from .env

### Phase 5: Testing & Migration

1. Test on macOS (bash 3.2) and Linux (bash 4+)
2. Update README with new CLI
3. Mark deploy.sh as deprecated

## Confidence Assessment

| Pattern | Confidence | Source |
|---------|------------|--------|
| Function-based routing | HIGH | Existing deploy.sh, proven pattern |
| Directory discovery | HIGH | Existing scripts/lib/discovery.sh |
| Git config commands | HIGH | Official Git documentation |
| Git includeIf | MEDIUM | Feature exists since Git 2.13, needs testing |
| Bash 3.2 compat | HIGH | Existing deploy.sh works on macOS |
| Plugin interface contract | HIGH | Standard plugin pattern |
| Lazy loading | HIGH | Basic bash sourcing |
| Shared lib pattern | HIGH | Already implemented |

## Sources

### Official Documentation
- [Git Configuration](https://git-scm.com/book/en/v2/Customizing-Git-Git-Configuration)
- [Git config command](https://git-scm.com/docs/git-config)
- [Git hooks documentation](https://git-scm.com/docs/githooks)

### Architecture Patterns
- [Plugin Architecture Design Pattern](https://www.devleader.ca/2023/09/07/plugin-architecture-design-pattern-a-beginners-guide-to-modularity/)
- [Best Practices for Decoupling Software Using Plugins](https://arjancodes.com/blog/best-practices-for-decoupling-software-using-plugins/)
- [Plug-in Architecture Overview](https://medium.com/omarelgabrys-blog/plug-in-architecture-dec207291800)

### Bash Implementation Examples
- [Simple bash subcommands gist](https://gist.github.com/waylan/4080362)
- [Bash-it framework](https://github.com/Bash-it/bash-it)
- [Oh My Bash framework](https://github.com/ohmybash/oh-my-bash)

### CLI Design
- [Command Line Interface Guidelines](https://clig.dev/)
- [Mastering CLI Design Best Practices](https://jsschools.com/programming/mastering-cli-design-best-practices-for-powerful-/)

### Git Config Management
- [Conditional Git configuration](https://utf9k.net/blog/conditional-gitconfig/)
- [Modularizing git config with conditional includes](https://blog.thomasheartman.com/posts/modularizing-your-git-config-with-conditional-includes/)
- [Using includeIf to manage git identities](https://medium.com/@mrjink/using-includeif-to-manage-your-git-identities-bcc99447b04b)
- [Share Git Hooks Directory Across Repositories](https://jpearson.blog/2022/09/07/tip-share-a-git-hooks-directory-across-your-repositories/)

### Bash 3.2 Compatibility
- [About bash, zsh, sh, and dash in macOS](https://scriptingosx.com/2020/06/about-bash-zsh-sh-and-dash-in-macos-catalina-and-beyond/)
- [How to Ensure Bash Scripts Work on macOS and Linux](https://yomotherboard.com/question/how-to-ensure-bash-scripts-work-on-both-macos-and-linux/)
- [BashFAQ/006 - Arrays](https://mywiki.wooledge.org/BashFAQ/006)

### Additional References
- [Bash namerefs for dynamic variable referencing](https://rednafi.com/misc/bash-namerefs/) (Bash 4.3+ only - avoid)
- [Include Files in Bash with source](https://www.baeldung.com/linux/source-include-files)

---

**Research complete.** All patterns validated against bash 3.2 constraints. No external dependencies required. Ready for roadmap creation.

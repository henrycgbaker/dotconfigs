# Plugin Architecture for dotclaude

**Project:** dotclaude (Subsequent Milestone - Plugin System)
**Researched:** 2026-02-07
**Confidence:** HIGH

## Executive Summary

The dotclaude project needs to evolve from a monolithic `deploy.sh` (1085 lines) into a plugin-based architecture where Claude and Git configurations become independent, reusable plugins. Research into established bash configuration managers (Dot, bashdot, Modular Bashrc Manager, Oh My Bash) reveals consistent patterns: directory-based plugin discovery, minimal interface contracts, and symlink-based deployment.

**Recommended approach:** Strangler Fig Pattern migration—incrementally extract functionality into plugins while maintaining the existing monolith until migration is complete. This allows for safe, gradual refactoring with working code at every stage.

## Current Architecture Analysis

### Existing Components

```
dotclaude/
├── deploy.sh               # 1085 lines - monolithic orchestrator
│   ├── cmd_global()        # Global deployment wizard + execution
│   ├── cmd_project()       # Project scaffolding
│   └── deploy_remote()     # Remote deployment via SSH
├── scripts/lib/
│   ├── wizard.sh           # Interactive prompts (wizard_yesno, wizard_prompt, wizard_header)
│   ├── symlinks.sh         # Symlink management (backup_and_link, is_dotclaude_owned)
│   └── discovery.sh        # Content discovery (discover_hooks, discover_skills, discover_claude_sections)
├── .env                    # Flat key=value configuration
├── templates/
│   ├── claude-md/          # CLAUDE.md sections (01-communication.md, etc.)
│   ├── settings/           # Settings.json templates (base.json, python.json, node.json)
│   └── hooks-conf/         # Hooks.conf profiles (default.conf, strict.conf)
├── hooks/                  # Claude Code hooks (post-tool-format.py)
├── githooks/               # Git hooks (commit-msg, pre-commit)
└── commands/               # Skills (commit.md, squash-merge.md)
```

### Dependencies and Boundaries

**Current implicit dependencies:**
- `deploy.sh` depends on all of `scripts/lib/`
- `cmd_global()` knows about Claude-specific directories (templates/, hooks/, commands/)
- `cmd_global()` knows about Git-specific directories (githooks/)
- Wizard hardcodes 9 steps mixing Claude and Git concerns
- `.env` uses flat namespacing (DEPLOY_TARGET, CLAUDE_SECTIONS, HOOKS_ENABLED, GIT_USER_NAME)

**Natural boundaries identified:**
1. **Claude plugin scope:** CLAUDE.md sections, settings.json, hooks, skills
2. **Git plugin scope:** git hooks, git identity (user.name/email), core.hooksPath
3. **Shared libraries:** wizard, symlinks, discovery (remain in core)
4. **Core orchestrator:** entry point routing, plugin discovery, shared config

## Recommended Architecture

### Target Directory Structure

```
dotclaude/
├── dotclaude                    # Entry point script (replaces deploy.sh)
├── lib/                         # Core shared libraries
│   ├── wizard.sh
│   ├── symlinks.sh
│   ├── discovery.sh
│   └── plugin-loader.sh         # NEW: Plugin discovery and loading
├── plugins/
│   ├── claude/
│   │   ├── plugin.sh            # Plugin entry point
│   │   ├── setup-wizard.sh      # Claude-specific wizard steps
│   │   ├── deploy.sh            # Claude deployment logic
│   │   ├── templates/
│   │   │   ├── claude-md/       # CLAUDE.md sections
│   │   │   ├── settings/        # settings.json templates
│   │   │   └── hooks-conf/      # hooks.conf profiles
│   │   ├── hooks/               # Claude Code hooks
│   │   └── commands/            # Skills
│   └── git/
│       ├── plugin.sh            # Plugin entry point
│       ├── setup-wizard.sh      # Git-specific wizard steps
│       ├── deploy.sh            # Git deployment logic
│       └── githooks/            # Git hooks
└── .env                         # Configuration (plugin-namespaced)
```

### Plugin Interface Contract

Each plugin MUST provide a `plugin.sh` with the following interface:

```bash
# plugins/PLUGIN_NAME/plugin.sh

# Plugin metadata (required)
PLUGIN_NAME="plugin-name"
PLUGIN_DESCRIPTION="Brief description"
PLUGIN_VERSION="1.0.0"

# Subcommand handlers (all optional, implement as needed)
plugin_setup_wizard() {
    # Interactive configuration collection
    # Writes to .env via shared wizard functions
}

plugin_deploy_global() {
    # Deploy to global ~/.claude/ or equivalent
    # Reads from .env, uses shared symlink functions
}

plugin_deploy_project() {
    # Scaffold project-specific configuration
    # Args: project_path
}

plugin_deploy_remote() {
    # Remote deployment via SSH
    # Args: remote_host, method
}

plugin_validate() {
    # Optional: Validate plugin configuration
    # Returns: 0 if valid, 1 if invalid
}

plugin_list_dependencies() {
    # Optional: Declare dependencies on other plugins
    # Prints: space-separated list of plugin names
}
```

### Core Entry Point

**New `dotclaude` script structure:**

```bash
#!/bin/bash
# dotclaude — Modular dotfile configuration manager

DOTCLAUDE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTCLAUDE_LIB="$DOTCLAUDE_ROOT/lib"
DOTCLAUDE_PLUGINS="$DOTCLAUDE_ROOT/plugins"
ENV_FILE="$DOTCLAUDE_ROOT/.env"

# Source core libraries
source "$DOTCLAUDE_LIB/wizard.sh"
source "$DOTCLAUDE_LIB/symlinks.sh"
source "$DOTCLAUDE_LIB/discovery.sh"
source "$DOTCLAUDE_LIB/plugin-loader.sh"

# Main routing
case "$1" in
    global)
        shift
        cmd_global "$@"
        ;;
    project)
        shift
        cmd_project "$@"
        ;;
    plugin)
        shift
        cmd_plugin "$@"  # NEW: Direct plugin invocation
        ;;
    *)
        show_usage
        ;;
esac

# Core subcommand: global deployment
cmd_global() {
    # Load enabled plugins from .env: ENABLED_PLUGINS="claude git"
    local enabled_plugins=($(config_get "ENABLED_PLUGINS" "claude git"))

    # Run setup wizards for each plugin
    for plugin in "${enabled_plugins[@]}"; do
        plugin_load "$plugin"
        plugin_setup_wizard
    done

    # Deploy each plugin
    for plugin in "${enabled_plugins[@]}"; do
        plugin_load "$plugin"
        plugin_deploy_global
    done
}

# Core subcommand: project scaffolding
cmd_project() {
    local project_path="$1"
    local enabled_plugins=($(config_get "ENABLED_PLUGINS" "claude git"))

    for plugin in "${enabled_plugins[@]}"; do
        plugin_load "$plugin"
        plugin_deploy_project "$project_path"
    done
}

# NEW: Direct plugin subcommand invocation
cmd_plugin() {
    local plugin_name="$1"
    shift
    plugin_load "$plugin_name"

    case "$1" in
        wizard)
            plugin_setup_wizard
            ;;
        deploy)
            plugin_deploy_global
            ;;
        *)
            echo "Usage: dotclaude plugin $plugin_name [wizard|deploy]"
            exit 1
            ;;
    esac
}
```

### Plugin Discovery and Loading

**New `lib/plugin-loader.sh`:**

```bash
#!/bin/bash
# lib/plugin-loader.sh — Plugin discovery and loading

# Current plugin context (set by plugin_load)
CURRENT_PLUGIN=""
CURRENT_PLUGIN_ROOT=""

# Discover available plugins
# Returns: space-separated list of plugin names
plugin_discover() {
    local plugins=""
    for plugin_dir in "$DOTCLAUDE_PLUGINS"/*; do
        if [[ -d "$plugin_dir" && -f "$plugin_dir/plugin.sh" ]]; then
            plugins="$plugins $(basename "$plugin_dir")"
        fi
    done
    echo "$plugins" | xargs  # Trim whitespace
}

# Load a plugin into current context
# Args: plugin_name
plugin_load() {
    local plugin_name="$1"
    local plugin_root="$DOTCLAUDE_PLUGINS/$plugin_name"

    if [[ ! -f "$plugin_root/plugin.sh" ]]; then
        echo "Error: Plugin '$plugin_name' not found" >&2
        exit 1
    fi

    CURRENT_PLUGIN="$plugin_name"
    CURRENT_PLUGIN_ROOT="$plugin_root"

    # Source plugin
    source "$plugin_root/plugin.sh"

    # Source plugin's additional scripts if they exist
    [[ -f "$plugin_root/setup-wizard.sh" ]] && source "$plugin_root/setup-wizard.sh"
    [[ -f "$plugin_root/deploy.sh" ]] && source "$plugin_root/deploy.sh"
}

# Helper: Get plugin-namespaced config value
# Args: key, default
plugin_config_get() {
    local key="$1"
    local default="$2"
    config_get "${CURRENT_PLUGIN}_${key}" "$default"
}

# Helper: Set plugin-namespaced config value
# Args: key, value
plugin_config_set() {
    local key="$1"
    local value="$2"
    wizard_save_env "$ENV_FILE" "${CURRENT_PLUGIN}_${key}" "$value"
}
```

### Configuration Strategy: Namespaced Flat .env

**Recommendation:** Continue using flat `.env` with plugin-namespaced keys.

**Rationale:**
- Simple to parse in bash (just `source .env`)
- No external dependencies (no jq, yq, or custom parsers)
- Easy to manually inspect and edit
- Compatible with existing `wizard_save_env()` function

**Namespacing convention:**

```bash
# .env structure

# Core configuration
ENABLED_PLUGINS="claude git"
DEPLOY_TARGET="$HOME/.claude"

# Claude plugin configuration
claude_SETTINGS_ENABLED="true"
claude_CLAUDE_SECTIONS="communication simplicity documentation git code-style"
claude_HOOKS_ENABLED="post-tool-format.py"
claude_SKILLS_ENABLED="commit squash-merge simplicity-check"
claude_GSD_INSTALL="false"

# Git plugin configuration
git_USER_NAME="Henry Baker"
git_USER_EMAIL="henry@example.com"
git_ALIASES_ENABLED="true"
git_ALIAS_DEPLOY_NAME="deploy"
```

**Alternative considered:** INI-style sections with custom parser. **Rejected:** Adds complexity, requires custom parser, harder to debug.

## Migration Path: Strangler Fig Pattern

The Strangler Fig Pattern allows incremental refactoring by building new plugin-based code alongside the existing monolith, gradually routing functionality to plugins until the monolith can be retired.

### Phase 1: Foundation (Week 1)

**Goal:** Set up plugin infrastructure without breaking existing functionality.

**Tasks:**
1. Create `lib/plugin-loader.sh` with plugin discovery
2. Create `plugins/` directory structure
3. Add plugin interface documentation
4. Implement plugin discovery (scanning `plugins/*/plugin.sh`)
5. Keep `deploy.sh` unchanged (still the entry point)

**Success criteria:** Plugin infrastructure exists but nothing uses it yet.

### Phase 2: Extract Claude Plugin (Week 2-3)

**Goal:** Move Claude-specific functionality to `plugins/claude/`.

**Tasks:**
1. Create `plugins/claude/plugin.sh` with metadata
2. Extract Claude wizard steps from `deploy.sh` → `plugins/claude/setup-wizard.sh`
3. Extract Claude deployment logic → `plugins/claude/deploy.sh`
4. Move `templates/claude-md/`, `templates/settings/`, `templates/hooks-conf/` → `plugins/claude/templates/`
5. Move `hooks/`, `commands/` → `plugins/claude/`
6. Update `deploy.sh` to route Claude operations to plugin (strangler proxy)

**Routing strategy:**
```bash
# In deploy.sh cmd_global()
if plugin_exists "claude"; then
    plugin_load "claude"
    plugin_setup_wizard  # NEW: Plugin handles this
else
    # OLD: Fallback to monolithic wizard steps
    run_wizard "$SCRIPT_DIR"
fi
```

**Success criteria:**
- `deploy.sh global` still works
- Claude config now handled by plugin
- Old monolithic wizard still exists as fallback

### Phase 3: Extract Git Plugin (Week 4)

**Goal:** Move Git-specific functionality to `plugins/git/`.

**Tasks:**
1. Create `plugins/git/plugin.sh`
2. Extract Git wizard steps → `plugins/git/setup-wizard.sh`
3. Extract Git deployment logic → `plugins/git/deploy.sh`
4. Move `githooks/` → `plugins/git/`
5. Update `deploy.sh` to route Git operations to plugin

**Success criteria:**
- Both Claude and Git plugins fully functional
- Old monolithic code path still exists

### Phase 4: Replace Entry Point (Week 5)

**Goal:** Replace `deploy.sh` with new `dotclaude` entry point.

**Tasks:**
1. Create new `dotclaude` script with clean plugin-based routing
2. Migrate `.env` to namespaced keys (backwards-compatible migration script)
3. Test all workflows (global, project, remote)
4. Add symlink: `ln -s dotclaude deploy.sh` (backwards compatibility)

**Success criteria:**
- `dotclaude` is the new canonical entry point
- `deploy.sh` still works (symlink)

### Phase 5: Retire Monolith (Week 6)

**Goal:** Remove old monolithic code.

**Tasks:**
1. Delete old wizard code from monolithic `deploy.sh`
2. Delete old deployment functions
3. Remove `deploy.sh` symlink (document breaking change)
4. Update README with new plugin architecture

**Success criteria:**
- Only plugin-based code remains
- All tests pass
- Documentation updated

### Migration Risk Mitigation

**Rollback strategy:**
- Each phase completes with working code
- Git branches per phase: `refactor/phase-1-foundation`, etc.
- Old code path remains until phase 5

**Testing strategy:**
- Manual smoke tests after each phase:
  - `./deploy.sh global`
  - `./deploy.sh project /tmp/test-project`
  - `./deploy.sh global --target /tmp/test-target`
- Create test fixture: minimal `.env` with known config

**User impact:**
- Phases 1-4: No visible changes to users
- Phase 5: Breaking change (remove `deploy.sh` symlink)

## Integration Points

### Plugin → Core Library Integration

**Plugins MUST use shared libraries:**

| Library Function | Purpose | Used By |
|------------------|---------|---------|
| `wizard_prompt()` | Interactive input | setup-wizard.sh |
| `wizard_yesno()` | Yes/no questions | setup-wizard.sh |
| `wizard_save_env()` | Save config | setup-wizard.sh |
| `backup_and_link()` | Symlink management | deploy.sh |
| `is_dotclaude_owned()` | Ownership detection | deploy.sh |
| `discover_*()` | Content discovery | deploy.sh |

**Plugin isolation:**
- Plugins MUST NOT call other plugins directly
- Plugins MUST NOT assume specific deploy target paths (read from .env)
- Plugins SHOULD be idempotent (safe to run multiple times)

### Core → Plugin Integration

**Core invokes plugins via well-defined entry points:**

```bash
# Core loads plugin
plugin_load "claude"

# Core invokes plugin function
plugin_setup_wizard    # Defined by plugin

# Plugin uses shared libraries
wizard_yesno "Enable settings.json?" "y"
plugin_config_set "SETTINGS_ENABLED" "true"
```

### Plugin Dependencies

**If a plugin depends on another plugin:**

```bash
# In plugins/advanced/plugin.sh
plugin_list_dependencies() {
    echo "claude git"
}
```

Core plugin loader can enforce dependency order during deployment.

## Component Boundaries

### Core Responsibilities

**What stays in core:**
- Entry point routing (`dotclaude` script)
- Plugin discovery and loading (`lib/plugin-loader.sh`)
- Shared libraries (wizard, symlinks, discovery)
- `.env` management (read/write)
- Remote deployment orchestration (SSH connection, repo transfer)

**What core does NOT do:**
- Domain-specific configuration (Claude settings, Git identity)
- Domain-specific deployment (symlinking Claude files, setting Git config)

### Plugin Responsibilities

**What plugins do:**
- Collect plugin-specific configuration (wizard steps)
- Deploy plugin-specific files (symlinks, copies)
- Validate plugin-specific config
- Provide plugin-specific defaults

**What plugins do NOT do:**
- Implement their own wizard primitives (use shared `wizard_yesno()`, etc.)
- Implement their own symlink logic (use shared `backup_and_link()`)
- Directly manipulate `.env` (use `plugin_config_set()`)

## Architecture Patterns

### Pattern 1: Plugin Discovery via Filesystem

**What:** Discover plugins by scanning `plugins/*/plugin.sh`

**When:** At startup, core needs to know available plugins

**Example:**
```bash
# In lib/plugin-loader.sh
plugin_discover() {
    for plugin_dir in "$DOTCLAUDE_PLUGINS"/*; do
        [[ -f "$plugin_dir/plugin.sh" ]] && basename "$plugin_dir"
    done
}
```

**Why:** Simple, no registry needed, self-documenting directory structure.

### Pattern 2: Convention Over Configuration

**What:** Plugins follow naming conventions instead of explicit registration

**When:** File locations, function names, config keys

**Example:**
- Plugin files: `plugins/PLUGIN_NAME/plugin.sh`
- Function names: `plugin_setup_wizard()`, `plugin_deploy_global()`
- Config keys: `PLUGIN_NAME_KEY_NAME`

**Why:** Reduces boilerplate, enforces consistency, easier to understand.

### Pattern 3: Shared Context via Global Variables

**What:** Core sets global variables that plugins can read

**When:** Plugin needs to know its own name/path or access core paths

**Example:**
```bash
# Core sets before sourcing plugin
CURRENT_PLUGIN="claude"
CURRENT_PLUGIN_ROOT="/path/to/plugins/claude"
DOTCLAUDE_ROOT="/path/to/dotclaude"
ENV_FILE="/path/to/.env"

# Plugin reads
echo "I am the $CURRENT_PLUGIN plugin"
template_path="$CURRENT_PLUGIN_ROOT/templates/settings/base.json"
```

**Why:** Bash limitation—no better way to pass context to sourced scripts.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Plugin-to-Plugin Direct Calls

**What:** Plugin A directly sources Plugin B's scripts

**Why bad:** Creates tight coupling, breaks plugin isolation

**Instead:** Use plugin dependencies (`plugin_list_dependencies()`) and let core handle load order

### Anti-Pattern 2: Hard-coded Paths

**What:** Plugin assumes deploy target is `~/.claude`

**Why bad:** Breaks customisation (user may override with `--target`)

**Instead:** Read from `.env`: `DEPLOY_TARGET=$(config_get "DEPLOY_TARGET")`

### Anti-Pattern 3: Stateful Plugins

**What:** Plugin writes to global variables that persist across invocations

**Why bad:** Makes behaviour unpredictable, hard to test

**Instead:** Keep plugin state in `.env`, read on each invocation

### Anti-Pattern 4: Monolithic Plugin Functions

**What:** `plugin_deploy_global()` is 500 lines doing everything

**Why bad:** Hard to maintain, violates single responsibility

**Instead:** Extract helper functions in plugin's `deploy.sh`

## Scalability Considerations

### At 2 Plugins (Current)

**Approach:** Direct implementation, minimal abstraction

**Constraints:** None

**Tooling:** Basic shell functions

### At 5-10 Plugins (Near Future)

**Approach:** Add plugin manager subcommand

**Constraints:** Manual enabling/disabling becomes tedious

**Tooling:**
```bash
dotclaude plugin list              # Show available plugins
dotclaude plugin enable PLUGIN     # Add to ENABLED_PLUGINS
dotclaude plugin disable PLUGIN    # Remove from ENABLED_PLUGINS
dotclaude plugin info PLUGIN       # Show metadata
```

### At 10+ Plugins (Future)

**Approach:** Add plugin marketplace/registry

**Constraints:** Discovery beyond local filesystem needed

**Tooling:**
```bash
dotclaude plugin search TERM       # Search plugin registry
dotclaude plugin install PLUGIN    # Download and enable plugin
dotclaude plugin update PLUGIN     # Update to latest version
```

**Implementation:** JSON/YAML registry file listing plugins with URLs, versions, descriptions.

## Build Order Recommendation

Based on dependency analysis and migration risk:

### Order 1: Foundation First (Recommended)

1. **Phase 1: Foundation** — Build plugin infrastructure
2. **Phase 2: Extract Claude** — Lowest risk, highest value (most complex plugin)
3. **Phase 3: Extract Git** — Simpler plugin, learn from Claude extraction
4. **Phase 4: Replace Entry Point** — After both plugins proven
5. **Phase 5: Retire Monolith** — Final cleanup

**Rationale:** Validates architecture with Claude (complex) before committing fully.

### Order 2: Git First (Alternative)

1. **Phase 1: Foundation** — Build plugin infrastructure
2. **Phase 2: Extract Git** — Simpler plugin, faster validation
3. **Phase 3: Extract Claude** — More complex, but architecture proven
4. **Phase 4: Replace Entry Point**
5. **Phase 5: Retire Monolith**

**Rationale:** Quick win with Git validates approach before tackling Claude complexity.

**Recommendation:** Order 1 (Claude first) — better to validate architecture with the hard case first.

## Sources

Research drew from the following authoritative sources:

**Plugin Architecture Patterns:**
- [Plugin Architecture Design Pattern – A Beginner's Guide To Modularity](https://www.devleader.ca/2023/09/07/plugin-architecture-design-pattern-a-beginners-guide-to-modularity/)
- [Understanding Plugin Architecture: Building Flexible and Scalable Applications | dotCMS](https://www.dotcms.com/blog/plugin-achitecture)

**Bash Configuration Managers:**
- [GitHub - ohmybash/oh-my-bash](https://github.com/ohmybash/oh-my-bash)
- [GitHub - sds/dot: Framework for managing multiple shell configurations and dot files](https://github.com/sds/dot)
- [GitHub - bashdot/bashdot: Minimalist dotfile management framework](https://github.com/bashdot/bashdot)
- [GitHub - SimoLinuxDesign/Modular-Bashrc-Manager](https://github.com/SimoLinuxDesign/Modular-Bashrc-Manager)

**Configuration Best Practices:**
- [How to Use Docker Environment Files (.env) Effectively](https://oneuptime.com/blog/post/2026-01-16-docker-env-files/view)
- [Mastering the Bash Env File: A Quick Guide](https://bashcommands.com/bash-env-file)
- [Parsing config files with Bash | Opensource.com](https://opensource.com/article/21/6/bash-config)

**Migration Patterns:**
- [The Strangler Fig application pattern: incremental modernization to microservices](https://microservices.io/post/refactoring/2023/06/21/strangler-fig-application-pattern-incremental-modernization-to-services.md.html)
- [Strangler Pattern in Microservices System Design: A Practical Migration Playbook – TheLinuxCode](https://thelinuxcode.com/strangler-pattern-in-microservices-system-design-a-practical-migration-playbook/)
- [Refactoring legacy code: The Strangler Fig Migration Pattern](https://blog.theengineeringcompass.com/p/refactoring-legacy-code-the-strangler)

**General Dotfiles Ecosystem:**
- [General-purpose dotfiles utilities - dotfiles.github.io](https://dotfiles.github.io/utilities/)
- [GitHub - webpro/awesome-dotfiles: A curated list of dotfiles resources](https://github.com/webpro/awesome-dotfiles)

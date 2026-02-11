# Architecture

**Analysis Date:** 2026-02-10

## Pattern Overview

**Overall:** Plugin-based configuration management system with three-tier deployment model

**Key Characteristics:**
- Modular plugin architecture: Each plugin (claude, git) independently implements setup, deploy, and project-init workflows
- Three-tier configuration hierarchy: Hardcoded defaults → Global .env → Per-project config files
- Symlink-based deployment: File-level symlinks with ownership tracking for safe coexistence with other tools
- Convention-over-configuration: Plugin functions follow naming patterns (`plugin_${name}_setup`, `plugin_${name}_deploy`, etc.)

## Layers

**Entry Point Layer:**
- Purpose: CLI routing, argument parsing, plugin discovery
- Location: `/Users/henrybaker/Repositories/dotconfigs/dotconfigs` (main script)
- Contains: Command handlers (setup, global-configs, deploy, project-init, status, list), usage/help
- Depends on: Shared libs (wizard.sh, symlinks.sh, discovery.sh, etc.)
- Used by: Users via CLI commands

**Plugin Layer:**
- Purpose: Domain-specific configuration management (Claude Code, Git)
- Location: `/Users/henrybaker/Repositories/dotconfigs/plugins/{claude,git}/`
- Contains: `setup.sh` (wizard), `deploy.sh` (deployment logic), `project.sh` (per-repo setup), templates, hooks, commands
- Depends on: Shared libs (wizard, symlinks, discovery, config)
- Used by: Entry point via sourcing and function invocation

**Shared Library Layer:**
- Purpose: Reusable abstractions for all plugins
- Location: `/Users/henrybaker/Repositories/dotconfigs/lib/`
- Contains:
  - `wizard.sh` - Interactive prompts, user input, .env saving
  - `symlinks.sh` - Symlink management, ownership detection, conflict resolution
  - `discovery.sh` - Plugin/hook/skill/section discovery via filesystem scanning
  - `config.sh` - Configuration SSOT reference and hierarchy documentation
  - `validation.sh` - Git repo validation
  - `colours.sh` - TTY-aware colourization and status symbols
- Depends on: None (stdlib only)
- Used by: Entry point and all plugins

**Configuration Layer:**
- Purpose: Store and manage configuration state
- Location: `.env` (gitignored, per-machine)
- Contains: Namespaced key=value pairs (`CLAUDE_*`, `GIT_*`)
- Consumed by: All plugins via sourcing

**Asset Layer:**
- Purpose: Template sources and hook/command implementations
- Location: `plugins/{claude,git}/templates/`, `plugins/{claude,git}/hooks/`, `plugins/{claude,git}/commands/`
- Contains: JSON/Markdown/Python/Shell template and hook files
- Used by: Plugin deploy/project handlers to assemble or copy files

## Data Flow

**Global Configuration Setup (global-configs command):**

1. User invokes: `dotconfigs global-configs <plugin>`
2. Entry point routes to `cmd_global_configs()` → sources `plugins/<plugin>/setup.sh`
3. Plugin setup wizard (`plugin_${plugin}_setup()`) runs interactive prompts:
   - Uses shared `wizard_prompt()`, `wizard_yesno()`, `wizard_select()` from `lib/wizard.sh`
   - Collects user input (e.g., deploy target, hooks to enable, sections to include)
   - Calls `wizard_save_env()` to write config to `.env`
4. Config persists in `.env` as plugin-namespaced variables (e.g., `CLAUDE_DEPLOY_TARGET`, `GIT_USER_NAME`)

**Global Configuration Deployment (deploy command):**

1. User invokes: `dotconfigs deploy [plugin] [--dry-run|--force|--regenerate]`
2. Entry point routes to `cmd_deploy()` → sources `plugins/<plugin>/deploy.sh`
3. Plugin deploy handler (`plugin_${plugin}_deploy()`) executes:
   - Calls `_${plugin}_load_config()` to source `.env` and parse plugin config
   - For Claude: Builds CLAUDE.md from enabled sections, assembles settings.json from templates
   - For Git: Applies identity, workflow, aliases, and hooks to git config
   - Uses shared `backup_and_link()` from `lib/symlinks.sh` for symlink creation with conflict handling
   - Reports drift detection and status via `check_file_state()`
4. Files deployed to `~/.claude/` (Claude) or git config (Git)

**Per-Project Configuration Setup (project-init command):**

1. User invokes: `dotconfigs project-init [plugin] <path>`
2. Entry point validates git repo at path, routes to `cmd_project_configs()`
3. Plugin project handler (`plugin_${plugin}_project()`) executes:
   - For Claude: Scaffolds `.claude/settings.json` (per-repo overrides), optionally CLAUDE.md
   - For Git: Copies hooks to `.git/hooks/`, optionally sets per-repo identity
   - Applies CLAUDE.md exclusion patterns to `.git/info/exclude` or `.gitignore`
4. Per-repo files created, can override global config via config hierarchy

**Configuration Resolution at Runtime (in hooks):**

1. Hooks execute in project context (e.g., `git commit`, Claude tool invocation)
2. Hooks load config via three-tier hierarchy (documented in `lib/config.sh`):
   - Layer 1: Hardcoded defaults (in hook code)
   - Layer 2: Environment variables from .env (e.g., `GIT_HOOK_BLOCK_AI_ATTRIBUTION`)
   - Layer 3: Project config files (e.g., `.claude/git-hooks.conf`, `.git/hooks/hooks.conf`)
3. First-found-wins precedence: Project config > Env vars > Hardcoded defaults

**State Management:**

Global state:
- `.env` file: Single source of truth for user preferences (wizard-managed)
- Symlinks in `~/.claude/`: Owned by dotconfigs, tracked via `is_dotconfigs_owned()`
- Git global config: Managed via `git config --global` commands

Per-project state:
- `.claude/settings.json`: Per-repo Claude Code overrides
- `.claude/CLAUDE.md`: Optional per-repo instructions
- `.git/hooks/`: Git hooks copied from dotconfigs
- `.git/info/exclude` or `.gitignore`: CLAUDE.md/project exclusion patterns

## Key Abstractions

**Plugin Interface:**

Purpose: Defines the contract all plugins must implement
Examples: `plugins/claude/setup.sh`, `plugins/git/setup.sh`
Pattern: Each plugin provides three functions via sourced script:
- `plugin_${name}_setup()` - Interactive configuration wizard
- `plugin_${name}_deploy()` - Deploy global configuration from .env
- `plugin_${name}_project()` - Scaffold per-project configuration
- `plugin_${name}_status()` - Optional: report deployment status

**Symlink Management with Ownership Tracking:**

Purpose: Safe deployment of configuration files alongside other tools
Examples: `lib/symlinks.sh` with `is_dotconfigs_owned()`, `backup_and_link()`, `check_file_state()`
Pattern:
- File-level symlinks (not directory-level) allow multiple tools to share directories
- `is_dotconfigs_owned()` checks if symlink target is within dotconfigs repo
- `backup_and_link()` handles conflicts: skip, overwrite, backup, or diff
- `check_file_state()` reports status: deployed, not-deployed, drifted-broken, drifted-wrong-target, drifted-foreign

**Plugin Discovery via Filesystem:**

Purpose: Discover available plugins without explicit registration
Examples: `lib/discovery.sh` with `discover_plugins()`, `plugin_exists()`
Pattern:
- Scan `plugins/` directory for subdirectories with required files
- Plugin valid if contains both `setup.sh` and `deploy.sh`
- `discover_hooks()`, `discover_skills()`, `discover_claude_sections()` scan for assets

**Configuration Namespacing:**

Purpose: Support multiple plugins sharing single .env without key collisions
Examples: `CLAUDE_*` prefix for Claude config, `GIT_*` prefix for Git config
Pattern:
- Flat .env file with plugin-namespaced keys
- `wizard_save_env()` reads/writes key=value pairs
- Plugins access config via `source "$ENV_FILE"` then reference vars

**Wizard Framework:**

Purpose: Reusable interactive prompts for all plugins
Examples: `lib/wizard.sh` with `wizard_prompt()`, `wizard_yesno()`, `wizard_select()`, `wizard_save_env()`
Pattern:
- Plugins call shared wizard functions instead of implementing their own prompts
- `wizard_save_env()` handles file updates (creates .env if missing, appends or updates keys)
- Supports toggleable options with arrays (parsed space-separated strings in .env)

## Entry Points

**dotconfigs script:**
- Location: `/Users/henrybaker/Repositories/dotconfigs/dotconfigs` (executable, no .sh extension)
- Triggers: User invokes command (setup, global-configs, deploy, project-init, status, list, help)
- Responsibilities:
  - Parse CLI arguments and options
  - Route to appropriate command handler
  - Manage .env file path and plugin discovery
  - Initialize shared libraries
  - Handle color output for status/errors

**setup command:**
- Creates PATH symlinks (dotconfigs + dots convenience link)
- Saves DOTCONFIGS_VERSION=2.0 to .env
- One-time initialization

**global-configs command:**
- Invokes plugin setup wizard
- Saves configuration to .env
- No deployment happens until `deploy` is run

**deploy command:**
- Sources plugin deploy.sh
- Reads .env configuration
- Applies configuration to filesystem (symlinks, git config)
- Supports --dry-run (preview), --force (no prompts), --regenerate (rebuild from templates)

**project-init command:**
- Validates git repository
- Invokes plugin project setup handler
- Scaffolds per-repo config files

**status command:**
- Sources all plugin deploy.sh files
- Calls `plugin_${name}_status()` for each plugin
- Reports deployment state and drift

**list command:**
- Shows available plugins and installation status
- Checks for presence of key environment variables

## Error Handling

**Strategy:** Fail-fast with informative error messages, user-guided resolution

**Patterns:**
- Exit with status 1 on validation failures (missing .env, invalid plugin, invalid path)
- Dry-run mode prevents any filesystem changes (takes precedence over --force)
- Interactive prompts on conflict (overwrite/skip/backup/diff) unless --force specified
- Migration helper: `_${plugin}_migrate_old_keys()` handles backwards compatibility
- Validation functions: `validate_git_repo()`, `plugin_exists()` with clear error messages

## Cross-Cutting Concerns

**Logging:**
- Structured output: ✓/✗/△/! symbols with colour codes (from `lib/colours.sh`)
- Status tracking: "Would", "Deployed", "Updated", "Skipped", "Drifted" labels
- Dry-run header: "═══════════════════════════════════════════════════════════"
- All output to stdout; errors to stderr

**Validation:**
- At system edges only (entry point, git repo check)
- Plugin existence verified before sourcing
- .env existence checked before deploying
- Config values validated in plugin-specific logic (e.g., is deploy target a writable directory?)

**Authentication:**
- Not handled by dotconfigs (operates on local filesystem)
- Git credentials managed via git config, not dotconfigs

**Path Resolution:**
- Bash 3.2 compatible (macOS) symlink resolution using `perl` fallback for `readlink -f`
- Platform-aware sed for macOS/Linux compatibility
- Symlink recursion handling to find real script location
- `expand_path()` for relative path resolution

---

*Architecture analysis: 2026-02-10*

# dotconfigs

Single source of truth for dev configuration — one repo, one CLI, one `.env`, deployed everywhere.

**dotconfigs** is an extensible, plugin-based configuration manager for developer tools. Clone onto any machine (local Mac, remote servers, Docker, CI/CD) to get a consistent development environment. Currently manages Claude Code and Git configuration, with a plugin architecture that supports adding new config domains (shell, editors, etc.) without restructuring.

**Note:** `dots` is available as a convenience symlink to `dotconfigs`.

## Architecture

The system follows a three-command model: **global-configs** (wizard), **deploy** (apply config), and **project-configs** (per-repo overrides).

```
┌─────────────────────────────────────────────────────────────────┐
│                        dotconfigs CLI                           │
└─────────────────────────────────────────────────────────────────┘
                                 │
                 ┌───────────────┼───────────────┐
                 ▼               ▼               ▼
          ┌──────────────┐  ┌──────────┐  ┌──────────────┐
          │global-configs│  │  deploy  │  │project-configs│
          └──────────────┘  └──────────┘  └──────────────┘
                 │               │               │
                 │               │               │
         Wizard prompts    Reads .env      Scaffolds per-repo
         Saves to .env    Applies to        local files
                          filesystem
                                 │
                 ┌───────────────┴───────────────┐
                 ▼                               ▼
          ┌──────────┐                    ┌──────────┐
          │  Global  │                    │ Per-repo │
          │  Config  │                    │  Config  │
          └──────────┘                    └──────────┘


Plugin: claude                     Plugin: git
─────────────────                  ───────────────
deploy:                            deploy:
  settings.json → ~/.claude/         git config --global (identity, workflow)
  CLAUDE.md → ~/.claude/             aliases → git config
  hooks/ → ~/.claude/hooks/          (optional) hooks/ → ~/.git/config/core.hooksPath
  commands/ → ~/.claude/commands/
                                   project:
                                     .git/hooks/ (per-repo hooks)
project:                             .git/config (optional per-repo identity)
  .claude/settings.json
  CLAUDE.md (optional)
```

**Data flow:**
1. `dotconfigs global-configs <plugin>` runs interactive wizard, saves configuration to `.env`
2. `dotconfigs deploy [plugin]` reads `.env` and applies globally (symlinks, git config)
3. `dotconfigs project-configs [plugin]` sets up per-repository files (`.claude/`, `.git/hooks/`)

## Installation

Clone the repository and run deploy to add `dotconfigs` to your PATH:

```bash
git clone git@github.com:henrycgbaker/dotconfigs.git ~/dotconfigs
cd ~/dotconfigs
./dotconfigs deploy
```

**Requirements:** bash 3.2+ (macOS and Linux supported)

## Quick Start

Three steps to configure your environment:

```bash
dotconfigs global-configs claude    # Interactive wizard for Claude Code
dotconfigs deploy claude            # Apply configuration globally
dotconfigs status                   # Verify deployment
```

## Usage

### dotconfigs global-configs \<plugin\>

Runs an interactive wizard to configure a plugin. Saves configuration to `.env`.

```bash
dotconfigs global-configs claude    # Configure Claude Code settings
dotconfigs global-configs git       # Configure Git identity, workflow, aliases
```

The wizard pre-fills values from existing `.env` and git config. Configuration is saved but not applied until you run `deploy`.

### dotconfigs deploy [plugin] [--dry-run] [--force] [--regenerate]

Deploys configuration to the filesystem. Without arguments, deploys all plugins.

```bash
dotconfigs deploy               # Deploy all configured plugins
dotconfigs deploy claude        # Deploy only Claude plugin
dotconfigs deploy --dry-run     # Show what would change without applying
dotconfigs deploy --force       # Skip all conflict prompts (overwrite)
dotconfigs deploy --regenerate  # Rebuild generated files from templates (with backup)
```

**Flags:**
- `--dry-run` — show planned changes without applying (takes precedence over `--force`)
- `--force` — suppress drift warnings and conflict prompts, overwrite existing files
- `--regenerate` — rebuild generated files (CLAUDE.md, settings.json) from templates, creating backups of existing files

**Generated files (CLAUDE.md, settings.json)** are only created from templates on the first deploy. After that, they are your files to edit directly. Use `--regenerate` to reset them from templates (creates timestamped backups).

Deploy reads `.env` and applies configuration:
- **Claude plugin:** Symlinks settings.json, CLAUDE.md, hooks, commands to `~/.claude/`
- **Git plugin:** Writes to `git config --global`, creates aliases, optionally deploys hooks

**Conflict resolution:** Deploy uses **file-level symlinks** (not directory-level) and tracks ownership. If a file at the deploy target already exists and isn't a dotconfigs symlink, it's treated as a "foreign" file — you'll be prompted to overwrite, skip, backup, or diff. This means dotconfigs safely coexists with other tools (e.g., GSD framework) that share `~/.claude/` directories like `commands/` and `hooks/`. Each tool's files are individually tracked; deploying dotconfigs won't clobber files belonging to other tools.

### dotconfigs project-configs [plugin] [path]

Scaffolds per-repository configuration files. Can be run from within a project (auto-detects) or with an explicit path.

```bash
dotconfigs project-configs claude              # Set up .claude/ in current directory
dotconfigs project-configs git /path/to/repo   # Set up git hooks in specific repo
dotconfigs project-configs claude .            # Explicit current directory
```

**Claude plugin:** Creates `.claude/settings.json` (per-repo overrides), optionally CLAUDE.md
**Git plugin:** Copies hooks to `.git/hooks/`, optionally configures per-repo identity

### dotconfigs status [plugin]

Shows deployment state with drift detection. Reports per-file status for symlinks and per-setting status for git config.

```bash
dotconfigs status          # Status for all plugins
dotconfigs status claude   # Status for Claude plugin only
```

**States:**
- ✓ **deployed** — file/setting matches .env configuration
- ✗ **not-deployed** — file/setting doesn't exist
- ⚠ **drifted-broken** — symlink points to wrong location or is broken
- ⚠ **drifted-foreign** — file exists but isn't a symlink (foreign content)
- ⚠ **drifted-wrong-target** — git config value doesn't match .env

### dotconfigs list

Shows available plugins and their installation status.

```bash
dotconfigs list
```

### dotconfigs help [command]

Displays contextual help. Without arguments, shows command overview.

```bash
dotconfigs help         # Overview of all commands
dotconfigs help deploy  # Detailed help for deploy command
```

## GSD Framework

dotconfigs works well with the [Get Shit Done (GSD)](https://github.com/henrycgbaker/get-shit-done) planning and execution framework for Claude Code. GSD is installed separately — see its own documentation for setup.

## Plugins

### claude

Manages Claude Code configuration: CLAUDE.md, settings.json, hooks, and skills.

**What it deploys (all via symlinks):**
- `settings.json` — permission rules, environment variables, hooks config
- `CLAUDE.md` — global instructions built from toggleable section templates
- Hooks — scripts triggered by Claude events (PreToolUse guard, PostToolUse Ruff formatter)
- Commands — skills like `/commit`, `/squash-merge`, `/pr-review`, `/simplicity-check`

Generated files (settings.json, CLAUDE.md) are created from templates on first deploy, then treated as user-editable source files. Use `--regenerate` to rebuild from templates.

**Configuration:** Interactive wizard for deploy target, settings, CLAUDE.md sections, hooks, and skills.

### git

Manages Git configuration: identity, workflow settings, aliases, and hooks.

**What it deploys:**
- Identity — `user.name` and `user.email` in global git config
- Workflow settings — `pull.rebase`, `push.default`, `fetch.prune`, `init.defaultBranch`, etc.
- Aliases — Common shortcuts (`unstage`, `last`, `lg`, `amend`, `undo`, `wip`) plus custom aliases
- Hooks — 7 hooks for commit validation, branch protection, and workflow automation:
  - `commit-msg` — AI attribution blocking, conventional commit enforcement
  - `pre-commit` — secrets detection, large file check, debug statement detection
  - `pre-push` — branch protection (main/master)
  - `prepare-commit-msg` — auto-prefix commits with branch-based type
  - `post-merge` — dependency change detection, migration reminders
  - `post-checkout` — branch info display
  - `post-rewrite` — dependency detection for rebase workflows

**Configuration:** Menu-based wizard with four sections (identity, workflow, aliases, hooks). Each section can be configured independently.

## Configuration

All configuration is stored in `.env` (gitignored, per-machine). The setup wizard manages this file — manual editing is optional.

See `.env.example` for a complete reference of available configuration keys.

**Key namespaces:**
- `CLAUDE_*` — Claude plugin configuration (deploy target, settings, hooks, skills, GSD)
- `GIT_*` — Git plugin configuration (identity, workflow settings, aliases, hooks)

### Configuration Hierarchy

dotconfigs uses a three-tier configuration hierarchy for maximum flexibility:

| Tier | Scope | Use Case | Example |
|------|-------|----------|---------|
| **Hardcoded defaults** | All projects | Sensible defaults for most users | `GIT_HOOK_BLOCK_AI_ATTRIBUTION=true` |
| **Global .env** | All projects on this machine | Personal preferences, machine-specific settings | Set via `dotconfigs global-configs` wizard |
| **Project config files** | Single repository | Project-specific overrides | `.claude/git-hooks.conf` in repo |

**Precedence:** Project config > Global .env > Hardcoded defaults (higher tiers override lower).

**When to use each tier:**
- **Hardcoded defaults:** Built into hook code — no action needed, just works
- **Global .env:** Personal preferences that apply across all your projects (set once via global-configs wizard)
- **Project config files:** Per-repository overrides for team workflows or project-specific requirements (deployed by `dotconfigs project-configs`)

**Plugin configuration ownership:**
- Git plugin owns `git-hooks.conf` — deployed by `dotconfigs project-configs git`
- Claude plugin owns `claude-hooks.conf` — deployed by `dotconfigs project-configs claude`

**Git hook config discovery paths** (first found wins):
1. `.githooks/config`
2. `.claude/git-hooks.conf`
3. `.git/hooks/hooks.conf`
4. `.claude/hooks.conf`

For a complete list of all hooks, commands, and configuration options, see [docs/ROSTER.md](docs/ROSTER.md).

For detailed documentation on Claude Code configuration types (agents, skills, hooks, settings), see [docs/usage-guide.md](docs/usage-guide.md).

## Directory Structure

```
dotconfigs/
├── dotconfigs                 # CLI entry point (primary)
├── dots                       # Convenience symlink → dotconfigs
├── .env                       # Configuration store (gitignored, wizard-managed)
├── .env.example               # Configuration reference (SSOT for available keys)
├── lib/                       # Shared bash libraries (sourced, no shebangs)
│   ├── colours.sh             # TTY-aware colour output, G/L badge helpers
│   ├── config.sh              # Configuration hierarchy and variable reference
│   ├── discovery.sh           # Asset discovery (sections, hooks, skills)
│   ├── symlinks.sh            # Symlink management, backup, conflict resolution
│   ├── validation.sh          # Common validation helpers (is_git_repo, path_exists)
│   └── wizard.sh              # Wizard helpers (prompts, y/n, save, toggle, edit mode)
├── plugins/
│   ├── claude/
│   │   ├── setup.sh           # Claude global-configs wizard
│   │   ├── deploy.sh          # Claude deployment logic (symlinks, assembly)
│   │   ├── project.sh         # Per-repo scaffolding with G/L indicators
│   │   ├── DESCRIPTION        # Plugin metadata
│   │   ├── settings.json      # Assembled settings (generated, gitignored)
│   │   ├── CLAUDE.md          # Assembled CLAUDE.md (generated, gitignored)
│   │   ├── hooks/             # Claude Code hooks
│   │   │   ├── block-destructive.sh   # PreToolUse guard
│   │   │   └── post-tool-format.py    # PostToolUse Ruff formatter
│   │   ├── commands/          # Skills (/commit, /squash-merge, /pr-review, /simplicity-check)
│   │   └── templates/
│   │       ├── claude-md/     # CLAUDE.md section templates
│   │       ├── settings/      # settings.json base + language rule templates
│   │       └── claude-hooks.conf  # Hook config template
│   └── git/
│       ├── setup.sh           # Git global-configs wizard
│       ├── deploy.sh          # Git deployment logic (git config, aliases)
│       ├── project.sh         # Per-repo hooks + optional identity
│       ├── DESCRIPTION        # Plugin metadata
│       ├── hooks/             # Git hooks (7: commit-msg, pre-commit, pre-push, etc.)
│       └── templates/
│           └── git-hooks.conf # Per-project hook config template
├── scripts/                   # Utility scripts
│   ├── generate-roster.sh     # Auto-generates docs/ROSTER.md from hook metadata
│   └── registry-scan.sh       # Registry scanning utility
├── tests/                     # E2E validation
│   └── validate-deploy.sh     # Verify deployed config matches tool reality
└── docs/                      # Additional documentation
    ├── ROSTER.md              # Complete hook/command/config reference (generated)
    └── usage-guide.md         # Claude Code configuration guide
```

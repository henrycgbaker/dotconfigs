# dotconfigs

Single source of truth for dev configuration — one repo, one CLI, one `.env`, deployed everywhere.

**dotconfigs** is an extensible, plugin-based configuration manager for developer tools. Clone onto any machine (local Mac, remote servers, Docker, CI/CD) to get a consistent development environment. Currently manages Claude Code and Git configuration, with a plugin architecture that supports adding new config domains (shell, editors, etc.) without restructuring.

## Architecture

The system follows a three-command model: **setup** (wizard), **deploy** (apply config), and **project** (per-repo scaffolding).

```
┌─────────────────────────────────────────────────────────────────┐
│                         dotconfigs CLI                          │
└─────────────────────────────────────────────────────────────────┘
                                 │
                 ┌───────────────┼───────────────┐
                 ▼               ▼               ▼
          ┌──────────┐    ┌──────────┐    ┌──────────┐
          │  setup   │    │  deploy  │    │ project  │
          └──────────┘    └──────────┘    └──────────┘
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
  GSD framework (optional)         project:
                                     .git/hooks/ (per-repo hooks)
project:                             .git/config (optional per-repo identity)
  .claude/settings.json
  CLAUDE.md (optional)
```

**Data flow:**
1. `dotconfigs setup <plugin>` runs interactive wizard, saves configuration to `.env`
2. `dotconfigs deploy [plugin]` reads `.env` and applies globally (symlinks, git config)
3. `dotconfigs project [plugin]` sets up per-repository files (`.claude/`, `.git/hooks/`)

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
dotconfigs setup claude    # Interactive wizard for Claude Code
dotconfigs deploy claude   # Apply configuration globally
dotconfigs status          # Verify deployment
```

## Usage

### dotconfigs setup \<plugin\>

Runs an interactive wizard to configure a plugin. Saves configuration to `.env`.

```bash
dotconfigs setup claude    # Configure Claude Code settings
dotconfigs setup git       # Configure Git identity, workflow, aliases
```

The wizard pre-fills values from existing `.env` and git config. Configuration is saved but not applied until you run `deploy`.

### dotconfigs deploy [plugin] [--dry-run] [--force]

Deploys configuration to the filesystem. Without arguments, deploys all plugins.

```bash
dotconfigs deploy          # Deploy all configured plugins
dotconfigs deploy claude   # Deploy only Claude plugin
dotconfigs deploy --dry-run # Show what would change without applying
dotconfigs deploy --force  # Skip all conflict prompts (overwrite)
```

**Flags:**
- `--dry-run` — show planned changes without applying (takes precedence over `--force`)
- `--force` — suppress drift warnings and conflict prompts, overwrite existing files

Deploy reads `.env` and applies configuration globally:
- **Claude plugin:** Symlinks settings.json, CLAUDE.md, hooks, commands to `~/.claude/`
- **Git plugin:** Writes to `git config --global`, creates aliases, optionally deploys hooks

### dotconfigs project [plugin] [path]

Scaffolds per-repository configuration files. Can be run from within a project (auto-detects) or with an explicit path.

```bash
dotconfigs project claude              # Set up .claude/ in current directory
dotconfigs project git /path/to/repo   # Set up git hooks in specific repo
dotconfigs project claude .            # Explicit current directory
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

## Plugins

### claude

Manages Claude Code configuration: CLAUDE.md, settings.json, hooks, and skills.

**What it deploys:**
- `settings.json` — permission rules, environment variables, hooks config (symlinked from repo)
- `CLAUDE.md` — global instructions built from toggleable section templates
- Hooks — Python scripts triggered by Claude events (PostToolUse for Ruff formatting)
- Commands — Custom skills like `/commit`, `/squash-merge`, `/simplicity-check`
- GSD framework — Optional installation of Get Shit Done planning agents

**Configuration:** Interactive wizard for deploy target, settings, CLAUDE.md sections, hooks, skills, GSD installation, and git identity.

### git

Manages Git configuration: identity, workflow settings, aliases, and hooks.

**What it deploys:**
- Identity — `user.name` and `user.email` in global git config
- Workflow settings — `pull.rebase`, `push.default`, `fetch.prune`, `init.defaultBranch`, etc.
- Aliases — Common shortcuts (`unstage`, `last`, `lg`, `amend`, `undo`, `wip`) plus custom aliases
- Hooks — `commit-msg` (conventional commits), `pre-push` (branch protection)

**Configuration:** Menu-based wizard with four sections (identity, workflow, aliases, hooks). Each section can be configured independently.

## Configuration

All configuration is stored in `.env` (gitignored, per-machine). The setup wizard manages this file — manual editing is optional.

See `.env.example` for a complete reference of available configuration keys.

**Key namespaces:**
- `CLAUDE_*` — Claude plugin configuration (deploy target, settings, hooks, skills, GSD)
- `GIT_*` — Git plugin configuration (identity, workflow settings, aliases, hooks)

## Directory Structure

```
dotconfigs/
├── dotconfigs              # Main CLI entry point
├── .env                    # Configuration (gitignored, wizard-managed)
├── .env.example            # Configuration reference
├── settings.json           # Claude global settings (source of truth)
├── CLAUDE.md               # Repository CLAUDE.md
├── lib/                    # Shared bash libraries
│   ├── cli.sh              # CLI framework (subcommands, error handling)
│   ├── wizard.sh           # Wizard helpers (prompts, y/n, save)
│   ├── discovery.sh        # Asset discovery (sections, hooks, skills)
│   ├── deployment.sh       # Deployment helpers (symlinks, backups)
│   └── output.sh           # Output formatting (colours, TTY detection)
├── plugins/
│   ├── claude/
│   │   ├── setup.sh        # Claude setup wizard
│   │   ├── deploy.sh       # Claude deployment logic
│   │   ├── project.sh      # Per-repo scaffolding
│   │   ├── hooks/          # Claude Code hooks (Python)
│   │   ├── commands/       # Skills (/commit, /squash-merge, etc.)
│   │   └── templates/
│   │       ├── claude-md/  # CLAUDE.md section templates
│   │       ├── settings/   # Project settings.json templates
│   │       └── hooks-conf/ # Git hook config presets
│   └── git/
│       ├── setup.sh        # Git setup wizard
│       ├── deploy.sh       # Git deployment logic
│       ├── project.sh      # Per-repo git setup
│       └── hooks/          # Git hooks (commit-msg, pre-push)
├── scripts/                # Utility scripts
└── docs/                   # Additional documentation
```

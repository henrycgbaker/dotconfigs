# dotconfigs

Single source of truth for dev configuration — one repo, one CLI, one `.env`, deployed everywhere.

**dotconfigs** is an extensible, plugin-based configuration manager for developer tools. Clone onto any machine (local Mac, remote servers, Docker, CI/CD) to get a consistent development environment. Currently manages Claude Code and Git configuration, with a plugin architecture that supports adding new config domains (shell, editors, etc.) without restructuring.

**Note:** The CLI command is `dots` (shorter, more ergonomic). The `dotconfigs` command still works for backwards compatibility.

## Architecture

The system follows a three-command model: **setup** (wizard), **deploy** (apply config), and **project** (per-repo scaffolding).

```
┌─────────────────────────────────────────────────────────────────┐
│                            dots CLI                             │
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
1. `dots setup <plugin>` runs interactive wizard, saves configuration to `.env`
2. `dots deploy [plugin]` reads `.env` and applies globally (symlinks, git config)
3. `dots project [plugin]` sets up per-repository files (`.claude/`, `.git/hooks/`)

## Installation

Clone the repository and run deploy to add `dots` to your PATH:

```bash
git clone git@github.com:henrycgbaker/dotconfigs.git ~/dotconfigs
cd ~/dotconfigs
./dots deploy
```

**Requirements:** bash 3.2+ (macOS and Linux supported)

## Quick Start

Three steps to configure your environment:

```bash
dots setup claude    # Interactive wizard for Claude Code
dots deploy claude   # Apply configuration globally
dots status          # Verify deployment
```

## Usage

### dots setup \<plugin\>

Runs an interactive wizard to configure a plugin. Saves configuration to `.env`.

```bash
dots setup claude    # Configure Claude Code settings
dots setup git       # Configure Git identity, workflow, aliases
```

The wizard pre-fills values from existing `.env` and git config. Configuration is saved but not applied until you run `deploy`.

### dots deploy [plugin] [--dry-run] [--force]

Deploys configuration to the filesystem. Without arguments, deploys all plugins.

```bash
dots deploy          # Deploy all configured plugins
dots deploy claude   # Deploy only Claude plugin
dots deploy --dry-run # Show what would change without applying
dots deploy --force  # Skip all conflict prompts (overwrite)
```

**Flags:**
- `--dry-run` — show planned changes without applying (takes precedence over `--force`)
- `--force` — suppress drift warnings and conflict prompts, overwrite existing files

Deploy reads `.env` and applies configuration globally:
- **Claude plugin:** Symlinks settings.json, CLAUDE.md, hooks, commands to `~/.claude/`
- **Git plugin:** Writes to `git config --global`, creates aliases, optionally deploys hooks

### dots project [plugin] [path]

Scaffolds per-repository configuration files. Can be run from within a project (auto-detects) or with an explicit path.

```bash
dots project claude              # Set up .claude/ in current directory
dots project git /path/to/repo   # Set up git hooks in specific repo
dots project claude .            # Explicit current directory
```

**Claude plugin:** Creates `.claude/settings.json` (per-repo overrides), optionally CLAUDE.md
**Git plugin:** Copies hooks to `.git/hooks/`, optionally configures per-repo identity

### dots status [plugin]

Shows deployment state with drift detection. Reports per-file status for symlinks and per-setting status for git config.

```bash
dots status          # Status for all plugins
dots status claude   # Status for Claude plugin only
```

**States:**
- ✓ **deployed** — file/setting matches .env configuration
- ✗ **not-deployed** — file/setting doesn't exist
- ⚠ **drifted-broken** — symlink points to wrong location or is broken
- ⚠ **drifted-foreign** — file exists but isn't a symlink (foreign content)
- ⚠ **drifted-wrong-target** — git config value doesn't match .env

### dots list

Shows available plugins and their installation status.

```bash
dots list
```

### dots help [command]

Displays contextual help. Without arguments, shows command overview.

```bash
dots help         # Overview of all commands
dots help deploy  # Detailed help for deploy command
```

## GSD Framework

dotconfigs supports the [Get Shit Done (GSD)](https://github.com/henrycgbaker/get-shit-done) planning and execution framework for Claude Code. GSD provides structured phase planning, task breakdown, and execution workflows.

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
| **Global .env** | All projects on this machine | Personal preferences, machine-specific settings | Set via `dotconfigs setup` wizard |
| **Project config files** | Single repository | Project-specific overrides | `.claude/git-hooks.conf` in repo |

**Precedence:** Project config > Global .env > Hardcoded defaults (higher tiers override lower).

**When to use each tier:**
- **Hardcoded defaults:** Built into hook code — no action needed, just works
- **Global .env:** Personal preferences that apply across all your projects (set once via setup wizard)
- **Project config files:** Per-repository overrides for team workflows or project-specific requirements (deployed by `dotconfigs project`)

**Plugin configuration ownership:**
- Git plugin owns `git-hooks.conf` — deployed by `dotconfigs project git`
- Claude plugin owns `claude-hooks.conf` — deployed by `dotconfigs project claude`

**Git hook config discovery paths** (first found wins):
1. `.githooks/config`
2. `.claude/git-hooks.conf`
3. `.git/hooks/hooks.conf`
4. `.claude/hooks.conf`

For a complete list of all hooks, commands, and configuration options, see [docs/ROSTER.md](docs/ROSTER.md).

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
│   ├── config.sh           # Configuration hierarchy and variable reference
│   ├── wizard.sh           # Wizard helpers (prompts, y/n, save)
│   ├── discovery.sh        # Asset discovery (sections, hooks, skills)
│   ├── deployment.sh       # Deployment helpers (symlinks, backups)
│   └── output.sh           # Output formatting (colours, TTY detection)
├── plugins/
│   ├── claude/
│   │   ├── setup.sh        # Claude setup wizard
│   │   ├── deploy.sh       # Claude deployment logic
│   │   ├── project.sh      # Per-repo scaffolding
│   │   ├── hooks/          # Claude Code hooks (block-destructive.sh, post-tool-format.py)
│   │   ├── commands/       # Skills (/commit, /squash-merge, /pr-review, /simplicity-check)
│   │   └── templates/
│   │       ├── claude-md/  # CLAUDE.md section templates
│   │       ├── settings/   # Project settings.json templates
│   │       └── hooks-conf/ # Hook config templates
│   └── git/
│       ├── setup.sh        # Git setup wizard
│       ├── deploy.sh       # Git deployment logic
│       ├── project.sh      # Per-repo git setup
│       └── hooks/          # Git hooks (7 hooks for commit validation & workflow)
├── scripts/                # Utility scripts
│   └── generate-roster.sh  # Auto-generates docs/ROSTER.md from metadata
└── docs/                   # Additional documentation
    └── ROSTER.md           # Complete hook/command/config reference
```

# dotconfigs

Single source of truth for dev configuration -- one repo, one CLI, deployed everywhere.

**dotconfigs** is a plugin-based configuration manager. Clone onto any machine to get a consistent development environment. Manages Claude Code, Git, shell, and VS Code configuration through a manifest-driven architecture with per-file symlink tracking.

**Note:** `dots` is available as a convenience alias for `dotconfigs`.

## Architecture

### Single Source of Truth

Plugin manifests are the SSOT. Everything flows from them:

```
                         SSOT: Plugin Manifests
                      plugins/*/manifest.json
                                │
             ┌──────────────────┴──────────────────┐
             │                                     │
             ▼                                     ▼
      .global sections                      .project sections
             │                                     │
             ▼                                     ▼
   ┌───────────────────┐              ┌─────────────────────────┐
   │    global.json    │              │ .dotconfigs/project.json │
   │  (machine-wide)   │              │ (per-repo)              │
   └────────┬──────────┘              └────────────┬────────────┘
            │                                      │
    dotconfigs deploy                      dotconfigs project
            │                                      │
            ▼                                      ▼
   ┌───────────────────┐              ┌─────────────────────────┐
   │ ~/.claude/        │              │ .git/hooks/             │
   │ ~/.gitconfig      │              │ .claude/hooks/          │
   │ ~/.dotconfigs/    │              │ .claude/commands/       │
   │ ~/Library/...     │              │ .git/info/exclude       │
   └───────────────────┘              └─────────────────────────┘
     Filesystem (symlinks)              Filesystem (symlinks)
```

Each manifest declares modules with `source`, `target`, `method`, and `include`/`exclude` lists:

```
  plugins/claude/manifest.json           plugins/git/manifest.json
  ┌──────────────────────────────┐       ┌──────────────────────────────┐
  │ global:                      │       │ global:                      │
  │   hooks    → ~/.claude/hooks │       │   hooks  → ~/.dotconfigs/    │
  │   settings → ~/.claude/      │       │            git-hooks         │
  │   skills   → ~/.claude/cmds  │       │   config → ~/.gitconfig      │
  │   claude-md → ~/.claude/     │       │   excludes → ~/.config/git/  │
  │ project:                     │       │ project:                     │
  │   hooks    → .claude/hooks   │       │   hooks  → .git/hooks/       │
  │   skills   → .claude/cmds   │       │   excludes → .git/info/      │
  └──────────────────────────────┘       │   gitignore → .gitignore     │
                                         └──────────────────────────────┘
  plugins/shell/manifest.json            plugins/vscode/manifest.json
  ┌──────────────────────────────┐       ┌──────────────────────────────┐
  │ global:                      │       │ global:                      │
  │   init    → ~/.dotconfigs/   │       │   settings → ~/Library/      │
  │             shell/init.zsh   │       │     Application Support/     │
  │   aliases → ~/.dotconfigs/   │       │     Code/User/settings.json  │
  │             shell/aliases.zsh│       └──────────────────────────────┘
  └──────────────────────────────┘
```

### Data Flow

```
  First-time setup
  ─────────────────────────────────────────────────────────────────

  1. dotconfigs setup
     ├── scaffolds global.json from manifests (if not exists)
     └── creates PATH symlinks (dotconfigs, dots)

  2. dotconfigs deploy
     ├── reads global.json
     ├── for each module: symlink source → target
     └── conflict resolution: overwrite / skip / backup / diff

  Per-project setup
  ─────────────────────────────────────────────────────────────────

  3. dotconfigs project-init <path>
     ├── reads .project from each manifest
     ├── assembles .dotconfigs/project.json
     └── seeds .git/info/exclude

  4. (optional) edit project.json exclude lists
     └── e.g. exclude: ["post-tool-format.py"]

  5. dotconfigs project <path>
     ├── reads .dotconfigs/project.json
     ├── for each module: symlink source → target
     └── respects include/exclude lists
```

### Symlink Ownership

dotconfigs uses per-file symlinks (not directory-level), tracked by target resolution:

```
  ~/.claude/
  ├── hooks/
  │   ├── block-destructive.sh ──→ dotconfigs/plugins/claude/hooks/...  (ours)
  │   └── some-other-hook.sh   ──→ /other/tool/...               (foreign, untouched)
  └── commands/
      ├── commit.md            ──→ dotconfigs/plugins/claude/cmds/...   (ours)
      └── other-skill.md       ──→ /other/tool/...               (foreign, untouched)
```

Deploy only touches files it owns. Foreign files are never overwritten without prompting.

## Installation

```bash
git clone git@github.com:henrycgbaker/dotconfigs.git ~/Repositories/dotconfigs
cd ~/Repositories/dotconfigs
./dotconfigs setup
```

**Requirements:** bash 3.2+ (macOS and Linux), jq

## Quick Start

```bash
dotconfigs setup                  # One-time: PATH + scaffold global.json
dotconfigs deploy                 # Deploy all global config
dotconfigs project-init ~/myrepo  # Scaffold project config
dotconfigs project ~/myrepo       # Deploy project hooks + skills
```

## Commands

### dotconfigs setup

One-time initialisation. Scaffolds `global.json` from plugin manifests (if it doesn't exist) and creates PATH symlinks for `dotconfigs` and `dots`.

```bash
dotconfigs setup          # Run once after cloning
```

### dotconfigs deploy [group] [--dry-run] [--force]

Deploys configuration from `global.json` to the filesystem via symlinks. Also ensures `dotconfigs` and `dots` are on PATH.

```bash
dotconfigs deploy               # Deploy all groups
dotconfigs deploy claude        # Deploy claude group only
dotconfigs deploy git           # Deploy git group only
dotconfigs deploy --dry-run     # Preview without changes
dotconfigs deploy --force       # Skip conflict prompts
```

Aliases: `global-deploy`

**Conflict resolution:** If a target file exists and isn't a dotconfigs symlink, you're prompted to overwrite, skip, backup, or diff. dotconfigs tracks ownership per-file, so it coexists safely with other tools sharing directories like `~/.claude/`.

### dotconfigs project-init [path]

Assembles `.dotconfigs/project.json` from plugin manifests (`.project` sections only). Auto-excludes `.dotconfigs/` in `.git/info/exclude`. Defaults to current directory. Requires a git repository.

```bash
dotconfigs project-init .              # Current directory
dotconfigs project-init ~/myrepo       # Specific repo
dotconfigs project init ~/myrepo       # Space-separated alias
```

Aliases: `project-configs`, `project init`

The generated `project.json` has pre-populated include lists and empty exclude lists. Edit the exclude lists to skip specific hooks or skills per-project, then deploy with `dotconfigs project`.

### dotconfigs project [path] [--dry-run] [--force]

Deploys per-project configuration from `.dotconfigs/project.json`. Symlinks hooks, skills, and other modules into the project. Respects include/exclude lists. Defaults to current directory. Requires `.dotconfigs/project.json` (run `project-init` first).

```bash
dotconfigs project .                   # Deploy current project
dotconfigs project ~/myrepo --force    # Deploy, skip conflict prompts
dotconfigs project . --dry-run         # Preview
```

Aliases: `project-deploy`

### dotconfigs global-configs \<plugin\>

Interactive wizard to configure a plugin. Writes to `.env`. This is the legacy configuration path -- the manifest-based system (`global.json`) is the primary approach.

```bash
dotconfigs global-configs claude       # Configure Claude via wizard
dotconfigs global-configs git          # Configure Git via wizard
```

### dotconfigs status [plugin]

Shows deployment status with drift detection. Requires `.env` (legacy -- only works for plugins configured via `global-configs` wizard).

**States:**
- ✓ **Deployed** -- symlink correct
- △ **Drifted** -- broken symlink, foreign file, or wrong target
- ✗ **Not deployed** -- file doesn't exist

### dotconfigs list

Lists available plugins and whether they're configured. Checks legacy `.env` variables.

### dotconfigs help [command]

Shows detailed help for a specific command with usage, options, and examples.

```bash
dotconfigs help                # Overview of all commands
dotconfigs help deploy         # Detailed help for deploy
dotconfigs help project-init   # Detailed help for project-init
```

## Plugins

### claude

Manages Claude Code configuration via symlinks.

| Module | Source | Target |
|--------|--------|--------|
| hooks | `plugins/claude/hooks/` | `~/.claude/hooks/` (global), `.claude/hooks/` (project) |
| settings | `plugins/claude/settings.json` | `~/.claude/settings.json` |
| skills | `plugins/claude/commands/` | `~/.claude/commands/` (global), `.claude/commands/` (project) |
| CLAUDE.md | `plugins/claude/CLAUDE.md` | `~/.claude/CLAUDE.md` |

**Hooks:** `block-destructive.sh` (PreToolUse guard), `post-tool-format.py` (PostToolUse Ruff formatter)
**Skills:** `/commit`, `/squash-merge`, `/pr-review`, `/simplicity-check`

Project scope supports exclude lists to skip specific hooks or skills per-repo.

### git

Manages Git configuration: gitconfig, global excludes, and hooks.

| Module | Source | Target | Scope |
|--------|--------|--------|-------|
| hooks | `plugins/git/hooks/` | `~/.dotconfigs/git-hooks/` (global), `.git/hooks/` (project) | both |
| config | `plugins/git/templates/gitconfig` | `~/.gitconfig` | global |
| global-excludes | `plugins/git/templates/global-excludes` | `~/.config/git/ignore` | global |
| exclude-patterns | `plugins/git/templates/project-excludes` | `.git/info/exclude` | project |
| gitignore | `plugins/git/templates/gitignore-default` | `.gitignore` | project |

**7 hooks, all configurable via `.claude/git-hooks.conf`:**

| Hook | What it does | Key config |
|------|-------------|------------|
| `pre-commit` | Identity check, branch protection, secrets detection, large files, debug statements, ruff lint | `GIT_HOOK_IDENTITY_CHECK`, `GIT_HOOK_BRANCH_PROTECTION_COMMIT`, `GIT_HOOK_SECRETS_CHECK`, `GIT_HOOK_PYTHON_LINT` |
| `commit-msg` | AI attribution blocking, conventional commit enforcement, subject length | `GIT_HOOK_BLOCK_AI_ATTRIBUTION`, `GIT_HOOK_CONVENTIONAL_COMMITS` |
| `pre-push` | Force push protection on main/master | `GIT_HOOK_BRANCH_PROTECTION` |
| `prepare-commit-msg` | Auto-prefix from branch name (feature/* -> feat:) | `GIT_HOOK_BRANCH_PREFIX` |
| `post-merge` | Dependency change detection | |
| `post-checkout` | Branch info display | |
| `post-rewrite` | Dependency detection for rebase | |

### shell

Manages shell initialisation (zsh).

| Module | Source | Target |
|--------|--------|--------|
| init | `plugins/shell/init.zsh` | `~/.dotconfigs/shell/init.zsh` |
| aliases | `plugins/shell/aliases.zsh` | `~/.dotconfigs/shell/aliases.zsh` |

Global scope only. Source these from your `.zshrc`.

### vscode

Manages VS Code settings.

| Module | Source | Target |
|--------|--------|--------|
| settings | `plugins/vscode/settings.json` | `~/Library/Application Support/Code/User/settings.json` |

Global scope only (macOS path).

## Configuration

### Hook Configuration

Git hooks are configurable per-project via config files. Place a config file at any of these paths (first found wins):

1. `.githooks/config`
2. `.claude/git-hooks.conf`
3. `.git/hooks/hooks.conf`
4. `.claude/hooks.conf`

Example `.claude/git-hooks.conf`:
```bash
GIT_HOOK_IDENTITY_CHECK=true
GIT_HOOK_EXPECTED_NAME="henrycgbaker"
GIT_HOOK_EXPECTED_EMAIL="henry.c.g.baker@gmail.com"
GIT_HOOK_BRANCH_PROTECTION_COMMIT=true
GIT_HOOK_PYTHON_LINT=true
GIT_HOOK_DEBUG_CHECK_STRICT=false
```

**Precedence:** Config file > environment variable > hardcoded default.

### Manifest Format

Each plugin has a `manifest.json` with `global` and/or `project` sections:

```json
{
  "global": {
    "module-name": {
      "source": "plugins/name/file-or-dir",
      "target": "~/deploy/target",
      "method": "symlink",
      "include": ["file1", "file2"]
    }
  },
  "project": {
    "module-name": {
      "source": "plugins/name/file-or-dir",
      "target": ".relative/target",
      "method": "symlink",
      "include": ["file1", "file2"],
      "exclude": []
    }
  }
}
```

- `include` -- whitelist of files to deploy from a directory source
- `exclude` -- project-only, user-editable blacklist (empty by default)
- `method` -- `symlink` or `copy`
- Global targets use `~` (home-relative). Project targets are project-relative.

## Directory Structure

```
dotconfigs/
├── dotconfigs                    # CLI entry point
├── global.json                   # Assembled global config (gitignored, from manifests)
├── .env                          # Legacy config store (gitignored, wizard-managed)
├── lib/
│   ├── colours.sh                # TTY-aware colour output
│   ├── config.sh                 # Configuration hierarchy
│   ├── deploy.sh                 # JSON config deploy engine (include/exclude)
│   ├── discovery.sh              # Plugin and asset discovery
│   ├── init.sh                   # Manifest assembly, overwrite protection
│   ├── symlinks.sh               # Symlink management, conflict resolution
│   ├── validation.sh             # Common validators
│   └── wizard.sh                 # Interactive wizard helpers
├── plugins/
│   ├── claude/
│   │   ├── manifest.json         # SSOT: global + project module declarations
│   │   ├── hooks/                # block-destructive.sh, post-tool-format.py
│   │   ├── commands/             # commit.md, squash-merge.md, pr-review.md, simplicity-check.md
│   │   ├── settings.json         # Claude Code settings
│   │   ├── CLAUDE.md             # Global Claude instructions
│   │   ├── templates/            # Settings and project templates
│   │   ├── setup.sh              # Interactive wizard (legacy)
│   │   ├── deploy.sh             # Plugin deploy logic (legacy)
│   │   └── project.sh            # Plugin project logic (legacy)
│   ├── git/
│   │   ├── manifest.json         # SSOT: global + project module declarations
│   │   ├── hooks/                # 7 hooks (pre-commit, commit-msg, etc.)
│   │   ├── templates/
│   │   │   ├── gitconfig         # Git config (identity, aliases, workflow)
│   │   │   ├── global-excludes   # Global gitignore patterns
│   │   │   ├── project-excludes  # Per-project .git/info/exclude
│   │   │   └── gitignore-default # Default .gitignore for new projects
│   │   ├── setup.sh              # Interactive wizard (legacy)
│   │   ├── deploy.sh             # Plugin deploy logic (legacy)
│   │   └── project.sh            # Plugin project logic (legacy)
│   ├── shell/
│   │   ├── manifest.json         # SSOT: global module declarations
│   │   ├── init.zsh              # Shell initialisation (starship, fzf, etc.)
│   │   └── aliases.zsh           # Shell aliases (bat, eza, etc.)
│   └── vscode/
│       ├── manifest.json         # SSOT: global module declarations
│       └── settings.json         # VS Code settings
├── tests/
│   ├── conftest.py               # Pytest fixtures (project_dir, run_dotconfigs)
│   ├── test_cli.py               # CLI routing and help tests
│   ├── test_deploy_engine.py     # JSON deploy engine tests
│   └── test_project_commands.py  # project-init and project deploy tests
└── docs/
    ├── ROSTER.md                 # Hook/command/config reference
    └── usage-guide.md            # Claude Code configuration guide
```

# dotclaude

Portable Claude Code configuration — settings, hooks, skills, and deployment for any machine.

## Quick Start

```bash
git clone git@github.com:henrycgbaker/dotclaude.git ~/dotclaude
cd ~/dotclaude
./deploy.sh global
```

## What It Does

dotclaude is the single source of truth for Claude Code configuration. It deploys via symlinks to `~/.claude/`, keeping everything in sync with this repo. CLAUDE.md is the one exception — it's built from toggleable section templates.

## Usage

| Command | Purpose |
|---------|---------|
| `deploy.sh global` | Set up ~/.claude/ (wizard on first run) |
| `deploy.sh global --interactive` | Re-run wizard |
| `deploy.sh global --target DIR` | Non-interactive deploy |
| `deploy.sh global --remote HOST` | Deploy to remote server |
| `deploy.sh project [path]` | Scaffold a project |
| `scripts/registry-scan.sh` | Scan projects for configs |

## Structure

```
dotclaude/
├── deploy.sh              # Deployment script
├── .env.example           # Configuration template
├── settings.json          # Global settings source of truth
├── CLAUDE.md              # Current global CLAUDE.md
├── templates/
│   ├── claude-md/         # CLAUDE.md section templates
│   ├── settings/          # Project settings templates
│   └── hooks-conf/        # Git hook config presets
├── commands/              # Skills (/commit, /squash-merge, etc.)
├── hooks/                 # Claude Code hooks (PostToolUse, etc.)
├── githooks/              # Git hooks (commit-msg, pre-commit)
├── scripts/
│   ├── registry-scan.sh   # Project config scanner
│   └── lib/               # Shared bash functions
└── docs/
    └── usage-guide.md     # Comprehensive reference
```

## Configuration

All settings live in `.env` (gitignored, per-machine). See `.env.example` for all options.

## Deployment

`deploy.sh global` handles all deployment scenarios:

- **First run:** Interactive wizard for configuration
- **Updates:** Detects dotclaude-owned files, auto-updates
- **Conflicts:** Prompts for non-managed files
- **Remote:** `--remote HOST` deploys to remote server via SSH

CLAUDE.md is built from section templates in `templates/claude-md/`. Wizard lets you toggle sections on/off.

## Git Hooks

Git hooks in `githooks/` are copied to target repo's `.git/hooks/`:

| Hook | Purpose |
|------|---------|
| `commit-msg` | Validates commit format, blocks AI attribution |
| `pre-commit` | Enforces git identity, runs custom checks |

Configurable via `.claude/hooks.conf` (profile: default, strict, or off).

## GSD Coexistence

dotclaude and [GSD framework](https://github.com/get-shit-done-cc) coexist in `~/.claude/`. dotclaude uses file-level symlinks; GSD manages its own namespace. Neither touches the other's files.

## Registry Scanner

`scripts/registry-scan.sh` catalogues Claude Code configurations across projects:

```bash
./scripts/registry-scan.sh              # Human-readable table
./scripts/registry-scan.sh --json       # Machine-readable JSON
```

Reads `SCAN_PATHS` from `.env` to find projects. Reports settings, CLAUDE.md, hooks, skills, agents, and sync status for each project.

## Documentation

See **[docs/usage-guide.md](docs/usage-guide.md)** for comprehensive reference.

# dotclaude

Personal Claude Code configuration - agents, rules, hooks, commands, skills, and settings.

## Quick Start

```bash
git clone git@github.com:henrybaker/dotclaude.git ~/Repositories/dotclaude
cd ~/Repositories/dotclaude
./setup.sh
```

## What Gets Installed

| Source | Target | Method |
|--------|--------|--------|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | symlink |
| `rules/` | `~/.claude/rules/` | symlink |
| `agents/` | `~/.claude/agents/` | symlink |
| `hooks/` | `~/.claude/hooks/` | symlink |
| `commands/` | `~/.claude/commands/` | symlink |
| `skills/` | `~/.claude/skills/` | symlink |
| `settings.json` | `~/.claude/settings.json` | copy (allows local overrides) |
| `gitignore_global` | `~/.gitignore_global` | copy |
| `githooks/*` | `.git/hooks/` | copy |

## Directory Structure

```
dotclaude/
├── CLAUDE.md              # Personal policies & preferences
├── settings.json          # Claude settings (copied, not symlinked)
├── agents/                # System-wide reusable agents
├── rules/                 # Always-loaded behavioral standards
├── hooks/                 # Claude pre/post tool-use automation
├── commands/              # User-invoked /commands
├── skills/                # Model-invoked capabilities
├── project-agents/        # Version-controlled record of project agents
├── githooks/              # Git hook templates (→ .git/hooks/)
└── gitignore_global       # Global gitignore template
```

## Agents

### System-Wide

| Agent | Purpose | Mode |
|-------|---------|------|
| `git-manager` | Git workflows, semantic versioning, releases | acceptEdits |
| `python-refactorer` | Code quality, Ruff, strict typing | acceptEdits |
| `senior-architect` | System design, technical debt (advisory) | plan |
| `test-engineer` | Pytest, coverage, CI, bash testing | acceptEdits |
| `docs-writer` | READMEs, changelogs, API docs | acceptEdits |
| `devops-engineer` | CI/CD, GitHub Actions, Docker | acceptEdits |

### Project-Specific

Organized by project in `project-agents/`:

```
project-agents/
├── llm-efficiency-measurement-tool/
│   ├── research-pm.md
│   └── research-scientist.md
└── ds01-infra/
    ├── admin-docs-writer.md
    ├── cli-ux-designer.md
    ├── systems-architect.md
    ├── technical-product-manager.md
    └── user-docs-writer.md
```

**Sync agents:**
```bash
./sync-project-agents.sh pull    # projects → dotclaude
./sync-project-agents.sh push    # dotclaude → projects
./sync-project-agents.sh status  # check sync
```

## Rules

Always-loaded behavioral standards:

| Rule | Purpose |
|------|---------|
| `git-commits.md` | Conventional commits, semantic versioning |
| `python-standards.md` | Ruff, type hints, docstrings |
| `docker-practices.md` | Container best practices |
| `security.md` | Secrets, input validation |
| `research-code.md` | Reproducibility standards |
| `modular-claude-docs.md` | CLAUDE.md organization |
| `no-unnecessary-files.md` | Avoid .md bloat |

## Claude Hooks

Pre/post tool-use automation:

| Hook | Type | Purpose |
|------|------|---------|
| `post-tool-format.py` | PostToolUse | Auto-format Python with Ruff |
| `block-sensitive.py` | PreToolUse | Block access to .env, keys, credentials |

## Commands

User-invoked with `/command`:

| Command | Description |
|---------|-------------|
| `/gpu-status` | GPU utilization, memory, processes |
| `/docker-status` | Container status, resource usage |
| `/commit` | Create well-formatted commit |
| `/pr-review` | Review branch changes |

## Skills

Model-invoked when relevant:

| Skill | Purpose |
|-------|---------|
| `python-fixer` | Fix linting/formatting with Ruff |
| `type-checker` | MyPy type checking |
| `test-runner` | Run pytest, analyze failures |
| `container-inspector` | Debug Docker containers |
| `dependency-auditor` | Security scan dependencies |

## Git Configuration

### Git Hooks

Templates in `githooks/` are copied to `.git/hooks/` by `setup.sh`:

| Hook | Purpose |
|------|---------|
| `pre-commit` | Enforces git identity, syncs project agents |
| `commit-msg` | Blocks AI attribution patterns |

**After fresh clone:**
```bash
./setup.sh  # Installs hooks to .git/hooks/
```

**For other repos:**
```bash
cp ~/Repositories/dotclaude/githooks/* /path/to/repo/.git/hooks/
chmod +x /path/to/repo/.git/hooks/*
```

### Global Gitignore

Excludes common files across all repos:

| Pattern | Purpose |
|---------|---------|
| `.claude/`, `.claude-project` | Claude Code files |
| `.DS_Store`, `.idea/`, `.vscode/` | OS/editor files |
| `__pycache__/`, `.venv/`, etc. | Python artifacts |

**Manual setup:**
```bash
cp ~/Repositories/dotclaude/gitignore_global ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global
```

## Architecture Decisions

### Agent Strategy

| Location | Purpose | When to Use |
|----------|---------|-------------|
| `agents/` → `~/.claude/agents/` | Generic, reusable | Git, testing, refactoring |
| `project-agents/{project}/` | Version-controlled record | Domain-specific |
| Project's `.claude/agents/` | **Source of truth** | Where agents run |

- **Projects are source of truth** - agents live in each project's `.claude/agents/`
- **dotclaude is the record** - organized by project in `project-agents/`
- **Copy-based sync** - works across machines

### Scope Precedence

| Config Type | Precedence | Behavior |
|-------------|------------|----------|
| `settings.json` | Project > User | Merged (deny wins) |
| Agents | Project > User | Override |
| Hooks | All sources | Merged (all execute) |
| Rules | Project > User | Override |
| Commands/Skills | Project > User | Override |
| CLAUDE.md | Project > User | Override |

**Rule of thumb:** Project-level configs override user-level by name. Only hooks merge.

## Remote Deployment

```bash
./deploy-remote.sh hbaker --clone  # Clone and setup on remote
./deploy-remote.sh dsl --rsync     # Rsync local copy
```

## Documentation

**[docs/usage-guide.md](docs/usage-guide.md)** - Comprehensive guide to Claude Code configuration

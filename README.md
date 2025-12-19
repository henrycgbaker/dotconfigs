# dotclaude

Personal Claude Code configuration - agents, rules, hooks, commands, skills, and settings.

## Architecture Decisions

### System-Wide vs Project-Specific Agents

| Location | Purpose | When to Use |
|----------|---------|-------------|
| `agents/` → `~/.claude/agents/` | Generic, reusable across all projects | Git, testing, refactoring, CI/CD |
| `project-agents/{project}/` | Version-controlled record of project agents | Domain-specific agents |
| Project's `.claude/agents/` | **Source of truth** for that project | Where agents actually run |

**Key decisions:**
- **Projects are source of truth** - agents live in each project's `.claude/agents/`
- **dotclaude is the version-controlled record** - organized by project name in `project-agents/`
- **Copy-based sync** (not symlinks) - works across machines with different paths
- **Sync script** pulls latest from projects before commits

### Scope Precedence

| Config Type | Precedence | Behavior |
|-------------|------------|----------|
| `settings.json` | Project > User | Merged (deny wins) |
| Agents | Project > User | Override (project wins) |
| Hooks | All sources | Merged (all execute) |
| Rules | Project > User | Override |
| Commands/Skills | Project > User | Override |
| CLAUDE.md | Project > User | Override |

**Rule of thumb:** Project-level configs override user-level by name. Only hooks merge.

## Quick Start

```bash
git clone git@github.com:henrybaker/dotclaude.git ~/Repositories/dotclaude
cd ~/Repositories/dotclaude
./setup.sh
```

## Directory Structure

| Directory | Purpose | Syncs To |
|-----------|---------|----------|
| `CLAUDE.md` | Personal policies & preferences | `~/.claude/CLAUDE.md` |
| `settings.json` | Claude settings | `~/.claude/settings.json` |
| `rules/` | Always-loaded behavioral standards | `~/.claude/rules/` |
| `agents/` | System-wide reusable agents | `~/.claude/agents/` |
| `hooks/` | Pre/post tool-use automation | `~/.claude/hooks/` |
| `commands/` | User-invoked `/commands` | `~/.claude/commands/` |
| `skills/` | Model-invoked capabilities | `~/.claude/skills/` |
| `project-agents/` | Version-controlled record (not synced) | - |

## System-Wide Agents

| Agent | Purpose | Mode |
|-------|---------|------|
| `git-manager` | Git workflows, semantic versioning, releases | acceptEdits |
| `python-refactorer` | Code quality, Ruff, strict typing | acceptEdits |
| `senior-architect` | System design, technical debt (advisory) | plan |
| `test-engineer` | Pytest, coverage, CI, bash testing | acceptEdits |
| `docs-writer` | READMEs, changelogs, API docs | acceptEdits |
| `devops-engineer` | CI/CD, GitHub Actions, Docker | acceptEdits |

## Project Agents

Organized by project in `project-agents/`:

```
project-agents/
├── llm-efficiency-measurement-tool/
│   ├── research-pm.md          # Product roadmap, prioritization
│   └── research-scientist.md   # Experiment design, analysis
└── ds01-infra/
    ├── admin-docs-writer.md    # Sysadmin documentation
    ├── cli-ux-designer.md      # CLI UX patterns
    ├── systems-architect.md    # DS01-specific architecture
    ├── technical-product-manager.md
    └── user-docs-writer.md     # User-facing docs
```

**Sync agents from projects:**
```bash
./sync-project-agents.sh pull    # Pull from projects → dotclaude
./sync-project-agents.sh push    # Push from dotclaude → projects
./sync-project-agents.sh status  # Check sync status
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

## Hooks

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

## Git Hooks (for this repo)

| Hook | Purpose |
|------|---------|
| `pre-commit` | Syncs project-agents, enforces git identity |
| `commit-msg` | Blocks AI attribution |

Install: `git config core.hooksPath githooks`

## Remote Deployment

```bash
# Clone and setup on remote
./deploy-remote.sh hbaker --clone

# Rsync local copy
./deploy-remote.sh dsl --rsync
```

## Documentation

For detailed guidance on when to use agents, commands, skills, rules, and hooks, see:

**[docs/usage-guide.md](docs/usage-guide.md)** - Comprehensive guide to Claude Code configuration

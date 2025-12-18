# dotclaude

Personal Claude Code configuration - agents, rules, and settings.

## What's Included

| Directory | Purpose | Syncs To |
|-----------|---------|----------|
| `CLAUDE.md` | Personal policies & preferences | `~/.claude/CLAUDE.md` |
| `settings.json` | Claude settings | `~/.claude/settings.json` |
| `rules/` | Behavioral constraints | `~/.claude/rules/` |
| `agents/` | System-wide AI agents | `~/.claude/agents/` |
| `project-agents/` | Project-specific agents | Copy to `<project>/.claude/agents/` |

## Setup

### Fresh Install
```bash
git clone git@github.com:henrybaker/dotclaude.git ~/Repositories/dotclaude
cd ~/Repositories/dotclaude
./setup.sh
```

### On Remote Machines (hbaker, dsl)
```bash
cd ~/workspace  # or wherever you keep repos
git clone git@github.com:henrybaker/dotclaude.git
cd dotclaude
./setup.sh
```

## Workflow

### Update Config
```bash
cd ~/Repositories/dotclaude
# Edit files...
git add . && git commit -m "Update X"
git push
```

### Sync to Other Machines
```bash
cd ~/Repositories/dotclaude  # or ~/workspace/dotclaude
git pull
# Symlinks auto-update
```

### Add Project-Specific Agents
Copy from `project-agents/` to your project:
```bash
cp -r project-agents/research-pm ~/Repositories/my-project/.claude/agents/
```

## Agents

### System-Wide (always available)
- **git-manager** - Git workflows, semantic versioning, releases
- **python-refactorer** - Code quality, Ruff, typing
- **senior-architect** - System design (advisory)
- **test-engineer** - Test coverage, CI
- **docs-writer** - Documentation
- **devops-engineer** - CI/CD, GitHub Actions

### Project-Specific (copy as needed)
- **research-pm** - Product roadmap, prioritization
- **research-scientist** - Experiment design, analysis

## Git Hooks

This repo uses git hooks for commit quality:

| Hook | Purpose |
|------|---------|
| `pre-commit` | Enforces git identity (henrycgbaker / henry.c.g.baker@gmail.com) |
| `commit-msg` | Blocks AI attribution in commit messages |

**Location:** `.git/hooks/` (active, not tracked by git)
**Source:** `githooks/` (tracked copies)

The `.git/hooks/` directory is not tracked by git (it's inside `.git/`), so after cloning you need to install hooks manually:

```bash
cp githooks/* .git/hooks/
chmod +x .git/hooks/*
```

Or configure git to use the `githooks/` directory:
```bash
git config core.hooksPath githooks
```

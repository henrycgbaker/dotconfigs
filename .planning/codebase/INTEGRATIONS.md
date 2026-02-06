# External Integrations

**Analysis Date:** 2026-02-06

## APIs & External Services

**Claude API:**
- Claude Code IDE integration
- Model Context Protocol (MCP) for context fetching
- Spawning gsd-* agents for specialized tasks
- Command execution via `/command` syntax

**Model Integration:**
- Claude Opus 4.6 (or later frontier models)
- Configured via `settings.json` model selection
- MCP context protocol for data sources (`mcp__context7__*` tools)

## Data Storage

**Repositories:**
- GitHub (source: `git@github.com:henrycgbaker/dotclaude.git`)
- Clone or rsync to deploy

**File Storage:**
- Local filesystem only
- Home directory (`~/.claude/`)
- Project-relative paths (`.planning/`)
- No cloud storage integrations

**Project State:**
- `.planning/STATE.md` - Project state (loaded by commands)
- `.planning/ROADMAP.md` - Phase roadmap
- `.planning/config.json` - Project configuration
- `.planning/codebase/` - Codebase analysis documents

**Caching:**
- None (stateless design)

## Authentication & Identity

**Git Identity:**
- User: `henrycgbaker`
- Email: `henry.c.g.baker@gmail.com`
- Enforced by pre-commit hook
- SSH keys required for GitHub access

**SSH Authentication:**
- SSH keypair for remote deployment
- SSH config for known hosts (deploy-remote.sh)
- Used by rsync and git-clone deployment methods

**Claude Code:**
- User authentication via Claude Code IDE
- Per-project authorization through settings.json permissions
- No external OAuth providers

## Monitoring & Observability

**Error Tracking:**
- None detected

**Logs:**
- Console output from bash commands
- Pre-commit hook validation output
- Git hook error reporting
- Python hook stderr output

**Debugging:**
- `/gsd:debug` command available (gsd toolkit)
- Bash test output for diagnostics

## CI/CD & Deployment

**Hosting:**
- Decentralized: User's local machine
- Remote servers (SSH-accessible Unix systems)
- No dedicated CI/CD platform

**Deployment Method:**
- SSH + Git clone (`deploy-remote.sh --clone`)
- SSH + rsync (`deploy-remote.sh --rsync`)
- Manual setup via `setup.sh`

**Deployment Script:**
- Location: `deploy-remote.sh`
- Supports: SSH host specification, rsync or git-clone methods
- Installs: Symlinks to `~/.claude/`, settings.json, git hooks
- Post-deploy: Auto-runs `setup.sh` on remote

**Git Hooks:**
- Source: `githooks/` (pre-commit, commit-msg)
- Deployed: `.git/hooks/` (local only, not tracked)
- Enforcement:
  - Branch protection (prevent direct main commits)
  - Identity verification (git user.name/email)
  - Python linting via Ruff
  - Commit message validation
  - AI attribution blocking

## Environment Configuration

**Required env vars:**
- None hardcoded - system reads from standard environment
- Sensitive values blocked by pre-tool-use hooks

**Optional env vars:**
- `PYTHONDONTWRITEBYTECODE=1` (set in settings.json)
- `PYTHONUNBUFFERED=1` (set in settings.json)

**Secrets location:**
- `.env` files - blocked by hook security policy
- Environment variables - inherited from shell
- Git credentials - stored in `~/.gitconfig` (SSH keys)
- Blocked patterns: `*_key`, `*_secret`, `.ssh/`, `/secrets/`

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

## Tool Invocation

**Available Tools (Claude Code):**
- `Bash` - Shell command execution
- `Read` - File reading
- `Write` - File creation/modification
- `Edit` - File editing
- `Glob` - File pattern matching
- `Grep` - Content search
- `Task` - Complex multi-step operations
- `WebFetch` - HTTP requests (when needed)

**MCP Integration:**
- `mcp__context7__*` - Custom context fetching from external sources
- Used by gsd-planner for research tasks

## Git Integration

**Repository:**
- GitHub: `git@github.com:henrycgbaker/dotclaude.git`
- Remote: origin
- Branch: main (protected - requires feature branches)

**Operations:**
- Git commands allowed in bash (configured in permissions)
- Remote operations: push/pull/clone
- Pre-commit enforcement: identity, branch, formatting
- Commit message validation: conventional commits on main

## Project Integration Points

**Agent System:**
- `agents/` - System-wide reusable agents → symlinked to `~/.claude/agents/`
- `project-agents/` - Version-controlled project agents (separate repos)
- Agents spawned by command orchestrators
- Agents communicate via context loading and file writes

**Command System:**
- User invokes `/gsd:command-name` in Claude Code
- Commands defined in `commands/gsd/` as markdown with `<objective>`, `<process>`, `<context>`
- Commands reference agents via `agent:` field
- Command output: files to `.planning/`, console output

**Skill System:**
- Skills defined in `skills/` directory
- Model-invoked (Claude decides when to use)
- Available capabilities: python-fixer, type-checker, test-runner, etc.

---

*Integration audit: 2026-02-06*

# dotconfigs Hook & Command Roster

**Auto-generated reference** — Do not edit manually. Run `scripts/generate-roster.sh` to regenerate.

This document lists all available hooks, commands, and configuration options in dotconfigs.


## Git Hooks

Git hooks run during git operations to enforce quality standards and protect workflows.

| Hook | Description | Configuration Keys |
|------|-------------|-------------------|
| commit-msg | Blocks AI attribution patterns in commit messages |  |
| post-checkout | Post-checkout info — displays branch information on checkout | GIT_HOOK_BRANCH_INFO, GIT_HOOK_POST_CHECKOUT_ENABLED |
| post-merge | Post-merge checks — dependency change detection and migration reminders | GIT_HOOK_DEPENDENCY_CHECK, GIT_HOOK_MIGRATION_REMINDER, GIT_HOOK_POST_MERGE_ENABLED |
| post-rewrite | Post-rewrite checks — dependency detection for rebase workflows | GIT_HOOK_DEPENDENCY_CHECK, GIT_HOOK_MIGRATION_REMINDER, GIT_HOOK_POST_REWRITE_ENABLED |
| pre-commit | Branch-aware pre-commit — identity check always, Ruff format on main only |  |
| pre-push | Code quality validation (pytest + ruff + mypy) and force-push protection |  |
| pre-rebase | Blocks rebasing main/master and warns about pushed commits |  |
| prepare-commit-msg | Prepares commit message — extracts conventional commit prefix from branch name | GIT_HOOK_BRANCH_PREFIX, GIT_HOOK_PREPARE_COMMIT_MSG_ENABLED |

## Claude Hooks

Claude hooks run during Claude Code operations for code quality and safety.

| Hook | Description | Configuration Keys |
|------|-------------|-------------------|
| block-destructive | PreToolUse hook to block destructive commands and protect sensitive files | CLAUDE_HOOK_DESTRUCTIVE_GUARD, CLAUDE_HOOK_FILE_PROTECTION |

## Commands

Custom Claude Code commands (skills) for common workflows.

| Command | Description |
|---------|-------------|
| /commit | Help create a well-formatted commit |
| /pr-review | Review current branch changes for PR readiness |
| /simplicity-check | Review code or architecture for unnecessary complexity |
| /squash-merge | Squash merge current branch to main |

## Configuration Reference

All hook configuration follows a three-tier hierarchy:

1. **Hardcoded defaults** — Built into hook code (documented below)
2. **Environment variables** — Set in `.env` or shell environment
3. **Project config files** — Per-repository overrides

Higher tiers override lower tiers (config file > env var > default).

### Git Hook Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `GIT_HOOK_BRANCH_INFO` | `true` | Display branch info on checkout |
| `GIT_HOOK_BRANCH_PREFIX` | `true` | Auto-prefix commit with branch name |
| `GIT_HOOK_DEPENDENCY_CHECK` | `true` | Check for dependency changes |
| `GIT_HOOK_MIGRATION_REMINDER` | `true` | Remind about pending migrations |
| `GIT_HOOK_POST_CHECKOUT_ENABLED` | `true` | Enable post-checkout hook |
| `GIT_HOOK_POST_MERGE_ENABLED` | `true` | Enable post-merge hook |
| `GIT_HOOK_POST_REWRITE_ENABLED` | `true` | Enable post-rewrite hook |
| `GIT_HOOK_PREPARE_COMMIT_MSG_ENABLED` | `true` | Enable prepare-commit-msg hook |

### Claude Hook Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_HOOK_DESTRUCTIVE_GUARD` | `true` | Guard against destructive commands |
| `CLAUDE_HOOK_FILE_PROTECTION` | `true` | Protect critical files |

### Configuration File Locations

**Git hooks:** Per-project config files (first found wins):
- `.githooks/config`
- `.claude/git-hooks.conf`
- `.git/hooks/hooks.conf`
- `.claude/hooks.conf`

**Claude hooks:** Per-project config files (first found wins):
- `.claude/claude-hooks.conf` (project-specific)
- `~/.claude/claude-hooks.conf` (global fallback)

### Plugin Configuration Ownership

- **Git plugin** owns `git-hooks.conf` — deployed by `dotconfigs project` when project.json includes the git plugin
- **Claude plugin** owns `claude-hooks.conf` — deployed by `dotconfigs project` when project.json includes the claude plugin

---

*Generated: 2026-02-14 19:42:33 UTC*

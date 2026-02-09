# dotconfigs Hook & Command Roster

**Auto-generated reference** — Do not edit manually. Run `scripts/generate-roster.sh` to regenerate.

This document lists all available hooks, commands, and configuration options in dotconfigs.


## Git Hooks

Git hooks run during git operations to enforce quality standards and protect workflows.

| Hook | Description | Configuration Keys |
|------|-------------|-------------------|
| commit-msg | Validates commit messages — AI attribution blocking and conventional commit enforcement | GIT_HOOK_BLOCK_AI_ATTRIBUTION, GIT_HOOK_WIP_BLOCK_ON_MAIN, GIT_HOOK_CONVENTIONAL_COMMITS, GIT_HOOK_CONVENTIONAL_COMMITS_STRICT, GIT_HOOK_MAX_SUBJECT_LENGTH, GIT_HOOK_COMMIT_MSG_ENABLED |
| post-checkout | Post-checkout info — displays branch information on checkout | GIT_HOOK_BRANCH_INFO, GIT_HOOK_POST_CHECKOUT_ENABLED |
| post-merge | Post-merge checks — dependency change detection and migration reminders | GIT_HOOK_DEPENDENCY_CHECK, GIT_HOOK_MIGRATION_REMINDER, GIT_HOOK_POST_MERGE_ENABLED |
| post-rewrite | Post-rewrite checks — dependency detection for rebase workflows | GIT_HOOK_DEPENDENCY_CHECK, GIT_HOOK_MIGRATION_REMINDER, GIT_HOOK_POST_REWRITE_ENABLED |
| pre-commit | Pre-commit validation — secrets detection, large file check, debug statement detection | GIT_HOOK_SECRETS_CHECK, GIT_HOOK_LARGE_FILE_CHECK, GIT_HOOK_LARGE_FILE_THRESHOLD, GIT_HOOK_DEBUG_CHECK, GIT_HOOK_DEBUG_CHECK_STRICT, GIT_HOOK_PRE_COMMIT_ENABLED |
| pre-push | Protects main/master branches from force-push operations | GIT_HOOK_BRANCH_PROTECTION, GIT_HOOK_PRE_PUSH_ENABLED |
| prepare-commit-msg | Prepares commit message — extracts conventional commit prefix from branch name | GIT_HOOK_BRANCH_PREFIX, GIT_HOOK_PREPARE_COMMIT_MSG_ENABLED |

## Claude Hooks

Claude hooks run during Claude Code operations for code quality and safety.

| Hook | Description | Configuration Keys |
|------|-------------|-------------------|
| block-destructive | PreToolUse hook to block destructive commands and protect sensitive files | CLAUDE_HOOK_DESTRUCTIVE_GUARD, CLAUDE_HOOK_FILE_PROTECTION |
| post-tool-format | Auto-formats Python files with Ruff after Write/Edit | CLAUDE_HOOK_RUFF_FORMAT |

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
| `GIT_HOOK_BLOCK_AI_ATTRIBUTION` | `true` | Block AI attribution in commits |
| `GIT_HOOK_WIP_BLOCK_ON_MAIN` | `true` | Block WIP commits on main branch |
| `GIT_HOOK_CONVENTIONAL_COMMITS` | `true` | Enable conventional commit validation |
| `GIT_HOOK_CONVENTIONAL_COMMITS_STRICT` | `false` | Enforce conventional (vs warn) |
| `GIT_HOOK_MAX_SUBJECT_LENGTH` | `72` | Maximum subject line length |
| `GIT_HOOK_COMMIT_MSG_ENABLED` | `true` | Enable commit-msg hook |
| `GIT_HOOK_BRANCH_PROTECTION` | `warn` | Protect main/master (block/warn/off) |
| `GIT_HOOK_PRE_PUSH_ENABLED` | `true` | Enable pre-push hook |
| `GIT_HOOK_SECRETS_CHECK` | `true` | Check for secrets in staged files |
| `GIT_HOOK_LARGE_FILE_CHECK` | `true` | Check for large files |
| `GIT_HOOK_LARGE_FILE_THRESHOLD` | `1048576` | Large file size threshold (bytes) |
| `GIT_HOOK_DEBUG_CHECK` | `true` | Check for debug statements |
| `GIT_HOOK_DEBUG_CHECK_STRICT` | `false` | Block vs warn on debug statements |
| `GIT_HOOK_PRE_COMMIT_ENABLED` | `true` | Enable pre-commit hook |
| `GIT_HOOK_BRANCH_PREFIX` | `true` | Auto-prefix commit with branch name |
| `GIT_HOOK_PREPARE_COMMIT_MSG_ENABLED` | `true` | Enable prepare-commit-msg hook |
| `GIT_HOOK_DEPENDENCY_CHECK` | `true` | Check for dependency changes |
| `GIT_HOOK_MIGRATION_REMINDER` | `true` | Remind about pending migrations |
| `GIT_HOOK_POST_MERGE_ENABLED` | `true` | Enable post-merge hook |
| `GIT_HOOK_BRANCH_INFO` | `true` | Display branch info on checkout |
| `GIT_HOOK_POST_CHECKOUT_ENABLED` | `true` | Enable post-checkout hook |
| `GIT_HOOK_POST_REWRITE_ENABLED` | `true` | Enable post-rewrite hook |

### Claude Hook Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_HOOK_DESTRUCTIVE_GUARD` | `true` | Guard against destructive commands |
| `CLAUDE_HOOK_FILE_PROTECTION` | `true` | Protect critical files |
| `CLAUDE_HOOK_RUFF_FORMAT` | `true` | Auto-format Python with Ruff |

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

- **Git plugin** owns `git-hooks.conf` — deployed by `dotconfigs project git`
- **Claude plugin** owns `claude-hooks.conf` — deployed by `dotconfigs project claude`

---

*Generated: 2026-02-09 17:29:47 UTC*

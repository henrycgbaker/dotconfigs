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
| pre-commit | Pre-commit — identity check, secrets scan, block main commits, Ruff format+lint on staged files |  |
| pre-push | Force-push protection and fast lint/format check (tests + types run in CI) |  |
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
| /squash-merge | Squash merge current branch to main via GitHub PR |

## Customisation

Hooks are opinionated by default. To add per-project behaviour, use `.local` extension scripts:

- `.git/hooks/pre-commit.local` — runs at end of pre-commit
- `.git/hooks/pre-push.local` — runs at end of pre-push
- `.git/hooks/commit-msg.local` — runs at end of commit-msg

To skip a hook entirely, exclude it in `.dotconfigs/project.json` before deploying.

---

*Generated: 2026-03-04 10:24:05 UTC*

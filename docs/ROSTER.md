# dotconfigs Hook & Skill Roster

**Auto-generated reference** — Do not edit manually. Run `scripts/generate-roster.sh` to regenerate.

This document lists all available hooks, skills, and configuration options in dotconfigs.


## Git Hooks

Git hooks run during git operations to enforce quality standards and protect workflows.

| Hook | Description | Configuration Keys |
|------|-------------|-------------------|
| check-facade-consumers | Verify every facade __all__ entry has at least one external consumer |  |
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
| block-ai-pr-attribution | PreToolUse hook to block AI attribution in PR titles and descriptions | CLAUDE_HOOK_PR_ATTRIBUTION_GUARD |
| block-destructive | PreToolUse hook to block destructive commands and protect sensitive files | CLAUDE_HOOK_DESTRUCTIVE_GUARD, CLAUDE_HOOK_FILE_PROTECTION |
| block-gh-pr-write | PreToolUse hook to block GitHub PR/issue write operations (comments, reviews, replies) unless explicitly authorised via GH_PR_COMMENT_OK=1 | CLAUDE_HOOK_GH_PR_WRITE_GUARD |

## Skills

Custom Claude Code skills (`/name`) for common workflows.

| Command | Description |
|---------|-------------|
| /check-resolution | After resolving merge/rebase conflicts locally, verify the resolution didn't silently resurrect old code the branch removed or undo a fix that landed on main |
| /commit | Help create a well-formatted conventional commit |
| /preflight-merge | Pre-merge gate Claude runs before completing any squash merge to main - simulates the merge and flags silent auto-merge regressions that would reintroduce code the base already fixed |
| /rebase-stacked-prs | Safely rebase a stacked PR onto main, dropping already-merged stacked-below work without reintroducing legacy code |
| /squash-merge | Squash merge current branch to main via GitHub PR |

## Customisation

Hooks are opinionated by default. To add per-project behaviour, use `.local` extension scripts:

- `.git/hooks/pre-commit.local` — runs at end of pre-commit
- `.git/hooks/pre-push.local` — runs at end of pre-push
- `.git/hooks/commit-msg.local` — runs at end of commit-msg

To skip a hook entirely, exclude it in `.dotconfigs/project.json` before deploying.

---

*Generated: 2026-06-03 15:09:22 UTC*

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
| block-chmod-777 | PreToolUse hook blocking chmod -R 777 (creates security vulnerability) | CLAUDE_HOOK_DESTRUCTIVE_GUARD |
| block-drop-table | PreToolUse hook blocking DROP TABLE / DROP DATABASE SQL statements (case-insensitive) | CLAUDE_HOOK_DESTRUCTIVE_GUARD |
| block-force-push | PreToolUse hook blocking git push --force without --force-with-lease | CLAUDE_HOOK_DESTRUCTIVE_GUARD |
| block-gh-comment | PreToolUse hook blocking unsolicited GitHub comment/review posts across two entrypoints - the gh CLI (Bash) and the GitHub MCP server (mcp__github__*). gh writes are denied unless prefixed GH_COMMENT_OK=1; MCP comment/review writes return "ask" for interactive approval. | CLAUDE_HOOK_GH_COMMENT_GUARD |
| block-git-clean | PreToolUse hook blocking git clean -fd (and -fdX variants) which deletes untracked files | CLAUDE_HOOK_DESTRUCTIVE_GUARD |
| block-hard-reset | PreToolUse hook blocking git reset --hard (discards uncommitted work) | CLAUDE_HOOK_DESTRUCTIVE_GUARD |
| block-rm-rf-root | PreToolUse hook blocking rm -rf / or rm -rf ~ (full filesystem wipe) | CLAUDE_HOOK_DESTRUCTIVE_GUARD |
| block-sensitive-write | PreToolUse hook blocking Write/Edit on sensitive files (private keys, credentials, .env.production) | CLAUDE_HOOK_FILE_PROTECTION |
| inject-context | UserPromptSubmit hook prepending git context (branch, dirty count, head sha + subject) to every prompt | CLAUDE_HOOK_PROMPT_CONTEXT |
| notify | Notification hook fanning notifications out to ntfy.sh (if NTFY_TOPIC set) and desktop notify-send (if a display is available). Terminal bell is handled by settings.json preferredNotifChannel. | CLAUDE_HOOK_NOTIFY_NTFY, CLAUDE_HOOK_NOTIFY_DESKTOP |
| pre-compact-snapshot | PreCompact hook snapshotting the transcript to ~/.claude/snapshots/<session_id>-precompact.jsonl before compaction | CLAUDE_HOOK_PRECOMPACT_SNAPSHOT |
| session-end-log | SessionEnd hook appending a JSONL telemetry line to ~/.claude/session-log.jsonl (timestamp, session_id, duration, model, project_dir) | CLAUDE_HOOK_SESSION_LOG |
| session-start-env | SessionStart hook auto-activating a Python .venv in $CLAUDE_PROJECT_DIR by writing VIRTUAL_ENV and PATH to $CLAUDE_ENV_FILE | CLAUDE_HOOK_VENV_AUTO |

## Skills

Custom Claude Code skills (`/name`) for common workflows.

| Command | Description |
|---------|-------------|
| /branch-cleanup | Delete local branches already merged into main and prune stale remote-tracking refs. Use after squash-merging a PR, when local `git branch` is cluttered with leftovers, or when the user says "clean up branches". |
| /check-resolution | Audit a just-resolved merge or rebase locally to confirm the resolution didn't silently resurrect code the branch removed or revert a fix that landed on main. Use after `git add` of resolved files and before `git rebase --continue` / `git commit`. |
| /commit | Stage changes and create a conventional commit on the current branch. Use when wrapping up a logical unit of work or when the user says "commit". |
| /diagnose-missing-work | Diagnose a "I thought we did X" / "this got lost" report before concluding work is missing. Fetches first, distinguishes squash-merge dangling commits (normal) from genuine loss, and checks merged PRs and the reflog. Use when the user says work seems gone, a change isn't on main, or a branch "disappeared" - and BEFORE any destructive recovery or re-doing the work. |
| /fix-pr-feedback | Sync a PR branch, triage its unresolved review comments, let the user pick which to address (mechanical via checklist, judgement-calls via options), fix each as a discrete commit, then audit and offer to push. Runs interactively by default; --semi-auto and --auto reduce or remove the prompts for unattended runs. Use when a reviewer has left comments / requested changes and the user says "address the feedback", "fix the comments", or "respond to the review". |
| /pr-create | Open a GitHub PR for the current branch with a derived title and a structured Summary / Test plan / Doc audit body. Use when the user says "open a PR", "draft a PR", or after a feature branch is ready for review but not yet merged. |
| /preflight-merge | Simulate the squash of a PR against its current base and flag silent auto-merge regressions that would reintroduce code the base has since fixed. Use as the mandatory gate inside `/squash-merge` before `gh pr merge`, or before completing any merge of a long-running or stacked PR. |
| /rebase-stacked-prs | Rebase a stacked PR onto current main by cherry-picking only its genuinely-new commits and auditing the result, dropping already-merged stacked-below work without reintroducing legacy code. Use when a stacked PR's lower PRs have merged (often in modified form) and a naive `git rebase --onto` would replay superseded commits. |
| /squash-merge | Drive the current feature branch through a GitHub PR to a squash-merge on main, running the preflight gate, CI watch, and post-merge cleanup. Use when the branch is review-ready or the user says "merge", "ship it", or "squash to main". |

## Customisation

Hooks are opinionated by default. To add per-project behaviour, use `.local` extension scripts:

- `.git/hooks/pre-commit.local` — runs at end of pre-commit
- `.git/hooks/pre-push.local` — runs at end of pre-push
- `.git/hooks/commit-msg.local` — runs at end of commit-msg

To skip a hook entirely, exclude it in `.dotconfigs/project.json` before deploying.

---

*Generated: 2026-06-04 10:26:43 UTC*

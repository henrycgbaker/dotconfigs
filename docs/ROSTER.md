# dotconfigs Hook & Skill Roster

**Auto-generated reference** — Do not edit manually. Run `scripts/generate-roster.sh` to regenerate.

This document lists the hooks and skills catalogued in dotconfigs. Toggle any item on or
off in your `deploy.json` (`~/.dotconfigs/deploy.json` for the machine, or
`<repo>/.dotconfigs/deploy.json` for a project).


## Git Hooks

Git hooks run during git operations to enforce quality standards and protect workflows.

| Hook | Description | Event / Matcher |
|------|-------------|-----------------|
| check-facade-consumers | Verify every facade __all__ entry has at least one external consumer |  |
| commit-msg | Block AI attribution patterns in commit messages |  |
| pre-commit | Identity check, secrets scan, block main commits, Ruff format+lint on staged files |  |
| pre-push | Force-push protection and fast lint/format check |  |
| pre-rebase | Block rebasing main/master and warn about pushed commits |  |
| prepare-commit-msg | Extract conventional commit prefix from branch name |  |
| post-checkout | Display branch information on checkout |  |
| post-merge | Dependency change detection and migration reminders |  |
| post-rewrite | Dependency detection for rebase workflows |  |

## Claude Hooks

Claude hooks run during Claude Code operations for code quality and safety.

| Hook | Description | Event / Matcher |
|------|-------------|-----------------|
| _hook-common | Shared hook helpers (sourced library, not an event hook) |  |
| block-rm-rf-root | Block rm -rf / or rm -rf ~ (full filesystem wipe) | PreToolUse (Bash) |
| block-force-push | Block git push --force without --force-with-lease | PreToolUse (Bash) |
| block-hard-reset | Block git reset --hard (discards uncommitted work) | PreToolUse (Bash) |
| block-git-clean | Block git clean -fd which deletes untracked files | PreToolUse (Bash) |
| block-drop-table | Block DROP TABLE / DROP DATABASE SQL statements | PreToolUse (Bash) |
| block-chmod-777 | Block chmod -R 777 (creates security vulnerability) | PreToolUse (Bash) |
| block-sensitive-write | Block Write/Edit on sensitive files (private keys, credentials, .env.production) | PreToolUse (Write|Edit) |
| block-ai-pr-attribution | Block AI attribution in PR titles/bodies and GitHub MCP writes | PreToolUse (Bash), PreToolUse (mcp__github__.*) |
| block-gh-comment | Block unsolicited GitHub comment/review posts via gh CLI and the GitHub MCP server | PreToolUse (Bash), PreToolUse (mcp__github__.*) |
| facade-check | Facade orphan-export check after Write/Edit | PostToolUse (Write|Edit) |
| inject-context | Prepend git context (branch, dirty count, head) to every prompt | UserPromptSubmit |
| session-start-env | Auto-activate a Python .venv in the project on session start | SessionStart |
| session-end-log | Append a JSONL telemetry line to ~/.claude/session-log.jsonl on session end | SessionEnd |
| pre-compact-snapshot | Snapshot the transcript before compaction | PreCompact |
| notify | Fan notifications out to ntfy.sh and desktop notify-send | Notification |

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

Hooks are opinionated and on by default. To disable one, set it `false` in your
`deploy.json` and re-run `dotconfigs deploy` — the hook is then neither symlinked
nor wired into settings.json.

For per-project additions without editing the shared hook, use `.local` scripts:

- `.git/hooks/pre-commit.local` — runs at end of pre-commit
- `.git/hooks/pre-push.local` — runs at end of pre-push
- `.git/hooks/commit-msg.local` — runs at end of commit-msg

---

*Generated: 2026-06-05 11:31:05 UTC*

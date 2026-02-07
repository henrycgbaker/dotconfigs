---
created: 2026-02-07T10:30
title: dotgit flow — comprehensive git hooks management
area: tooling
files:
  - githooks/commit-msg
  - githooks/pre-commit
  - deploy.sh:140-162
---

## Problem

Current git hooks (commit-msg, pre-commit) are hardcoded and always-deployed. There's no toggleable system like HOOKS_ENABLED provides for Claude Code hooks. As more git hooks are needed (pre-push, prepare-commit-msg, etc.), the current approach won't scale.

The discover_hooks() function only scans hooks/*.py (Claude Code hooks), not githooks/ (git hooks). Git hooks need their own discovery, toggle, and deployment flow.

## Solution

New phase or separate tool/repo — either:
1. Expand dotclaude with a `dotgit` command/subcommand for git hooks management (discover, toggle, deploy per-project)
2. Separate `dotgit` repo with its own deployment and configuration

Should mirror the HOOKS_ENABLED pattern: discover available git hooks, let user toggle each, save to .env, deploy selected ones to .git/hooks/ or via core.hooksPath.

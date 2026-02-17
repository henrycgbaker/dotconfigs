---
created: 2026-02-17T00:00
title: Use hookify format rather than shell scripts for hooks
area: planning
files:
  - plugins/claude/hooks/
  - ~/.claude/settings.json
---

## Problem

Current hook implementation uses standalone shell scripts (e.g. `block-destructive.sh`, `pre-commit`) that are deployed via symlinks or copies. Claude Code now supports a "hookify" format — declarative hook definitions in `settings.json` with matchers and inline/referenced commands — which is more portable, doesn't require path resolution hacks, and integrates natively with Claude Code's hook system.

Moving to hookify format would:
- Eliminate the `$CLAUDE_PROJECT_DIR` path resolution issues (hooks defined declaratively, not as file paths)
- Simplify deployment (no symlinking shell scripts)
- Better align with Claude Code's native configuration model
- Reduce the shell script surface area that needs bash 3.2 compat testing

## Solution

TBD — investigate hookify format capabilities and constraints, then migrate existing shell script hooks to declarative hookify definitions. May overlap with the global vs project architecture rethink.

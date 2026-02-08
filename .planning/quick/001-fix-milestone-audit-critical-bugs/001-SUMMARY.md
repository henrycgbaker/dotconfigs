---
quick_task: 001
description: Fix 2 critical bugs from v2.0 milestone audit
completed: 2026-02-07
---

# Quick Task 001: Summary

## What Changed

### 1. lib/colours.sh — Added colour_cyan()

- Added `COLOUR_CYAN` initialisation in both TTY and non-TTY branches of `init_colours()`
- Added `colour_cyan()` function matching the pattern of existing colour helpers
- Fixes: `dotconfigs deploy --dry-run` banner display (6 call sites)

### 2. plugins/claude/project.sh — Added PLUGIN_DIR

- Added `PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` at file top
- Matches pattern used by `plugins/claude/deploy.sh` and `plugins/claude/setup.sh`
- Fixes: `dotconfigs project .` template path resolution (3 usage sites)

## Verification

- Both files pass `bash -n` syntax check
- No bash 4+ features introduced
- `colour_cyan` produces correct ANSI output in TTY mode

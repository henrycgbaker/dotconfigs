---
quick_task: 001
description: Fix 2 critical bugs from v2.0 milestone audit
status: complete
---

# Quick Task 001: Fix Milestone Audit Critical Bugs

## Context

The v2.0 milestone audit (`.planning/v2.0-MILESTONE-AUDIT.md`) identified 2 critical cross-phase integration bugs that block release.

## Tasks

### Task 1: Add colour_cyan() to lib/colours.sh

**Problem:** `dotconfigs` CLI calls `colour_cyan()` 6 times (lines 321-323, 352-354 for dry-run banners) but `lib/colours.sh` only defines green, yellow, and red.

**Fix:**
- Add `COLOUR_CYAN='\033[36m'` to TTY branch of `init_colours()`
- Add `COLOUR_CYAN=''` to non-TTY branch
- Add `colour_cyan()` function after `colour_red()`

**Files:** `lib/colours.sh`

### Task 2: Add PLUGIN_DIR to plugins/claude/project.sh

**Problem:** `plugins/claude/project.sh` uses `$PLUGIN_DIR` at lines 186, 187, 234 for template paths but never initialises it. Other plugin scripts (`deploy.sh`, `setup.sh`) have this line.

**Fix:**
- Add `PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` at top of file (after header comments)

**Files:** `plugins/claude/project.sh`

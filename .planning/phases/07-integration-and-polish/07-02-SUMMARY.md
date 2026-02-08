---
phase: 07-integration-and-polish
plan: 02
subsystem: cli
tags: [bash, status-reporting, drift-detection, colour-output, tty-detection]

# Dependency graph
requires:
  - phase: 07-01
    provides: "Shared infrastructure (colours, symlinks, help system)"
provides:
  - "cmd_status() and cmd_list() commands in dotconfigs CLI"
  - "plugin_claude_status() and plugin_git_status() functions"
  - "Per-file drift detection with 5-state model"
  - "TTY-aware colour output (ANSI when TTY, plain when piped)"
affects: [07-03, 07-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Plugin status functions follow plugin_<name>_status() naming convention"
    - "Status functions report per-file/per-config-item granularity"
    - "_print_config_status() helper for git config items"

key-files:
  created: []
  modified:
    - plugins/claude/deploy.sh
    - plugins/git/deploy.sh
    - dotconfigs

key-decisions:
  - "Status functions return per-file granularity with 5-state model (deployed, not-deployed, drifted-broken, drifted-foreign, drifted-wrong-target)"
  - "Git plugin uses _print_config_status() helper for config items (separate from file status)"
  - "List command shows minimal output: plugin name + installed/not-installed"
  - "All colour output respects TTY detection (plain text when piped)"

patterns-established:
  - "Plugin status functions: plugin_<name>_status() exported from deploy.sh"
  - "Status functions count ok/drift/missing states for overall plugin status"
  - "Special handling for generated files (CLAUDE.md) vs symlinks"

# Metrics
duration: 2min 36s
completed: 2026-02-07
---

# Phase 07 Plan 02: Status and List Commands Summary

**Working status and list commands with per-file drift detection, coloured TTY output, and plugin filtering**

## Performance

- **Duration:** 2min 36s
- **Started:** 2026-02-07T19:15:21Z
- **Completed:** 2026-02-07T19:17:56Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Per-file status reporting for Claude plugin (settings.json, CLAUDE.md, hooks, skills)
- Per-config-item status reporting for Git plugin (identity, workflow, aliases, hooks)
- Coloured status output with TTY detection (green OK, yellow drift, red missing)
- Minimal list command showing plugin installation status
- Plugin filtering support for status command

## Task Commits

Each task was committed atomically:

1. **Task 1: Add plugin status functions** - `dba8f2b` (feat)
2. **Task 2: Implement cmd_status and cmd_list** - `67597b8` (feat)

## Files Created/Modified
- `plugins/claude/deploy.sh` - Added plugin_claude_status() with per-file checking
- `plugins/git/deploy.sh` - Added plugin_git_status() with per-config-item checking
- `dotconfigs` - Implemented cmd_status() and rewrote cmd_list()

## Decisions Made

**1. Status functions report per-file/per-config granularity**
- Claude plugin checks each file individually (settings.json, CLAUDE.md, hooks, skills)
- Git plugin checks each config item individually (user.name, user.email, workflow settings, aliases)
- Overall plugin status derived from file/config states

**2. Special handling for CLAUDE.md (generated file)**
- CLAUDE.md is not a symlink (it's generated from templates)
- Status check: if file exists → deployed, if not → not-deployed
- Does not use check_file_state() function

**3. Git config items use separate _print_config_status() helper**
- Git manages config values, not symlinks
- _print_config_status() format matches _print_file_status() for consistency
- Shows current vs expected values for drifted config

**4. List command minimal output**
- Shows plugin name + installed/not-installed status
- Uses colour + symbols (green checkmark / red x-mark)
- No descriptions (per user decision for minimal output)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - implementation proceeded smoothly.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Status and list commands complete and functional
- Ready for Wave 3: deployment improvements (07-03, 07-04)
- All existing commands (setup, deploy, project, help) unaffected

## Self-Check: PASSED

All commits exist:
- dba8f2b: feat(07-02): add plugin status functions to claude and git
- 67597b8: feat(07-02): implement cmd_status and rewrite cmd_list

All modified files exist:
- plugins/claude/deploy.sh
- plugins/git/deploy.sh
- dotconfigs

---
*Phase: 07-integration-and-polish*
*Completed: 2026-02-07*

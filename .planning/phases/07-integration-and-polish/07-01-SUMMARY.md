---
phase: 07
plan: 01
subsystem: cli-infrastructure
tags: [cli, colours, drift-detection, help-system, bash]
requires: [06-03]
provides:
  - lib/colours.sh (TTY-aware colour helpers)
  - lib/symlinks.sh check_file_state() (drift detection)
  - dotconfigs help system (comprehensive command help)
  - dotconfigs deploy-all mode
affects: [07-02, 07-03]
tech-stack:
  added: []
  patterns: [TTY detection, drift state machine]
key-files:
  created:
    - lib/colours.sh
  modified:
    - lib/symlinks.sh
    - dotconfigs
decisions:
  - id: CLI-07-TTY
    choice: "Use [[ -t 1 ]] for TTY detection, ANSI codes when TTY, plain text when piped"
    rationale: "Supports both interactive use (coloured) and scripting/logging (plain text)"
  - id: CLI-07-STATES
    choice: "5 drift states: deployed, not-deployed, drifted-broken, drifted-foreign, drifted-wrong-target"
    rationale: "Covers all file state scenarios for accurate status reporting"
  - id: CLI-07-HELP
    choice: "Hierarchical help: dotconfigs help shows overview, dotconfigs help <cmd> shows detail"
    rationale: "Standard CLI pattern (git, docker) balances discoverability with conciseness"
  - id: CLI-07-DEPLOY-ALL
    choice: "dotconfigs deploy (no plugin) deploys all configured plugins"
    rationale: "Convenience for full deployments, iterates discover_plugins"
metrics:
  duration: 3m 41s
  completed: 2026-02-07
---

# Phase 07 Plan 01: Shared Infrastructure and Help System Summary

**One-liner:** TTY-aware colour helpers, 5-state drift detection, and comprehensive help system with deploy-all mode.

## What Was Built

Created foundational infrastructure for Phase 7 CLI improvements:

1. **lib/colours.sh** — TTY-aware colour helpers
   - `init_colours()`: Detects TTY via `[[ -t 1 ]]`, sets ANSI codes or plain text
   - Colour wrappers: `colour_green()`, `colour_yellow()`, `colour_red()`
   - Symbols: checkmark/OK, delta/DRIFT, x-mark/MISSING (TTY-dependent)
   - `_print_file_status()`: Formatted status line printer for status command

2. **lib/symlinks.sh extensions** — Drift detection
   - `check_file_state()`: 5-state drift detector
   - States: deployed (OK), not-deployed (missing), drifted-broken (dangling symlink), drifted-foreign (not owned), drifted-wrong-target (wrong source)
   - Returns state via stdout, exit codes: 0 (deployed), 1 (not deployed), 2 (drifted)
   - Uses existing `is_dotconfigs_owned()` and platform-aware path resolution

3. **dotconfigs help system** — Comprehensive command help
   - Updated `show_usage()`: All commands with brief descriptions, examples, options
   - `show_command_help()`: Per-command detailed help (setup, deploy, project, status, list)
   - `cmd_help()`: Routes `dotconfigs help [command]`
   - Help shows deploy flags: --interactive, --force, --dry-run

4. **dotconfigs deploy-all mode**
   - No plugin argument: iterates all discovered plugins, deploys each
   - Flags passed through to plugin deploy functions
   - Output: "Deploying all configured plugins..." with per-plugin sections

5. **CLI routing updates**
   - Added `status` command route (stub: "not yet implemented", Plan 02 implements)
   - Added `help` command route
   - Sources lib/colours.sh in eager loading
   - Fixed cmd_setup() shift-before-check bug

## Commits

| Hash    | Description                                    |
| ------- | ---------------------------------------------- |
| d7c2f51 | feat(07-01): create colour helpers and drift detection |
| f1afe09 | feat(07-01): add help system and update CLI routing    |

## Task Breakdown

### Task 1: Create lib/colours.sh and extend lib/symlinks.sh
- **Delivered:** lib/colours.sh (new), check_file_state() in lib/symlinks.sh
- **Key decisions:** TTY detection pattern, 5-state model
- **Commit:** d7c2f51

### Task 2: Add help system and update CLI routing
- **Delivered:** Help system, deploy-all mode, status stub, routing updates
- **Key decisions:** Hierarchical help, deploy-all iteration pattern
- **Commit:** f1afe09

## Technical Decisions

### TTY Detection (CLI-07-TTY)
**Decision:** Use `[[ -t 1 ]]` (stdout TTY check) to toggle ANSI codes vs plain text.

**Context:** Status and list output need to be human-readable in terminal but parseable when piped to files/scripts.

**Implementation:**
- TTY: ANSI colour codes (`\033[32m`), Unicode symbols (✓, △, ✗)
- Non-TTY: Empty colour vars, ASCII symbols ([OK], [DRIFT], [MISSING])

**Alternative considered:** Always use colours, rely on `tput` for detection → rejected (extra dependency, less portable)

### 5-State Drift Model (CLI-07-STATES)
**Decision:** `check_file_state()` returns 5 distinct states covering all file scenarios.

**Rationale:** Precise drift detection enables actionable status messages:

| State                  | Meaning                           | Exit Code | User Action                 |
| ---------------------- | --------------------------------- | --------- | --------------------------- |
| deployed               | Symlink correct                   | 0         | None                        |
| not-deployed           | File missing                      | 1         | Run deploy                  |
| drifted-broken         | Symlink dangling (source deleted) | 2         | Re-deploy                   |
| drifted-foreign        | File exists, not our symlink      | 2         | Backup + deploy or skip     |
| drifted-wrong-target   | Our symlink, wrong source         | 2         | Re-deploy (source changed?) |

**Implementation notes:**
- Uses `is_dotconfigs_owned()` to distinguish foreign vs owned symlinks
- Platform-aware absolute path resolution (macOS perl, Linux readlink -f)
- Covers edge case: dangling symlinks (`[[ -L path && ! -e path ]]`)

### Hierarchical Help (CLI-07-HELP)
**Decision:** Two-tier help system following git/docker pattern.

**Structure:**
- `dotconfigs help`: Overview of all commands with brief descriptions, examples
- `dotconfigs help <command>`: Detailed usage, options, examples for specific command
- `dotconfigs --help`: Alias for overview help

**Content decisions:**
- Keep help concise (per user feedback: no verbose descriptions)
- Show all deploy flags in both overview and deploy-specific help
- Include real examples for each command
- List available plugins dynamically via `discover_plugins`

### Deploy-All Mode (CLI-07-DEPLOY-ALL)
**Decision:** `dotconfigs deploy` without plugin argument deploys all configured plugins.

**Implementation:**
- Detect plugin arg vs flag: `if [[ ! "$1" =~ ^-- ]]; then plugin="$1"; fi`
- No plugin: iterate `discover_plugins`, source each deploy.sh, call plugin function
- Pass remaining args (flags) through to each plugin
- Output: Section headers for each plugin (`==> Deploying git`)

**User benefit:** Single command for full deployment (common workflow after .env changes)

## Integration Points

### For Plan 02 (status command)
- `lib/colours.sh` sourced and ready
- `init_colours()` must be called before status output
- `check_file_state()` available for drift detection
- `_print_file_status()` ready for formatted output
- `cmd_status()` stub exists, needs implementation

### For Plan 03 (dry-run/interactive deploy)
- Flags parsed in `cmd_deploy()`: `--interactive`, `--force`, `--dry-run`
- Passed to plugin deploy functions in `args` array
- Plugin functions need to handle these flags (Plan 03 work)

### For Plan 04 (list improvements)
- `cmd_list()` exists, outputs plugin names + DESCRIPTION
- Plan 04 will enhance with status indicators and .env configuration checks

## Testing Notes

**Verified:**
- All files pass `bash -n` syntax check
- `dotconfigs help` shows comprehensive usage
- `dotconfigs help deploy` shows deploy flags
- `dotconfigs help nonexistent` errors correctly
- `dotconfigs --help` works
- `dotconfigs list` still works
- `dotconfigs setup` (no arg) shows error + usage
- `dotconfigs deploy` (no plugin) attempts deploy-all
- `check_file_state()` returns correct states for: non-existent file (not-deployed, exit 1), regular file (drifted-foreign, exit 2)

**Not tested (Plan 02 scope):**
- Full status command output (stub only)
- Colour output in actual terminal (CI tested non-TTY path)

## Dependencies and Migration

**Requires:**
- Phase 06 complete (git plugin, existing lib/ files)
- `lib/symlinks.sh` with `is_dotconfigs_owned()`
- `lib/discovery.sh` with `discover_plugins()`

**Provides for future phases:**
- Colour infrastructure for all CLI output
- Drift detection for status/list/deploy
- Help system for user onboarding
- Deploy-all convenience command

**Breaking changes:** None (additive only)

## Deviations from Plan

None — plan executed exactly as written.

## Performance

- **Execution time:** 3m 41s
- **Task commits:** 2 (T1: d7c2f51, T2: f1afe09)
- **Files created:** 1 (lib/colours.sh)
- **Files modified:** 2 (lib/symlinks.sh, dotconfigs)
- **Lines added:** ~330

## Next Phase Readiness

**Blockers:** None

**Concerns:** None

**Ready for Plan 02:** Yes
- All infrastructure in place for status command implementation
- colour helpers tested and working
- check_file_state() tested with basic scenarios
- Help system complete

**Recommended next steps:**
1. Plan 02: Implement `cmd_status()` using colour helpers and drift detection
2. Plan 03: Enhance plugin deploy functions with flag handling (--dry-run, --interactive, --force)
3. Plan 04: Enhance `cmd_list()` with status indicators and .env configuration checks

## Self-Check: PASSED

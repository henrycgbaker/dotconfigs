---
phase: 04-core-infrastructure-cli-entry-point
plan: 02
subsystem: cli-entry-point
tags: [bash, cli, routing, plugin-architecture]
requires: [04-01]
provides: [dotconfigs-cli, plugin-stubs, end-to-end-routing]
affects: [05-claude-plugin]
tech-stack:
  added: []
  patterns: [subcommand-routing, lazy-plugin-loading, filesystem-based-discovery]
key-files:
  created: [dotconfigs, plugins/claude/setup.sh, plugins/claude/deploy.sh]
  modified: []
key-decisions:
  - decision: Subcommand-based CLI (not flag-based)
    rationale: Cleaner user experience, natural plugin routing
    impact: All plugins use `dotconfigs <command> <plugin>` pattern
  - decision: Lazy plugin loading (source on-demand)
    rationale: Fast startup, only load what's needed
    impact: Plugins sourced in cmd_setup/cmd_deploy, not at startup
  - decision: No shebang in plugin files
    rationale: Plugin files are sourced libraries, not executed directly
    impact: Prevents accidental direct execution, clarifies sourcing pattern
patterns-established:
  - Plugin function naming: plugin_<name>_<action>
  - Error handling: stderr for errors, stdout for usage, non-zero exit codes
  - Dynamic plugin discovery via filesystem scanning
duration: 2m
completed: 2026-02-07
---

# Phase 04 Plan 02: CLI Entry Point & Plugin Stubs Summary

**One-liner:** Subcommand-based CLI with lazy plugin loading and filesystem-based discovery

## Performance

- **Start time:** 2026-02-07T14:31:02Z
- **End time:** 2026-02-07T14:33:04Z
- **Duration:** 2 minutes 2 seconds
- **Tasks completed:** 2/2
- **Commits:** 2 (plus metadata commit)

## Accomplishments

Created the complete CLI entry point with end-to-end plugin routing:

1. **dotconfigs CLI entry point** — Executable script at repo root with subcommand dispatch (setup/deploy/list/help), eager lib loading, lazy plugin loading, comprehensive error handling, and dynamic plugin discovery

2. **Claude plugin stubs** — Minimal plugin implementation proving the architecture works (plugins/claude/setup.sh and plugins/claude/deploy.sh with stub functions)

3. **End-to-end verification** — Full routing chain tested: CLI → discovery → validation → plugin execution, including all error cases and extensibility proof

## Task Commits

| Task | Commit  | Description                                    |
| ---- | ------- | ---------------------------------------------- |
| 1    | 5ca8f7d | Create dotconfigs CLI entry point              |
| 2    | 958b5e5 | Create claude plugin stubs with e2e routing    |

## Files Created

**dotconfigs**
- Executable CLI entry point at repo root
- 117 lines of bash
- Sources all 4 lib files eagerly
- Routes setup/deploy/list/help subcommands
- Validates plugins before execution
- Dynamic usage display with plugin discovery

**plugins/claude/setup.sh**
- Plugin setup stub with plugin_claude_setup function
- Returns 0 (success) for testing
- Prints stub message indicating Phase 5 implementation

**plugins/claude/deploy.sh**
- Plugin deploy stub with plugin_claude_deploy function
- Returns 0 (success) for testing
- Prints stub message indicating Phase 5 implementation

## Files Modified

None — all files created new in this plan.

## Decisions Made

**1. Subcommand-based CLI design**
- **Context:** Choose between `dotconfigs --setup claude` vs `dotconfigs setup claude`
- **Decision:** Subcommand pattern (`dotconfigs setup claude`)
- **Reasoning:** More intuitive, cleaner routing logic, standard Unix pattern (git, docker, etc.)
- **Impact:** All commands follow verb-noun pattern, simpler dispatch logic

**2. Lazy plugin loading**
- **Context:** When to source plugin files
- **Decision:** Source plugins on-demand in cmd_setup/cmd_deploy, not at startup
- **Reasoning:** Fast startup time, only load what's needed, better error isolation
- **Impact:** Startup time stays constant regardless of plugin count

**3. No shebang in plugin files**
- **Context:** Should plugin files have `#!/bin/bash`?
- **Decision:** No shebang in plugin files (they're sourced, not executed)
- **Reasoning:** Clarifies that plugins are libraries, prevents accidental direct execution
- **Impact:** Plugin files are clearly marked as sourced libraries in comments

**4. Error output to stderr**
- **Context:** Where to send error messages
- **Decision:** All errors to stderr, usage to stdout, non-zero exit codes
- **Reasoning:** Standard Unix convention, allows output redirection
- **Impact:** Error handling follows best practices, scriptable in pipelines

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None — all implementation went smoothly.

## Next Phase Readiness

**Ready for Phase 5:** Plugin implementation

The CLI infrastructure is complete and tested. All routing works end-to-end:
- `dotconfigs setup claude` routes to plugin_claude_setup
- `dotconfigs deploy claude` routes to plugin_claude_deploy
- Plugin discovery works automatically via filesystem
- Error handling covers all edge cases
- Extensibility proven: adding a plugin directory makes it available with zero entry point changes

**Phase 5 can now implement:**
- Full plugin_claude_setup wizard (interactive configuration)
- Full plugin_claude_deploy logic (file deployment with symlinks)
- Real functionality replacing stubs

**Blockers:** None

**Concerns:** None — architecture proven solid

**Recommendations:**
- Phase 5 should start with setup.sh (more complex, interactive)
- Deploy.sh can reuse patterns from setup.sh once established
- Consider adding DESCRIPTION files to plugins for better `dotconfigs list` output

## Self-Check: PASSED

All created files verified:
- dotconfigs
- plugins/claude/setup.sh
- plugins/claude/deploy.sh

All commits verified:
- 5ca8f7d
- 958b5e5

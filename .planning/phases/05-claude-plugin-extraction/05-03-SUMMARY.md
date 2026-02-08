---
phase: 05-claude-plugin-extraction
plan: 03
subsystem: infra
tags: [bash, deployment, plugin-architecture, symlinks]

# Dependency graph
requires:
  - phase: 05-01
    provides: "Plugin structure with assets migrated, discovery functions adapted"
provides:
  - "Full Claude deployment implementation reading CLAUDE_* keys from .env"
  - "File-level symlink deployment preserving GSD coexistence"
  - "CLAUDE.md builder from template sections"
  - "Git hooks and identity configuration"
affects: [05-04, 05-05, CLI-03, COMP-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CLAUDE_* prefix for all Claude plugin config keys"
    - "_plugin_* prefix for internal functions"
    - "Plugin-relative asset paths via PLUGIN_DIR"
    - "Repo root access via DOTCONFIGS_ROOT"

key-files:
  created: []
  modified:
    - "plugins/claude/deploy.sh"

key-decisions:
  - "CLAUDE_* prefix for all config keys (namespace separation)"
  - "Plugin derives DOTCONFIGS_ROOT from PLUGIN_DIR location"
  - "Settings.json symlinked from repo root (global shared file)"
  - "Hooks/commands symlinked from plugin dir (plugin assets)"
  - "Git hooks remain in Claude plugin until Phase 6 Git plugin extraction"
  - "Shell aliases and remote deploy dropped (dead code)"

patterns-established:
  - "Config loading: source .env then parse space-separated strings to arrays"
  - "Asset paths: plugin assets via PLUGIN_DIR, shared files via DOTCONFIGS_ROOT"
  - "Internal functions prefixed with _claude_ for namespacing"

# Metrics
duration: 1min
completed: 2026-02-07
---

# Phase 05 Plan 03: Claude Deployment Logic Summary

**Full deployment implementation extracting deploy_global() logic with CLAUDE_* config keys, file-level symlinks, and bash 3.2 compatibility**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-07T16:48:36Z
- **Completed:** 2026-02-07T16:50:01Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Extracted deployment logic from deploy.sh deploy_global() into plugin_claude_deploy()
- Implemented _claude_load_config() to read CLAUDE_* prefixed keys from .env
- Implemented _claude_build_md() to build CLAUDE.md from enabled template sections
- Deployment handles settings.json, CLAUDE.md, hooks, skills, git hooks, git identity, GSD framework
- GSD coexistence maintained via backup_and_link file-level symlinks
- Interactive conflict handling preserved for non-interactive and interactive modes
- Shell aliases and remote deploy logic dropped (dead code from v1)

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement plugin_claude_deploy with CLAUDE_* key reading** - `378f99c` (feat)

**Plan metadata:** (to be committed after SUMMARY.md)

## Files Created/Modified
- `plugins/claude/deploy.sh` - Full deployment logic extracted from deploy.sh lines 48-536, adapted for plugin architecture with CLAUDE_* config keys

## Decisions Made

**1. CLAUDE_* prefix for all config keys**
- Rationale: Namespace separation for Claude plugin config vs future git/shell plugins
- Keys: CLAUDE_DEPLOY_TARGET, CLAUDE_SETTINGS_ENABLED, CLAUDE_MD_SECTIONS, CLAUDE_HOOKS_ENABLED, CLAUDE_SKILLS_ENABLED, CLAUDE_GSD_INSTALL, CLAUDE_GIT_USER_NAME, CLAUDE_GIT_USER_EMAIL

**2. Plugin derives DOTCONFIGS_ROOT from PLUGIN_DIR**
- Rationale: Plugin can find repo root without entry point passing it as parameter
- Implementation: `DOTCONFIGS_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"`

**3. Settings.json symlinked from repo root**
- Rationale: settings.json is a shared global file, not plugin-specific
- Source: `$DOTCONFIGS_ROOT/settings.json`

**4. Hooks/commands symlinked from plugin dir**
- Rationale: These are Claude plugin assets, stored under plugins/claude/
- Sources: `$PLUGIN_DIR/hooks/`, `$PLUGIN_DIR/commands/`

**5. Git hooks remain in Claude plugin**
- Rationale: Phase 6 will extract to git plugin, but current deploy.sh has them so maintain behaviour
- Location: `$DOTCONFIGS_ROOT/githooks/` (root level, not plugin-specific yet)

**6. Shell aliases and remote deploy dropped**
- Rationale: Dead code - aliases referenced deploy.sh which is being deleted, remote deploy not used
- Impact: Cleaner codebase, no functionality loss

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for:**
- Phase 05-04: Entry point cmd_deploy integration
- Phase 05-05: Entry point cmd_setup integration
- CLI-03: `dotconfigs deploy claude` command functional

**Blockers:**
None.

**Notes:**
- Deploy function requires .env file with CLAUDE_* keys (created by setup wizard)
- Entry point must source lib/symlinks.sh before calling plugin_claude_deploy (uses backup_and_link)
- Git hooks deployment will move to git plugin in Phase 6

---
*Phase: 05-claude-plugin-extraction*
*Completed: 2026-02-07*

## Self-Check: PASSED

All files and commits verified:
- ✓ plugins/claude/deploy.sh exists
- ✓ Commit 378f99c exists

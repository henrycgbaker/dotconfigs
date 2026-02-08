---
phase: 04-core-infrastructure-cli-entry-point
plan: 01
subsystem: shared-library
tags: [bash, library, wizard, symlinks, discovery, validation, plugin-architecture]
requires: []
provides:
  - lib/wizard.sh (interactive wizard helpers)
  - lib/symlinks.sh (symlink management with conflict handling)
  - lib/discovery.sh (plugin discovery + legacy content scanning)
  - lib/validation.sh (path/git validation helpers)
affects:
  - 04-02 (CLI entry point will source all lib/ files)
  - 05-* (All plugins will consume lib/ functions)
tech-stack:
  added: []
  patterns:
    - Bash 3.2 compatibility (macOS native bash)
    - Sourced libraries without shebangs
    - Filesystem-based plugin discovery
    - perl-based readlink for macOS portability
key-files:
  created:
    - lib/wizard.sh
    - lib/symlinks.sh
    - lib/discovery.sh
    - lib/validation.sh
  modified: []
key-decisions:
  - decision: "Remove shebangs from lib files"
    rationale: "These are sourced libraries, not executable scripts"
    impact: "Clear distinction between entry points and libraries"
  - decision: "Keep legacy discovery functions alongside new plugin functions"
    rationale: "plugins/claude/ in Phase 5 will need hooks/skills/templates discovery"
    impact: "Strangler fig migration — old and new coexist"
  - decision: "Use find with basename instead of globbing"
    rationale: "Consistent across macOS and Linux, handles spaces in names"
    impact: "Reliable plugin discovery"
patterns-established:
  - "lib/ as shared foundation sourced eagerly"
  - "Plugin discovery via filesystem scanning (find + basename)"
  - "Validation helpers with descriptive error messages"
  - "wizard_* prefix for interactive functions"
duration: 1min 42s
completed: 2026-02-07
---

# Phase 04 Plan 01: Shared Library Layer Summary

**One-liner:** Shared lib layer with wizard, symlinks, discovery, validation for bash 3.2 plugin architecture

## Performance

- **Execution time:** 1min 42s
- **Tasks completed:** 2/2
- **Commits created:** 2 (atomic per-task commits)
- **Files created:** 4 lib files (392 total lines)

## Accomplishments

Created the foundational `lib/` directory with four shared libraries that form the basis for the plugin architecture:

1. **lib/wizard.sh** — Interactive wizard helpers (6 functions)
   - wizard_prompt, wizard_select, wizard_yesno, wizard_header
   - wizard_save_env for .env management
   - _is_in_list utility

2. **lib/symlinks.sh** — Symlink management (3 functions)
   - is_dotclaude_owned for ownership detection
   - backup_and_link with conflict handling
   - link_file wrapper with macOS perl compatibility

3. **lib/discovery.sh** — Plugin + content discovery (8 functions)
   - NEW: discover_plugins, plugin_exists, list_available_plugins
   - LEGACY: discover_hooks, discover_githooks, discover_skills, discover_claude_sections, discover_settings_templates

4. **lib/validation.sh** — Validation helpers (4 functions)
   - validate_path, is_git_repo, validate_git_repo
   - expand_path for tilde expansion

All code is bash 3.2 compatible (no namerefs, associative arrays, ${var,,} operators).

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Move and update wizard.sh and symlinks.sh | aff87d4 | lib/wizard.sh, lib/symlinks.sh |
| 2 | Create discovery.sh and validation.sh | 2d599f1 | lib/discovery.sh, lib/validation.sh |

## Files Created

```
lib/
├── wizard.sh        (112 lines) — Interactive wizard functions
├── symlinks.sh      (109 lines) — Symlink conflict handling
├── discovery.sh     (117 lines) — Plugin + content discovery
└── validation.sh     (44 lines) — Path/git validation
```

## Files Modified

None. Original files in `scripts/lib/` intentionally preserved for strangler fig migration (deploy.sh still depends on them).

## Decisions Made

1. **No shebangs in lib files**
   - These are sourced libraries, not executables
   - Clear architectural distinction

2. **Hybrid discovery.sh**
   - New plugin discovery functions for v2.0 architecture
   - Preserved legacy functions for hooks/skills/templates
   - Enables gradual migration in Phase 5

3. **macOS compatibility via perl**
   - Preserved perl-based readlink workaround from v1
   - macOS native bash lacks readlink -f

4. **Filesystem-based plugin discovery**
   - No hardcoded plugin lists
   - find + basename pattern for robustness
   - Validates setup.sh + deploy.sh presence

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None. All bash syntax validated, all functions present, zero bash 4+ features confirmed.

## Next Phase Readiness

**Ready for 04-02:** CLI entry point implementation

The lib/ foundation is complete and tested. Next plan can:
- Source all four lib files eagerly
- Use wizard_* functions for interactive setup
- Use discover_plugins + plugin_exists for plugin enumeration
- Use validation helpers for path/git checks

**Blockers:** None

**Concerns:** None

**Dependencies satisfied:**
- ✓ Bash 3.2 compatible code
- ✓ macOS portability (perl readlink)
- ✓ All planned functions implemented

## Self-Check: PASSED

All created files verified:
- lib/wizard.sh ✓
- lib/symlinks.sh ✓
- lib/discovery.sh ✓
- lib/validation.sh ✓

All commits verified:
- aff87d4 ✓
- 2d599f1 ✓

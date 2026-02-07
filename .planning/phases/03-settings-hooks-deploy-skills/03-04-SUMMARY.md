---
phase: 03-settings-hooks-deploy-skills
plan: 04
subsystem: tooling
tags: [bash, skills, deployment, symlinks, wizard]

# Dependency graph
requires:
  - phase: 03-01
    provides: Settings templates and rules framework
provides:
  - Updated /commit and /squash-merge skills with stale reference fixes
  - New /simplicity-check skill for on-demand complexity review
  - Shared bash libraries for wizard prompts, symlink management, and dynamic discovery
affects: [03-05, 03-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bash select for interactive menus (no external dependencies)"
    - "macOS portability via OSTYPE detection for readlink"
    - "Dynamic discovery functions scan filesystem (no hardcoded lists)"

key-files:
  created:
    - commands/simplicity-check.md
    - scripts/lib/wizard.sh
    - scripts/lib/symlinks.sh
    - scripts/lib/discovery.sh
  modified:
    - commands/commit.md
    - commands/squash-merge.md

key-decisions:
  - "Use bash select for menus (no dialog/whiptail dependencies)"
  - "Symlink ownership detection via dotclaude path prefix matching"
  - "macOS portability via perl for absolute path resolution"

patterns-established:
  - "All lib functions accept repo root as argument (no globals)"
  - "Discovery functions dynamically scan directories"
  - "Symlink functions handle conflicts with interactive/non-interactive modes"

# Metrics
duration: 2min
completed: 2026-02-06
---

# Phase 3 Plan 4: Skills and Libraries Summary

**Three skills updated with stale reference fixes and new /simplicity-check created; shared bash libraries (wizard, symlinks, discovery) ready for deploy.sh to source**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-06T16:50:27Z
- **Completed:** 2026-02-06T16:52:37Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Removed stale /rules/ references from /commit and /squash-merge skills
- Created new /simplicity-check skill for on-demand complexity review (QUAL-02)
- Built wizard.sh with bash select-based interactive prompts
- Built symlinks.sh with ownership detection and macOS portability
- Built discovery.sh with dynamic scanning for hooks, skills, and templates

## Task Commits

Each task was committed atomically:

1. **Task 1: Update skills and create /simplicity-check** - `a97cc6a` (feat)
2. **Task 2: Create shared bash library functions** - `6c04215` (feat)

## Files Created/Modified
- `commands/commit.md` - Removed stale "See rule: git-commits" reference
- `commands/squash-merge.md` - Changed /rules/git-commits.md to CLAUDE.md Git section
- `commands/simplicity-check.md` - New on-demand complexity review skill with 4 simplicity principles
- `scripts/lib/wizard.sh` - Interactive wizard functions (prompt, select, yesno, header, save_env)
- `scripts/lib/symlinks.sh` - Symlink management (is_dotclaude_owned, backup_and_link, link_file) with macOS portability
- `scripts/lib/discovery.sh` - Dynamic scanning (discover_hooks, discover_githooks, discover_skills, discover_claude_sections, discover_settings_templates)

## Decisions Made
- **Bash select for menus:** No external dependencies (dialog, whiptail) - use built-in bash select for portability
- **Ownership detection:** Check if symlink target starts with dotclaude_root path prefix
- **macOS portability:** Use perl for absolute path resolution on darwin, readlink -f on linux
- **Dynamic discovery:** Scan filesystem at runtime, no hardcoded lists

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Skills ready for symlink deployment in 03-05
- Shared libraries ready for deploy.sh to source in 03-06
- No blockers for remaining Phase 3 plans

## Self-Check: PASSED

---
*Phase: 03-settings-hooks-deploy-skills*
*Completed: 2026-02-06*

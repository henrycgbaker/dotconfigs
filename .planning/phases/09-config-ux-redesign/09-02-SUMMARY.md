---
phase: 09-config-ux-redesign
plan: 02
subsystem: cli-ux
tags: [bash, wizard, colours, settings.json, gitignore]

# Dependency graph
requires:
  - phase: 08-hooks-architecture
    provides: Complete hooks infrastructure and CLI integration
provides:
  - Colour badge helpers for G/L provenance display (cyan Global, green Local)
  - Wizard helpers for opt-in category menus and config toggles
  - Complete settings.json template with all common rules
  - Root settings.json gitignore entry
affects: [09-03, 09-04, 09-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Provenance badge helpers for wizard summaries"
    - "Category-based wizard navigation patterns"
    - "Edit-mode display with managed/unmanaged states"

key-files:
  created:
    - plugins/claude/templates/settings/settings-template.json
  modified:
    - lib/colours.sh
    - lib/wizard.sh
    - .gitignore

key-decisions:
  - "Settings template includes all common rules (Python, Node, git, docker, hooks)"
  - "Dim colour constant for [not managed] labels"
  - "wizard_config_toggle adds 'none' option vs existing wizard_checkbox_menu"

patterns-established:
  - "colour_badge_global/local for G/L provenance in wizard summaries"
  - "wizard_category_menu uses read (not select) for numbered input"
  - "wizard_edit_mode_display shows current config with managed/unmanaged states"
  - "wizard_parse_edit_selection handles comma-separated edit selections"

# Metrics
duration: 2min
completed: 2026-02-09
---

# Phase 09 Plan 02: Shared Wizard Infrastructure Summary

**Colour badge helpers, opt-in wizard functions, and complete settings.json template for G/L provenance UX**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-09T23:27:21Z
- **Completed:** 2026-02-09T23:29:15Z
- **Tasks:** 3
- **Files modified:** 4 (created 1, modified 3)

## Accomplishments
- Added G/L provenance colour badge helpers (cyan [G], green [L], dim [not managed])
- Added four wizard helper functions for opt-in category navigation
- Created complete settings-template.json with all common permission rules
- Added settings.json to .gitignore to prevent committing personal config

## Task Commits

Each task was committed atomically:

1. **Task 1: Add G/L provenance badge helpers to lib/colours.sh** - `3bc18fb` (feat)
2. **Task 2: Add opt-in wizard helpers to lib/wizard.sh** - `0e5db77` (feat)
3. **Task 3: Create settings.json template + add .gitignore entry** - `1bb19b6` (feat)

## Files Created/Modified
- `lib/colours.sh` - Added colour_badge_global(), colour_badge_local(), colour_not_managed(), COLOUR_DIM constant
- `lib/wizard.sh` - Added wizard_category_menu(), wizard_edit_mode_display(), wizard_parse_edit_selection(), wizard_config_toggle()
- `plugins/claude/templates/settings/settings-template.json` - Complete reference template with Python/Node/git/docker rules, hooks, env vars, sandbox config
- `.gitignore` - Added settings.json entry to prevent committing personal config

## Decisions Made
- **Template structure:** Merged all existing partial templates (base, python, node, hooks) into one complete reference template with _template_note explaining usage
- **Dim colour for unmanaged:** Added COLOUR_DIM constant for [not managed] labels in edit mode
- **wizard_config_toggle vs wizard_checkbox_menu:** New function adds 'none' option for deselecting all configs, cleaner formatting for config toggle UX

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Plans 09-03 (Git wizard opt-in) and 09-04 (Claude wizard opt-in) can now use these shared helpers
- Plan 09-05 (project-configs wizard) can use badge helpers for G/L provenance display
- Complete settings.json template ready as public reference for users

---
*Phase: 09-config-ux-redesign*
*Completed: 2026-02-09*

## Self-Check: PASSED

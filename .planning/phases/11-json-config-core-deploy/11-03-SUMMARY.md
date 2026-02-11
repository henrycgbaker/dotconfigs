---
phase: 11-json-config-core-deploy
plan: 03
subsystem: cli
tags: [bash, json, deployment, project-config]

# Dependency graph
requires:
  - phase: 11-01
    provides: deploy_from_json() generic deployer with JSON parsing
provides:
  - cmd_project() reads .dotconfigs/project.json and deploys to projects
  - cmd_project_init() scaffolds project.json from template
  - Project-root-relative target path resolution in deploy_from_json
  - Auto-exclusion of .dotconfigs/ directory
affects: [11-04, project-deployment, per-project-config]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Per-project config in .dotconfigs/project.json"
    - "project_root parameter for relative target resolution"
    - "Auto-exclude pattern for project metadata directories"

key-files:
  created: []
  modified:
    - dotconfigs
    - lib/deploy.sh

key-decisions:
  - "project_root parameter resolves relative targets against project path"
  - "Removed plugin-based project.sh scripts in favour of JSON config"
  - ".dotconfigs/ auto-excluded to keep project git clean"

patterns-established:
  - "Project config pattern: source paths from dotconfigs root, targets relative to project"
  - "Auto-exclude pattern: add to .git/info/exclude after deployment"

# Metrics
duration: 3min
completed: 2026-02-11
---

# Phase 11 Plan 03: Project JSON Config Summary

**CLI commands for per-project deployment: `dotconfigs project` reads JSON config and deploys, `dotconfigs project-init` scaffolds the template**

## Performance

- **Duration:** 3 min 14 sec
- **Started:** 2026-02-11T22:35:14Z
- **Completed:** 2026-02-11T22:38:28Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Project-level JSON deployment replaces broken plugin project.sh scripts
- Source paths resolve against dotconfigs repo root
- Target paths resolve relative to project root
- .dotconfigs/ automatically excluded from git

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement cmd_project for JSON-based project deployment** - `4cb134c` (feat)
2. **Task 2: Implement cmd_project_init for scaffolding project.json** - `2261d97` (feat)

## Files Created/Modified
- `dotconfigs` - Added cmd_project() and cmd_project_init(), updated routing and help text
- `lib/deploy.sh` - Added project_root parameter to deploy_from_json() for relative target resolution

## Decisions Made

**Relative path resolution pattern:**
- When project_root is set, targets NOT starting with `/` or `~` are resolved relative to project_root
- Absolute and tilde paths always resolve normally
- Backwards compatible: when project_root is empty (global deploy), all paths expand normally

**Auto-exclude .dotconfigs/:**
- Both cmd_project and cmd_project_init ensure .dotconfigs/ is added to .git/info/exclude
- Keeps project git status clean without requiring .gitignore changes
- Skipped in dry-run mode

**Removed plugin filter from project-init:**
- Old cmd_project_configs accepted optional plugin argument
- New cmd_project_init deploys all modules from project.json
- Simpler UX: users edit JSON to control what's deployed

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for Phase 11-04 (global/project deploy workflows).

Key capabilities now available:
- Per-project config scaffolding
- JSON-driven project deployment
- Source/target path resolution
- Auto-exclusion of project metadata

Blockers: None

## Self-Check: PASSED

---
*Phase: 11-json-config-core-deploy*
*Completed: 2026-02-11*

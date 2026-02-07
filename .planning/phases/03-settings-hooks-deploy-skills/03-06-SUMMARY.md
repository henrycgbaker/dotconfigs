---
phase: 03-settings-hooks-deploy-skills
plan: 06
subsystem: infra
tags: [bash, deployment, ssh, project-scaffolding]

# Dependency graph
requires:
  - phase: 03-05
    provides: "deploy.sh global subcommand with wizard and symlink deployment"
provides:
  - "Project scaffolding with type-aware defaults (Python/Node/Go)"
  - "Remote deployment via SSH (clone or rsync methods)"
  - "Brownfield/greenfield project detection"
  - "Settings.json template merging system"
affects: [03-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Project type detection via filesystem markers (pyproject.toml, package.json, go.mod)"
    - "JSON template merging (base + type overlay)"
    - "Remote deployment with per-machine .env separation"
    - "SSH connection testing with fast-fail timeout"

key-files:
  created: []
  modified:
    - deploy.sh

key-decisions:
  - "Project settings.json built from templates (not symlinked) for per-project customisation"
  - "Hooks.conf copied (not symlinked) for per-project git hook configuration"
  - "CLAUDE.md created/appended but never blindly overwritten (brownfield protection)"
  - ".git/info/exclude appends only (preserves existing exclusions)"
  - "Remote deployment excludes .env (per-machine configuration)"
  - "Remote uses clone method by default (preserves git history)"
  - "Rsync method available as alternative (no git dependency on remote)"

patterns-established:
  - "Greenfield/brownfield detection pattern: check for .claude/, CLAUDE.md, .git/info/exclude"
  - "Project type detection: Python → pyproject.toml/setup.py/requirements.txt, Node → package.json, Go → go.mod"
  - "Interactive conflict resolution: overwrite/skip/show diff menu via bash select"
  - "Remote deployment pattern: test connection → transfer repo → run deploy.sh → optional GSD install"

# Metrics
duration: 2min
completed: 2026-02-06
---

# Phase 3 Plan 6: Project Scaffolding and Remote Deployment Summary

**Project scaffolding with type-aware settings/hooks templates and remote SSH deployment (clone/rsync) — deploy.sh now complete with global, project, and remote capabilities**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-06T17:00:36Z
- **Completed:** 2026-02-06T17:02:48Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Project scaffolding with intelligent brownfield detection and conflict resolution
- Type-aware defaults (Python/Node/Go) for settings.json and hooks.conf
- Remote deployment via SSH with clone (default) or rsync transfer methods
- deploy.sh now complete: replaces both setup.sh and deploy-remote.sh

## Task Commits

Each task was committed atomically:

1. **Task 1: Add project subcommand to deploy.sh** - `6e61b7e` (feat)
2. **Task 2: Add remote deployment support to deploy.sh** - `f7d6099` (feat)

## Files Created/Modified

- `deploy.sh` - Added 470 lines for project and remote deployment (509 → 970 lines total)
  - `detect_project_type()` - Filesystem-based project type detection
  - `merge_settings_json()` - Template merging via jq or Python fallback
  - `cmd_project()` - Full project scaffolding workflow
  - `deploy_remote()` - SSH-based remote deployment

## Decisions Made

1. **Settings.json built not symlinked:** Project settings.json is merged from templates/settings/base.json + type overlay (python.json, node.json) to allow per-project customisation. This is the only exception to the symlink ownership model.

2. **Hooks.conf copied not symlinked:** Per-project hooks.conf is a copy of templates/hooks-conf/ template (default/strict/permissive) to allow per-project git hook configuration.

3. **CLAUDE.md append-only:** Existing CLAUDE.md never blindly overwritten. Interactive mode offers append/skip. Non-interactive mode skips.

4. **Git exclusions append-only:** .git/info/exclude only appends missing entries (CLAUDE.md, .claude/, .claude-project). Never overwrites existing exclusions.

5. **Remote .env separation:** Remote deployment excludes .env from rsync. Remote machines run deploy.sh global with their own wizard/config.

6. **Clone method default:** Remote deployment defaults to `git clone` (or `git pull` if exists) to preserve git history and enable updates. Rsync available as fallback for no-git environments.

7. **Type-aware defaults:** Python projects → RUFF_ENABLED=true, Node projects → RUFF_ENABLED=false in hooks.conf.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for Plan 07:**
- deploy.sh feature-complete with global, project, and remote subcommands
- Ready to deprecate setup.sh and deploy-remote.sh (deleted in 03-07)
- Skills (commands/) ready for implementation in remaining plans

**Remaining Phase 3 work:**
- 03-07: Cleanup (delete setup.sh, deploy-remote.sh, update docs)

## Self-Check: PASSED

All files and commits verified.

---
*Phase: 03-settings-hooks-deploy-skills*
*Completed: 2026-02-06*

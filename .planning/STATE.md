# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-11)

**Core value:** Single source of truth for all personal dev configuration — one repo, one JSON config, deployed everywhere via symlinks.
**Current focus:** v3.0 Explicit Config MVP — Phase 11 complete, ready for Phase 12

## Current Position

Phase: 12 (VS Code Plugin + Migration + CLI) — third of 4 v3.0 phases (10-13)
Plan: Not yet planned
Status: Ready for planning
Last activity: 2026-02-11 — Completed 11-04-PLAN.md (gap closure)

Progress: ██████████░░░░░░ 50% (2/4 phases)

## Performance Metrics

**v1.0 (archived):**
- Total plans completed: 12
- Total execution time: 24min

**v2.0 (archived):**
- Total plans completed: 44 (29 phase plans + 8 quick tasks + 7 gap closures)
- Total execution time: ~75min

**v3.0:**
- Total plans completed: 5
- Total execution time: ~12min

## Accumulated Context

### Decisions

Decisions logged in PROJECT.md Key Decisions table.

**v3.0 decisions:**
- Explicit source→target JSON config (global.json, project.json)
- Generic file deployer — tool doesn't know about plugin names
- Git config as gitconfig include file (not git config commands)
- CLAUDE.md as single maintained file (no template assembly)
- Wizards deferred to v4 — users edit JSON directly
- VS Code plugin added to v3 scope
- Shell plugin deferred to v4+
- jq dependency required
- Group argument maps to top-level keys in global.json (11-02)
- No validation that group exists - jq returns empty for missing keys (11-02)
- Old plugin deploy scripts preserved for status/list commands until Phase 12 (11-02)
- project_root parameter enables relative target path resolution for per-project configs (11-03)
- .dotconfigs/ auto-excluded in .git/info/exclude to keep projects clean (11-03)
- Removed plugin filter from project-init — JSON config controls what's deployed (11-03)
- Project-specific overrides hardcoded for claude/git, unknown groups auto-transformed (11-04)
- project.json.example deleted — global.json is single source of truth (11-04)

**Carrying forward from v2.0:**
- Plugin architecture (plugins/claude/, plugins/git/, shared lib/)
- `dotconfigs` as CLI entry point name
- Bash 3.2 compatibility (macOS requirement)
- File-level symlinks for GSD coexistence

### Pending Todos

- [ ] **Phase 12**: VS Code plugin + .env migration + CLI cleanup
- [ ] **Phase 13**: Documentation
- [ ] **v4+**: Deployment scan/status report command (`dotconfigs scan`)
- [ ] **v4+**: Add `deploy` toggle field to global.json/project.json schema (skip entries without deleting)
- [ ] **v4+**: Build merge-based deploy method for shared config files (settings.json SSOT vs runtime writes)

### Blockers/Concerns

**Resolved:**
- Global hooks only work from dotconfigs repo — FIXED in 10-01
- Over-engineered wizard-driven deployment — RESOLVED by v3 simplification
- Project scaffolding (project.sh) bugs — REPLACED by JSON-based project config commands in 11-03

**Active:**
- .env quoting bugs — will be eliminated by JSON migration in Phase 12

### Backup Reference

Original v3 plans (wizard refactor, CLI restructure) backed up to `.planning/v4-v3-backup/`.
Wizard code (setup.sh files, lib/wizard.sh) preserved in codebase — shelved, not deleted.

## Session Continuity

Last session: 2026-02-11 15:15:20Z
Stopped at: Completed 11-04-PLAN.md (gap closure for UAT Test 5)
Resume file: None

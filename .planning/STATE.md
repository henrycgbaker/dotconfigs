# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-10)

**Core value:** Single source of truth for all personal dev configuration — one repo, one CLI, deployed everywhere with minimal context footprint.
**Current focus:** v3.0 Architecture Rethink — research and implement manifest-driven deployment with JSON config.

## Current Position

Phase: Not started (research pending)
Plan: —
Status: Defining requirements
Last activity: 2026-02-10 — Milestone v3.0 started

Progress: ░░░░░░░░░░░░░░░░ 0%

## Performance Metrics

**v1.0 (archived):**
- Total plans completed: 12
- Total execution time: 24min
- Average duration: 2.0min

**v2.0 (archived):**
- Total plans completed: 44 (29 phase plans + 8 quick tasks + 7 gap closures)
- Total execution time: ~75min
- Average duration: 2.6min

## Accumulated Context

### Decisions

Decisions logged in PROJECT.md Key Decisions table.

**v3.0 decisions:**
- [v3.0]: Config-first, wizards later — manual JSON config + deploy in v3.0, wizard UX in v4.0
- [v3.0]: Thin layer principle — leverage underlying tool schemas tightly, don't build parallel config infrastructure
- [v3.0]: .env → JSON config — structured config replaces flat .env
- [v3.0]: Phase 10 (per-hook scope) absorbed — module-level deploy targets solve this naturally
- [v3.0]: Preserve existing functionality — simplify/unify, don't discard working code
- [v3.0]: Shelve wizards on branch — existing wizard code preserved for v4.0

**Carrying forward from v2.0:**
- Plugin architecture (plugins/claude/, plugins/git/, shared lib/)
- `dotconfigs` as CLI entry point name
- Plugin function naming: `plugin_<name>_<action>`
- Bash 3.2 compatibility (macOS requirement)
- File-level symlinks for GSD coexistence
- TTY-aware colour output
- Drift detection model (5-state)
- Per-hook enable/disable via config variables

### Pending Todos

- [ ] **Architecture**: Rethink global vs project-level interaction model (see todos/pending/) — PRIMARY v3.0 DRIVER
- [ ] **Testing**: Test project-init on brownfield project and ds01 server
- [ ] **GSD framework**: Add Explore agent to model profile lookup table (GSD PR, not this repo)
- [ ] **Wizard UX**: Unify rerun/edit-mode logic (deferred to v4.0)
- [ ] **Wizard UX**: Improve toggle menu previews (deferred to v4.0)

### Blockers/Concerns

**Active:**
- Global hooks only work from dotconfigs repo — `$CLAUDE_PROJECT_DIR` resolves to CWD, not dotconfigs path (drives v3.0 architecture)
- Plugins have inconsistent UX between and within (drives v3.0 simplification)

**Resolved:**
- Pre-commit hook COMMIT_EDITMSG timing bug — FIXED in v1.0 03-03
- v1 CLI design mismatches — accepted as-is
- Settings.json deny rules bug (#6699, #8961) — WORKAROUND: PreToolUse hook (08-04)

### v2.0 Quick Tasks (archived)

| # | Description | Date | Commit |
|---|-------------|------|--------|
| 001 | Fix milestone audit critical bugs | 2026-02-07 | 1bd83e4 |
| 002 | Rename CLI, restructure commands, .env quoting | 2026-02-09 | 683ace8 |
| 003-01..04 | Claude/Git wizard UX, edit mode, setup polish | 2026-02-09 | b36d8d0..e0d75d2 |
| 004-01..02 | Deploy provenance, project-configs fixes | 2026-02-09 | a461bbc..5be5c68 |

## Session Continuity

Last session: 2026-02-10
Stopped at: Milestone v3.0 initialization
Resume file: None

---

**v2.0 Status:** COMPLETE — archived to MILESTONES.md
**v3.0 Status:** Initializing — research pending

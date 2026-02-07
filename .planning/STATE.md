# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-07)

**Core value:** Single source of truth for all personal dev configuration — one repo, one CLI, one `.env`, deployed everywhere with minimal context footprint.
**Current focus:** v2.0 Plugin Architecture — requirements and roadmap defined, ready for phase planning.

## Current Position

Phase: 4 (Core Infrastructure & CLI Entry Point)
Plan: Not yet created
Status: Requirements and roadmap complete, ready for `/gsd:plan-phase`
Last activity: 2026-02-07 — v2.0 requirements and roadmap defined

## Performance Metrics

**v1.0 (archived):**
- Total plans completed: 12
- Total execution time: 24min
- Average duration: 2.0min

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.

Key decisions carrying forward from v1:
- Subcommand CLI design (not flag-based)
- File-level symlinks for GSD coexistence
- .env for deploy configuration
- Settings.json layering (global → project)
- Hooks as local-only copies (not tracked in projects)
- macOS portability via perl for absolute path resolution
- bash select for menus (no dialog/whiptail dependencies)

New v2.0 decisions:
- [v2.0]: Rename dotclaude → dotconfigs
- [v2.0]: Plugin architecture (plugins/claude/, plugins/git/, shared lib/)
- [v2.0]: `dotconfigs` as CLI entry point name
- [v2.0]: Separate setup (wizard → .env) from deploy (.env → filesystem)
- [v2.0]: Git plugin covers hooks + identity + gitconfig workflow
- [v2.0]: Shell plugin deferred to v3
- [v2.0]: Bash 3.2 fixes already on branch (refactor/lean-claude-setup)
- [v2.0]: Strangler fig migration — deploy.sh becomes wrapper, not deleted
- [v2.0]: Plugin function naming: `plugin_<name>_<action>`
- [v2.0]: Eager lib loading, lazy plugin loading

### Pending Todos

- [ ] **GSD framework**: Add Explore agent to model profile lookup table (GSD PR, not this repo)
- [ ] **Git workflow**: Review squash-merge vs native git merge
- [ ] **Explore hook**: Add hook for sonnet on explore agents (deferred to v3)
- [ ] **README**: Comprehensive rewrite with latest workflows (deferred to v3)

### Blockers/Concerns

- Settings.json deny rules have a known bug (Claude Code #6699, #8961) — PreToolUse hook workaround in place
- Current branch `refactor/lean-claude-setup` has uncommitted bash 3.2 fixes + wizard improvements that need to be committed before Phase 4 planning

**Resolved:**
- Pre-commit hook COMMIT_EDITMSG timing bug — FIXED in v1.0 03-03
- v1 CLI design mismatches (subcommands vs flags) — accepted as-is, cleaner design

## Session Continuity

Last session: 2026-02-07
Stopped at: v2.0 requirements and roadmap written, ready for phase 4 planning
Resume file: None

# Milestones: dotconfigs (formerly dotclaude)

## Completed Milestones

### v1.0: Lean Claude Setup

**Completed:** 2026-02-06
**Phases:** 3 (12 plans)
**Duration:** ~24min execution

**Goal:** Transform over-engineered 94-file repo into lean, portable Claude Code configuration with minimal context footprint and deterministic enforcement.

**Delivered:**
- Phase 1: Cleanup & Deletion — 94→30 files, GSD duplicates removed, rules/ eliminated
- Phase 2: Context Optimisation — CLAUDE.md 52→41 lines, context burn reduced
- Phase 3: Settings, Hooks, Deploy & Skills — settings.json, git hooks, deploy.sh wizard, /commit, /squash-merge, registry scanner

**Requirements:** 26/29 satisfied (3 design mismatches accepted — subcommand CLI vs flag CLI)

**Key decisions that carry forward:**
- Subcommand CLI design (not flag-based)
- File-level symlinks for GSD coexistence
- .env for deploy configuration
- Settings.json layering (global → project)
- Hooks as local-only copies (not tracked in projects)

**Last phase number:** 3

### v2.0: Plugin Architecture

**Completed:** 2026-02-10
**Phases:** 6 (phases 4-9, 44 plans) + 8 quick tasks
**Duration:** ~75min execution

**Goal:** Transform dotclaude into dotconfigs — extensible plugin-based configuration manager with `claude` and `git` plugins, shared library layer, and unified `dotconfigs` CLI.

**Delivered:**
- Phase 4: Core Infrastructure — dotconfigs entry point, lib/ shared libraries, filesystem-based plugin discovery
- Phase 5: Claude Plugin Extraction — setup wizard, deploy logic, project scaffolding migrated from monolithic deploy.sh
- Phase 6: Git Plugin — hooks, identity, workflow, aliases with full wizard and deploy flow
- Phase 7: Integration & Polish — status/list, drift detection, deploy flags, README, PATH symlink
- Phase 8: Hooks & Workflows Review — unified variable naming, PreToolUse guard, full hook roster, auto-generated ROSTER.md
- Phase 9: Config UX Redesign — opt-in wizards, G/L provenance badges, CLAUDE.md exclusion, settings assembly

**Requirements:** 32/32 satisfied (100%)

**Key decisions that carry forward:**
- Three-tier config hierarchy: hardcoded default → .env → project config
- Plugin interface: plugin_{name}_{setup|deploy|project|status}()
- Opt-in config model (unset = unmanaged)
- File-level symlinks with ownership tracking
- Bash 3.2 compatibility (macOS requirement)
- Phase 10 (per-hook scope) not started — absorbed into v3.0

**Last phase number:** 9

---

## Active Milestone

### v3.0: Architecture Rethink + Shell Plugin

See PROJECT.md and ROADMAP.md for current milestone details.

---
*Last updated: 2026-02-10*
